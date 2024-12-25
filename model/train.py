from ultralytics import YOLO


IMGSZ = 640


# Load a pretrained YOLO model (recommended for training)
model = YOLO("yolov8n.pt")

results = model.train(data="dataset.yml", epochs=100, imgsz=IMGSZ)

model.predict("./original-images/", save=True, imgsz=IMGSZ)

# success = model.export(format="saved_model")
