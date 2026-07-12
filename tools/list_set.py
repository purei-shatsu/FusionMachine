"""List the cards of one set, with the fields the fusion rule reads.

Prints level, DP, traits and colours, one card per row. The traits are the card's
card_types resolved through DigimonTraits.lua exactly as the game resolves them:
slop dropped, the rest mapped to the group the fusion rule compares, capped at the
first two. Agumon's raw "Reptile, LIBERATOR" shows up as "Dinosaur".

    python tools/list_set.py EX11               # the Digimon of EX-11
    python tools/list_set.py EX11 --all         # Tamers, Options and DigiEggs too
    python tools/list_set.py EX11 --with-art    # only the cards the game can draw
    python tools/list_set.py EX11 --raw-traits  # every raw DCGO trait, ungrouped
    python tools/list_set.py EX11 --csv         # comma-separated instead of aligned
"""

import argparse
import csv
import re
import sqlite3
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

DEFAULT_DB = REPO / "digimon.cdb"
DEFAULT_TRAITS = REPO / "DigimonTraits.lua"

QUERY = """
    SELECT c.card_id,
           c.name_en,
           c.card_kind_name,
           c.level,
           c.dp,
           (SELECT group_concat(type_en, '/') FROM
                (SELECT type_en FROM card_types
                  WHERE card_id = c.card_id ORDER BY ord)),
           (SELECT group_concat(color_name, '/') FROM
                (SELECT color_name FROM card_colors
                  WHERE card_id = c.card_id ORDER BY ord)),
           c.has_art
      FROM cards c
     WHERE c.set_code = ?
       AND (? = 0 OR c.card_kind = 0)
       AND (? = 0 OR c.has_art = 1)
     ORDER BY c.level, c.card_number
"""

HEADER = ["Card", "Name", "Kind", "Lvl", "DP", "Traits", "Colors", "Art"]

MAX_TRAITS = 2

GROUP = re.compile(r'^ {4}(?:\["([^"]+)"\]|(\w+)) = \{')
GROUPED_TRAIT = re.compile(r'^ {8}"([^"]+)"')
SLOP_START = re.compile(r"^local slop = \{")
SLOP_TRAIT = re.compile(r'^ {4}"([^"]+)"')


def loadTraits(path):
    """The raw trait -> group map and the slop set, read out of DigimonTraits.lua so the
    game and this script cannot drift apart."""
    groups = {}
    slop = set()
    group = None
    inSlop = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if SLOP_START.match(line):
            inSlop = True
            continue
        if inSlop:
            raw = SLOP_TRAIT.match(line)
            if raw:
                slop.add(raw.group(1))
            continue
        header = GROUP.match(line)
        if header:
            group = header.group(1) or header.group(2)
            continue
        raw = GROUPED_TRAIT.match(line)
        if raw and group:
            groups[raw.group(1)] = group
    return groups, slop


def getGroups(rawTraits, groups, slop):
    """The same rule as DigimonTraits.getGroups: the first two distinct non-slop groups,
    in ord order. A raw trait in neither table is what DigimonTraits refuses to bucket
    silently, so blow up here too rather than quietly dropping it."""
    resolved = []
    for rawTrait in rawTraits:
        if rawTrait in slop:
            continue
        if rawTrait not in groups:
            sys.exit(f"unknown trait '{rawTrait}': group it in DigimonTraits, or slop it")
        group = groups[rawTrait]
        if group not in resolved:
            resolved.append(group)
            if len(resolved) == MAX_TRAITS:
                break
    return resolved


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("set_code", help="the set to list, e.g. EX11")
    ap.add_argument("--all", action="store_true", help="include Tamers, Options and DigiEggs")
    ap.add_argument("--with-art", action="store_true", help="only cards with art, i.e. the ones the game uses")
    ap.add_argument("--raw-traits", action="store_true", help="show every raw DCGO trait instead of the groups")
    ap.add_argument("--csv", action="store_true", help="print CSV instead of an aligned table")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="the Digimon database")
    ap.add_argument("--traits", type=Path, default=DEFAULT_TRAITS, help="the Lua trait grouping")
    args = ap.parse_args()

    db = sqlite3.connect(args.db)
    cards = db.execute(QUERY, (args.set_code, 0 if args.all else 1, 1 if args.with_art else 0)).fetchall()
    db.close()

    if not cards:
        sys.exit(f"no cards in set {args.set_code}")

    groups, slop = loadTraits(args.traits)

    rows = []
    for card_id, name, kind, level, dp, rawTraits, colors, has_art in cards:
        traits = rawTraits or ""
        #only a Digimon's traits are grouped: the fusion rule never reads any other kind, and
        #Tamers and Options carry types the map deliberately does not cover
        if rawTraits and not args.raw_traits and kind == "Digimon":
            traits = "/".join(getGroups(rawTraits.split("/"), groups, slop))
        rows.append(
            [card_id, name, kind, str(level), str(dp), traits, colors or "", "yes" if has_art else "no"]
        )

    if args.csv:
        out = csv.writer(sys.stdout, lineterminator="\n")
        out.writerow(HEADER)
        out.writerows(rows)
        return

    widths = [max(len(row[i]) for row in [HEADER] + rows) for i in range(len(HEADER))]
    for row in [HEADER] + rows:
        print("  ".join(cell.ljust(widths[i]) for i, cell in enumerate(row)).rstrip())
    print(f"\n{len(rows)} cards")


if __name__ == "__main__":
    sys.exit(main())
