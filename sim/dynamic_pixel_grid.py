import matplotlib.pyplot as plt
import matplotlib.animation as anim
import numpy as np


def plot_cont(get_pixels, HRES=320, VRES=180):
	fig = plt.figure()
	ax = fig.add_subplot(111)
	ax.set_xlim(0, HRES)
	ax.set_ylim(0, VRES)

	def update(i):
		ax.clear()
		ax.set_xlim(0, HRES)
		ax.set_ylim(0, VRES)
		# get_pixels returns an np array bitmap for all the pixels that are active

		pixels = get_pixels()
		ax.imshow(pixels, cmap="gray", interpolation="nearest")
	a = anim.FuncAnimation(fig, update, frames=1, repeat=True)
	plt.show()
 

def gen_rand_screen():
	return np.random.randint(0, 2, (180, 320))

plot_cont(gen_rand_screen)