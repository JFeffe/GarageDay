# Garage Day dans Roblox Studio

Le Petit Atelier reprend le plan de la première carte Godot, avec son bureau, sa salle d’attente, ses comptoirs, sa baie de réparation et ses places extérieures. Utilise le téléphone pour ouvrir le service. Le planning à l’accueil affiche les rendez-vous et leur prix. Accueille chaque client, conduis son véhicule d’A 01 à la baie 01, fais l’intervention, gare-le en P 01, puis encaisse à la caisse.

## Journées de service

- **Camille, plaquettes avant.** Lève le pont, dépose les deux roues avant et remplace leurs plaquettes.
- **Noah, pression des pneus.** Mesure la pression à l’arrière droit, gonfle le pneu et vérifie les 34 psi au manomètre.
- **Léa, vidange.** Prends un bac, récupère et vide l’huile usée, puis remplis le moteur sous le capot et recycle le bidon vide.
- **Alex, batterie.** Retire et recycle la batterie usée, prends une neuve à l’étagère ÉLECTRICITÉ, installe-la et teste le démarrage.

Le téléphone ouvre la journée suivante après le départ du dernier client. Les trois plannings reviennent à tour de rôle et la caisse conserve les recettes pendant la session. À deux, préparez les pièces et partagez les interventions. Si un mécano réapparaît ou quitte la partie avec du matériel, son équipier peut le récupérer au poste indiqué.

À pied, joue à la première personne et utilise **E** au clavier, **X** à la manette ou l’invite tactile. À deux, partagez les étapes de la journée et les outils de réparation. Au volant, la caméra passe derrière la berline. Utilise **WASD** ou les flèches, le stick gauche ou les commandes tactiles pour conduire. Relâche l’accélérateur sur la place indiquée, puis valide avec **E**, **X** ou le bouton à l’écran. Pour descendre en cours de trajet, arrête-toi et utilise **Q**, **B** ou **Descendre**.

## Ouvrir et tester

Ouvre `build/roblox/Garage Day.rbxlx` dans Roblox Studio et clique sur **Play**. L’atelier s’installe au démarrage du test. Pour une partie à deux, choisis **Server & Clients** avec deux clients dans les modes de test de Studio. Chaque joueur a sa vue et les opérations sur la voiture sont partagées.

Pour reconstruire le fichier depuis la racine, utilise Node.js et [Rojo](https://rojo.space/docs/v7/getting-started/installation/) 7.6 ou plus récent.

```powershell
Set-Location roblox
npm ci
npm run build
```

Les scripts se trouvent dans `src/`. Le serveur gère la journée, la circulation des clients, la conduite et les réparations partagées. Les joueurs voient l’étape en cours et la recette sur leur tableau de service. Tu peux utiliser `rojo serve` après `npm run assets` pour synchroniser les modifications dans Studio.

## Modèles du garage

La construction reprend les GLB des berlines classique et sport, de leurs capots, du pont, des disques de frein, du moteur, de la batterie, de l’outillage et du mobilier. Elle conserve leur géométrie et applique les couleurs des matériaux en échantillonnant les textures par triangle. Le serveur prépare les modèles au démarrage. Si les API de maillage sont indisponibles, le jeu charge des formes de remplacement. Les attributs `OriginalModels` et `OriginalServiceModels` du modèle `Le Petit Atelier` indiquent que les modèles principaux et les éléments d’intervention ont été chargés.

Les crédits et les licences des modèles sont dans le [README de Garage Day](../README.md#cr%C3%A9dits-des-assets). Pour tester une future version hébergée avec les modèles originaux, configure le réglage **Mesh / Image APIs** du projet ou importe les GLB dans Studio. [Règles des maillages éditables](https://create.roblox.com/docs/reference/engine/classes/EditableMesh)

## Vérifier les règles de service

Depuis la racine du dépôt, lance `luau roblox/tests/repair.luau` avec la [CLI Luau](https://github.com/luau-lang/luau/releases).
