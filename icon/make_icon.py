from PIL import Image, ImageDraw, ImageFilter
S=2048  # supersample canvas, final 1024
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
img=Image.new("RGBA",(S,S),(0,0,0,0))
m=int(S*0.098); w=S-2*m; r=int(w*0.225)
# background gradient
bg=Image.new("RGBA",(w,w))
px=bg.load()
c1=(18,26,48); c2=(10,92,110)
for y in range(w):
    for x in range(w):
        t=(x*0.35+y*0.65)/w
        px[x,y]=lerp(c1,c2,t)+(255,)
mask=Image.new("L",(w,w),0)
ImageDraw.Draw(mask).rounded_rectangle([0,0,w-1,w-1],radius=r,fill=255)
# drop shadow
sh=Image.new("RGBA",(S,S),(0,0,0,0))
ImageDraw.Draw(sh).rounded_rectangle([m,m+int(S*0.012),m+w,m+w+int(S*0.012)],radius=r,fill=(0,0,0,110))
sh=sh.filter(ImageFilter.GaussianBlur(S*0.012))
img=Image.alpha_composite(img,sh)
img.paste(bg,(m,m),mask)
# waveform bars
heights=[0.18,0.34,0.52,0.74,0.46,0.62,0.30,0.16]
n=len(heights); bw=w*0.070; gap=w*0.040
total=n*bw+(n-1)*gap
x0=m+(w-total)/2; cy=m+w*0.5
glow=Image.new("RGBA",(S,S),(0,0,0,0))
bars=Image.new("RGBA",(S,S),(0,0,0,0))
gd=ImageDraw.Draw(glow); bd=ImageDraw.Draw(bars)
for i,h in enumerate(heights):
    x=x0+i*(bw+gap); hh=w*h
    box=[x,cy-hh/2,x+bw,cy+hh/2]
    gd.rounded_rectangle(box,radius=bw/2,fill=(70,230,210,200))
    t=i/(n-1)
    col=lerp((120,255,220),(90,200,255),t)
    bd.rounded_rectangle(box,radius=bw/2,fill=col+(255,))
glow=glow.filter(ImageFilter.GaussianBlur(S*0.018))
img=Image.alpha_composite(img,glow)
img=Image.alpha_composite(img,bars)
# status dot bottom-right
d=ImageDraw.Draw(img)
dr=w*0.055; dx=m+w*0.82; dy=m+w*0.82
d.ellipse([dx-dr*1.5,dy-dr*1.5,dx+dr*1.5,dy+dr*1.5],fill=(10,24,40,255))
d.ellipse([dx-dr,dy-dr,dx+dr,dy+dr],fill=(80,235,130,255))
# top gloss
gl=Image.new("RGBA",(w,w),(0,0,0,0))
gp=gl.load()
for y in range(int(w*0.5)):
    a=int(38*(1-y/(w*0.5)))
    for x in range(w): gp[x,y]=(255,255,255,a)
glm=Image.new("RGBA",(S,S),(0,0,0,0)); glm.paste(gl,(m,m),mask)
img=Image.alpha_composite(img,glm)
img=img.resize((1024,1024),Image.LANCZOS)
img.save("icon1024.png")
img.save("NavidromeControl.icns",format="ICNS",sizes=[(16,16),(32,32),(64,64),(128,128),(256,256),(512,512),(1024,1024)])
print("ok")
