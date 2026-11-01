// 장기알 PNG 생성 스크립트. 폰트 글자를 path로 바꿔 SVG로 그린 뒤 resvg로 PNG를 만든다.
// 사용: node generate.mjs
// 결과: out/<재질>/<진영>_<기물>.png 와 판 위 미리보기 out/<재질>/preview.png
import * as fontkit from 'fontkit';
import { Resvg } from '@resvg/resvg-js';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const outRoot = join(dirname(fileURLToPath(import.meta.url)), 'out');

// PNG 한 변의 픽셀 크기. 장군 기준이며 다른 기물도 같은 캔버스에 작게 그린다.
const pngSize = 256;

function openFont(path, psName) {
  const loaded = fontkit.openSync(path);
  return loaded.fonts ? loaded.fonts.find((x) => x.postscriptName === psName) : loaded;
}

// 진영별 글자 폰트와 색. 초는 초서체 느낌을 내려고 한과 다른 폰트를 쓸 수 있다.
const sides = {
  han: { font: openFont('C:/Windows/Fonts/batang.ttc', 'Gungsuh'), ink: '#D0121B' },
  cho: { font: openFont('C:/Windows/Fonts/batang.ttc', 'Gungsuh'), ink: '#1537A6' },
};

// 기물별 글자와 크기 비율(장군 1.0 기준).
const pieces = [
  { name: 'general', han: '漢', cho: '楚', scale: 1.0 },
  { name: 'chariot', han: '車', cho: '車', scale: 0.84 },
  { name: 'horse', han: '馬', cho: '馬', scale: 0.84 },
  { name: 'elephant', han: '象', cho: '象', scale: 0.84 },
  { name: 'guard', han: '士', cho: '士', scale: 0.68 },
  { name: 'cannon', han: '包', cho: '包', scale: 0.84 },
  { name: 'soldier', han: '兵', cho: '卒', scale: 0.68 },
];

// 재질별 색. 지금은 플라스틱만 있다.
const materials = {
  plastic: {
    faceLight: '#FFFFFF', // 윗면 가운데
    faceDark: '#ECECEA', // 윗면 가장자리
    bevelLight: '#FAFAF8', // 비스듬한 테두리의 빛 받는 쪽(왼쪽 위)
    bevelDark: '#A9A9A6', // 비스듬한 테두리의 그늘진 쪽(오른쪽 아래)
    outline: '#7D7D7A',
    shadowOpacity: 0.35,
  },
};

const f = (n) => +n.toFixed(2);

// 모서리를 깎은 팔각형. r은 중심에서 변까지 거리, cut은 모서리를 깎는 비율.
function octagon(cx, cy, r, cut = 0.5) {
  const c = r * cut;
  const pts = [
    [cx - r + c, cy - r], [cx + r - c, cy - r], [cx + r, cy - r + c], [cx + r, cy + r - c],
    [cx + r - c, cy + r], [cx - r + c, cy + r], [cx - r, cy + r - c], [cx - r, cy - r + c],
  ];
  return 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join(' L') + ' Z';
}

// 글자 path를 캔버스 좌표로 옮기는 transform. 글자 bbox 기준으로 가운데 맞춘다.
function glyphTransform(glyph, cx, cy, size) {
  const b = glyph.bbox;
  const s = size / Math.max(b.maxX - b.minX, b.maxY - b.minY);
  const gx = (b.minX + b.maxX) / 2;
  const gy = (b.minY + b.maxY) / 2;
  return { t: `translate(${f(cx - gx * s)} ${f(cy + gy * s)}) scale(${s.toFixed(5)} ${(-s).toFixed(5)})`, s };
}

// 100x100 캔버스에 기물 하나를 그린 SVG 본문(<svg> 태그 제외). id는 한 문서에 여러 개 넣을 때 겹치지 않게 붙인다.
function pieceBody(id, ch, side, scale, m) {
  const { font, ink } = sides[side];
  const R = 44 * scale; // 바깥 테두리 반지름
  const bevel = 5.5 * scale; // 비스듬한 테두리 폭
  const cx = 50;
  const cy = 49;
  const glyph = font.glyphForCodePoint(ch.codePointAt(0));
  const { t, s } = glyphTransform(glyph, cx, cy, (R - bevel) * 1.42);
  const bold = (1.4 * scale) / s; // 획을 조금 굵게 하는 외곽선 두께(폰트 단위)

  return `
  <defs>
    <filter id="${id}-shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur stdDeviation="${f(1.6 * scale)}"/>
    </filter>
    <linearGradient id="${id}-bevel" x1="0.15" y1="0.1" x2="0.85" y2="0.9">
      <stop offset="0" stop-color="${m.bevelLight}"/>
      <stop offset="0.45" stop-color="${m.bevelLight}"/>
      <stop offset="1" stop-color="${m.bevelDark}"/>
    </linearGradient>
    <radialGradient id="${id}-face" cx="0.42" cy="0.38" r="0.75">
      <stop offset="0" stop-color="${m.faceLight}"/>
      <stop offset="0.6" stop-color="${m.faceLight}"/>
      <stop offset="1" stop-color="${m.faceDark}"/>
    </radialGradient>
    <linearGradient id="${id}-inner" x1="0.15" y1="0.1" x2="0.85" y2="0.9">
      <stop offset="0" stop-color="#B8B8B4"/>
      <stop offset="1" stop-color="#FFFFFF"/>
    </linearGradient>
  </defs>
  <path d="${octagon(cx + 0.8 * scale, cy + 2.2 * scale, R)}" fill="#000" opacity="${m.shadowOpacity}" filter="url(#${id}-shadow)"/>
  <path d="${octagon(cx, cy, R)}" fill="url(#${id}-bevel)" stroke="${m.outline}" stroke-width="${f(0.9 * scale)}" stroke-linejoin="round"/>
  <path d="${octagon(cx, cy, R - bevel)}" fill="url(#${id}-face)" stroke="url(#${id}-inner)" stroke-width="${f(0.8 * scale)}"/>
  <path transform="${t}" d="${glyph.path.toSVG()}" fill="${ink}" stroke="${ink}" stroke-width="${f(bold)}" stroke-linejoin="round"/>`;
}

function renderPng(svg, width) {
  return new Resvg(svg, { fitTo: { mode: 'width', value: width } }).render().asPng();
}

// 9x10 판에 초기 배치로 기물을 올린 미리보기 SVG.
function previewSvg(material) {
  const cell = 80;
  const margin = 50;
  const w = margin * 2 + cell * 8;
  const h = margin * 2 + cell * 9;
  const X = (c) => margin + c * cell;
  const Y = (r) => margin + r * cell;
  let lines = '';
  for (let c = 0; c < 9; c++) lines += `<line x1="${X(c)}" y1="${Y(0)}" x2="${X(c)}" y2="${Y(9)}"/>`;
  for (let r = 0; r < 10; r++) lines += `<line x1="${X(0)}" y1="${Y(r)}" x2="${X(8)}" y2="${Y(r)}"/>`;
  for (const r of [0, 7]) {
    lines += `<line x1="${X(3)}" y1="${Y(r)}" x2="${X(5)}" y2="${Y(r + 2)}"/><line x1="${X(5)}" y1="${Y(r)}" x2="${X(3)}" y2="${Y(r + 2)}"/>`;
  }
  const back = ['chariot', 'horse', 'elephant', 'guard', null, 'guard', 'elephant', 'horse', 'chariot'];
  const placed = [];
  back.forEach((name, c) => name && placed.push(['han', name, 0, c], ['cho', name, 9, c]));
  placed.push(['han', 'general', 1, 4], ['cho', 'general', 8, 4]);
  for (const c of [1, 7]) placed.push(['han', 'cannon', 2, c], ['cho', 'cannon', 7, c]);
  for (const c of [0, 2, 4, 6, 8]) placed.push(['han', 'soldier', 3, c], ['cho', 'soldier', 6, c]);

  const size = cell * 1.08;
  const body = placed.map(([side, name, r, c], i) => {
    const p = pieces.find((x) => x.name === name);
    return `<svg x="${X(c) - size / 2}" y="${Y(r) - size / 2}" width="${size}" height="${size}" viewBox="0 0 100 100">${pieceBody(`p${i}`, p[side], side, p.scale, materials[material])}</svg>`;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">
  <rect width="${w}" height="${h}" fill="#E9C77F"/>
  <g stroke="#5A4325" stroke-width="1.5">${lines}</g>${body}
</svg>`;
}

for (const material of Object.keys(materials)) {
  const dir = join(outRoot, material);
  mkdirSync(dir, { recursive: true });
  for (const side of ['han', 'cho']) {
    for (const p of pieces) {
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">${pieceBody('p', p[side], side, p.scale, materials[material])}</svg>`;
      writeFileSync(join(dir, `${side}_${p.name}.png`), renderPng(svg, pngSize));
    }
  }
  const preview = previewSvg(material);
  writeFileSync(join(dir, 'preview.png'), new Resvg(preview).render().asPng());
  console.log(`${material}: ${pieces.length * 2}개 생성 → ${dir}`);
}
