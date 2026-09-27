# Prompt for the next session

Copy everything below the line into a new Claude Code session opened in the project folder.

---

This session continues **Split Second**.

1. Read `docs/HANDOFF.md` (start with "This session" and "Known issues / next steps"), then `docs/ART_DIRECTION.md`, `docs/MAP_BRIEFS.md` §0 and `CLAUDE.md`.
2. Ask me for my playtest notes on the list in HANDOFF next steps §0 (SPIRAL, Pendulum Hall, swing grapple, weapons, momentum, aim assist) before changing any of those systems' feel. Ask everything in one batch.
3. Continue the AAA art pass (`ART_DIRECTION.md` §4): merge any finished `worktree-agent-*` branch first, then the museum kit for Pendulum Hall, a training-dummy model, and weapons on the third-person avatar. Follow "Mirror's Edge bones, cyberpunk skin": clean readable route surfaces, dense detail around them.
4. Then finish Pendulum Hall (dressing, a timed par) and start Spillway (`MAP_BRIEFS.md` §5.3; prototype one bank first).
5. Rules:
   - Every change should make movement and gameplay feel satisfying and addictive.
   - Maps are big but full.
   - Run on a mid-range Windows PC: bench Low and High, and never bench while another agent's Godot or Blender is running.
   - Keep windowed runs short (the Mac runs hot).
   - Run `tests/run_tests.sh` before finishing.
   - Run `tools/build.sh all` before telling me something is ready.
   - Update HANDOFF and commit.
