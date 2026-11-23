# Garage Day dans Roblox Studio

Le Petit Atelier reprend le plan de la première carte Godot, avec son bureau, sa salle d’attente, ses comptoirs, sa baie de réparation et ses places extérieures. Utilise le téléphone pour ouvrir le service. Le planning à l’accueil affiche les rendez-vous et leur prix. Accueille chaque client, conduis son véhicule d’A 01 à la baie 01, fais l’intervention, gare-le en P 01, puis encaisse à la caisse.

## Journées de service

Chaque journée tire un nouveau planning. Une voiture peut demander plusieurs interventions. La caisse verse la facture une fois le véhicule réparé et stationné. Le téléphone permet d’ajouter un rendez-vous en cours de service.

| Dès le jour | Interventions |
| --- | --- |
| 1 | Pneus, vidange, inspection, batterie, pression, refroidissement, essuie-glaces, feux |
| 2 | Cache moteur, plaquettes |
| 3 | Courroie, crevaison |
| 4 | Silencieux, amortisseur |
| 5 | Vitre électrique |
| 6 | Roulement |

Prépare la clé à choc, le bac de vidange, la valise de diagnostic, le manomètre, le cliquet, la sonde ou l’extracteur selon la panne. Les pannes peuvent varier au sein d’une même intervention. Une crevaison peut demander une rustine ou le remplacement de la roue. Une inspection peut mener à un devis pour la batterie.

Les roues démontées peuvent être ramassées, posées, transportées à l’établi ou déposées au recyclage. Le chariot transporte jusqu’à quatre roues neuves. Les bacs séparent l’huile usée, les pneus, les métaux et le recyclage courant. À deux, les rôles se partagent entre conduite, outillage et pièces. Le poste **OBJETS RÉCUPÉRÉS** permet de retrouver les pièces déposées quand un joueur quitte.

Après le dernier client, la caravane propose jusqu’à trois articles sur le parvis. La caisse sert à acheter des améliorations permanentes ou des services pour le lendemain. Le téléphone ouvre la journée suivante.

## Sauvegarde automatique

Le jeu conserve le jour, le planning, les factures encaissées, la caisse et les achats à la caravane. À la reprise, le premier client dont la facture est encore ouverte revient à l’accueil. Si le service était terminé, la caravane reste disponible avec ses offres du soir. En coop, la progression appartient à l’atelier du premier joueur arrivé. Chaque joueur conserve son propre réglage de souris.

Dans le fichier local de Studio, la sauvegarde passe par le plugin Garage Day - Sauvegarde locale. Sur une autre machine, place le fichier `Garage Day - Sauvegarde locale.rbxmx` généré par la compilation dans le dossier des plugins locaux de Studio, puis relance Studio. Une expérience hébergée utilise les Data Stores Roblox. Les essais dans une expérience publiée depuis Studio utilisent un espace de stockage dédié. [Documentation des Data Stores Roblox](https://create.roblox.com/docs/cloud-services/data-stores)

## Commandes

À pied, les gants et les objets tenus sont visibles en première personne. Utilise **E** au clavier, **X** à la manette ou l’invite tactile. **Q**, **B** ou **Poser** dépose une pièce ou lâche le chariot. Les invites du chariot indiquent la commande pour charger ou prendre une roue. Les devis ont une commande distincte pour reporter l’intervention.

**O** ouvre les options. Le curseur règle la sensibilité de la souris de **20 % à 130 %**, avec une valeur par défaut de **55 %**. Les trois portes piétonnes s’ouvrent à l’approche et se referment une fois le passage dégagé.

Au volant, la caméra passe derrière la berline. Utilise **WASD** ou les flèches, le stick gauche ou les commandes tactiles pour conduire. Relâche l’accélérateur sur la place indiquée, puis valide avec **E**, **X** ou le bouton à l’écran. Pour descendre en cours de trajet, arrête-toi et utilise **Q**, **B** ou **Descendre**.

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

La construction reprend les GLB des berlines classique et sport, du pont, du moteur, des roues, du silencieux, de la caravane, des outils et du mobilier. Le parvis, la façade et les maisons s’éclairent à la fermeture. Le serveur prépare les modèles au démarrage. Si les API de maillage sont indisponibles, le jeu charge des formes de remplacement. Les attributs `OriginalModels` et `OriginalServiceModels` du modèle `Le Petit Atelier` indiquent que les modèles principaux et les éléments d’intervention ont été chargés.

Les crédits et les licences des modèles sont dans le [README de Garage Day](../README.md#cr%C3%A9dits-des-assets). Pour tester une future version hébergée avec les modèles originaux, configure le réglage **Mesh / Image APIs** du projet ou importe les GLB dans Studio. [Règles des maillages éditables](https://create.roblox.com/docs/reference/engine/classes/EditableMesh)

## Vérifier les règles de service

Depuis la racine du dépôt, lance `luau roblox/tests/repair.luau` et `luau roblox/tests/save.luau` avec la CLI Luau. [Télécharger la CLI Luau](https://github.com/luau-lang/luau/releases)
