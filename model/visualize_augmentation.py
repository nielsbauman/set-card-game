from pathlib import Path

from PIL import Image

from ultralytics.utils import IterableSimpleNamespace
from ultralytics.data.dataset import YOLODataset

# create dataset config
default_cfg = IterableSimpleNamespace(task='detect', bgr=0., mode='test', model=None, data=None, epochs=100, patience=50, batch=16, imgsz=640, save=True, save_period=-1, cache=False, device=None, workers=8, project=None, name=None, exist_ok=False, pretrained=True, optimizer='auto', verbose=True, seed=0, deterministic=True, single_cls=False, rect=False, cos_lr=False, close_mosaic=10, resume=False, amp=True, fraction=1.0, profile=False, freeze=None, overlap_mask=True, mask_ratio=4, dropout=0.0, val=True, split='val', save_json=False, save_hybrid=False, conf=None, iou=0.7, max_det=300, half=False, dnn=False, plots=True, source=None, show=False, save_txt=False, save_conf=False, save_crop=False, show_labels=True, show_conf=True, vid_stride=1, line_width=None, visualize=False, augment=False, agnostic_nms=False, classes=None, retina_masks=False, boxes=True, format='torchscript', keras=False, optimize=False, int8=False, dynamic=False, simplify=False, opset=None, workspace=4, nms=False, lr0=0.01, lrf=0.01, momentum=0.937, weight_decay=0.0005, warmup_epochs=3.0, warmup_momentum=0.8, warmup_bias_lr=0.1, box=7.5, cls=0.5, dfl=1.5, pose=12.0, kobj=1.0, label_smoothing=0.0, nbs=64, hsv_h=0.015, hsv_s=0.7, hsv_v=0.4, degrees=0.0, translate=0.1, scale=0.5, shear=0.0, perspective=0.0, flipud=0.0, fliplr=0.5, mosaic=1.0, mixup=0.0, copy_paste=0.0, cfg=None, tracker='botsort.yaml', copy_paste_mode='flip')

my_dataset = YOLODataset(
    data={'nc': 3, 'names': ['one', 'three', 'two']},
    img_path="dataset/train/images/",
    imgsz=640,
    hyp=default_cfg,
    batch_size=1
)

augmented_image = next(iter(my_dataset))
Image.fromarray(augmented_image['img'].permute((1,2,0)).numpy())
