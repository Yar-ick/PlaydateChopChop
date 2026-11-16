-- Gameplay rules independent of rendering and device APIs.
import "code/GameplayTuning"
import "code/Foods"
local tuning = GameplayTuning
Chopping = {}
Chopping.__index = Chopping
function Chopping.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end
function Chopping.new(food)
    food = food or Foods[1]
    return setmetatable({food = food, x = food.endX - 10, edge = food.endX, height = 1, armed = false,
        score = 0, cuts = 0, foodsChopped = 0, finished = false}, Chopping)
end
function Chopping:nextFood()
    self.edge, self.x, self.finished, self.armed = self.food.endX, self.food.endX - 10, false, false
end
function Chopping:update(angle, docked, velocity, dt)
    angle = angle % 360
    local span = (tuning.KNIFE_UPPER_ANGLE - tuning.KNIFE_LOWER_ANGLE) % 360
    assert(span > 0 and span < 180, "Knife crank arc must be between 0 and 180 degrees")
    local halfSpan = span / 2
    local midpoint = tuning.KNIFE_LOWER_ANGLE + halfSpan
    local relative = (angle - midpoint + 180) % 360 - 180
    self.height = (Chopping.clamp(relative, -halfSpan, halfSpan) + halfSpan) / span
    if docked then self.height = 1; self.armed = false end
    -- Clear the food before moving sideways.
    if self.height > 0.38 then
        self.x = Chopping.clamp(self.x + velocity * dt, self.food.startX - 6, self.food.endX + 20)
    end
    if docked or self.finished then return false end
    -- A full revolution via zero must not become a chop.
    if math.abs(relative) > halfSpan + tuning.CRANK_OVERSHOOT then self.armed = false end
    if relative >= halfSpan - tuning.READY_BELOW_UPPER
        and relative <= halfSpan + tuning.READY_ABOVE_UPPER then self.armed = true end
    if not self.armed or self.height > tuning.CHOP_HEIGHT_THRESHOLD then return false end
    self.armed = false
    local x = math.floor(self.x + 0.5)
    if x < self.food.startX or x > self.edge - 2 then return true end
    local width = self.edge - x
    local points = math.max(5, math.floor(120 / math.sqrt(width / 2)))
    local label = width <= 6 and "Paper thin!" or (width <= 14 and "Nice slice!" or "Thick cut")
    self.edge = x
    self.score, self.cuts = self.score + points, self.cuts + 1
    if self.edge <= self.food.startX + 4 then
        self.finished = true
        self.foodsChopped = self.foodsChopped + 1
    end
    return true, {x = x, width = width, points = points, label = label}
end
