

# This will plot different values of Lz to show the power-vs-Z curve used in Scanimage5 -- documentation ("Power Controls") shows the equation used here. Lz specifies the exponential length constant for a given beam. Power is increased with depth (z) according to the equation in Ln 27.


import numpy as np
import matplotlib.pyplot as plt
import math


P0 = 20
# Lz = 400
pmax = 80

vol_start = 0
vol_end = 200
step_size = 5

zlevels = np.arange(vol_start, vol_end+step_size, step_size)

# Lz_vals = [1, 5, 10, 25, 50, 100, 150, 200, 250, 300]
Lz_vals = [125, 150, 175, 200, 225, 250, 275, 300, 325, 350]

plt.figure()
for Lz_idx, Lz in enumerate(Lz_vals):
	plevels = []
	for z in zlevels:
		curr_power = P0 * math.exp((float(z) - float(vol_start)) / float(Lz))
		if curr_power > pmax:
			plevels.append(pmax)
		else:
			plevels.append(curr_power)

	plt.subplot(2,5,Lz_idx)
	plt.plot(zlevels, plevels)
	plt.ylim([P0, pmax])
	plt_title = "P0: %i, Lz: %i, %i um volume" % (P0, Lz, vol_end-vol_start)

	plt.title(plt_title)
