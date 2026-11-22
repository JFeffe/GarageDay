# Garage Day dans Roblox Studio

Le Petit Atelier propose une intervention à la première personne sur la roue avant gauche d’une berline. Lève le pont, desserre la roue avec la clé à choc, dépose-la, prends des plaquettes à l’étagère, pose-les, remonte la roue et abaisse le pont. Le levier permet ensuite de recommencer.

Approche-toi du poste et suis le tableau de service. Utilise **E** au clavier, **X** à la manette ou touche l’invite sur téléphone. À deux, l’un peut lever le pont et travailler avec la clé pendant que l’autre prépare les plaquettes. Un mécano seul peut faire toute l’intervention.

## Ouvrir et tester

Ouvre `build/roblox/Garage Day.rbxlx` dans Roblox Studio et clique sur **Play**. L’atelier s’installe au démarrage du test. Pour une partie à deux, choisis **Server & Clients** avec deux clients dans les modes de test de Studio. Chaque joueur a sa vue et les opérations sur la voiture sont partagées.

Pour reconstruire le fichier depuis la racine, utilise Node.js et [Rojo](https://rojo.space/docs/v7/getting-started/installation/) 7.6 ou plus récent.

```powershell
Set-Location roblox
npm ci
npm run build
```

Les scripts se trouvent dans `src/`. Le serveur gère les étapes, l’outillage et le pont. Le client affiche le tableau de service et utilise la caméra et les commandes de Roblox. Tu peux aussi utiliser `rojo serve` après `npm run assets` pour continuer à modifier les scripts dans le dépôt et les synchroniser avec Studio.

## Modèles du garage

La construction reprend les fichiers `sedan.glb`, `car-lift.glb` et `impact-wrench.glb` du jeu Godot. Elle conserve leur géométrie et applique les couleurs des matériaux en échantillonnant les textures par triangle. Le serveur prépare les modèles au démarrage. Si les API de maillage sont indisponibles, la version locale charge des formes de remplacement pour permettre le test du jeu. L’attribut `OriginalModels` du modèle `Le Petit Atelier` indique si les modèles d’origine ont été chargés.

Les crédits et les licences des modèles sont dans le [README de Garage Day](../README.md#cr%C3%A9dits-des-assets). Pour tester une future version hébergée avec les modèles originaux, configure le réglage **Mesh / Image APIs** du projet ou importe les GLB dans Studio. [Règles des maillages éditables](https://create.roblox.com/docs/reference/engine/classes/EditableMesh)

## Vérifier les règles de réparation

Depuis la racine du dépôt, lance `luau roblox/tests/repair.luau` avec la [CLI Luau](https://github.com/luau-lang/luau/releases).
