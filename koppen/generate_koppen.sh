#!/bin/bash
source ./config.sh

set -e

# On définit le répertoire de sortie basé sur DATA_DIR
OUTPUT_DIR="$DATA_DIR/koppen_tiles"
BECK_RESOLUTION="0p083"
BECK_VERSION="present"

# Chemin du fichier source
INPUT_FILE="$DATA_DIR/Beck_KG_V1/Beck_KG_V1_${BECK_VERSION}_${BECK_RESOLUTION}.tif"

# Vérification
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Erreur: Fichier source introuvable : $INPUT_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=================================================="
echo "Génération des tuiles Köppen 6656×6656"
echo "=================================================="
echo ""
echo "📊 Paramètres:"
echo "   Résolution Beck: $BECK_RESOLUTION"
echo "   Version: $BECK_VERSION"
echo "   Output: $OUTPUT_DIR"
echo ""

# Script Python embarqué (Corrigé)
KOPPEN_SCRIPT=$(cat <<'EOF'
import numpy as np
from PIL import Image
from osgeo import gdal
import os
import sys

gdal.UseExceptions()

# Récupération des arguments
col = int(sys.argv[1])
row = int(sys.argv[2])
output_dir = sys.argv[3]
input_file = sys.argv[4] # C'est ici le chemin complet du tif

TILE_SIZE = 6656

# Paramètres géographiques
LON_MIN = -180 + col * 45
LON_MAX = -180 + (col + 1) * 45
LAT_MAX = 90 - row * 45
LAT_MIN = 90 - (row + 1) * 45

print(f"  Tuile [x={col}, y={row}] — Lon {LON_MIN}°-{LON_MAX}°, Lat {LAT_MIN}°-{LAT_MAX}°")

# Ouverture du fichier source
ds = gdal.Open(input_file)
if ds is None:
    print(f"❌ Impossible d'ouvrir {input_file}")
    sys.exit(1)

try:
    # Extraire la région avec GDAL en utilisant directement input_file
    vrt_output = f"/tmp/beck_{col}_{row}.vrt"
    gdal.BuildVRT(
        vrt_output,
        input_file,
        outputBounds=[LON_MIN, LAT_MIN, LON_MAX, LAT_MAX]
    )
    
    # Rééchantillonner
    png_temp = f"/tmp/beck_{col}_{row}.png"
    gdal.Translate(
        png_temp,
        vrt_output,
        format="PNG",
        width=TILE_SIZE,
        height=TILE_SIZE,
        outputType=gdal.GDT_Byte
    )
    
    # Charger et mapper les couleurs
    img = Image.open(png_temp)
    arr = np.array(img)
    
    # Palette de couleurs
    palette = {
        0: (0, 0, 255), 1: (0, 120, 255), 2: (70, 170, 250),
        3: (255, 0, 0), 4: (255, 150, 150), 5: (245, 165, 0),
        6: (255, 220, 100), 7: (255, 255, 0), 8: (200, 200, 0),
        9: (150, 150, 0), 10: (150, 255, 150), 11: (100, 200, 100),
        12: (50, 150, 50), 13: (200, 255, 80), 14: (100, 255, 80),
        15: (50, 200, 0), 16: (255, 0, 255), 17: (200, 0, 200),
        18: (150, 50, 150), 19: (150, 100, 150), 20: (170, 175, 255),
        21: (90, 120, 220), 22: (75, 80, 180), 23: (50, 0, 135),
        24: (0, 255, 255), 25: (55, 200, 255), 26: (0, 125, 125),
        27: (0, 70, 95), 28: (178, 178, 178), 29: (102, 102, 102)
    }
    
    rgb_arr = np.zeros((TILE_SIZE, TILE_SIZE, 3), dtype=np.uint8)
    for i in range(TILE_SIZE):
        for j in range(TILE_SIZE):
            idx = arr[i, j]
            rgb_arr[i, j] = palette.get(idx, (128, 128, 128))
    
    # Sauvegarder
    output_file = os.path.join(output_dir, f"x{col}_y{row}.png")
    Image.fromarray(rgb_arr).save(output_file)
    print(f"    ✅ Tuile générée")
    
    # Cleanup
    os.remove(vrt_output)
    os.remove(png_temp)
    
except Exception as e:
    print(f"    ❌ Erreur: {e}")
    sys.exit(1)
EOF
)

export KOPPEN_SCRIPT

generate_koppen_tile() {
    # On passe bien les arguments ici
    python3 - $1 $2 "$OUTPUT_DIR" "$INPUT_FILE" <<< "$KOPPEN_SCRIPT"
}

export -f generate_koppen_tile

echo "🔄 Génération en parallèle..."
echo ""

COLS=8
ROWS=4

for row in $(seq 0 $((ROWS-1))); do
    for col in $(seq 0 $((COLS-1))); do
        generate_koppen_tile $col $row &
    done
done

wait

echo ""
echo "=================================================="
SIZE=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
COUNT=$(ls "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l || echo 0)
echo "✅ Génération terminée!"
echo "   📁 Dossier: $OUTPUT_DIR"
echo "   📦 Fichiers: $COUNT tuiles PNG"
echo "   💾 Taille totale: $SIZE"
echo "=================================================="