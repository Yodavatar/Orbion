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
echo "Génération des heightmaps 6656×6656"
echo "Mapping non-linéaire intelligent"
echo "================================================"
echo ""

# Vérifier que le fichier source existe
if [ ! -f "$INPUT" ]; then
    echo "❌ Erreur: $INPUT non trouvé"
    exit 1
fi

# Script Python embarqué pour blur + mapping
POSTPROCESS_SCRIPT=$(cat <<'EOF'
import sys
import numpy as np
from PIL import Image
from scipy.ndimage import convolve

def nonlinear_map(altitude):
    """
    Mapping non-linéaire:
    - Compresse les profondeurs extrêmes
    - Étire les côtes
    - Compresse les pics
    - Eau à Y=60
    """
    # Points de contrôle: (altitude réelle, Y-level Minecraft)
    control_points = [
        (-10000, 10),      # Fosses extrêmes
        (-5000, 20),       # Abyssal
        (-2000, 35),       # Bathyal profond
        (-500, 50),        # Plateau continental
        (-200, 55),        # Côte profonde
        (0, 60),           # Niveau mer ← PIVOT
        (200, 65),         # Plages
        (500, 70),         # Collines basses
        (1000, 90),        # Collines moyennes
        (2000, 130),       # Petites montagnes
        (3000, 160),       # Montagnes
        (5000, 200),       # Hautes montagnes
        (8900, 240),       # Pics
    ]
    
    alts = np.array([p[0] for p in control_points], dtype=np.float64)
    y_lvls = np.array([p[1] for p in control_points], dtype=np.float64)
    
    # Interpolation polynomiale (cubic)
    coeffs = np.polyfit(alts, y_lvls, deg=3)
    poly = np.poly1d(coeffs)
    
    return poly(altitude)

path = sys.argv[1]
img = Image.open(path)
arr = np.array(img, dtype=np.int16)  # Signed int pour négatifs

print(f"[Postprocess] Chargement: {path}")
print(f"  Altitude min: {arr.min()}m, max: {arr.max()}m")

# Étape 1: Mapping non-linéaire
print(f"  Mapping non-linéaire...")
y_levels = nonlinear_map(arr)
y_levels = np.clip(y_levels, 0, 255).astype(np.uint8)
print(f"  Y-levels: {y_levels.min()} à {y_levels.max()}")

# Étape 2: Blur gaussien pour lisser
print(f"  Blur gaussien...")
arr_float = y_levels.astype(np.float64)
kernel = np.array([
    [1, 2, 1],
    [2, 4, 2],
    [1, 2, 1]
], dtype=np.float64) / 16.0
blurred = convolve(arr_float, kernel, mode='reflect')
blurred = np.clip(blurred, 0, 255).astype(np.uint8)

# Sauvegarder
Image.fromarray(blurred, mode='L').save(path)
print(f"  ✓ Traité et sauvegardé")
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

  echo "📍 Tuile [row=$row, col=$col] (Lon: $LON_MIN°-$LON_MAX°, Lat: $LAT_MIN°-$LAT_MAX°)"

  # Extraire en 16-bit signé (brut de GEBCO)
  gdal_translate \
    -of PNG \
    -ot Int16 \
    -projwin $LON_MIN $LAT_MAX $LON_MAX $LAT_MIN \
    -outsize $TILE_W $TILE_H \
    "$INPUT" "$OUT" 2>&1 | grep -v "Warning" || true

  # Postprocess: mapping non-linéaire + blur
  python3 - "$OUT" <<< "$POSTPROCESS_SCRIPT"
}

export -f generate_tile
export INPUT TILE_W TILE_H POSTPROCESS_SCRIPT

echo "📊 Paramètres:"
echo "   Dimensions: ${TILE_W}×${TILE_H} pixels par tuile"
echo "   Grille: ${COLS}×${ROWS} (32 tuiles total)"
echo "   Zone par tuile: 45°×45° (~1 bloc ≈ 1.2 km)"
echo ""
echo "🗺️  Mapping:"
echo "   Eau: Y=60 (référence)"
echo "   Profondeurs: -10000 à -200m → Y=10 à Y=55 (compressé)"
echo "   Côtes: -200 à +500m → Y=55 à Y=70 (pas compressé)"
echo "   Terres: +500 à +2000m → Y=70 à Y=130 (étiré)"
echo "   Montagnes: +2000 à +8900m → Y=130 à Y=240 (compressé)"
echo ""
echo "🔄 Génération en parallèle..."
echo ""

for row in $(seq 0 $((ROWS-1))); do
  for col in $(seq 0 $((COLS-1))); do
    generate_tile $row $col &
  done
done

wait

echo ""
echo "================================================"
SIZE=$(du -sh tiles_6656 2>/dev/null | cut -f1)
COUNT=$(ls tiles_6656/*.png 2>/dev/null | wc -l)
echo "✅ Génération terminée!"
echo "   📁 Dossier: ./data/tiles_6656/"
echo "   📦 Fichiers: $COUNT tuiles PNG (8-bit grayscale)"
echo "   💾 Taille totale: $SIZE"
echo "   ⚖️  Format: Chaque pixel = Y-level Minecraft [0-255]"
echo "================================================"