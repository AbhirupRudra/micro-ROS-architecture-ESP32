#!/bin/bash
set -e

echo "======================================================"
echo "  Automated Docker Setup & Micro-ROS Agent Runner"
echo "======================================================"
echo

echo "[1/5] Updating apt package list..."
sudo apt update
echo "Done."
echo

echo "[2/5] Enabling and starting Docker service..."
sudo systemctl enable --now docker
echo "Done."
echo

echo "[3/5] Adding current user ($USER) to the 'docker' group..."
sudo usermod -aG docker "$USER"
echo "Current Docker version:"
docker --version
echo "Done."
echo

echo "[4/5] Pulling the microros/micro-ros-agent:jazzy image..."
sg docker -c "docker pull microros/micro-ros-agent:jazzy"
echo "Done."
echo

echo "[5/5] Running the micro-ROS agent container interactively..."
sg docker -c "docker run -it --rm --net=host microros/micro-ros-agent:jazzy udp4 --port 8888 -v6"
echo "Done."
echo
echo "Docker setup and execution finished."
