
# Chop Chop!

A crank-controlled food chopping Playdate game.

The main menu offers **Free chopping** and **60-second rush**. Use the D-pad to choose and A to start.

In the timed mode, finishing a vegetable automatically spawns a random one different from the current vegetable, while preserving your score and totals. The timer continues during the short spawn transition; system pauses stop the clock. A cannot skip ingredients. B exits to the main menu. When time expires, A retries and B returns to the menu.

`CHALLENGE_SECONDS` and `CHALLENGE_SPAWN_DELAY` in `source/code/GameplayTuning.lua` control the duration and transition delay.

Knife control is relative: rotate clockwise to lift and counterclockwise to cut. A full stroke takes **30 degrees**, starting from any physical crank angle. Continuing past the raised or lowered stop has no effect; reversing direction moves the knife immediately. Change `KNIFE_TRAVEL_ANGLE` in GameplayTuning to adjust the stroke.

A vegetable counts as finished when **5% or less of its original edible area remains**. Leaves are excluded, and potato rolls preserve the tracked area. `FOOD_COMPLETION_FRACTION` sets this threshold. Area tracking uses cached outlines and does not scan pixels while chopping.
