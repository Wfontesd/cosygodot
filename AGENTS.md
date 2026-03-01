# Floating Sanctuary

A cozy 2.5D isometric ecosystem management game built with Godot 4. See `README.md` for the full Game Design Document (in French).

## Cursor Cloud specific instructions

### Engine

- **Godot 4.6.1** is installed at `/usr/local/bin/godot`. The `.gitignore` is configured for Godot 4+.
- The README references Unity, but the project uses Godot. Treat Godot as the engine.

### Running the game

```bash
# GUI mode (requires DISPLAY)
DISPLAY=:1 godot --path /workspace

# Headless mode (no display)
godot --headless --path . --quit          # import resources
godot --headless --path .                 # run main scene headlessly (quits on get_tree().quit())
timeout 10 godot --headless --path .      # run for N seconds then kill
```

### GDScript validation

```bash
godot --headless --path . --quit   # clean import, exit code 0 = no errors
```

Individual script `--check-only` fails on scripts that reference autoloads (GameManager, EcosystemManager, Enums). This is expected — use project-level import to validate.

### Project structure

| Directory | Contents |
|---|---|
| `scripts/` | Autoload singletons: `enums.gd`, `game_manager.gd`, `ecosystem_manager.gd` |
| `scenes/player/` | Player character (CharacterBody2D, isometric movement, proximity interaction) |
| `scenes/creatures/` | Creature AI (`creature.gd/.tscn`) and Egg system (`egg.gd/.tscn`) |
| `scenes/buildings/` | Building system (5 types: incubator, rest zone, nature cabin, magic tower, mining workshop) |
| `scenes/ui/` | HUD, interaction prompts, radial menu, building panel |
| `scenes/main.*` | Main scene assembling world, buildings, player, eggs, UI |

### Gotchas

- All visuals use placeholder `_draw()` calls — no external image assets needed.
- Dynamic GDScript created via `GDScript.new()` must use `=` (not `:=`) for Dictionary `.get()` calls to avoid Variant inference warnings treated as errors in Godot 4.6.
- Egg (Area2D) interaction requires checking both the area node itself and its parent when resolving interaction targets (see `player.gd` `_update_interaction_target`).
