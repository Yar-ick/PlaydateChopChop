
# Chop Chop!

A crank-controlled food chopping Playdate game.

The main menu offers **Free chopping** and **60-second rush**. Use the D-pad to choose and A to start.

In the timed mode, finishing a vegetable automatically spawns a random one while preserving your score and totals. The timer continues during the short spawn transition; system pauses stop the clock. A cannot skip ingredients. B exits to the main menu. When time expires, A retries and B returns to the menu.

`CHALLENGE_SECONDS` and `CHALLENGE_SPAWN_DELAY` in `source/code/GameplayTuning.lua` control the duration and transition delay.
