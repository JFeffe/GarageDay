# Garage Day dans Roblox Studio

Deux cartes issues de la version Godot sont disponibles. Le Petit Atelier a une baie. Le Tandem a deux ponts, deux places d’arrivée et deux stationnements de sortie. Au lancement, sélectionne **Continuer** ou **Nouvelle partie** sur la carte de ton choix. Chaque carte affiche son jour et sa caisse. Une confirmation s’affiche avant de recommencer une carte qui a déjà une partie.

Au téléphone, **F** au clavier ou **Y** à la manette rouvre ce menu avant le premier service, le soir ou après le bilan.

Le planning à l’accueil affiche les rendez-vous et leur prix. Accueille chaque client, conduis son véhicule de la place d’arrivée au pont correspondant, fais les interventions, puis gare-le sur sa place de sortie et encaisse à la caisse. Au Tandem, les deux voitures peuvent rester à des étapes différentes et passer à la caisse dans l’ordre où tu termines leur réparation.

## Journées de service

La campagne dure dix journées. Chaque journée tire un nouveau planning, et une voiture peut demander plusieurs interventions. Le téléphone permet d’ajouter un rendez-vous en cours de service.

Le tableau de service affiche la patience de chaque client. La note du jour part de cinq étoiles. Quand un client n’a plus de patience, le garage perd une demi-étoile, puis une autre toutes les dix secondes tant que sa facture reste ouverte. Les clients peuvent être servis jusqu’à la fermeture, même si la note tombe à zéro. Les notes de chaque journée alimentent le bilan final.

| Dès le jour | Interventions |
| --- | --- |
| 1 | Pneus, vidange, inspection, batterie, pression, refroidissement, essuie-glaces, feux |
| 2 | Cache moteur, plaquettes |
| 3 | Courroie, crevaison |
| 4 | Silencieux, amortisseur |
| 5 | Vitre électrique |
| 6 | Roulement |

Prépare la clé à choc, le bac de vidange, la valise de diagnostic, le manomètre, le cliquet, la sonde ou l’extracteur selon la panne. Les pannes peuvent varier au sein d’une même intervention. Une crevaison peut demander une rustine ou le remplacement de la roue. Une inspection peut mener à un devis pour la batterie.

Avec plusieurs interventions sur le bon de travail, **F** près de la portière ou **Y** à la manette permet de choisir la prochaine. Ce choix revient entre deux interventions.

Pour les pneus, chaque roue a ses propres gestes. Tu peux desserrer et déposer les quatre roues avant d’en remonter une, puis choisir l’ordre de remontage et de recyclage. Une roue desserrée tombe au sol même si tu tiens déjà un outil ou une pièce. Libère tes mains pour la ramasser et la transporter.

Les pièces lourdes se portent à deux mains et ralentissent la marche. Le chariot transporte jusqu’à quatre roues neuves. Les bacs séparent l’huile usée, les pneus, les métaux et le recyclage courant. Le poste **OBJETS RÉCUPÉRÉS** permet de retrouver certaines pièces quand un joueur quitte.

Après le dernier client, la caravane propose jusqu’à trois articles sur le parvis. La caisse sert à acheter des améliorations permanentes ou des services pour le lendemain. Le téléphone ouvre la journée suivante, puis affiche le bilan à la fin du jour 10.

Le soir, vise un meuble et utilise l’invite **Déplacer ou pivoter**. Déplace son aperçu, pivote-le par quarts de tour et dépose-le à un emplacement libre. Les outils et les interactions des postes suivent le mobilier.

## Sauvegarde automatique

Chaque carte a sa propre sauvegarde avec son jour, son planning, ses factures, sa caisse, ses achats, ses étoiles, sa patience et son aménagement. Une sauvegarde antérieure apparaît automatiquement sous la carte où la partie était enregistrée. À la reprise, les clients dont la facture est ouverte reviennent à l’accueil. En fin de service, la caravane retrouve ses offres du soir. En coop, le premier joueur arrivé choisit la partie et conserve la progression. Chaque joueur conserve son propre réglage de souris.

Dans le fichier local de Studio, la sauvegarde passe par le plugin Garage Day - Sauvegarde locale. Sur une autre machine, place le fichier `Garage Day - Sauvegarde locale.rbxmx` généré par la compilation dans le dossier des plugins locaux de Studio, puis relance Studio. Une expérience hébergée utilise les Data Stores Roblox. Les essais dans une expérience publiée depuis Studio utilisent un espace de stockage dédié. [Documentation des Data Stores Roblox](https://create.roblox.com/docs/cloud-services/data-stores)

## Commandes

À pied, les gants et les objets tenus sont visibles en première personne. Utilise **E** au clavier, **X** à la manette ou l’invite tactile. **Q**, **B** ou **Poser** dépose l’objet que tu tiens ou lâche le chariot. Il faut libérer tes mains pour reprendre un outil, prendre une pièce ou conduire. L’invite **Ranger** permet de rapporter un outil à son poste. Les devis ont leur propre invite pour reporter l’intervention.

En réaménagement, **E** dépose, **R** pivote et **Q** annule. À la manette, utilise **X**, **LB** et **B**. Les mêmes actions apparaissent à l’écran sur mobile.

**O** ouvre les options. Le curseur règle la sensibilité de la souris de **20 % à 130 %**, avec une valeur par défaut de **55 %**. Les trois portes piétonnes s’ouvrent à l’approche et se referment une fois le passage dégagé.

Au volant, la caméra passe derrière la berline. Utilise **WASD** ou les flèches, le stick gauche ou les commandes tactiles pour conduire. Relâche l’accélérateur sur la place indiquée, puis valide avec **E**, **X** ou le bouton à l’écran. Pour descendre en cours de trajet, arrête-toi et utilise **Q**, **B** ou **Descendre**.

## Ouvrir et tester

Ouvre `build/roblox/Garage Day.rbxlx` dans Roblox Studio et clique sur **Play**. Choisis une partie à l’accueil pour charger l’atelier. Pour une partie à deux, choisis **Server & Clients** avec deux clients dans les modes de test de Studio. Chaque joueur a sa vue et les opérations sur la voiture sont partagées.

Pour reconstruire le fichier depuis la racine, utilise Node.js et [Rojo](https://rojo.space/docs/v7/getting-started/installation/) 7.6 ou plus récent.

```powershell
Set-Location roblox
npm ci
npm run build
```

Les scripts se trouvent dans `src/`. Le serveur gère la journée, la circulation des clients, la conduite et les réparations partagées. Les joueurs voient l’étape en cours et la recette sur leur tableau de service. Tu peux utiliser `rojo serve` après `npm run assets` pour synchroniser les modifications dans Studio.

## Modèles du garage

La construction reprend les GLB des berlines classique et sport, du pont, du moteur, des roues, du silencieux, de la caravane, des outils et du mobilier. Le parvis, la façade et les maisons s’éclairent à la fermeture. Le serveur prépare les modèles au démarrage. Si les API de maillage sont indisponibles, le jeu charge des formes de remplacement. Les attributs `OriginalModels` et `OriginalServiceModels` du modèle de la carte indiquent que les modèles principaux et les éléments d’intervention ont été chargés.

Les crédits et les licences des modèles sont dans le [README de Garage Day](../README.md#cr%C3%A9dits-des-assets). Pour tester une future version hébergée avec les modèles originaux, configure le réglage **Mesh / Image APIs** du projet ou importe les GLB dans Studio. [Règles des maillages éditables](https://create.roblox.com/docs/reference/engine/classes/EditableMesh)

## Vérifier les règles de service

Depuis la racine du dépôt, lance `luau roblox/tests/repair.luau` et `luau roblox/tests/save.luau` avec la CLI Luau. [Télécharger la CLI Luau](https://github.com/luau-lang/luau/releases)
