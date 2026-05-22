#!/usr/bin/env python3
"""
koppen_smooth.py - Prétraitement des tuiles Köppen pour des transitions douces.

Principe :
  1. Charger l'image Köppen (couleurs exactes par zone climatique)
  2. Déformer avec un champ Perlin calculé sur grille 128x128 (léger) puis upscalé
  3. Flou gaussien pour interpoler entre couleurs voisines
  4. Requantifier vers la couleur Köppen la plus proche (palette fixe)

Usage :
  python3 koppen_smooth.py                  # toutes les tuiles
  python3 koppen_smooth.py --col 0 --row 0  # une tuile spécifique

Dépendances :
  pip install pillow numpy noise
"""

import argparse
import numpy as np
from pathlib import Path
from PIL import Image, ImageFilter

try:
    from noise import pnoise2
    HAS_NOISE = True
except ImportError:
    print("⚠️  Module 'noise' non trouvé : pip install noise")
    print("   Transitions sans bruit de Perlin.")
    HAS_NOISE = False

# ── Config ────────────────────────────────────────────────────────────────────
BASE_PATH  = Path("/home/yodavatar/orbion")
INPUT_DIR  = BASE_PATH / "data" / "koppen_tiles"
OUTPUT_DIR = BASE_PATH / "data" / "koppen_tiles_smooth"
COLS       = 8
ROWS       = 4

BLUR_RADIUS  = 2      # pixels de flou gaussien (~8 blocs de transition)
PERLIN_SCALE = 0.06   # fréquence du bruit sur la grille 128x128
PERLIN_AMP   = 120     # amplitude max du déplacement en pixels image finale
PERLIN_OCT   = 4      # octaves Perlin

# Palette Köppen exacte
KOPPEN_PALETTE = [
    (0,   0,   255),  # Af
    (0,   120, 255),  # Am
    (70,  170, 250),  # Aw
    (255, 0,   0  ),  # BWh
    (255, 150, 150),  # BWk
    (245, 165, 0  ),  # BSh
    (255, 220, 100),  # BSk
    (255, 255, 0  ),  # Csa
    (200, 200, 0  ),  # Csb
    (150, 150, 0  ),  # Csc
    (150, 255, 150),  # Cwa
    (100, 200, 100),  # Cwb
    (50,  150, 50 ),  # Cwc
    (200, 255, 80 ),  # Cfa
    (100, 255, 80 ),  # Cfb
    (50,  200, 0  ),  # Cfc
    (255, 0,   255),  # Dsa
    (200, 0,   200),  # Dsb
    (150, 50,  150),  # Dsc
    (150, 100, 150),  # Dsd
    (170, 175, 255),  # Dwa
    (90,  120, 220),  # Dwb
    (75,  80,  180),  # Dwc
    (50,  0,   135),  # Dwd
    (0,   255, 255),  # Dfa
    (55,  200, 255),  # Dfb
    (0,   125, 125),  # Dfc
    (0,   70,  95 ),  # Dfd
    (178, 178, 178),  # ET
    (102, 102, 102),  # EF
]

PALETTE_NP = np.array(KOPPEN_PALETTE, dtype=np.float32)


def nearest_koppen(img_array: np.ndarray) -> np.ndarray:
    """Requantifie chaque pixel vers la couleur Köppen la plus proche (L2)."""
    h, w, _ = img_array.shape
    flat  = img_array.reshape(-1, 3).astype(np.float32)
    diffs = flat[:, None, :] - PALETTE_NP[None, :, :]
    dist2 = (diffs ** 2).sum(axis=2)
    idx   = dist2.argmin(axis=1)
    return PALETTE_NP[idx].reshape(h, w, 3).astype(np.uint8)


def perlin_warp(img_array: np.ndarray, col: int, row: int) -> np.ndarray:
    """Déforme l'image via un champ Perlin calculé sur grille 128x128 puis upscalé.
    128*128 = 16k appels pnoise2 au lieu de 45M → pas de crash."""
    h, w = img_array.shape[:2]
    seed_x = col * 100 + row * 10 + 1
    seed_y = col * 100 + row * 10 + 2
    GRID = 128

    print("  Bruit de Perlin (128x128)...")
    dx_small = np.array([
        [pnoise2(x * PERLIN_SCALE + seed_x, y * PERLIN_SCALE + seed_x, octaves=PERLIN_OCT)
         for x in range(GRID)]
        for y in range(GRID)
    ], dtype=np.float32) * PERLIN_AMP

    dy_small = np.array([
        [pnoise2(x * PERLIN_SCALE + seed_y, y * PERLIN_SCALE + seed_y, octaves=PERLIN_OCT)
         for x in range(GRID)]
        for y in range(GRID)
    ], dtype=np.float32) * PERLIN_AMP

    # Upscale vers la résolution de l'image
    dx = np.array(Image.fromarray(dx_small).resize((w, h), Image.BILINEAR))
    dy = np.array(Image.fromarray(dy_small).resize((w, h), Image.BILINEAR))

    # Remap vectorisé
    ys, xs = np.mgrid[0:h, 0:w]
    src_x = np.clip(xs + dx, 0, w - 1).astype(np.int32)
    src_y = np.clip(ys + dy, 0, h - 1).astype(np.int32)
    return img_array[src_y, src_x]


def process_tile(col: int, row: int):
    input_path  = INPUT_DIR  / f"x{col}_y{row}.png"
    output_path = OUTPUT_DIR / f"x{col}_y{row}.png"

    if not input_path.exists():
        print(f"  ⚠️  Manquant : {input_path}")
        return

    print(f"Tuile x={col} y={row}...")
    arr = np.array(Image.open(input_path).convert("RGB"))

    if HAS_NOISE:
        arr = perlin_warp(arr, col, row)

    print("  Flou gaussien...")
    arr = np.array(Image.fromarray(arr).filter(ImageFilter.GaussianBlur(radius=BLUR_RADIUS)))

    print("  Requantification...")
    arr = nearest_koppen(arr)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(output_path)
    print(f"  ✓ {output_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--col", type=int, default=None)
    parser.add_argument("--row", type=int, default=None)
    args = parser.parse_args()

    if args.col is not None and args.row is not None:
        process_tile(args.col, args.row)
    else:
        for row in range(ROWS):
            for col in range(COLS):
                process_tile(col, row)

    print(f"\nTerminé ! Résultat dans : {OUTPUT_DIR}")
    print("Dans earth_tile.js, change 'koppen_tiles' → 'koppen_tiles_smooth'")


if __name__ == "__main__":
    main()
