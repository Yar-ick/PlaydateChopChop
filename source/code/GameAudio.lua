import "code/GameplayTuning"
GameAudio = {}
local pd, t = playdate, GameplayTuning
local enabled, paused, scene = true, false, nil
local duckLevel,lastSecond=0,nil
local cue=pd.sound.synth.new(pd.sound.kWaveSine)
cue:setADSR(0,.025,0,.035)
local selectSound = assert(pd.sound.sampleplayer.new("sounds/SelectButton"))
selectSound:setVolume(t.SELECT_SOUND_VOLUME)
local tracks = {
    menu = {player=assert(pd.sound.fileplayer.new("sounds/the-old-master")),gain=0,target=0},
    game = {player=assert(pd.sound.fileplayer.new("sounds/castle-unknown")),gain=0,target=0},
}
for _,track in pairs(tracks) do
    track.player:setBufferSize(t.MUSIC_BUFFER_SECONDS)
    track.player:setStopOnUnderrun(false)
    track.player:setVolume(0)
end
function GameAudio.select()
    if not enabled or paused then return end
    selectSound:stop()
    selectSound:play(1)
end
function GameAudio.scene(nextScene)
    if scene==nextScene then return end
    scene=nextScene
    lastSecond=nil
    for name,track in pairs(tracks) do
        track.target=name==scene and 1 or 0
        if track.target>0 and enabled and not paused and not track.player:isPlaying() then
            track.player:setVolume(0)
            track.player:play(0)
        end
    end
end
function GameAudio.update(dt)
    if paused or not enabled then return end
    duckLevel=duckLevel*math.exp(-dt*3/math.max(.01,t.MUSIC_DUCK_SECONDS))
    local step=dt/math.max(.01,t.MUSIC_FADE_SECONDS)
    for name,track in pairs(tracks) do
        if track.gain<track.target then track.gain=math.min(track.target,track.gain+step)
        elseif track.gain>track.target then track.gain=math.max(track.target,track.gain-step) end
        track.player:setVolume(track.gain*(name=="menu" and t.MENU_MUSIC_VOLUME or t.GAME_MUSIC_VOLUME*(1-duckLevel)))
        if track.gain==0 and track.target==0 and track.player:isPlaying() then track.player:stop() end
    end
end
function GameAudio.setEnabled(value)
    enabled=value
    if not value then cue:stop() end
    selectSound:stop()
    for _,track in pairs(tracks) do
        if not enabled then track.player:stop();track.gain=0
        elseif track.target>0 and not paused then track.player:setVolume(0);track.player:play(0) end
    end
end
function GameAudio.pause()
    paused=true
    cue:stop()
    selectSound:stop()
    for _,track in pairs(tracks) do track.player:pause() end
end
function GameAudio.resume()
    if not paused then return end
    paused=false
    if enabled then
        for _,track in pairs(tracks) do
            if track.target>0 or track.gain>0 then track.player:play(0) end
        end
    end
end
function GameAudio.stop()
    cue:stop()
    selectSound:stop()
    for _,track in pairs(tracks) do track.player:stop();track.gain=0 end
end

function GameAudio.duck(amount)
    if enabled and not paused then
        duckLevel=math.max(duckLevel,amount)
        -- Let the impact through immediately, then release in update().
        tracks.game.player:setVolume(tracks.game.gain*t.GAME_MUSIC_VOLUME*(1-duckLevel))
    end
end
function GameAudio.countdown(second)
    if second~=lastSecond then
        lastSecond=second
        if enabled and not paused and second>0 and second<=5 then cue:playNote(880,.13,.035) end
    end
end
function GameAudio.finish()
    if enabled and not paused then cue:playNote(440,.16,.08) end
end
