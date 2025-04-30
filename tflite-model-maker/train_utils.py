def split(images_dir, annotations_dir, target_dir, fraction):
    train_dir = f'{target_dir}/train'
    test_dir = f'{target_dir}/test'
    if os.path.exists(train_dir) or os.path.exists(test_dir):
        print("Target directory already exists, not splitting")
        return
    train_images = f'{train_dir}/images'
    train_annotations = f'{train_dir}/Annotations'
    os.makedirs(train_images, exist_ok=True)
    os.makedirs(train_annotations, exist_ok=True)
    test_images = f'{test_dir}/images'
    test_annotations = f'{test_dir}/Annotations'
    os.makedirs(test_images, exist_ok=True)
    os.makedirs(test_annotations, exist_ok=True)

    image_paths = os.listdir(images_dir)
    random.shuffle(image_paths)

    threshold = int(len(image_paths) * fraction)
    for i, image_path in enumerate(image_paths):
        if i < threshold:
            shutil.copy(f'{images_dir}/{image_path}', train_images)
            shutil.copy(f'{annotations_dir}/{image_path.replace("jpg", "xml")}', train_annotations)
        else:
            shutil.copy(f'{images_dir}/{image_path}', test_images)
            shutil.copy(f'{annotations_dir}/{image_path.replace("jpg", "xml")}', test_annotations)
