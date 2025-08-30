import os

import cv2
import numpy as np

from card_model import Card
from predict_utils import target_to_image_names


def analyze_card_color(card_image):
    """
    Analyzes the colors present in the shapes of a card image.

    Args:
        card_image (numpy.ndarray): The image of a single card.

    Returns:
        list: A list of colors detected in the shapes (e.g., ['red', 'green', 'purple']).
              Returns an empty list if no dominant shape color is found.
    """

    hsv_image = cv2.cvtColor(card_image, cv2.COLOR_BGR2HSV)
    height, width, _ = card_image.shape

    # Define HSV color ranges for red, green, and purple
    # These ranges might need fine-tuning based on your specific card colors and lighting
    lower_red = np.array([0, 100, 100])
    upper_red = np.array([10, 255, 255])
    lower_red2 = np.array([167, 100, 100])
    upper_red2 = np.array([180, 255, 255])
    lower_green = np.array([30, 50, 30])
    upper_green = np.array([90, 255, 255])
    lower_purple = np.array([110, 35, 20])
    upper_purple = np.array([165, 255, 255])

    color_masks = {
        'r': cv2.inRange(hsv_image, lower_red, upper_red) + cv2.inRange(hsv_image, lower_red2, upper_red2),
        'g': cv2.inRange(hsv_image, lower_green, upper_green),
        'p': cv2.inRange(hsv_image, lower_purple, upper_purple)
    }

    detected_colors = []
    color_threshold_percentage = 0.01  # Minimum percentage of card area for a color to be considered

    for color, mask in color_masks.items():
        color_pixel_count = cv2.countNonZero(mask)
        if color_pixel_count > (height * width * color_threshold_percentage):
            detected_colors.append({'color': color, 'count': color_pixel_count / (height * width) * 100})

    detected_colors.sort(key=lambda x: x['count'], reverse=True)

    return detected_colors


if __name__ == '__main__':
    images_dir, image_names = target_to_image_names('output-card-extraction/set-card-game-real-5-rwf2.jpg')
    for image_name in image_names:
        card = Card.from_filename(image_name)
        image_path = os.path.join(images_dir, image_name)
        image = cv2.imread(image_path)
        colors = analyze_card_color(image)
        print(f"Detected shape colors in {image_path}: {colors}")
        if len(colors) == 0 or colors[0]['color'] != str(card.color):
            print(f'{image_name} has color {colors}')
