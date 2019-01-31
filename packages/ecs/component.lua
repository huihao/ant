local function foreach_init_2(c, w)
    if c.method and c.method.init then
        assert(not c.default)
        return c.method.init()
    end
    if c.default ~= nil or c.type == 'primtype' then
        return c.default
    end
    assert(w.schema.map[c.type], "unknown type:" .. c.type)
    if c.array then
        if c.array == 0 then
            return {}
        end
        local ret = {}
        for i = 1, c.array do
            ret[i] = w:create_component(c.type)
        end
        return ret
    end
    if c.map then
        return {}
    end
    return w:create_component(c.type)
end

local function foreach_init_1(c, w)
    if not c.type then
        local ret = {}
        for _, v in ipairs(c) do
            assert(v.type)
            ret[v.name] = foreach_init_2(v, w)
        end
        if c.method and c.method.init then
            return c.method.init(ret)
        end
        return ret
    end
    return foreach_init_2(c, w)
end

local function gen_init(c, w)
    return function()
        return foreach_init_1(c, w)
    end
end

local foreach_delete_1
local function foreach_delete_2(component, c, schema)
    if c.method and c.method.delete then
        c.method.delete(component)
        return
    end
    if schema.map[c.type] then
        foreach_delete_1(component, schema.map[c.type], schema)
        return
    end
end

function foreach_delete_1(component, c, schema)
    if c.method and c.method.delete then
        c.method.delete(component)
        return
    end
    if not c.type then
        for _, v in ipairs(c) do
            foreach_delete_1(component, v, schema)
        end
        return
    end
    if c.array then
        local n = c.array == 0 and #component or c.array
        for i = 1, n do
            foreach_delete_2(component[i], c, schema)
        end
        return
    end
    if c.map then
        for _, v in pairs(component) do
            foreach_delete_2(v, c, schema)
        end
        return
    end
    foreach_delete_2(component, c, schema)
end

local function gen_delete(c, schema)
    return function(component)
        return foreach_delete_1(component, c, schema)
    end
end

local nonref = {int=true,real=true,string=true,boolean=true,primtype=true}

local function is_ref(c, schema)
    if not c.type then
        return true
    end
    if schema.map[c.type] then
        return is_ref(schema.map[c.type], schema)
    end
    assert(nonref[c.type], "unknown type:" .. c.type)
    return false
end

return function(c, w)
    return {
        init = gen_init(c, w),
        delete = gen_delete(c, w.schema),
        ref = is_ref(c, w.schema)
    }
end
