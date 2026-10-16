import sys
from PIL import Image, ImageDraw
src, x0,y0,x1,y1, scale, out = sys.argv[1], *map(int, sys.argv[2:6]), float(sys.argv[6]), sys.argv[7]
step = int(sys.argv[8]) if len(sys.argv)>8 else 20
im = Image.open(src).convert('RGB').crop((x0,y0,x1,y1))
im = im.resize((int(im.width*scale), int(im.height*scale)), Image.LANCZOS)
d = ImageDraw.Draw(im)
for x in range((x0//step+1)*step, x1, step):
    X=(x-x0)*scale; d.line([(X,0),(X,im.height)], fill=(255,0,0) if x%100==0 else (255,120,120), width=1)
    if x%100==0: d.text((X+2,2), str(x), fill=(255,255,0))
for y in range((y0//step+1)*step, y1, step):
    Y=(y-y0)*scale; d.line([(0,Y),(im.width,Y)], fill=(255,0,0) if y%100==0 else (255,120,120), width=1)
    if y%100==0: d.text((2,Y+2), str(y), fill=(255,255,0))
im.save(out)
