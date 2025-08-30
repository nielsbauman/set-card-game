import os.path

import numpy as np
import tensorflow as tf
from PIL import Image

from card_model import Card
from predict_utils import preprocess_image, detect_objects, filter_objects_by_overlap, draw_results, \
    target_to_image_names, preprocess_image_from_opencv

# Load the TFLite model
interpreter = tf.lite.Interpreter(model_path='model_shape_detection.tflite')
interpreter.allocate_tensors()

CLASSES = [
    'oval-empty', 'oval-filled', 'oval-partial',
    'rhombus-empty', 'rhombus-filled', 'rhombus-partial',
    'wave-empty', 'wave-filled', 'wave-partial',
]
COLORS = np.random.randint(0, 255, size=(len(CLASSES), 3), dtype=np.uint8)
DETECTION_THRESHOLD = 0.3
OVERLAP_THRESHOLD = 0.3


def run_odt(image_name, opencv_image=None):
    """Run object detection on the input image and draw the detection results"""
    # Load the input shape required by the model
    _, input_height, input_width, _ = interpreter.get_input_details()[0]['shape']

    # Load the input image and preprocess it
    input_size = (input_height, input_width)
    preprocessed_image, original_image = preprocess_image(image_name, input_size) \
        if opencv_image is None else preprocess_image_from_opencv(opencv_image, input_size)

    # Run object detection on the input image
    raw_results = detect_objects(interpreter, CLASSES, preprocessed_image, threshold=DETECTION_THRESHOLD)
    filtered_results = filter_objects_by_overlap(raw_results, OVERLAP_THRESHOLD)
    # print(f'Found {len(filtered_results)} ({len(raw_results)} before filtering) objects in {image_name}')
    if len(set([x['class_id'] for x in filtered_results])) > 1:
        print(f'Found more than one class in {image_name}, {filtered_results}')

    return original_image, filtered_results


def predict(target: str, save: bool, show: bool):
    if save:
        output_dir = 'output-shape-detection'
        os.makedirs(output_dir, exist_ok=True)
    images_dir, image_names = target_to_image_names(target)
    for image_name in image_names:
        image_path = os.path.join(images_dir, image_name)
        card = Card.from_filename(image_name)
        original_image, results = run_odt(image_path)
        found_class = CLASSES[int(results[0]['class_id'])]
        if len(results) != card.count or found_class != f'{card.shape.to_long()}-{card.filling.to_long()}':
            print(f'Found mismatch in {image_path}, expected {card}, found class {found_class}, results ({len(results)} {results}')
        detection_result_image = draw_results(COLORS, original_image, results)

        if save:
            Image.fromarray(detection_result_image).save(f'{output_dir}/{image_name}')
        elif show:
            Image.fromarray(detection_result_image).show()


if __name__ == '__main__':
    # predict('data/images', True)
    predict('data-shapes/images/set-card-game-real-11-rre3.jpg', False, True)
