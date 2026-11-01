# 투명 배경 기물 이미지 한 장(2줄 x 7개)을 기물별 PNG로 자른다.
# 사용: python crop.py <원본 이미지> [재질 이름, 기본 wood]
# 결과: out/<재질>/<진영>_<기물>.png 와 미리보기 out/<재질>/preview.png
# 원본 배치: 윗줄 한(漢 車 馬 象 士 包 兵), 아랫줄 초(楚 車 馬 象 士 包 卒)
import sys
from pathlib import Path

from PIL import Image

out_root = Path(__file__).resolve().parent / 'out'

# PNG 한 변의 픽셀 크기. generate.mjs와 같게 맞춘다.
png_size = 256

# 장군 너비가 캔버스에서 차지하는 비율. generate.mjs의 바깥 테두리 지름(88%)과 같다.
general_width_ratio = 0.88

# 원본 한 줄의 기물 순서와 크기 비율(장군 1.0 기준). generate.mjs와 같다.
pieces = [
    ('general', 1.0),
    ('chariot', 0.84),
    ('horse', 0.84),
    ('elephant', 0.84),
    ('guard', 0.68),
    ('cannon', 0.84),
    ('soldier', 0.68),
]
sides = ['han', 'cho']

# 이 값 이하의 알파는 배경으로 보고 기물 위치 찾기와 결과 이미지에서 뺀다.
# 원본 가장자리 근처에 1px짜리 희미한 점이 흩어져 있어서 너무 낮게 잡으면 점이 기물로 잡힌다.
alpha_threshold = 32

# 기물끼리 나눌 때 쓰는 알파 기준. 기물이 붙어 있어도 반투명 가장자리끼리만 닿아 있으면 이 기준으로 떨어진다.
split_alpha = 128

# 나눈 구간을 바깥으로 넓히는 최대 픽셀. split_alpha 아래의 반투명 가장자리를 살리려고 쓴다.
edge_margin = 4

# 이보다 좁은 구간은 기물이 아닌 잡티로 보고 버린다.
min_piece_size = 20

# 원본 기물 안쪽이 알파 250 전후로 약간 비쳐서, 이 값 이상은 완전 불투명으로 바꾼다.
opaque_alpha = 240


def find_segments(flags):
    """True가 min_piece_size 이상 이어지는 구간을 (시작, 끝) 목록으로 돌려준다."""
    segments = []
    start = None
    for i, flag in enumerate(flags):
        if flag and start is None:
            start = i
        if not flag and start is not None:
            segments.append((start, i))
            start = None
    if start is not None:
        segments.append((start, len(flags)))
    return [(s, e) for s, e in segments if e - s >= min_piece_size]


def widen_segments(segments, length):
    """구간을 edge_margin만큼 넓히되 이웃 구간과의 가운데를 넘지 않게 한다."""
    widened = []
    for i, (start, end) in enumerate(segments):
        low = (segments[i - 1][1] + start) // 2 if i > 0 else 0
        high = (end + segments[i + 1][0]) // 2 if i + 1 < len(segments) else length
        widened.append((max(start - edge_margin, low), min(end + edge_margin, high)))
    return widened


def find_piece_boxes(image):
    """줄마다 기물의 bbox 목록을 찾는다."""
    alpha = image.getchannel('A')
    px = alpha.load()
    width, height = image.size
    rows = find_segments([any(px[x, y] > split_alpha for x in range(width)) for y in range(height)])
    rows = widen_segments(rows, height)
    boxes = []
    for top, bottom in rows:
        cols = find_segments([any(px[x, y] > split_alpha for y in range(top, bottom)) for x in range(width)])
        cols = widen_segments(cols, width)
        row_boxes = []
        for left, right in cols:
            # 줄 높이 안에서 이 기물만의 실제 위아래 범위를 다시 잡는다.
            piece = alpha.crop((left, top, right, bottom))
            l, t, r, b = piece.point(lambda v: 255 if v > alpha_threshold else 0).getbbox()
            row_boxes.append((left + l, top + t, left + r, top + b))
        boxes.append(row_boxes)
    return boxes


def make_piece(image, box, scale):
    """기물 하나를 잘라 크기 비율에 맞춰 정사각 캔버스 가운데에 놓는다."""
    piece = image.crop(box)
    r, g, b, a = piece.split()
    a = a.point(lambda v: 255 if v >= opaque_alpha else (0 if v <= alpha_threshold else v))
    piece = Image.merge('RGBA', (r, g, b, a))

    target_width = round(png_size * general_width_ratio * scale)
    target_height = round(piece.height * target_width / piece.width)
    piece = piece.resize((target_width, target_height), Image.LANCZOS)

    canvas = Image.new('RGBA', (png_size, png_size), (0, 0, 0, 0))
    canvas.paste(piece, ((png_size - target_width) // 2, (png_size - target_height) // 2), piece)
    return canvas


def make_preview(images):
    """두 줄로 늘어놓고 판 색 배경을 깐 미리보기."""
    preview = Image.new('RGBA', (png_size * len(pieces), png_size * len(sides)), (222, 184, 135, 255))
    for row, side in enumerate(sides):
        for col, (name, _) in enumerate(pieces):
            tile = images[f'{side}_{name}']
            preview.alpha_composite(tile, (col * png_size, row * png_size))
    return preview


def main():
    source = Path(sys.argv[1])
    material = sys.argv[2] if len(sys.argv) > 2 else 'wood'
    image = Image.open(source).convert('RGBA')

    boxes = find_piece_boxes(image)
    if len(boxes) != len(sides) or any(len(row) != len(pieces) for row in boxes):
        counts = [len(row) for row in boxes]
        raise SystemExit(f'기물 배치가 2줄 x {len(pieces)}개가 아니다: {counts}')

    out_dir = out_root / material
    out_dir.mkdir(parents=True, exist_ok=True)
    images = {}
    for side, row_boxes in zip(sides, boxes):
        for (name, scale), box in zip(pieces, row_boxes):
            key = f'{side}_{name}'
            images[key] = make_piece(image, box, scale)
            images[key].save(out_dir / f'{key}.png')
            print(key, box)
    make_preview(images).save(out_dir / 'preview.png')
    print(f'저장: {out_dir}')


if __name__ == '__main__':
    main()
