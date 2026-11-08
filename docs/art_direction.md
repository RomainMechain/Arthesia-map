# Arthesia — Direction artistique (Étage 1 : « L'Aube qui ne Finit Jamais »)

> Statut : **planche de style en attente de validation** (`art/preview/styleboard_x3.png`).
> Source des assets : générés par code (`tools/art/`), déterministes — relancer un script redonne
> exactement les mêmes pixels.

## Cadre du jeu

- Fantasme joueur : un « Marqué » qui explore une Tour étage par étage, seul ou en groupe.
- Verbes : se déplacer, cibler / combattre, récolter, parler, commercer.
- Moteur : Godot 4.6, renderer Mobile, 2D.
- Plateformes : mobile (paysage) en priorité, desktop pour le dev.
- Vue : **top-down 3/4** (sol vu de dessus, personnages et objets vus légèrement de face).
- Viewport natif : **480×270**, mise à l'échelle entière (×4 en 1080p, ×3 en 810p…).
- Taille à l'écran : tuile 16 px, personnage ~16×24 px, mob 16 à 32 px, boss 48 à 64 px.

## Système visuel

- **Langage de formes** : rond et organique pour la nature (canopées en grappes, rives douces) ;
  géométrique, angles droits et lignes gravées pour tout ce qui est architecte (ruines, mécanisme,
  gardien). Ce contraste *naturel / fabriqué* porte le lore de l'étage : l'aube est artificielle.
- **Silhouettes** : personnages lisibles à 16 px — tête grosse (≈ 40 % de la hauteur), couleur
  vive sur le torse. Mobs reconnaissables à leur seule forme.
- **Valeurs** : sol en valeurs moyennes et peu contrastées ; personnages, mobs et ressources plus
  saturés et contourés pour ressortir du terrain. Le gameplay doit se lire en noir et blanc.
- **Lumière** : soleil d'aube bas, venant du **haut-gauche**. Reflets dorés en haut-gauche des
  volumes, ombres portées **vers le bas-droite**, teintées violet (jamais de gris neutre ni de noir).
- **Matières** : herbe chaude jaune-vert, terre ocre, eau turquoise calme et reflets dorés, pierre
  architecte beige froid, gravée de **runes cyan lumineuses** (seule couleur froide saturée du jeu,
  réservée à la magie et aux Architectes).
- **Contour** : contour sélectif `#2a1a2e` sur personnages, mobs et props ; aucun contour sur les
  tuiles de sol.
- **Densité de détails** : faible sur le sol (bruit léger, 2 ou 3 touffes par tuile), moyenne sur
  les props, maximale sur les points de repère de chaque zone.
- **Mouvement** : animations courtes (2 à 4 frames), rebond doux, lucioles et poussière dorée en
  particules.
- **Exclusions** : pas de texte dans les images, pas de dégradés lisses ni d'anticrénelage, pas de
  noir pur ni de blanc pur.

## Palette (verrouillée, 40 couleurs)

Définie dans `tools/art/palette.py`, qui est la seule source. Rôles :

| Rôle | Teintes |
|---|---|
| Lumière d'aube / or | `#fff4d6` `#ffe08a` `#f5b84a` `#d9822b` |
| Végétation | `#e0e070` `#a8c84e` `#74a843` `#4a8040` `#2f5a3a` `#1d3a2e` |
| Terre / bois | `#f0d29a` `#d4a265` `#a8743f` `#7a5030` `#4f3324` |
| Eau | `#d4f4ec` `#8fd8d0` `#52aab8` `#347a98` `#244e70` |
| Pierre architecte | `#ece2cf` `#c4b59c` `#948672` `#665c55` `#433c42` |
| Runes / magie | `#b8fff0` `#5ae8e0` `#2aa8c0` |
| Peau / tissus | `#f8d0a8` `#d8946a` `#e05a48` `#a83a40` `#6a2a44` `#5868c8` `#38407a` |
| Ombres / contour | `#7a5878` `#4a3450` `#2a1a2e` |

## Biomes de l'étage 1

| Biome | Zones | Sol | Identité |
|---|---|---|---|
| `village` | village_aube | herbe claire, pavés chauds, chemins de terre | toits de chaume orangés, fanions, lumière la plus dorée |
| `foret` | sentier_lisiere, foret_ancienne, sous_bois_perdu, veilleurs_oublies | herbe plus sombre, mousse, racines | canopée dense, rais de lumière, lucioles ; plus sombre en s'enfonçant |
| `eau` | rive_paisible, lac_miroir, camp_pecheurs | sable, rive, eau calme | reflets dorés, roseaux, pontons |
| `ruines` | ruines_architectes | dalles gravées, herbe envahissante | runes cyan, géométrie, colonnes brisées |
| `sanctuaire` | sanctuaire_aube, chambre_gardien, passage_etage2 | dalles intactes, or | mécanisme d'aube, lumière la plus intense, cyan et or mêlés |

Chaque zone d'un même biome se distingue par sa **teinte d'ambiance** (`CanvasModulate`), sa
**forme de carte** et ses **2 ou 3 points de repère** uniques.

## Contrat technique

- Tuiles : 16×16, atlas PNG RGBA, sans padding (filtrage Nearest, pas de mipmaps → pas de bavure).
- Sprites : PNG RGBA, ancre **bas-centre** (les pieds), frames de même taille en bande horizontale.
- Godot : `default_texture_filter = Nearest`, `snap_2d_transforms_to_pixel = true`,
  stretch `viewport`, aspect `expand`, échelle entière.
- Nommage : `assets/art/<famille>/<biome|categorie>/<id>.png`, ids = ids des JSON quand ils existent
  (`lapin_bondissant.png`).
- Inventaire et suivi : `art/asset_manifest.json`.
