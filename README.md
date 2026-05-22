<img width="1000" height="550" alt="image" src="https://github.com/user-attachments/assets/e6b57053-c60e-4290-8d9f-87cb737f7695" />

This Orbion repository is a suite of automated tools designed to transform raw geographic data (GEBCO bathymetry, Köppen climate classification) into large-scale Minecraft worlds, ready for **WorldPainter**.
---

## 🗺️ Table of Contents
- [Introduction](#introduction)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Contribution](#contribution)
- [License](#license)

---
## 📖 Introduction
Orbion's goal is to enable the creation of realistic Minecraft world maps by automating complex raster data transformation processes.

The pipeline handles:

- Elevation data processing (GEBCO).
- Climate biome generation (Köppen).
- Optimized export to WorldPainter.

---

## ✨ Features

### 1. Heightmap Processing

- Transformation of GEBCO bathymetric data into 16-bit heightmaps.
- Application of **non-linear mappings** to ensure natural relief (coastal stretching, abyssal compression).
- Efficient handling of large datasets via VRT file creation.

### 2. Köppen Climate Integration

- Conversion of Beck KG V1 climate data into biome maps.
- **Organic smoothing** of climate boundaries using Perlin noise and Gaussian filters.

### 3. WorldPainter Automation

- Scripted pipeline for applying biome layers.
- Bulk export and parallel tile management.

---

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone git@github.com:Yodavatar/Orbion.git
   cd orbion
   ```

2. **Required dependencies:**
Please ensure you have GDAL and Python 3.14+ installed on your system.
   ```bash
   pip install numpy pillow scipy noise
   ```

---

## 🛠️ Usage

Orbion is used via a series of Bash scripts. The recommended workflow is as follows:

1. **Data preparation:**
    ```bash
    ./merge_gebco_final.sh
    ```
2. **Relief generation:**
    ```bash
    ./generate_all_heightmap.sh
    ```
3. **Climate generation:**
   ```bash
   ./generate_koppen.sh
   ```
4. **Build final (WorldPainter) :**
   ```bash
   ./build.sh
   ```

---

## Contact

If you have any questions or suggestions, <br>
feel free to contact me at contact@yodavatar.me <br>
