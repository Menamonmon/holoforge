from matplotlib.animation import FuncAnimation
import numpy as np
import matplotlib.pyplot as plt


def plot_camera_on_sphere_animatable(initial_r, initial_phi, initial_theta):
    """
    Animatable 3D visualization of a camera on a sphere with adjustable r, phi, and theta.

    Parameters:
    - initial_r: Initial radius of the sphere.
    - initial_phi: Initial azimuthal angle of the camera in radians (0 ≤ phi < 2π).
    - initial_theta: Initial polar angle of the camera in radians (0 ≤ theta ≤ π).
    """
    # Create a figure and 3D axis
    fig = plt.figure(figsize=(10, 8))
    ax = fig.add_subplot(111, projection="3d")

    # Sphere coordinates
    u_sphere = np.linspace(0, 2 * np.pi, 100)
    v_sphere = np.linspace(0, np.pi, 100)
    x_sphere = np.outer(np.cos(u_sphere), np.sin(v_sphere))
    y_sphere = np.outer(np.sin(u_sphere), np.sin(v_sphere))
    z_sphere = np.outer(np.ones_like(u_sphere), np.cos(v_sphere))
    ax.plot_surface(
        x_sphere,
        y_sphere,
        z_sphere,
        color="lightblue",
        alpha=0.6,
        edgecolor="w",
        zorder=1,
    )

    # Initial camera position and vectors
    r, phi, theta = initial_r, initial_phi, initial_theta

    # Function to update the visualization
    def update(frame):
        nonlocal r, phi, theta
        ax.clear()

        # Sphere redraw
        ax.plot_surface(
            r * x_sphere,
            r * y_sphere,
            r * z_sphere,
            color="lightblue",
            alpha=0.6,
            edgecolor="w",
            zorder=1,
        )

        # Update camera position
        C = np.array(
            [
                r * np.sin(theta) * np.cos(phi),
                r * np.sin(theta) * np.sin(phi),
                r * np.cos(theta),
            ]
        )

        # Compute basis vectors
        n = C / np.linalg.norm(C)  # Forward vector
        arbitrary = np.array([0, 0, 1]) if np.abs(n[2]) < 0.9 else np.array([1, 0, 0])
        u = np.cross(arbitrary, n)
        u /= np.linalg.norm(u)  # Right vector
        v = np.cross(n, u)  # Up vector

        # Scale for visualizing the vectors
        scale = r * 0.3

        # Plot camera center and vectors
        ax.scatter(
            C[0], C[1], C[2], color="red", s=100, label="Camera Center (C)", zorder=3
        )
        ax.quiver(
            C[0],
            C[1],
            C[2],
            u[0],
            u[1],
            u[2],
            color="green",
            length=scale,
            label="u (right)",
            normalize=True,
        )
        ax.quiver(
            C[0],
            C[1],
            C[2],
            v[0],
            v[1],
            v[2],
            color="blue",
            length=scale,
            label="v (up)",
            normalize=True,
        )
        ax.quiver(
            C[0],
            C[1],
            C[2],
            n[0],
            n[1],
            n[2],
            color="orange",
            length=scale,
            label="n (forward)",
            normalize=True,
        )

        # Update plot limits, labels, and title
        ax.set_xlim([-r, r])
        ax.set_ylim([-r, r])
        ax.set_zlim([-r, r])
        ax.set_xlabel("X-axis")
        ax.set_ylabel("Y-axis")
        ax.set_zlabel("Z-axis")
        ax.set_title("Camera on a Sphere with Basis Vectors")
        ax.legend(loc="upper left")

        # Animate changes in r, phi, theta
        phi += 0.05  # Slowly rotate azimuthally
        theta += 0.02  # Change polar angle slightly
        if phi > 2 * np.pi:
            phi -= 2 * np.pi
        if theta > np.pi:
            theta -= np.pi

    # Create an animation
    ani = FuncAnimation(fig, update, frames=360, interval=30, repeat=True)

    plt.show()


# Example usage
plot_camera_on_sphere_animatable(
    initial_r=5.0, initial_phi=np.pi / 4, initial_theta=np.pi / 3
)
