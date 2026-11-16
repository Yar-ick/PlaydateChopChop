import "CoreLibs/graphics"
import "code/Chopping"

local pd, gfx = playdate, playdate.graphics
pd.display.setRefreshRate(50)
pd.startAccelerometer()
local carrot = assert(gfx.image.new("images/Carrot"))
local knife = assert(gfx.image.new("images/Knife")):scaledImage(0.75)
local _, knifeH = knife:getSize()
local carrotX, carrotY, boardY = 64, 103, 184
local game = Chopping.new()
local pieces, feedback = {}, nil
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
    game = Chopping.new()
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
        message("Miss - aim inside the carrot")
        return
    end
    local width = result.width
    local img = gfx.image.new(width, 128, gfx.kColorClear)
    gfx.pushContext(img)
    carrot:drawScaled(carrotX - result.x, 0, 2)
    gfx.popContext()
    pieces[#pieces + 1] = {image = img, x = result.x, y = carrotY,
        vx = 28 + math.random() * 35, vy = -35, age = 0}
    message(string.format("%s  +%d  (%dpx)", result.label, result.points, width))
    if soundOn then ping:playNote(450 + result.points * 5, 0.16, 0.05) end
end

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("CHOP CHOP", 10, 7)
    gfx.drawTextAligned(string.format("%06d", game.score), 390, 7, kTextAlignment.right)
    gfx.drawLine(10, 29, 390, 29)
    gfx.drawRoundRect(34, boardY, 332, 31, 8)
    gfx.drawLine(45, boardY + 25, 354, boardY + 25)
    gfx.setClipRect(carrotX, carrotY, game.edge - carrotX, 128)
    carrot:drawScaled(carrotX, carrotY, 2)
    gfx.clearClipRect()
    for _, p in ipairs(pieces) do p.image:draw(math.floor(p.x), math.floor(p.y)) end
    local x = math.floor(game.x)
    local bottom = boardY - game.height * 65
    if bump > 0 then bottom = bottom + 2 end
    if game.height > 0.35 and not game.finished then
        for y = math.max(115, math.floor(bottom)), boardY - 1, 5 do
            gfx.drawPixel(x, y)
        end
        gfx.fillTriangle(x - 3, boardY + 5, x + 3, boardY + 5, x, boardY + 1)
    end
    knife:draw(x - 8, math.floor(bottom - knifeH))
    if feedback then
        gfx.drawTextAligned(feedback.text, 200, 49, kTextAlignment.center)
    elseif game.finished then
        gfx.drawTextAligned("Carrot done!  A: next carrot", 200, 49, kTextAlignment.center)
    elseif pd.isCrankDocked() then
        gfx.drawTextAligned("Undock crank to chop", 200, 49, kTextAlignment.center)
    else
        gfx.drawTextAligned(game.armed and "Aim a thin slice, then lower" or
            string.format("Raise to %.0f to ready the knife", GameplayTuning.KNIFE_UPPER_ANGLE),
            200, 49, kTextAlignment.center)
    end
    gfx.drawText(string.format("Cuts %d   Carrots %d", game.cuts, game.carrots), 42, 193)
    gfx.drawTextAligned(string.format("%d deg", math.floor(pd.getCrankPosition())), 352, 193, kTextAlignment.right)
    gfx.drawTextAligned("Tilt / L R: move   B: center   A: fresh", 200, 222, kTextAlignment.center)
end

function pd.update()
    local now = pd.getCurrentTimeMilliseconds()
    local dt = math.min((now - lastTime) / 1000, 0.05)
    lastTime = now
    if pd.buttonJustPressed(pd.kButtonB) then calibrate(); message("Tilt centered") end
    if pd.buttonJustPressed(pd.kButtonA) then game:nextCarrot(); feedback = nil end
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
