#!/usr/bin/env bash
# Build the ros2_plus overlay on top of /opt/ros/jazzy.
#
#   ros2_plus/install.sh
#
# The workspace is the directory that holds this clone (<ws>/ros2_plus). The repositories go to
# <ws>/src. WITH_NUMPY2=1 also creates the numpy 2 virtual environment <ws>/.venv_np2.
# ros2_plus/env.sh loads the result in a shell.
# REPOS selects another repository list, BUILD_JOBS sets how many packages build at once.
set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$(cd -P "$HERE/.." && pwd)"
REPOS="${REPOS:-$HERE/ros2_plus.repos}"
JOBS="${BUILD_JOBS:-$(( $(nproc) / 2 > 0 ? $(nproc) / 2 : 1 ))}"

for tool in vcs rosdep cargo git python3; do
  command -v "$tool" >/dev/null || { echo "install.sh: $tool is missing" >&2; exit 1; }
done
[ -f /opt/ros/jazzy/setup.bash ] || { echo "install.sh: /opt/ros/jazzy is missing" >&2; exit 1; }

mkdir -p "$WS/src"
vcs import --skip-existing "$WS/src" < "$REPOS"

# The ROS setup scripts read unset variables.
set +u
source /opt/ros/jazzy/setup.bash
set -u
# cargo (for zenoh-c) comes from rustup, and Connext is not a supported RMW.
rosdep install --from-paths "$WS/src" --ignore-src --rosdistro jazzy -y \
  --skip-keys "cargo rmw_connextdds"

cd "$WS"
colcon build --base-paths src --symlink-install --parallel-workers "$JOBS" \
  --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo

if [ "${WITH_NUMPY2:-0}" = 1 ]; then
  python3 -m venv --system-site-packages .venv_np2
  .venv_np2/bin/pip install numpy==2.5.4 opencv-python==4.14.0.94 transforms3d==0.4.2
  # cv_bridge built against numpy 1 headers crashes on import under numpy 2. Built against numpy 2
  # headers it runs under both.
  colcon build --base-paths src --symlink-install --packages-select cv_bridge \
    --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    "-DPython3_NumPy_INCLUDE_DIR=$WS/.venv_np2/lib/python3.12/site-packages/numpy/_core/include"
fi

echo "ros2_plus: built in $WS. Run 'source $HERE/env.sh' in each shell."
