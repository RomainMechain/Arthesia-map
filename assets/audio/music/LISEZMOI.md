# Musiques d'Arthesia

Dépose ici tes morceaux (`.ogg` de préférence, sinon `.mp3` ou `.wav`). Ils bouclent tout seuls et
s'enchaînent en fondu (2 s) quand on change de zone ou d'humeur. Sans fichier, le jeu reste sans
musique (les ambiances de zone continuent).

| Fichier | Quand | Intention |
|---|---|---|
| `titre.ogg` | écran titre | thème principal, nostalgique |
| `calme.ogg` | village, zones simples (nature, eau, camp, passage) | très paisible |
| `tension.ogg` | zones dangereuses (`danger`, `ruins`) | plus tendu, inquiet |
| `boss.ogg` | pendant un combat de boss (une bête de rôle `boss` qui t'a repéré) | très épique |

Un fichier au nom d'une zone passe avant son humeur : `village_aube.ogg`, `sentier_lisiere.ogg`,
`rive_paisible.ogg`… (pas pour le titre ni le boss).

Conseils : pour une boucle propre, un morceau qui finit comme il commence ; volume normalisé autour
de −14 LUFS ; 2 à 4 min suffisent. Attention aux droits si le jeu est diffusé : une musique libre de
droits (CC0 / CC-BY, en créditant l'auteur) ou une composition originale.

Les bruitages et ambiances, eux, sont générés par `tools/audio/sfx.py`.
