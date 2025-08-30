"""
Interactively renames image files in a specified directory based on user input.

This script scans a directory for image files matching the pattern
'set-card-game-real-\d+-\d.jpg'. For each matching file, it displays the
image and prompts the user in the terminal for a new suffix. The script then
renames the file, replacing the last number with the user's input.

Usage:
    python rename_extracted_cards.py <path_to_your_image_directory>
"""
import sys
import os
import re
from PIL import Image


def rename_images_interactively(directory_path: str):
    """
    Iterates through images in a directory, displays each one,
    and renames it based on user input.

    The script targets files with the pattern 'set-card-game-real-d+-d.jpg'.
    It replaces the final number in the filename with the provided user input.

    Args:
        directory_path (str): The path to the folder containing the images.
    """
    # Regex to identify the files you want to process
    file_pattern = re.compile(r'set-card-game-real-\d+-\d\.jpg')

    # Verify the provided path is a valid directory
    if not os.path.isdir(directory_path):
        print(f"❌ Error: Directory not found at '{directory_path}'")
        return

    print(f"✅ Starting image processing in: {directory_path}\n")

    # Get a sorted list of files for predictable order
    image_files = sorted(
        [f for f in os.listdir(directory_path) if file_pattern.match(f)]
    )

    if not image_files:
        print("No matching images found. Please check the filename pattern.")
        return

    for filename in image_files:
        old_filepath = os.path.join(directory_path, filename)

        try:
            # --- 1. Show the image ---
            with Image.open(old_filepath) as img:
                img.show()

            # --- 2. Get user input ---
            prompt = f"Enter new suffix for '{filename}': "
            user_input = input(prompt)

            if not user_input.strip():
                print("Skipping file (no input provided).\n")
                continue

            # --- 3. Construct new name and rename ---
            prefix, _ = filename.rsplit('-', 1)
            extension = ".jpg"

            new_filename = f"{prefix}-{user_input}{extension}"
            new_filepath = os.path.join(directory_path, new_filename)

            # --- ✨ ADDED CHECK ✨ ---
            # Check if the target filename already exists
            if os.path.exists(new_filepath):
                print(f"❌ Error: A file named '{new_filename}' already exists.")
                print("Aborting script to prevent overwriting files.")
                sys.exit(1)  # Exit the script

            # Perform the rename
            os.rename(old_filepath, new_filepath)
            print(f"👍 Renamed: '{filename}' -> '{new_filename}'\n")

        except FileNotFoundError:
            print(f"❓ Error: Could not find file '{old_filepath}'.")
        except Exception as e:
            print(f"An unexpected error occurred with '{filename}': {e}")

    print("🎉 Finished processing all images.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python rename_images.py <path_to_your_image_directory>")
        sys.exit(1)

    image_directory = sys.argv[1]
    rename_images_interactively(image_directory)
