#!/bin/bash

set -e  # Exit on any error

echo "[0/7] Detecting current user and choosing directory..."

# Detect original (non-root) user even if run with sudo
if [ "$EUID" -eq 0 ]; then
    ORIGINAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
else
    ORIGINAL_USER=$USER
fi
echo "Installing services under user: $ORIGINAL_USER"

# Define target path
PROJECT_DIR="/opt/Rime-AI-Orchestration"
# Move if necessary
if [[ "$PWD" != "$PROJECT_DIR" ]]; then
    echo "Moving project to $PROJECT_DIR..."
    sudo mkdir -p "$PROJECT_DIR"
    sudo cp -r . "$PROJECT_DIR"
    cd "$PROJECT_DIR"
else
    echo "Already in correct directory: $PWD"
fi
# change ownership to current user
sudo chown -R "$ORIGINAL_USER" "$PROJECT_DIR"
# sample video for virtual cam
SAMPLE_VIDEO="$PROJECT_DIR/sample.mp4"

echo "[1/7] Updating APT packages..."
sudo apt update && sudo apt upgrade -y

echo "[2/7] Installing system dependencies..."
sudo apt install -y python3 python3-venv python3-pip redis-server ffmpeg build-essential linux-headers-$(uname -r)

echo "[2.1] Installing v4l2loopback-dkms..."

# Clean up any broken install if it exists
sudo dpkg --purge --force-all v4l2loopback-dkms 2>/dev/null || true
sudo rm -f /var/crash/v4l2loopback-dkms.0.crash 2>/dev/null || true

# Detect current kernel version (e.g., 6.8.0-64-generic)
KERNEL_MAJOR=$(uname -r | cut -d. -f1)
KERNEL_MINOR=$(uname -r | cut -d. -f2)

# Use GitHub if kernel >= 6.8
if { [ "$KERNEL_MAJOR" -eq 6 ] && [ "$KERNEL_MINOR" -ge 8 ]; }; then
    echo "Detected kernel $KERNEL_MAJOR.$KERNEL_MINOR — using GitHub build for v4l2loopback..."

    cd /tmp
    if [ -d "v4l2loopback" ]; then
        echo "Removing old v4l2loopback directory..."
        rm -rf v4l2loopback
    fi

    git clone https://github.com/umlaeute/v4l2loopback.git
    cd v4l2loopback
    make
    sudo make install
    echo "v4l2loopback installed from source"
    cd "$PROJECT_DIR"
else
    echo "Detected kernel $KERNEL_MAJOR.$KERNEL_MINOR — using APT for v4l2loopback..."
    sudo apt install -y v4l2loopback-dkms
    echo "v4l2loopback-dkms installed via APT"
fi

# loading v4l2loopback
echo "Loading v4l2loopback module to dev/video10..."
sudo modprobe v4l2loopback devices=1 video_nr=10 card_label="VirtualCam" exclusive_caps=1

echo "[3/7] Creating Python virtual environment..."
python3 -m venv .venv
source .venv/bin/activate

echo "[4/7] Installing Python packages from requirements.txt..."
pip install --upgrade pip
pip install -r requirements.txt

echo "[5/7] Enabling and starting Redis server..."
sudo systemctl enable redis-server
sudo systemctl start redis-server

echo "[6/7] creating systemd service files..."

# Virtual cam service
sudo tee /etc/systemd/system/virtualcam.service > /dev/null <<EOF
[Unit]
Description=VirtualCam via v4l2loopback and FFmpeg
After=network.target

[Service]
ExecStartPre=/sbin/modprobe v4l2loopback devices=1 video_nr=10 card_label="VirtualCam" exclusive_caps=1
ExecStart=/usr/bin/ffmpeg -stream_loop -1 -re -i $SAMPLE_VIDEO -f v4l2 /dev/video10
Restart=always
RestartSec=5
User=$ORIGINAL_USER

[Install]
WantedBy=multi-user.target
EOF

# Mock API service
sudo tee /etc/systemd/system/mock-api.service > /dev/null <<EOF
[Unit]
Description=YOLO FastAPI Mock API Server
After=network.target

[Service]
Type=simple
User=$ORIGINAL_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/.venv/bin/python3 mock_api.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# YOLO app service
sudo tee /etc/systemd/system/yolo-app.service > /dev/null <<EOF
[Unit]
Description=YOLO Edge AI Surveillance App
After=network.target redis-server.service mock-api.service
Requires=redis-server.service mock-api.service virtualcam.service

[Service]
Type=simple
User=$ORIGINAL_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/.venv/bin/python3 app.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[7/7] Enabling on reboot and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable virtualcam.service
sudo systemctl enable mock-api.service
sudo systemctl enable yolo-app.service
sudo systemctl start virtualcam.service
sleep 2
sudo systemctl start mock-api.service
sudo systemctl start yolo-app.service

echo "Setup complete. Services are running:"
systemctl status virtualcam.service --no-pager
systemctl status mock-api.service --no-pager
systemctl status yolo-app.service --no-pager

echo "[8/8] Setting up watchdog cron job..."
# make script exceutable
chmod +x "$PROJECT_DIR/watchdog.sh"
# Install cron job in root's crontab (to run as root, no sudo needed inside watchdog script)
sudo bash -c "(crontab -l 2>/dev/null | grep -Fv '$PROJECT_DIR/watchdog.sh' ; echo '* * * * * $PROJECT_DIR/watchdog.sh') | crontab -"

echo "Watchdog cron job installed in root's crontab. It will run every minute."
