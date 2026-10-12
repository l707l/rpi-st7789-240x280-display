from PIL import Image

width = 240
height = 280

with open('/home/q/dispmanx.raw', 'rb') as f:
    raw = f.read()

# RGB565 format (16-bit)
img = Image.frombytes('RGB', (width, height), raw, 'raw', 'BGR;16')
img.save('/home/q/dispmanx.png')
print("Successfully converted dispmanx.raw to /home/q/dispmanx.png")
