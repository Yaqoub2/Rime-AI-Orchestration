from fastapi import FastAPI
from pydantic import BaseModel
from typing import List
import base64
import logging
import uvicorn
import os
from dotenv import load_dotenv

# Load .env values
load_dotenv()

HOST = os.getenv("FASTAPI_HOST", "127.0.0.1")
PORT = int(os.getenv("FASTAPI_PORT", "8000"))

app = FastAPI()

#for each object: label and confidence 
class Detection(BaseModel):
    label: str
    confidence: float
#for whole image
class Snapshot(BaseModel):
    timestamp: str
    image: str  # base64-encoded image
    detections: List[Detection]

# Recieve annotated snapshot sent from app.py
@app.post("/upload/")
async def upload(snapshot: Snapshot):
    print(f"Detection at {snapshot.timestamp}")

    for d in snapshot.detections:
        print(f"{d.label} — Confidence: {d.confidence:.2f}")

    print(f"Image size: {len(snapshot.image)} characters (base64)\n")

    return {"status": "received"}

if __name__ == "__main__":
    uvicorn.run("mock_api:app", host=HOST, port=PORT)

