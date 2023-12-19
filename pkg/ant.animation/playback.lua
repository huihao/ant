local ecs = ...
local world = ecs.world
local w = world.w

local timer = ecs.require "ant.timer|timer_system"

local m = ecs.system "playback_system"

function m:animation_playback()
    local delta = timer.delta() * 0.001
    if delta == 0 then
        return
    end
    for e in w:select "animation_playback animation:in animation_changed?out" do
        local ani = e.animation
        local playing = false
        for _, status in pairs(ani.status) do
            if status.play then
                local duration = status.handle:duration()
                local speed = status.speed or 1
                local ratio = status.ratio + speed * delta / duration
                if ratio > 1 then
                    if status.loop then
                        ratio = ratio - math.floor(ratio)
                    else
                        status.play = nil
                        status.ratio = 0
                        status.weight = 0
                        e.animation_changed = true
                        goto continue
                    end
                end
                playing = true
                if status.ratio ~= ratio then
                    status.ratio = ratio
                    e.animation_changed = true
                end
                ::continue::
            end
        end
        if not playing then
            w:extend(e, "animation_playback?out")
            e.animation_playback = false
        end
    end
end

local api = {}

function api.set_play(e, name, v)
    w:extend(e, "animation:in animation_playback?out")
    local status = e.animation.status[name]
    if status.play ~= v then
        status.play = v
        if status.play and status.weight == 0 then
            status.weight = 1
        end
        e.animation_playback = true
    end
end

function api.set_loop(e, name, v)
    w:extend(e, "animation:in")
    local status = e.animation.status[name]
    if status.loop ~= v then
        status.loop = v
    end
end

function api.set_speed(e, name, v)
    w:extend(e, "animation:in")
    local status = e.animation.status[name]
    if status.speed ~= v then
        status.speed = v
    end
end

return api
