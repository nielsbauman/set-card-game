import os

# Define file paths
classes_file_path = "dataset/train/classes.txt"
labels_dir_path = "dataset/train/labels/"

# Read all class names from the file
with open(classes_file_path, 'r') as f:
    class_names = [line.strip() for line in f.readlines()]

# Set to collect unique class names used
used_class_names = set()

# Iterate over all files in the labels directory
for filename in os.listdir(labels_dir_path):
    file_path = os.path.join(labels_dir_path, filename)

    # Ensure we are working with a file
    if not os.path.isfile(file_path):
        continue

    # Read and process the file
    with open(file_path, 'r') as label_file:
        for line in label_file:
            # Split the line into floats and get the first one
            values = line.strip().split()
            if not values:
                continue

            # Convert the first value to an int and retrieve the class name
            try:
                class_index = int(values[0])
                class_name = class_names[class_index]
                used_class_names.add(class_name)
                print(class_name)
            except (ValueError, IndexError) as e:
                print(f"Error processing line '{line.strip()}': {e}")

# Print all unique class names used
print("\nUnique class names used:")
print("['" + "','".join(used_class_names) + "']")
print(len(used_class_names))

