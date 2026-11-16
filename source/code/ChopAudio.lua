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
    player:play(1, 1 + (math.random() - 0.5) * GameplayTuning.CHOP_PITCH_VARIATION)
    return true
end
