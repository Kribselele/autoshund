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
| `scripts/main.gd` | The battle viewer that plays a demo fight |
| `tests/test_battle.gd` | Headless tests for the battle rules |
| `tools/sample_fight.gd` | Prints the demo fight's result, for quick balance checks |

## Running locally

With Godot 4.3:

```sh
godot --headless --import
godot --headless -s tests/test_battle.gd   # run the tests
godot --headless -s tools/sample_fight.gd  # print a sample fight
godot                                      # open the editor
```

Every push runs the tests and builds the web version. Pushes to `main` publish it to GitHub Pages.
