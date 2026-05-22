// earth_tile.js - Version avec vérifications de sécurité strictes

var col = parseInt(arguments[0]);
var row = parseInt(arguments[1]);

var BASE_PATH      = "/home/yodavatar/orbion/";
var DATA_PATH      = BASE_PATH + "data/";
var SAVES_PATH     = "/home/yodavatar/minecraft-server/";
var WORLD_NAME     = "EarthMap";
var TILE_SIZE      = 6656;

var offsetX        = col * TILE_SIZE;
var offsetZ        = row * TILE_SIZE;

print("=== Début traitement tuile x=" + col + " y=" + row + " ===");

try {
    // ── 1. Initialisation Heightmap ──────────────────────────────────────────
    var hmPath = DATA_PATH + "tiles_6656/x" + col + "_y" + row + ".png";
    print("Chargement heightmap depuis : " + hmPath);
    
    var heightMap = wp.getHeightMap().fromFile(hmPath).go();
    if (heightMap == null) throw "Erreur: Heightmap non chargée (null)";

    var mapFormat = wp.getMapFormat().withId('org.pepsoft.anvil.1.20.5').go();

    print("Création du monde...");
    var world = wp.createWorld()
        .fromHeightMap(heightMap)
        .withWaterLevel(60)
        .withLowerBuildLimit(-64)
        .withUpperBuildLimit(320)
        .withMapFormat(mapFormat)
        .shift(offsetX, offsetZ)
        .fromLevels(0, 255).toLevels(-64, 256)
        .go();
    
    if (world == null) throw "Erreur: Le monde n'a pas pu être créé";
    world.setName(WORLD_NAME);

    // ── 2. Chargement Biomes Köppen ──────────────────────────────────────────
    var kpPath = DATA_PATH + "koppen_tiles_smooth/x" + col + "_y" + row + ".png";
    print("Chargement carte Köppen depuis : " + kpPath);
    
    var koppenMap = wp.getHeightMap().fromFile(kpPath).go();
    if (koppenMap == null) throw "Erreur: Carte Köppen non chargée (null)";

    // ── 3. Initialisation des layers ─────────────────────────────────────────
    print("Initialisation des layers...");
    function getOrCreateLayer(name, type) {
        try {
            var layer = wp.getLayer().withName(name).go();
            return layer;
        } catch (e) {
            print("Création du calque : " + name);
            return wp.createLayer().withName(name).withType(type).go();
        }
    }

    var biomesLayer = getOrCreateLayer("Biomes", "CUSTOM");
    
    // ── 4. Application des biomes ────────────────────────────────────────────
    print("Application des biomes...");
    wp.applyHeightMap(koppenMap)
        .toWorld(world)
        .applyToLayer(biomesLayer)
        .fromColour(0, 0, 255).toLevel(23)      // Af
        .fromColour(0, 120, 255).toLevel(23)    // Am
        .fromColour(70, 170, 250).toLevel(35)   // Aw
        .go();

    // ── 5. Export ────────────────────────────────────────────────────────────
    print("Export en cours...");
    wp.exportWorld(world)
        .toDirectory(SAVES_PATH) // On exporte dans le dossier parent
        .go();

    print("=== TUILE x=" + col + " y=" + row + " TERMINÉE AVEC SUCCÈS ===");

} catch (err) {
    print("!!! ERREUR FATALE DANS LE SCRIPT !!!");
    print(err);
    // On force l'arrêt propre
    java.lang.System.exit(1);
}