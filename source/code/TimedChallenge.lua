import "code/GameplayTuning"
TimedChallenge = {}
TimedChallenge.__index = TimedChallenge
function TimedChallenge.new(random)
    return setmetatable({remaining = GameplayTuning.CHALLENGE_SECONDS,
        running = true, random = random or math.random}, TimedChallenge)
end
function TimedChallenge:pickFood(count)
    return self.random(1, count)
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
