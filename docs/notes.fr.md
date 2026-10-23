# Notes

## Décisions

- Les curseurs de glissement de la grille passent par le second appel privé, `CGSSetConnectionProperty(…, "SetsCursorInBackground")` : macOS ne laisse que l'app active changer le pointeur, et la grille ne doit pas prendre le focus. Cosmétique : si Apple le retire, seules les mains disparaissent.
- La grille trie les apps selon l'empilement du serveur de fenêtres (`CGWindowListCopyWindowInfo`, à l'écran seulement) : les fenêtres garées restent à l'écran d'un pixel, donc gardent leur rang, et dans un bureau la première est la dernière utilisée. Aucune permission nécessaire pour les numéros de fenêtre.
- Les fenêtres sont repérées par leur CGWindowID, pas par leur élément AX : Zen (basé sur Firefox) est une fois revenu à la position de repli après un aller-retour ⌃⇧N, signe qu'une app peut fournir un nouvel élément pour la même fenêtre. Obtenir l'identifiant passe par `_AXUIElementGetWindow`, un appel privé (pas d'alternative publique ; AeroSpace, yabai et Rectangle s'en servent ; aucun changement de SIP).
- Bureau vide : wrkspaces prend le focus lui-même (sans fenêtre, la frappe ne va nulle part). Le Finder a été écarté : ses fenêtres garées ailleurs déclencheraient le suivi à l'activation.
- Ouverture à la connexion via `SMAppService.mainApp`, désactivée par défaut, proposée seulement en .app.
- L'icône ouvre la grille plutôt qu'un menu : plus léger à lire. Quitter est au clic droit, l'endroit habituel des apps de barre de menus.
- Tester les clics : l'icône bouge avec les menus de l'app au premier plan, lire sa position avant de cliquer (`position of menu bar item 1 of menu bar 1`).
- Grille affichée 0,15 s après ⌃N si ⌃ est encore enfoncé, comme Cmd-Tab : `⌃` seul est trop courant (Ctrl-C, Ctrl-clic) pour déclencher quoi que ce soit.
- Pour la tester avec System Events : `key code … using control down` relâche ⌃ à la fin ; utiliser `key down control` puis un `key code` seul.
- Bureaux émulés à la AeroSpace (fenêtres garées hors écran) plutôt que de vrais Spaces : pas de SIP, pas d'API privée des Spaces, instantané, survit aux mises à jour de macOS.
- Raccourcis `⌃1…9` / `⌃⇧1…9` repris des Spaces natifs : rien à apprendre. Codes de touche physiques, donc identiques en AZERTY.
- `RegisterEventHotKey` (Carbon) pour les raccourcis : aucune permission en plus, contrairement à un CGEvent tap.
- Délai AX réduit à 0,25 s pour qu'une app bloquée ne fige pas un changement de bureau.

## Pas encore géré

- Plusieurs écrans (les fenêtres sont garées au-delà de tous les écrans, mais les bureaux sont globaux).
- Changement de focus dans une même app (⌘`) vers une fenêtre garée : non suivi.
- i18n du menu.

## Vérifié

| OS | État |
|---|---|
| macOS 27.0.1 (arm64) | changement, ⌃⇧N, restauration sur SIGTERM, grille (⌃ maintenu l'affiche, un appui bref non), grille depuis l'icône (clic sur un bureau, clic ailleurs ferme, clic droit Quitter) vérifiés, 1 écran, 7 apps ; suivi Cmd-Tab vu marcher par effet de bord ; focus pris sur bureau vide, restauration à la fermeture après ⌃⇧N enchaînés (3 passes scriptées) ; le .app se construit et se signe, pas encore lancé |

## Pièges

- Le panneau de la grille ne devient jamais la fenêtre active : le survol demande une zone de suivi `.activeAlways`, ajoutée dans `viewDidMoveToWindow` (`updateTrackingAreas` n'était jamais appelé pour elle).

- macOS limite la position verticale des fenêtres garées (y=981 demandé, 865–889 obtenu selon la fenêtre) : seul x est fiable, d'où `isHidden` qui ne regarde que x.
