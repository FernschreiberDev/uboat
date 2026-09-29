# Ambiance sonore — 28 septembre 2026

Création sonore stéréo synthétisée, au caractère présent et cinématographique choisi pour cette version. Aucun enregistrement ni échantillon tiers : pas de téléchargement ou de licence sonore supplémentaire. Il ne s’agit pas d’un enregistrement historique de moteur VIIC.

- Moteur : pulsations graves, vibrations et bruit mécanique suivant le régime effectif des arbres, y compris ralentissement et inversion. Un timbre électrique remplace progressivement le diesel lorsque le bateau s’immerge.
- Surface : souffle marin, vagues irrégulières et bruit d’écoulement renforcé avec la vitesse.
- Sous l’eau : grondement et remous plus graves ; les aigus s’atténuent progressivement selon la hauteur de la caméra. La transition se fait autour du niveau moyen de la mer, pas sur chaque crête individuelle.
- Distance : le moteur s’atténue lorsque la caméra s’éloigne du bateau.
- Pause et silence : fondu court, sans arrêt brutal du signal. À l’arrêt des moteurs, l’ambiance marine reste présente.

**F6** coupe/rétablit le son. **F7/F8** règlent le volume par pas de 10 %. Utiliser Fn avec les touches F si macOS les réserve aux commandes multimédias. M et les touches du pavé numérique sont aussi reliées au son ; utiliser de préférence F6/F7/F8 pour éviter les différences de disposition du clavier. Le niveau et la coupure sont sauvegardés avec la partie, sans invalider les anciennes sauvegardes. Le volume initial est 75 %. La barre du bas affiche le réglage.

Les sons sont créés en continu, sans boucle courte répétée. Les changements de paramètres sont lissés et la sortie est limitée pour éviter la saturation numérique. Le mixage suit une perspective extérieure : cette étape n’ajoute pas de compartiments intérieurs acoustiques, d’hydrophone, de parole d’équipage ou de musique.

Validation : test autonome `Tests/ocean-sound.cpp` (signal stéréo fini, marge avant saturation, variation moteur/surface/immersion, extinction en silence). L’argument `-VoyageAudioTest` vérifie que le mélangeur Unreal appelle la génération audio et reçoit des échantillons non nuls dans un emplacement de sauvegarde distinct.
