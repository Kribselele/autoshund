# Autoshund

A TFT-style autobattler starring teckels (dachshunds) and their friends, built with Godot 4 for the web.

- **Design plan:** https://claude.ai/artifact/DiHBiGRXeUpUbAWACHvMHz
- **Balance sheet:** https://claude.ai/artifact/SpQsPYvoSkEdQxfuYdgvHk
- **Play the latest build:** https://kribselele.github.io/autoshund/ (published from `main`)

## Project layout

| Path | What it holds |
| --- | --- |
| `data/breeds.json` | The 35 breeds: groups, jobs, tier and base stats, from the balance sheet |
| `scripts/battle/` | The battle rules as pure logic: board, targeting, long teckels, synergies |
| `scripts/game/` | The season: economy, shared kennel, shop, packs, merging, AI rivals |
| `scripts/ui/` | The game screen (shop, board, bench, league) and the battle view |
| `tests/` | Headless tests for the battle, the game rules and the screen |
| `tools/sample_fight.gd` | Prints a demo fight's result, for quick balance checks |
| `tools/sample_season.gd` | Plays a whole season with bots and prints the standings |
| `tools/ui_snapshots.gd` | Saves screenshots of the shop and a battle |

## Running locally

With Godot 4.3:

```sh
godot --headless --import
godot --headless -s tests/test_battle.gd   # run the tests (also test_game.gd, test_ui.gd)
godot --headless -s tools/sample_fight.gd  # print a sample fight
SEED=3 godot --headless -s tools/sample_season.gd  # play a bot season
godot                                      # open the editor
```

Every push runs the tests and builds the web version. Pushes to `main` publish it to GitHub Pages.
