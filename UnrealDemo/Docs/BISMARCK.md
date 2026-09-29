# Bismarck — 27 septembre 2026

Le cuirassé Bismarck tel qu’il appareille pour l’opération Rheinübung (mai 1941), à la mer dans son propre niveau Unreal, `/Game/Bismarck/AtlanticBismarck`. Ce niveau est une copie d’AtlanticDemo (océan, île, ciel, VIIC) où le Bismarck est stoppé à 430 m de la caméra de départ, au-delà du sous-marin. AtlanticDemo, AtlanticCoast, le VIIC et leurs scripts ne sont pas modifiés : leurs empreintes SHA-256 sont comparées avant et après chaque portage (`bismarck-port.json`).

- Ouvrir : `Ouvrir-bismarck.command` ; jouer : `Jouer-bismarck.command`.
- Modèle : `Sources/Bismarck/` (Swift/SceneKit, hors du jeu) ; contrôles et vues : `scripts/render-bismarck.sh`.
- Export : `Tools/export-bismarck.sh` → `Import/Bismarck/` (OBJ, MTL, 3 textures, `Bismarck.json` avec les peintures et l’hydrostatique).
- Portage : `Tools/port-bismarck.sh` (éditeur complet, se ferme seul) → assets dans `/Game/Bismarck`, niveau `AtlanticBismarck`.
- Contrôle en simulation : `Tools/port-bismarck.sh capture_bismarck.py` → `Saved/BismarckCheck`.

## Sources et fidélité

Données officielles (kbismarck.com) : 250,50 m hors tout, 241,55 m à la flottaison, 36,00 m de large, creux 15,00 m, coefficients de bloc 0,55, de maître-couple 0,97 et de flottaison 0,66 (5 740 m²), tourelles aux couples 192,55 / 174,35 / 64,35 / 46,15. Le reste est relevé sur le plan au 1/1000 de Manuel P. González López « Bismarck, 24 mai 1941 » (profil et plan de pont) : tonture, contour du pont, livrée, emplacement de chaque affût et silhouette des superstructures. Le plan a servi de mesure uniquement ; il n’est pas copié dans le projet.

- Coque : couples ajustés aux coefficients officiels (Cb 0,544, Cwp 0,665, Cm 0,970 au tirant d’eau de projet de 9,33 m) ; 49 264 t à la flottaison du modèle (10,0 m). Voûte, étrave, quilles de roulis, trois hélices, deux safrans, écubiers, ancres et chaînes, rambardes.
- Armement : 8 × 38 cm (Anton, Bruno, Caesar, Dora), 12 × 15 cm, 16 × 10,5 cm, 16 × 3,7 cm, 12 × 2 cm simples et 2 Flakvierling, pièces au repos dans l’axe comme sur le plan.
- Superstructures : tour avant et passerelles, télémètres et radars FuMO 23, cheminée et sa coiffe, grand mât, hangar et catapulte, projecteurs, grues, embarcations. Le profil du modèle suit celui du plan à moins d’un mètre, hors éléments fins (mâts, antennes, rambardes).
- Livrée : celle du 24 mai 1941 par défaut (bandes baltiques recouvertes de gris, dessus des tourelles gris, fausse vague d’étrave conservée), pavillon de guerre à la corne ; livrée du 21 mai en option (voir « Marques nationales et livrées »).

## Passe de détail (27 septembre, après-midi)

Références : plan de González López lu pixel par pixel (livrée, hublots, ceinture, zones d’acier du pont, grue, coiffe de cheminée), pages techniques de kbismarck.com (armement, conduite de tir, équipement : 4 ancres dont une à la poupe bâbord, 7 projecteurs, 16 radeaux, 4 grues, 6 paravanes), NavWeaps (tourelles de 38 cm, affûts de 10,5 cm), photo du Bundesarchiv 193-04-1-26 et maquette au 1/50 de la tourelle Berta (Wikimedia Commons). Les modèles 3D gratuits trouvés (Sketchfab) ont été écartés : silhouettes fausses ou modèles de jeu peu détaillés.

- Coque : bandes du camouflage baltique repeintes (paires gris foncé et gris clair, positions et inclinaisons du plan), fausses vagues d’étrave (blanche) et de poupe (grise), arête de la ceinture blindée à 12,4 m entre les couples 31,7 et 205,3, les 46 hublots du plan avec leurs sourcils, échelons soudés à la poupe, coulures de rouille et salissures ; ancre de poupe à bâbord.
- Tourelles de 38 cm redessinées (plaques supérieures inclinées des flancs, de l’arrière et de la face, capots du télémètre avec leur fenêtre, capots de périscopes, champignons d’aération, écoutille, échelle) ; tourelles de 15 cm de même, télémètres de 6,5 m sur les tourelles centrales.
- Affûts de 10,5 cm : Dop. L. C/31 à l’avant (bouclier court), C/37 à l’arrière (bouclier haut couvrant à demi les culasses) ; 3,7 cm, 2 cm et quadruples détaillés.
- Superstructures : garde-corps sur tous les ponts et plateformes, portes étanches, grilles de ventilation, échelles verticales et inclinées, vitres de la passerelle et de la passerelle amiral, fentes de vision du blockhaus, télémètres de nuit, directeurs SL-8 découverts à l’arrière, projecteur du mât avant, coiffe de cheminée plus claire avec tuyaux de sirènes, grues (dont deux petites sous la plateforme de la cheminée), catapulte en treillis, embarcations avec cabines ou tauds, 16 radeaux.
- Pont : lattes de teck de teintes variées, zones d’acier (étrave, poupe, arcs sous le souffle des tourelles de 15 cm), bittes, chaumards, champignons d’aération, panneaux, coffres à munitions, six paravanes.
- Mâture : antennes filaires entre les mâts, haubans, étais, mâts de beaupré et de pavillon.
- Matériaux Unreal : cartes de normales (joints et soudures de tôles, arête de ceinture, hublots ; rainures du teck ; panneaux et hublots des superstructures).

## Marques nationales et livrées

Pour la fidélité historique du simulateur, le navire porte les marques de mai 1941, datées d’après les plans de González López et la chronologie de kbismarck.com :

- **Pavillon de guerre** (Reichskriegsflagge 1938–1945, dessiné d’après sa spécification, fichier SVG de Wikimedia Commons) hissé à la corne du grand mât, 2,4 × 4 m, les deux faces modélisées (endroit vu de bâbord, envers vu de tribord). Dans Unreal, il ondule au vent (déplacement des sommets par le matériau). Présent dans les deux livrées.
- **Livrée « 24mai »** (par défaut) : opération Rheinübung, Détroit de Danemark. Bandes baltiques et marques de pont repeintes en gris le 21–22 mai (bandes grises visibles sur la coque).
- **Livrée « 21mai »** : entrée dans le Korsfjord. Bandes noires et blanches sur la coque, extrémités gris foncé, fausses vagues blanches, et marques d’identification aérienne sur le gaillard et la plage arrière (pont peint en rouge, disque blanc de 5,1 m, croix gammée noire de 6,8 m), repeintes en gris le 22 mai.

Changer de livrée sans réimporter : `Tools/port-bismarck.sh livery_bismarck.py 21mai` (ou `24mai`). Un portage complet prend aussi la livrée en argument : `Tools/port-bismarck.sh port_bismarck.py 21mai`.

## Flottaison

`Content/Python/float_bismarck.py`, sur le même principe que le VIIC : corps Chaos de 49 264 t sur une boîte de collision autour de la coque, 20 flotteurs du plugin Water dimensionnés à partir de l’hydrostatique de la coque exportée (volume, flottaison, centre de carène, rayons métacentriques). GM retenu : 3,9 m (estimation), d’où KG = 11,2 m au-dessus de la quille. Périodes propres : pilonnement 5,8 s, roulis 13,9 s, tangage 6,7 s. Le navire est stoppé : pas de propulsion, pas d’ancre.

Contrôle en simulation (`capture_bismarck.py`, 100 s après 10 s de mise en eau, houle de Gerstner de la scène) : navire dans l’eau en permanence, pilonnement de 14 à 18 cm d’écart type selon les essais (étendue 70 cm), roulis de 0,5° (±1,2° au plus), tangage de 0,06°, cap stable à 0,3° près, dérive inférieure à 4 cm. Il flotte à 3 mm près sur le niveau moyen de l’eau mesuré sous ses flotteurs (−41 cm, dû aux vagues de Gerstner). Ce sont des mouvements faibles, attendus pour un navire de 250 m dans des vagues de 40 à 60 m. Vues et série d’images : `Saved/BismarckCheck` ; sélection dans `Docs/Bismarck-*.jpg`, `Bismarck-houle.gif` et `Bismarck-profil.png`.

Deux défauts corrigés en route :
- Le composant de flottabilité, ajouté dans la session même où son Blueprint avait été créé, avait été enregistré dans le niveau avec 0 flotteur : le navire coulait. `float_bismarck.py` vérifie désormais le nombre de flotteurs de l’instance et la recrée si besoin.
- Le modèle SceneKit a la proue vers +Z (image miroir dans le repère de SceneKit), alors que VIIC.obj a la proue vers −Z : le Bismarck arrivait retourné dans Unreal. L’export inverse z (avec normales et ordre des sommets) ; le portage vérifie la proue par la position du grand mât, le point le plus haut (x = −19,3 m).

Un portage échoué a aussi appris que dupliquer la carte puis l’ouvrir dans la même session arrête l’éditeur (fuite de monde) : la copie se fait par un enregistrement sous un autre nom, au premier passage.

## Limites et doutes

- Plan de González López : utilisé pour les mesures seulement.
- Formes de carène sous la flottaison : reconstruites à partir des coefficients officiels, pas relevées.
- GM de 3,9 m et rayons de giration : estimations ; ils fixent les périodes de roulis et de tangage.
- Restent simplifiés ou absents : hydravions Arado 196 (aucun sur la catapulte sur le plan du 24 mai), échelles de coupée, troisième ancre d’étrave (position incertaine), radars et télémètres encore schématiques de près, pas d’animation des tourelles ni des hélices. Portes, grilles et radeaux sont placés de façon plausible, pas relevés un à un.
- Maillage unique de 210 000 triangles, sans Nanite ni LOD, textures jusqu’à 8192 px.
- Le Bismarck n’existe que dans AtlanticBismarck ; AtlanticDemo et AtlanticCoast restent inchangés.
