# ros2_plus

ROS 2 Jazzy overlay.

## 원본 ROS 2와의 차이

기능, 지원 RMW, 런타임 스위치는 [docs/differences.md](docs/differences.md), 패키지별 API와 바뀐 동작은 [docs/api.md](docs/api.md)에 있다.

## 설치

Ubuntu 24.04, `/opt/ros/jazzy`, vcstool, Rust(cargo, ros2_rust 빌드용)가 필요하다.

```bash
mkdir -p ~/ros2_plus_ws/src
cd ~/ros2_plus_ws
git clone -b jazzy <URL> ros2_plus
vcs import src < ros2_plus/ros2_plus.repos
rosdep install --from-paths src --ignore-src --rosdistro jazzy -y --skip-keys "cargo rmw_connextdds"
python3 -m pip install --no-deps --target colcon_ext \
  colcon-cargo==0.2.0 cargo-ament-build==0.1.11 toml==0.10.2 \
  "colcon-ros-cargo @ git+https://github.com/DCUSnSLab/colcon-ros-cargo.git@cfa593190add821c34d94c910fd35f3533a786da"
export PYTHONPATH="$PWD/colcon_ext${PYTHONPATH:+:$PYTHONPATH}" PATH="$PWD/colcon_ext/bin:$PATH"
source /opt/ros/jazzy/setup.bash
colcon build --base-paths src --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  --packages-up-to rosidl_generator_py
source install/setup.bash
colcon build --base-paths src --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo
source install/setup.bash
```

워크스페이스 위치(`~/ros2_plus_ws`)는 바꿔도 된다.

rosdep은 빌드와 시험 의존성을 apt로 설치한다. 빠지면 `rosidl_runtime_c`가 시험 의존성(`performance_test_fixture`)을 찾지 못해 실패한다. `cargo`는 Rust 설치(rustup)로, Connext는 지원하지 않는 RMW라서 건너뛴다.

`rosidl_generator_py`를 먼저 빌드하고 `install/setup.bash`를 불러온 뒤 나머지를 빌드한다. 메시지 패키지가 install 공간의 생성기 템플릿을 읽기 때문이다. 불러오지 않으면 `/opt/ros/jazzy`의 원본 생성기를 잡는다. colcon cargo 확장은 `pip install --user`로 설치하지 않는다. 다른 워크스페이스의 `Cargo.toml` 디렉터리까지 가로챈다. colcon-ros-cargo는 PyPI의 0.2.0 대신 연구실 포크를 쓴다. 0.2.0은 워크스페이스 맨 위에 `.cargo/config.toml`을 써서, 같은 워크스페이스에서 `cargo --locked`로 빌드하는 zenoh-c가 lock 파일 불일치로 실패한다. 포크는 이 설정을 패키지의 build 디렉터리에 쓴다.
