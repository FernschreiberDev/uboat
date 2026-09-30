# Lorient photoréaliste — plan de travail (session locale sur le Mac)

La première version (`Tools/generate-lorient.py`, carte `/Game/Lorient/LorientKeroman`) a été jugée insuffisante : géographie tracée de mémoire, bâtiments mal placés, sol absent sous les bâtiments, aspect non réaliste. Elle a été faite sans Unreal ni accès aux données. Cette note fixe la nouvelle méthode.

## Principes

1. **Voir avant de valider** : chaque étape se termine par des captures dans Unreal (`Content/Python/capture_*.py` comme modèle), comparées aux photos de référence. Pas d'étape « terminée » sans image.
2. **Données réelles géoréférencées** (Lambert-93, EPSG:2154), jamais de coordonnées de mémoire.
3. **Assets photo-scannés** (Megascans via Fab, gratuits dans Unreal) plutôt que des textures générées.
4. **Détail là où la caméra va** : base et rade en haute définition ; ville et rives lointaines en silhouettes crédibles.

## Étapes

1. **Diagnostic de la v1** : ouvrir LorientKeroman, capturer, lire `Saved/Logs/Lorient-populate.log` (sol manquant : import du terrain, axes, collision ou matériau). Décider ce qui se garde (C++ `FVoyageMission`, scripts de construction) et ce qui se jette (géométrie procédurale).
2. **Données** (dans `Import/Lorient/Sources`, avec licences) :
   - relief : IGN LiDAR HD MNT ou RGE ALTI 1 m (`data.geopf.fr`) ;
   - bathymétrie : SHOM / HOMONIM, EMODnet ;
   - orthophoto actuelle BD ORTHO 20 cm (implantation exacte de K1, K2, K3, des Dombunker, du slipway) ;
   - photos aériennes 1944–1950 (IGN « Remonter le temps ») pour l'état de 1943 : quais, bassins, bâtiments disparus ;
   - OSM / BD TOPO : trait de côte, emprises ;
   - dossiers de l'Inventaire du patrimoine de Bretagne (plans, photos des blocs).
3. **Terrain** : Landscape Unreal depuis le MNT + bathymétrie fusionnés (heightmap 16 bits), couches de matériau Megascans (vase, sable, roche, herbe), Water plugin calé sur le Landscape. Vérifier le calage avec l'orthophoto en décalque.
4. **Keroman III** en premier, modélisé aux cotes et d'après photos (alvéoles, Fangrost, façade, tours de Flak), béton Megascans + décals de coulures. Validation par captures comparées aux photos.
5. **K1, K2, slipway, transbordeur, Dombunker**, puis quais et terre-pleins de 1943.
6. **Environnement** : Port-Louis et sa citadelle, Kernével, Saint-Michel, rives (kits Fab + PCG pour la végétation), Lorient en ruine en arrière-plan.
7. **Jeu** : départ dans l'alvéole, objectifs, test de navigation (`Tests/lorient-navigation.py` à adapter au nouveau terrain), mesure des performances sur le M4.

## Dépendances côté utilisateur

- Compte Epic connecté à Fab dans Unreal (Megascans).
- Photos ou plans de référence éventuels dans `Import/Lorient/References`.
