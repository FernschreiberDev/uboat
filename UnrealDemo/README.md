# Nordatlantik — démo Unreal sur Mac

Projet séparé du jeu SceneKit, destiné à évaluer le rendu d’Unreal sur le Mac M4.

## Installation depuis GitHub

Cloner `https://github.com/FernschreiberDev/uboat.git`, puis ouvrir le dossier `UnrealDemo`. Le dépôt contient le code C++, les cartes, les assets, les outils et leurs sources de modèles Swift dans `Sources/`. Les caches, binaires compilés et sauvegardes personnelles sont exclus.

Sur Mac Apple Silicon, installer Unreal Engine **5.8.3** et Xcode avec ses composants Metal, puis compiler le module du jeu depuis la racine du dépôt :

```bash
"/Users/Shared/Epic Games/UE_5.8/Engine/Build/BatchFiles/Mac/Build.sh" NordatlantikDemoEditor Mac Development "$PWD/UnrealDemo/NordatlantikDemo.uproject" -WaitMutex -NoHotReload
```

Lancer ensuite `UnrealDemo/Jouer-a-Nordatlantik.command`. Les lanceurs supposent l’emplacement d’installation Epic par défaut. Les assets sont déjà importés ; leur régénération avec les outils Swift est facultative. Aucun binaire du moteur Unreal n’est distribué dans ce dépôt.

**Version d’exploration jouable : `Jouer-a-Nordatlantik.command`.** Pilotage du VIIC, plongée assistée, trois découvertes et sauvegarde dans la nouvelle carte AtlanticVoyage. Commandes et limites : [JOUER.md](Docs/JOUER.md). Les démonstrations de rendu décrites ci-dessous restent disponibles. Dans la version jouable, les hélices, gouvernails et barres sont animés : **G** pour les vues rapprochées, **V** pour comparer avec le modèle fixe.

**Lorient — base de Keroman 1943 : `Jouer-a-Lorient.command`.** Nouvelle carte jouable : départ dans une alvéole de Keroman III, sortie par la rade et la passe de Port-Louis, plongée au large. Blocs K1, K2, K3, slipway et transbordeur, Dombunker, citadelle, villes en ruine. Elle se construit une fois avec `Tools/build-lorient.sh`. Détails, sources et limites : [LORIENT.md](Docs/LORIENT.md).

## Ouvrir

Pour ouvrir l’éditeur : double-cliquer sur `Ouvrir-la-demo.command`.
Pour la fenêtre de démonstration sans l’éditeur : `Jouer-la-demo.command`. Unreal 5.8.3 doit être installé dans `/Users/Shared/Epic Games/UE_5.8`.

La scène cible est `/Game/Demo/AtlanticDemo`. Le sous-marin est le modèle VIIC détaillé du jeu (celui de la touche U, sources `Sources/Detailed*.swift`), exporté depuis le code Swift. La côte est une île fictive générée localement. L’océan utilise le plugin Water d’Epic ; la lumière provient du soleil et de l’atmosphère d’Unreal.

Le mode jeu charge la scène avec une caméra libre. Il nécessite encore Unreal installé : ce n’est pas une application distribuable indépendante. Fermer la fenêtre pour quitter.

## Déplacement dans l’éditeur

Maintenir le bouton droit de la souris pour regarder autour de soi ; utiliser W/A/S/D pour se déplacer, Q/E pour descendre/monter. La molette, pendant le déplacement, ajuste la vitesse. Sur un clavier AZERTY, les touches peuvent dépendre de la configuration de l’éditeur.

## Limites

Il s’agit d’une scène d’évaluation visuelle, pas encore du portage du jeu. La navigation du sous-marin et les torpilles ne sont pas transférées. En jeu et en simulation, le sous-marin est porté par la houle mais reste sur place ; dans l’éditeur, il est montré au repos sur la flottaison du jeu. C’est un maillage unique : gouvernails, barres de plongée et hélices ne bougent pas, les périscopes sont levés. À la flottaison du jeu, les portes des tubes lance-torpilles sont sous l’eau. La côte procédurale n’est pas une reconstruction géographique ni un scan photogrammétrique.

## Réglages et matériaux

Le profil M4 utilise Lumen logiciel, une résolution interne de 70 % et un budget de textures de 1,5 Go. Les matériaux Naval conservent les couleurs et textures du modèle avec une rugosité et une réponse métallique explicites. Les couleurs du MTL sont en sRGB, comme le jeu les définit ; elles sont converties en valeurs linéaires dans les matériaux, et les textures de couleur sont importées en sRGB. AtlanticWater est une instance locale des matériaux Water ; les assets fournis par Epic ne sont pas modifiés.

## Flottaison

Le sous-marin est un corps physique Chaos de 769 t (déplacement en surface du Type VIIC), avec une boîte de collision autour de la coque. Le composant de flottabilité du plugin Water (Blueprint `/Game/Demo/Blueprints/BP_FlottaisonVIIC`) le porte par 16 flotteurs sphériques répartis sur 60 m. Chacun pousse selon son volume immergé sous la vague qui passe à cet endroit, d’où le pilonnement, le roulis et le tangage. Les réglages visent des périodes propres d’environ 4,9 s en pilonnement, 8,1 s en roulis et 5,5 s en tangage, avec une hauteur métacentrique de 0,4 m : ce sont des estimations, pas des données d’archives. Ils se trouvent en tête de `Content/Python/float_submarine.py`, que `port_submarine.py` applique après chaque import ; le script peut aussi être relancé seul.

Sur la mer de la scène, la vérification donne un pilonnement de 69 cm d’écart type, un roulis jusqu’à ±4,5° et un tangage jusqu’à ±3,5°, sans dérive. La surface moyenne des vagues de Gerstner se trouve environ 44 cm sous le niveau zéro (crêtes pointues, creux plats) : en jeu, le bateau flotte donc un demi-mètre plus bas que dans l’éditeur, à la même hauteur par rapport à l’eau.

La coque ne fait que chevaucher la géométrie statique, sans s’y heurter : la collision de la côte est une enveloppe convexe unique qui englobe aussi le mouillage du sous-marin, et l’en éjecterait. L’acteur signale aussi ses chevauchements dès le chargement du niveau, faute de quoi l’océan, où il se trouve déjà, ne se déclarerait jamais à la flottabilité.

## Régénération

w
`Tools/export-submarine.sh` exporte le modèle détaillé, ses couleurs et ses textures en OBJ/MTL dans `Import/` (ou dans le dossier passé en argument). Le modèle est rendu une fois par SceneKit avant la lecture : sans ce rendu, les primitives sortent comme des pièces provisoires d’environ 1 m et les formes extrudées sans sommets. L’export s’arrête si une pièce ne correspond pas à sa taille.

`Content/Python/port_submarine.py` remplace le sous-marin de la scène par `Import/VIIC.obj`, redressé à l’import (proue vers +X), contrôle ses dimensions, réaccorde les matériaux Naval sur le MTL (couleur, rugosité, métal), replace le bateau à la flottaison du jeu et le rend flottant (`float_submarine.py`). Le reste de la scène n’est pas modifié.

```bash
"/Users/Shared/Epic Games/UE_5.8/Engine/Binaries/Mac/UnrealEditor-Cmd" "$PWD/NordatlantikDemo.uproject" -run=pythonscript -script="$PWD/Content/Python/port_submarine.py" -unattended -nop4 -nosplash -stdout -FullStdOutLogOutput
```

`Content/Python/capture_port.py` prend six vues de contrôle dans `Saved/PortCheck` (ensemble, proue tribord, bâbord et de face, massif, poupe), en masquant l’océan pour les vues sous la flottaison, puis ferme l’éditeur sans rien enregistrer. Comme `capture_float.py`, le script empêche l’éditeur de ralentir en arrière-plan, sans quoi les captures n’aboutissent pas.

```bash
"/Users/Shared/Epic Games/UE_5.8/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor" "$PWD/NordatlantikDemo.uproject" /Game/Demo/AtlanticDemo -NoSplash -ExecCmds="py $PWD/Content/Python/capture_port.py"
```

`Content/Python/capture_float.py` lance une simulation dans l’éditeur, enregistre le mouvement du bateau dans `Saved/FloatCheck/motion.csv` avec ses statistiques dans le journal, prend 36 images, puis arrête la simulation et ferme l’éditeur sans rien enregistrer. Ne pas fermer l’éditeur de force pendant une simulation : il plante en quittant.

```bash
"/Users/Shared/Epic Games/UE_5.8/Engine/Binaries/Mac/UnrealEditor.app/Contents/MacOS/UnrealEditor" "$PWD/NordatlantikDemo.uproject" /Game/Demo/AtlanticDemo -NoSplash -ExecCmds="py $PWD/Content/Python/capture_float.py"
```

`Tools/generate-coast.py` génère la côte. `Content/Python/build_demo.py` construit le niveau dans Unreal ; un marqueur dans Saved empêche de réécrire une scène terminée. Les sources Swift et les sauvegardes du jeu existant ne sont pas modifiées.

## Variante de côte détaillée

`Jouer-cote-detaillee.command` ouvre **AtlanticCoast**, une copie de la scène avec un nouveau décor. `Ouvrir-cote-detaillee.command` ouvre cette variante dans l’éditeur. Les lanceurs habituels continuent d’ouvrir **AtlanticDemo**.

La variante reprend le sous-marin et sa flottabilité actuels. Seule la côte change : reliefs dissymétriques, falaises, criques, strates rocheuses, rivage humide et végétation rase sur les pentes douces. Le relief général reste fictif et procédural. Il reçoit désormais une texture de roche Poly Haven en 2K et huit sections rocheuses détaillées au rivage, avec quatre niveaux de détail selon la distance. Le maillage côtier n’a pas de collision dans cette démonstration de mouillage, conformément à la limitation actuelle des collisions avec la terre.

`Tools/generate-atlantic-coast.py` produit un nouvel asset d’import sans remplacer Coast.obj. `Content/Python/build_coast_variant.py` duplique le niveau et crée les assets de décor ; il refuse d’écraser une variante terminée. Il doit tourner dans l’éditeur complet avec rendu actif : un commandlet sans rendu ne régénère pas les maillages WaterInfo de l’océan. `repair_coast_water.py`, lancé avec AtlanticCoast ouvert, reconstruit ces maillages et les enregistre sans toucher aux vagues ni à la flottabilité. Les captures de contrôle vont dans `Saved/CoastCheck`, et le contrôle de flottaison distinct dans `Saved/CoastFloatCheck`.

Cette étape reste une démonstration de rendu et de flottabilité au mouillage : pas encore de vagues déferlantes sur la côte ni de navigation propulsée. Les réglages de houle de la scène originale sont conservés.

### Détails du littoral

Matériaux de roche en 2K, projection sur les parois verticales, relief de surface et bande humide irrégulière. Huit affleurements utilisent le modèle Coastal Cliff 01 et ses quatre LOD d’origine, sans superposer ces versions. Les rochers restent décoratifs et ne modifient ni la houle ni la flottabilité. AtlanticDemo et la scène Bismarck restent inchangées.

Reconstruction dans l’éditeur complet, AtlanticCoast ouvert : `Content/Python/install_coast_detail.py`. Contrôle visuel : `capture_coast_pbr.py`. Aperçus dans `Docs/Atlantic-coast-ensemble.png` et `Docs/Atlantic-coast-roche.png`. Sources des assets : `Docs/ASSETS-LITTORAL.md`. Étapes restantes pour jouer : `Docs/VERS-JEU-JOUABLE.md`.

### Ambiance sonore

La version jouable comprend désormais un moteur lié au régime, des vagues de surface et une ambiance sous-marine, avec une création sonore synthétisée de caractère cinématographique. **F6** : son activé/coupé ; **F7/F8** : volume (Fn si nécessaire). Réglages sauvegardés. Détails : [SONS.md](Docs/SONS.md).
