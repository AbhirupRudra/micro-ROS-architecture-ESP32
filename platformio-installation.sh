#!/bin/bash
set -e

echo "======================================================"
echo "  Automated VS Code & PlatformIO Installation"
echo "======================================================"
echo

echo "[1/7] Updating apt package list..."
sudo apt update
echo "Done."
echo

echo "[2/7] Installing the latest version of VS Code..."
# Using snap is the officially recommended and easiest way to get the latest stable VS Code on Ubuntu
sudo apt install -y snapd
sudo snap install --classic code
echo "Done."
echo

echo "[3/7] Setting up Python3 virtual environment..."
# Ensuring python3-venv is installed before trying to create a venv
sudo apt install -y python3-venv
python3 -m venv ~/.platformio/venv
echo "Done."
echo

echo "[4/7] Upgrading pip in the PlatformIO virtual environment..."
~/.platformio/venv/bin/pip install --upgrade pip
echo "Done."
echo

echo "[5/7] Installing PlatformIO..."
~/.platformio/venv/bin/pip install platformio
echo "PlatformIO version installed:"
~/.platformio/venv/bin/pio --version
echo "Done."
echo

echo "[6/7] Adding PlatformIO to your PATH in ~/.bashrc..."
# Checking if it's already in the bashrc to avoid duplicates
if ! grep -q 'export PATH="$HOME/.platformio/venv/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.platformio/venv/bin:$PATH"' >> ~/.bashrc
fi
echo "Done."
echo

echo "[7/7] Verifying global PlatformIO access (in local script context)..."
# source doesn't export to the parent terminal, so we temporarily export it here for the script
export PATH="$HOME/.platformio/venv/bin:$PATH"
pio --version
echo "Done."
echo

echo "======================================================================="
echo "Setup complete!"
echo "======================================================================="
echo
echo "IMPORTANT NEXT STEPS:"
echo "-----------------------------------------------------------------------"
echo "1. Apply the PATH updates to your current terminal by running:"
echo "   source ~/.bashrc"
echo ""
echo "2. Launch VS Code by typing 'code' in your terminal or opening it"
echo "   from your application menu."
echo ""
echo "3. Install the PlatformIO Extension in VS Code:"
echo "   - Press 'Ctrl + Shift + X' to open the Extensions view."
echo "   - Search for 'PlatformIO IDE'."
echo "   - Click 'Install' on the official extension by PlatformIO."
echo "   - Wait for it to finish installing its internal dependencies."
echo "======================================================================="
