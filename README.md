# Garage Day

Garage Day est un jeu de gestion de garage miniature à jouer à la manette ou au clavier. Accueille les clients, rentre leurs voitures, répare-les et protège ta réputation pendant dix jours. Entre deux services, réaménage l’atelier et choisis parmi les offres de la fourgonnette.

**[Jouer à Garage Day dans le navigateur](https://jfeffe.github.io/GarageDay/)**

## Jouer à deux dans le navigateur

Choisis un garage et clique sur **Héberger à deux**. Copie le lien dans la barre de la partie et transmets-le à ton invité. L’hôte garde son onglet ouvert. Vous partagez la caméra. L’invité peut accueillir, réparer, utiliser les comptoirs et encaisser. L’hôte conduit, choisit les pièces au rayon et gère le chariot, l’aménagement et les menus.

La partie hébergée est sauvegardée dans le navigateur de l’hôte en atelier libre et avant l’ouverture. **Reprendre comme hôte** permet de reprendre cette sauvegarde avec un nouveau lien. Une interruption pendant le service ramène au début de ce service. Le partage transmet l’image du jeu à l’invité. La connexion WebRTC est négociée via PeerServer Cloud et dépend du réseau des deux joueurs. [Documentation PeerJS](https://peerjs.com/client/getting-started) · [Licence MIT](web/vendor/LICENSE)

## Lancer le jeu dans Godot

1. Importe [project.godot](project.godot) dans le gestionnaire de projets de **Godot 4.5.1**.
2. Attends la fin de l’import des assets et appuie sur **F5**.
3. La partie débute en atelier libre à **La Traversée**. Vise le téléphone du bureau et maintiens **A / F** pour ouvrir le service.

**View / F9** ouvre le menu de nouvelle partie. Tu peux choisir **La Traversée** avec une baie, **Le Tandem** avec deux ou **Les Trois Ponts** avec trois.

## Commandes

| Action | Manette Xbox | Clavier |
| --- | --- | --- |
| Marcher et viser | Stick gauche et stick droit | WASD ou flèches, IJKL pour viser |
| Interagir ou maintenir pour une réparation | A | F |
| Prendre, poser ou valider le stationnement | Y | E |
| Pivoter un objet ou vider le chariot tracté | X | R |
| Annuler ou refuser une réparation | B | Q |
| Zoomer | LB / RB | − / = |
| Accélérer, freiner et reculer | Stick gauche vers le haut, au centre ou vers le bas | W / S |
| Braquer | Stick droit horizontal | A / D |

## Développement

Le dossier est la racine du projet Godot et du futur dépôt GitHub. Les scripts, les modèles et leurs paramètres d’import sont inclus. Le cache Godot, les journaux et les exports sont ignorés par Git.

Depuis la racine, avec l’exécutable Godot accessible sous le nom `godot` dans le terminal, importe les assets puis lance les tests du garage.

```sh
godot --headless --editor --import --path .
godot --headless --path . --script res://test_workshop.gd --quit-after 1100
```

## Crédits des assets

Les modèles et textures tiers inclus proviennent des packs suivants, distribués sous [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

- Kenney pour les véhicules, les meubles et le personnage animé. [Car Kit](https://kenney.nl/assets/car-kit) · [Furniture Kit](https://kenney.nl/assets/furniture-kit) · [Animated Characters Protagonists](https://kenney.nl/assets/animated-characters-protagonists)
- Grab3D pour le pont et plusieurs pièces mécaniques. Le pont est adapté pour dégager la vue. [Cozy Car Parts & Garage Kit](https://grab3d.com/kits/cozy-car-parts/)
- 3DAssets.dev pour le mobilier et l’équipement du garage. Les modèles utilisés ont été adaptés au format glTF de Godot. [Car Repair Garage and MOT Workshop](https://3dassets.dev/packs/car-repair-garage-and-mot-workshop)

Noto Sans Symbols 2 fournit les caractères spéciaux de l’interface. [Police](https://fonts.google.com/noto/specimen/Noto+Sans+Symbols+2) · [SIL Open Font License 1.1](assets/fonts/OFL.txt)
