"""Make every generated asset: runs the generators in generation/ into assets/outputs/.

The art-side counterpart of master_sync.py (which pushes the scripts in src/ to TTS).
Card text and per-card data live in generation/content.json.

    python master_make.py                     run every generator
    python master_make.py agenda house        run only these (a name or the start of one)
    python master_make.py --list              list the generators

Each generator runs as `python -m generation.<name>` from the project root, in the order below.
A failing generator is reported and the rest still run; the exit code is non-zero if any failed.
"""

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# name -> what it makes (outputs under assets/outputs/)
GENERATORS = {
    "agenda_card": "Secret Agenda cards + back -> agendas/",
    "house_card": "House selection cards + back -> house_cards/",
    "signature": "House signature decals -> house_signatures/",
    "voting_card": "Aye / Nay / Pass vote cards + back -> vote_cards/",
    "token_card": "Moderator / Leader tokens -> tokens/",
    "player_board": "player board -> boards/",
    "scoring_card": "errata + start / end of game tablets -> aids/",
    "kd_card": "house-rule cards -> aids/",
    "legend_card": "Legend of Special Abilities -> aids/",
    "scorecard": "session scorecard -> aids/",
    "house_stats_card": "House avg / max tracker -> aids/",
}


def resolve(names):
    """Each name must equal a generator or be the start of exactly one."""
    picked = []
    for name in names:
        hits = [g for g in GENERATORS if g == name] or [g for g in GENERATORS if g.startswith(name)]
        if len(hits) != 1:
            sys.exit(f"error: {name!r} matches {hits or 'no generator'}; see --list")
        if hits[0] not in picked:
            picked.append(hits[0])
    return picked


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="generators to run (default: all)")
    ap.add_argument("--list", action="store_true", help="list the generators and exit")
    a = ap.parse_args()

    if a.list:
        for g, what in GENERATORS.items():
            print(f"  {g:<17} {what}")
        return

    failed = []
    for g in resolve(a.names) if a.names else list(GENERATORS):
        print(f"== {g}", flush=True)
        start = time.time()
        if subprocess.run([sys.executable, "-m", f"generation.{g}"], cwd=ROOT).returncode:
            failed.append(g)
            print(f"!! {g} failed", flush=True)
        else:
            print(f"   done in {time.time() - start:.1f}s", flush=True)

    if failed:
        sys.exit(f"make: {len(failed)} failed: {', '.join(failed)}")
    print("make: all done")


if __name__ == "__main__":
    main()
