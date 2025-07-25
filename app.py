import cv2
from ultralytics import YOLO
import time
import redis
import base64
import json
from datetime import datetime
import requests
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Use environment variables
VIDEO_DEVICE = os.getenv("VIDEO_DEVICE", "/dev/video10")
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))
FASTAPI_HOST = os.getenv("FASTAPI_HOST", "127.0.0.1")
FASTAPI_PORT = os.getenv("FASTAPI_PORT", "8000")
API_URL = f"http://{FASTAPI_HOST}:{FASTAPI_PORT}/upload/"

# Connect to Redis
r = redis.Redis(host= REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)

# take stream from Camera
cap = cv2.VideoCapture(VIDEO_DEVICE)
if not cap.isOpened():
    print(f"Cannot open video device: {VIDEO_DEVICE}")
    exit()

# Load model: YOLO8 nano is lightweight and fast
model = YOLO("yolov8n.pt")

## main loop: read frame then annotate it and send the copy to redis and fastAPI
while True:
    ret, frame = cap.read()
    if not ret:
        print("Can't receive frame. Exiting...")
        break

    # Run YOLO
    results = model(frame)
    boxes = results[0].boxes
    # only send if YOLO detected objects
    if boxes is not None and len(boxes) > 0:
        # Draw annotations on a copy of the frame
        annotated = results[0].plot()

        # Encode annotated frame to JPEG → base64
        _, buffer = cv2.imencode('.jpg', annotated)
        jpg_base64 = base64.b64encode(buffer).decode('utf-8')

        # Extract labels & confidences
        detections = []
        for box in boxes:
            cls_id = int(box.cls[0])
            label = model.names[cls_id]
            conf = float(box.conf[0])
            detections.append({"label": label, "confidence": round(conf, 3)})

        # Create JSON payload
        data = {
            "timestamp": datetime.utcnow().isoformat(),
            "image": jpg_base64,
            "detections": detections
        }

        # Save to Redis
        r.set("last_detection", json.dumps(data))
        
        
        # Send to FastAPI
        try:
            response = requests.post(API_URL , json=data)
            if response.status_code == 200:
                print("Sent to API")
            else:
                print("API error:", response.status_code)
        except Exception as e:
            print("Failed to send to API:", e)


cap.release()
cv2.destroyAllWindows()

