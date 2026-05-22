#!/usr/bin/env python3
"""
Mapping non-linéaire pour GEBCO → Minecraft
- Compresse les profondeurs extrêmes
- Étire les côtes (transition eau/terre)
- Compresse les pics extrêmes
- Place l'eau à Y=60 avec espace pour constructions
"""

import numpy as np
from PIL import Image
import sys

def create_elevation_curve():
    """
    Crée une courbe de mapping non-linéaire.
    
    Real-world altitudes:
    -10000m (fosses) → compressé vers bas
    -5000m (abyssal) → compressé
    -2000m (bathyal) → légèrement compressé
    -200m (plateau continental) → MOINS compressé
    0m (niveau mer) → point pivot
    +2000m (collines) → pas compressé
    +5000m (montagnes) → léger compress
    +8900m (pics) → compressé
    
    Minecraft:
    Y=60: eau (reference)
    Y=256: limite construction
    Y=0: bedrock
    """
    
    # Points de contrôle: (altitude réelle en m, Y-level Minecraft)
    control_points = [
        (-10000, 10),      # Fosses extrêmes → très bas
        (-5000, 20),       # Abyssal → bas
        (-2000, 35),       # Bathyal profond → modéré
        (-500, 50),        # Plateau continental → proche eau
        (-200, 55),        # Côte profonde → très proche eau
        (0, 60),           # Niveau mer (pivot)
        (200, 65),         # Plages/deltas → légèrement au-dessus
        (500, 70),         # Collines basses
        (1000, 90),        # Collines moyennes
        (2000, 130),       # Petites montagnes
        (3000, 160),       # Montagnes
        (5000, 200),       # Hautes montagnes
        (8900, 240),       # Pics (près du limite)
    ]
    
    alts = np.array([p[0] for p in control_points])
    y_levels = np.array([p[1] for p in control_points])
    
    # Interpolation polynomial (deg 3 = cubic spline)
    coeffs = np.polyfit(alts, y_levels, deg=3)
    poly = np.poly1d(coeffs)
    
    return poly

def process_heightmap(input_path, output_path):
    """Applique le mapping non-linéaire à une heightmap."""
    
    print(f"Chargement: {input_path}")
    img = Image.open(input_path)
    arr = np.array(img, dtype=np.int16)  # Important: signed int pour négatifs
    
    print(f"  Dimensions: {arr.shape}")
    print(f"  Min: {arr.min()}m, Max: {arr.max()}m")
    
    # Créer la courbe de mapping
    poly = create_elevation_curve()
    
    # Appliquer le mapping
    print("Mapping non-linéaire...")
    y_levels = poly(arr)
    
    # Clamp dans [0, 255] (8-bit pour Minecraft)
    # On peut aussi utiliser [0, 65535] pour 16-bit si WorldPainter le supporte
    y_levels = np.clip(y_levels, 0, 255).astype(np.uint8)
    
    print(f"  Y-levels: {y_levels.min()} à {y_levels.max()}")
    
    # Sauvegarder
    result_img = Image.fromarray(y_levels, mode='L')  # 'L' = 8-bit grayscale
    result_img.save(output_path)
    print(f"Sauvegardé: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 nonlinear_map.py <input.png> <output.png>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    process_heightmap(input_file, output_file)