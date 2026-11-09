"""Pont entre le jeu et Claude Code pour inventer l'objet d'un craft inédit (technique « B » : version
de test, un seul joueur, sur le PC où Claude Code est installé et connecté).

Usage (lancé par le jeu) : python tools/craft/claude_craft.py <requete.json> <reponse.json>

La requête (écrite par game/craft/craft_ai.gd) contient l'atelier, le type d'objet demandé, les
ingrédients et les icônes possibles. La réponse est {"ok": true, "item": {...}} ou {"ok": false,
"error": "..."}. Les chiffres (niveau, stats, valeur, rareté) ne viennent jamais d'ici : le jeu les
calcule (game/craft/craft_rules.gd).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROMPT = HERE / "craft_prompt.md"
MODEL = os.environ.get("ARTHESIA_CRAFT_MODEL", "opus")
TIMEOUT = 180

STATS = ["hp", "atk", "def", "agi", "int", "sag"]
SCHEMA = {
    "type": "object",
    "properties": {
        "id": {"type": "string", "pattern": "^[a-z0-9_]{3,40}$"},
        "name": {"type": "string", "minLength": 2, "maxLength": 48},
        "description": {"type": "string", "minLength": 10, "maxLength": 320},
        "coherence": {"type": "string", "enum": ["aucune", "normale", "rare"]},
        "stat_weights": {
            "type": "object",
            "properties": {k: {"type": "integer", "minimum": 1, "maximum": 10} for k in STATS},
            "additionalProperties": False,
        },
        "weapon_style": {"type": "string", "enum": ["aucun", "dague", "lame", "hachette", "masse", "lance"]},
        "icon_from": {"type": "string"},
    },
    "required": ["id", "name", "description", "coherence", "stat_weights", "weapon_style", "icon_from"],
    "additionalProperties": False,
}


def find_claude():
    exe = shutil.which("claude")
    if exe:
        return exe
    for p in (Path.home() / ".local/bin/claude.exe", Path.home() / ".local/bin/claude"):
        if p.exists():
            return str(p)
    return None


def user_message(req):
    return ("Voici la combinaison inédite. Invente l'objet de base demandé.\n\n```json\n"
            + json.dumps(req, ensure_ascii=False, indent=2) + "\n```")


def run(req):
    exe = find_claude()
    if not exe:
        return {"ok": False, "error": "Claude Code introuvable (commande « claude »)."}
    args = [exe, "-p", "--output-format", "json", "--no-session-persistence", "--tools", "",
            "--model", MODEL, "--setting-sources", "", "--system-prompt-file", str(PROMPT),
            "--json-schema", json.dumps(SCHEMA)]
    t0 = time.time()
    with tempfile.TemporaryDirectory() as cwd:          # aucun CLAUDE.md ni réglage de projet chargé
        try:
            p = subprocess.run(args, input=user_message(req), capture_output=True, text=True,
                               encoding="utf-8", timeout=TIMEOUT, cwd=cwd)
        except subprocess.TimeoutExpired:
            return {"ok": False, "error": "Claude n'a pas répondu à temps."}
    try:
        out = json.loads(p.stdout)
    except json.JSONDecodeError:
        return {"ok": False, "error": (p.stderr or p.stdout or "réponse vide").strip()[:300]}
    if out.get("is_error") or not isinstance(out.get("structured_output"), dict):
        return {"ok": False, "error": str(out.get("result") or out.get("subtype") or "échec")[:300]}
    return {"ok": True, "item": out["structured_output"], "seconds": round(time.time() - t0, 1)}


def main():
    req_path, out_path = sys.argv[1], sys.argv[2]
    try:
        req = json.loads(Path(req_path).read_text(encoding="utf-8"))
        res = run(req)
    except Exception as e:                               # le jeu doit toujours recevoir une réponse
        res = {"ok": False, "error": f"{type(e).__name__}: {e}"}
    Path(out_path).write_text(json.dumps(res, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
