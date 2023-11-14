local utility           = require "model.utility"
local serialize         = import_package "ant.serialize"
local lfs               = require "bee.filesystem"
local material_compile  = require "material.compile"
local L                 = import_package "ant.render.core".layout

local invalid_chars<const> = "<>:/\\|?%s%[%]%(%)"
local replace_char<const> = '_'

local function fix_invalid_name(name)
    return name:gsub(invalid_chars, replace_char)
end

local function create_entity(status, t)
    if t.parent then
        t.mount = t.parent
        t.data.scene = t.data.scene or {}
    end
    table.sort(t.policy)
    status.prefab[#status.prefab+1] = {
        policy = t.policy,
        data = t.data,
        mount = t.mount,
    }
    return #status.prefab
end

local function get_transform(math3d, node)
    if node.matrix then
        local s, r, t = math3d.srt(math3d.matrix(node.matrix))
        local rr = math3d.tovalue(r)
        rr[3], rr[4] = -rr[3], -rr[4]
        local ttx, tty, ttz = math3d.index(t, 1, 2, 3)
        return {
            s = {math3d.index(s, 1, 2, 3)},
            r = rr,
            t = {ttx, tty, -ttz},
        }
    end

    local t, r = node.translation, node.rotation
    return {
        s = node.scale,
        r = r and {r[1], r[2], -r[3], -r[4]} or nil,     --r2l
        t = t and {t[1], t[2], -t[3]} or nil,            --r2l
    }
end

local DEFAULT_STATE = "main_view|selectable|cast_shadow"

local function duplicate_table(m)
    local t = {}
    for k, v in pairs(m) do
        if type(v) == "table" then
            t[k] = duplicate_table(v)
        else
            t[k] = v
        end
    end
    return t
end

local check_update_material_info; do
    local function declname_shortnames(declname)
        local n = {}
        for dn in declname:gmatch "%w+" do
            n[#n+1] = dn:sub(1, 1)
        end
        table.sort(n)
        return table.concat(n, "")
    end

    local function build_cfg_name(basename, cfg)
        return ("%s_%s%s"):format(basename, cfg.pack_tangent_frame, declname_shortnames(cfg.binded_declname))
    end

    local function build_name(filename, cfg)
        local basename = lfs.path(filename):stem():string()
        return build_cfg_name(basename, cfg)
    end

    local build_varyings; do
        function build_varyings(cfg, mat)
            local varyings = L.varying_inputs(cfg.binded_declname)

            if cfg.pack_tangent_frame and varyings.a_tangent then
                assert(not varyings.a_normal, "Normal should pack to Tangent attirb")
                local v = {}
                for n in varyings.a_tangent:gmatch "%w+" do
                    v[#v+1] = n
                end
    
                varyings.a_tangent = {
                    type = v[1],
                    bind = v[2],
                    pack_from_quat = true,
                }
            end

            --varying
            local num_varying = 0
            local function gen_varying(a, v, n)
                assert(n > 1)
                for i=0, n-1 do
                    local aa = a .. i
                    if not varyings[aa] then
                        return i
                    end
                    local vv = v .. i
                    varyings[vv] = varyings[aa]
                end
            end

            local vtex_idx = gen_varying("a_texcoord", "v_texcoord", 8)
            num_varying = num_varying + vtex_idx
            num_varying = num_varying + gen_varying("a_color", "v_color", 4)

            if mat.fx.setting.lighting == "on" then
                varyings.v_posWS    = "vec4 TEXCOORD" .. vtex_idx
                varyings.v_tangent  = "vec3 TANGENT"
                varyings.v_normal   = "vec3 NORMAL"
                varyings.v_bitangent= "vec3 BITANGENT"

                num_varying = num_varying + 4
            end

            if num_varying > 16 then
                error(("Too many varying attribute:%d, max number is: 16"):format(num_varying))
            end
            return varyings
        end
    end


    local function build_material(material, cfg)
        local nm = duplicate_table(material)
        nm.fx.varyings = build_varyings(cfg, nm)
        return nm
    end
    function check_update_material_info(status, filename, material, cfg)
        local basename = lfs.path(filename):stem():string()
        local c = status.material_cache[basename]
        if c == nil then
            c = {}
            status.material_cache[basename] = c
        end

        local name = build_name(filename, cfg)

        local cc = c[name]
        if nil == cc then
            -- check next(c) to let the first material file use basename, because most materials with the same basic name have only one
            local fn = ("materials/%s.material"):format(next(c) and name or basename)
            local mi = build_material(material, cfg)
            cc = {
                filename = fn,
                material = mi,
            }

            c[name] = cc
            material_compile(status.tasks, status.post_tasks, status.depfiles, cc.material, status.input, status.output / cc.filename, status.setting)
        end
        return cc
    end
end

local function seri_material(status, filename, cfg)
    local material_names = status.material_names
    local stem = lfs.path(filename):stem():string()

    if filename:sub(1, 1) == "/" then
        material_names[stem] = stem
        return filename
    else
        local material = assert(status.material[filename])
        local info = check_update_material_info(status, filename, material, cfg)
        local newstem = lfs.path(info.filename):stem():string()
        material_names[newstem] = stem
        return info.filename
    end
end

local function has_skin(gltfscene, status, nodeidx)
    local node = gltfscene.nodes[nodeidx+1]
    if node.skin and next(status.animations) and status.skeleton then
        if node.skin then
            return true
        end
    end
end

local function create_mesh_node_entity(math3d, gltfscene, nodeidx, parent, status)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(math3d, node)
    local meshidx = node.mesh
    local mesh = gltfscene.meshes[meshidx+1]

    --TODO: need build mesh.primitives into one vertex buffer, and create entity to reference this share vertex buffer/index buffer
    assert(#mesh.primitives == 1, "We assume 'primitives' field only have one mesh primitive")

    local function mesh_declname(em)
        local declname = em.declname
        if #declname == 2 then
            return ("%s|%s"):format(declname[1], declname[2])
        end

        return declname[1]
    end

    local primidx, prim = 1, mesh.primitives[1]; do
        local em        = status.mesh[meshidx+1][primidx]
        local mode      = prim.mode or 4
        assert(mode == 4, "Only 'TRIANGLES' primitive mode is supported")

        local materialfile = status.material_idx[prim.material+1]
        local meshfile = em.meshbinfile
        if meshfile == nil then
            error(("not found meshfile in export data:%d, %d"):format(meshidx+1, primidx))
        end

        status.material_cfg[meshfile] = {
            pack_tangent_frame      = em.pack_tangent_frame and "P" or "",
            binded_declname         = mesh_declname(em),
        }

        local data = {
            mesh        = meshfile,
---@diagnostic disable-next-line: need-check-nil
            material    = materialfile,
            visible_state= DEFAULT_STATE,
        }

        local policy = {}

        local hasskin   = has_skin(gltfscene, status, nodeidx)
        if hasskin then
            policy[#policy+1] = "ant.render|skinrender"
            data.skinning = true
        else
            policy[#policy+1] = "ant.render|render"
            data.scene    = {s=srt.s,r=srt.r,t=srt.t}
        end

        return create_entity(status, {
            policy  = policy,
            data    = data,
            parent  = (not hasskin) and parent,
        })
    end
end

local function create_node_entity(math3d, gltfscene, nodeidx, parent, status)
    local node = gltfscene.nodes[nodeidx+1]
    local srt = get_transform(math3d, node)
    local policy = {
        "ant.scene|scene_object"
    }
    local data = {
        scene = {s=srt.s,r=srt.r,t=srt.t}
    }
    --add_animation(gltfscene, status, nodeidx, policy, data)
    return create_entity(status, {
        policy = policy,
        data = data,
        parent = parent,
    })
end

local function create_skin_entity(status, parent)
    if not status.skeleton then
        return
    end
    local has_animation = next(status.animations) ~= nil
    local has_meshskin = #status.skin > 0
    if not has_animation and not has_meshskin then
        return
    end
    local policy = {}
    local data = {}
    if has_meshskin then
        policy[#policy+1] = "ant.scene|scene_object"
        policy[#policy+1] = "ant.animation|meshskin"
        data.meshskin = status.skin[1]
        data.skinning = true
        data.scene = {}
    end
    if has_animation then
        policy[#policy+1] = "ant.animation|animation"
        data.animation = {}
        local anilst = {}
        for name, file in pairs(status.animations) do
            local n = fix_invalid_name(name)
            anilst[#anilst+1] = n
            data.animation[n] = file
        end
        table.sort(anilst)
        data.animation_birth = ""
        data.anim_ctrl = {}
    end
    data.skeleton = status.skeleton
    if not has_meshskin then
        parent = nil
    end
    return create_entity(status, {
        policy = policy,
        data = data,
        parent = parent,
    })
end

local function find_mesh_nodes(gltfscene, scenenodes, meshnodes)
    for _, nodeidx in ipairs(scenenodes) do
        local node = gltfscene.nodes[nodeidx+1]
        if node.children then
            find_mesh_nodes(gltfscene, node.children, meshnodes)
        end

        if node.mesh then
            meshnodes[#meshnodes+1] = nodeidx
        end
    end
end

local function serialize_path(path)
    if path:sub(1,1) ~= "/" then
        return serialize.path(path)
    end
    return path
end

local function serialize_prefab(status, data)
    for _, v in ipairs(data) do
        local e = v.data
        if e then
            if e.animation then
                for name, file in pairs(e.animation) do
                    e.animation[name] = serialize_path(file)
                end
            end
            if e.material then
                e.material = seri_material(status, e.material, status.material_cfg[e.mesh])
                e.material = serialize_path(e.material)
            end
            if e.mesh then
                e.mesh = serialize_path(e.mesh)
            end
            if e.skeleton then
                e.skeleton = serialize_path(e.skeleton)
            end
            if e.meshskin then
                e.meshskin = serialize_path(e.meshskin)
            end
        end
    end
    return data
end

return function (status)
    local glbdata = status.glbdata
    local math3d = status.math3d
    local gltfscene = glbdata.info
    local sceneidx = gltfscene.scene or 0
    local scene = gltfscene.scenes[sceneidx+1]

    status.prefab = {}
    status.material_names = {}
    local rootid = create_entity(status, {
        policy = {
            "ant.scene|scene_object",
        },
        data = {
            scene = {},
        },
    })

    local meshnodes = {}
    find_mesh_nodes(gltfscene, scene.nodes, meshnodes)

    create_skin_entity(status, rootid)

    local C = {}
    local scenetree = status.scenetree
    local function check_create_node_entity(nodeidx)
        local p_nodeidx = scenetree[nodeidx]
        local parent
        if p_nodeidx == nil then
            parent = rootid
        else
            parent = C[p_nodeidx]
            if parent == nil then
                parent = check_create_node_entity(p_nodeidx)
            end
        end

        local node = gltfscene.nodes[nodeidx+1]
        local e
        if node.mesh then
            e = create_mesh_node_entity(math3d, gltfscene, nodeidx, parent, status)
        else
            e = create_node_entity(math3d, gltfscene, nodeidx, parent, status)
        end

        C[nodeidx] = e
        return e
    end

    for _, nodeidx in ipairs(meshnodes) do
        check_create_node_entity(nodeidx)
    end
    utility.save_txt_file(status, "mesh.prefab", status.prefab, function (data)
        return serialize_prefab(status, data)
    end)

    utility.save_txt_file(status, "translucent.prefab", status.prefab, function (data)
        for _, v in ipairs(data) do
            local e = v.data
            if e then
                if e.material then
                    e.material = serialize_path "/pkg/ant.resources/materials/translucent.material"
                end
            end
        end
        return data
    end)

    utility.save_txt_file(status, "materials.names", status.material_names, function (data) return data end)
end
