# Can Clash

A planned 2.5D five-player LAN arena game inspired by Tumbang Preso.

## Current status

This repository contains a Godot 4 project scaffold. Gameplay and networking
are not implemented. The initial menu displays a scaffold status message.
Godot 4 is the proposed engine from the concept note; confirm the engine and
specific version with the team before implementation.

## Open the project

1. Install Godot 4 using its official distribution.
2. Import `project.godot` in the Godot Project Manager.
3. Open the project and run the main scene.

## Layout

- `autoload/`: LAN session and saved user settings.
- `game/`: match, player, slipper, can, and arena scenes with adjacent scripts.
- `ui/`: menu, lobby, HUD, results, pause menu, settings, and shared theme.
- `assets/`: character, prop, environment, UI, effect, audio, font, and shader assets.
- `docs/`: original concept note, decisions, networking plan, playtest checklist, and credits.
- `builds/`: local exports; generated build contents are excluded from Git.

## Implementation order

LAN lobby, movement, throwing and can, retrieval and safe returns, tagging,
scoring and results. The host must validate gameplay outcomes.

Proposed controls are WASD movement, mouse aim and charged throwing, an
Interact key, and a lunge key. Bindings, match duration, and tie rules remain TBD.


### Local and online play

Play Local hosts five-player LAN games. Play Online creates or joins four-player
GD-Sync Free rooms using a shared code. Online requires the developer's game API
configuration; see [GD-Sync setup and verification](docs/online_setup.md).
LAN, Practice and developer mode work without online keys.

Hold left-click and release the bouncing marker inside the randomized green zone
for full power and accuracy. Yellow is weaker; red adds aim error. Tagged players
regain movement immediately while retaining one second of re-tag protection.
