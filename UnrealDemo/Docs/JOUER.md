# Jouer à Nordatlantik — exploration Unreal

Double-cliquer sur **Jouer-a-Nordatlantik.command**, dans le dossier UnrealDemo. La fenêtre démarre directement aux commandes du VIIC. Cliquer dans l’image pour donner le clavier au jeu. Unreal 5.8.3 doit rester installé ; ce lanceur n’est pas encore une application Mac autonome.

La nouvelle carte AtlanticVoyage est séparée des démonstrations AtlanticDemo et AtlanticCoast. Le jeu SceneKit reste disponible. Le modèle et la flottabilité de surface du VIIC sont réutilisés.

## Commandes

| Action | Touches |
|---|---|
| Augmenter le moteur | Z, W ou flèche haut, maintenir |
| Réduire le moteur, puis marche arrière | S ou flèche bas, maintenir |
| Virer | Q/A/gauche et D/droite |
| Couper les moteurs | X ; le bateau conserve son inertie |
| Augmenter la profondeur cible | F, maintenir |
| Réduire la profondeur cible | R, maintenir |
| Revenir à la surface | P |
| Tourner la caméra | Glisser avec un bouton de souris enfoncé |
| Zoom | Molette |
| Recentrer la caméra | C |
| Vues des hélices/gouvernails, puis barres avant | G |
| Comparer modèle articulé / modèle fixe | V |
| Choisir un objectif | Tab |
| Afficher/masquer les commandes | H |
| Couper / rétablir le son | F6 |
| Volume sonore | F7 / F8 |
| Pause/reprise | Espace ou Échap |
| Sauvegarder | F5 (Fn+F5 selon le clavier) |
| Retour au mouillage, progression conservée | Home (Fn+flèche gauche sur clavier Mac compact) |
| Nouvelle exploration | Maj+Home |
| Quitter | Cmd+Q ou fermer la fenêtre |

## Première sortie

Avancer vers la balise orange, à 350 m au nord du départ. La carte en bas à gauche est orientée nord en haut ; ses numéros correspondent aux trois découvertes. Tab sélectionne l’objectif dont la distance et la profondeur sont affichées.

L’épave est au nord-est, à 45 m sous la surface : maintenir F pour régler la cible vers 45 m, puis relâcher et laisser le sous-marin se stabiliser. Utiliser P pour remonter. Le troisième objectif est un rendez-vous près du Bismarck, au sud du départ. Une découverte se valide à moins de 85 m horizontalement et avec moins de 12 m d’écart de profondeur. Après les trois découvertes, la navigation reste libre.

La puissance reste au réglage choisi après relâchement de Z/S. Anticiper les virages et l’arrêt. La protection contre le fond, la côte et les obstacles arrête les moteurs avant contact ; elle ne simule pas les dégâts d’un échouage. La zone de jeu a un rayon de 2 km et la profondeur cible est limitée à 120 m.

## Sauvegarde

Sauvegarde automatique toutes les 15 secondes, à chaque découverte, en pause et à la fermeture normale. La prochaine ouverture reprend la position, la profondeur cible, les découvertes et la distance, avec les moteurs à zéro.

Fichier : `Saved/SaveGames/NordatlantikVoyage_v1.sav`. Les essais utilisent des fichiers distincts `NordatlantikVoyage_Test.sav` et `NordatlantikVoyage_InputTest.sav`. Les sauvegardes SceneKit ne sont pas utilisées.

## Ce que cette version simule

Exploration pilotable, houle et flottabilité de surface existantes, inertie, virages, plongée assistée, caméra extérieure, repères, progression et sauvegarde. Le Bismarck est un repère immobile dans cette carte ; sa propre scène conserve sa simulation de flottabilité améliorée.

La plongée est un asservissement de profondeur simplifié, pas une reproduction complète des ballasts et des barres du VIIC. L’épave et la balise sont des repères provisoires. Restent à développer : instruments et périscope jouables, sillages, détails sous-marins, navires autonomes, torpilles et combat, ainsi que la livraison en application autonome. Le réalisme intégral n’est pas atteint.

Les hélices, gouvernails et barres de plongée sont maintenant articulés. Leur fonctionnement, leurs limites et les références sont décrits dans [ORGANES-MOBILES.md](ORGANES-MOBILES.md).

Ambiance cinématographique dynamique : moteurs, vagues et immersion. Réglages et limites : [SONS.md](SONS.md).
