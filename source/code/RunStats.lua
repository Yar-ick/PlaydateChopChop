import "code/GameplayTuning"
RunStats = {}
RunStats.__index = RunStats
function RunStats.new()
    return setmetatable({score=0,cuts=0,foodsChopped=0,misses=0,crushed=0,perfects=0,
        cleanCuts=0,combo=0,bestCombo=0,totalWidth=0,bestWidth=nil},RunStats)
end
function RunStats:miss()
    self.misses=self.misses+1
    self.combo=0
end
function RunStats:record(result)
    local t=GameplayTuning
    self.cuts=self.cuts+1
    self.totalWidth=self.totalWidth+result.width
    self.bestWidth=math.min(self.bestWidth or result.width,result.width)
    local clean=not result.crushed and result.width<=t.CLEAN_SLICE_WIDTH
    if clean then self.cleanCuts=self.cleanCuts+1;self.combo=self.combo+1 else self.combo=0 end
    if not result.crushed and result.width<=t.PERFECT_SLICE_WIDTH then self.perfects=self.perfects+1 end
    if result.crushed then self.crushed=self.crushed+1 end
    self.bestCombo=math.max(self.bestCombo,self.combo)
    local multiplier=clean and math.min(t.MAX_COMBO_MULTIPLIER,1+math.floor(self.combo/t.COMBO_STEP)*0.25) or 1
    result.basePoints=result.points
    result.points=math.floor(result.points*multiplier+0.5)
    result.multiplier,result.combo=multiplier,self.combo
    result.milestone=clean and self.combo>1 and self.combo%t.COMBO_STEP==0
    self.score=self.score+result.points
end
function RunStats:precision()
    return self.cuts>0 and math.floor(self.cleanCuts/self.cuts*100+0.5) or 0
end
function RunStats:averageWidth()
    return self.cuts>0 and self.totalWidth/self.cuts or 0
end
function RunStats:rank()
    local t=GameplayTuning
    if self.score>=t.RANK_MASTER_SCORE then return "Master chef" end
    if self.score>=t.RANK_CHEF_SCORE then return "Head chef" end
    if self.score>=t.RANK_COOK_SCORE then return "Prep cook" end
    return "Apprentice"
end
