<h1 align="center">wrkspaces</h1>
<p align="center">Des bureaux virtuels pour macOS. Pas de tiling, pas d'animation, rien à apprendre.</p>
<p align="center"><sub>v0.1.10 · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#fonctionnalités">Fonctionnalités</a> · <a href="#installation">Installation</a> · <a href="#utilisation">Utilisation</a> · <a href="#développement">Développement</a> · <a href="README.md">English</a></p>

<p align="center">
  <img src="docs/menubar.jpg" width="560" alt="L'icône de wrkspaces dans la barre de menus de macOS, sa grille ouverte en dessous : neuf bureaux avec les icônes de leurs apps, le choix de l'icône et la liste des raccourcis">
</p>

## Fonctionnalités

- **Changement instantané** : six bureaux, jusqu'à neuf depuis le clic droit, aucune animation, pas de SIP à désactiver.
- **Raccourcis déjà connus** : les mêmes que les Spaces de macOS.
- **Vous suit** : Cmd-Tab ou le Dock vers une fenêtre d'un autre bureau vous y emmène.
- **Rien de perdu** : quitter, Ctrl-C ou un plantage remet chaque fenêtre à l'écran.
- **Presque aucune config** : une icône dans la barre de menus avec le numéro du bureau courant et un petit dessin : une fenêtre avec des yeux, un blob, une fleur dont la pétale en surbrillance est le bureau, ou un anneau. Il se choisit sous la grille que l'icône ouvre.
- **Voir où est tout** : un clic sur l'icône ouvre une grille des bureaux avec leurs apps (jusqu'à huit par bureau), un clic sur un bureau vous y emmène. Gardez `⌃` enfoncé après `⌃N` et la même grille apparaît, comme Cmd-Tab. Glissez une app sur un autre bureau pour y envoyer ses fenêtres, ou sur une autre app du même bureau pour les réordonner. Une liste dépliable sous la grille rappelle tous les raccourcis. Clic droit sur l'icône pour choisir le nombre de bureaux, ou pour quitter.

## Installation

Téléchargez `wrkspaces-macos-universal.dmg` depuis la [dernière release](https://github.com/te-o-o-o/wrkspaces/releases/latest), ouvrez-le et glissez `wrkspaces.app` sur Applications (un `.zip` de la même app est aussi disponible). Il tourne sur les Mac Apple Silicon et Intel, macOS 14 ou plus récent.

L'app n'est pas signée avec un identifiant développeur Apple, donc macOS la bloque au premier lancement : clic droit dessus puis **Ouvrir**, ou lancez une fois `xattr -d com.apple.quarantine /Applications/wrkspaces.app`.

Depuis les sources (outils en ligne de commande Xcode requis) :

```sh
git clone https://github.com/te-o-o-o/wrkspaces && cd wrkspaces
./bundle.sh
cp -R .build/wrkspaces.app /Applications/
open /Applications/wrkspaces.app
```

Au premier lancement, macOS demande l'accès Accessibilité : accordez-le et l'app démarre d'elle-même. Clic droit sur l'icône puis **Open at Login** pour la lancer avec la session.

Les releases sont toutes signées avec la même clé : une mise à jour garde l'accès Accessibilité. En venant de la 0.1.9 ou d'avant, ou après une compilation maison (`./bundle.sh` signe ad hoc), macOS ne reconnaît plus l'app : retirez-la de la liste Accessibilité (ou lancez `tccutil reset Accessibility io.github.te-o-o-o.wrkspaces`) et accordez l'accès à nouveau.

## Utilisation

| Raccourci | Action |
|---|---|
| `⌃1` … `⌃9` | aller au bureau N ; encore, `⌃` tenu, pour choisir une de ses apps dans la grille |
| `⌃⇧1` … `⌃⇧9` | emmener la fenêtre active au bureau N, et y aller avec elle |
| `⌃` ou `⌃⇧` + pavé `1` … `9` | pareil, depuis le pavé numérique |

<p align="center"><img src="docs/hold.jpg" width="560" alt="La grille affichée tant que ⌃ reste enfoncé, au centre de l'écran : le bureau courant en surbrillance, chaque bureau avec les icônes de ses apps"></p>

Si les raccourcis natifs « Passer au bureau N » sont activés, désactivez-les : Réglages Système > Clavier > Raccourcis clavier > Mission Control.

**Pas encore** : un seul jeu de bureaux pour tous les écrans, pas de bureaux par écran.

**Mises à jour** : quand une nouvelle version sort, le menu du clic droit propose **Update to X.Y.Z**. Un clic la télécharge, vérifie qu'elle est signée avec la même clé et la relance : pas de boîte Gatekeeper, l'accès Accessibilité est gardé. Une copie compilée avec `./bundle.sh` ne se met jamais à jour.

## Développement

```sh
swift test
swift run wrkspaces
```

Principe : les fenêtres des autres bureaux sont garées dans le coin en bas à droite de l'écran, comme le fait AeroSpace. Décisions et pièges dans [docs/notes.fr.md](docs/notes.fr.md).

## Licence

[MIT](LICENSE)
