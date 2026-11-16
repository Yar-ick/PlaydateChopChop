import "CoreLibs/graphics"
import "code/Chopping"
import "code/CuttingGeometry"
import "code/FoodBitmap"
import "code/TimedChallenge"
import "code/ChopAudio"
import "code/PaperUI"

local pd, gfx = playdate, playdate.graphics
pd.display.setRefreshRate(50)
pd.startAccelerometer()
math.randomseed(pd.getSecondsSinceEpoch())
local tuning = GameplayTuning
local foodIndex, mode = 1, "modes"
local modeChoice, timed, challenge = 1, false, nil
local food = Foods[foodIndex]
local foodImages, previews, foodOutlines, foodAreas = {}, {}, {}, {}
for i, item in ipairs(Foods) do
    local source = assert(gfx.image.new(item.path))
    foodImages[i] = source:scaledImage(item.scale)
    local outline = FoodBitmap.outline(foodImages[i])
    -- Ignore inedible leaves/stems when deciding whether 5% remains.
    foodOutlines[i] = FoodBitmap.clip(outline, item.startX, item.x, item.y, item, false)
    foodAreas[i] = math.max(1, FoodBitmap.area(foodOutlines[i]))
    local w, h = source:getSize()
    previews[i] = source:scaledImage(math.min(165 / w, 85 / h))
end
PaperUI.initialize(Foods, previews)
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
local function measureRemainder(edge)
    local outline = FoodBitmap.clip(foodOutline, edge, foodX, foodY, food, true)
    return FoodBitmap.area(outline) / foodAreas[foodIndex], outline
end
game.measureRemainder = measureRemainder

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
local function loadFood(index, keepTotals)
    local score, cuts, chopped = game.score, game.cuts, game.foodsChopped
    foodIndex = index
    food = Foods[foodIndex]
    foodImage = foodImages[foodIndex]
    foodW, foodH = foodImage:getSize()
    foodX, foodY = food.x, food.y
    game = Chopping.new(food)
    game.measureRemainder = measureRemainder
    if keepTotals then game.score, game.cuts, game.foodsChopped = score, cuts, chopped end
    remainingFood = foodImage
    foodOutline = foodOutlines[foodIndex]
    pieces, feedback, bump, peel = {}, nil, 0, nil
end
local function reset()
    if timed then
        challenge = TimedChallenge.new()
        loadFood(challenge:pickFood(#Foods), false)
    else
        challenge = nil
        loadFood(foodIndex, false)
    end
    calibrate()
    mode = "play"
end
local menu = pd.getSystemMenu()
menu:addMenuItem("Restart", reset)
menu:addMenuItem("Center tilt", calibrate)
menu:addCheckmarkMenuItem("Sound", true, function(value) soundOn = value end)
calibrate()

local function cut(result)
    bump = 0.09
    if soundOn then
        -- Keep carrot and empty board taps exactly as before.
        if not result or food.name == "Carrot" then thud:playNote(110, 0.45, 0.04)
        else ChopAudio.play(food.name, result.crushed) end
    end
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
    foodOutline = result.remainingOutline or FoodBitmap.clip(foodOutline, result.x, foodX, foodY, food, true)
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
    if soundOn and food.name ~= "Tomato" then ping:playNote(450 + result.points * 5, 0.16, 0.05) end
end

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(food.name, 10, 7)
    if timed then gfx.drawTextAligned("Time " .. math.ceil(challenge.remaining) .. "s", 200, 7, kTextAlignment.center) end
    gfx.drawTextAligned(string.format("%06d", game.score), 390, 7, kTextAlignment.right)
    gfx.drawLine(10, 29, 390, 29)
    gfx.drawRoundRect(tuning.BOARD_LEFT, tuning.BOARD_TOP, tuning.BOARD_WIDTH, tuning.BOARD_HEIGHT, 8)
    gfx.drawLine(tuning.BOARD_LEFT + 11, tuning.BOARD_TOP + tuning.BOARD_HEIGHT - 6,
        tuning.BOARD_LEFT + tuning.BOARD_WIDTH - 12, tuning.BOARD_TOP + tuning.BOARD_HEIGHT - 6)
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
        for y = tuning.BOARD_TOP, tuning.BOARD_TOP + tuning.BOARD_HEIGHT, 4 do
            local guideX = math.floor(CuttingGeometry.cutX(x, y, food) + 0.5)
            gfx.drawLine(guideX, y, guideX, math.min(y + 1, tuning.BOARD_TOP + tuning.BOARD_HEIGHT))
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
    -- Keep raised blade tips and flying slices behind the HUD, so the
    -- statistics and cutting hint stay readable above the board.
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 30, 400, 53)
    gfx.setColor(gfx.kColorBlack)
    if feedback then
        gfx.drawTextAligned(feedback.text, 200, 61, kTextAlignment.center)
    elseif game.finished then
        gfx.drawTextAligned(timed and "Done! Next vegetable..." or food.name .. " done! Take another ingredient", 200, 61, kTextAlignment.center)
    elseif pd.isCrankDocked() then
        gfx.drawTextAligned("Undock crank to chop", 200, 61, kTextAlignment.center)
    else
        gfx.drawTextAligned(game.armed and "Aim a thin slice, then lower" or
            "Clockwise: lift / counterclockwise: cut",
            200, 61, kTextAlignment.center)
    end
    gfx.drawText("Cuts " .. game.cuts, 10, 34)
    gfx.drawTextAligned("Chopped " .. game.foodsChopped, 200, 34, kTextAlignment.center)
    gfx.drawTextAligned(string.format("%d deg", math.floor(pd.getCrankPosition())), 390, 34, kTextAlignment.right)
    PaperUI.footer(timed)
end

local function drawMenu() PaperUI.foods(foodIndex) end
local function drawModes() PaperUI.modes(modeChoice) end
local function drawResults() PaperUI.results(game) end

function pd.update()
    local now = pd.getCurrentTimeMilliseconds()
    local elapsed = math.max(0, (now - lastTime) / 1000)
    local dt = math.min(elapsed, 0.05)
    lastTime = now
    if mode == "modes" then
        if pd.buttonJustPressed(pd.kButtonLeft) then modeChoice=1
        elseif pd.buttonJustPressed(pd.kButtonRight) then modeChoice=2
        elseif pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonUp) then
            modeChoice=3-modeChoice
        end
        if pd.buttonJustPressed(pd.kButtonA) then
            timed = modeChoice == 2
            if timed then reset(); draw() else mode = "menu"; drawMenu() end
        else drawModes() end
        return
    end
    if mode == "results" then
        if pd.buttonJustPressed(pd.kButtonA) then reset(); draw()
        elseif pd.buttonJustPressed(pd.kButtonB) then mode = "modes"; drawModes()
        else drawResults() end
        return
    end
    if mode == "menu" then
        if pd.buttonJustPressed(pd.kButtonB) then mode = "modes"; drawModes(); return end
        local step = 0
        if pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then step = 1 end
        if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then step = -1 end
        foodIndex = (foodIndex - 1 + step) % #Foods + 1
        if pd.buttonJustPressed(pd.kButtonA) then reset(); mode = "play" else drawMenu(); return end
        -- A selected the food; don't also treat that press as a fresh-food request.
        draw()
        return
    end
    if timed then
        local event = challenge:update(elapsed)
        if event == "finished" then mode = "results"; game.armed = false; drawResults(); return end
        if event == "spawn" then loadFood(challenge:pickFood(#Foods), true) end
    end
    if pd.buttonJustPressed(pd.kButtonB) then
        mode = timed and "modes" or "menu"
        game.armed = false
        if timed then drawModes() else drawMenu() end
        return
    end
    if not timed and pd.buttonJustPressed(pd.kButtonA) then
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
    local crankChange = pd.getCrankChange() -- use the unaccelerated delta, even across full turns
    local struck, result = game:update(pd.getCrankPosition(), pd.isCrankDocked(), velocity, dt, crankChange)
    if struck then cut(result) end
    if timed and game.finished then challenge:foodCompleted() end
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
    game:syncCrank()
end

pd.deviceDidUnlock = pd.gameWillResume
