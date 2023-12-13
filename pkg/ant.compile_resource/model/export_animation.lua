local lfs = require "bee.filesystem"
local GLTF2OZZ = require "tool_exe_path"("gltf2ozz")
local subprocess = require "subprocess"
local utility = require "model.utility"
local serialize = import_package "ant.serialize"

local function serialize_path(path)
    if path:sub(1,1) ~= "/" then
        return serialize.path(path)
    end
    return path
end

return function (status)
    local gltfscene = status.glbdata.info
    local skins = gltfscene.skins
    if skins == nil then
        return
    end
    local input = status.input
    local output = status.output
    local folder = output / "animations"
    lfs.create_directories(folder)
    local cwd = lfs.current_path()
    print("animation compile:")
    local success, msg = subprocess.spawn_process {
        GLTF2OZZ,
        "--file=" .. (cwd / input):string(),
        "--config_file=" .. (cwd / "pkg/ant.compile_resource/model/gltf2ozz.json"):string(),
        cwd = folder:string(),
    }

    if not success then
        print(msg)
    end
    if not lfs.exists(folder / "skeleton.bin") then
        error("NO SKELETON export!")
    end
    local animations = {}
    for path in lfs.pairs(folder) do
        if path:equal_extension ".bin" then
            local filename = path:filename():string()
            if filename ~= "skeleton.bin" then
                local stemname = path:stem():string()
                assert(not stemname:match "[<>:/\\|?%s%[%]%(%)]")
                animations[stemname] = filename
            end
        end
    end
    status.animation = "animations/animation.ozz"
    utility.save_txt_file(status, "animations/animation.ozz", {
        skeleton = "skeleton.bin",
        animations = animations,
    }, function (t)
        if t.animations then
            for name, file in pairs(t.animations) do
                t.animations[name] = serialize_path(file)
            end
        end
        if t.skeleton then
            t.skeleton = serialize_path(t.skeleton)
        end
        return t
    end)
end
