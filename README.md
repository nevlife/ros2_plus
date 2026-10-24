# ros2_plus

ROS 2 Jazzy overlay.
순정 ROS 2와의 차이는 [docs/differences.md](docs/differences.md)에 있다.

## 설치

Ubuntu 24.04, `/opt/ros/jazzy`, vcstool이 필요하다.

```bash
mkdir -p ~/ros2_plus_ws/src
cd ~/ros2_plus_ws
git clone -b jazzy <URL> ros2_plus
vcs import src < ros2_plus/ros2_plus.repos
source /opt/ros/jazzy/setup.bash
colcon build --base-paths src --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo
source install/setup.bash
```

워크스페이스 위치(`~/ros2_plus_ws`)는 바꿔도 된다.
