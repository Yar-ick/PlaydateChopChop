Profile = {}
Profile.__index = Profile
local function integer(value)
    return type(value)=="number" and value==value and value>=0 and value<100000000 and math.floor(value) or 0
end
function Profile.new(store)
    local self=setmetatable({store=store or playdate.datastore,bestScore=0,bestCombo=0,sound=true},Profile)
    local ok,data=pcall(self.store.read,"chop-profile")
    if ok and type(data)=="table" then
        self.bestScore,self.bestCombo=integer(data.bestScore),integer(data.bestCombo)
        if type(data.sound)=="boolean" then self.sound=data.sound end
    end
    return self
end
function Profile:save()
    -- Only menu changes and finished runs write data, never a cutting frame.
    return pcall(self.store.write,{version=1,bestScore=self.bestScore,bestCombo=self.bestCombo,sound=self.sound},"chop-profile")
end
function Profile:setSound(value)
    self.sound=value==true
    self:save()
end
function Profile:record(stats)
    local record=stats.score>self.bestScore
    local changed=record or stats.bestCombo>self.bestCombo
    self.bestScore=math.max(self.bestScore,stats.score)
    self.bestCombo=math.max(self.bestCombo,stats.bestCombo)
    if changed then self:save() end
    return record
end
