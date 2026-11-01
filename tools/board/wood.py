# 선 없는 나무 무늬 판 배경 이미지를 만든다. 외부 이미지 없이 무작위 잡음으로 나무결을 그린다.
# 사용: python wood.py [시드, 기본 7]
# 결과: out/wood.png 와 선·기물을 올린 미리보기 out/preview.png (preview.py)
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

from preview import make_preview

root = Path(__file__).resolve().parent
out_dir = root / 'out'

# 판 배경 크기. 가로 8칸 x 세로 9칸에 여백을 더한 비율(약 9:10)이다.
width = 2048
height = 2276

# 나무 바탕색과 결 색.
base_color = (238, 200, 128)
fiber_color = (176, 124, 66)
grain_color = (140, 88, 40)
highlight_color = (250, 224, 165)


def noise(rng, size, out_size, blur):
    """작은 무작위 잡음을 out_size로 늘리고 흐린 흑백 이미지."""
    small = Image.frombytes('L', size, rng.randbytes(size[0] * size[1]))
    big = small.resize(out_size, Image.BICUBIC)
    if blur:
        big = big.filter(ImageFilter.GaussianBlur(blur))
    return big


def warp(image, rng, amplitude, period):
    """가로줄마다 x를 조금씩 밀어 나무결을 물결치게 한다."""
    pad = amplitude * 2
    padded = Image.new(image.mode, (image.width + pad * 2, image.height))
    padded.paste(image, (pad, 0))
    padded.paste(image.crop((0, 0, pad, image.height)), (image.width + pad, 0))
    padded.paste(image.crop((image.width - pad, 0, image.width, image.height)), (0, 0))
    phase = rng.random() * math.tau
    phase2 = rng.random() * math.tau
    result = Image.new(image.mode, image.size)
    band = 2
    for y in range(0, image.height, band):
        shift = amplitude * (0.7 * math.sin(y / period + phase) + 0.3 * math.sin(y / (period * 0.37) + phase2))
        x = pad + round(shift)
        result.paste(padded.crop((x, y, x + image.width, y + band)), (0, y))
    return result


def stretch_contrast(image, low, high):
    """low~high 밝기를 0~255로 늘린다."""
    return image.point(lambda v: max(0, min(255, round((v - low) * 255 / (high - low)))))


def tint(base, color, mask, strength):
    """mask가 밝은 곳일수록 base 위에 color를 strength만큼 덮는다."""
    layer = Image.new('RGB', base.size, color)
    return Image.composite(layer, base, mask.point(lambda v: round(v * strength)))


def make_wood(seed):
    rng = random.Random(seed)
    size = (width, height)
    image = Image.new('RGB', size, base_color)

    # 판 전체의 큰 얼룩. 밝은 곳과 어두운 곳이 넓게 퍼진다.
    patches = stretch_contrast(noise(rng, (5, 6), size, 120), 90, 170)
    image = tint(image, highlight_color, patches, 0.55)
    image = tint(image, fiber_color, ImageChops.invert(patches), 0.12)

    # 세로로 길게 늘어진 가는 섬유결.
    fibers = noise(rng, (900, 14), size, 1.2)
    fibers = warp(fibers, rng, 18, 260)
    image = tint(image, fiber_color, stretch_contrast(fibers, 120, 200), 0.22)

    # 나이테처럼 이어지는 진한 결. 부드러운 잡음의 등고선을 선으로 뽑는다.
    rings_src = noise(rng, (60, 5), size, 6)
    rings_src = warp(rings_src, rng, 40, 340)
    rings = rings_src.point(lambda v: 255 - min(255, (v % 22) * 60) if v % 22 < 5 else 0)
    rings = rings.filter(ImageFilter.GaussianBlur(1.6))
    image = tint(image, grain_color, rings, 0.30)

    # 아주 고운 표면 잡티로 평평한 색감을 없앤다.
    speckle = noise(rng, (width // 2, height // 2), size, 0.6)
    image = tint(image, fiber_color, stretch_contrast(speckle, 150, 255), 0.06)
    return image


def main():
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    out_dir.mkdir(parents=True, exist_ok=True)
    wood = make_wood(seed)
    wood.save(out_dir / 'wood.png', optimize=True)
    make_preview(wood).save(out_dir / 'preview.png')
    print(out_dir / 'wood.png')


if __name__ == '__main__':
    main()
