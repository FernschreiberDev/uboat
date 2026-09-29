"""Fictional fractured Atlantic island, metres/Y-up. Leaves Coast.obj untouched."""
from pathlib import Path
import math
OUT=Path(__file__).resolve().parents[1]/'Import'/'AtlanticCliffs.obj'
N,SIZE=384,1600.0

def noise(x,y):
    def h(a,b):
        n=(a*374761393+b*668265263+1274126177)&0xffffffff
        n=((n^(n>>13))*1274126177)&0xffffffff
        return (n^(n>>16))/4294967295.0
    a,b=math.floor(x),math.floor(y)
    u,v=x-a,y-b
    u,v=u*u*(3-2*u),v*v*(3-2*v)
    return ((1-u)*h(a,b)+u*h(a+1,b))*(1-v)+((1-u)*h(a,b+1)+u*h(a+1,b+1))*v

def height(x,z):
    # Warp the shore into bays and headlands, then raise an abrupt coastal shelf.
    wx=x+65*(noise(x/180+19,z/180+8)-0.5)
    wz=z+90*(noise(x/240+8,z/240+33)-0.5)
    r=math.hypot(wx/570,wz/325)
    shore=r+0.19*(noise(x/130+1,z/130+8)-0.5)+0.08*math.sin(x/49+z/125)
    shelf=46*math.tanh((0.94-shore)*22)-15
    core=max(0,min(1,(1.13-shore)*3.5))
    ridges=105*math.exp(-((x+180)/230)**2-((z-35)/160)**2)
    ridges+=138*math.exp(-((x-205)/160)**2-((z+40)/175)**2)
    fractured=0
    for scale,amp in [(190,55),(73,30),(25,15),(9,4)]:
        fractured+=(1-abs(2*noise((x+0.27*z)/scale+17,z/scale+41)-1)-0.55)*amp
    gullies=12*abs(math.sin((x+0.38*z)/20+noise(x/80,z/80)*3))
    return shelf+core*(ridges+fractured-gullies)

step=SIZE/N
heights=[[height((i/N-.5)*SIZE,(j/N-.5)*SIZE) for i in range(N+1)] for j in range(N+1)]
with OUT.open('w') as f:
    f.write('# Fictional Atlantic cliffs; metres, Y-up\no AtlanticCliffs\n')
    for j in range(N+1):
        for i in range(N+1):
            x,z=(i/N-.5)*SIZE,(j/N-.5)*SIZE
            dx=(heights[j][min(N,i+1)]-heights[j][max(0,i-1)])/((min(N,i+1)-max(0,i-1))*step)
            dz=(heights[min(N,j+1)][i]-heights[max(0,j-1)][i])/((min(N,j+1)-max(0,j-1))*step)
            length=math.sqrt(1+dx*dx+dz*dz)
            f.write(f'v {x:.4f} {heights[j][i]:.4f} {z:.4f}\nvt {i/N:.6f} {j/N:.6f}\nvn {-dx/length:.6f} {1/length:.6f} {-dz/length:.6f}\n')
    for j in range(N):
        for i in range(N):
            a=j*(N+1)+i+1;b=a+N+1
            for tri in [(a,b,a+1),(a+1,b,b+1)]:
                f.write('f '+' '.join(f'{k}/{k}/{k}' for k in tri)+'\n')
print(f'{OUT}: {(N+1)**2} vertices, {N*N*2} triangles, heights {min(map(min,heights)):.1f}…{max(map(max,heights)):.1f} m')
