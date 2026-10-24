# 순정 ROS 2와의 차이

순정 헤더로 빌드한 바이너리는 overlay 위에서 그대로 돈다. 새 기능은 모두 스위치로 켠다.

## 기능

- 같은 프로세스 안의 topic, service, action을 rcl broker가 직렬화 없이 전달한다
- rclcpp, rclpy executor를 rcl_executor core 하나로 돌린다
- rmw_zenoh SHM loan
- rclpy가 받은 숫자 배열을 복사 없는 numpy view로 준다. Python type adapter와 C++·Python 혼합 component container
- rosbag2, rviz, image_transport, cv_bridge, tf2 성능 개선

## RMW

| 등급 | RMW | 뜻 |
| --- | --- | --- |
| 1 | `rmw_zenoh_cpp`(기본), `rmw_cyclonedds_cpp` | 모든 기능과 시험을 지원한다 |

## 런타임 스위치

모두 기본으로 꺼져 있다. 끄면 동작은 순정 Jazzy와 같다.

| 변수 | 의미 |
| --- | --- |
| `ROS_EXECUTOR_CORE=1` | rclcpp, rclpy의 Single/MultiThreadedExecutor를 rcl_executor core로 돌린다 |
| `RCL_INTRA_PROCESS=1` | 같은 rcl context의 메시지·service를 rcl broker로 전달한다(rmw_zenoh) |
| `RCLPY_MESSAGE_ARRAYS=numpy` | rclpy가 받은 숫자 배열 필드를 복사 없는 읽기 전용 numpy view로 준다 |
| `ROS_DISABLE_LOANED_MESSAGES=0` | 구독 쪽 loan을 켠다(rmw_zenoh SHM loan) |
| `ZENOH_CONFIG_OVERRIDE='transport/shared_memory/enabled=true'` | rmw_zenoh 공유 메모리 |

## 더 볼 문서

- [api.md](api.md): 스위치, 패키지별 새 API, 바뀐 동작, 주의할 점, Python composition
- [release-notes](release-notes): 버전별 변경
