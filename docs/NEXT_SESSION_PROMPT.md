# Prompt for the next session

Copy everything below the line into a new Claude Code session opened in this folder.

---

This session is for building the new maps.

1. Read `docs/HANDOFF.md`, then `docs/MAP_BRIEFS.md`, then DESIGN §4 and §7.
2. Build the first map in the briefs, SPIRAL. Before you commit to a layout, ask me the design questions in §7 of the briefs, all in one batch. Decide everything else yourself, and don't stop to ask about anything that isn't a design question.
3. Follow the patterns in `scripts/maps/rooftops.gd`. Give the map a timed course using `Course` (copy `_course()`), add it to the main menu, and add it to the level lint.
4. Follow the efficiency rules in `CLAUDE.md`. Build static geometry through `LevelBuilder`, and make the map feel huge with the cheap tricks in the briefs (§3), not expensive geometry. My main machine is a mid-range Windows PC.
5. Don't edit `scripts/player/*` or `scripts/maps/rooftops.gd` unless the map can't be built otherwise. If you have to, tell me why first.
6. Check the map with `--shots` screenshots and a short `--bench`. Keep windowed runs short because the Mac runs hot, and close anything you launch.
7. Run `tests/run_tests.sh` before you finish.
8. When SPIRAL is ready for me to play, run `tools/build.sh all`, update `docs/HANDOFF.md` and the briefs, and commit. Then give me a short summary of what to try and anything you need me to decide.
