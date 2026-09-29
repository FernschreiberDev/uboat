# Version jouable et prochaines étapes

État au 27 septembre 2026. Une première exploration Unreal est maintenant implémentée dans **AtlanticVoyage**, distincte des démonstrations existantes et du jeu SceneKit. Démarrage : `Jouer-a-Nordatlantik.command`. Commandes : [JOUER.md](JOUER.md).

## Disponible

- Pilotage physique du VIIC en surface : moteur, inertie, marche arrière et gouverne ; flottabilité et houle existantes conservées.
- Plongée assistée de 0 à 120 m et retour à la surface, avec stabilisation et caméra extérieure suivant l’immersion.
- Trois découvertes : balise, épave à 45 m et rendez-vous près du Bismarck ; navigation libre après la fin.
- Vitesse, cap, profondeur, puissance, objectif et petite carte ; aide, pause, retour au mouillage et nouvelle partie.
- Sauvegarde/reprise distincte du jeu SceneKit.
- Protection contre le terrain, le fond et la limite de zone. Elle arrête le bateau avant contact ; pas de simulation de dégâts.

Le Bismarck est immobile dans la carte d’exploration. Sa scène AtlanticBismarck et ses derniers réglages de flottabilité restent séparés et conservés.

## Réalisme à approfondir

La plongée utilise un contrôle de profondeur simplifié. Restent à modéliser les ballasts, les barres de plongée et leur effet hydrodynamique, la consommation et les limites opérationnelles. Les hélices, gouvernails et barres de plongée sont maintenant séparés et animés dans la carte jouable, avec commandes progressives. Voir [ORGANES-MOBILES.md](ORGANES-MOBILES.md).

L’épave et la balise servent de repères provisoires. Restent à enrichir les fonds, le rivage, les sillages et l’écume. La houle de Gerstner ne produit pas à elle seule des vagues déferlantes physiquement simulées. Aucun réalisme historique intégral n’est revendiqué.

## Pour aller au-delà de l’exploration

Périscope et instruments utilisables, hydrophones/détection, solutions de tir, torpilles, navires avec comportement autonome, dégâts, réparations et missions. Ces systèmes ne sont pas présents dans cette version.

## Livraison

Le lanceur utilise Unreal 5.8.3 installé sur ce Mac. Une application autonome, les profils de qualité M4/M1 Max et les essais prolongés restent à produire. Les validations de cette version sont consignées dans `VALIDATION-JEU.md`.

Ambiance sonore ajoutée le 28 septembre : moteur lié au régime, vagues et transition sous-marine ; volume et silence sauvegardés. Voir [SONS.md](SONS.md).
