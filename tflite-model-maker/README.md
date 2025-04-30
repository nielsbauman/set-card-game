# TFLite model training and utils

This directory mainly contains the python code to train the object detection models.

## Setup

- The required python version is `3.9` (not higher).
  This is due to the `tflite-model-maker` not working with any higher versions.
- You might need to install `libportaudio2` by running `sudo apt install libportaudio2`
- When installing python dependencies from `requirements.txt`,
  you might need the `--use-deprecated=legacy-resolver` flag to resolve the `tflite-model-maker` package.

## Approach

- We train a model (`model_card_detection.tflite`) on a set of images that each contain an arrangement of a few cards.
  This model is purely trained to detect the individual cards as a whole (i.e. just the label `"card"`).
    - Use the command `label-studio` (installed as a python dependency) to start a local server of Label Studio which
      allows labeling images for training purposes. Cards should simply be labeled as `"card"`.
    - Use `train_card_detection.py` to train the model based on data in the `data-images` directory.
      Data has to be in the PASCAL VOC format.
    - To deal with a large range of prediction scores, we set the detection threshold relatively low (`0.5`) but implement
      a post-processing filter. This filter relies on the fact that we know that cards will never overlap in images.
      It checks if there are any overlapping detected objects and discards the object with the lowest score.
- Using this model, we can extract the cards from the image and inspect them one-by-one with greater accuracy.
    - Use `predict_card_detection.py` to run prediction and/or extraction.
      Predication can be run using the `predict` method and allows saving predictions to disk in the form of annotated
      versions of the original image.
      Extraction can be run using the `extract` method and will write each individual detected card to disk in the
      `output-card-extraction` directory. The extracted card images will have to be renamed to include the "code" that
      represents the card in the image, to allow automatic validation in the next steps.
- Now that we have the individual cards, we'll be identifying the card in two separate steps:
    - We determine the color of the card by applying some HSV color range masks using the opencv (`cv2`) library.
        - Use `analyze_card_color.py` to run the color analysis on images
    - We train a model (`model_shape_detection.tflite`) that identifies the shapes and their fillings in the
      _gray scaled_ card image. By removing the color from the image, the detection becomes significantly easier.
      The number of (sufficiently confident) detections will determine the "count" of the card.
      We use overlap filtering here as well for improved accuracy.
        - We need to annotate the training data again using Label Studio.
          We need to label each individual shape with the correct shape-filling combination.
        - Use `train_shape_detection.py` to train the model based on data in the `data-shapes` directory.
          Data has to be in the PASCAL VOC format.
        - Use `predict_shape_detection.py` to run prediction.
    - Use `full_card_detection_validator.py` to validate the combined output of the two steps - using the naming
      structure from the filenames.

