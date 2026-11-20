--[[
    Buff Timers HUD - Monster Hunter Wilds (REFramework)
    Mostra o tempo restante dos buffs logo abaixo dos icones de status do HUD.

    Onde o jogo guarda os icones (fontes: HudController de kmy0, wilds-world-hud):
        app.GUI020003 (HUD de vida) -> PNL_Pat00 / PNL_StateIcons / PNL_STIcon*
        cada icone tem os filhos PNL_timerLong e PNL_timerNum

    v0.3:
      * Cada icone vem de app.StatusIconManager._StatusIconInfoList
        (_StatusIcon = app.IconDef.STATUS, <StatusIconPanel> = o icone).
      * A ligacao STATUS -> timer de cHunterStatus._ItemBuff e aprendida sozinha:
        icone que aparece junto com um timer que comeca (ou some quando zera).
        Fica salva em reframework/data/buff_timers_hud.json (cfg.learned).
      * Mostra "2:35" ou "45s", amarelo abaixo de 30s e vermelho abaixo de 10s.
      * A refeicao ja tem tempo nativo do jogo e nao e redesenhada.
      * "Modo inspetor" mostra o codigo de cada icone e o tempo ligado a ele.
      * "Gerar dump" salva reframework/data/buff_timers_hud_dump.json.
]]

local MOD_NAME = "Buff Timers HUD"
local CONFIG_FILE = "buff_timers_hud.json"
local DUMP_FILE = "buff_timers_hud_dump.json"

local cfg = { enabled = true, inspector = false, offset_x = 0, offset_y = 28, char_width = 7, learned = {} }
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
    -- imgui.calc_text_size usa a fonte do menu do REFramework (maior que a do
    -- draw.text) e empurrava o texto para a esquerda; largura fixa por caractere
    local w = cfg.char_width * #text
    local tx = x - w / 2 + cfg.offset_x
    local ty = y + cfg.offset_y
    draw.text(text, tx + 1, ty + 1, 0xFF000000) -- sombra
    draw.text(text, tx, ty, color)
end

---------------------------------------------------------------------------
-- Ligacao icone -> buff (v0.3)
--
-- app.GUI020003._StatusIconManager._StatusIconInfoList[i] tem:
--   _StatusIcon                       : app.IconDef.STATUS (qual buff/estado)
--   <StatusIconPanel>k__BackingField  : o PNL_STIcon* daquele buff
--   _DispState                        : 0 = escondido
--
-- Os nomes do enum sao codigos sem sentido (STATUS_0014...), entao a ligacao
-- STATUS -> timer de _ItemBuff e APRENDIDA: quando um icone novo aparece junto
-- com um timer que comeca (ou some junto com um timer que zera), e so ha um
-- de cada, os dois sao ligados e salvos em cfg.learned.
---------------------------------------------------------------------------

local function get_hunter_status()
    local info = call(sdk.get_managed_singleton("app.PlayerManager"), "getMasterPlayer")
    local chr = call(info, "get_Character")
    return call(chr, "get_HunterStatus")
end

-- valor numerico do enum -> nome (so para o dump)
local STATUS_NAMES = {}
try(function()
    for _, f in ipairs(sdk.find_type_definition("app.IconDef.STATUS"):get_fields()) do
        if f:is_static() then
            local v = try(function() return f:get_data(nil) end)
            if type(v) == "number" then STATUS_NAMES[v] = f:get_name() end
        end
    end
end)

-- Ligacoes ja confirmadas em jogo (19/11/2026); o resto e aprendido sozinho
local KNOWN = {
    ["19"] = { "meal" },                -- refeicao (Timer do icone = DurationTimer)
    ["65"] = { "_Kairiki_Timer" },      -- Semente de Poder
    ["66"] = { "_KijinPowder_Timer" },  -- Po do Demonio
    ["70"] = { "_CoolerDrink_Timer" },  -- Bebida Fria
}
for sid, list in pairs(KNOWN) do
    if cfg.learned[sid] == nil then cfg.learned[sid] = list end
end

-- Campos de timer de _ItemBuff: { name = "_Kairiki_Timer", obj = false }
local timer_fields = nil

local function build_timer_fields(ib)
    local out = {}
    for _, f in ipairs(ib:get_type_definition():get_fields()) do
        if not f:is_static() then
            local name = f:get_name()
            local v = field(ib, name)
            if type(v) == "number" and name:find("Timer") then
                out[#out + 1] = { name = name, obj = false }
            elseif type(v) == "userdata" and type(field(v, "_Timer")) == "number" then
                out[#out + 1] = { name = name, obj = true }
            end
        end
    end
    out[#out + 1] = { name = "meal", meal = true }
    return out
end

-- Le todos os timers: { ["_Kairiki_Timer"] = 163.7, meal = 2414.8, ... }
local function read_all_timers(ib, status)
    local out = {}
    for _, tf in ipairs(timer_fields) do
        local v
        if tf.meal then
            v = call(field(status, "_MealEffect"), "get_DurationTimer")
        else
            v = field(ib, tf.name)
            if tf.obj then v = field(v, "_Timer") end
        end
        if type(v) == "number" then out[tf.name] = v end
    end
    return out
end

local function fmt_time(s)
    s = math.floor(s + 0.5)
    if s >= 60 then return string.format("%d:%02d", s // 60, s % 60) end
    return s .. "s"
end

local function time_color(s)
    if s <= 10 then return 0xFF4040FF end -- vermelho (ABGR)
    if s <= 30 then return 0xFF40E0FF end -- amarelo
    return 0xFFFFFFFF
end

local function elements(arr)
    local els = try(function() return arr:get_elements() end)
    if els then return els end
    local out = {}
    local n = call(arr, "get_Length") or 0
    for i = 0, n - 1 do out[#out + 1] = try(function() return arr:get_element(i) end) end
    return out
end

---------------------------------------------------------------------------
-- Aprendizado
---------------------------------------------------------------------------

-- Para cada timer que comeca (ou zera), os candidatos sao os icones que
-- apareceram (ou sumiram) ate LEARN_WINDOW segundos antes/depois. A cada novo
-- evento do mesmo timer, os candidatos sao cruzados (intersecao). Quando sobra
-- um so, a ligacao e salva. Assim um icone que pisca na hora (ex.: 26) nao
-- atrapalha.
local LEARN_WINDOW = 3.0

local prev_timers, prev_active = nil, nil
local appear_at, vanish_at = {}, {}   -- sid -> ultimo instante em que apareceu/sumiu
local pending = {}                    -- { name, t, kind = "start"|"end" }
local candidates = {}                 -- timer -> { [sid] = true }
local learn_msg = nil

-- Log de eventos (reframework/data/buff_timers_hud_events.json) para diagnostico
local EVENTS_FILE = "buff_timers_hud_events.json"
local events, events_dirty, events_saved_at = {}, false, 0

local function log_event(kind, what, extra)
    events[#events + 1] = { t = string.format("%.2f", os.clock()), kind = kind, what = tostring(what), extra = extra }
    if #events > 200 then table.remove(events, 1) end
    events_dirty = true
end

local function flush_events(force)
    local now = os.clock()
    if events_dirty and (force or now - events_saved_at > 1.0) then
        json.dump_file(EVENTS_FILE, events)
        events_dirty, events_saved_at = false, now
    end
end

local function owner_of(timer_name)
    for sid, list in pairs(cfg.learned) do
        for _, n in ipairs(list) do
            if n == timer_name then return sid end
        end
    end
    return nil
end

local function link(sid, timer_name)
    local key = tostring(sid)
    local owner = owner_of(timer_name)
    if owner ~= nil and owner ~= key then return end -- timer ja e de outro icone
    local list = cfg.learned[key] or {}
    for _, n in ipairs(list) do
        if n == timer_name then return end
    end
    list[#list + 1] = timer_name
    cfg.learned[key] = list
    json.dump_file(CONFIG_FILE, cfg)
    learn_msg = "Aprendido: icone " .. key .. " = " .. timer_name
    log_event("link", key, timer_name)
end

-- icones que ja tem dono nao entram como candidatos de outro timer
local function owned_sids()
    local out = {}
    for sid in pairs(cfg.learned) do out[tonumber(sid)] = true end
    return out
end

local function resolve(ev)
    if owner_of(ev.name) ~= nil then return end -- ja aprendido
    local log = ev.kind == "start" and appear_at or vanish_at
    local owned = owned_sids()
    local set, all = {}, {}
    for sid, ts in pairs(log) do
        if math.abs(ts - ev.t) <= LEARN_WINDOW then
            all[sid] = true
            if not owned[sid] then set[sid] = true end
        end
    end
    -- versoes "G" (ex.: _Kairiki_G_Timer) podem usar o mesmo icone de outro timer
    if next(set) == nil then set = all end
    local prev = candidates[ev.name]
    if prev ~= nil then
        local inter = {}
        for sid in pairs(set) do
            if prev[sid] then inter[sid] = true end
        end
        if next(inter) ~= nil then set = inter end -- intersecao vazia: recomeca
    end
    local n, only = 0, nil
    local ids = {}
    for sid in pairs(set) do n, only = n + 1, sid; ids[#ids + 1] = tostring(sid) end
    log_event("resolve", ev.name, ev.kind .. " candidatos=[" .. table.concat(ids, ",") .. "]")
    if n == 1 then
        link(only, ev.name)
        candidates[ev.name] = nil
    elseif n > 1 then
        candidates[ev.name] = set
        learn_msg = ev.name .. ": " .. n .. " candidatos, use de novo para confirmar"
    end
end

local function learn(active, timers)
    if prev_timers == nil then
        prev_timers, prev_active = timers, active
        local tn, ids = {}, {}
        for name, v in pairs(timers) do tn[#tn + 1] = name .. "=" .. string.format("%.1f", v) end
        for sid in pairs(active) do ids[#ids + 1] = tostring(sid) end
        log_event("init", "timers", table.concat(tn, " "))
        log_event("init", "icones", table.concat(ids, ","))
        flush_events(true)
        return
    end
    local now = os.clock()
    for name, v in pairs(timers) do
        local p = prev_timers[name]
        if p ~= nil then
            if p <= 0 and v > 0 then
                pending[#pending + 1] = { name = name, t = now, kind = "start" }
                log_event("timer_start", name, string.format("%.1f", v))
            elseif p > 0 and v <= 0 then
                pending[#pending + 1] = { name = name, t = now, kind = "end" }
                log_event("timer_end", name, string.format("%.1f -> %.1f", p, v))
            elseif v > p + 1.0 then
                log_event("timer_refresh", name, string.format("%.1f -> %.1f", p, v))
            end
        end
    end
    for sid in pairs(active) do
        if not prev_active[sid] then appear_at[sid] = now; log_event("icon_appear", sid) end
    end
    for sid in pairs(prev_active) do
        if not active[sid] then vanish_at[sid] = now; log_event("icon_vanish", sid) end
    end
    flush_events(false)
    -- espera a janela passar para ver tambem icones que mudam um pouco depois
    local keep = {}
    for _, ev in ipairs(pending) do
        if now - ev.t > LEARN_WINDOW then resolve(ev) else keep[#keep + 1] = ev end
    end
    pending = keep
    prev_timers, prev_active = timers, active
end

local function seconds_for(sid, timers)
    local list = cfg.learned[tostring(sid)]
    if list == nil then return nil, false end
    local best, is_meal = nil, false
    for _, n in ipairs(list) do
        local v = timers[n]
        if type(v) == "number" and v > 0 and (best == nil or v > best) then
            best, is_meal = v, (n == "meal")
        end
    end
    return best, is_meal
end

---------------------------------------------------------------------------
-- Loop principal
---------------------------------------------------------------------------

local icon_mgr = nil
local frame = 0

local function find_icon_manager()
    return field(call(get_gui_manager(), "getGUI", GUI_ID), "_StatusIconManager")
end

re.on_frame(function()
    if not cfg.enabled then return end

    frame = frame + 1
    if icon_mgr == nil or frame % 60 == 0 then
        icon_mgr = find_icon_manager()
    end
    if icon_mgr == nil then return end

    local status = get_hunter_status()
    local ib = field(status, "_ItemBuff")
    if ib == nil then return end
    if timer_fields == nil then timer_fields = build_timer_fields(ib) end

    local infos = field(icon_mgr, "_StatusIconInfoList")
    if infos == nil then return end

    -- icones ativos agora: sid -> info
    local active, list = {}, {}
    for _, info in ipairs(elements(infos)) do
        local sid = field(info, "_StatusIcon")
        if type(sid) == "number" and sid >= 0 and field(info, "_DispState") ~= 0 then
            active[sid] = true
            list[#list + 1] = { sid = sid, info = info }
        end
    end

    local timers = read_all_timers(ib, status)
    learn(active, timers)

    if not hud_visible() then return end

    for _, e in ipairs(list) do
        local pnl = field(e.info, "<StatusIconPanel>k__BackingField")
        if pnl ~= nil and is_visible(pnl) then
            local x, y = screen_pos(pnl)
            if x then
                local secs, is_meal = seconds_for(e.sid, timers)
                if cfg.inspector then
                    draw_label(tostring(e.sid), x, y, 0xFF00FFFF)
                    if secs then draw_label(fmt_time(secs), x, y + 16, 0xFFFFFFFF) end
                elseif secs and not is_meal then
                    -- a refeicao ja tem tempo nativo do jogo; nao desenhar por cima
                    draw_label(fmt_time(secs), x, y, time_color(secs))
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Diagnostico
---------------------------------------------------------------------------

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

---------------------------------------------------------------------------
-- Reflexao generica: abre um objeto gerenciado (campos, arrays, listas)
---------------------------------------------------------------------------

local function is_managed(v)
    return try(function() return sdk.is_managed_object(v) end) == true
end

-- Converte um valor qualquer em algo que cabe no JSON
local function plain(v)
    local t = type(v)
    if t == "number" or t == "boolean" or t == "string" or v == nil then return v end
    if t == "userdata" then
        local tn = type_name(v)
        if tn == "System.String" then return tostring(call(v, "ToString")) end
        local s = call(v, "ToString")
        if s ~= nil then return tn .. " = " .. tostring(s) end
        return tn
    end
    return tostring(v)
end

local reflect

local function reflect_array(arr, depth, seen)
    local out = {}
    local n = call(arr, "get_Length") or call(arr, "get_size") or 0
    if type(n) ~= "number" then n = 0 end
    for i = 0, math.min(n, 48) - 1 do
        local el = try(function() return arr:get_element(i) end)
        if el == nil then el = call(arr, "Get", i) end
        out[#out + 1] = reflect(el, depth + 1, seen)
    end
    return { type = type_name(arr), length = n, items = out }
end

-- Valores de todos os getters sem parametro (get_*)
local function getter_values(obj, td, depth, seen)
    local out = {}
    for _, m in ipairs(td:get_methods()) do
        local name = m:get_name()
        local nparams = try(function() return m:get_num_params() end) or 1
        if name:sub(1, 4) == "get_" and nparams == 0 and not try(function() return m:is_static() end) then
            local v = try(function() return m:call(obj) end)
            if is_managed(v) and depth < 3 then
                out[name] = reflect(v, depth + 1, seen)
            else
                out[name] = plain(v)
            end
        end
    end
    return out
end

reflect = function(obj, depth, seen)
    if obj == nil or not is_managed(obj) then return plain(obj) end
    local tn = type_name(obj)
    if tn == "System.String" then return plain(obj) end
    local addr = try(function() return obj:get_address() end)
    if addr then
        if seen[addr] then return "<ja visto: " .. tn .. ">" end
        seen[addr] = true
    end
    if tn:sub(-2) == "[]" then return reflect_array(obj, depth, seen) end
    if depth > 4 then return "<" .. tn .. ">" end
    -- nao descer em controles de GUI, telas inteiras ou GameObjects: so o nome
    if tn:sub(1, 8) == "via.gui." then
        return "<" .. tn .. " " .. tostring(call(obj, "get_Name") or "") .. ">"
    end
    if tn:match("^app%.GUI%d") or tn == "via.GameObject" or tn:sub(1, 8) == "ace.GUIB" then
        return "<" .. tn .. ">"
    end

    local d = { type = tn, fields = {} }
    local td = obj:get_type_definition()
    while td ~= nil do
        local tdn = td:get_full_name()
        if tdn == "System.Object" or tdn == "via.clr.ManagedObject" then break end
        for _, f in ipairs(td:get_fields()) do
            if not f:is_static() then
                local v = field(obj, f:get_name())
                d.fields[f:get_name()] = is_managed(v) and reflect(v, depth + 1, seen) or plain(v)
            end
        end
        td = td:get_parent_type()
    end
    -- List`1: os itens ficam em _items/_size
    if tn:find("System.Collections.Generic.List", 1, true) then
        d.size = field(obj, "_size")
    end
    return d
end

local function list_methods(td)
    local out = {}
    while td ~= nil and td:get_full_name() ~= "System.Object" do
        for _, m in ipairs(td:get_methods()) do
            local ret = try(function() return m:get_return_type():get_full_name() end) or "?"
            local params = {}
            for _, p in ipairs(try(function() return m:get_param_types() end) or {}) do
                params[#params + 1] = try(function() return p:get_full_name() end) or "?"
            end
            out[#out + 1] = td:get_full_name() .. "::" .. m:get_name() .. "(" .. table.concat(params, ", ") .. ") : " .. ret
        end
        td = td:get_parent_type()
    end
    return out
end

local function describe(node, depth)
    local d = { name = node_name(node), type = type_name(node), visible = is_visible(node) }
    if d.type == "via.gui.Text" then d.message = tostring(call(node, "get_Message")) end
    if d.visible and (d.type == "via.gui.Material" or d.type == "via.gui.Texture") then
        d.props = try(function() return getter_values(node, node:get_type_definition(), 2, {}) end)
    end
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
    local names = {}
    for k, v in pairs(STATUS_NAMES) do names[tostring(k)] = v end
    d.status_names = names
    d.learned = cfg.learned
    -- v0.1.1: abre o gerenciador que decide qual buff vai em cada icone
    local sim = field(gui, "_StatusIconManager")
    if sim ~= nil then
        d.status_icon_manager = try(function() return reflect(sim, 0, {}) end) or "falhou ao refletir"
        d.status_icon_manager_getters = try(function()
            return getter_values(sim, sim:get_type_definition(), 0, {})
        end)
        d.status_icon_manager_methods = try(function() return list_methods(sim:get_type_definition()) end)
    else
        d.status_icon_manager = "_StatusIconManager nao encontrado"
    end
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
    c2, cfg.inspector = imgui.checkbox("Modo inspetor (mostra o codigo de cada icone)", cfg.inspector)
    c3, cfg.offset_x = imgui.drag_int("Deslocamento X", cfg.offset_x, 1, -300, 300)
    c4, cfg.offset_y = imgui.drag_int("Deslocamento Y", cfg.offset_y, 1, -300, 300)
    local c5
    c5, cfg.char_width = imgui.drag_int("Largura da letra (centraliza o texto)", cfg.char_width, 1, 3, 20)
    if c1 or c2 or c3 or c4 or c5 then json.dump_file(CONFIG_FILE, cfg) end

    if imgui.button("Gerar dump de diagnostico") then
        local ok, res = pcall(make_dump)
        dump_msg = ok and res or ("Erro: " .. tostring(res))
    end
    if dump_msg then imgui.text(dump_msg) end

    imgui.separator()
    imgui.text("Icones aprendidos (codigo = timer):")
    local keys = {}
    for k in pairs(cfg.learned) do keys[#keys + 1] = k end
    table.sort(keys, function(x, y) return (tonumber(x) or 0) < (tonumber(y) or 0) end)
    for _, k in ipairs(keys) do
        imgui.text("  " .. k .. " = " .. table.concat(cfg.learned[k], ", "))
    end
    if learn_msg then imgui.text(learn_msg) end
    if imgui.button("Esquecer o que foi aprendido") then
        cfg.learned = {}
        for sid, list in pairs(KNOWN) do cfg.learned[sid] = list end
        json.dump_file(CONFIG_FILE, cfg)
        learn_msg = nil
    end
    imgui.tree_pop()
end)

re.on_config_save(function()
    json.dump_file(CONFIG_FILE, cfg)
end)
