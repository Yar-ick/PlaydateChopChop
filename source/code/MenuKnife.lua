import "code/GameplayTuning"
MenuKnife = {}
MenuKnife.__index = MenuKnife

function MenuKnife.new()
    return setmetatable({x=GameplayTuning.MENU_KNIFE_LEFT_X,velocity=0,phase=0},MenuKnife)
end

function MenuKnife:update(choice,dt)
    local t=GameplayTuning
    dt=math.max(0,math.min(dt or 0,0.05))
    local target=choice==2 and t.MENU_KNIFE_RIGHT_X or t.MENU_KNIFE_LEFT_X
    -- Exact critically damped spring: reversing selection retains position
    -- and momentum, including when the knife is already between the boards.
    local omega=6/math.max(.01,t.MENU_KNIFE_GLIDE_SECONDS)
    local decay=math.exp(-omega*dt)
    local distance=self.x-target
    local step=(self.velocity+omega*distance)*dt
    self.x=target+(distance+step)*decay
    self.velocity=(self.velocity-omega*step)*decay
    -- Never reset the bob phase when changing boards.
    self.phase=(self.phase+dt/math.max(.01,t.MENU_KNIFE_BOB_SECONDS))%1
    local y=t.MENU_KNIFE_Y+math.sin(self.phase*math.pi*2)*t.MENU_KNIFE_BOB_PIXELS
    return self.x,y
end
