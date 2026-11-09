# Source in each shell after ros2_plus/install.sh:
#
#   source ros2_plus/env.sh [numpy2]
#
# It loads /opt/ros/jazzy, the workspace that holds this clone and the colcon cargo extensions that
# a later colcon build needs for the Rust packages. With "numpy2" it also activates the numpy 2
# virtual environment that WITH_NUMPY2=1 install.sh created. ROS2_PLUS_WS and ROS2_PLUS_COLCON_EXT
# override the workspace and the extension directory.
_ros2_plus_ws="${ROS2_PLUS_WS:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
_ros2_plus_ext="${ROS2_PLUS_COLCON_EXT:-$_ros2_plus_ws/colcon_ext}"
source /opt/ros/jazzy/setup.bash
# Missing only before the first build.
[ -f "$_ros2_plus_ws/install/setup.bash" ] && source "$_ros2_plus_ws/install/setup.bash"
export PATH="$HOME/.cargo/bin:$_ros2_plus_ext/bin:$PATH"
export PYTHONPATH="$_ros2_plus_ext${PYTHONPATH:+:$PYTHONPATH}"
# The cargo and cargo_workspace rules would claim the root Cargo.toml of flux and orma and hide
# their ament packages. ament_cargo (rclrs) stays on.
export COLCON_EXTENSION_BLOCKLIST=colcon_core.package_identification.cargo:colcon_core.package_identification.cargo_workspace
if [ "${1:-}" = numpy2 ]; then
  if [ -f "$_ros2_plus_ws/.venv_np2/bin/activate" ]; then
    source "$_ros2_plus_ws/.venv_np2/bin/activate"
    # Node entry points start with #!/usr/bin/python3, so the environment also goes in PYTHONPATH.
    export PYTHONPATH="$VIRTUAL_ENV/lib/python3.12/site-packages:$PYTHONPATH"
  else
    echo "ros2_plus/env.sh: no .venv_np2, run WITH_NUMPY2=1 ros2_plus/install.sh" >&2
  fi
fi
unset _ros2_plus_ws _ros2_plus_ext
