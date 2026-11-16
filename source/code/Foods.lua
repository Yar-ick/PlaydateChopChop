import "code/GameplayTuning"
local t = GameplayTuning
Foods = {
    {name = "Carrot", path = "images/Carrot", scale = t.CARROT_SCALE,
        x = t.CARROT_X, y = t.CARROT_Y, startX = t.CARROT_BODY_START_X,
        endX = t.CARROT_BODY_END_X, boardY = t.BOARD_Y, referenceY = t.CUT_REFERENCE_Y},
    {name = "Cucumber", path = "images/Cucumber", scale = 1.1,
        x = 134, y = 117, startX = 134, endX = 269, boardY = 152, referenceY = 134},
    {name = "Potato", path = "images/Potato", scale = 0.65,
        x = 172, y = 103, startX = 173, endX = 249, boardY = 152, referenceY = 133},
}
