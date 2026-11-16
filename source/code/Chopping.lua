-- Gameplay rules independent of rendering and device APIs.
import "code/GameplayTuning"
import "code/Foods"
local tuning = GameplayTuning
Chopping = {}
Chopping.__index = Chopping
function Chopping.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end
function Chopping.new(food, random)
    local self = setmetatable({food = food or Foods[1], random = random or math.random,
        score = 0, cuts = 0, foodsChopped = 0}, Chopping)
    self:nextFood()
    return self
end
function Chopping:nextFood()
    self.startX, self.endX = self.food.startX, self.food.endX
    self.edge, self.x = self.endX, self.endX - 10
    self.finished, self.armed, self.height = false, false, 1
    self.offsetX, self.rotation, self.peakSpeed, self.squash = 0, 0, 0, 0
    self.cooldown, self.slip, self.ingredientCuts = 0, 0, 0
end
function Chopping:setBounds(first, last)
    self.startX, self.edge, self.endX = first, last, last
end
function Chopping:update(angle, docked, velocity, dt)
    dt = math.max(dt, 0.001)
    self.cooldown = math.max(0, self.cooldown - dt)
    self.squash = math.max(0, self.squash - dt * 0.6)
    local previousHeight = self.height
    angle = angle % 360
    local span = (tuning.KNIFE_UPPER_ANGLE - tuning.KNIFE_LOWER_ANGLE) % 360
    assert(span > 0 and span < 180, "Knife crank arc must be between 0 and 180 degrees")
    local halfSpan = span / 2
    local relative = (angle - tuning.KNIFE_LOWER_ANGLE - halfSpan + 180) % 360 - 180
    self.height = (Chopping.clamp(relative, -halfSpan, halfSpan) + halfSpan) / span
    if docked then self.height = 1; self.armed = false; self.peakSpeed = 0 end
    if self.height > 0.38 then
        self.x = Chopping.clamp(self.x + velocity * dt, self.startX - 6, self.endX + 20)
    end
    if docked or self.finished then return false end
    if math.abs(relative) > halfSpan + tuning.CRANK_OVERSHOOT then self.armed = false end
    local readyBelow = math.min(tuning.READY_BELOW_UPPER, span * 0.28)
    if relative >= halfSpan - readyBelow and relative <= halfSpan + tuning.READY_ABOVE_UPPER then
        if not self.armed then self.peakSpeed = 0 end
        self.armed = true
    end
    if self.armed then
        self.peakSpeed = math.max(self.peakSpeed, (previousHeight - self.height) / dt)
        if self.food.behavior == "soft" and self.height < 0.65
            and self.x >= self.startX and self.x <= self.edge
            and self.peakSpeed > tuning.TOMATO_MAX_SPEED then self.squash = 0.24 end
    end
    if not self.armed or self.height > tuning.CHOP_HEIGHT_THRESHOLD or self.cooldown > 0 then return false end
    self.armed = false
    local x = math.floor(self.x + 0.5)
    if x < self.startX or x > self.edge - 2 then return true end
    local width = self.edge - x
    local points = math.max(5, math.floor(120 / math.sqrt(width / 2)))
    local label = width <= 6 and "Paper thin!" or (width <= 14 and "Nice slice!" or "Thick cut")
    local result = {x = x, width = width, points = points, label = label}
    if self.food.behavior == "soft" then
        result.crushed = self.peakSpeed > tuning.TOMATO_MAX_SPEED
        if result.crushed then
            result.points = math.max(1, math.floor(points * tuning.TOMATO_CRUSH_MULTIPLIER))
            result.label, self.squash = "Crushed! Slow down", 0.24
        else result.label = "Smooth cut!" end
    end
    self.edge = x
    self.score, self.cuts = self.score + result.points, self.cuts + 1
    self.ingredientCuts = self.ingredientCuts + 1
    if self.edge <= self.startX + 4 then
        self.finished = true
        self.foodsChopped = self.foodsChopped + 1
    elseif self.food.behavior == "slippery" then
        local shift = self.random(tuning.CUCUMBER_SLIP_MIN, tuning.CUCUMBER_SLIP_MAX)
        if self.random(0, 1) == 0 then shift = -shift end
        local offset = Chopping.clamp(self.offsetX + shift, -tuning.CUCUMBER_MAX_OFFSET, tuning.CUCUMBER_MAX_OFFSET)
        shift = offset - self.offsetX
        -- At a travel limit, slip back toward the center instead of staying still.
        if shift == 0 then shift = self.offsetX > 0 and -tuning.CUCUMBER_SLIP_MIN or tuning.CUCUMBER_SLIP_MIN end
        self.offsetX, self.slip = self.offsetX + shift, shift
        self.startX, self.edge, self.endX = self.startX + shift, self.edge + shift, self.endX + shift
        self.cooldown, result.shift = tuning.FOOD_SETTLE_TIME, shift
    elseif self.food.behavior == "rolling" and self.random(1, 100) <= tuning.POTATO_ROLL_CHANCE then
        local rotation = self.random(3, tuning.POTATO_MAX_ROLL)
        if self.random(0, 1) == 0 then rotation = -rotation end
        result.rotation = rotation
        self.rotation = self.rotation + rotation
        self.cooldown = tuning.FOOD_SETTLE_TIME
    elseif self.food.behavior == "layered" and self.ingredientCuts % tuning.ONION_LAYER_EVERY == 0 then
        result.peel = true
    end
    return true, result
end
