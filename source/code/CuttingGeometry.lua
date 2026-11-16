import "code/GameplayTuning"
CuttingGeometry = {}
local tuning = GameplayTuning

-- All cut boundaries use the same blade-aligned line through the carrot.
function CuttingGeometry.cutX(centerX, y)
    return centerX + tuning.CUT_SLOPE * (y - tuning.CUT_REFERENCE_Y)
end

function CuttingGeometry.pose(centerX, height)
    local progress = 1 - height
    local eased = progress * progress * (3 - 2 * progress)
    local slide = (eased - 0.5) * tuning.KNIFE_STROKE_TRAVEL
    -- Slide along the blade while lowering vertically. The eased slide makes
    -- a curved slicing stroke; reversing the crank withdraws the knife.
    local y = tuning.BOARD_Y + slide
    return CuttingGeometry.cutX(centerX, y), y - height * tuning.KNIFE_LIFT
end
