# 판 배경 이미지 위에 선, 궁성, 표시와 처음 상차림 기물을 올려 본 미리보기를 만든다.
# 사용: python preview.py <배경 이미지> [기물 재질, 기본 plastic]
# 결과: out/preview.png
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

root = Path(__file__).resolve().parent
out_dir = root / 'out'
pieces_dir = root.parent.parent / 'app' / 'assets' / 'pieces'

# 미리보기 이미지 너비(px).
preview_width = 1024


def make_preview(background, piece_set='plastic'):
    """판 위에 선, 궁성, 표시와 처음 상차림 기물을 올려 본 미리보기."""
    board = background.convert('RGB')
    board = board.resize((preview_width, round(board.height * preview_width / board.width)), Image.LANCZOS)
    w, h = board.size
    # 바깥 선에서 판 끝까지 여백을 칸의 0.65배로 둬서 가장자리 기물이 잘리지 않게 한다.
    cell = w / (8 + 0.65 * 2)
    margin_x = cell * 0.65
    margin_y = (h - cell * 9) / 2

    def point(file, rank):
        return margin_x + file * cell, margin_y + (9 - rank) * cell

    draw = ImageDraw.Draw(board, 'RGBA')
    line = (70, 40, 15, 200)
    line_width = max(1, round(cell * 0.022))
    for rank in range(10):
        draw.line([point(0, rank), point(8, rank)], fill=line, width=line_width)
    for file in range(9):
        draw.line([point(file, 0), point(file, 9)], fill=line, width=line_width)
    for r0 in (0, 7):
        draw.line([point(3, r0), point(5, r0 + 2)], fill=line, width=line_width)
        draw.line([point(5, r0), point(3, r0 + 2)], fill=line, width=line_width)

    # 포·졸 자리 표시
    arm = cell * 0.12
    for file, rank in [(1, 2), (7, 2), (1, 7), (7, 7)] + [(f, r) for f in (0, 2, 4, 6, 8) for r in (3, 6)]:
        x, y = point(file, rank)
        for dx in (-1, 1):
            for dy in (-1, 1):
                if 0 <= file + dx * 0.5 <= 8:
                    draw.line([(x + dx * arm * 0.4, y + dy * arm * 0.4), (x + dx * arm * 1.3, y + dy * arm * 1.3)],
                              fill=line, width=line_width)

    # 처음 상차림 (초 아래, 마상상마)
    back = ['chariot', 'horse', 'elephant', 'guard', None, 'guard', 'horse', 'elephant', 'chariot']
    layout = []
    for side, back_rank, cannon_rank, soldier_rank, general_rank in (('cho', 0, 2, 3, 1), ('han', 9, 7, 6, 8)):
        layout += [(side, name, f, back_rank) for f, name in enumerate(back) if name]
        layout += [(side, 'cannon', 1, cannon_rank), (side, 'cannon', 7, cannon_rank), (side, 'general', 4, general_rank)]
        layout += [(side, 'soldier', f, soldier_rank) for f in (0, 2, 4, 6, 8)]

    piece_px = round(cell * 1.05)
    shadow_offset = round(cell * 0.05)
    for side, name, file, rank in layout:
        piece = Image.open(pieces_dir / piece_set / f'{side}_{name}.png').resize((piece_px, piece_px), Image.LANCZOS)
        x, y = point(file, rank)
        pos = (round(x - piece_px / 2), round(y - piece_px / 2))
        shadow = Image.new('RGBA', piece.size, (40, 20, 0, 0))
        shadow.putalpha(piece.getchannel('A').point(lambda v: v * 0.45).filter(ImageFilter.GaussianBlur(cell * 0.04)))
        board.paste(shadow, (pos[0] + shadow_offset, pos[1] + shadow_offset), shadow)
        board.paste(piece, pos, piece)
    return board


def main():
    background = Image.open(sys.argv[1])
    piece_set = sys.argv[2] if len(sys.argv) > 2 else 'plastic'
    out_dir.mkdir(parents=True, exist_ok=True)
    make_preview(background, piece_set).save(out_dir / 'preview.png')
    print(out_dir / 'preview.png')


if __name__ == '__main__':
    main()
