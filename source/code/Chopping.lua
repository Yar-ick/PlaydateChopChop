-- Gameplay rules independent of rendering and device APIs.
import "code/GameplayTuning"
import "code/Foods"
import "code/RunStats"
local tuning = GameplayTuning
Chopping = {}
Chopping.__index = Chopping
function Chopping.clamp(value, low, high)
    return math.max(low, math.min(high, value))
end
function Chopping.new(food, random)
    local self = setmetatable({food = food or Foods[1], random = random or math.random,
        score = 0, cuts = 0, foodsChopped = 0}, Chopping)
    self.progress=RunStats.new()
    self:nextFood()
    return self
end
function Chopping:syncTotals()
    self.score,self.cuts,self.foodsChopped=self.progress.score,self.progress.cuts,self.progress.foodsChopped
end
function Chopping:inheritProgress(other)
    self.progress=other.progress
    self:syncTotals()
end
function Chopping:nextFood()
    self.startX, self.endX = self.food.startX, self.food.endX
    self.edge, self.x = self.endX, self.endX - 10
    self.initialWidth, self.remainingFraction = self.endX - self.startX, 1
    self:syncCrank()
    self.finished, self.armed, self.height = false, false, 1
    self.offsetX, self.rotation, self.peakSpeed, self.squash = 0, 0, 0, 0
    self.cooldown, self.slip, self.ingredientCuts, self.cutSpeed = 0, 0, 0, 0
end
function Chopping:setBounds(first, last)
    self.startX, self.edge, self.endX = first, last, last
end
-- Ignore stale crank movement when entering play, changing food, or resuming.
function Chopping:syncCrank()
    self.lastCrankAngle, self.wasDocked = nil, false
end
function Chopping:update(angle, docked, velocity, dt, crankChange, elapsedSeconds)
    dt = math.max(dt, 0.001)
    local elapsed=math.max(0,elapsedSeconds or dt)
    self.cooldown = math.max(0, self.cooldown - elapsed)
    self.squash = math.max(0, self.squash - elapsed * 0.6)
    local previousHeight = self.height
    angle = angle % 360
    local delta = 0
    if self.lastCrankAngle ~= nil and not self.wasDocked and not docked then
        delta = crankChange
        if delta == nil then delta = (angle - self.lastCrankAngle + 180) % 360 - 180 end
    end
    self.lastCrankAngle, self.wasDocked = angle, docked
    local travel = tuning.KNIFE_TRAVEL_ANGLE
    assert(travel > 0, "Knife travel angle must be positive")
    -- Clamp the accumulated knife position, not the crank position. There is
    -- no stored overshoot to unwind at the top or bottom of the stroke.
    self.height = Chopping.clamp(self.height + delta / travel, 0, 1)
    if docked then self.height = 1; self.armed = false; self.peakSpeed = 0 end
    if self.height > tuning.KNIFE_REPOSITION_HEIGHT then
        self.x = Chopping.clamp(self.x + velocity * dt, self.startX - 6, self.endX + 20)
    end
    if docked or self.finished then return false end
    if self.height >= tuning.KNIFE_READY_HEIGHT then
        if not self.armed or delta > 0 then self.peakSpeed,self.cutSpeed = 0,0 end
        self.armed = true
    end
    if self.armed and self.food.behavior=="soft" then
        -- Judge the part of the descent that actually enters food. A fast
        -- movement above the board, or a slow device frame, must not crush it.
        local seconds=math.max(elapsed,0.001)
        local contact=tuning.TOMATO_CONTACT_HEIGHT
        local contactDrop=math.max(0,math.min(previousHeight,contact)-math.min(self.height,contact))
        local speed=contactDrop/seconds
        self.cutSpeed=self.cutSpeed+(speed-self.cutSpeed)*(1-math.exp(-seconds*tuning.TOMATO_SPEED_FILTER))
        self.peakSpeed=math.max(self.peakSpeed,self.cutSpeed)
        if self.height<contact
            and self.x>=self.startX and self.x<=self.edge and self.peakSpeed>tuning.TOMATO_MAX_SPEED then
            self.squash=0.24
        end
    end
    local crossed=previousHeight>tuning.CHOP_HEIGHT_THRESHOLD and self.height<=tuning.CHOP_HEIGHT_THRESHOLD
    if not self.armed or not crossed then return false end
    self.armed=false
    -- A stroke during a slide is consumed, never queued for a delayed cut.
    if self.cooldown>0 then return false end
    local x=math.floor(self.x+0.5)
    if x<self.startX or x>self.edge-2 then self.progress:miss();return true end
    local remaining,outline
    if self.measureRemainder then remaining,outline=self.measureRemainder(x)
    else remaining=(x-self.startX)/self.initialWidth end
    remaining=Chopping.clamp(remaining,0,1)
    -- Reject empty space even when an irregular silhouette's bounding box
    -- contains it. No points, no invisible edge movement.
    if remaining>=self.remainingFraction-0.00001 then self.progress:miss();return true end
    local width = self.edge - x
    local points = math.max(5, math.floor(120 / math.sqrt(width / 2)))
    local label = width <= tuning.PERFECT_SLICE_WIDTH and "Perfect!" or (width <= tuning.CLEAN_SLICE_WIDTH and "Clean cut!" or "Thick cut")
    local result = {x = x, width = width, points = points, label = label}
    if self.food.behavior == "soft" then
        result.crushed = self.peakSpeed > tuning.TOMATO_MAX_SPEED
        if result.crushed then
            result.points = math.max(1, math.floor(points * tuning.TOMATO_CRUSH_MULTIPLIER))
            result.label, self.squash = "Crushed! Slow down", 0.24
        else result.label = "Smooth cut!" end
    end
    self.edge = x
    self.progress:record(result)
    self:syncTotals()
    self.ingredientCuts = self.ingredientCuts + 1
    self.remainingFraction = remaining
    result.remainingOutline = outline
    if self.remainingFraction <= tuning.FOOD_COMPLETION_FRACTION + 1e-9 then
        self.finished = true
        result.completionBonus=tuning.VEGETABLE_COMPLETE_BONUS
        result.points=result.points+result.completionBonus
        self.progress.score=self.progress.score+result.completionBonus
        self.progress.foodsChopped=self.progress.foodsChopped+1
        self:syncTotals()
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
