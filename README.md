
# Chop Chop

A Playdate game-feel prototype using the supplied carrot and knife art. Starts directly on the chopping board.

- Turn the crank to **270 degrees** to raise the knife, then back to **180 degrees** to chop.
- Tilt left/right or use the **left/right D-pad** to aim. Lift the blade clear of the carrot to move it.
- Work from the carrot's right tip toward the leaves. The dotted line marks the cut.
- Thin slices earn more points: `floor(120 / sqrt(width / 2))`. Minimum slice width is 2 screen pixels. Empty cuts earn nothing.
- **A** brings in a fresh carrot, keeping the session score. **B** centers tilt for your current grip.
- The system menu has Restart, Center tilt, and Sound. Scores are temporary.

Each slice falls away with a short chop sound and score feedback. There is no time limit, so you can experiment with thickness and rhythm.

Change `KNIFE_UPPER_ANGLE` and `KNIFE_LOWER_ANGLE` in `source/code/GameplayTuning.lua` to tune the crank positions, then rebuild. The same file exposes the ready and contact tolerances. The decreasing-angle arc from upper to lower must be less than 180 degrees; crossing zero is supported. The on-screen raise hint follows the configured angle.

Build with the Playdate SDK (`pdc` on PATH), from the project folder:

```powershell
New-Item -ItemType Directory -Force builds | Out-Null
pdc source builds/ChopChop.pdx
& "$env:PLAYDATE_SDK_PATH/bin/PlaydateSimulator.exe" "$pwd/builds/ChopChop.pdx"
```

In the Simulator, undock and rotate the crank with its onscreen control; use the keyboard arrows for horizontal movement. Test tilt and calibrate with B on hardware.

To build the regression checks, run `./tests/BuildTests.ps1`, then open `builds/ChopTests.pdx` in the Simulator. The screen should show `PASS: 22 checks`. These exercise custom angles (including crossing zero), the gameplay rules and scripted frames of the real game, including sound, falling pieces, completion, and fresh-carrot input.
