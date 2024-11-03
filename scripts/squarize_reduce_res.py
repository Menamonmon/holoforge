from PIL import Image


def convert_to_square_and_reduce_resolution(image_path, output_path, target_size):
    # Open the image
    img = Image.open(image_path)

    # Get the dimensions of the image
    width, height = img.size

    # Crop the image to make it square
    if width > height:
        left = (width - height) / 2
        right = (width + height) / 2
        img = img.crop((left, 0, right, height))
    else:
        top = (height - width) / 2
        bottom = (height + width) / 2
        img = img.crop((0, top, width, bottom))

    # Resize the image to the target size
    img = img.resize((target_size, target_size), Image.Resampling.LANCZOS)

    # Save the output image
    img.save(output_path)


# Usage
convert_to_square_and_reduce_resolution(
    "/Users/menaf/Downloads/cube.jpg", "./test_data/cube_texture.jpg", target_size=256
)
