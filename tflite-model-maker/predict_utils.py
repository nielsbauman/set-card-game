import os

import cv2
import numpy as np
import tensorflow as tf


def preprocess_image(image_path, input_size):
    """Preprocess the input image to feed to the TFLite model"""
    img = tf.io.read_file(image_path)
    img = tf.io.decode_image(img, channels=3)
    img = tf.image.convert_image_dtype(img, tf.uint8)
    original_image = img
    resized_img = tf.image.resize(img, input_size)
    resized_img = resized_img[tf.newaxis, :]
    resized_img = tf.cast(resized_img, dtype=tf.uint8)
    return resized_img, original_image


def preprocess_image_from_opencv(cv2_img, input_size):
    """Preprocess the input image to feed to the TFLite model"""
    rgb = cv2.cvtColor(cv2_img, cv2.COLOR_BGR2RGB)
    img = tf.convert_to_tensor(rgb, dtype=tf.uint8)
    original_image = img
    resized_img = tf.image.resize(img, input_size)
    resized_img = resized_img[tf.newaxis, :]
    resized_img = tf.cast(resized_img, dtype=tf.uint8)
    return resized_img, original_image


def detect_objects(interpreter, classes, image, threshold):
    """Returns a list of detection results, each a dictionary of object info."""

    signature_fn = interpreter.get_signature_runner()

    # Feed the input image to the model
    output = signature_fn(images=image)

    # Get all outputs from the model
    count = int(np.squeeze(output['output_0']))
    scores = np.squeeze(output['output_1'])
    class_ids = np.squeeze(output['output_2'])
    boxes = np.squeeze(output['output_3'])

    results = []
    for i in range(count):
        if scores[i] >= threshold:
            result = {
                'bounding_box': boxes[i],
                'class_id': class_ids[i],
                'class_name': classes[int(class_ids[i])],
                'score': scores[i]
            }
            results.append(result)
    return results


def calculate_overlap(rect1, rect2):
    """
    Calculates the ratio of rect1's area that overlaps with rect2.

    Parameters:
    - rect1: list or array of [ymin, xmin, ymax, xmax]
    - rect2: list or array of [ymin, xmin, ymax, xmax]

    Returns:
    - overlap_ratio: float (ratio of rect1's area that overlaps with rect2)
    """
    # Coordinates of the intersection rectangle
    inter_ymin = max(rect1[0], rect2[0])
    inter_xmin = max(rect1[1], rect2[1])
    inter_ymax = min(rect1[2], rect2[2])
    inter_xmax = min(rect1[3], rect2[3])

    # Compute width and height of the intersection
    inter_width = max(0, inter_xmax - inter_xmin)
    inter_height = max(0, inter_ymax - inter_ymin)

    # Area of intersection
    inter_area = inter_width * inter_height

    # Area of rect1
    area1 = (rect1[2] - rect1[0]) * (rect1[3] - rect1[1])

    if area1 == 0:
        return 0.0  # Avoid division by zero if rect1 is degenerate

    # Overlap ratio relative to rect1
    return inter_area / area1


def filter_objects_by_overlap(objects, overlap_threshold):
    """
    Filters out objects that have more than a given overlap percentage with any other object.

    Parameters:
    - objects: list of dicts, each containing 'bounding_box', 'class_id', and 'score'
    - overlap_threshold: float, percentage above which an object will be filtered out

    Returns:
    - filtered_objects: list of dicts, objects with no high-overlap neighbors
    """
    keep = [True] * len(objects)

    for i in range(len(objects)):
        if not keep[i]:
            continue  # Already marked for removal

        box_i = objects[i]['bounding_box']

        for j in range(i + 1, len(objects)):
            if not keep[j]:
                continue  # Already marked for removal

            box_j = objects[j]['bounding_box']
            overlap_i = calculate_overlap(box_i, box_j)
            overlap_j = calculate_overlap(box_j, box_i)

            if overlap_i > overlap_threshold or overlap_j > overlap_threshold:
                if objects[i]['score'] > objects[j]['score']:
                    keep[j] = False  # Keep i, remove j
                else:
                    keep[i] = False  # Keep j, remove i
                    break  # No need to check i further, it’s removed

    filtered_objects = [obj for obj, k in zip(objects, keep) if k]
    return filtered_objects


def draw_results(colors, original_image, results):
    # Plot the detection results on the input image
    original_image_np = original_image.numpy().astype(np.uint8)
    for obj in results:
        # Convert the object bounding box from relative coordinates to absolute
        # coordinates based on the original image resolution
        ymin, xmin, ymax, xmax = obj['bounding_box']
        xmin = int(xmin * original_image_np.shape[1])
        xmax = int(xmax * original_image_np.shape[1])
        ymin = int(ymin * original_image_np.shape[0])
        ymax = int(ymax * original_image_np.shape[0])

        # Find the class index of the current object
        class_id = int(obj['class_id'])

        # Draw the bounding box and label on the image
        color = [int(c) for c in colors[class_id]]
        cv2.rectangle(original_image_np, (xmin, ymin), (xmax, ymax), color, 8)
        # Make adjustments to make the label visible for all objects
        y = ymin - 15 if ymin - 15 > 15 else ymin + 15
        label = "{}: {:.0f}%".format(obj['class_name'], obj['score'] * 100)
        cv2.putText(original_image_np, label, (xmin, y),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, color, 2)
    # Return the final image
    original_uint8 = original_image_np.astype(np.uint8)
    return original_uint8


def extract_objects(original_image, objects):
    results = []
    original_image_np = original_image.numpy().astype(np.uint8)
    for obj in objects:
        # Convert the object bounding box from relative coordinates to absolute
        # coordinates based on the original image resolution
        ymin, xmin, ymax, xmax = obj['bounding_box']
        xmin = int(xmin * original_image_np.shape[1])
        xmax = int(xmax * original_image_np.shape[1])
        ymin = int(ymin * original_image_np.shape[0])
        ymax = int(ymax * original_image_np.shape[0])

        cropped = original_image_np[ymin:ymax, xmin:xmax]
        results.append(cropped)

    return results


def target_to_image_names(target: str) -> tuple[str, list[str]]:
    if os.path.isdir(target):
        images = os.listdir(target)
        images.sort()
        return target, images
    else:
        return os.path.dirname(target), [os.path.basename(target)]
