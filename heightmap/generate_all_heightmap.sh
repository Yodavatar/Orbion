#!/bin/bash
source ./config.sh

set -e

INPUT="$DATA_DIR/gebco_merged_v2.tif"
TILE_W=6656
TILE_H=6656
COLS=8
ROWS=4

mkdir -p "$TILE_DIR"

echo "================================================"
echo "Génération linéaire (Sans étirement)"
echo "Mapping direct Altitude -> Y-level"
echo "================================================"
echo ""

if [ ! -f "$INPUT" ]; then
    echo "❌ Erreur: $INPUT non trouvé"
    exit 1
fi

POSTPROCESS_SCRIPT=$(cat <<'EOF'
import sys
import numpy as np
from PIL import Image

# Plage réelle GEBCO
ALT_MIN = -10000.0
ALT_MAX = 8900.0

path = sys.argv[1]
img = Image.open(path)
arr = np.array(img, dtype=np.float32)

print(f"[Linear] Chargement: {path}")
print(f"  Alt min: {arr.min()}, max: {arr.max()}")

# Mapping linéaire pur : 
# 0 correspond à -10000m, 255 correspond à +8900m
y_levels = 255 * (arr - ALT_MIN) / (ALT_MAX - ALT_MIN)
y_levels = np.clip(y_levels, 0, 255).astype(np.uint8)

# Sauvegarder
Image.fromarray(y_levels, mode='L').save(path)
print(f"  ✓ Mapping linéaire appliqué")
EOF
)

generate_tile() {
  row=$1
  col=$2

  LON_MIN=$(echo "-180 + $col * 45" | bc)
  LON_MAX=$(echo "-180 + ($col + 1) * 45" | bc)
  LAT_MAX=$(echo "90 - $row * 45" | bc)
  LAT_MIN=$(echo "90 - ($row + 1) * 45" | bc)

  OUT="data/tiles_6656/x${col}_y${row}.png"

  echo "📍 Tuile [row=$row, col=$col]"

  gdal_translate \
    -of PNG \
    -ot Float32 \
    -projwin $LON_MIN $LAT_MAX $LON_MAX $LAT_MIN \
    -outsize $TILE_W $TILE_H \
    "$INPUT" "$OUT" 2>&1 | grep -v "Warning" || true

  python3 - "$OUT" <<< "$POSTPROCESS_SCRIPT"
}

export -f generate_tile
export INPUT TILE_W TILE_H POSTPROCESS_SCRIPT

for row in $(seq 0 $((ROWS-1))); do
  for col in $(seq 0 $((COLS-1))); do
    generate_tile $row $col &
  done
done
wait