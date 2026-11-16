import "code/GameplayTuning"
GameAudio = {}
local pd, t = playdate, GameplayTuning
local enabled, paused, scene = true, false, nil
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
    local step=dt/math.max(.01,t.MUSIC_FADE_SECONDS)
    for name,track in pairs(tracks) do
        if track.gain<track.target then track.gain=math.min(track.target,track.gain+step)
        elseif track.gain>track.target then track.gain=math.max(track.target,track.gain-step) end
        track.player:setVolume(track.gain*(name=="menu" and t.MENU_MUSIC_VOLUME or t.GAME_MUSIC_VOLUME))
        if track.gain==0 and track.target==0 and track.player:isPlaying() then track.player:stop() end
    end
end
function GameAudio.setEnabled(value)
    enabled=value
    selectSound:stop()
    for _,track in pairs(tracks) do
        if not enabled then track.player:stop();track.gain=0
        elseif track.target>0 and not paused then track.player:setVolume(0);track.player:play(0) end
    end
end
function GameAudio.pause()
    paused=true
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
    selectSound:stop()
    for _,track in pairs(tracks) do track.player:stop();track.gain=0 end
end
