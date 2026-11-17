import "CoreLibs/graphics"
import "code/FoodBitmap"
import "code/GameplayTuning"
CutEffects={}
CutEffects.__index=CutEffects
local gfx,t=playdate.graphics,GameplayTuning
function CutEffects.new()
    return setmetatable({pieces={},crumbs={},age=1,power=0,displayedScore=0},CutEffects)
end
function CutEffects:clearBoard()
    self.pieces,self.crumbs,self.age={}, {},1
end
function CutEffects:reset() self:clearBoard();self.displayedScore=0 end
function CutEffects:cut(image,outline,result,x,y,food)
    local sprite,ox,oy=FoodBitmap.crop(image,outline)
    if result.crushed then
        local _,h=sprite:getSize()
        sprite=sprite:scaledImage(1.2,0.6)
        oy=oy+h*0.4
    end
    local w,h=sprite:getSize()
    local direction=math.random(0,1)==0 and -1 or 1
    local poses={sprite,sprite:rotatedImage(11*direction),sprite:rotatedImage(25*direction)}
    self.pieces[#self.pieces+1]={poses=poses,x=x+ox+w/2,y=y+oy+h/2,
        vx=38+math.random()*32,vy=-35-math.random()*15,age=0}
    if #self.pieces>t.MAX_SLICE_EFFECTS then table.remove(self.pieces,1) end
    self.age=0
    self.power=food.behavior=="soft" and .5 or (food.behavior=="standard" and 2 or 1.4)
    self.hitX,self.hitY=result.x,food.referenceY
    local count=result.width<=t.PERFECT_SLICE_WIDTH and 5 or 3
    for i=1,count do
        self.crumbs[#self.crumbs+1]={x=result.x,y=food.referenceY,
            vx=(math.random()-.3)*90,vy=-25-math.random()*50,age=0,wet=food.behavior=="soft"}
        if #self.crumbs>t.MAX_CRUMBS then table.remove(self.crumbs,1) end
    end
end
function CutEffects:update(dt,score)
    self.age=self.age+dt
    if score<self.displayedScore then self.displayedScore=score end
    local difference=score-self.displayedScore
    if difference>0 then self.displayedScore=math.min(score,self.displayedScore+math.max(1,math.ceil(difference*(1-math.exp(-dt*17))))) end
    local drag=#self.pieces>0 and math.exp(-dt*1.2) or 1
    for i=#self.pieces,1,-1 do
        local p=self.pieces[i]
        p.age=p.age+dt;p.vy=p.vy+460*dt;p.vx=p.vx*drag
        p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt
        if p.age>t.SLICE_LIFETIME or p.y>270 then table.remove(self.pieces,i) end
    end
    for i=#self.crumbs,1,-1 do
        local p=self.crumbs[i]
        p.age=p.age+dt;p.vy=p.vy+300*dt
        p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt
        if p.age>.36 or p.y>213 then table.remove(self.crumbs,i) end
    end
end
function CutEffects:boardOffset()
    if self.age>.15 then return 0 end
    return math.floor(self.power*math.exp(-self.age*30)*math.sin(self.age*70)+.5)
end
function CutEffects:recoil()
    return self.age<.12 and 2*math.exp(-self.age*40) or 0
end
function CutEffects:draw()
    for _,p in ipairs(self.pieces) do
        local pose=p.age>.30 and 3 or (p.age>.12 and 2 or 1)
        p.poses[pose]:drawCentered(math.floor(p.x),math.floor(p.y))
    end
    gfx.setColor(gfx.kColorBlack)
    for _,p in ipairs(self.crumbs) do
        if p.wet then gfx.fillCircleAtPoint(p.x,p.y,1.5)
        else gfx.drawLine(p.x,p.y,p.x+1,p.y+1) end
    end
    if self.age<.065 and self.hitX then
        local x,y=self.hitX,self.hitY
        gfx.setLineWidth(3);gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(x+5,y-4,x+10,y-7);gfx.drawLine(x-4,y-5,x-6,y-10)
        gfx.setLineWidth(1);gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x+5,y-4,x+10,y-7);gfx.drawLine(x-4,y-5,x-6,y-10)
    end
end
