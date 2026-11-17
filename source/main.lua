import "CoreLibs/graphics"
import "code/Chopping"
import "code/CuttingGeometry"
import "code/FoodBitmap"
import "code/TimedChallenge"
import "code/ChopAudio"
import "code/PaperUI"
import "code/GameAudio"
import "code/IngredientTransition"
import "code/KnifeInput"
import "code/Profile"
import "code/CutEffects"

local pd, gfx = playdate, playdate.graphics
pd.display.setRefreshRate(50)
pd.startAccelerometer()
math.randomseed(pd.getSecondsSinceEpoch())
local tuning = GameplayTuning
local profile=Profile.new()
local input=KnifeInput.new()
local effects=CutEffects.new()
local newRecord=false
local foodIndex, mode = 1, "modes"
local modeChoice, timed, challenge = 1, false, nil
local helpPage=1
local food = Foods[foodIndex]
local foodImages, previews, foodOutlines, foodAreas = {}, {}, {}, {}
for i, item in ipairs(Foods) do
    local source = assert(gfx.image.new(item.path))
    foodImages[i] = FoodBitmap.scaledImage(source,item.scale)
    local outline = FoodBitmap.outline(foodImages[i])
    -- Ignore inedible leaves/stems when deciding whether 5% remains.
    foodOutlines[i] = FoodBitmap.clip(outline, item.startX, item.x, item.y, item, false)
    foodAreas[i] = math.max(1, FoodBitmap.area(foodOutlines[i]))
    -- Derive real bounds after scaling. A smaller asset cannot leave invisible
    -- scored pixels where the old, larger image used to end.
    local first,last=FoodBitmap.bounds(foodOutlines[i],item.x,item.y,item)
    item.startX,item.endX=math.max(item.startX,first),last
    local w, h = source:getSize()
    previews[i] = FoodBitmap.scaledImage(source,math.min(165 / w, 85 / h))
end
PaperUI.initialize(Foods, previews)
if PaperUI.setBestScore then PaperUI.setBestScore(profile.bestScore) end
local foodImage = foodImages[foodIndex]
local foodW, foodH = foodImage:getSize()
local knife = assert(gfx.image.new("images/Knife")):rotatedImage(
    tuning.KNIFE_IMAGE_ROTATION, tuning.KNIFE_IMAGE_SCALE)
local knifeW, knifeH = knife:getSize()
local boardSource = assert(gfx.image.new("images/CuttingBoard"))
local boardW, boardH = boardSource:getSize()
local boardScale = math.min(tuning.BOARD_HEIGHT / boardH, tuning.BOARD_WIDTH / boardW)
local board = boardSource:scaledImage(boardScale)
-- Center the complete artwork, including its handle. Translate the food and
-- blade by the same amount to preserve their alignment with the board face.
local scaledBoardW = board:getSize()
local boardX = math.floor((400-scaledBoardW)/2)
local playfieldDX = boardX-math.floor(tuning.BOARD_LEFT+tuning.BOARD_WIDTH/2-boardW*boardScale*0.585)
local playfieldDY = tuning.PLAYFIELD_OFFSET_Y
-- Cache the full-height guide and white keyline. Either slope direction
-- remains inside the image when adjusting the blade geometry for playtests.
local guideMin=math.min(0,tuning.CUT_SLOPE*tuning.BOARD_HEIGHT)
local guideMax=math.max(0,tuning.CUT_SLOPE*tuning.BOARD_HEIGHT)
local guideBase=2-math.floor(guideMin)
local guide=gfx.image.new(math.ceil(guideMax-guideMin)+5,tuning.BOARD_HEIGHT+2,gfx.kColorClear)
gfx.pushContext(guide)
for y=0,tuning.BOARD_HEIGHT,4 do
    local x=math.floor(guideBase+tuning.CUT_SLOPE*y+.5)
    gfx.setLineWidth(3);gfx.setColor(gfx.kColorWhite);gfx.drawLine(x,y,x,math.min(y+1,tuning.BOARD_HEIGHT))
    gfx.setLineWidth(1);gfx.setColor(gfx.kColorBlack);gfx.drawLine(x,y,x,math.min(y+1,tuning.BOARD_HEIGHT))
end
gfx.popContext()
local boardY = tuning.BOARD_TOP
local bladeX = math.floor(knifeW * tuning.KNIFE_BLADE_ANCHOR_X + 0.5)
local bladeY = math.floor(knifeH * tuning.KNIFE_BLADE_ANCHOR_Y + 0.5)
local foodX, foodY = food.x, food.y
local game = Chopping.new(food)
local feedback = nil
local remainingFood = foodImage
local foodOutline = foodOutlines[foodIndex]
local peel = nil
local rollVisual=nil
local transition = IngredientTransition.new()
local pendingFood, firstEntry, completionScheduled = nil, false, false
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
local tiltZero = 0
local soundOn = profile.sound
GameAudio.setEnabled(soundOn)
local thud = pd.sound.synth.new(pd.sound.kWaveNoise)
thud:setADSR(0, 0.035, 0, 0.025)
local ping = pd.sound.synth.new(pd.sound.kWaveSine)
ping:setADSR(0, 0.04, 0, 0.08)
local lastTime = pd.getCurrentTimeMilliseconds()
local blockedAim=0
local inputVelocity=0

local function calibrate()
    tiltZero = pd.readAccelerometer() or 0
    input:reset()
end
local function message(text)
    feedback = {text = text, life = tuning.CUT_FEEDBACK_SECONDS}
end
local function loadFood(index, keepTotals)
    local previousGame=game
    foodIndex = index
    food = Foods[foodIndex]
    foodImage = foodImages[foodIndex]
    foodW, foodH = foodImage:getSize()
    foodX, foodY = food.x, food.y
    game = Chopping.new(food)
    game.measureRemainder = measureRemainder
    if keepTotals then game:inheritProgress(previousGame) else effects:reset() end
    remainingFood = foodImage
    foodOutline = foodOutlines[foodIndex]
    feedback, blockedAim, peel, rollVisual = nil, 0, nil, nil
    -- Detached slices finish falling across ingredient changes. A new run
    -- clears them through reset(), so the last slice never pops out midair.
    transition:enter()
    pendingFood, completionScheduled = nil, false
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
    firstEntry = true
    newRecord=false
    GameAudio.scene("game")
    mode = "play"
end
local menu = pd.getSystemMenu()
menu:addMenuItem("Restart", function() GameAudio.select(); reset() end)
menu:addMenuItem("Center tilt", calibrate)
menu:addCheckmarkMenuItem("Sound", soundOn, function(value)
    soundOn=value;GameAudio.setEnabled(value);profile:setSound(value)
    if not value then ChopAudio.stop();thud:stop();ping:stop() end
end)
calibrate()

local function cut(result)

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
    local sliceOutline=FoodBitmap.clip(foodOutline,result.x,foodX,foodY,food,false)
    effects:cut(img,sliceOutline,result,foodX,foodY,food)
    GameAudio.duck(food.name=="Tomato" and 0.45 or 0.25)
    foodImage, remainingFood = nextRemaining, nextRemaining
    if result.shift then foodX = foodX + result.shift end
    foodOutline = result.remainingOutline or FoodBitmap.clip(foodOutline, result.x, foodX, foodY, food, true)
    if result.rotation then
        -- Crop first so repeated rolls cannot accumulate transparent padding.
        local ignoredFirst, ignoredLast
        foodImage, foodX, foodY, ignoredFirst, ignoredLast, foodOutline = FoodBitmap.fit(foodImage, foodX, foodY, food, foodOutline)
        foodW, foodH = foodImage:getSize()
        local poses={foodImage}
        for frame=1,tuning.POTATO_ROLL_FRAMES-1 do
            poses[#poses+1]=foodImage:rotatedImage(result.rotation*frame/tuning.POTATO_ROLL_FRAMES)
        end
        rollVisual={poses=poses,x=foodX+foodW/2,y=foodY+foodH/2,age=0}
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
    if result.completionBonus then result.label="Board clear!"
    elseif result.milestone then result.label=result.combo.." cut streak!" end
    local bonus=result.multiplier>1 and string.format("  x%.2f",result.multiplier) or ""
    message(string.format("%s +%d (%dpx)%s",result.label,result.points,width,bonus))
    feedback.quality=result.milestone or (not result.crushed and result.width<=tuning.PERFECT_SLICE_WIDTH)
    if soundOn and food.name ~= "Tomato" then ping:playNote(450 + result.points * 5, 0.16, 0.05) end
end

GameAudio.scene("menu")

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    local boardKick=effects:boardOffset()
    board:draw(boardX, boardY+boardKick+playfieldDY)
    gfx.setDrawOffset(playfieldDX,playfieldDY)
    local foodDX, foodDY, knifeDX, knifeDY = transition:offsets()
    local settle = game.cooldown / tuning.FOOD_SETTLE_TIME
    local drawX = foodX + foodDX - (food.behavior == "slippery" and game.slip * settle or 0)
    if rollVisual and not transition:active() then
        local index=math.min(#rollVisual.poses,math.floor(rollVisual.age/tuning.FOOD_SETTLE_TIME*#rollVisual.poses)+1)
        rollVisual.poses[index]:drawCentered(rollVisual.x,rollVisual.y+boardKick)
    elseif game.squash > 0 then
        local sx, sy = 1 + game.squash * 0.5, 1 - game.squash
        remainingFood:drawScaled(drawX - foodW * (sx - 1) / 2, foodY + foodDY + boardKick + foodH * (1 - sy), sx, sy)
    else remainingFood:draw(math.floor(drawX), math.floor(foodY + foodDY + boardKick)) end
    effects:draw()
    local x = math.floor(game.x + 0.5)
    if not transition:active() and game.height > tuning.KNIFE_GUIDE_MIN_HEIGHT and not game.finished then
        -- Guide is the actual diagonal cut on the board, not a vertical drop.
        gfx.setClipRect(tuning.BOARD_LEFT,tuning.BOARD_TOP+boardKick,tuning.BOARD_WIDTH,tuning.BOARD_HEIGHT)
        guide:draw(math.floor(CuttingGeometry.cutX(x,tuning.BOARD_TOP,food)-guideBase+.5),tuning.BOARD_TOP+boardKick)
        gfx.clearClipRect()
    end
    if peel and not transition:active() then
        local elapsed = tuning.ONION_LAYER_SECONDS - peel.life
        local sway = math.sin(elapsed * 8) * 4
        -- A loose outer skin sits over the true edge and briefly hides the guide.
        gfx.setColor(gfx.kColorWhite)
        gfx.fillEllipseInRect(peel.edge - 10 + sway, food.referenceY - 23, 22, 43)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawEllipseInRect(peel.edge - 10 + sway, food.referenceY - 23, 22, 43)
        gfx.drawEllipseInRect(peel.edge - 6 + sway, food.referenceY - 20, 14, 37)
        peel.image:draw(peel.x + sway + 4, peel.y - elapsed * 3)
        gfx.setDrawOffset(0,0)
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
    -- Keep flying slices behind the HUD. The knife is drawn last so its
    -- full silhouette stays visible when raised into the text area.
    gfx.setDrawOffset(0,0)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 83)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(food.name, 10, 7)
    if timed then
        if challenge.remaining<=10 and not firstEntry then
            gfx.fillRoundRect(155,3,90,23,4);gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawTextAligned(pd.isCrankDocked() and "Paused" or "Time "..math.ceil(challenge.remaining).."s",200,7,kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.fillRect(155,26,math.floor(90*challenge.remaining/tuning.CHALLENGE_SECONDS),2)
    end
    gfx.drawTextAligned(string.format("%06d", effects.displayedScore), 390, 7, kTextAlignment.right)
    gfx.drawLine(10, 29, 390, 29)
    if transition.phase=="enter" then
        gfx.drawTextAligned("Get ready...",200,61,kTextAlignment.center)
    elseif blockedAim>.12 and not game.finished and (not feedback or feedback.life<tuning.CUT_FEEDBACK_SECONDS-tuning.CUT_FEEDBACK_PRIORITY_SECONDS) then
        PaperUI.feedback("Lift the blade to reposition",false)
    elseif feedback then
        PaperUI.feedback(feedback.text,feedback.quality)
    elseif game.finished then
        gfx.drawTextAligned(timed and "Done! Next vegetable..." or food.name .. " done! Take another ingredient", 200, 61, kTextAlignment.center)
    elseif pd.isCrankDocked() then
        gfx.drawTextAligned(timed and "Undock to resume the clock" or "Undock crank to chop", 200, 61, kTextAlignment.center)
    else
        local hint="Clockwise: lift / turn back: cut"
        if peel then hint="Loose layer! Watch the edge."
        elseif game.cooldown>0 then hint=food.behavior=="rolling" and "Rolling... find the new edge" or "Slippery... adjust your aim"
        elseif game.height<=tuning.KNIFE_REPOSITION_HEIGHT and math.abs(inputVelocity or 0)>5 then hint="Lift the blade to move sideways"
        elseif game.armed then
            local nextWidth=math.floor(game.edge-game.x+.5)
            if nextWidth>=2 and game.x>=game.startX then
                hint=string.format("Next: %dpx / %s",nextWidth,nextWidth<=tuning.PERFECT_SLICE_WIDTH and "paper thin" or (nextWidth<=tuning.CLEAN_SLICE_WIDTH and "clean slice" or "thick cut"))
                if game.progress.cuts==0 then
                    hint=string.format(food.behavior=="soft" and "Next: %dpx / turn back slowly to cut" or "Next: %dpx / turn crank back to cut",nextWidth)
                elseif food.behavior=="soft" then hint=hint.." / go slowly" end
            else hint="Aim inside the vegetable" end
        end
        gfx.drawTextAligned(hint,200,61,kTextAlignment.center)
    end
    gfx.drawText("Cuts " .. game.cuts, 10, 34)
    gfx.drawTextAligned("Streak " .. game.progress.combo, 200, 34, kTextAlignment.center)
    gfx.drawTextAligned("Veg "..game.foodsChopped,390,34,kTextAlignment.right)
    gfx.fillRect(10,26,math.floor(85*game.remainingFraction),2)
    PaperUI.footer(timed)
    if tuning.DEBUG_SHOW_FPS then pd.drawFPS(360,84) end
    local knifeX, knifeY = CuttingGeometry.pose(x, game.height, food)
    knifeY=knifeY+boardKick+effects:recoil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setDrawOffset(playfieldDX,playfieldDY)
    knife:draw(math.floor(knifeX - bladeX + knifeDX), math.floor(knifeY - bladeY + knifeDY))
    gfx.setDrawOffset(0,0)
end

local function drawMenu() GameAudio.scene("menu"); PaperUI.foods(foodIndex) end
local function drawModes() GameAudio.scene("menu"); PaperUI.modes(modeChoice) end
local function drawResults() GameAudio.scene("menu"); PaperUI.results(game,{best=profile.bestScore,newRecord=newRecord}) end
local function drawHelp() GameAudio.scene("menu");PaperUI.help(helpPage) end

function pd.update()
    local now = pd.getCurrentTimeMilliseconds()
    local elapsed = math.max(0, (now - lastTime) / 1000)
    local dt = math.min(elapsed, 0.05)
    lastTime = now
    GameAudio.update(elapsed)
    if mode=="help" then
        if pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight)
            or pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonDown) then
            helpPage=3-helpPage;GameAudio.select()
        end
        if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
            GameAudio.select();mode="modes";drawModes()
        else drawHelp() end
        return
    end
    if mode == "modes" then
        if pd.buttonJustPressed(pd.kButtonB) then
            GameAudio.select();mode="help";helpPage=1;drawHelp();return
        end
        local previousChoice=modeChoice
        if pd.buttonJustPressed(pd.kButtonLeft) then modeChoice=1
        elseif pd.buttonJustPressed(pd.kButtonRight) then modeChoice=2
        elseif pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonUp) then
            modeChoice=3-modeChoice
        end
        if modeChoice~=previousChoice then GameAudio.select() end
        if pd.buttonJustPressed(pd.kButtonA) then
            GameAudio.select()
            timed = modeChoice == 2
            if timed then reset(); draw() else mode = "menu"; drawMenu() end
        else drawModes() end
        return
    end
    if mode == "results" then
        if pd.buttonJustPressed(pd.kButtonA) then GameAudio.select(); reset(); draw()
        elseif pd.buttonJustPressed(pd.kButtonB) then GameAudio.select(); mode = "modes"; drawModes()
        else drawResults() end
        return
    end
    if mode == "menu" then
        if pd.buttonJustPressed(pd.kButtonB) then GameAudio.select(); mode = "modes"; drawModes(); return end
        local step = 0
        if pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then step = 1 end
        if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then step = -1 end
        foodIndex = (foodIndex - 1 + step) % #Foods + 1
        if step~=0 then GameAudio.select() end
        if pd.buttonJustPressed(pd.kButtonA) then GameAudio.select(); reset(); mode = "play" else drawMenu(); return end
        -- A selected the food; don't also treat that press as a fresh-food request.
        draw()
        return
    end
    -- Exempt exactly the first arrival animation. A slow frame that spans
    -- its end still spends the part that belongs to the playable minute.
    local clockElapsed=elapsed
    if firstEntry then
        clockElapsed=math.max(0,elapsed-math.max(0,tuning.INGREDIENT_ENTER_SECONDS-transition.time))
    end
    if timed and clockElapsed>0 and not pd.isCrankDocked() then
        local event = challenge:update(clockElapsed)
        if event=="finished" then
            mode="results";game.armed=false
            newRecord=profile:record(game.progress)
            PaperUI.setBestScore(profile.bestScore)
            GameAudio.finish()
            drawResults();return
        end
        GameAudio.countdown(math.ceil(challenge.remaining))
        if event == "spawn" then pendingFood=challenge:pickFood(#Foods) end
    end
    if pd.buttonJustPressed(pd.kButtonB) then
        GameAudio.select()
        mode = timed and "modes" or "menu"
        game.armed = false
        if timed then drawModes() else drawMenu() end
        return
    end
    if not timed and not transition:active() and pd.buttonJustPressed(pd.kButtonA) then
        GameAudio.select()
        pendingFood=foodIndex
        transition:exit()
    end
    local animationEvent=transition:update(elapsed)
    if transition.phase=="gone" and pendingFood then loadFood(pendingFood,true) end
    if animationEvent=="entered" then
        firstEntry=false
        input:reset();inputVelocity=0
        game:syncCrank()
        pd.getCrankChange() -- discard motion during the entry animation
    end
    if peel then
        peel.life = peel.life - elapsed
        if peel.life <= 0 then peel = nil end
    end
    if feedback then
        feedback.life=feedback.life-elapsed
        if feedback.life<=0 then feedback=nil end
    end
    if rollVisual then
        rollVisual.age=rollVisual.age+elapsed
        if rollVisual.age>=tuning.FOOD_SETTLE_TIME then rollVisual=nil end
    end
    local ax=(pd.readAccelerometer() or tiltZero)-tiltZero
    inputVelocity=input:update(pd.buttonIsPressed(pd.kButtonLeft),pd.buttonIsPressed(pd.kButtonRight),ax,dt)
    if game.height<=tuning.KNIFE_REPOSITION_HEIGHT and math.abs(inputVelocity)>5 then blockedAim=blockedAim+dt else blockedAim=0 end
    local crankChange = pd.getCrankChange() -- use the unaccelerated delta, even across full turns
    local struck, result
    if not transition:active() then
        struck,result=game:update(pd.getCrankPosition(),pd.isCrankDocked(),inputVelocity,dt,crankChange,elapsed)
    end
    if struck then cut(result) end
    if timed and game.finished and not completionScheduled then
        challenge:foodCompleted()
        completionScheduled=true
        if transition.phase=="idle" then transition:exit() end
    end

    effects:update(dt,game.score)
    draw()
end
function pd.gameWillResume()
    lastTime = pd.getCurrentTimeMilliseconds()
    game.armed = false
    game.peakSpeed = 0
    game:syncCrank()
    input:reset();inputVelocity=0
    GameAudio.resume()
end

pd.deviceDidUnlock = pd.gameWillResume

function pd.gameWillPause()
    GameAudio.pause();ChopAudio.stop();thud:stop();ping:stop()
end
pd.deviceWillLock = pd.gameWillPause
pd.deviceWillSleep = pd.gameWillPause
function pd.gameWillTerminate() GameAudio.stop() end
