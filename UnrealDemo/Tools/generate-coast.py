"""Deterministic fictional rocky island; OBJ in metres, Y up (matching submarine)."""
from pathlib import Path
import math

OUT = Path(__file__).resolve().parents[1] / 'Import' / 'Coast.obj'
N = 256
SIZE = 1800.0

def noise(x, y):
    def h(a, b):
        n = (a * 374761393 + b * 668265263 + 1274126177) & 0xffffffff
        n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
        return (n ^ (n >> 16)) / 4294967295.0
    a, b = math.floor(x), math.floor(y)
    u, v = x-a, y-b
    u, v = u*u*(3-2*u), v*v*(3-2*v)
    return ((1-u)*h(a,b)+u*h(a+1,b))*(1-v)+((1-u)*h(a,b+1)+u*h(a+1,b+1))*v

def height(x, z):
    ridge = sum((noise(x/s+17,z/s+31)-0.5)*a for s,a in [(380,65),(140,28),(55,13),(19,5),(7,1.8)])
    r = math.sqrt((x/540)**2+(z/330)**2)
    shore = r + 0.12*math.sin(z/95)+0.07*math.sin(x/66)
    shelf = 42 * math.tanh((0.9-shore)*8)
    peak = 76*math.exp(-((x-90)/280)**2-((z+35)/165)**2)
    return shelf + peak + ridge*max(0,1-min(1,shore/1.8)) - 10

with OUT.open('w') as f:
    f.write('# Fictional rocky Atlantic island; metres, Y up\no Coast\n')
    for j in range(N+1):
        z = (j/N-0.5)*SIZE
        for i in range(N+1):
            x = (i/N-0.5)*SIZE
            y = height(x,z)
            dx, dz = (height(x+1,z)-height(x-1,z))/2, (height(x,z+1)-height(x,z-1))/2
            length = math.sqrt(dx*dx+dz*dz+1)
            f.write(f'v {x:.4f} {y:.4f} {z:.4f}\nvt {i/N:.6f} {j/N:.6f}\nvn {-dx/length:.6f} {1/length:.6f} {-dz/length:.6f}\n')
    for j in range(N):
        for i in range(N):
            a = j*(N+1)+i+1
            b = a+N+1
            for tri in [(a,b,a+1),(a+1,b,b+1)]:
                f.write('f '+' '.join(f'{k}/{k}/{k}' for k in tri)+'\n')
print(OUT)
