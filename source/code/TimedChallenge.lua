import "code/GameplayTuning"
TimedChallenge = {}
TimedChallenge.__index = TimedChallenge
function TimedChallenge.new(random)
    return setmetatable({remaining = GameplayTuning.CHALLENGE_SECONDS,
        running = true, random = random or math.random}, TimedChallenge)
end
function TimedChallenge:pickFood(count)
    assert(count >= 1, "At least one food is required")
    local excluded = self.lastFood
    local nextFood
    if count == 1 then nextFood = 1
    elseif excluded and excluded <= count then
        -- Uniformly choose among the other foods, without retry loops.
        nextFood = self.random(1, count - 1)
        if nextFood >= excluded then nextFood = nextFood + 1 end
    else nextFood = self.random(1, count) end
    self.lastFood = nextFood
    return nextFood
end
function TimedChallenge:foodCompleted()
    if self.running and not self.spawnIn then self.spawnIn = GameplayTuning.CHALLENGE_SPAWN_DELAY end
end
function TimedChallenge:update(elapsed)
    if not self.running then return "finished" end
    elapsed = math.max(0, elapsed)
    self.remaining = math.max(0, self.remaining - elapsed)
    if self.remaining <= 0 then
        self.running, self.spawnIn = false, nil
        return "finished"
    end
    if self.spawnIn then
        self.spawnIn = self.spawnIn - elapsed
        if self.spawnIn <= 0 then self.spawnIn = nil; return "spawn" end
    end
end
