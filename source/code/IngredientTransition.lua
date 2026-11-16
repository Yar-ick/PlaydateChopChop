import "code/GameplayTuning"
IngredientTransition = {}
IngredientTransition.__index = IngredientTransition
function IngredientTransition.new()
    return setmetatable({phase="idle",time=0},IngredientTransition)
end
function IngredientTransition:enter()
    self.phase,self.time="enter",0
end
function IngredientTransition:exit()
    self.phase,self.time="exit",0
end
function IngredientTransition:active() return self.phase~="idle" end
function IngredientTransition:update(dt)
    self.time=self.time+math.max(0,dt)
    if self.phase=="enter" and self.time>=GameplayTuning.INGREDIENT_ENTER_SECONDS then
        self.phase="idle";return "entered"
    elseif self.phase=="exit" and self.time>=GameplayTuning.INGREDIENT_EXIT_SECONDS then
        self.phase="gone";return "exited"
    end
end
local function ease(p)
    p=math.max(0,math.min(1,p))
    return p*p*(3-2*p)
end
function IngredientTransition:offsets()
    local t=GameplayTuning
    if self.phase=="enter" then
        local p=1-ease(self.time/t.INGREDIENT_ENTER_SECONDS)
        local knifeP=1-ease((self.time-t.KNIFE_ENTER_DELAY)/(t.INGREDIENT_ENTER_SECONDS-t.KNIFE_ENTER_DELAY))
        return t.INGREDIENT_SLIDE_PIXELS*p,6*p,18*knifeP,-t.KNIFE_TRANSITION_LIFT*knifeP
    elseif self.phase=="exit" or self.phase=="gone" then
        local p=self.phase=="gone" and 1 or ease(self.time/t.INGREDIENT_EXIT_SECONDS)
        return -t.INGREDIENT_SLIDE_PIXELS*p,12*p,18*p,-t.KNIFE_TRANSITION_LIFT*p
    end
    return 0,0,0,0
end
