# Parkour Shooter

A first-person parkour shooter for Mac (Windows later), built in Godot 4.7. See [docs/DESIGN.md](docs/DESIGN.md) and [docs/ROADMAP.md](docs/ROADMAP.md).

## Run it

Double-click `build/mac/Parkour Shooter.app` (build it with `tools/build.sh`), or on Windows run `build/windows/ParkourShooter.exe`. From source:

```sh
brew install --cask godot    # once (Godot 4.7.x)
godot --path .               # play the Movement Gym
godot -e --path .            # open the editor
```

## Controls

Titanfall 2 / Apex PC conventions.

| Action | Keyboard / Mouse | Xbox |
|---|---|---|
| Move / look | WASD / mouse | Left stick / right stick |
| Sprint | Hold Shift | Click L3 (toggle) |
| Jump / double jump / wall-kick | Space | A |
| Slide / crouch (hold, release to stand) | Ctrl or C | B |
| Grapple (hold, release to let go) | Q or mouse side button | LB |
| Fire / aim | LMB / RMB | RT / LT |
| Reload | R | X |
| Melee | V | R3 |
| Swap weapon | 1 / 2 / mouse wheel | Y |
| Restart at checkpoint | T | View |
| Previous / next station | [ / ] | D-pad left / right |
| Tuning panel | ` (backtick) · Esc closes | Menu |
| Debug readout | O | — |
| Third-person view | P | — |
| Release / capture mouse | Esc / click | — |

You walk by default and sprint with Shift or L3. Slides and vaults need sprint speed. Auto-sprint is an option in the tuning panel's Player tab.

## How the moves work

- **Wall-run:** jump at any wall at an angle while holding forward. Jump again to kick off in the direction you're looking. A jump pressed just after the wall ends still counts as a kick.
- **Wall-climb:** jump at a wall *head-on* (within ~35°) to run up it. Jump to kick back off; the camera turns 180° for you. You can climb each wall once per airtime, so chimneys work.
- **Mantle / vault:** jump into a ledge holding forward. Sprint into waist-high cover to vault it without losing speed.
- **Slide-hop:** slide, jump, and keep crouch held as you land. You land straight back into a slide. Each chained slide adds a smaller boost.
- **Grapple:** hold to be pulled toward where you aim; release (or jump) to let go with your momentum. Cyan points attract your aim. If you reach a ledge while grappling, you mantle onto it automatically.

## Tuning feel

Press **F1** in game. Every movement, camera, and weapon number is a live slider. **Save as default** writes to `tuning/*.tres` and `scripts/weapons/rifle.tres`, so tuned values end up in the repo.

## Tests

```sh
tests/run_tests.sh            # all headless movement + weapon tests
tests/run_tests.sh wallrun    # one test
godot --path . -- --shots=/tmp/shots   # screenshot every station
godot --path . -- --bench              # frame-time benchmark
```
