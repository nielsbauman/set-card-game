import cv2

image_path = "dataset/train/images/b6b027a0-set-card-game.jpg"
label_path = "dataset/train/labels/b6b027a0-set-card-game.txt"
classes_path = "dataset/train/classes.txt"

# Read image
image = cv2.imread(image_path)

# Read labels
with open(label_path, "r") as f:
    labels = f.readlines()
# Read classes
with open(classes_path, "r") as f:
    classes = f.readlines()

# Parse labels
height, width, _ = image.shape
for label in labels:
    class_id, x_center, y_center, bbox_width, bbox_height = map(float, label.split())
    x_min = int((x_center - bbox_width / 2) * width)
    y_min = int((y_center - bbox_height / 2) * height)
    x_max = int((x_center + bbox_width / 2) * width)
    y_max = int((y_center + bbox_height / 2) * height)

    class_name = classes[int(class_id)]

    # Draw box
    cv2.rectangle(image, (x_min, y_min), (x_max, y_max), (0, 255, 0), 2)
    cv2.putText(image, str(class_name), (x_min, y_min - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

# Show image
cv2.imshow("Labeled Image", image)
cv2.waitKey(0)
cv2.destroyAllWindows()

