# 원본 ROS 2와의 차이

원본 Jazzy(`/opt/ros/jazzy`) 위에 덮어 빌드하는 overlay다. 원본 헤더로 빌드한 기존 프로그램은 다시 빌드하지 않아도 그대로 돈다. 새 기능은 대부분 환경 변수로 켜고, 끄면 원본과 같이 동작한다.

## 한눈에 보기

| 기능 | 원본 | ros2_plus | 켜는 법 |
| --- | --- | --- | --- |
| executor | rclcpp와 rclpy의 executor가 따로 구현돼 있다 | 두 언어의 `SingleThreadedExecutor`, `MultiThreadedExecutor`가 C로 된 공통 executor(rcl_executor)를 쓴다. 실행 순서는 원본 rclcpp와 같다 | `ROS_EXECUTOR_CORE=1` |
| C++과 Python 노드를 한 프로세스에 | 안 된다 | `component_container_mixed`에 rclcpp component와 rclpy 노드를 함께 올린다 | `ros2 run rclpy_components component_container_mixed` |

지원 RMW는 rmw_zenoh_cpp(기본)와 rmw_cyclonedds_cpp다.

## 측정 예

같은 머신에서 번갈아 잰 중앙값이다. "이전"은 원본 코드다.

| 상황 | 이전 | ros2_plus |
| --- | --- | --- |
| tf2로 100만 점(xyz) 좌표 변환 | 48 ms(원본) | 17 ms |
| `ros2 topic hz`로 1 kHz topic을 잴 때 CPU | 36.8%(원본) | 8.6% |

## 패키지별로 더한 것

| 패키지 | 더한 것 |
| --- | --- |
| rosbag2 | 녹화할 때 topic별 주기 제한(`--topic-throttle-frequency /imu=10`), 변환할 때 topic별 메시지 구간만 꺼내기, MCAP에서 topic별 chunk(일부 topic만 빠르게 읽기) |
| launch | `ros2 launch ... --dump-params`(노드를 띄우지 않고 최종 파라미터 출력), 파라미터 파일 여러 개를 하나로 합쳐 넘기기, launch 파일 로드 시간 감소 |
| image_transport | 새 transport `depthz`(depth 영상 무손실 압축), OpenCV 영상 같은 adapted 타입을 그대로 발행하는 publisher |
| cv_bridge | 메시지 버퍼를 복사 없이 가리키는 numpy view(`imgmsg_to_cv2_view`) |
| pcl_conversions, ros2_numpy | PCL 점군의 C++ type adapter, XYZ를 복사 없이 읽는 view |
| rviz | PointCloud2를 깊이에 따라 흐리게, 필드 값에 따라 점 크기를 다르게 그리기, Bayer 영상 표시 옵션 |
| rclcpp, rclpy | 여러 노드가 `/clock` 구독 하나를 공유(TimeSource 공유), 파라미터 여러 개를 이벤트 하나로 선언 |

## 켜지 않아도 바뀌는 것

원본의 버그를 고친 것이다. 스위치와 관계없이 적용된다.

- rclcpp `MultiThreadedExecutor`가 바쁜 group 때문에 다른 스레드를 헛돌리던 것
- rclcpp `EventsExecutor`에서 늦은 timer가 연달아 여러 번 실행되던 것, `EventsCBGExecutor` 큐가 무한히 늘던 것
- rclpy가 Ctrl-C에서 멈추거나 `RCLError`로 끝나던 것, sim time에서 callback이 도는 동안 ROS time이 멈추던 것
- rmw_zenoh에서 엔티티를 지울 때 생기던 교착
- `ros2 topic hz`, `bw`가 큰 메시지에서 값을 내지 않던 것

전체 목록과 정확한 조건은 [api.md](api.md) 3절, 버전별 변경은 [release-notes](release-notes)에 있다.

## 주의할 점

- 위 기능의 새 API를 쓴 코드는 ros2_plus가 있어야 빌드된다. 원본 Jazzy만으로는 빌드되지 않는다.
- 메시지 패키지는 ros2_plus의 생성기로 다시 빌드해야 숫자 배열 setter와 역직렬화 개선이 적용된다(설치 절차대로 빌드하면 된다).
- 수 MB 메시지를 한 프로세스에서 계속 주고받을 때 CPU가 크게 늘면 glibc 할당기 설정 두 개를 함께 준다([api.md](api.md) 4절).
