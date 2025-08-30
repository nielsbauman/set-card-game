"""
This script copies and renames image and XML annotation files from a source directory,
removing the random UUID prefix and updating internal XML references accordingly.

This process is non-destructive and does not modify the original files.

Usage:
    1. Run it from the terminal, providing the path to the source directory
       containing your 'Annotations' and 'images' folders.

    Example:
       python rename_remove_identifier.py /path/to/your/dataset
"""
import os
import re
import shutil
import sys

# --- Configuration ---
DEST_DIR_NAME = 'renamed'  # The directory where processed files will be saved
# ---------------------

# Define the regex pattern to capture the random prefix and the rest of the filename
# Group 1: ([a-z0-9]+-) -> The random prefix to be removed
# Group 2: (set-card-game-real-\d+(-[a-z0-9]+)?) -> The base name to keep with an optional suffix
filename_pattern = re.compile(r'([a-z0-9]+-)(set-card-game-real-\d+(-[a-z0-9]+)?)')


def process_files(source_dir):
    """
    Finds, renames, copies, and modifies the annotation and image files.
    """
    # Define source and destination paths based on the input
    source_annotations_dir = os.path.join(source_dir, 'Annotations')
    source_images_dir = os.path.join(source_dir, 'images')
    dest_dir = os.path.join(source_dir, DEST_DIR_NAME)
    dest_annotations_dir = os.path.join(dest_dir, 'Annotations')
    dest_images_dir = os.path.join(dest_dir, 'images')

    # 1. Create destination directories if they don't exist
    print(f"Setting up destination directory: '{dest_dir}'")
    os.makedirs(dest_annotations_dir, exist_ok=True)
    os.makedirs(dest_images_dir, exist_ok=True)

    # Check if source directories exist
    if not os.path.isdir(source_annotations_dir):
        print(f"Error: Source directory '{source_annotations_dir}' not found.")
        return

    print(f"Processing files from '{source_annotations_dir}' and '{source_images_dir}'...")
    processed_count = 0

    # Get a sorted list of files for predictable order
    xml_files = sorted(os.listdir(source_annotations_dir))

    # 2. Iterate through files in the Annotations directory
    for old_xml_name in xml_files:
        if not old_xml_name.endswith('.xml'):
            print(f"  - Skipping '{old_xml_name}' (not an XML file).")
            continue
        match = filename_pattern.match(old_xml_name)
        if not match:
            print(f"  - Skipping '{old_xml_name}' (does not match pattern).")
            continue

        # 3. Determine old and new filenames
        random_identifier = match.group(1)  # e.g., '1be2d382-'
        base_name = match.group(2)  # e.g., 'set-card-game-real-2'

        old_jpg_name = f"{random_identifier}{base_name}.jpg"
        new_jpg_name = f"{base_name}.jpg"

        new_xml_name = f"{base_name}.xml"

        source_xml_path = os.path.join(source_annotations_dir, old_xml_name)
        dest_xml_path = os.path.join(dest_annotations_dir, new_xml_name)

        source_jpg_path = os.path.join(source_images_dir, old_jpg_name)
        dest_jpg_path = os.path.join(dest_images_dir, new_jpg_name)

        # 4. Check if the corresponding image file exists
        if not os.path.exists(source_jpg_path):
            print(f"  - Warning: XML file '{old_xml_name}' has no matching image. Skipping.")
            continue

        # 5. Read XML, replace filename, and write to new location
        try:
            with open(source_xml_path, 'r', encoding='utf-8') as f:
                content = f.read()

            modified_content = content.replace(old_jpg_name, new_jpg_name)

            with open(dest_xml_path, 'w', encoding='utf-8') as f:
                f.write(modified_content)

            # 6. Copy the corresponding image file with the new name
            shutil.copy2(source_jpg_path, dest_jpg_path)

            processed_count += 1

        except Exception as e:
            print(f"  - Error processing '{old_xml_name}': {e}")

    print(f"\n✅ Done! Processed {processed_count} file pairs.")
    print(f"Renamed files are located in the '{dest_dir}' directory.")


if __name__ == "__main__":
    # Check if the user provided exactly one command-line argument
    if len(sys.argv) != 2:
        print("Usage: python rename_script.py <source_directory>")
        sys.exit(1)  # Exit with an error code

    source_path = sys.argv[1]

    # Check if the provided path is a valid directory
    if not os.path.isdir(source_path):
        print(f"Error: Provided path '{source_path}' is not a valid directory.")
        sys.exit(1)

    process_files(source_path)
