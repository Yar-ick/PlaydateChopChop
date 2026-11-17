import "code/GameplayTuning"
ChopAudio = {}
local players = {}
local names = {"Cucumber", "Potato", "Tomato", "Onion"}
-- All loading happens at startup, never in the cutting frame.
for _, name in ipairs(names) do
    players[name] = assert(playdate.sound.sampleplayer.new("sounds/Chop" .. name))
    players[name]:setVolume(GameplayTuning.CHOP_SAMPLE_VOLUME)
end
function ChopAudio.play(foodName, crushed)
    -- Both normal and crushed tomato cuts use the first preview sample.
    local player = players[foodName]
    if not player then return false end
    player:stop()
    local rate=foodName=="Tomato" and 1 or 1+(math.random()-.5)*GameplayTuning.CHOP_PITCH_VARIATION
    player:play(1,rate)
    return true
end

function ChopAudio.stop() for _,player in pairs(players) do player:stop() end end
