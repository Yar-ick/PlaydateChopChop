import "CoreLibs/graphics"
import "code/Chopping"
import "code/CuttingGeometry"
import "code/FoodBitmap"

local pd, gfx = playdate, playdate.graphics
pd.display.setRefreshRate(50)
pd.startAccelerometer()
math.randomseed(pd.getSecondsSinceEpoch())
local tuning = GameplayTuning
local foodIndex, mode = 1, "menu"
local food = Foods[foodIndex]
local foodImages, previews, foodOutlines = {}, {}, {}
for i, item in ipairs(Foods) do
    local source = assert(gfx.image.new(item.path))
    foodImages[i] = source:scaledImage(item.scale)
    if item.behavior == "rolling" then foodOutlines[i] = FoodBitmap.outline(foodImages[i]) end
    local w, h = source:getSize()
    previews[i] = source:scaledImage(math.min(165 / w, 85 / h))
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
local foodOutline = foodOutlines[foodIndex]
local peel = nil

-- Bake parallel diagonal boundaries only when a cut changes the food.
-- This same mask makes the falling slice and remaining food meet exactly.
local function foodSection(left, right)
    return FoodBitmap.section(foodImage, foodX, foodY, food, left, right)
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
    foodOutline = foodOutlines[foodIndex]
    pieces, feedback, bump, peel = {}, nil, 0, nil
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
    local img, nextRemaining = FoodBitmap.split(foodImage, foodX, foodY, food, result.x)
    if result.peel then
        peel = {image = foodSection(result.x - 8, result.x), x = foodX, y = foodY,
            edge = result.x, life = tuning.ONION_LAYER_SECONDS}
    end
    pieces[#pieces + 1] = {image = img, x = foodX, y = foodY,
        vx = 28 + math.random() * 35, vy = -35, age = 0, crushed = result.crushed, w = foodW, h = foodH}
    foodImage, remainingFood = nextRemaining, nextRemaining
    if result.shift then foodX = foodX + result.shift end
    if foodOutline then foodOutline = FoodBitmap.clip(foodOutline, result.x, foodX, foodY, food, true) end
    if result.rotation then
        -- Crop first so repeated rolls cannot accumulate transparent padding.
        local ignoredFirst, ignoredLast
        foodImage, foodX, foodY, ignoredFirst, ignoredLast, foodOutline = FoodBitmap.fit(foodImage, foodX, foodY, food, foodOutline)
        foodW, foodH = foodImage:getSize()
        local rotated = foodImage:rotatedImage(result.rotation)
        local rw, rh = rotated:getSize()
        foodOutline = FoodBitmap.rotateOutline(foodOutline, result.rotation, foodW, foodH, rw, rh)
        local first, last
        foodImage, foodX, foodY, first, last, foodOutline = FoodBitmap.fit(rotated,
            math.floor(foodX + (foodW - rw) / 2), math.floor(foodY + (foodH - rh) / 2), food, foodOutline)
        foodW, foodH = foodImage:getSize()
        remainingFood = foodImage
        game:setBounds(first, last)
    end
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
    local settle = game.cooldown / tuning.FOOD_SETTLE_TIME
    local drawX = foodX - (food.behavior == "slippery" and game.slip * settle or 0)
    if game.squash > 0 then
        local sx, sy = 1 + game.squash * 0.5, 1 - game.squash
        remainingFood:drawScaled(drawX - foodW * (sx - 1) / 2, foodY + foodH * (1 - sy), sx, sy)
    else remainingFood:draw(math.floor(drawX), foodY) end
    for _, p in ipairs(pieces) do
        if p.crushed then
            p.image:drawScaled(p.x - p.w * 0.1, p.y + p.h * 0.4, 1.2, 0.6)
        else p.image:draw(math.floor(p.x), math.floor(p.y)) end
    end
    local x = math.floor(game.x + 0.5)
    if game.height > 0.35 and not game.finished and not peel then
        -- Guide is the actual diagonal cut on the board, not a vertical drop.
        for y = food.referenceY - 22, food.referenceY + 24, 4 do
            local guideX = math.floor(CuttingGeometry.cutX(x, y, food) + 0.5)
            gfx.drawLine(guideX, y, guideX, y + 1)
        end
    end
    local knifeX, knifeY = CuttingGeometry.pose(x, game.height, food)
    if bump > 0 then knifeY = knifeY + 2 end
    knife:draw(math.floor(knifeX - bladeX), math.floor(knifeY - bladeY))
    if peel then
        local elapsed = tuning.ONION_LAYER_SECONDS - peel.life
        local sway = math.sin(elapsed * 8) * 4
        -- A loose outer skin sits over the true edge and briefly hides the guide.
        gfx.setColor(gfx.kColorWhite)
        gfx.fillEllipseInRect(peel.edge - 10 + sway, food.referenceY - 23, 22, 43)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawEllipseInRect(peel.edge - 10 + sway, food.referenceY - 23, 22, 43)
        gfx.drawEllipseInRect(peel.edge - 6 + sway, food.referenceY - 20, 14, 37)
        peel.image:draw(peel.x + sway + 4, peel.y - elapsed * 3)
        for i = 1, 3 do
            local ty = 65 + ((elapsed * 65 + i * 39) % 125)
            local tx = i % 2 == 0 and 372 or 22
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(tx, ty, 4)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(tx, ty, 4)
            gfx.drawLine(tx - 3, ty - 3, tx, ty - 10)
            gfx.drawLine(tx, ty - 10, tx + 3, ty - 3)
        end
    end
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
        local y = 73 + (i - 1) * 25
        if i == foodIndex then
            gfx.fillRoundRect(20, y - 5, 150, 24, 5)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawText(item.name, 35, y)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
    previews[foodIndex]:drawCentered(282, 112)
    gfx.drawTextInRect(Foods[foodIndex].hint, 190, 166, 190, 35)
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
    if pd.buttonJustPressed(pd.kButtonA) then
        game:nextFood()
        foodImage = foodImages[foodIndex]
        foodW, foodH = foodImage:getSize()
        foodX, foodY = food.x, food.y
        remainingFood, feedback, peel, pieces = foodImage, nil, nil, {}
        foodOutline = foodOutlines[foodIndex]
    end
    if peel then
        peel.life = peel.life - dt
        if peel.life <= 0 then peel = nil end
    end
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
    game.peakSpeed = 0
end
