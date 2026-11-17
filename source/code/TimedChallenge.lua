import "code/GameplayTuning"
TimedChallenge = {}
TimedChallenge.__index = TimedChallenge
function TimedChallenge.new(random)
    return setmetatable({remaining = GameplayTuning.CHALLENGE_SECONDS,
        running = true, random = random or math.random}, TimedChallenge)
end
function TimedChallenge:pickFood(count)
    assert(count >= 1, "At least one food is required")
    if not self.bag or self.bagCount~=count or #self.bag==0 then
        self.bag,self.bagCount={},count
        for i=1,count do self.bag[i]=i end
        for i=count,2,-1 do
            local j=self.random(1,i)
            self.bag[i],self.bag[j]=self.bag[j],self.bag[i]
        end
        -- A full bag guarantees variety; its seam cannot repeat the last food.
        if count>1 and self.bag[count]==self.lastFood then
            self.bag[count],self.bag[1]=self.bag[1],self.bag[count]
        end
    end
    local nextFood=table.remove(self.bag)
    self.lastFood=nextFood
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
