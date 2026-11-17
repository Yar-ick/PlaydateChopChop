import "code/GameplayTuning"
KnifeInput = {}
KnifeInput.__index = KnifeInput
function KnifeInput.new() return setmetatable({direction=0,held=0,tilt=0},KnifeInput) end
function KnifeInput:reset() self.direction,self.held,self.tilt=0,0,0 end
function KnifeInput:update(left,right,acceleration,dt)
    local t=GameplayTuning
    self.tilt=self.tilt+(acceleration-self.tilt)*(1-math.exp(-dt*t.TILT_FILTER_SPEED))
    local direction=(right and 1 or 0)-(left and 1 or 0)
    if left or right then
        if direction~=self.direction then self.held=0 end
        self.direction=direction
        self.held=self.held+dt
        local ramp=math.max(0,math.min(1,(self.held-t.AIM_FINE_SECONDS)/t.AIM_ACCEL_SECONDS))
        return direction*(t.AIM_FINE_SPEED+(t.AIM_MAX_SPEED-t.AIM_FINE_SPEED)*ramp)
    end
    self.direction,self.held=0,0
    local amount=math.abs(self.tilt)-t.TILT_DEADZONE
    if amount<=0 then return 0 end
    local normalized=math.min(1,amount/t.TILT_FULL_SCALE)
    return (self.tilt<0 and -1 or 1)*normalized^1.5*t.AIM_MAX_SPEED
end
