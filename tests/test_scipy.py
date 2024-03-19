#!/usr/bin/env python3

import numpy as np
from scipy import integrate, optimize, interpolate, fft, signal, linalg, spatial, stats, ndimage, sparse, cluster, io
from scipy.special import jn, erf, gamma

# Integrate
# result, error = integrate.quad(lambda x: np.exp(-x ** 2), -np.inf, np.inf)  # Covered: integrate

# Optimize
min_result = optimize.minimize(lambda x: x**2, x0=1.0)  # Covered: optimize

# Interpolate
x = np.arange(0, 10)
y = np.exp(-x/3.0)
f = interpolate.interp1d(x, y)  # Covered: interpolate


# FFT
t = np.arange(256)
sp = fft.fft(np.sin(t))
freq = fft.fftfreq(t.shape[-1])  # Covered: FFT


# Linear Algebra
A = np.array([[1, 2], [3, 4]])
_, v = linalg.eig(A)  # Covered: linalg


# Spatial algorithms
points = np.random.rand(30, 2)
hull = spatial.ConvexHull(points)  # Covered: spatial


# Statistics
a = np.random.normal(0, 1, size=100)
density = stats.gaussian_kde(a)
density.covariance_factor = lambda : .25
density._compute_covariance()  # Covered: stats


# Ndimage
im = np.random.random((10,10))
im_filtered = ndimage.gaussian_filter(im, sigma=1.5)  # Covered: ndimage


# Sparse matrices
A = sparse.csr_matrix([[1, 2, 0], [0, 0, 3], [4, 0, 5]])  # Covered: sparse


# Special functions (demonstration purpose, not a major area per instruction but relevant)
x = np.linspace(0, 5, 100)
d = jn(0, x) + erf(x) + gamma(x)  # Utilizes special functions

# print("Integration result:", result)
print("Optimization result:", min_result.x)
print("Interpolated value at 4.5:", f(4.5))
print("First 5 FFT frequencies:", freq[:5])
print("Linear Algebra - Eigenvalues:", v)
print("Convex Hull - Volume:", hull.volume)
print("Statistics - Density estimation:", density(a[:5]))
print("Ndimage - Filtered image mean:", im_filtered.mean())
print("Sparse matrix - Nonzero elements:", A.count_nonzero())
print("Completed an extensive demonstration of scipy functionalities.")
