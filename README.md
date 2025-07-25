# Rime-AI-Orchestration
An Edge AI Surveillance system that captures video from a virtual webcam (via v4l2loopback and ffmpeg), runs object detection using YOLOv8, and forwards the results to a mock FastAPI server while caching the latest detection snapshot in Redis.
