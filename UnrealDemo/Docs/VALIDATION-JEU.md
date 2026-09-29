# Validation de la version jouable — 27 septembre 2026

Mac mini M4, 16 Go, Unreal Engine 5.8.3. Module C++ compilé en Development Editor pour Apple Silicon. Essais dans une vraie fenêtre de jeu 1600 × 900, avec rendu Metal. Le lanceur utilise l’installation locale d’Unreal.

## Parcours de simulation

Résultat : PASS, journal conservé dans `voyage-runtime-validation.log`.

- Propulsion : déplacement de plus de 25 m en 10 s ; vitesse mesurée 17,2 nd à pleine puissance en surface.
- Virage : cap passé d’environ −90° à −49° en 10 s avec gouverne à 80 %.
- Plongée cible 15 m : 13,7 m après 10 s, 14,9 m après 20 s. Roulis et tangage stabilisés près de zéro sans changement de cap incontrôlé.
- Remontée : retour à moins de 1,5 m, contrôle de profondeur désactivé et reprise de la flottabilité d’origine. Les vagues font ensuite varier la profondeur instantanée.
- Tests de garde : point de départ navigable, terrain central refusé, limite de zone et profondeur excessive refusées.
- Trois découvertes et sauvegarde : PASS. Le test utilise des déplacements instantanés pour vérifier les trois déclencheurs ; il ne constitue pas un parcours manuel complet entre les objectifs.
- Nouvelle session de jeu : reprise des trois découvertes et de la distance sauvegardée, PASS (`Saved/VoyageTests/resume.txt`).

Le test de mouvement pilote les paramètres de propulsion dans le code de test ; il ne simule pas un utilisateur maintenant les touches. Ce n’est ni un essai d’endurance ni une validation hydrodynamique historique.

## Commandes dans la fenêtre

Vérifiés au clavier : pause/reprise par Espace, changement d’objectif par Tab, aide par H, retour au mouillage par Home, sauvegarde F5 et fermeture normale Cmd+Q. F5 n’active plus le mode de diagnostic graphique d’Unreal. Le texte de l’interface a été agrandi et contrôlé à l’écran. Le lanceur livré a ensuite ouvert la partie normale, laissée en pause au mouillage (0/3 découvertes), prête à reprendre.

L’outil de contrôle n’a pas réussi à envoyer les gestes souris à cette fenêtre ; rotation et zoom ne sont donc pas validés par un essai manuel automatisé. Les touches maintenues de propulsion et de plongée restent à confirmer par un essai utilisateur ; la simulation correspondante passe le parcours ci-dessus.

## Préservation

L’audit final retrouve dans AtlanticCoast les mêmes 19 acteurs, classes, maillages, tags, modes de collision et absence de mode de jeu que dans la copie intacte précédant les ajouts. La carte a été réenregistrée : son empreinte binaire diffère. Les huit acteurs de jeu se trouvent seulement dans AtlanticVoyage (27 acteurs au total).

Les empreintes du niveau AtlanticDemo, du maillage VIIC, du Blueprint de flottabilité VIIC et de float_submarine.py sont inchangées depuis le contrôle initial. Les assets Bismarck ont évolué avant la reprise de ce travail ; ils ont été conservés tels que retrouvés, avec leurs améliorations récentes. Le contrôle `voyage-preserved-current.json` confirme qu’ils n’ont pas changé pendant les derniers essais de jeu.

Copies de récupération dans `Saved/VoyageRecovery`, audit initial dans `voyage-copy-audit.json`, audit final dans `voyage-final-audit.json`. Aucune sauvegarde de production n’est utilisée par les tests automatiques.

## Limites restantes

Plongée assistée, collisions de protection sans dégâts, Bismarck immobile dans cette carte, épave et balise provisoires. Pas de sons, de combat, d’animation indépendante des gouvernes/hélices ni d’application empaquetée. Voir `JOUER.md` et `VERS-JEU-JOUABLE.md`.

## Organes mobiles — 28 septembre

Nouvelle représentation : sept composants visuels articulés, total 265 624 triangles, même total que le VIIC importé précédemment. Contrôles des dimensions et pivots : `articulated-import.json`. Le corps physique original reste actif et son maillage original reste disponible avec V.

Le test autonome des servocommandes vérifie les butées, la vitesse de braquage, l’inversion progressive, le retour au neutre, la pause et la cohérence à 30/120 Hz. Le premier parcours Unreal avec les pièces articulées passe propulsion, virage, plongée à 15 m, remontée, trois objectifs et marche arrière ; les hélices tournent en sens opposés. L’assiette reste stable. Les vues des organes sont disponibles avec G.

Les limites de réalisme et références sont précisées dans `ORGANES-MOBILES.md`. La mention antérieure de gouvernes/hélices figées concernait la version du 27 septembre.

Second parcours : plongée cible 30 m (29,6 m atteints), incidences des barres observées à +23°/−23°, remontée et marche arrière validées. Résultat `GEAR_RUNTIME_PASS`, journal `gear-runtime-validation.log`. Captures : `VIIC-organes-arriere.png` et `VIIC-barres-avant.png`.

La partie normale a été rouverte avec la progression existante ; les touches G (vue rapprochée) et V (comparaison avec le modèle d’origine) ont été vérifiées à l’écran.

## Ambiance sonore — 28 septembre

Compilation Apple Silicon réussie. Test DSP : sortie stéréo finie, crête 0,458 pour un volume à 75 %, transition surface/moteur/immersion puis extinction. Test dans le mélangeur Unreal : 939 008 trames générées, dont 799 282 au-dessus du seuil de signal ; résultat PASS dans `Saved/VoyageTests/audio.txt`. Ce contrôle confirme la génération du signal, pas une écoute critique ni le réglage du volume des haut-parleurs macOS. Création synthétisée, pas d’enregistrement historique.

Commandes F6/F7/F8 vérifiées dans la fenêtre de jeu : baisse à 65 %, remontée à 75 %, coupure/rétablissement. Après fermeture puis nouvelle session de test, le volume à 65 % et la coupure sont retrouvés. Les essais utilisent `NordatlantikVoyage_InputTest`, indépendamment de la partie habituelle.
