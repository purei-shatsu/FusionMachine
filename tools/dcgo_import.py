"""Import Digimon card data from the DCGO simulator into a SQLite database.

DCGO stores one Unity YAML `.asset` per card under
`CardBaseEntity/<Set>/<Color>/<Kind>/<CARDID>.asset`. This walks that tree and
upserts every card into `digimon.cdb` (schema in tools/schema.sql).

The import is incremental and idempotent: each card row keeps the sha1 of the
`.asset` it came from, so re-running after DCGO ships a new set only touches the
cards that are new or changed. Safe to run repeatedly.

    python tools/dcgo_import.py                 # uses the defaults below
    python tools/dcgo_import.py --prune         # also drop cards whose .asset is gone
"""

import argparse
import hashlib
import re
import sqlite3
import struct
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent

DEFAULT_DCGO = Path(r"D:\Git\DCGO\DCGO\Assets\CardBaseEntity")
DEFAULT_ART = Path(r"D:\Downloads\DCGO_Application\Assets\Textures\Card")
DEFAULT_DB = REPO / "digimon.cdb"

# Confirmed against sample cards: Monzaemon=0, Tai Kamiya=1, Gravity Crush=2, Upamon=3.
CARD_KINDS = {0: "Digimon", 1: "Tamer", 2: "Option", 3: "DigiEgg"}

# `m_Name: BT10_060_P1` -> alt-art printing of BT10-060. The CardID field itself
# stays the base id, so it is the merge key; this only picks which asset wins.
VARIANT_RE = re.compile(r"_P(\d+)$")

# cardColors is Unity's compact hex blob for an int array. It must NOT go through
# YAML: "01000000" matches YAML 1.1's octal int rule and would silently become 262144.
CARD_COLORS_RE = re.compile(r"^\s*cardColors:\s*(\S*)\s*$", re.MULTILINE)


def parse_asset(path):
    """Parse one Unity .asset into (fields, colors). Returns None for non-card assets."""
    text = path.read_text(encoding="utf-8")

    # Drop the Unity header (%YAML / %TAG / --- !u!114 &...) so this is plain YAML.
    body = text.split("\n", 3)[3]
    doc = yaml.safe_load(body)
    fields = doc.get("MonoBehaviour")
    if not fields or "CardID" not in fields:
        return None

    match = CARD_COLORS_RE.search(text)
    blob = match.group(1) if match else ""
    if len(blob) % 8:
        raise ValueError(f"{path}: cardColors blob {blob!r} is not a whole number of int32s")
    raw = bytes.fromhex(blob)
    colors = [v[0] for v in struct.iter_unpack("<i", raw)]

    return fields, colors


def blank_to_none(value):
    if value is None:
        return None
    value = str(value).strip()
    return value or None


def derive_color_names(cards):
    """Map colour int -> name using the <Color> folder each card sits in.

    Folder names are mostly right but not authoritative (some cards are misfiled),
    so take the majority folder per colour value rather than trusting any one card.
    """
    votes = defaultdict(Counter)
    for card in cards.values():
        if card["colors"]:
            votes[card["colors"][0]][card["folder_color"]] += 1
    return {value: tally.most_common(1)[0][0] for value, tally in votes.items()}


def collect(dcgo_root):
    """Walk the CardBaseEntity tree, merging alt-art printings into one card each."""
    best = {}
    for path in sorted(dcgo_root.rglob("*.asset")):
        parsed = parse_asset(path)
        if parsed is None:
            continue
        fields, colors = parsed

        card_id = fields["CardID"]
        variant = VARIANT_RE.search(path.stem)
        # Prefer the unsuffixed asset; otherwise the lowest -Pn.
        rank = -1 if variant is None else int(variant.group(1))

        rel = path.relative_to(dcgo_root)
        if card_id in best and best[card_id]["rank"] <= rank:
            continue
        best[card_id] = {
            "rank": rank,
            "fields": fields,
            "colors": colors,
            "path": path,
            "source_path": rel.as_posix(),
            "folder_color": rel.parts[1],
            "source_hash": hashlib.sha1(path.read_bytes()).hexdigest(),
        }
    return best


def build_row(card_id, card, art_dir, now):
    fields = card["fields"]

    set_code, _, number = card_id.rpartition("-")
    kind = fields["cardKind"]

    image = art_dir / f"{card_id}.webp"
    has_art = image.is_file()

    return {
        "card_id": card_id,
        "set_code": set_code,
        "card_number": int(number) if number.isdigit() else None,
        "name_en": fields["CardName_ENG"],
        "name_jp": blank_to_none(fields.get("CardName_JPN")),
        "card_kind": kind,
        "card_kind_name": CARD_KINDS[kind],
        "level": fields.get("Level"),
        "dp": fields.get("DP"),
        "play_cost": fields.get("PlayCost"),
        "rarity": fields.get("rarity"),
        "overflow_memory": fields.get("OverflowMemory"),
        "link_dp": fields.get("LinkDP"),
        "link_effect": blank_to_none(fields.get("LinkEffect")),
        "link_requirement": blank_to_none(fields.get("LinkRequirement")),
        "max_in_deck": fields.get("MaxCountInDeck"),
        "effect_en": blank_to_none(fields.get("EffectDiscription_ENG")),
        "inherited_effect_en": blank_to_none(fields.get("InheritedEffectDiscription_ENG")),
        "security_effect_en": blank_to_none(fields.get("SecurityEffectDiscription_ENG")),
        "sprite_name": blank_to_none(fields.get("CardSpriteName")),
        "image_file": image.name if has_art else None,
        "has_art": int(has_art),
        "source_path": card["source_path"],
        "source_hash": card["source_hash"],
        "updated_at": now,
    }


def write_children(db, card_id, card, color_names):
    for table in ("card_colors", "card_types", "card_forms", "card_attributes", "card_evo_costs"):
        db.execute(f"DELETE FROM {table} WHERE card_id = ?", (card_id,))

    db.executemany(
        "INSERT INTO card_colors (card_id, ord, color, color_name) VALUES (?, ?, ?, ?)",
        [(card_id, i, c, color_names.get(c)) for i, c in enumerate(card["colors"])],
    )
    for table, column, field in (
        ("card_types", "type_en", "Type_ENG"),
        ("card_forms", "form_en", "Form_ENG"),
        ("card_attributes", "attribute_en", "Attribute_ENG"),
    ):
        db.executemany(
            f"INSERT INTO {table} (card_id, ord, {column}) VALUES (?, ?, ?)",
            [(card_id, i, v) for i, v in enumerate(card["fields"].get(field) or [])],
        )
    db.executemany(
        "INSERT INTO card_evo_costs"
        " (card_id, ord, from_color, from_color_name, from_level, memory_cost)"
        " VALUES (?, ?, ?, ?, ?, ?)",
        [
            (
                card_id,
                i,
                evo.get("CardColor"),
                color_names.get(evo.get("CardColor")),
                evo.get("Level"),
                evo.get("MemoryCost"),
            )
            for i, evo in enumerate(card["fields"].get("EvoCosts") or [])
        ],
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dcgo", type=Path, default=DEFAULT_DCGO, help="DCGO CardBaseEntity folder")
    ap.add_argument("--art", type=Path, default=DEFAULT_ART, help="folder of <CardID>.webp art")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="output SQLite database")
    ap.add_argument("--prune", action="store_true", help="delete cards whose .asset is gone")
    args = ap.parse_args()

    cards = collect(args.dcgo)
    color_names = derive_color_names(cards)
    print(f"scanned {len(cards)} cards; colours: " + ", ".join(
        f"{v}={color_names[v]}" for v in sorted(color_names)))

    db = sqlite3.connect(args.db)
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript((REPO / "tools" / "schema.sql").read_text(encoding="utf-8"))

    known = dict(db.execute("SELECT card_id, source_hash FROM cards"))
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")

    added = updated = unchanged = 0
    for card_id, card in cards.items():
        if known.get(card_id) == card["source_hash"]:
            unchanged += 1
            continue

        row = build_row(card_id, card, args.art, now)
        columns = ", ".join(row)
        placeholders = ", ".join(f":{c}" for c in row)
        db.execute(
            f"INSERT INTO cards ({columns}) VALUES ({placeholders})"
            f" ON CONFLICT(card_id) DO UPDATE SET"
            + ", ".join(f" {c} = excluded.{c}" for c in row if c != "card_id"),
            row,
        )
        write_children(db, card_id, card, color_names)

        if card_id in known:
            updated += 1
        else:
            added += 1

    missing = sorted(set(known) - set(cards))
    if missing and args.prune:
        db.executemany("DELETE FROM cards WHERE card_id = ?", [(c,) for c in missing])

    db.commit()

    with_art = db.execute("SELECT count(*) FROM cards WHERE has_art = 1").fetchone()[0]
    total = db.execute("SELECT count(*) FROM cards").fetchone()[0]
    db.close()

    print(f"added {added} / updated {updated} / unchanged {unchanged}")
    if missing:
        action = "pruned" if args.prune else "still present (use --prune to delete)"
        print(f"missing .asset for {len(missing)} cards: {action}")
    print(f"{total} cards in {args.db}; {with_art} with art, {total - with_art} without")


if __name__ == "__main__":
    sys.exit(main())
