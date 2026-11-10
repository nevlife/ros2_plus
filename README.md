# ros2_plus

ROS 2 Jazzy overlay.

## 원본 ROS 2와의 차이

기능, 지원 RMW, 런타임 스위치는 [docs/differences.md](docs/differences.md), 패키지별 API와 바뀐 동작은 [docs/api.md](docs/api.md)에 있다.

## 설치

Ubuntu 24.04, `/opt/ros/jazzy`, vcstool, rustup으로 설치한 cargo(rmw_zenoh의 zenoh-c 빌드용)가 필요하다.

```bash
mkdir -p ~/ros2_plus_ws
cd ~/ros2_plus_ws
git clone -b jazzy <URL> ros2_plus
ros2_plus/install.sh
source ros2_plus/env.sh
```

`install.sh`는 아래 절차를 그대로 실행한다. 저장소를 `src`에 받고, rosdep으로 의존성을 설치한 뒤 빌드한다. 동시에 빌드하는 패키지 수는 `BUILD_JOBS`(기본은 CPU 수의 절반)로 정한다. 셸마다 `source ros2_plus/env.sh`를 불러온다. `env.sh`는 `/opt/ros/jazzy`와 이 워크스페이스를 불러오고, zenoh-c를 다시 빌드할 때 쓰도록 `~/.cargo/bin`을 `PATH`에 넣는다. 워크스페이스 위치가 이 구조와 다르면 `ROS2_PLUS_WS`로 정한다.

numpy 2가 필요한 노드가 있으면 `WITH_NUMPY2=1 ros2_plus/install.sh`로 설치한다. 이 경우 numpy 2 가상 환경 `.venv_np2`를 만들고, cv_bridge를 numpy 2 헤더로 다시 빌드한다. numpy 2 헤더로 빌드한 cv_bridge는 numpy 1과 2에서 모두 돈다. numpy 2로 노드를 띄울 셸에서는 `source ros2_plus/env.sh numpy2`를 불러온다. apt의 `python3-opencv`는 numpy 1용이라 이 환경에서는 pip의 opencv-python을 쓴다. 이 환경은 시스템 Python 패키지도 함께 보는데, apt의 scipy처럼 numpy 1용으로 빌드된 패키지는 numpy 2에서 import하지 못할 수 있다.

손으로 설치하려면 다음을 실행한다.

```bash
mkdir -p ~/ros2_plus_ws/src
cd ~/ros2_plus_ws
git clone -b jazzy <URL> ros2_plus
vcs import src < ros2_plus/ros2_plus.repos
source /opt/ros/jazzy/setup.bash
rosdep install --from-paths src --ignore-src --rosdistro jazzy -y --skip-keys "cargo rmw_connextdds"
colcon build --base-paths src --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo
source install/setup.bash
```

워크스페이스 위치(`~/ros2_plus_ws`)는 바꿔도 된다.

rosdep은 빌드와 시험 의존성을 apt로 설치한다. 빠지면 `rosidl_runtime_c`가 시험 의존성(`performance_test_fixture`)을 찾지 못해 실패한다. `cargo`는 rustup으로 설치한 것을 쓰고, Connext는 지원하지 않는 RMW라서 건너뛴다.

rclrs(ros2_rust), rosidl_runtime_rs, rosidl_rust는 목록에서 빠졌다. 메시지 패키지는 원본 Jazzy처럼 `/opt`의 `rosidl_generator_rs`로 생성한다. 이전 목록으로 설치한 워크스페이스에는 이 저장소들이 남는다(`vcs import`는 목록에 없는 저장소를 지우지 않는다). 남은 `rosidl_generator_rs`는 계속 빌드되어 `/opt`의 생성기를 가리므로, 새 셸에서 다음처럼 지운 뒤 다시 설치한다.

```bash
cd ~/ros2_plus_ws
rm -rf src/ros2/ros2_rust src/ros2/rosidl_runtime_rs src/ros2/rosidl_rust colcon_ext \
  {build,install}/{rclrs,rosidl_runtime_rs,rosidl_generator_rs}
ros2_plus/install.sh
```
