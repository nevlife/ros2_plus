# ros2_plus

ROS 2 Jazzy overlay다. 순정 `/opt/ros/jazzy` 위에 수정한 포크를 올려 빌드한다. 순정 헤더로 빌드한 바이너리는 overlay 위에서 그대로 돈다. 새 기능은 모두 스위치로 켠다.

- 같은 프로세스 안의 topic, service, action을 rcl broker가 직렬화 없이 전달한다
- rclcpp, rclpy executor를 rcl_executor core 하나로 돌린다
- rmw_zenoh SHM loan
- rclpy가 받은 숫자 배열을 복사 없는 numpy view로 준다. Python type adapter와 C++·Python 혼합 component container
- rosbag2, rviz, image_transport, cv_bridge, tf2 성능 개선

## 버전

| 목록 | 내용 |
| --- | --- |
| [ros2_plus.repos](ros2_plus.repos) | 수정한 저장소의 `jazzy` 브랜치 |

지금은 rcl만 있다. rcl은 rmw의 수정(`rmw/intra_process.h`)에 의존하므로 rmw가 목록에 들어올 때까지 이 목록만으로는 빌드되지 않는다.

## 설치

Ubuntu 24.04, `/opt/ros/jazzy`, vcstool, Rust(cargo, ros2_rust 빌드용)가 필요하다.

```bash
mkdir -p ~/ros2_plus_ws/src
cd ~/ros2_plus_ws
git clone -b jazzy <이 저장소 URL> ros2_plus
vcs import src < ros2_plus/ros2_plus.repos
python3 -m pip install --no-deps --target colcon_ext \
  colcon-cargo==0.2.0 colcon-ros-cargo==0.2.0 cargo-ament-build==0.1.11 toml==0.10.2
export PYTHONPATH="$PWD/colcon_ext${PYTHONPATH:+:$PYTHONPATH}" PATH="$PWD/colcon_ext/bin:$PATH"
source /opt/ros/jazzy/setup.bash
colcon build --base-paths src --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  --packages-up-to rosidl_generator_py
source install/setup.bash
colcon build --base-paths src --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo
source install/setup.bash
```

워크스페이스 위치(`~/ros2_plus_ws`)는 바꿔도 된다.

`rosidl_generator_py`를 먼저 빌드하고 `install/setup.bash`를 불러온 뒤 나머지를 빌드한다. 메시지 패키지가 install 공간의 생성기 템플릿을 읽기 때문이다. 불러오지 않으면 `/opt/ros/jazzy`의 순정 생성기를 잡는다. colcon cargo 확장은 `pip install --user`로 설치하지 않는다. 다른 워크스페이스의 `Cargo.toml` 디렉터리까지 가로챈다.

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

## 문서

- [docs/api.md](docs/api.md): 스위치, 패키지별 새 API, 바뀐 동작, 주의할 점, Python composition
- [docs/release-notes](docs/release-notes): 버전별 변경

## 라이선스

Apache License 2.0. 각 포크는 upstream 저장소의 라이선스를 따른다.
