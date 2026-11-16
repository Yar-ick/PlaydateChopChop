import "code/GameplayTuning"
local t = GameplayTuning
Foods = {
    {name = "Carrot", behavior = "standard", hint = "Firm: practice thin slices", path = "images/Carrot", scale = t.CARROT_SCALE,
        x = t.CARROT_X, y = t.CARROT_Y, startX = t.CARROT_BODY_START_X,
        endX = t.CARROT_BODY_END_X, boardY = t.BOARD_Y, referenceY = t.CUT_REFERENCE_Y},
    {name = "Cucumber", behavior = "slippery", hint = "Slippery: adjust your aim", path = "images/Cucumber", scale = 1.1,
        x = 134, y = 117, startX = 134, endX = 269, boardY = 152, referenceY = 134},
    {name = "Potato", behavior = "rolling", hint = "Rolls: watch the new edge", path = "images/Potato", scale = 0.65,
        x = 172, y = 103, startX = 173, endX = 249, boardY = 152, referenceY = 133},
    {name = "Tomato", behavior = "soft", hint = "Soft: lower the crank slowly", path = "images/Tomato", scale = 0.6,
        x = 174, y = 98, startX = 168, endX = 250, boardY = 152, referenceY = 134},
    {name = "Onion", behavior = "layered", hint = "Layered: loose skins and tears", path = "images/Onion", scale = 0.65,
        x = 172, y = 105, startX = 171, endX = 250, boardY = 152, referenceY = 136},
}