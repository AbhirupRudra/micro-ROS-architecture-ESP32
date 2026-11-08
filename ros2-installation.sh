#!/bin/bash
set -e

echo "======================================================"
echo "  Automated ROS 2 Jazzy Installation"
echo "======================================================"
echo

echo "[1/5] Updating apt packages..."
sudo apt update && sudo apt upgrade -y
echo "Done."
echo

echo "[2/5] Installing pre-requisites..."
sudo apt install -y software-properties-common curl terminator git
echo "Done."
echo

echo "[3/5] Adding ROS 2 sources and keys..."
sudo add-apt-repository universe -y
export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb
sudo apt update && sudo apt upgrade -y
echo "Done."
echo

echo "[4/5] Installing ROS 2 Jazzy Desktop and Dev Tools..."
sudo apt install -y ros-jazzy-desktop ros-dev-tools
echo "Done."
echo

echo "[5/5] Adding ROS 2 sourcing to ~/.bashrc..."
echo "# Source ROS2 Jazzy, as instructed in https://ros2-tutorial.readthedocs.io" >> ~/.bashrc
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
echo "Done."
echo

echo "======================================================================="
echo "Setup complete!"
echo "Please run 'source ~/.bashrc' or open a new terminal to start using ROS 2."
echo "======================================================================="
