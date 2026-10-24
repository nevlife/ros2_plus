# 원본 ROS 2와의 차이

원본 Jazzy(`/opt/ros/jazzy`) 위에 덮어 빌드하는 overlay다. 원본 헤더로 빌드한 기존 프로그램은 다시 빌드하지 않아도 그대로 돈다. 새 기능은 대부분 환경 변수로 켜고, 끄면 원본과 같이 동작한다.

## 한눈에 보기

| 기능 | 원본 | ros2_plus | 켜는 법 |
| --- | --- | --- | --- |
| 같은 프로세스 안 전달 | 같은 프로세스의 노드끼리도 메시지를 직렬화해 미들웨어로 보낸다. rclcpp intra-process는 C++끼리만 되고 노드마다 설정해야 한다 | rcl이 메시지 객체를 직렬화 없이 그대로 넘긴다. C++과 Python 사이, topic, service, action 모두 | `RCL_INTRA_PROCESS=1`(rmw_zenoh) |
| executor | rclcpp와 rclpy의 executor가 따로 구현돼 있다 | 두 언어가 C로 된 공통 executor(rcl_executor)를 쓴다. 스레드 시작 hook(우선순위, CPU 고정), callback group 우선순위, group별 전용 스레드 | `ROS_EXECUTOR_CORE=1` 또는 `RclExecutor` |
| 프로세스 사이 공유 메모리 loan | rmw_zenoh는 loan을 주지 않는다 | 고정 크기 메시지를 공유 메모리에 바로 써서 보내고, 받는 쪽도 그 메모리를 읽는다 | 공유 메모리를 켜고 `borrow_loaned_message` |
| Python 배열 수신 | 숫자 배열을 Python `array`로 원소마다 복사한다 | 복사 없는 읽기 전용 numpy view로 준다 | `RCLPY_MESSAGE_ARRAYS=numpy` |
| Python type adapter | 없다 | Python 객체(예: OpenCV 영상, numpy 점군)를 그대로 발행하고 받는다. 같은 프로세스면 변환이 일어나지 않는다 | `create_publisher`, `create_subscription`에 adapter |
| C++과 Python 노드를 한 프로세스에 | 안 된다 | `component_container_mixed`에 rclcpp component와 rclpy 노드를 함께 올린다 | `ros2 run rclpy_components component_container_mixed` |

지원 RMW는 rmw_zenoh_cpp(기본)와 rmw_cyclonedds_cpp다. 같은 프로세스 안 전달과 loan은 rmw_zenoh에서만 동작한다.

## 측정 예

같은 머신에서 번갈아 잰 중앙값이다. "이전"은 원본 코드, 또는 원본처럼 ROS 메시지로 변환해 보내는 경로다.

| 상황 | 이전 | ros2_plus |
| --- | --- | --- |
| 같은 프로세스의 Python 노드끼리 8 MiB 데이터 전달 | 2.3 ms(ROS 메시지로 변환) | 0.16~0.23 ms(type adapter, 객체 그대로) |
| 같은 프로세스에서 OpenCV 영상 한 장 전달 | 5.9 ms(ROS 메시지로 변환) | 0.40 ms(cv_bridge adapter) |
| 같은 프로세스에서 100만 점 점군 전달 | 18.3 ms(ROS 메시지로 변환) | 0.40 ms(ros2_numpy adapter) |
| Python에서 8 MiB Image를 받아 Python 객체로 만들기 | 244 us(원본) | 2.1 us(numpy view) |
| tf2로 100만 점(xyz) 좌표 변환 | 48 ms(원본) | 17 ms |
| `ros2 topic hz`로 1 kHz topic을 잴 때 CPU | 36.8%(원본) | 8.6% |

## 패키지별로 더한 것

| 패키지 | 더한 것 |
| --- | --- |
| rosbag2 | 녹화할 때 topic별 주기 제한(`--topic-throttle-frequency /imu=10`), 변환할 때 topic별 메시지 구간만 꺼내기, MCAP에서 topic별 chunk(일부 topic만 빠르게 읽기) |
| launch | `ros2 launch ... --dump-params`(노드를 띄우지 않고 최종 파라미터 출력), 파라미터 파일 여러 개를 하나로 합쳐 넘기기, launch 파일 로드 시간 감소 |
| image_transport | 새 transport `depthz`(depth 영상 무손실 압축), OpenCV 영상 같은 adapted 타입을 그대로 발행하는 publisher |
| cv_bridge | 메시지 버퍼를 복사 없이 가리키는 numpy view(`imgmsg_to_cv2_view`), GPU(`cv::cuda::GpuMat`) type adapter |
| pcl_conversions, ros2_numpy | PCL, numpy 점군 type adapter, XYZ를 복사 없이 읽는 view |
| rviz | PointCloud2를 깊이에 따라 흐리게, 필드 값에 따라 점 크기를 다르게 그리기, Bayer 영상 표시 옵션 |
| rclcpp, rclpy | 여러 노드가 `/clock` 구독 하나를 공유(TimeSource 공유), 파라미터 여러 개를 이벤트 하나로 선언, rclpy loan 발행과 수신 |

## 켜지 않아도 바뀌는 것

원본의 버그를 고친 것이다. 스위치와 관계없이 적용된다.

- rclcpp `MultiThreadedExecutor`가 바쁜 group 때문에 다른 스레드를 헛돌리던 것
- rclcpp `EventsExecutor`에서 늦은 timer가 연달아 여러 번 실행되던 것, `EventsCBGExecutor` 큐가 무한히 늘던 것
- rclpy가 Ctrl-C에서 멈추거나 `RCLError`로 끝나던 것, sim time에서 callback이 도는 동안 ROS time이 멈추던 것
- rmw_zenoh에서 엔티티를 지울 때 생기던 교착
- `ros2 topic hz`, `bw`가 큰 메시지에서 값을 내지 않던 것
- Python 메시지의 `byte[]` 필드가 list가 아니라 `bytes`다. list 대입은 계속 되고 `ros2 topic echo` 출력은 원본과 같다

전체 목록과 정확한 조건은 [api.md](api.md) 3절, 버전별 변경은 [release-notes](release-notes)에 있다.

## 주의할 점

- 위 기능의 새 API를 쓴 코드는 ros2_plus가 있어야 빌드된다. 원본 Jazzy만으로는 빌드되지 않는다.
- 메시지 패키지는 ros2_plus의 생성기로 다시 빌드해야 numpy view와 `bytes` 변경이 적용된다(설치 절차대로 빌드하면 된다).
- 같은 프로세스 안 전달로 받은 메시지와 공유 메모리 loan은 발행자, 다른 구독자와 같은 메모리다. 고치려면 먼저 복사한다.
- loan은 작은 메시지에서 오히려 느리다. 큰 고정 크기 메시지에만 쓴다.
