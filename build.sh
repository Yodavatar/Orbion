#!/bin/bash
# build.sh - Génération complète de la carte Terre Minecraft Orbion

set -e

export _JAVA_OPTIONS="-Xmx26G -Xms14G -XX:+UseG1GC"

ORBION="/home/yodavatar/orbion"
SAVES="/home/yodavatar/minecraft-server"
WORLD_NAME="EarthMap"
COLS=8
ROWS=4
FROM="heightmap"
SINGLE_TILE=0
TILE_COL=0
TILE_ROW=0

# ── Arguments ─────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case $1 in
        --from) FROM=$2; shift 2 ;;
        --tile) SINGLE_TILE=1; TILE_COL=$2; TILE_ROW=$3; shift 3 ;;
        *) echo "Argument inconnu : $1"; exit 1 ;;
    esac
done

# ── Fonctions ─────────────────────────────────────────────────────────────────
step() { 
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "════════════════════════════════════════════════════════════"
}
ok() { echo "  ✓ $1"; }

# ── Étape 1 : Heightmaps (GEBCO → PNG 8-bit, mapping non-linéaire) ───────────
if [[ "$FROM" == "heightmap" && $SINGLE_TILE -eq 0 ]]; then
    step "Étape 1/4 : Génération des heightmaps non-linéaires (GEBCO)"
    cd "$ORBION"
    bash generate.sh
    ok "32 tuiles heightmap 6656×6656 générées dans data/tiles_6656/"
else
    ok "Étape 1/4 : Heightmaps ignorées"
fi

# ── Étape 2 : Biomes Köppen (Beck_KG_V1 → PNG RGB) ───────────────────────────
if [[ "$FROM" == "heightmap" || "$FROM" == "koppen" ]] && [[ $SINGLE_TILE -eq 0 ]]; then
    step "Étape 2/4 : Génération des tuiles Köppen (Beck_KG_V1)"
    cd "$ORBION"
    bash koppen/generate_koppen.sh
    ok "32 tuiles Köppen 6656×6656 générées dans data/koppen_tiles/"
else
    ok "Étape 2/4 : Biomes Köppen ignorés"
fi

# ── Étape 3 : Lissage Köppen (Perlin + blur pour transitions fluides) ────────
if [[ "$FROM" != "export" ]] && [[ "$FROM" == "heightmap" || "$FROM" == "koppen" || "$FROM" == "smooth" ]] && [[ $SINGLE_TILE -eq 0 ]]; then
    step "Étape 3/4 : Lissage des transitions biomes (Perlin noise)"
    cd "$ORBION"
    python3 koppen/koppen_smooth.py
    ok "32 tuiles lissées dans data/koppen_tiles/ (overwrite)"

elif [[ $SINGLE_TILE -eq 1 ]] && [[ "$FROM" != "export" ]]; then
    step "Étape 3/4 : Lissage tuile x=${TILE_COL} y=${TILE_ROW}"
    cd "$ORBION"
    python3 koppen/koppen_smooth.py --col $TILE_COL --row $TILE_ROW
    ok "Tuile lissée"
else
    ok "Étape 3/4 : Lissage ignoré (ou déjà fait)"
fi

# ── Étape 4 : Export WorldPainter → Minecraft ─────────────────────────────────
step "Étape 4/4 : Export WorldPainter → Minecraft"

if [[ $SINGLE_TILE -eq 1 ]]; then
    echo "  [Mode Test] Tuile unique x=${TILE_COL} y=${TILE_ROW}"
    wpscript "$ORBION/earth_tile.js" $TILE_COL $TILE_ROW
    ok "Tuile exportée vers ${SAVES}/${WORLD_NAME}/"
else
    TOTAL=$((COLS * ROWS))
    COUNT=0
    
    # Initialiser le dossier monde si absent
    mkdir -p "${SAVES}/${WORLD_NAME}"
    
    echo "  Exportation de $TOTAL tuiles..."
    for row in $(seq 0 $((ROWS-1))); do
        for col in $(seq 0 $((COLS-1))); do
            COUNT=$((COUNT + 1))
            printf "    [%2d/%2d] Tuile x=%d y=%d ... " "$COUNT" "$TOTAL" "$col" "$row"
            
            if wpscript "$ORBION/earth_tile.js" $col $row > /dev/null 2>&1; then
                echo "✓"
            else
                echo "✗ ERREUR"
                exit 1
            fi
        done
    done
    
    ok "32 tuiles exportées dans ${SAVES}/${WORLD_NAME}/"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✓ Build terminé avec succès !"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Prochaines étapes:"
echo "    1. Lance le serveur Minecraft"
echo "    2. Ouvre le monde : ${WORLD_NAME}"
echo "    3. Explore la Terre en Minecraft ! 🌍"
echo ""