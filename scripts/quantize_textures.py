import sys
from PIL import Image, ImageOps

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: {0} <image to convert>".format(sys.argv[0]))

    else:
        input_fname = sys.argv[1]
        image_in = Image.open(input_fname)
        image_in = image_in.convert("RGB")

        num_colors_out = 32
        w, h = image_in.size
        input_fname_without_ext = input_fname.split(".")[0]
        print(
            f"Reducing {input_fname} of size {w}x{h} to {num_colors_out} unique colors."
				 
        )

        # Take input image and divide each color channel's value by 16
        # preview = image_in.copy()
        image_out = image_in.copy()

        # Palettize the image
        image_out = image_out.convert(mode="P", palette=1, colors=num_colors_out)
        image_out.save(f"{input_fname_without_ext}_preview.png")
        print(f"Output image preview saved at {input_fname_without_ext}_preview.png")
        palette = image_out.getpalette()
        rgb_tuples = [
            tuple(palette[i : i + 3]) for i in range(0, 3 * num_colors_out, 3)
        ]

        # Save pallete
        with open(f"./mem/texture_palette.mem", "w") as f:
			# write the palette out as 565 values
            f.write("\n".join([f"{r:02x}{g:02x}{b:02x}" for r, g, b in rgb_tuples]))

        print("Output image pallete saved at texture_palette.mem")

        # Save the image itself
        with open(f"./mem/texture_image.mem", "w") as f:
            for y in range(h):
                for x in range(w):
                    f.write(f"{image_out.getpixel((x,y)):02x}\n")

        print("Output image saved at texture_image.mem")
