# 원본 ROS 2와의 차이

원본 Jazzy(`/opt/ros/jazzy`) 위에 덮어 빌드하는 overlay다. 원본 헤더로 빌드한 기존 프로그램은 다시 빌드하지 않아도 그대로 돈다. 새 기능은 대부분 환경 변수로 켜고, 끄면 원본과 같이 동작한다.

## 한눈에 보기

| 기능 | 원본 | ros2_plus | 켜는 법 |
| --- | --- | --- | --- |
| executor | rclcpp와 rclpy의 executor가 따로 구현돼 있다 | 두 언어의 `SingleThreadedExecutor`, `MultiThreadedExecutor`가 C로 된 공통 executor(rcl_executor)를 쓴다. 실행 순서는 원본 rclcpp와 같다 | `ROS_EXECUTOR_CORE=1` |

지원 RMW는 rmw_zenoh_cpp(기본)와 rmw_cyclonedds_cpp다.

## 측정 예

같은 머신에서 번갈아 잰 중앙값이다. "이전"은 원본 코드다.

| 상황 | 이전 | ros2_plus |
| --- | --- | --- |
| rviz에 1920x1080 영상 8개(30 Hz)를 띄웠을 때 rviz CPU(20초 동안) | 22.8 s(원본) | 8.3 s |
| `MultiThreadedExecutor`에서 20 ms callback을 돌릴 때 CPU | 81~84%(원본) | 2~4% |

## 패키지별로 더한 것

| 패키지 | 더한 것 |
| --- | --- |
| rosbag2 | 녹화할 때 topic별 주기 제한(`--topic-throttle-frequency /imu=10`), 변환할 때 topic별 메시지 구간만 꺼내기, MCAP에서 topic별 chunk(일부 topic만 빠르게 읽기) |
| launch | `ros2 launch ... --dump-params`(노드를 띄우지 않고 최종 파라미터 출력), 파라미터 파일 여러 개를 하나로 합쳐 넘기기, launch 파일 로드 시간 감소 |
| rviz | PointCloud2를 깊이에 따라 흐리게, 필드 값에 따라 점 크기를 다르게 그리기, Bayer 영상 표시 옵션 |
| rclpy | sim time에서 `/clock`을 전용 스레드로 받는 `use_clock_thread` |

## 켜지 않아도 바뀌는 것

원본의 버그를 고친 것이다. 스위치와 관계없이 적용된다.

- rclcpp `MultiThreadedExecutor`가 바쁜 group 때문에 다른 스레드를 헛돌리던 것
- rclcpp `EventsExecutor`에서 늦은 timer가 연달아 여러 번 실행되던 것, `EventsCBGExecutor` 큐가 무한히 늘던 것
- rclpy가 Ctrl-C에서 멈추거나 `RCLError`로 끝나던 것, sim time에서 callback이 도는 동안 ROS time이 멈추던 것
- rmw_zenoh에서 엔티티를 지울 때 생기던 교착
- `ros2 topic hz`, `bw`가 큰 메시지에서 값을 내지 않던 것
- `ros2 topic echo`, `hz`의 `--filter` 식이 임의 코드를 실행하던 것(CVE-2024-42002)
- namespace가 토픽 이름보다 긴 노드에서 image_transport 발행자와 구독자가 죽던 것
- rclcpp 액션 서버가 이미 있는 goal ID의 요청을 받으면 abort하던 것
- tf2_sensor_msgs가 PCL 방식으로 패딩된 점군을 변환하지 못하던 것

전체 목록과 정확한 조건은 [api.md](api.md) 3절, 버전별 변경은 [release-notes](release-notes)에 있다.

## 주의할 점

- 위 기능의 새 API를 쓴 코드는 ros2_plus가 있어야 빌드된다. 원본 Jazzy만으로는 빌드되지 않는다.
- 수 MB 메시지를 한 프로세스에서 계속 주고받을 때 CPU가 크게 늘면 glibc 할당기 설정 두 개를 함께 준다([api.md](api.md) 4절).
