import trimesh
import numpy as np

path = "./test_data/car/model_normalized.obj"


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
        assert isinstance(mesh, trimesh.Trimesh)
        mesh = scene_or_mesh
    return mesh


mesh = as_mesh(trimesh.load(path))

# count the number of faces
num_faces = len(mesh.faces)
print(num_faces)

# trianglulate the mesh
mesh_triangulated = trimesh.geometry.triangulate_quads(mesh.faces)

mesh.faces = mesh_triangulated

print(len(mesh_triangulated))
# take the largest vertex
max_vertex = np.max(mesh.vertices)
print(max_vertex)

min_vertex = np.min(mesh.vertices)
print(min_vertex)


# save a trianglulated version of the mesh as just faces into an obj file called model_normalized.obj
# mesh.export("./test_data/car/model_normalized.obj")
