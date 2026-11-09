# Craft v1 (version de test)

Décisions : pas de réglage par atelier ; l'IA (Claude Code, « technique B ») invente chaque recette
inédite une seule fois ; la rareté est tirée à chaque fabrication, meilleure avec le niveau de métier.

## Déroulé

1. Au village, un atelier propose **Fabriquer**. On choisit le type d'objet (les `item_types` de
   l'atelier), puis on pose jusqu'à 4 ingrédients différents (8 en tout) sur l'établi.
2. Un ingrédient doit avoir un `level` ≤ au niveau du métier de l'atelier, et ne pas être un objet déjà
   crafté à partir d'objets craftés (génération 2).
3. Clé de recette : `atelier|type|id:quantité,...` (ids triés).
4. **Recette connue** : 3 s, même objet de base. **Inédite** : la barre attend Claude (≈ 6 s), qui
   fournit l'identité ; le jeu fixe les chiffres et fige l'objet. Sans Claude, nom provisoire
   (« Lame de Croc d'Or Pur »), renommé en arrière-plan à la prochaine ouverture d'un atelier.
5. Rang tiré, objet donné (`base~rang`, le commun garde l'id de base), XP de métier.

## Ce que fait Claude, ce que fait le jeu

| Claude (`tools/craft/claude_craft.py` + `craft_prompt.md`) | Le jeu (`game/craft/craft_rules.gd`) |
|---|---|
| nom, description, id | niveau : moyenne des ingrédients pondérée par la quantité (≤ le plus haut) |
| cohérence : aucune / normale / rare | stats : 0,7 × niveau points équivalents × 70 / 100 / 115 % selon la cohérence |
| poids relatifs de 2 stats au plus | soin 41 + 17 (niv-1), mana 26 + 4,9 (niv-1), × 0,8 / 1 / 1,2 |
| forme d'arme (dague, lame, hachette, masse, lance) | zone du coup selon la forme |
| icône (parmi des objets existants du même type) | valeur : 85 % des ingrédients, dans 70-130 % de la cible du niveau |

## Rareté

Base par cohérence (commun / peu commun / rare / épique / légendaire) : aucune 92/7/1/0/0, normale
70/22/7/1/0, rare 25/35/27/10/3. Chaque cran fait monter 8 % des chances de chaque rang au rang
suivant (au plus 60 %) : un cran par niveau de métier au-dessus du niveau de la recette, et par rang
de rareté d'un ingrédient. Un ingrédient épique ou mieux garantit au moins « rare ». Multiplicateurs
du document d'équilibrage (stats ×1,15 à ×1,8 ; effet ×1,1 à ×1,5 ; valeur ×1,5 à ×7) ; dès « rare »,
une stat gagne au moins +1.

## XP de métier

Une fabrication vaut 4 récoltes du niveau de l'objet (+10 %/niveau), −25 %/niveau si l'objet est trop
facile pour le métier (25 % min) ; recette inédite ×1,5. Tous les métiers d'artisanat sont ouverts dès
le départ (test solo).

## Technique

- `game/craft/craft_ai.gd` lance `python tools/craft/claude_craft.py requete.json reponse.json` dans un
  fil séparé ; le script appelle `claude -p --json-schema … --tools "" --model opus` depuis un dossier
  temporaire (aucun réglage de projet chargé). Fonctionne sur le PC où Claude Code est connecté.
- Cache des recettes et objets : `user://arthesia_craft.json`, partagé par toutes les parties du PC
  (« Nouvelle partie » ne l'efface pas).
- Réglage `craft_ai` (vrai par défaut) : faux pour forcer les noms provisoires.
- Tests : `tools/godot/craft_test.gd` (sans IA), `-- --ai` pour un vrai appel.

## Enchantement

On pose **un équipement** (un seul exemplaire) et **au moins un réactif**, et on choisit l'orientation de
la rune (Force, Arcane, Garde, Vivacité, Sagesse). Le niveau de la recette est celui de l'équipement.
L'objet enchanté est une copie de l'équipement (forme de base) qui gagne 20 / 30 / 40 % du budget de
stats de son niveau (cohérence aucune / normale / rare) sur les stats de l'orientation, garde son icône,
et ne peut plus être ni réenchanté ni réutilisé comme ingrédient. Le rang ne baisse jamais : un
équipement rare donne au moins un objet rare (plancher appliqué aux chances affichées). Claude le
renomme en gardant l'objet reconnaissable (section « enchantement » de `craft_prompt.md`).

## Carnet › Recettes

Toutes les recettes connues sur ce PC, par atelier : l'objet, ses stats, sa description, les
ingrédients (ce qu'on a / ce qu'il faut), combien de fois on l'a faite dans cette partie et le meilleur
rang obtenu (`profile.crafts`). « Préparer l'établi » : à la prochaine ouverture de cet atelier, les
ingrédients qu'on possède sont déjà posés.
