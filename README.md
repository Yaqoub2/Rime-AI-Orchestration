# Rime-AI-Orchestration

An end-to-end Edge AI surveillance system that takes a video feed, performs real-time object detection using YOLOv8, and streams results to Redis and a FastAPI backend. Built for easy deployment and self-healing with systemd + cron.

## 🚀 Features

- **Virtual Webcam via `v4l2loopback` or Real Webcam**
- **Feed video using `ffmpeg` for headless servers instead of `OBS`**
- **YOLOv8-nano real-time detection on frames**
- **Saves base64 images to Redis on detection**
- **Sends detection metadata to FastAPI mock API**
- **Runs as systemd services with watchdog cron job**
- **Auto restart on failure or reboot**

## 🧱 Project Structure

```
Rime-AI-Orchestration/
├── app.py              # Main inference app (YOLOv8 + Redis + FastAPI client)
├── mock_api.py         # FastAPI server to receive detections
├── requirements.txt    # Python dependencies
├── sample.mp4          # Sample video file used as input stream
├── .env                # Configuration (Redis, API, video device)
├── setup.sh            # One-click setup script (installs + enables all)
└── watchdog.sh         # Cron-based service watchdog
```

## ⚙️ Quickstart (Ubuntu preferably 22.04)

1. **Clone the repository**

```bash
git clone https://github.com/yaqoub2/Rime-AI-Orchestration.git
cd Rime-AI-Orchestration
```

2. **Make the setup script executable**

```bash
chmod +x setup.sh
```

3. **Run the setup**

```bash
./setup.sh
```

> 'That’s it. Everything is installed and running as services!'

`setup.sh` will put project in path: `/opt/Rime-AI-Orchestration`

## 🔄 System Workflow

### 1. Virtual Camera Setup
- `v4l2loopback` creates `/dev/video10`
- `ffmpeg` loops and feeds `sample.mp4` into it
#### for Real camera: 
-  change `VIDEO_DEVICE` in `.env` to your camera usually `/dev/video0`
-  and restart `app.py` service
```bash
sudo systemctl restart yolo-app.service
```

### 2. Services Started by `setup.sh`
- `redis-server` runs in background
- `virtualcam.service` load v4l2loopback to `/dev/video10` and take stream from `ffmpeg`
- `mock-api.service` launches a FastAPI server
- `yolo-app.service` reads from `VIDEO_DEVICE`, detects objects via YOLOv8n
- Saves each detection (base64 snapshot + metadata) to Redis
- Sends detection to FastAPI via POST

### 3. Auto-Restart
- All above services run with `systemd`
- `watchdog.sh` is scheduled via `cron` every minute to ensure they stay alive

## 🧪 How to Test It Works

- Open a terminal and run:

```bash
redis-cli get last_detection
```

- You should see a JSON object with:
  - base64 image
  - detection metadata
- You’ll also see console logs from the mock API and `app.py`:

```bash
journalctl -u mock-api.service -f
journalctl -u yolo-app.service -f
```

## 🔧 Configuration (`.env`)

```env
VIEDO_DEVICE=/dev/video10
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
FASTAPI_HOST=127.0.0.1
FASTAPI_PORT=8000
```

> You can change the input device or ports(`Redis` needs to be changed first in redis-server config) if needed.

## 🐞 Watchdog via Cron

`watchdog.sh` is scheduled every minute via `cron`, and will:
- Restart services if killed
- Keep your pipeline always-on

## 📦 Dependencies

All listed in [`requirements.txt`](./requirements.txt):

- `ultralytics` (YOLOv8)
- `opencv-python`
- `redis`, `fastapi`, `requests`
- `python-dotenv`, `uvicorn`

Installed automatically by `setup.sh` as well as `apt` packages.

## 📸 Powered by:

- [YOLOv8n](https://docs.ultralytics.com/) – Real-time lightweight detection
- [FFmpeg](https://ffmpeg.org/) – Feed any video as webcam
- [Redis](https://redis.io/) – Shared detection store
- [FastAPI](https://fastapi.tiangolo.com/) – Mock API backend
- [Systemd + Cron] – Auto-start and recovery

## 📁 Logs & Monitoring

To check logs for each service:

```bash
journalctl -u yolo-app.service -f
journalctl -u mock-api.service -f
journalctl -u virtualcam.service -f
```
 exit with ctrl + c

## 🛠️ Want to Customize?

Replace `sample.mp4` with your own video just make sure its name is `sample.mp4`, or edit `.env` to connect to real `/dev/video0` device (e.g., webcam).

## 📌 Notes

- Tested on Ubuntu 22.04 with Python 3.10+
- Used `ffmpeg` for feeding video instead of `OBS` which requires GUI
- Make sure `/dev/video10` is not in use by another process
- You may need to unload and load the `v4l2loopback` module manually if setup fails

## ⚖️ Scalability & Expansion 
- **Multi-Camera Support:** Use multiple instances of `app.py` (or implement multithreading) to handle different `/dev/video*` sources and separate Redis keys/databases.  
- **Multi-Branch:** Each branch or site can run its own stack and forward detections to a central API endpoint.  
- **Containerization:** Package the app, Redis, and FastAPI into containers for easy deployment using Docker,.deb or Ansible-playbook.  
- **Cloud Forwarding:** Replace mock_api.py with a real-time cloud ingestion pipeline (e.g., MQTT, Kafka, or cloud functions).  
- **Storage:** Add cloud or local disk storage for permenant storing of annotated snapshots.  
<br>
    
### **Built for**&nbsp;&nbsp;&nbsp;<img width="128" height="22" alt="image" src="https://github.com/user-attachments/assets/a6a4e585-9a87-4c6b-a0f2-de7e5ed3d050" />
