// earth_tile.js - Génération de mondes Minecraft Orbion
// Utilise heightmaps 6656×6656 (8-bit, Y-level direct) et biomes Köppen

var col = parseInt(arguments[0]);
var row = parseInt(arguments[1]);

var BASE_PATH      = "/home/yodavatar/orbion/";
var DATA_PATH      = BASE_PATH + "data/";
var TILE_SIZE      = 6656;

var SAVES_PATH     = "/home/yodavatar/minecraft-server/";
var WORLD_NAME     = "EarthMap";

var offsetX        = col * TILE_SIZE;
var offsetZ        = row * TILE_SIZE;

print("=== Début traitement tuile x=" + col + " y=" + row + " ===");

// ── 1. Heightmap (8-bit, Y-level direct) ──────────────────────────────────────
print("Chargement heightmap (résolution 6656×6656)...");
var heightMap = wp.getHeightMap()
    .fromFile(DATA_PATH + "tiles_6656/x" + col + "_y" + row + ".png")
    .go();

var mapFormat = wp.getMapFormat()
    .withId('org.pepsoft.anvil.1.20.5')
    .go();

print("Création du monde...");
var world = wp.createWorld()
    .fromHeightMap(heightMap)
    .withWaterLevel(60)  // Eau à Y=60 (correspondant à 0m altitude réelle)
    .withLowerBuildLimit(-64)
    .withUpperBuildLimit(320)
    .withMapFormat(mapFormat)
    .shift(offsetX, offsetZ)
    .fromLevels(0, 255).toLevels(0, 320)  // Mapping direct: pixel 8-bit → Y-level 320
    .go();

// ── 2. Chargement Biomes Köppen ──────────────────────────────────────────────
print("Chargement carte Köppen...");
var koppenMap = wp.getHeightMap()
    .fromFile(DATA_PATH + "koppen_tiles/x" + col + "_y" + row + ".png")
    .go();

// ── 3. Création des layers ───────────────────────────────────────────────────
print("Initialisation des layers...");

var biomesLayer = wp.createLayer()
    .withName("Biomes")
    .withType("CUSTOM")
    .go();

var deciduousLayer = wp.createLayer()
    .withName("Deciduous")
    .withType("FOREST")
    .go();

var pineLayer = wp.createLayer()
    .withName("Pine")
    .withType("FOREST")
    .go();

var jungleLayer = wp.createLayer()
    .withName("Jungle")
    .withType("FOREST")
    .go();

var frostLayer = wp.createLayer()
    .withName("Frost")
    .withType("CUSTOM")
    .go();

// ── 4. Application des biomes ────────────────────────────────────────────────
print("Application des biomes Köppen...");

// Tropical (bleu)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(0, 0, 255).toLevel(23)       // Af → jungle
    .fromColour(0, 120, 255).toLevel(23)     // Am → jungle
    .fromColour(70, 170, 250).toLevel(35)    // Aw → savanna
    .go();

// Désert (rouge)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(255, 0, 0).toLevel(2)        // BWh → desert
    .fromColour(255, 150, 150).toLevel(2)    // BWk → desert
    .applyToTerrain()
    .fromColour(255, 0, 0).toTerrain(12)     // Sand
    .fromColour(255, 150, 150).toTerrain(12) // Sand
    .go();

// Steppe (orange)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(245, 165, 0).toLevel(35)     // BSh → savanna
    .fromColour(255, 220, 100).toLevel(36)   // BSk → savanna plateau
    .go();

// Méditerranéen (jaune)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(255, 255, 0).toLevel(1)      // Csa → plains
    .fromColour(200, 200, 0).toLevel(1)      // Csb → plains
    .fromColour(150, 150, 0).toLevel(4)      // Csc → forest
    .go();

// Tempéré (vert/jaune)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(150, 255, 150).toLevel(1)    // Cwa → plains
    .fromColour(100, 200, 100).toLevel(4)    // Cwb → forest
    .fromColour(50, 150, 50).toLevel(4)      // Cwc → forest
    .fromColour(200, 255, 80).toLevel(1)     // Cfa → plains
    .fromColour(100, 255, 80).toLevel(4)     // Cfb → forest
    .fromColour(50, 200, 0).toLevel(4)       // Cfc → forest
    .go();

// Continental/Taïga (violet/cyan)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(255, 0, 255).toLevel(5)      // Dsa → taiga
    .fromColour(200, 0, 200).toLevel(5)      // Dsb → taiga
    .fromColour(150, 50, 150).toLevel(5)     // Dsc → taiga
    .fromColour(150, 100, 150).toLevel(30)   // Dsd → snowy taiga
    .fromColour(170, 175, 255).toLevel(5)    // Dwa → taiga
    .fromColour(90, 120, 220).toLevel(5)     // Dwb → taiga
    .fromColour(75, 80, 180).toLevel(30)     // Dwc → snowy taiga
    .fromColour(50, 0, 135).toLevel(30)      // Dwd → snowy taiga
    .fromColour(0, 255, 255).toLevel(5)      // Dfa → taiga
    .fromColour(55, 200, 255).toLevel(5)     // Dfb → taiga
    .fromColour(0, 125, 125).toLevel(30)     // Dfc → snowy taiga
    .fromColour(0, 70, 95).toLevel(30)       // Dfd → snowy taiga
    .go();

// Polaire (gris)
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromColour(178, 178, 178).toLevel(29)   // ET → snowy plains
    .fromColour(102, 102, 102).toLevel(29)   // EF → snowy plains
    .applyToTerrain()
    .fromColour(178, 178, 178).toTerrain(30) // Snow
    .fromColour(102, 102, 102).toTerrain(30) // Snow
    .go();

// ── 5. Application des forêts feuillues (Deciduous) ────────────────────────
print("Application des forêts feuillues...");
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(deciduousLayer)
    .fromColour(100, 255, 80).toLevel(8)     // Cfb
    .fromColour(50, 200, 0).toLevel(8)       // Cfc
    .fromColour(100, 200, 100).toLevel(8)    // Cwb
    .fromColour(50, 150, 50).toLevel(8)      // Cwc
    .fromColour(150, 150, 0).toLevel(6)      // Csc
    .fromColour(200, 255, 80).toLevel(6)     // Cfa
    .fromColour(255, 255, 0).toLevel(5)      // Csa
    .fromColour(200, 200, 0).toLevel(5)      // Csb
    .fromColour(150, 255, 150).toLevel(5)    // Cwa
    .go();

// ── 6. Application des forêts de conifères (Pine) ──────────────────────────
print("Application des forêts de conifères...");
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(pineLayer)
    .fromColour(0, 255, 255).toLevel(10)     // Dfa
    .fromColour(55, 200, 255).toLevel(10)    // Dfb
    .fromColour(0, 125, 125).toLevel(10)     // Dfc
    .fromColour(0, 70, 95).toLevel(8)        // Dfd
    .fromColour(150, 50, 150).toLevel(10)    // Dsc
    .fromColour(150, 100, 150).toLevel(8)    // Dsd
    .fromColour(255, 0, 255).toLevel(10)     // Dsa
    .fromColour(200, 0, 200).toLevel(10)     // Dsb
    .fromColour(170, 175, 255).toLevel(10)   // Dwa
    .fromColour(90, 120, 220).toLevel(10)    // Dwb
    .fromColour(75, 80, 180).toLevel(8)      // Dwc
    .fromColour(50, 0, 135).toLevel(6)       // Dwd
    .go();

// ── 7. Application de la jungle (Tropical) ─────────────────────────────────
print("Application des jungles tropicales...");
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(jungleLayer)
    .fromColour(0, 0, 255).toLevel(10)       // Af
    .fromColour(0, 120, 255).toLevel(10)     // Am
    .fromColour(70, 170, 250).toLevel(6)     // Aw
    .go();

// ── 8. Application du frost (climat polaire/très froid) ──────────────────
print("Application du frost...");
wp.applyHeightMap(koppenMap)
    .toWorld(world)
    .applyToLayer(frostLayer)
    .fromColour(178, 178, 178).toLevel(1)    // ET
    .fromColour(102, 102, 102).toLevel(1)    // EF
    .fromColour(0, 70, 95).toLevel(1)        // Dfd
    .fromColour(0, 125, 125).toLevel(1)      // Dfc
    .fromColour(50, 0, 135).toLevel(1)       // Dwd
    .fromColour(75, 80, 180).toLevel(1)      // Dwc
    .fromColour(150, 100, 150).toLevel(1)    // Dsd
    .go();

// ── 9. Sécurité : Biome océan sous le niveau d'eau ───────────────────────
print("Application biome océan automatique...");
wp.applyHeightMap(heightMap)
    .toWorld(world)
    .applyToLayer(biomesLayer)
    .fromLevels(0, 60).toLevel(0)  // Pixels Y=0-60 → biome ocean (0)
    .go();

// ── 10. Export ────────────────────────────────────────────────────────────
print("Export du monde vers Minecraft...");
wp.exportWorld(world)
    .toDirectory(SAVES_PATH + WORLD_NAME)
    .go();

print("=== Tuile x=" + col + " y=" + row + " TERMINÉE ! ===");