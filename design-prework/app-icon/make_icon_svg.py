"""Writes clipboard-remix-icon.svg. Run: python3 make_icon_svg.py
The SVG is the editable master; this script only exists so the squircle
outline stays mathematically exact (superellipse, n=5, Apple's 824pt body on a 1024 grid)."""
import math, pathlib

def squircle(cx=512, cy=512, a=412, n=5.0, step=0.5):
    pts = []
    i = 0.0
    while i < 360:
        t = math.radians(i); c, s = math.cos(t), math.sin(t)
        x = cx + a * math.copysign(abs(c) ** (2 / n), c)
        y = cy + a * math.copysign(abs(s) ** (2 / n), s)
        pts.append(f"{x:.1f} {y:.1f}")
        i += step
    return "M" + " L".join(pts) + " Z"

SQ = squircle()

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <title>Clipboard Remix app icon</title>
  <defs>
    <!-- Body -->
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#4C8DFF"/>
      <stop offset="0.55" stop-color="#2A5FE0"/>
      <stop offset="1" stop-color="#2238A8"/>
    </linearGradient>
    <radialGradient id="bgGlow" cx="0.3" cy="0.15" r="0.75">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.28"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="rim" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.45"/>
      <stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.06"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.14"/>
    </linearGradient>
    <!-- Screenshot clip -->
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFB36B"/>
      <stop offset="1" stop-color="#FF6F7D"/>
    </linearGradient>
    <linearGradient id="hillBack" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7A5CE0"/>
      <stop offset="1" stop-color="#5A43C2"/>
    </linearGradient>
    <linearGradient id="hillFront" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3E3399"/>
      <stop offset="1" stop-color="#2D2577"/>
    </linearGradient>
    <!-- Text clip paper -->
    <linearGradient id="paper" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#EEF1F8"/>
    </linearGradient>
    <linearGradient id="hl" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#FFC94A"/>
      <stop offset="1" stop-color="#FFB02E"/>
    </linearGradient>
    <filter id="iconShadow" x="-10%" y="-10%" width="120%" height="125%">
      <feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000" flood-opacity="0.30"/>
    </filter>
    <filter id="cardShadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#0A1A5C" flood-opacity="0.38"/>
    </filter>
    <clipPath id="photoClip"><rect x="-196" y="-150" width="392" height="300" rx="30"/></clipPath>
  </defs>

  <!-- 1. Squircle body (824pt on 1024 canvas, macOS grid) -->
  <g filter="url(#iconShadow)">
    <path d="{SQ}" fill="url(#bg)"/>
  </g>
  <path d="{SQ}" fill="url(#bgGlow)"/>
  <path d="{SQ}" fill="none" stroke="url(#rim)" stroke-width="4"/>

  <!-- 2a. Ghost card: older history further down the stack -->
  <g transform="translate(560 360) rotate(9)">
    <rect x="-200" y="-160" width="400" height="320" rx="46" fill="#FFFFFF" fill-opacity="0.22"/>
    <rect x="-200" y="-160" width="400" height="320" rx="46" fill="none" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="4"/>
  </g>

  <!-- 2. Back card: a saved screenshot, tilted left -->
  <g transform="translate(424 388) rotate(-11)" filter="url(#cardShadow)">
    <rect x="-216" y="-170" width="432" height="340" rx="46" fill="#FFFFFF"/>
    <g clip-path="url(#photoClip)">
      <rect x="-196" y="-150" width="392" height="300" fill="url(#sky)"/>
      <circle cx="78" cy="-58" r="46" fill="#FFF3D6"/>
      <path d="M-196 70 C-120 -10 -60 -20 10 40 C70 -10 130 -30 196 20 L196 150 L-196 150 Z" fill="url(#hillBack)"/>
      <path d="M-196 120 C-110 60 -20 70 60 110 C120 80 170 80 196 92 L196 150 L-196 150 Z" fill="url(#hillFront)"/>
    </g>
  </g>

  <!-- 3. Front card: a saved text clip, tilted right -->
  <g transform="translate(588 604) rotate(7)" filter="url(#cardShadow)">
    <rect x="-210" y="-196" width="420" height="392" rx="50" fill="url(#paper)"/>
    <!-- highlighted match (search hit / selected line) -->
    <rect x="-158" y="-128" width="244" height="58" rx="18" fill="url(#hl)"/>
    <rect x="-142" y="-111" width="212" height="24" rx="12" fill="#1C2A5E"/>
    <!-- remaining text lines -->
    <rect x="-142" y="-34" width="284" height="24" rx="12" fill="#B9C2D8"/>
    <rect x="-142" y="26" width="248" height="24" rx="12" fill="#B9C2D8"/>
    <rect x="-142" y="86" width="176" height="24" rx="12" fill="#B9C2D8"/>
  </g>
</svg>
'''
out = pathlib.Path(__file__).with_name("clipboard-remix-icon.svg")
out.write_text(svg)
print(out)
