--[[
    Buff Timers HUD - Monster Hunter Wilds (REFramework)
    Mostra o tempo restante dos buffs logo abaixo dos icones de status do HUD.

    Onde o jogo guarda os icones (fontes: HudController de kmy0, wilds-world-hud):
        app.GUI020003 (HUD de vida) -> PNL_Pat00 / PNL_StateIcons / PNL_STIcon*
        cada icone tem os filhos PNL_timerLong e PNL_timerNum

    v0.1 - versao de diagnostico:
      * "Modo inspetor" escreve #1, #2, ... abaixo de cada icone visivel
        (confirma que a posicao na tela esta certa).
      * Se o proprio jogo preencher um texto em PNL_timerNum, ele e mostrado.
      * "Gerar dump" salva reframework/data/buff_timers_hud_dump.json com a arvore
        dos icones, os timers de buff ativos e os campos de app.GUI020003. E com esse
        arquivo que da para ligar cada icone ao buff certo na proxima versao.
]]

local MOD_NAME = "Buff Timers HUD"
local CONFIG_FILE = "buff_timers_hud.json"
local DUMP_FILE = "buff_timers_hud_dump.json"

local cfg = { enabled = true, inspector = true, offset_x = 0, offset_y = 28 }
local saved = json.load_file(CONFIG_FILE)
if type(saved) == "table" then
    for k, v in pairs(saved) do
        if cfg[k] ~= nil then cfg[k] = v end
    end
end

local CONTROL_T = sdk.typeof("via.gui.Control")
local SCREEN_POS = sdk.find_type_definition("app.GUIUtilApp"):get_method("getScreenPosByGrobalPosition(via.vec3)")

local function try(fn)
    local ok, res = pcall(fn)
    if ok then return res end
    return nil
end

-- obj:call protegido: devolve nil se o objeto for nil ou o metodo falhar
local function call(obj, method, ...)
    if obj == nil then return nil end
    local args = table.pack(...)
    return try(function() return obj:call(method, table.unpack(args, 1, args.n)) end)
end

local function field(obj, name)
    if obj == nil then return nil end
    return try(function() return obj:get_field(name) end)
end

local GUI_ID = try(function()
    return sdk.find_type_definition("app.GUIID.ID"):get_field("GUI020003"):get_data(nil)
end) or 51

---------------------------------------------------------------------------
-- Navegacao na arvore de GUI
---------------------------------------------------------------------------

local function children(node)
    local out = {}
    local child = call(node, "get_Child")
    while child ~= nil and #out < 64 do
        out[#out + 1] = child
        child = call(child, "get_Next")
    end
    return out
end

local function node_name(node)
    return tostring(call(node, "get_Name") or "?")
end

local function type_name(obj)
    return try(function() return obj:get_type_definition():get_full_name() end) or "?"
end

local function is_visible(node)
    local v = call(node, "get_ActualVisible")
    if v == nil then v = call(node, "get_Visible") end
    return v == true
end

local function screen_pos(node)
    local gp = call(node, "get_GlobalPosition")
    if gp == nil then return nil end
    local sp = try(function() return SCREEN_POS:call(nil, gp) end)
    if sp == nil then return nil end
    return sp.x, sp.y
end

local function get_gui_manager()
    return sdk.get_managed_singleton("app.GUIManager")
end

local function find_icon_panel()
    local hud = call(get_gui_manager(), "get_HudDisplayManager")
    local disp = call(hud, "findDisplayControl", GUI_ID)
    local root = field(disp, "_TargetControl")
    local pat = call(root, "getObject(System.String, System.Type)", "PNL_Pat00", CONTROL_T)
    return call(pat, "getObject(System.String, System.Type)", "PNL_StateIcons", CONTROL_T)
end

-- O HUD de vida fica invisivel em mapa, menus e telas de carregamento
local function hud_visible()
    local gui = call(get_gui_manager(), "getGUI", GUI_ID)
    return call(gui, "get_IsVisible") ~= false
end

local function find_icons(node, out, depth)
    for _, c in ipairs(children(node)) do
        local name = node_name(c)
        if name:sub(1, 10) == "PNL_STIcon" then
            out[#out + 1] = c
        elseif depth < 3 then
            find_icons(c, out, depth + 1)
        end
    end
    return out
end

-- Primeiro via.gui.Text com mensagem nao vazia dentro da subarvore
local function find_text(node, depth)
    for _, c in ipairs(children(node)) do
        if type_name(c) == "via.gui.Text" then
            local msg = call(c, "get_Message")
            if msg ~= nil and tostring(msg) ~= "" then return tostring(msg) end
        end
        if depth < 4 then
            local m = find_text(c, depth + 1)
            if m then return m end
        end
    end
    return nil
end

local function native_timer_text(icon)
    local num = call(icon, "getObject(System.String, System.Type)", "PNL_timerNum", CONTROL_T)
    if num == nil or not is_visible(num) then return nil end
    return find_text(num, 0)
end

---------------------------------------------------------------------------
-- Desenho
---------------------------------------------------------------------------

local function draw_label(text, x, y, color)
    local w = try(function() return imgui.calc_text_size(text).x end) or (7 * #text)
    local tx = x - w / 2 + cfg.offset_x
    local ty = y + cfg.offset_y
    draw.text(text, tx + 1, ty + 1, 0xFF000000) -- sombra
    draw.text(text, tx, ty, color)
end

local panel, icons = nil, {}
local frame = 0

re.on_frame(function()
    if not cfg.enabled then return end

    -- reacha o painel e a lista de icones a cada 60 frames (sobrevive a trocas de cena)
    frame = frame + 1
    if panel == nil or frame % 60 == 0 then
        panel = find_icon_panel()
        icons = panel and find_icons(panel, {}, 0) or {}
    end
    if panel == nil or not hud_visible() then return end

    for i, icon in ipairs(icons) do
        if is_visible(icon) then
            local x, y = screen_pos(icon)
            if x then
                local text = native_timer_text(icon)
                if cfg.inspector then
                    draw_label("#" .. i .. (text and (" " .. text) or ""), x, y, 0xFF00FFFF)
                elseif text then
                    draw_label(text, x, y, 0xFFFFFFFF)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Diagnostico
---------------------------------------------------------------------------

local function get_hunter_status()
    local info = call(sdk.get_managed_singleton("app.PlayerManager"), "getMasterPlayer")
    local chr = call(info, "get_Character")
    return call(chr, "get_HunterStatus")
end

-- Timers (em segundos) dos buffs de item e da refeicao
local function read_buffs(status)
    local out = {}
    local ib = field(status, "_ItemBuff")
    if ib ~= nil then
        for _, f in ipairs(ib:get_type_definition():get_fields()) do
            if not f:is_static() then
                local name = f:get_name()
                local v = field(ib, name)
                if type(v) == "number" and name:find("Timer") then
                    out["item." .. name] = v
                elseif type(v) == "userdata" then
                    local t = field(v, "_Timer")
                    if type(t) == "number" then out["item." .. name] = t end
                end
            end
        end
    end
    local meal = call(field(status, "_MealEffect"), "get_DurationTimer")
    if type(meal) == "number" then out["meal.DurationTimer"] = meal end
    return out
end

local function describe(node, depth)
    local d = { name = node_name(node), type = type_name(node), visible = is_visible(node) }
    if d.type == "via.gui.Text" then d.message = tostring(call(node, "get_Message")) end
    local x, y = screen_pos(node)
    if x then d.screen = { x, y } end
    if depth < 5 then
        local kids = {}
        for _, c in ipairs(children(node)) do kids[#kids + 1] = describe(c, depth + 1) end
        if #kids > 0 then d.children = kids end
    end
    return d
end

local function list_fields(td)
    local out = {}
    while td ~= nil and td:get_full_name() ~= "System.Object" do
        for _, f in ipairs(td:get_fields()) do
            out[#out + 1] = td:get_full_name() .. "::" .. f:get_name() .. " : " .. f:get_type():get_full_name()
        end
        td = td:get_parent_type()
    end
    return out
end

local function list_getters(td)
    local out = {}
    for _, m in ipairs(td:get_methods()) do
        local name = m:get_name()
        if name:sub(1, 4) == "get_" then out[#out + 1] = name end
    end
    return out
end

local function make_dump()
    local status = get_hunter_status()
    local p = find_icon_panel()
    local gui = call(get_gui_manager(), "getGUI", GUI_ID)
    local d = {
        gui_id = GUI_ID,
        buffs = status and read_buffs(status) or "cHunterStatus nao encontrado",
        icon_panel = p and describe(p, 0) or "PNL_StateIcons nao encontrado",
        gui020003_fields = gui and list_fields(gui:get_type_definition()) or {},
        hunter_status_fields = status and list_fields(status:get_type_definition()) or {},
        texture_getters = list_getters(sdk.find_type_definition("via.gui.Texture")),
    }
    json.dump_file(DUMP_FILE, d)
    return "Dump salvo em reframework/data/" .. DUMP_FILE
end

---------------------------------------------------------------------------
-- Menu do REFramework (tecla Insert -> Script Generated UI)
---------------------------------------------------------------------------

local dump_msg = nil

re.on_draw_ui(function()
    if not imgui.tree_node(MOD_NAME) then return end
    local c1, c2, c3, c4
    c1, cfg.enabled = imgui.checkbox("Ativado", cfg.enabled)
    c2, cfg.inspector = imgui.checkbox("Modo inspetor (numera os icones)", cfg.inspector)
    c3, cfg.offset_x = imgui.drag_int("Deslocamento X", cfg.offset_x, 1, -300, 300)
    c4, cfg.offset_y = imgui.drag_int("Deslocamento Y", cfg.offset_y, 1, -300, 300)
    if c1 or c2 or c3 or c4 then json.dump_file(CONFIG_FILE, cfg) end

    if imgui.button("Gerar dump de diagnostico") then
        local ok, res = pcall(make_dump)
        dump_msg = ok and res or ("Erro: " .. tostring(res))
    end
    if dump_msg then imgui.text(dump_msg) end
    imgui.tree_pop()
end)

re.on_config_save(function()
    json.dump_file(CONFIG_FILE, cfg)
end)
