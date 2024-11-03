import numpy as np
import argparse


def parse_obj_file(obj_file_path):
    vertices = []

    with open(obj_file_path, "r") as obj_file:
        for line in obj_file:
            if line.startswith("v "):  # Vertex line
                _, x, y, z = line.split()
                vertices.append([float(x), float(y), float(z)])

    return np.array(vertices)


def normalize_vertices(vertices):
    # Step 1: Find the bounding box
    min_coords = vertices.min(axis=0)
    max_coords = vertices.max(axis=0)

    # Step 2: Calculate the center and scale factor
    center = (min_coords + max_coords) / 2
    scale = 1.0 / (max_coords - min_coords).max()  # Scale to fit in 1x1x1 cube

    # Step 3: Normalize vertices
    normalized_vertices = (vertices - center) * scale

    return normalized_vertices


def save_normalized_obj(obj_file_path, normalized_vertices, output_file_path):
    with open(obj_file_path, "r") as obj_file, open(
        output_file_path, "w"
    ) as output_file:
        vertex_index = 0
        for line in obj_file:
            if line.startswith("v "):  # Replace vertex lines
                x, y, z = normalized_vertices[vertex_index]
                output_file.write(f"v {x:.6f} {y:.6f} {z:.6f}\n")
                vertex_index += 1
            else:
                output_file.write(line)  # Copy non-vertex lines as-is


# make this into a cli script that takes in an input obj path and an output obj path

args = argparse.ArgumentParser()
args.add_argument("--input", type=str, required=True)
args.add_argument("--output", type=str, required=True)

args = args.parse_args()

vertices = parse_obj_file(args.input)
normalized_vertices = normalize_vertices(vertices)
save_normalized_obj(args.input, normalized_vertices, args.output)

# Run the script with the following command:
# python normalize_obj_file.py --input input.obj --output output.obj
