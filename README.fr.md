<h1 align="center">wrkspaces</h1>
<p align="center">Des bureaux virtuels pour macOS. Pas de tiling, pas d'animation, rien à apprendre.</p>
<p align="center"><sub>v0.1.0 · Swift · macOS · MIT</sub></p>
<p align="center"><a href="#fonctionnalités">Fonctionnalités</a> · <a href="#installation">Installation</a> · <a href="#utilisation">Utilisation</a> · <a href="#développement">Développement</a> · <a href="README.md">English</a></p>

## Fonctionnalités

- **Changement instantané** : neuf bureaux, aucune animation, pas de SIP à désactiver.
- **Raccourcis déjà connus** : les mêmes que les Spaces de macOS.
- **Vous suit** : Cmd-Tab ou le Dock vers une fenêtre d'un autre bureau vous y emmène.
- **Rien de perdu** : quitter, Ctrl-C ou un plantage remet chaque fenêtre à l'écran.
- **Aucune config** : une icône dans la barre de menus, une petite fenêtre avec des yeux et le numéro du bureau courant.
- **Voir où est tout** : un clic sur l'icône ouvre une grille des neuf bureaux avec leurs apps, un clic sur un bureau vous y emmène. Gardez `⌃` enfoncé après `⌃N` et la même grille apparaît, comme Cmd-Tab. Clic droit sur l'icône pour quitter.

## Installation

Pas encore de release. Depuis les sources (outils en ligne de commande Xcode requis) :

```sh
git clone https://github.com/te-o-o-o/wrkspaces && cd wrkspaces
./bundle.sh
cp -R .build/wrkspaces.app /Applications/
open /Applications/wrkspaces.app
```

Au premier lancement, macOS demande l'accès Accessibilité : accordez-le et l'app démarre d'elle-même. Clic droit sur l'icône puis **Open at Login** pour la lancer avec la session.

Après une recompilation, macOS ne reconnaît plus l'app : retirez-la de la liste Accessibilité (ou lancez `tccutil reset Accessibility io.github.te-o-o-o.wrkspaces`) et accordez l'accès à nouveau.

## Utilisation

| Raccourci | Action |
|---|---|
| `⌃1` … `⌃9` | aller au bureau N |
| `⌃⇧1` … `⌃⇧9` | envoyer la fenêtre active au bureau N |

Si les raccourcis natifs « Passer au bureau N » sont activés, désactivez-les : Réglages Système > Clavier > Raccourcis clavier > Mission Control.

**Pas encore** : un seul jeu de bureaux pour tous les écrans, pas de bureaux par écran.

## Développement

```sh
swift test
swift run wrkspaces
```

Principe : les fenêtres des autres bureaux sont garées dans le coin en bas à droite de l'écran, comme le fait AeroSpace. Décisions et pièges dans [docs/notes.fr.md](docs/notes.fr.md).

## Licence

[MIT](LICENSE)
