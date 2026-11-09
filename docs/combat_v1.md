# Combat V1 — version carte 2D (décisions)

> Décisions prises avec Romain le 2026-11-08. Complète la section « Combat (squelette v1) » de
> `arthesia_data_model.md`. Là où ce document diverge, c'est lui qui fait foi pour la version carte.
> Les formules (dégâts, mana, vitesse d'attaque, critiques) restent celles de
> `arthesia_balance_reference.md` / `back/combat_engine.py`, portées à l'identique.

## 1. Principe

**Action libre en temps réel.** Pas de verrouillage de cible : chaque coup part devant le personnage et
touche ce qui se trouve dans sa zone d'impact. Les autres bêtes restent dans le monde (pas d'arène).

| Sujet | Décision |
|---|---|
| Attaque classique | **Un tap = un coup**, dès que le temps de recharge (réduit par `agi`) est écoulé. Sans mana. |
| Visée | **Direction du regard + aide** : si une bête est dans un cône d'environ 60° devant, le coup se tourne vers elle. |
| Compétences | Barre de 4 emplacements en bas à droite (extensible à 8 comme prévu), même visée que l'attaque. |
| Mobile | Déplacement au toucher du sol (comme aujourd'hui), bouton d'attaque et barre de compétences. |
| PC | ZQSD ou flèches pour bouger, clic gauche pour attaquer vers la souris, touches 1 à 4 pour les compétences vers la souris. |
| Esquive | **Sortir de la zone** : une attaque avec `telegraph_seconds > 0` affiche sa zone au sol pendant ce temps et rate si on en est sorti. Sans télégraphe, elle touche toujours. |
| Mise à jour des JSON | Autorisée pour coller à ce combat : les gros coups des movesets reçoivent un `telegraph_seconds` réel (≈ 0,5–0,7 s pour la Lisière). |

## 2. Bêtes

- **Agressivité selon la bête**, déduite de sa description :
  - les **calmes** (lapin, oiseau) fuient et ne ripostent que si on les frappe ;
  - les **prédateurs** (loup doré) attaquent quand on entre dans leur rayon ;
  - le **renardeau** « mord avant de fuir ».
- IA : parmi les coups dont la recharge est finie, tirage pondéré par `weight` (règle du modèle de
  données). Une bête qui s'éloigne trop de son point d'apparition abandonne le combat, rentre et se soigne.
- Une bête morte réapparaît après le `cooldown_seconds` de son Entry, avec un `state_scope` partagé.

## 3. Joueur

- **Départ à mains nues** : Frappe dans la barre, sans arme. L'arme s'achète chez Thessaly ou se forge.
- **Progression** : les bêtes donnent de l'XP ; à chaque niveau, **6 points à répartir** (valeurs : hp +25,
  atk/def/int/sag +2, agi +1). Les compétences se débloquent selon leur `unlock_condition` et prennent
  le premier emplacement libre de la barre.
- **Butin** : ramassage automatique (les objets volent vers le joueur) dans le Sac.
- **Mort** : fondu au noir, puis retour au cercle d'arrivée de Val-de-l'Aube avec les PV pleins.
  Pénalités :
  - « **Ébranlé** » : −20 % sur les stats pendant 60 s ;
  - **perte d'une partie de l'or porté** (proposition : 10 %).
- **Animations en 8 directions** (5 dessinées, les 3 côté gauche en miroir) : repos, marche, attaque,
  touché, KO.

## 4. Interface

- HUD :
  - **barres de PV et de mana du joueur** ;
  - **barre de PV au-dessus des bêtes blessées** ;
  - **chiffres de dégâts** (dorés en critique, verts pour les soins) ;
  - **flash blanc et petit recul** à l'impact.
- Pas de tremblement d'écran.
- **Carnet** : un seul bouton qui ouvre un panneau à trois onglets, Personnage (stats et points),
  Sac et Quêtes.
- **Quêtes, boucle complète** :
  1. accepter auprès du PNJ ;
  2. suivi à l'écran (« Loups Dorés 2/4 ») ;
  3. rendre la quête et recevoir les récompenses.

  Le marqueur passe de « ! » à « … » puis « ? ». Cela s'applique à « La Veille Silencieuse » (Aurin)
  et à « Une Truite pas Comme les Autres » (Garin).

## 5. Architecture : solo, prête pour un serveur

Le combat tourne en local, mais **les règles sont séparées du rendu** pour pouvoir passer côté serveur
plus tard :

- `game/combat/rules.gd` : formules pures, statiques et sans nœud. Portage de `combat_engine.py`.
- `game/combat/combatant.gd` : PV, mana, recharges, couche de modificateurs (buffs, équipement,
  « Ébranlé »). Les stats dérivées sont toujours recalculées, jamais stockées.
- Bus d'événements `CombatEvents` : coup porté, mort, butin, XP. L'interface, les effets et les
  quêtes s'y abonnent sans connaître le combat.
- Les zones d'impact (arc, cercle) sont **géométriques**, calculées dans les règles, et non par la
  physique de Godot : le même code pourra être exécuté par un serveur.
- `GameState` (autoload) contient l'état du joueur : niveau, XP, points, Sac, or, quêtes, barre. Il
  est sauvegardé avec un champ `version`.

## 6. Implémentation (état au 2026-11-08)

| Élément | Fichier |
|---|---|
| Formules (portage de `docs/combat_engine.py`) | `game/combat/rules.gd` |
| Combattant (PV, mana, effets, bouclier, recharges) | `game/combat/fighter.gd` |
| Profil joueur, conditions, quêtes, défaite, sauvegarde | `game/game_state.gd` (autoload) |
| Joueur, 8 directions | `game/player.gd`, planche `tools/art/player_sheet.py` |
| Bêtes (tempérament, IA, télégraphes, butin, réapparition) | `game/mob.gd` |
| HUD, Carnet | `game/ui/hud.gd`, `game/ui/carnet.gd` |
| Effets (télégraphe, traces, chiffres, butin, flash) | `game/combat/*.gd`, `game/fx/flash.gdshader` |
| Adaptation des JSON (`area`, télégraphes) | `tools/data/patch_combat_v1.py` |
| Tests | `tools/godot/combat_test.gd`, `smoke_test.gd`, `travel_test.gd` |

Champ `area` (optionnel, sur les coups des movesets et les compétences actives) :
`{"shape": "arc", "range": px, "angle": °}`, `{"shape": "circle", "radius": px}`,
`{"shape": "line", "range": px, "width": px}` (première cible), `{"shape": "self"}`. Sans ce champ : arc 22 px / 80°.

Notes :
- **Courbe d'XP** : `back/balance.py` n'est pas dans le projet. Elle est reconstituée à partir des
  tableaux du document d'équilibrage : exacte aux niveaux 1, 10, 50 et 100, interpolée entre ces niveaux.
  L'XP d'un monstre normal vaut 10 × 1,06^(niveau−1).
- Le niveau 1 donne ses 6 points, comme pour le joueur de référence : on commence avec 6 points à répartir.
- Défaite : 3 % de l'or (au plus 20 × le niveau) et relevé à 20 % des PV, comme dans le document
  d'équilibrage, plus « Ébranlé ». Pas de perte d'XP (choix de Romain).
- `avoidable_by: "esquive"` correspond à sortir de la zone (il n'y a pas de bouton d'esquive). `"interruption"` :
  une compétence de dégâts qui touche la bête pendant l'annonce l'annule.
- Avant la couche action : niveau 1, mains nues, 6 points en build aventurier contre le Lapin Bondissant.
  Victoire en ~70 s, jugée trop longue pour ce combat.

## 7. Couche action (2026-11-08)

Les combats du mode nœuds (~65 s) sont trop longs pour l'action temps réel. Les formules de
`combat_engine.py` et les templates ne changent pas. Des multiplicateurs, regroupés dans
`game/combat/rules.gd` (`ACTION_*`), s'appliquent en jeu :

| Réglage | Valeur | Effet |
|---|---|---|
| PV des monstres | × 0,4 | combats ~2,5 fois plus courts |
| Dégâts des monstres | × 1,8 | un combat coûte toujours des PV |
| Coups annoncés | × 1,2 | esquiver divise les pertes par deux |
| PV hors combat | pleins en 1 min (au lieu de 10), 3 fois plus vite en ville | on enchaîne les combats |
| XP par bête | × 0,18, +3,5 % par niveau de la bête | ~65 bêtes par heure au lieu de 12 : les durées de niveau ne changent pas (le bonus par niveau compense les zones profondes, plus coûteuses en PV) |
| Butin ordinaire | **garanti** : un objet par bête (décision de Romain, 2026-11-09) | une victoire rapporte toujours quelque chose |
| Rachat | 35 % de la valeur, **arrondi** (au lieu de tronqué) | au niveau 1, la troncature faisait perdre 43 % de la valeur |
| Butin très rare | chance × 0,18 | même fréquence par heure qu'avant |

Cibles (décision de Romain) contre une bête normale du même niveau : **25-30 s**, **~35 % des PV**
perdus sans esquiver, **~15-20 %** en esquivant les annonces. Calibrage et vérification :
`python tools/balance/simulate_action.py`, avec les formules de `docs/combat_engine.py` importées
telles quelles. Relancer avec `python tools/balance/simulate_action.py <PV> <dégâts> <annonces>` pour
tester d'autres valeurs.

Joueur de référence niveau 1 (équipé), en esquivant la moitié des annonces : 27 s et 27 % des PV
perdus en moyenne. Lapin ~21 s, loup ~25 s, oiseau ~22 s, renardeau (niv. 2, rare) ~41 s et ~53 %.
Départ mains nues : ~31 s et ~42 %. Une arme compte vraiment.
### Progression et économie (2026-11-09)

Simulées par `python tools/balance/simulate_action.py progression`. Joueur de référence de chaque niveau
contre les bêtes normales de ce niveau, en esquivant la moitié des annonces. Un cycle par bête comprend
le combat, la régénération et 12 s de marche. Les quêtes apportent 30 % de l'XP.

| Niv. | Combat | PV perdus | Bêtes/h | Durée du niveau (cible) | Or/h | Équipement du niveau |
|---|---|---|---|---|---|---|
| 1 | 23 s | 20 % | 67 | 15 min (15) | 162 | 35 or ≈ 13 min |
| 3 | 23 s | 24 % | 65 | 20 min (20) | 326 | 105 or ≈ 19 min |
| 5 | 17 s | 27 % | 71 | 23 min (26) | 848 | 175 or ≈ 12 min |
| 8 | 24 s | 35 % | 57 | 42 min (40) | 1 184 | 280 or ≈ 14 min |
| 10 | 24 s | 41 % | 55 | 57 min (52) | 984 | 350 or ≈ 21 min |

Lecture : la première arme (la dague de Thessaly) se paie en ~13 min de chasse. Une pièce d'équipement
de son niveau coûte 12 à 21 min, mais les niveaux requis limitent ce qu'on peut acheter. On arrive
ainsi aux 40-50 % de puissance tirés de l'équipement que vise le document d'équilibrage.
## 8. Récolte et métiers (2026-11-09)

- **Récolter** : toucher une ressource (ou E). Le joueur reste occupé pendant `gather_time_seconds`, avec une
  barre au-dessus de lui. Se déplacer ou recevoir un coup interrompt la récolte. À la fin : un tirage pondéré
  dans `yields`, et le stock (`spawn.stock`) diminue. Épuisée, la ressource pâlit puis repousse après
  `spawn.cooldown_seconds`.
- **Prérequis** : sans le niveau de métier (`profession_required.min_level`), la ressource reste visible et
  affiche « Herboristerie niv. 2 requis », comme le prévoit le modèle de données.
- **Courbe** (document d'équilibrage) : ~50 récoltes de sa tranche par niveau. Une récolte de niveau r vaut
  10 × (1 + 0,1 (r − 1)) XP. Si elle est plus facile que le métier : −25 % par niveau d'écart (25 % au
  minimum). Il faut 500 × (1 + 0,1 (L − 1)) XP pour passer le niveau L.
- Les compteurs de récolte alimentent les conditions `gather_count` (Mains de Ravaudeur, Sève des
  Fougères…).

## 9. Carte de l'étage et accès aux zones

- Onglet « Carte » du Carnet : la carte à nœuds du squelette (`position`, `connections`). Une zone est
  « tu es ici », visitée, accessible (son `unlock_condition` est remplie) ou verrouillée (« ??? »). Les zones
  `hidden` restent invisibles tant qu'elles sont verrouillées. Les marqueurs de quête viennent des entrées
  `quest_giver` de chaque zone.
- Les sorties respectent `unlock_condition` : une zone verrouillée affiche son `hint` au lieu de s'ouvrir
  (exemple : Rive Paisible demande d'avoir accepté la quête de Garin).
## 10. Rive Paisible : bêtes d'eau et pêche

- **Sentinelle** (héron cendré) : immobile à son poste, repère le joueur à 44 px, frappe en ligne (long cou) sans le poursuivre.
- **Nageuse** (anguille des hauts-fonds) : chaque attaque est une plongée. Elle est invisible et intouchable sous l'eau, des rides (télégraphe circulaire, 0,8 à 1 s) marquent sa sortie, puis elle reste 1,4 s en surface : c'est la fenêtre pour frapper. Elle ne quitte jamais les hauts-fonds (laisse 4 tuiles).
- **Crabes** : prédateurs à petit rayon (44 px), par groupes de 3 sur la plage.
- **Hauts-fonds** : eau praticable, vitesse ×0,65, éclaboussures.
- **Pêche** : récolte classique (barre de récolte, 4 s), sur 3 postes : anse, embouchure, ponton de l'îlot.
- **Découvertes** : une note dans le Carnet (Quêtes › Notes) et 5 % de l'XP du niveau, une seule fois.
