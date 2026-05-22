#!/bin/bash
source ./config.sh # Chargement des variables

set -e

# Utilisation des variables de config.sh
INPUT_DIR="$DATA_DIR/gebco_2025_geotiff"
OUTPUT="$DATA_DIR/gebco_merged_v2.tif"
TEMP_VRT="gebco_temp.vrt"

# ... (reste du script inchangé)

echo "================================================"
echo "Fusion des tuiles GEBCO 2025"
echo "================================================"
echo ""

# Vérifier que le dossier existe
if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ Erreur: dossier $INPUT_DIR non trouvé"
    exit 1
fi

# Lister les tuiles
echo "📂 Tuiles détectées:"
TIFS=($(find "$INPUT_DIR" -name "gebco_2025_*.tif" -type f | sort))

if [ ${#TIFS[@]} -eq 0 ]; then
    echo "❌ Aucun fichier gebco_2025_*.tif trouvé dans $INPUT_DIR"
    exit 1
fi

for tif in "${TIFS[@]}"; do
    echo "   ✓ $tif"
done

echo ""
echo "📊 Total: ${#TIFS[@]} tuiles"
echo ""

# Étape 1: Créer un VRT (Virtual Raster Tile)
echo "🔨 Étape 1: Création du VRT virtuel..."
gdalbuildvrt -overwrite "$TEMP_VRT" "${TIFS[@]}"
echo "   ✓ VRT créé: $TEMP_VRT"
echo ""

# Étape 2: Convertir en GeoTIFF avec compression
echo "🔨 Étape 2: Conversion en GeoTIFF (compression DEFLATE)..."
gdal_translate \
    -of GTiff \
    -co COMPRESS=DEFLATE \
    -co ZLEVEL=9 \
    "$TEMP_VRT" \
    "$OUTPUT"
echo "   ✓ GeoTIFF créé: $OUTPUT"
echo ""

# Étape 3: Nettoyage
echo "🧹 Nettoyage des fichiers temporaires..."
rm -f "$TEMP_VRT"
echo "   ✓ Fichiers temporaires supprimés"
echo ""

# Étape 4: Infos sur le fichier généré
echo "📋 Infos sur le fichier généré:"
gdalinfo "$OUTPUT" | head -25
echo ""

# Taille du fichier
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "📦 Taille du fichier: $SIZE"
echo ""
echo "================================================"
echo "✅ Fusion terminée avec succès!"
echo "================================================"