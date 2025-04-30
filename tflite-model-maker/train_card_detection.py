import tensorflow as tf
from tflite_model_maker import model_spec
from tflite_model_maker import object_detector

from train_utils import split

assert tf.__version__.startswith('2')

tf.get_logger().setLevel('ERROR')
from absl import logging

logging.set_verbosity(logging.ERROR)

spec = model_spec.get('efficientdet_lite0')

# split('data/images', 'data/Annotations', target_dir='data', fraction=0.8)

label_map = ['card']
train_dir = 'data-cards'
test_dir = 'data-cards'
train_data = object_detector.DataLoader.from_pascal_voc(
    images_dir=f'{train_dir}/images',
    annotations_dir=f'{train_dir}/Annotations',
    label_map=label_map,
)
validation_data = object_detector.DataLoader.from_pascal_voc(
    images_dir=f'{test_dir}/images',
    annotations_dir=f'{test_dir}/Annotations',
    label_map=label_map,
)

model = object_detector.create(
    train_data,
    model_spec=spec,
    batch_size=8,
    train_whole_model=True,
    validation_data=validation_data,
    epochs=50,
)
model.export(export_dir='.', tflite_filename='model_card_detection.tflite')
