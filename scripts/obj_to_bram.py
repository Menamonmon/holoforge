from normalize_obj_file import parse_obj_file, normalize_vertices, save_normalized_obj
import os
from PIL import Image
import sys
import numpy as np
from FixedPoint import FXfamily, FXnum

import trimesh


def as_mesh(scene_or_mesh):
    """
    Convert a possible scene to a mesh.

    If conversion occurs, the returned mesh has only vertex and face data.
    """
    if isinstance(scene_or_mesh, trimesh.Scene):
        if len(scene_or_mesh.geometry) == 0:
            mesh = None  # empty scene
        else:
            # we lose texture information here
            mesh = trimesh.util.concatenate(
                tuple(
                    trimesh.Trimesh(vertices=g.vertices, faces=g.faces)
                    for g in scene_or_mesh.geometry.values()
                )
            )
    else:
        assert isinstance(scene_or_mesh, trimesh.Trimesh)
        mesh = scene_or_mesh
    return mesh


NTEXTURE_COLOR_SPACE = 1 << 8  # initially 2^8 unique colors can be adjust later

MAX_COLOR_IDX = 1 << 8  # max color index allowed by bram

TEXTURE_SIZE = 128  # reduced texture size

normfam = FXfamily(14, 2)


def normalize_mesh(mesh):
    """
    Normalize a triangle mesh by centering it at the origin and scaling it to fit within a unit sphere.

    Parameters:
    - mesh (trimesh.Trimesh): The input mesh to normalize.

    Returns:
    - trimesh.Trimesh: The normalized mesh.
    """
    # Step 1: Center the mesh at the origin
    center = mesh.centroid  # Get the centroid (center of the bounding box)
    mesh.apply_translation(-center)  # Translate the mesh so its center is at the origin

    # Step 2: Scale the mesh to fit within a unit sphere
    extents = mesh.bounds[1] - mesh.bounds[0]  # Get the extents of the mesh
    max_extent = max(extents)  # Find the largest extent

    # Scale factor to fit the mesh into a unit sphere
    scale_factor = 1.0 / max_extent

    # Apply scaling
    mesh.apply_scale(scale_factor)

    return mesh


def obj_to_bram(obj_folder_path, out_folder_path):
    # Parse the obj file
    # read obj file using trimesh

    obj_file = os.path.join(obj_folder_path, "model.obj")
    # texture_file = os.path.join(obj_folder_path, "texture.jpg")
    # vertices, normals, textures_points, faces = parse_obj_file(obj_file)
    # print(faces)
    mesh = trimesh.load(obj_file, process=False)
    mesh = as_mesh(mesh)
    mesh = normalize_mesh(mesh)
    mesh.fix_normals(False)
    faces = mesh.faces
    vertices = mesh.vertices
    normals = mesh.face_normals

    # Save the vertices
    # save the mesh
    mesh.export(f"{obj_folder_path}/model_normalized.obj")
    normalized_vertices = vertices
    for vertex in normalized_vertices:
        assert abs(np.linalg.norm(vertex)) <= 1

    # since it's normalized we conver the floating point to fixed point binary between -1 and 1 (16 bits)
    vertices_bram_width = (
        72 * 3
    )  # (x,y,z) (16, 16, 16) * 3 + (xn, yn, zn) (16, 16, 16) * 1 + 24 bits of color idx (8, 8, 8)
    vertices_bram_height = len(normalized_vertices)

    with open(f"{out_folder_path}/mesh.mem", "w") as f:
        with open(f"{out_folder_path}/normal_color_lookup.mem", "w") as f2:
            for face, normal in zip(faces, normals):
                print("f", face)
                print("n", normal)
                v1, v2, v3 = [normalized_vertices[i] for i in face]
                # norm = normals[face[0][2] - 1]
                # norm = norm / np.linalg.norm(norm)
                # print("NORMAL", norm)
                # c1, c2, c3 = [
                # 	vt_to_rgb(textures_points[i[1] - 1], texture) for i in face
                # ]

                vertex_line, norm_color_line = triangle_line(
                    v1, v2, v3, normal, 0, 0, 0
                )
                f.write(vertex_line)
                f2.write(norm_color_line)

    vertices_bram_size = vertices_bram_width * vertices_bram_height

    print(
        f"vertices.mem BRAM size: {vertices_bram_width}x{vertices_bram_height}={vertices_bram_size} bits"
    )

    # print(
    # 	f"TOTAL BRAM USED: {(vertices_bram_size + texture_image_bram_size + texture_palette_bram_size) / (1024 * 1024):10f} Mbits"
    # )

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
    # return (
    #     f"{v1[0]:04x}{v1[1]:04x}{v1[2]:04x}{v2[0]:04x}{v2[1]:04x}{v2[2]:04x}{v3[0]:04x}{v3[1]:04x}{v3[2]:04x}\n",
    #     f"{norm[0]:04x}{norm[1]:04x}{norm[2]:04x}{c1:02x}{c2:02x}{c3:02x}\n",
    # )
    return (
        f"{v3[2]}{v3[1]}{v3[0]}{v2[2]}{v2[1]}{v2[0]}{v1[2]}{v1[1]}{v1[0]}\n",
        f"{c3:02x}{c2:02x}{c1:02x}{norm[2]}{norm[1]}{norm[0]}\n",
    )


def vt_to_rgb(vt, texture):
    x, y = vt
    imgx = min(int(x * texture.width), texture.width - 1)
    imgy = min(int((1 - y) * texture.height), texture.height - 1)
    return texture.getpixel((imgx, imgy))


def floating_to_fixed_point(fnum, x, y):
    assert fnum <= 1 and fnum >= -1
    result = normfam(fnum).toBinaryString(1).replace(".", "")
    assert len(result) == 16
    # convert result from bits to hex
    result = hex(int(result, 2))[2:].zfill(4)
    assert len(result) == 4
    return result


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: {0} <obj folder path> <output folder path>".format(sys.argv[0]))
    else:
        obj_folder_path = sys.argv[1]
        out_folder = sys.argv[2]
        print(f"Converting {obj_folder_path} to BRAM format")
        obj_to_bram(obj_folder_path, out_folder)

        # load the file and remesh
        # mesh = remesh_to_low_poly(sys.argv[1])
        # mesh.export(file_obj=sys.argv[2])
