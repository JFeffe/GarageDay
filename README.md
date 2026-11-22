# Garage Day

Garage Day est un jeu de gestion de garage miniature à jouer à la manette ou au clavier. Accueille les clients, rentre leurs voitures, répare-les et protège ta réputation pendant dix jours. Entre deux services, réaménage l’atelier et choisis parmi les offres de la fourgonnette.

**[Jouer à Garage Day dans le navigateur](https://jfeffe.github.io/GarageDay/)**

## Jouer dans le navigateur

**Nouvelle partie** donne accès aux quatre garages, avec **Le Petit Atelier** en premier. En solo, **Menu** met la partie en pause et **Continuer** la reprend. Après la fermeture de l’onglet, la reprise repart du dernier atelier libre sauvegardé, y compris la configuration avant le service. Les sauvegardes solo et multijoueur sont distinctes. Si les deux existent, la sauvegarde solo est accessible via **Continuer** et celle de l’hôte via **Multijoueur**.

Dans **Options**, choisis entre **Fluide**, **Équilibré** et **Qualité**. Tu peux aussi afficher les images par seconde.

### Jouer à deux

Dans **Multijoueur**, clique sur **Créer une partie**, choisis un garage puis clique sur **Héberger**. Copie le lien dans la barre de la partie et transmets-le à ton invité. L’hôte garde son onglet ouvert. Vous partagez la caméra et le son du garage. Les deux joueurs peuvent conduire, accueillir, réparer et encaisser. L’hôte choisit les pièces au rayon et gère le chariot, l’aménagement et les menus. L’invité peut régler le son dans la barre du jeu.

La partie hébergée est sauvegardée dans le navigateur de l’hôte en atelier libre et avant l’ouverture. **Reprendre comme hôte** permet de reprendre cette sauvegarde avec un nouveau lien. Une interruption pendant le service ramène au début de ce service. Le partage transmet l’image du jeu à l’invité. La connexion WebRTC est négociée via PeerServer Cloud et dépend du réseau des deux joueurs. [Documentation PeerJS](https://peerjs.com/client/getting-started) · [Licence MIT](web/vendor/LICENSE)

## Lancer le jeu dans Godot

Sous Windows, double-clique sur [Jouer a Garage Day.bat](Jouer%20a%20Garage%20Day.bat) à la racine du projet. Le lanceur utilise Godot 4.5.1 dans le dossier voisin `Jam House` ou dans `tools\godot`. Il peut aussi utiliser `godot.exe` si la commande est disponible dans le PATH.

Pour ouvrir le projet dans l’éditeur :

1. Importe [project.godot](project.godot) dans le gestionnaire de projets de **Godot 4.5.1**.
2. Attends la fin de l’import des assets et appuie sur **F5**.
3. L’accueil propose **Continuer**, **Nouvelle partie**, **Multijoueur**, **Options** et les notes de mise à jour. Choisis un des quatre garages pour commencer. Vise le téléphone du bureau et maintiens **A / F** pour ouvrir le service.

**Start / Échap** met le jeu en pause, y compris pendant une réparation ou au volant. Le menu permet de reprendre, de régler les options ou de retourner à l’accueil. **Continuer** reprend exactement la partie tant que le jeu reste ouvert. Après fermeture, la reprise repart du dernier atelier libre sauvegardé, avant le service. Les réglages **Fluide / Équilibré / Qualité** et le compteur d’images par seconde sont conservés sur cet ordinateur. La sauvegarde locale est distincte de celles du navigateur.

Le bouton **Multijoueur** ouvre le mode Web dans le navigateur pour héberger ou rejoindre une partie.

**View / F9** ouvre le menu de nouvelle partie. Tu peux choisir **Le Petit Atelier** avec une baie et des salles réduites, **La Traversée** avec une baie, **Le Tandem** avec deux ou **Les Trois Ponts** avec trois.

## Les 12 h de Garage Day

Choisis **Nouvelle partie → Course de 12 h**, en local ou dans le navigateur. Tu gères les n° 27 et 81, chacune avec deux pilotes. Huit GT rivales roulent et s’arrêtent pendant que le classement se met à jour. L’horloge accélère en piste et ralentit lorsque tes voitures arrivent aux stands.

Rejoins le **poste de contrôle** à l’extérieur, à gauche de la porte du garage. Maintiens **A / F** au repère des écrans. Consulte les deux GT côte à côte et sélectionne celle à gérer avec **gauche / droite**. Le **Plan d’arrêt** permet de régler chaque intervention sur **Ignorer**, **Joueur** ou **Auto**, puis de choisir le box extérieur ou le garage. Les tâches automatiques sont plus longues et peuvent se dérouler en parallèle avec tes interventions. Une fois les travaux terminés, retourne au contrôle et choisis **Feu vert · reprendre la piste**.

**LT / RT** ou **[ / ]** règle la vitesse en piste sur **×12, ×24 ou ×48**. La course passe automatiquement à **×5** aux stands et pendant la consultation du poste. Le chrono indique le temps écoulé et le temps restant, y compris en pause.

L’écran du poste montre les dix GT en mouvement sur le circuit et leur passage aux stands. Les deux voitures de Garage Day sont entourées en clair. Le direct et le classement complet restent visibles quand tu modifies un plan d’arrêt.

Comme dans le garage de quartier, marche au **stick gauche / WASD / flèches**, vise au **stick droit / IJKL** et maintiens **A / F** sur le repère sélectionné. **LB / RB** ou **− / =** changent le zoom. Prends le pistolet à la pompe, puis branche-le sur la GT. Pour les pneus, lève chaque train avec son cric, change ses deux roues, puis abaisse-le. Récupère une clé près des outils pour réparer. Les deux crics et la pompe sont partagés entre les deux GT.

Dans le navigateur, **Multijoueur → Créer une partie → Course de 12 h** partage la course. Les deux mécanos peuvent utiliser le poste de contrôle pour les deux GT. Pendant que l’un s’occupe de la stratégie, l’autre peut continuer à travailler dans les stands. La course peut être mise en pause et reprise tant que la session reste ouverte. Les sauvegardes d’atelier sont indépendantes.

## Commandes

| Action | Manette Xbox | Clavier |
| --- | --- | --- |
| Pause / reprendre | Start | Échap |
| Marcher et viser | Stick gauche et stick droit | WASD ou flèches, IJKL pour viser |
| Interagir ou maintenir pour une réparation | A | F |
| Prendre, poser ou valider le stationnement | Y | E |
| Pivoter un objet ou vider le chariot tracté | X | R |
| Annuler ou refuser une réparation | B | Q |
| Zoomer | LB / RB | − / = |
| Ralentir / accélérer la course | LT / RT | [ / ] |
| Sélectionner une GT au contrôle | Croix / stick gauche, gauche ou droite | Flèches gauche ou droite |
| Accélérer, freiner et reculer | Stick gauche vers le haut, au centre ou vers le bas | W / S |
| Braquer | Stick droit horizontal | A / D |

## Développement

Le dossier est la racine du projet Godot et du futur dépôt GitHub. Les scripts, les modèles et leurs paramètres d’import sont inclus. Le cache Godot, les journaux et les exports sont ignorés par Git.

Depuis la racine, avec l’exécutable Godot accessible sous le nom `godot` dans le terminal, importe les assets puis lance les tests du garage.

```sh
godot --headless --editor --import --path .
godot --headless --path . --script res://test_workshop.gd --quit-after 1100
godot --headless --path . --script res://test_game_menu.gd
godot --headless --path . --script res://test_endurance.gd
node test_lobby.cjs
```

## Crédits des assets

Les modèles et textures tiers inclus proviennent des packs suivants, distribués sous [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

- Kenney pour les véhicules, les meubles et le personnage animé. [Car Kit](https://kenney.nl/assets/car-kit) · [Furniture Kit](https://kenney.nl/assets/furniture-kit) · [Animated Characters Protagonists](https://kenney.nl/assets/animated-characters-protagonists)
- Grab3D pour le pont et plusieurs pièces mécaniques. Le pont est adapté pour dégager la vue. [Cozy Car Parts & Garage Kit](https://grab3d.com/kits/cozy-car-parts/)
- 3DAssets.dev pour le mobilier et l’équipement du garage. Les modèles utilisés ont été adaptés au format glTF de Godot. [Car Repair Garage and MOT Workshop](https://3dassets.dev/packs/car-repair-garage-and-mot-workshop)
- 3DAssets.dev pour les deux GT d’endurance, réexportées pour Godot et recolorées dans le jeu. [GT à moteur avant](https://3dassets.dev/assets/endurance-and-gt-paddock-front-engine-gt-coupe-ff0949d7) · [Coupé GT4](https://3dassets.dev/assets/endurance-and-gt-paddock-gt4-sports-car-69ecfad1)

Noto Sans Symbols 2 fournit les caractères spéciaux de l’interface. [Police](https://fonts.google.com/noto/specimen/Noto+Sans+Symbols+2) · [SIL Open Font License 1.1](assets/fonts/OFL.txt)
