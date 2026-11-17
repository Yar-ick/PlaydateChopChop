import "CoreLibs/graphics"
PaperUI = {}
local gfx = playdate.graphics
local font = gfx.getFont()
local bold = gfx.getFont(gfx.font.kVariantBold) or font
local icons = {
    a = assert(gfx.image.new("images/A_Button")),
    b = assert(gfx.image.new("images/B_Button")),
    dpad = assert(gfx.image.new("images/DPadLeftRight")),
}
local modes, ingredients, gameFooters = {}, {}, {}
local background, logo, results
local bestScore,helpPages=0,{}

local function textCentered(text,x,y,strong)
    gfx.setFont(strong and bold or font)
    gfx.drawTextAligned(text,x,y,kTextAlignment.center)
    gfx.setFont(font)
end
local function paper(x,y,w,h,selected)
    local points={x+3,y+1,x+w-5,y,x+w,y+6,x+w-1,y+h-5,
        x+w-7,y+h,x+4,y+h-1,x,y+h-6,x+1,y+7}
    gfx.setColor(gfx.kColorBlack)
    local shadow={}
    local offset=selected and 4 or 2
    for i=1,#points do shadow[i]=points[i]+offset end
    gfx.fillPolygon(table.unpack(shadow))
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(table.unpack(points))
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(selected and 2 or 1)
    for i=1,#points,2 do
        local j=i+2
        if j>#points then j=1 end
        gfx.drawLine(points[i],points[i+1],points[j],points[j+1])
    end
    gfx.setLineWidth(1)
end
local function tape(x,y)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(x,y+2,x+29,y,x+31,y+8,x+2,y+10)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(x,y+2,x+29,y)
    gfx.drawLine(x+2,y+10,x+31,y+8)
    for i=5,25,7 do gfx.drawLine(x+i,y+3,x+i+2,y+6) end
end
local function footer(groups,y)
    local total=0
    local widths={}
    for i,group in ipairs(groups) do
        local width=gfx.getTextSize(group[2])
        widths[i]=24+4+width
        total=total+widths[i]+(i>1 and 15 or 0)
    end
    local x=math.floor((400-total)/2)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    for i,group in ipairs(groups) do
        icons[group[1]]:draw(x,y)
        gfx.drawText(group[2],x+28,y+4)
        x=x+widths[i]+15
    end
end
local function header(subtitle)
    logo:drawCentered(200,26)
    textCentered(subtitle,200,49,false)
    -- Small hand-inked divider, like the margin of a recipe card.
    gfx.drawLine(126,72,268,72)
    gfx.drawLine(139,75,257,75)
end
local function freeIllustration(cx,cy)
    gfx.fillPolygon(cx-32,cy-11,cx+30,cy+2,cx-31,cy+12)
    gfx.setColor(gfx.kColorWhite)
    for i=0,3 do gfx.drawLine(cx-22+i*11,cy-7+i*2,cx-18+i*11,cy+3+i) end
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(cx-33,cy,cx-46,cy-10)
    gfx.drawLine(cx-33,cy,cx-48,cy)
    gfx.drawLine(cx-33,cy,cx-44,cy+11)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(cx+12,cy-28,cx+23,cy-25,cx+13,cy-5,cx+5,cy-9)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(cx+12,cy-28,cx+23,cy-25)
    gfx.drawLine(cx+23,cy-25,cx+13,cy-5)
    gfx.drawLine(cx+13,cy-5,cx+5,cy-9)
    gfx.drawLine(cx+5,cy-9,cx+12,cy-28)
    gfx.setLineWidth(5)
    gfx.drawLine(cx+6,cy-7,cx-1,cy+8)
    gfx.setLineWidth(1)
    gfx.drawLine(cx-46,cy+22,cx+45,cy+22)
end
local function clockIllustration(cx,cy)
    gfx.setLineWidth(2)
    gfx.drawCircleAtPoint(cx,cy,21)
    gfx.drawRoundRect(cx-6,cy-30,12,6,2)
    gfx.drawLine(cx+16,cy-19,cx+21,cy-24)
    gfx.drawLine(cx,cy,cx,cy-13)
    gfx.drawLine(cx,cy,cx+11,cy+6)
    gfx.fillCircleAtPoint(cx,cy,2)
    gfx.setLineWidth(1)
    for _,p in ipairs({{-16,0},{16,0},{0,-16},{0,16}}) do gfx.fillRect(cx+p[1]-1,cy+p[2]-1,2,2) end
    gfx.drawLine(cx-36,cy-10,cx-29,cy-10)
    gfx.drawLine(cx-39,cy,cx-31,cy)
    gfx.drawLine(cx-35,cy+10,cx-29,cy+10)
end
local function render(draw,w,h)
    local image=gfx.image.new(w or 400,h or 240,gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    gfx.setFont(font)
    draw()
    gfx.setLineWidth(1)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.popContext()
    return image
end
function PaperUI.initialize(foods,previews)
    gfx.setFont(bold)
    local w,h=gfx.getTextSize("Chop Chop!")
    gfx.setFont(font)
    local title=render(function() textCentered("Chop Chop!",w/2+1,0,true) end,w+2,h+2)
    logo=title:scaledImage(2)
    background=render(function()
        -- Sparse margin hatching leaves the text and card interiors quiet.
        for y=7,232,11 do
            gfx.drawLine(2,y,8,y-4)
            gfx.drawLine(391,y+3,397,y-1)
        end
        gfx.drawLine(13,6,382,5)
        gfx.drawLine(12,234,385,233)
        for x=22,380,29 do gfx.drawPixel(x,8);gfx.drawPixel(x+5,231) end
    end)
    for selected=1,2 do
        modes[selected]=render(function()
            background:draw(0,0)
            header("by YaroslavtsevNick")
            for i=1,2 do
                local x=18+(i-1)*192
                local y=i==selected and 84 or 87
                local cx=x+86
                paper(x,y,172,111,i==selected)
                tape(x+15,y-4)
                textCentered(i==1 and "Free chopping" or "60 sec rush",cx,y+14,true)
                if i==1 then freeIllustration(cx,y+63) else clockIllustration(cx,y+62) end
                textCentered(i==1 and "At your pace" or "Random veggies",cx,y+89,false)
                if i==selected then gfx.fillTriangle(cx-4,y+116,cx+4,y+116,cx,y+112) end
            end
            footer({{"dpad","choose"},{"a","start"},{"b","tips"}},208)
        end)
    end
    local notes={standard="Firm & steady",slippery="Slips after cuts",rolling="Rolls after cuts",
        soft="Gentle cuts only",layered="Mind the layers"}
    for selected=1,#foods do
        ingredients[selected]=render(function()
            background:draw(0,0)
            header("Pick your ingredient")
            paper(18,83,154,117,false)
            for i,item in ipairs(foods) do
                local y=89+(i-1)*21
                if i==selected then
                    gfx.fillRoundRect(24,y-1,142,21,3)
                    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
                end
                gfx.drawText(item.name,39,y)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            end
            paper(190,83,190,117,true)
            tape(305,79)
            local preview=previews[selected]
            local pw,ph=preview:getSize()
            local art=preview:scaledImage(math.min(138/pw,65/ph))
            art:drawCentered(285,126)
            gfx.drawLine(210,166,359,166)
            textCentered(notes[foods[selected].behavior],285,176,false)
            footer({{"dpad","choose"},{"a","chop"},{"b","back"}},208)
        end)
    end
    results=render(function()
        background:draw(0,0)
        header("Time's up! / 60 sec rush")
        paper(43,83,310,115,true)
        tape(57,79)
        gfx.drawLine(63,119,333,119)
        footer({{"a","retry"},{"b","menu"}},208)
    end)
    local pages={
        {"Crank clockwise to lift. Turn back to cut.","30 degrees makes a full stroke.","Aim with arrows or tilt; lift to move.","Thin = more. Six clean cuts = bonus.","Dock the crank to pause the rush."},
        {"Carrot - firm and steady.","Cucumber - slips after a cut.","Potato - rolls to a new edge.","Tomato - gentle strokes, please.","Onion - loose skins hide the edge."},
    }
    for index,lines in ipairs(pages) do
        helpPages[index]=render(function()
            background:draw(0,0)
            header(index==1 and "Kitchen notes / controls" or "Kitchen notes / ingredients")
            paper(19,83,360,117,true)
            tape(33,79)
            for i,line in ipairs(lines) do gfx.drawText(line,34,91+(i-1)*21) end
            footer({{"dpad","page"},{"b","back"}},208)
        end)
    end
    for _,timed in ipairs({false,true}) do
        gameFooters[timed]=render(function()
            footer(timed and {{"dpad","move / tilt"},{"b","quit"}}
                or {{"dpad","move / tilt"},{"b","foods"},{"a","fresh"}},0)
        end,400,24)
    end
end
function PaperUI.setBestScore(score) bestScore=score end
function PaperUI.modes(choice)
    modes[choice]:draw(0,0)
    if bestScore>0 then
        local y=choice==2 and 84 or 87
        gfx.setColor(gfx.kColorWhite);gfx.fillRect(217,y+86,160,21)
        gfx.setColor(gfx.kColorBlack)
        textCentered("Best: "..bestScore,296,y+89,false)
    end
end
function PaperUI.foods(choice) ingredients[choice]:draw(0,0) end
function PaperUI.help(page) helpPages[page]:draw(0,0) end
function PaperUI.footer(timed) gameFooters[timed]:draw(0,216) end
function PaperUI.feedback(text,perfect)
    gfx.setFont(perfect and bold or font)
    local w=gfx.getTextSize(text)
    w=math.min(382,w+16)
    if perfect then
        gfx.setColor(gfx.kColorBlack);gfx.fillRoundRect((400-w)/2,56,w,25,4)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    end
    gfx.drawTextAligned(text,200,61,kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy);gfx.setFont(font)
end
function PaperUI.results(game,record)
    results:draw(0,0)
    local stats=game.progress
    local precision=stats and stats:precision() or 0
    local streak=stats and stats.bestCombo or 0
    local rank=stats and stats:rank() or "Apprentice"
    if record then
        gfx.setColor(gfx.kColorWhite);gfx.fillRect(10,48,380,21)
        gfx.setColor(gfx.kColorBlack)
        textCentered(record.newRecord and "Time's up! New personal best!" or "Time's up! Best: "..record.best,200,49,false)
    end
    gfx.drawText("Score",64,95)
    gfx.setFont(bold)
    gfx.drawTextAligned(tostring(game.score),331,95,kTextAlignment.right)
    gfx.setFont(font)
    gfx.drawText("Veg "..game.foodsChopped,64,128)
    gfx.drawTextAligned("Cuts "..game.cuts,331,128,kTextAlignment.right)
    gfx.drawText("Clean "..precision.."%",64,151)
    gfx.drawTextAligned("Streak "..streak,331,151,kTextAlignment.right)
    textCentered(rank,200,175,true)
end
