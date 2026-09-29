> Mise à jour du 27 septembre : la version jouable distincte **AtlanticVoyage** est décrite dans [JOUER.md](JOUER.md). Le présent document conserve l’historique de construction des démonstrations.

# État de la démo — 26 septembre 2026

Unreal Engine 5.8.3, Xcode 27 et Metal Toolchain sont installés sur le Mac mini M4 (16 Go).

Le niveau `/Game/Demo/AtlanticDemo` est construit et sauvegardé. Les assets incluent le sous-marin détaillé (265 624 triangles, 15 matériaux), ses textures exportées et une côte procédurale. L’axe Y du modèle d’origine est converti en axe vertical Unreal par une rotation de l’acteur. Dimensions contrôlées dans Unreal : 67,18 m de longueur, 6,21 m de largeur hors tout, 13,11 m de hauteur avec les périscopes levés.

L’océan utilise le matériau et les vagues Gerstner fournis par Epic. Éclairage dynamique avec soleil, atmosphère et ciel ; brume maritime et nuages volumétriques.

Une capture de la scène a été inspectée. Les matériaux et l’exposition ont été corrigés, puis la ligne de flottaison a été alignée sur la position du jeu d’origine (−1,9 m). Le démarrage en mode jeu a été confirmé dans le journal Unreal (chargement de AtlanticDemo et démarrage du monde). Le contrôle interactif final est limité par le verrouillage de la session macOS. Aucune mesure de performances de jeu autonome n’est encore disponible. Ce projet est une scène d’évaluation, pas le portage du jeu ni une certification historique du modèle.

Le projet Swift et ses sauvegardes sont conservés. Les cartes Atlantic et AtlanticPreview sont des ébauches vides des premières tentatives ; seule AtlanticDemo constitue la scène à ouvrir.

Les performances restent à mesurer en session active ; les temps d’une fenêtre en arrière-plan ou d’un Mac verrouillé ne constituent pas un benchmark valide.

## Portage du modèle détaillé

Le sous-marin de la scène est désormais le VIIC détaillé du jeu, version 0.3.1 de `Sources/Detailed*.swift` (massif d’après le relevé britannique de l’U-570, étrave et portes des tubes refaites). L’export précédent était faussé : SceneKit n’avait pas encore généré la géométrie des primitives au moment de la lecture, et la plupart des pièces sortaient comme des volumes provisoires d’environ 1 m (d’où les 7,74 m de largeur mesurés auparavant). L’outil d’export rend maintenant le modèle une fois avant de le lire et vérifie la taille de chacune des 1 866 pièces.

Les couleurs des matériaux Naval avaient été saisies en sRGB comme valeurs linéaires, ce qui éclaircissait fortement les gris foncés de la coque ; `port_submarine.py` les convertit à chaque portage. Six vues de contrôle sont capturées dans `Saved/PortCheck` par `capture_port.py` ; `Docs/Atlantic-demo.png` reprend la vue d’ensemble.

Le sous-marin reste un maillage unique : gouvernails, barres et hélices ne sont pas animés, et le maillage n’utilise ni Nanite ni cartes de normales.

## Flottaison

Le sous-marin est désormais porté par la houle en jeu et en simulation : corps physique de 769 t, 16 flotteurs du plugin Water réglés pour des périodes d’environ 4,9 s en pilonnement, 8,1 s en roulis et 5,5 s en tangage (`float_submarine.py`). Pour cela, le modèle est redressé à l’import (proue vers +X, acteur tourné de −90°) ; sa place dans la scène ne change pas.

Contrôle en simulation dans l’éditeur (`capture_float.py`, 90 s après 10 s de mise en eau) : bateau dans l’eau en permanence, pilonnement de 69 cm d’écart type (−2,3 à +1,1 m), roulis de 1,6° d’écart type (−4,5 à +4,3°), tangage de 1,6° (−3,6 à +3,4°), dérive inférieure à 4 cm et cap stable à 1,6° près. Le niveau moyen de l’eau autour de la coque est de −43 cm, conforme aux vagues de Gerstner de la scène ; le bateau flotte 12 cm plus bas que prévu par rapport à ce niveau.

Deux obstacles ont été levés en route. L’enveloppe convexe qui sert de collision à la côte englobe le mouillage et éjectait la coque : le bateau ne fait plus que la chevaucher. Le contact avec l’océan, présent dès le chargement, n’était pas signalé à la flottabilité : l’acteur génère désormais ses événements de chevauchement au chargement. Le plugin Buoyancy, activé par ChaosCloth, a été testé : il n’agit pas sur le bateau et reste dans son réglage d’origine.

## Variante côtière — 27 septembre 2026

AtlanticCoast est disponible via `Jouer-cote-detaillee.command` ou `Ouvrir-cote-detaillee.command`. AtlanticDemo reste la scène par défaut, inchangée, ainsi que VIIC, BP_FlottaisonVIIC et float_submarine.py (empreintes SHA-256 vérifiées). Le décor ajoute un terrain de 1,6 km avec falaises, criques et un matériau de roche et de végétation par pente ; il reste procédural.

L’océan invisible provenait des maillages WaterInfo absents après la génération sans rendu. Ils ont été reconstruits dans l’éditeur complet puis sauvegardés. Une relance sans réparation automatique confirme l’eau visible. Le test de simulation mesure 25 secondes après 10 secondes de stabilisation : contact avec l’eau à 100 %, pilonnement de 82 cm d’écart type, roulis de 1,68°, tangage de 1,93°, dérive maximale de 3,64 cm. Il s’agit d’un contrôle court, pas d’une validation physique exhaustive.

Aperçu vérifié : `Atlantic-coast-demo.png`. Mesures et préservation : `coast-variant-validation.json`. Pas encore de vagues déferlantes, de textures scannées, de propulsion ni de collision navigable avec la terre. Les paramètres des vagues et de la flottabilité de la scène originale sont conservés.

## Détails du littoral — 27 septembre 2026

AtlanticCoast utilise désormais CoastalRockPBR : textures 2K de roche, variation à plusieurs échelles, projection sans étirement sur les parois, rugosité et relief d’éclairage, bande humide irrégulière. Huit sections Coastal Cliff 01 complètent le bord de l’eau. Les quatre LOD fournis par l’auteur sont employés séparément : 238 686 / 121 526 / 62 253 / 32 185 sommets. Ils ne sont pas assemblés simultanément. Les captures d’ensemble et de près ont été inspectées après correction de l’orientation et du raccord au terrain.

Les maillages de rendu de l’océan sont présents, la masse et la position du VIIC sont conservées. Aucun changement de physique : ce contrôle vérifie le décor et les réglages, sans remplacer le précédent essai de flottabilité. Les empreintes des fichiers du Bismarck et des assets d’origine sont inchangées. Détails : `coast-detail-validation.json`. La documentation de la scène Bismarck signale encore son problème de flottabilité ; cette intervention sur le littoral ne le corrige pas.

Le décor reste un prototype. Pas de déferlement physique ni de collisions de navigation sur les nouveaux rochers, et aucune mesure de cadence en jeu n’est déduite des captures de l’éditeur.
