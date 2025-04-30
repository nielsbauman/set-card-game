import os.path

import tensorflow as tf
from PIL import Image

from predict_utils import preprocess_image, detect_objects, filter_objects_by_overlap, draw_results, \
    target_to_image_names, extract_objects

# Load the TFLite model
interpreter = tf.lite.Interpreter(model_path='model_card_detection.tflite')
interpreter.allocate_tensors()

CLASSES = ['card']
COLORS = [[255, 0, 0]]
DETECTION_THRESHOLD = 0.5
OVERLAP_THRESHOLD = 0.3


def run_odt(image_path):
    """Run object detection on the input image and draw the detection results"""
    # Load the input shape required by the model
    _, input_height, input_width, _ = interpreter.get_input_details()[0]['shape']

    # Load the input image and preprocess it
    preprocessed_image, original_image = preprocess_image(
        image_path,
        (input_height, input_width)
    )

    # Run object detection on the input image
    raw_results = detect_objects(interpreter, CLASSES, preprocessed_image, threshold=DETECTION_THRESHOLD)
    filtered_results = filter_objects_by_overlap(raw_results, OVERLAP_THRESHOLD)
    print(f'Found {len(filtered_results)} ({len(raw_results)} before filtering) objects in {image_path}')

    return original_image, filtered_results


def predict(target: str, save: bool):
    if save:
        output_dir = 'output-card-extraction'
        os.makedirs(output_dir, exist_ok=True)
    images_dir, image_names = target_to_image_names(target)
    for image_name in image_names:
        image_path = os.path.join(images_dir, image_name)
        original_image, results = run_odt(image_path)
        detection_result_image = draw_results(COLORS, original_image, results)
        if save:
            Image.fromarray(detection_result_image).save(f'{output_dir}/{image_name}')
        else:
            Image.fromarray(detection_result_image).show()


def extract(target: str, save: bool):
    if save:
        output_dir = 'output-card-extraction'
        os.makedirs(output_dir, exist_ok=True)
    images_dir, image_names = target_to_image_names(target)
    for image_name in image_names:
        image_path = os.path.join(images_dir, image_name)
        original_image, results = run_odt(image_path)
        extracted_objects = extract_objects(original_image, results)
        for i, extracted_object in enumerate(extracted_objects):
            if save:
                base_image_name = image_name.replace('.jpg', '')
                Image.fromarray(extracted_object).save(f'{output_dir}/{base_image_name}-{i}.jpg')
            else:
                Image.fromarray(extracted_object).show()


if __name__ == '__main__':
    # predict('data-cards/images', True)
    predict('data-cards/images/b0972e8e-set-card-game-real-8.jpg', False)
    # extract('data-cards/images', True)
    # extract('data-cards/images/76f09a9d-set-card-game-real-12.jpg', False)
