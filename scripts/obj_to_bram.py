from normalize_obj_file import parse_obj_file, normalize_vertices, save_normalized_obj
import os
from PIL import Image
import sys

NTEXTURE_COLOR_SPACE = 1 << 8  # initially 2^8 unique colors can be adjust later

MAX_COLOR_IDX = 1 << 8  # max color index allowed by bram

TEXTURE_SIZE = 128  # reduced texture size


def obj_to_bram(obj_folder_path, out_folder_path):
    # Parse the obj file
    obj_file = os.path.join(obj_folder_path, "model.obj")
    texture_file = os.path.join(obj_folder_path, "texture.jpg")
    vertices, normals, textures_points, faces = parse_obj_file(obj_file)

    # read the texture file
    texture = Image.open(texture_file)
    texture = texture.convert("RGB")
    texture = texture.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.Resampling.LANCZOS)
    texture = texture.convert(mode="P", palette=1, colors=NTEXTURE_COLOR_SPACE)
    texture.save(f"{obj_folder_path}/texture_compressed_preview.png")

    texture_map_size = TEXTURE_SIZE * TEXTURE_SIZE * 8  # 8 bits per pixel

    # make a map of color idx to 565 rgb values
    palette = texture.getpalette()
    rgb_tuples = [
        tuple(palette[i : i + 3]) for i in range(0, 3 * NTEXTURE_COLOR_SPACE, 3)
    ]

    # write the palette out as 565 values
    with open(f"{out_folder_path}/texture_palette.mem", "w") as f:
        for r, g, b in rgb_tuples:
            r = r >> 3
            g = g >> 2
            b = b >> 3
            rgb565 = (r << 11) | (g << 5) | b
            f.write(f"{rgb565:04x}\n")

    texture_palette_bram_width = 16
    texture_palette_bram_height = len(rgb_tuples)
    texture_palette_bram_size = texture_palette_bram_width * texture_palette_bram_height
    print(
        f"texture_palette.mem BRAM size: {texture_palette_bram_width}x{texture_palette_bram_height}={texture_palette_bram_size}bits"
    )

    # Save the image itself
    with open(f"{out_folder_path}/texture_image.mem", "w") as f:
        for y in range(TEXTURE_SIZE):
            for x in range(TEXTURE_SIZE):
                f.write(f"{texture.getpixel((x, y)):02x}\n")

    texture_image_bram_width = 8
    texture_image_bram_height = TEXTURE_SIZE * TEXTURE_SIZE
    texture_image_bram_size = texture_image_bram_width * texture_image_bram_height
    print(
        f"texture_image.mem BRAM size: {texture_image_bram_width}x{texture_image_bram_height}={texture_image_bram_size} bits"
    )

    # Save the vertices
    normalized_vertices = normalize_vertices(vertices)
    save_normalized_obj(
        obj_file, normalized_vertices, f"{obj_folder_path}/model_normalized.obj"
    )
    # since it's normalized we conver the floating point to fixed point binary between -1 and 1 (16 bits)
    vertices_bram_width = (
        72 * 3
    )  # (x,y,z) (16, 16, 16) * 3 + (xn, yn, zn) (16, 16, 16) * 1 + 24 bits of color idx (8, 8, 8)
    vertices_bram_height = len(normalized_vertices)

    with open(f"{out_folder_path}/mesh.mem", "w") as f:
        with open(f"{out_folder_path}/normal_color_lookup.mem", "w") as f2:
            for face in faces:
                v1, v2, v3 = [normalized_vertices[i[0] - 1] for i in face]
                norm = normals[face[0][2] - 1]
                c1, c2, c3 = [
                    vt_to_rgb(textures_points[i[1] - 1], texture) for i in face
                ]
                vertex_line, norm_color_line = triangle_line(
                    v1, v2, v3, norm, c1, c2, c3
                )
                f.write(vertex_line)
                f2.write(norm_color_line)

    vertices_bram_size = vertices_bram_width * vertices_bram_height

    print(
        f"vertices.mem BRAM size: {vertices_bram_width}x{vertices_bram_height}={vertices_bram_size} bits"
    )

    print(
        f"TOTAL BRAM USED: {(vertices_bram_size + texture_image_bram_size + texture_palette_bram_size) / (1024 * 1024):10f} Mbits"
    )

    print("Done!")


def triangle_line(v1, v2, v3, norm, c1, c2, c3):
    v1 = [
        floating_to_fixed_point(v1[0], 1, -1),
        floating_to_fixed_point(v1[1], 1, -1),
        floating_to_fixed_point(v1[2], 1, -1),
    ]
    v2 = [
        floating_to_fixed_point(v2[0], 1, -1),
        floating_to_fixed_point(v2[1], 1, -1),
        floating_to_fixed_point(v2[2], 1, -1),
    ]
    v3 = [
        floating_to_fixed_point(v3[0], 1, -1),
        floating_to_fixed_point(v3[1], 1, -1),
        floating_to_fixed_point(v3[2], 1, -1),
    ]
    norm = [
        floating_to_fixed_point(norm[0], 1, -1),
        floating_to_fixed_point(norm[1], 1, -1),
        floating_to_fixed_point(norm[2], 1, -1),
    ]
    # 72 * 3 / 4 = 54 hexes
    return (
        f"{v1[0]:04x}{v1[1]:04x}{v1[2]:04x}{v2[0]:04x}{v2[1]:04x}{v2[2]:04x}{v3[0]:04x}{v3[1]:04x}{v3[2]:04x}",
        f"{norm[0]:04x}{norm[1]:04x}{norm[2]:04x}{c1:02x}{c2:02x}{c3:02x}\n",
    )


def vt_to_rgb(vt, texture):
    x, y = vt
    imgx = min(int(x * texture.width), texture.width - 1)
    imgy = min(int((1 - y) * texture.height), texture.height - 1)
    return texture.getpixel((imgx, imgy))


def floating_to_fixed_point(fnum, fmax, fmin):
    return int((fnum - fmin) * (1 << 16) / (fmax - fmin))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: {0} <obj folder path> <output folder path>".format(sys.argv[0]))
    else:
        obj_folder_path = sys.argv[1]
        out_folder = sys.argv[2]
        obj_to_bram(obj_folder_path, out_folder)
