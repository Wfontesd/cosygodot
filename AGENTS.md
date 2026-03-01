# Floating Sanctuary

A cozy 2.5D isometric ecosystem management game. See `README.md` for the full Game Design Document.

## Cursor Cloud specific instructions

### Engine

- **Godot 4.6.1** is installed at `/usr/local/bin/godot`. The `.gitignore` is configured for Godot 4+.
- The README references Unity, but the `.gitignore` targets Godot. Treat Godot as the intended engine unless the project owner clarifies otherwise.

### Running Godot in headless mode

Since the Cloud VM has no display server, always use `--headless`:

```bash
godot --headless --path .              # Import resources / open project
godot --headless --path . --quit       # Quick import-and-quit
godot --headless --path . --script res://some_script.gd  # Run a script
```

### GDScript linting / validation

```bash
godot --headless --path . --check-only --script res://path/to/script.gd
```

Exit code 0 = valid, non-zero = parse/type errors printed to stderr.

### Running tests

No test framework is configured yet. When one is added (e.g. GUT — Godot Unit Test), run tests headlessly:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd   # GUT example
```

### Current repository state

This is a greenfield repo with only a GDD (`README.md`) and `.gitignore`. No Godot project (`project.godot`), scenes, scripts, or assets exist yet.
