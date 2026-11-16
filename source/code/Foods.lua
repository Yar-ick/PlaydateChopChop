import "code/GameplayTuning"
local t = GameplayTuning
Foods = {
    {name = "Carrot", behavior = "standard", hint = "Firm: practice thin slices", path = "images/Carrot", scale = t.CARROT_SCALE,
        x = t.CARROT_X, y = t.CARROT_Y, startX = t.CARROT_BODY_START_X,
        endX = t.CARROT_BODY_END_X, boardY = t.BOARD_Y, referenceY = t.CUT_REFERENCE_Y},
    {name = "Cucumber", behavior = "slippery", hint = "Slippery: adjust your aim", path = "images/Cucumber", scale = 1.0,
        x = 132, y = 143, startX = 132, endX = 267, boardY = 152, referenceY = 160},
    {name = "Potato", behavior = "rolling", hint = "Rolls: watch the new edge", path = "images/Potato", scale = 0.65,
        x = 162, y = 130, startX = 163, endX = 239, boardY = 152, referenceY = 160},
    {name = "Tomato", behavior = "soft", hint = "Soft: lower the crank slowly", path = "images/Tomato", scale = 0.6,
        x = 164, y = 124, startX = 158, endX = 240, boardY = 152, referenceY = 160},
    {name = "Onion", behavior = "layered", hint = "Layered: loose skins and tears", path = "images/Onion", scale = 0.65,
        x = 161, y = 129, startX = 160, endX = 239, boardY = 152, referenceY = 160},
}