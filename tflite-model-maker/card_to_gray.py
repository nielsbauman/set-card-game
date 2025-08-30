import os

import cv2
from PIL import Image

from card_model import Card
from predict_utils import target_to_image_names


def main():
    os.makedirs('output-gray', exist_ok=True)
    images_dir, image_names = target_to_image_names('output-card-extraction')
    seen_cards = set()
    for image_name in image_names:
        card = Card.from_filename(image_name)
        # We don't need to train on every type of card more than once, since we're training on the individual shapes
        # (and their fillings) which will give us plenty of training data.
        if card in seen_cards:
            continue
        seen_cards.add(card)
        image_path = os.path.join(images_dir, image_name)
        image = cv2.imread(image_path)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        Image.fromarray(gray).save(f'output-gray/{image_name}')


if __name__ == '__main__':
    main()
