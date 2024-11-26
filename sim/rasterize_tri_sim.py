import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from matplotlib.lines import Line2D
import numpy as np
import sys
import asyncio
from concurrent.futures import ThreadPoolExecutor
from utils import *


class DraggableTriangle:
	def __init__(self, ax, vertices, vertex_change_callback=None):
		self.ax = ax
		self.vertices = vertices
		self.dragging_point = None

		# Create the triangle polygon
		self.polygon = Polygon(
			vertices, closed=True, edgecolor="blue", fill=False, linewidth=2
		)
		self.ax.add_patch(self.polygon)

		# Create draggable points for vertices
		self.points = [
			self.ax.plot(v[0], v[1], "ro", markersize=8, picker=True)[0]
			for v in vertices
		]

		# Connect events
		self.cid_press = self.ax.figure.canvas.mpl_connect(
			"button_press_event", self.on_press
		)
		self.cid_release = self.ax.figure.canvas.mpl_connect(
			"button_release_event", self.on_release
		)
		self.cid_motion = self.ax.figure.canvas.mpl_connect(
			"motion_notify_event", self.on_motion
		)
		self.cid_press = self.ax.figure.canvas.mpl_connect(
			"button_press_event", self.on_press
		)
		self.vertex_change_callback = vertex_change_callback

		# Initialize the asyncio event loop and thread pool
		self.loop = asyncio.get_event_loop()
		self.executor = ThreadPoolExecutor()


	def on_press(self, event):
		"""Check if a vertex is clicked."""
		if event.inaxes != self.ax:
			return
		for i, point in enumerate(self.points):
			contains, _ = point.contains(event)
			if contains:
				self.dragging_point = i
				break

	def on_release(self, event):
		"""Stop dragging."""
		self.dragging_point = None
		# Call the async callback in the event loop
		if self.vertex_change_callback:
			# Use the executor to run the async function safely in the loop
			self.loop.run_in_executor(self.executor, self.run_callback)

	def on_motion(self, event):
		"""Move the vertex if dragging."""
		if self.dragging_point is None or event.inaxes != self.ax:
			return

		# Update the position of the dragged point
		self.vertices[self.dragging_point] = (event.xdata, event.ydata)

		self.points[self.dragging_point].set_xdata([event.xdata])
		self.points[self.dragging_point].set_ydata([event.ydata])

		self.polygon.set_xy(self.vertices)
		self.ax.figure.canvas.draw()

	def run_callback(self):
		"""Run the async callback method."""
		asyncio.run(self.vertex_change_callback(self.vertices.copy()))

	def close_plot(self, event):
		"""Close the plot if 'q' is pressed."""
		if event.key == 'q':  # Check if the pressed key is 'q'
			plt.close(self.ax.figure)



class Triangle:
	def __init__(self, vw, vh, vertex_change_callback=None):
		fig, ax = plt.subplots()

		ax.set_xlim(0, vw)
		ax.set_ylim(0, vh)
		ax.set_aspect("equal", adjustable="box")
		ax.grid(True, linestyle="--", linewidth=0.5)

		# Initial triangle vertices
		initial_vertices = generate_triangle_fast(vw, vh)
		tri = DraggableTriangle(ax, initial_vertices, vertex_change_callback)
		plt.connect("motion_notify_event", tri.on_motion)
		plt.connect("button_press_event", tri.on_press)
		plt.connect("button_release_event", tri.on_release)
		fig.canvas.mpl_connect('key_press_event', tri.close_plot)
		self.ax = ax
		self.triangle = tri
		self.vw = vw
		self.vh = vh

	def show(self):
		plt.show()

	def vertices(self):
		return self.triangle.vertices


def main():

	# make this program a command line argument that takes viewport height and width
	args = sys.argv[1:]
	if len(args) != 2:
		print("Usage: python rasterize_tri_sim.py <viewport_width> <viewport_height>")
		sys.exit(1)

	vw = int(args[0])
	vh = int(args[1])

	triangle = Triangle(vw, vh)
	triangle.show()


if __name__ == "__main__":
	main()
