import os.path

import cv2

import analyze_card_color
import predict_shape_detection
import predict_utils
from card_model import Shape, Color, Filling, Card


def main(target: str):
    images_dir, image_names = predict_utils.target_to_image_names(target)
    for image_name in image_names:
        image_path = os.path.join(images_dir, image_name)
        card = Card.from_filename(image_name)
        image = cv2.imread(image_path)
        colors = analyze_card_color.analyze_card_color(image)
        if len(colors) == 0:
            print(f'Unable to determine card color for {image_name}')
            continue
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        _, results = predict_shape_detection.run_odt(image_name, gray)
        if len(results) == 0:
            print(f'Unable to detect shapes for {image_name}')
            continue
        shape, filling = results[0]['class_name'].split('-')
        shape = Shape.from_long(shape)
        filling = Filling.from_long(filling)
        color = Color.from_short(colors[0]['color'])
        detected_card = Card(color, shape, filling, len(results))
        if detected_card != card:
            print(f'Detected card {detected_card}, expected {card}, in {image_name}')


if __name__ == '__main__':
    main('output-card-extraction')
    # main('output-card-extraction/set-card-game-real-1-goe3.jpg')
