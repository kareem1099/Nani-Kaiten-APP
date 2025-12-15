from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import cv2
import numpy as np
from PIL import Image
import io
import torch
import torchvision.transforms as T
from torchvision.models.segmentation import deeplabv3_resnet101
from contextlib import asynccontextmanager

model = None
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ===== Lifespan for model loading =====
@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    model_path = "C:/Users/Kareem/Final_best_model.pth"
    num_classes = 2

    model_local = deeplabv3_resnet101(weights=None, aux_loss=True)
    model_local.classifier[4] = torch.nn.Sequential(
        torch.nn.Conv2d(256, 128, kernel_size=3, padding=1),
        torch.nn.BatchNorm2d(128),
        torch.nn.ReLU(),
        torch.nn.Conv2d(128, num_classes, kernel_size=1)
    )
    model_local.aux_classifier[4] = torch.nn.Conv2d(256, num_classes, kernel_size=1)

    state_dict = torch.load(model_path, map_location=device)
    model_local.load_state_dict(state_dict)
    model_local.to(device)
    model_local.eval()

    model = model_local
    yield  # yield control back to FastAPI app

app = FastAPI(lifespan=lifespan)

# ===== Helper Functions =====
def preprocess_image(image, original_size):
    transform = T.Compose([
        T.Resize((512, 512)),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    resized_tensor = transform(image)
    return resized_tensor.unsqueeze(0).to(device), original_size

def detect_real_corners(contour, w, h):
    contour_image = np.zeros((h, w), dtype=np.uint8)
    cv2.drawContours(contour_image, [contour], -1, 255, 2)

    corners = cv2.goodFeaturesToTrack(contour_image, maxCorners=8, qualityLevel=0.5, minDistance=50)
    if corners is None:
        return []
    # normalize to [0,1]
    return [[float(x)/w, float(y)/h] for [x, y] in corners.reshape(-1, 2)]

def process_frame(frame):
    original_h, original_w = frame.shape[:2]  # احفظ الحجم الأصلي
    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    pil_image = Image.fromarray(frame_rgb)

    input_tensor, _ = preprocess_image(pil_image, (original_w, original_h))
    with torch.no_grad():
        output = model(input_tensor)
        pred_mask = torch.argmax(output['out'], dim=1).squeeze().cpu().numpy()

    binary_mask = (pred_mask == 1).astype(np.uint8) * 255
    contours, _ = cv2.findContours(binary_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    if not contours:
        return {"contour": [], "corners": [], "original_size": [original_w, original_h]}

    main_contour = max(contours, key=cv2.contourArea)

    # Scale الـ contour من 512x512 للـ original size
    scale_x = original_w / 512
    scale_y = original_h / 512
    main_contour_scaled = main_contour.astype(np.float32)
    main_contour_scaled[:, :, 0] *= scale_x  # x coords
    main_contour_scaled[:, :, 1] *= scale_y  # y coords
    main_contour_scaled = main_contour_scaled.astype(np.int32)

    # Normalize بناءً على original size
    contour_points = [[float(x)/original_w, float(y)/original_h] for [x, y] in main_contour_scaled.reshape(-1, 2)]

    # نفس الشيء للـ corners
    corners = detect_real_corners(main_contour_scaled, original_w, original_h)

    return {
        "contour": contour_points,
        "corners": corners,
        "original_size": [original_w, original_h]
    }

# ===== API Endpoints =====
@app.post("/process-video")
async def process_video(file: UploadFile = File(...)):
    if not file.content_type.startswith('video/'):
        raise HTTPException(status_code=400, detail="File must be a video")

    try:
        contents = await file.read()
        video_bytes = io.BytesIO(contents)
        video_bytes.seek(0)

        temp_video = "temp_video.mp4"
        with open(temp_video, "wb") as buffer:
            buffer.write(video_bytes.read())

        cap = cv2.VideoCapture(temp_video)
        ret, frame = cap.read()
        cap.release()

        if not ret:
            raise HTTPException(status_code=400, detail="Could not read video frame")

        result = process_frame(frame)
        return JSONResponse(content=result)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
