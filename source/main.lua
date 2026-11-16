import "CoreLibs/graphics"
import "code/Chopping"
import "code/CuttingGeometry"

local pd, gfx = playdate, playdate.graphics
pd.display.setRefreshRate(50)
pd.startAccelerometer()
local tuning = GameplayTuning
local foodIndex, mode = 1, "menu"
local food = Foods[foodIndex]
local foodImages, previews = {}, {}
for i, item in ipairs(Foods) do
    local source = assert(gfx.image.new(item.path))
    foodImages[i] = source:scaledImage(item.scale)
    local w, h = source:getSize()
    previews[i] = source:scaledImage(math.min(180 / w, 115 / h))
end
local foodImage = foodImages[foodIndex]
local foodW, foodH = foodImage:getSize()
local knife = assert(gfx.image.new("images/Knife")):rotatedImage(
    tuning.KNIFE_IMAGE_ROTATION, tuning.KNIFE_IMAGE_SCALE)
local knifeW, knifeH = knife:getSize()
local bladeX = math.floor(knifeW * tuning.KNIFE_BLADE_ANCHOR_X + 0.5)
local bladeY = math.floor(knifeH * tuning.KNIFE_BLADE_ANCHOR_Y + 0.5)
local foodX, foodY = food.x, food.y
local game = Chopping.new(food)
local pieces, feedback = {}, nil
local remainingFood = foodImage

-- Bake parallel diagonal boundaries only when a cut changes the food.
-- This same mask makes the falling slice and remaining food meet exactly.
local function foodSection(left, right)
    local section = gfx.image.new(foodW, foodH, gfx.kColorClear)
    gfx.pushContext(section)
    for row = 0, foodH - 1 do
        local y = foodY + row
        local first = left and math.ceil(CuttingGeometry.cutX(left, y, food) - foodX) or 0
        local last = right and math.ceil(CuttingGeometry.cutX(right, y, food) - foodX) or foodW
        first, last = math.max(0, first), math.min(foodW, last)
        if last > first then
            gfx.setClipRect(first, row, last - first, 1)
            foodImage:draw(0, 0)
        end
    end
    gfx.clearClipRect()
    gfx.popContext()
    return section
end
local tiltZero, tilt = 0, 0
local soundOn = true
local thud = pd.sound.synth.new(pd.sound.kWaveNoise)
thud:setADSR(0, 0.035, 0, 0.025)
local ping = pd.sound.synth.new(pd.sound.kWaveSine)
ping:setADSR(0, 0.04, 0, 0.08)
local lastTime = pd.getCurrentTimeMilliseconds()
local bump = 0

local function calibrate()
    tiltZero = pd.readAccelerometer() or 0
    tilt = 0
end
local function message(text)
    feedback = {text = text, life = 1.15}
end
local function reset()
    food = Foods[foodIndex]
    foodImage = foodImages[foodIndex]
    foodW, foodH = foodImage:getSize()
    foodX, foodY = food.x, food.y
    game = Chopping.new(food)
    remainingFood = foodImage
    pieces, feedback, bump = {}, nil, 0
    calibrate()
end
local menu = pd.getSystemMenu()
menu:addMenuItem("Restart", reset)
menu:addMenuItem("Center tilt", calibrate)
menu:addCheckmarkMenuItem("Sound", true, function(value) soundOn = value end)
calibrate()

local function cut(result)
    bump = 0.09
    if soundOn then thud:playNote(110, 0.45, 0.04) end
    if not result then
        message("Miss - aim inside the food")
        return
    end
    local width = result.width
    local oldEdge = result.x + width
    local img = foodSection(result.x, oldEdge < food.endX and oldEdge or nil)
    remainingFood = foodSection(nil, result.x)
    pieces[#pieces + 1] = {image = img, x = foodX, y = foodY,
        vx = 28 + math.random() * 35, vy = -35, age = 0}
    message(string.format("%s  +%d  (%dpx)", result.label, result.points, width))
    if soundOn then ping:playNote(450 + result.points * 5, 0.16, 0.05) end
end

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(food.name, 10, 7)
    gfx.drawTextAligned(string.format("%06d", game.score), 390, 7, kTextAlignment.right)
    gfx.drawLine(10, 29, 390, 29)
    gfx.drawRoundRect(34, 106, 332, 109, 8)
    gfx.drawLine(45, 209, 354, 209)
    remainingFood:draw(foodX, foodY)
    for _, p in ipairs(pieces) do p.image:draw(math.floor(p.x), math.floor(p.y)) end
    local x = math.floor(game.x + 0.5)
    if game.height > 0.35 and not game.finished then
        -- Guide is the actual diagonal cut on the board, not a vertical drop.
        for y = food.referenceY - 22, food.referenceY + 24, 4 do
            local guideX = math.floor(CuttingGeometry.cutX(x, y, food) + 0.5)
            gfx.drawLine(guideX, y, guideX, y + 1)
        end
    end
    local knifeX, knifeY = CuttingGeometry.pose(x, game.height, food)
    if bump > 0 then knifeY = knifeY + 2 end
    knife:draw(math.floor(knifeX - bladeX), math.floor(knifeY - bladeY))
    if feedback then
        gfx.drawTextAligned(feedback.text, 200, 49, kTextAlignment.center)
    elseif game.finished then
        gfx.drawTextAligned(food.name .. " done!  A: next", 200, 49, kTextAlignment.center)
    elseif pd.isCrankDocked() then
        gfx.drawTextAligned("Undock crank to chop", 200, 49, kTextAlignment.center)
    else
        gfx.drawTextAligned(game.armed and "Aim a thin slice, then lower" or
            string.format("Raise to %.0f to ready the knife", GameplayTuning.KNIFE_UPPER_ANGLE),
            200, 49, kTextAlignment.center)
    end
    gfx.drawTextAligned(string.format("Cuts %d   Chopped %d", game.cuts, game.foodsChopped), 352, 173, kTextAlignment.right)
    gfx.drawTextAligned(string.format("%d deg", math.floor(pd.getCrankPosition())), 352, 193, kTextAlignment.right)
    gfx.drawTextAligned("Tilt / L R: move   B: foods   A: fresh", 200, 222, kTextAlignment.center)
end

local function drawMenu()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("CHOP CHOP", 200, 12, kTextAlignment.center)
    gfx.drawTextAligned("Choose what to chop", 200, 39, kTextAlignment.center)
    for i, item in ipairs(Foods) do
        local y = 81 + (i - 1) * 37
        if i == foodIndex then
            gfx.fillRoundRect(20, y - 5, 150, 31, 5)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawText(item.name, 35, y)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
    previews[foodIndex]:drawCentered(282, 131)
    gfx.drawLine(20, 205, 380, 205)
    gfx.drawTextAligned("D-pad: choose    A: chop", 200, 218, kTextAlignment.center)
end

function pd.update()
    local now = pd.getCurrentTimeMilliseconds()
    local dt = math.min((now - lastTime) / 1000, 0.05)
    lastTime = now
    if mode == "menu" then
        local step = 0
        if pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then step = 1 end
        if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then step = -1 end
        foodIndex = (foodIndex - 1 + step) % #Foods + 1
        if pd.buttonJustPressed(pd.kButtonA) then reset(); mode = "play" else drawMenu(); return end
        -- A selected the food; don't also treat that press as a fresh-food request.
        draw()
        return
    end
    if pd.buttonJustPressed(pd.kButtonB) then
        mode = "menu"
        game.armed = false
        drawMenu()
        return
    end
    if pd.buttonJustPressed(pd.kButtonA) then game:nextFood(); remainingFood = foodImage; feedback = nil end
    local ax = (pd.readAccelerometer() or tiltZero) - tiltZero
    tilt = tilt + (ax - tilt) * math.min(1, dt * 12)
    local direction = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then direction = direction - 1 end
    if pd.buttonIsPressed(pd.kButtonRight) then direction = direction + 1 end
    local velocity = direction * 100
    if direction == 0 and math.abs(tilt) > 0.045 then
        velocity = Chopping.clamp((math.abs(tilt) - 0.045) * 320, 0, 130) * (tilt < 0 and -1 or 1)
    end
    local struck, result = game:update(pd.getCrankPosition(), pd.isCrankDocked(), velocity, dt)
    if struck then cut(result) end
    bump = math.max(0, bump - dt)
    if feedback then
        feedback.life = feedback.life - dt
        if feedback.life <= 0 then feedback = nil end
    end
    for i = #pieces, 1, -1 do
        local p = pieces[i]
        p.age = p.age + dt
        p.vy = p.vy + 260 * dt
        p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
        if p.age > 1.2 then table.remove(pieces, i) end
    end
    draw()
end
function pd.gameWillResume()
    lastTime = pd.getCurrentTimeMilliseconds()
    game.armed = false
end
