# Notes

## Décisions

- Bureaux émulés à la AeroSpace (fenêtres garées hors écran) plutôt que de vrais Spaces : pas de SIP, pas d'API privée, instantané, survit aux mises à jour de macOS.
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
| macOS 27.0.1 (arm64) | changement ⌃1↔⌃2 et restauration sur SIGTERM vérifiés, 1 écran, 7 apps ; ⌃⇧N et suivi Cmd-Tab pas encore |

## Pièges

- macOS limite la position verticale des fenêtres garées (y=981 demandé, 865–889 obtenu selon la fenêtre) : seul x est fiable, d'où `isHidden` qui ne regarde que x.
