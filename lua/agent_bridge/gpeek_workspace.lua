-- A gPeek-based workspace with an Agent Bridge-owned editable Lua pane.
-- Only this browser instance is changed; the Workshop addon remains intact.
if not CLIENT then return end
AgentBridge = AgentBridge or {}

local old = AgentBridge.GPeekWorkspace
local drafts = old and old.drafts or {}
local M = {drafts = drafts, views = old and old.views or {}}
AgentBridge.GPeekWorkspace = M
local MAX_DRAFTS = 32
local CODE_FONT = "AgentBridgeCode"
surface.CreateFont(CODE_FONT, {
    font = system.IsWindows() and "Consolas" or "DejaVu Sans Mono",
    size = 16, weight = 400, antialias = true, extended = true
})
local CODE_TEXT = Color(218, 225, 233)
local CODE_SELECT = Color(63, 97, 139, 190)
local CODE_CARET = Color(235, 241, 249)
local CLEAR = Color(0, 0, 0, 0)
local SYNTAX = {
    plain = CODE_TEXT,
    keyword = Color(255, 128, 122),
    ["function"] = Color(245, 178, 105),
    string = Color(141, 207, 166),
    comment = Color(125, 151, 176),
    number = Color(152, 188, 247)
}
local MUTED = Color(163, 177, 193)
local BACKGROUND = Color(13, 17, 23)
local PANEL = Color(22, 28, 37)
local GUTTER = Color(17, 22, 30)

local function paintSolid(color)
    return function(_, w, h)
        surface.SetDrawColor(color)
        surface.DrawRect(0, 0, w, h)
    end
end

local function styleButton(button)
    button:SetTextColor(CODE_TEXT)
    button.UpdateColours = function() end
    button.Paint = function(self, w, h)
        local color = not self:IsEnabled() and Color(36, 42, 51) or
            (self:IsHovered() and Color(65, 84, 105) or Color(44, 57, 72))
        surface.SetDrawColor(color)
        surface.DrawRect(1, 2, w - 2, h - 4)
    end
end

local function lineCount(text)
    local _, count = text:gsub("\n", "")
    return count + 1
end

local function setStatus(label, text)
    label:SetText(text)
    label:SetTooltip(text)
end

local function say(message)
    notification.AddLegacy("Agent Bridge: " .. message, NOTIFY_ERROR, 6)
end

local function draftCount()
    local count = 0
    for _ in pairs(M.drafts) do count = count + 1 end
    return count
end

local function status(record)
    local text = record.text ~= record.saved and "Unsaved session draft" or
        (record.destination and "Saved DATA copy" or "Source (unedited)")
    if record.conflict then text = text .. " | Source changed or unavailable; review before import" end
    if record.destination then text = text .. " | DATA/" .. record.destination end
    return text
end

local function updateStatus(view, mode)
    if not view.record then return end
    local text = status(view.record) .. " | " .. (mode or view.mode or "Plain text")
    if view.lastStatus ~= text then
        setStatus(view.status, text)
        view.lastStatus = text
    end
end

local function queueSyntax(view)
    view.syntax, view.syntaxText, view.syntaxJob, view.syntaxJobText = nil, nil, nil, nil
    view.syntaxHasTabs, view.syntaxHasNonAscii = nil, nil
    view.layout, view.layoutText, view.layoutWidth, view.layoutJob, view.layoutDue = nil, nil, nil, nil, nil
    view.layoutRequestWidth, view.layoutRequestText, view.layoutAttempts = nil, nil, nil
    view.syntaxDue = RealTime() + 0.2
    view.mode = "Preparing syntax colors"
    updateStatus(view)
end

local function release(view, preserveText)
    local record = view.record
    if record and not preserveText and IsValid(view.entry) then record.text = view.entry:GetValue() end
    if record then
        if record.text ~= record.saved or record.destination or record.conflict then
            M.drafts[record.path] = record
        elseif M.drafts[record.path] == record then
            M.drafts[record.path] = nil
        end
    end
    if record and M.views[record.path] == view then M.views[record.path] = nil end
    view.record = nil
end

local function createExtension()
    local ext = {Icon = "icon16/script_code.png"}
    local view

    local function message(text, preserveText)
        release(view, preserveText)
        view.syntax, view.syntaxText, view.syntaxDue, view.syntaxJob, view.syntaxJobText, view.lastStatus = nil, nil, nil, nil, nil, nil
        view.syntaxHasTabs, view.syntaxHasNonAscii = nil, nil
        view.layout, view.layoutText, view.layoutWidth, view.layoutJob, view.layoutDue = nil, nil, nil, nil, nil
        view.layoutRequestWidth, view.layoutRequestText, view.layoutAttempts = nil, nil, nil
        view.loading = true
        view.entry:SetEditable(false)
        view.entry:SetText("")
        view.loading = false
        setStatus(view.status, text)
        view.save:SetEnabled(false)
        view.discard:SetEnabled(false)
    end

    ext.Initialize = function()
        local root = vgui.Create("DPanel", ext.Container)
        root:Dock(FILL)
        root.Paint = paintSolid(BACKGROUND)
        local hint = vgui.Create("DLabel", root)
        hint:Dock(TOP)
        hint:DockMargin(8, 4, 8, 4)
        hint:SetTall(30)
        hint:SetWrap(true)
        hint:SetTextColor(MUTED)
        hint:SetText("Editing the resolved LUA search path; another addon may supply this file. " ..
            "Unsaved drafts last only this session. Save copy writes to DATA, not the original.")
        local bar = vgui.Create("DPanel", root)
        bar:Dock(BOTTOM)
        bar:SetTall(34)
        bar.Paint = paintSolid(PANEL)
        local save = vgui.Create("DButton", bar)
        save:Dock(LEFT) save:SetWide(100) save:SetText("Save copy") styleButton(save)
        local discard = vgui.Create("DButton", bar)
        discard:Dock(LEFT) discard:SetWide(110) discard:SetText("Discard draft") styleButton(discard)
        local state = vgui.Create("DLabel", bar)
        state:Dock(FILL) state:DockMargin(8, 0, 6, 0) state:SetTextColor(MUTED)
        local canvas = vgui.Create("DPanel", root)
        canvas:Dock(FILL)
        canvas.Paint = paintSolid(BACKGROUND)
        local gutter = vgui.Create("DPanel", canvas)
        gutter:Dock(LEFT)
        gutter:SetWide(48)
        gutter:SetTooltip("Line numbers identify source lines; wrapped continuations have no number.")
        local input = vgui.Create("DTextEntry", canvas)
        input:Dock(FILL)
        input:SetFont(CODE_FONT)
        -- A visible but offscreen native control calibrates the actual wrap
        -- width for this font/skin; it never reads or writes project files.
        local probe = vgui.Create("DTextEntry", root)
        probe:SetPos(-10000, -10000)
        probe:SetSize(100, 100)
        probe:SetMouseInputEnabled(false)
        probe:SetKeyboardInputEnabled(false)
        probe:SetMultiline(true)
        probe:SetVerticalScrollbarEnabled(true)
        probe:SetFont(CODE_FONT)
        probe:SetText("W")
        view = {entry = input, probe = probe, status = state, save = save, discard = discard, root = root, lines = 0}
        local thisView = view
        input.Paint = function(self, w, h)
            surface.SetDrawColor(BACKGROUND)
            surface.DrawRect(0, 0, w, h)
            local horizontal, first = self:GetScrollStartIndexes()
            surface.SetFont(CODE_FONT)
            local width, height = surface.GetTextSize("M")
            local thin = surface.GetTextSize("i")
            local space = surface.GetTextSize(" ")
            local fontReady = width and width > 0 and width == thin and width == space and height and height > 0
            local validSyntax = thisView.record and thisView.syntax and thisView.syntaxText == thisView.record.text and
                (system.IsWindows() or not thisView.syntaxHasTabs)
            if validSyntax and fontReady and (thisView.layoutRequestWidth ~= w or thisView.layoutRequestText ~= thisView.syntaxText) then
                thisView.layout, thisView.layoutText, thisView.layoutWidth, thisView.layoutJob = nil, nil, nil, nil
                thisView.layoutRequestWidth, thisView.layoutRequestText = w, thisView.syntaxText
                thisView.layoutDue = RealTime() + 0.25
                thisView.layoutAttempts = 0
                thisView.layoutGlyphWidth = width
                probe:SetSize(w, math.max(64, h))
                probe:SetText("W")
                probe:InvalidateLayout(true)
            end
            local nativeLines = self:GetNumLines()
            local visual = thisView.record and thisView.layout and thisView.layoutText == thisView.record.text and
                thisView.layoutWidth == w and #thisView.layout == nativeLines and thisView.layout or nil
            -- Unicode is rendered directly only when a leading newline and
            -- word wrapping cannot make the logical/visual rows diverge.
            local direct = validSyntax and thisView.syntaxHasNonAscii and
                nativeLines == thisView.lines and thisView.record.text:sub(1, 1) ~= "\n"
            local colored = validSyntax and fontReady and horizontal == 0 and (visual or direct)
            if not colored then
                self:DrawTextEntryText(CODE_TEXT, CODE_SELECT, CODE_CARET)
                local mode = thisView.syntaxDue and "Preparing syntax colors" or
                    (thisView.layoutDue and "Preparing wrapped layout" or
                    (thisView.syntax and "Plain text (layout mismatch or unsupported characters)" or thisView.mode or "Plain text"))
                updateStatus(thisView, mode)
                return
            end
            -- Native selection and caret remain authoritative. Colored glyphs
            -- use the same font and native text origin; if wrapping or other
            -- unsupported layout is detected, use normal native rendering.
            self:DrawTextEntryText(CLEAR, CODE_SELECT, CLEAR)
            height = height + 1
            for row = 0, math.ceil(h / height) do
                local visualRow = visual and visual[first + row + 1]
                local tokens = visual and visualRow and visualRow.tokens or (direct and thisView.syntax[first + row + 1])
                if not tokens then break end
                local x = 3
                for _, token in ipairs(tokens) do
                    -- Native GMod TextEntry keeps tabs in the value but
                    -- renders them with zero width on the tested branch.
                    local visible = token.text:gsub("\t", "")
                    surface.SetTextPos(x, 1 + row * height)
                    surface.SetTextColor(SYNTAX[token.kind] or CODE_TEXT)
                    surface.DrawText(visible)
                    if visible:find("[\128-\255]") then
                        x = x + surface.GetTextSize(visible)
                    else
                        x = x + #visible * width
                    end
                end
            end
            self:DrawTextEntryText(CLEAR, CLEAR, CODE_CARET)
            updateStatus(thisView, "Syntax colors")
        end
        root.Think = function()
            if not thisView.record then return end
            if thisView.syntaxDue and RealTime() >= thisView.syntaxDue then
                local highlighter = AgentBridge.LuaHighlighter
                local text = thisView.record.text
                if not istable(highlighter) or not isfunction(highlighter.Tokenize) then
                    thisView.syntax, thisView.syntaxText = nil, nil
                    thisView.mode = "Plain text (highlighter unavailable)"
                    thisView.syntaxDue = nil
                    updateStatus(thisView)
                    return
                end
                if not thisView.syntaxJob then
                    thisView.syntaxJob = isfunction(highlighter.Start) and highlighter.Start(text) or
                        coroutine.create(function() return highlighter.Tokenize(text) end)
                    thisView.syntaxJobText = text
                end
                local started = SysTime()
                for _ = 1, 8 do
                    local ok, rows, reason = coroutine.resume(thisView.syntaxJob)
                    if not ok or coroutine.status(thisView.syntaxJob) == "dead" then
                        thisView.syntax = ok and rows or nil
                        thisView.syntaxText = thisView.syntaxJobText
                        thisView.syntaxHasTabs = thisView.syntaxText:find("\t", 1, true) ~= nil
                        thisView.syntaxHasNonAscii = thisView.syntaxText:find("[\128-\255]") ~= nil
                        if not ok then thisView.mode = "Plain text (highlight error)"
                        elseif rows then thisView.mode = "Syntax colors"
                        elseif reason == "characters" then thisView.mode = "Plain text (unsupported characters)"
                        elseif reason == "line_length" then thisView.mode = "Plain text (line exceeds 2 KiB)"
                        else thisView.mode = "Plain text (file or line limit)" end
                        thisView.syntaxDue, thisView.syntaxJob, thisView.syntaxJobText = nil, nil, nil
                        updateStatus(thisView)
                        return
                    end
                    if SysTime() - started >= 0.002 then return end
                end
                return
            end
            if not thisView.syntax or not thisView.layoutDue or RealTime() < thisView.layoutDue then return end
            local layout = AgentBridge.TextLayout
            if not istable(layout) or not isfunction(layout.Start) or not IsValid(probe) then
                thisView.layoutDue = nil return
            end
            if not thisView.layoutJob then
                local ok, cap = pcall(function()
                    local max = math.ceil(thisView.layoutRequestWidth / thisView.layoutGlyphWidth) + 4
                    probe:SetText(string.rep("W", max)) probe:InvalidateLayout(true)
                    if probe:GetNumLines() < 2 then return nil end
                    local low, high = 0, max
                    while low < high do
                        local mid = math.ceil((low + high) / 2)
                        probe:SetText(string.rep("W", mid)) probe:InvalidateLayout(true)
                        if probe:GetNumLines() == 1 then low = mid else high = mid - 1 end
                    end
                    return low
                end)
                if not ok or not cap or cap < 4 then
                    thisView.layoutAttempts = thisView.layoutAttempts + 1
                    thisView.layoutDue = thisView.layoutAttempts < 3 and RealTime() + 0.25 or nil
                    return
                end
                thisView.layoutJob = layout.Start(thisView.syntax, cap)
            end
            local started = SysTime()
            for _ = 1, 8 do
                local ok, rows = coroutine.resume(thisView.layoutJob)
                if not ok or coroutine.status(thisView.layoutJob) == "dead" then
                    thisView.layout = ok and rows or nil
                    thisView.layoutText = thisView.layoutRequestText
                    thisView.layoutWidth = thisView.layoutRequestWidth
                    thisView.layoutDue, thisView.layoutJob = nil, nil
                    return
                end
                if SysTime() - started >= 0.002 then return end
            end
        end
        gutter.Paint = function(_, w, h)
            surface.SetDrawColor(GUTTER)
            surface.DrawRect(0, 0, w, h)
            if not IsValid(input) or not thisView.record then return end
            if not system.IsWindows() and thisView.syntaxHasTabs then return end
            local _, first = input:GetScrollStartIndexes()
            surface.SetFont(CODE_FONT)
            local _, height = surface.GetTextSize("M")
            if not height or height <= 0 then return end
            -- The native multiline TextEntry adds one pixel between rows.
            height = height + 1
            for row = 0, math.ceil(h / height) do
                local index = first + row + 1
                local visual = thisView.layout and thisView.layoutText == thisView.record.text and
                    thisView.layoutWidth == input:GetWide() and #thisView.layout == input:GetNumLines() and thisView.layout[index]
                local direct = not visual and thisView.syntax and thisView.syntaxText == thisView.record.text and
                    thisView.syntaxHasNonAscii and
                    input:GetNumLines() == thisView.lines and thisView.record.text:sub(1, 1) ~= "\n"
                local number = visual and not visual.continuation and visual.line or (direct and index)
                if number and number <= thisView.lines then
                    draw.SimpleText(tostring(number), CODE_FONT, w - 7, 1 + row * height, MUTED, TEXT_ALIGN_RIGHT)
                end
            end
        end
        root.OnRemove = function() release(thisView) end
        input.OnChange = function(self)
            if thisView.loading or not thisView.record then return end
            local record = thisView.record
            record.text = self:GetValue()
            thisView.lines = lineCount(record.text)
            queueSyntax(thisView)
        end
        save.DoClick = function()
            local record = thisView.record
            if not record then return end
            local editor = AgentBridge.SourceEditor
            local source = editor.ReadSource(record.path)
            if source == nil or util.SHA256(source) ~= record.sourceHash then record.conflict = true end
            local text = input:GetValue()
            local bytes, reason = editor.EncodeDraft(text, record.style)
            if not bytes then say(reason or "Could not encode the draft.") return end
            local destination, err = editor.SaveDraft(record.path, bytes)
            if not destination then say(err or "Could not save the draft.") return end
            record.text, record.saved, record.destination = text, text, destination
            M.drafts[record.path] = record
            updateStatus(thisView)
        end
        discard.DoClick = function()
            local record = thisView.record
            if not record then return end
            Derma_Query("Discard this session draft? Saved DATA copies stay on disk.", "Discard draft",
                "Discard", function()
                    if thisView.record ~= record then return end
                    release(thisView)
                    if M.drafts[record.path] == record then M.drafts[record.path] = nil end
                    ext.Browse("lua/" .. record.path)
                end, "Keep draft", function() end)
        end
        message("Select a Lua file to begin.")
    end

    ext.Browse = function(filePath)
        release(view)
        local path = isstring(filePath) and filePath:match("^lua/(.+)$") or nil
        if not path then message("The selected file does not have a valid LUA path.") return end
        local editor = AgentBridge.SourceEditor
        if not istable(editor) then message("Source editor helpers are unavailable.") return end
        local record = M.drafts[path]
        local raw, reason = editor.ReadSource(path)
        if not raw and not record then message(reason or "Source unavailable.") return end
        if record then
            record.conflict = raw == nil or util.SHA256(raw) ~= record.sourceHash
        else
            local text, style = editor.NormalizeSource(raw)
            if not text then message(style) return end
            if draftCount() >= MAX_DRAFTS then
                message("Session draft limit reached. Save and discard a draft to edit another file.") return
            end
            record = {path = path, sourceHash = util.SHA256(raw), style = style, text = text, saved = text}
        end
        local other = M.views[path]
        if other and other ~= view and IsValid(other.entry) then
            message("This source is already open in another Agent Bridge workspace.") return
        end
        view.record = record
        M.views[path] = view
        M.drafts[path] = record
        view.loading = true
        local configured, err = editor.ConfigureInput(view.entry, record.text)
        if not configured then message(err, true) return end
        view.entry:SetEditable(true)
        view.loading = false
        view.lines = lineCount(record.text)
        queueSyntax(view)
        view.save:SetEnabled(true)
        view.discard:SetEnabled(true)
    end

    ext.RightClick = function(menu)
        menu:AddOption("Copy displayed text", function()
            if view and IsValid(view.entry) then SetClipboardText(view.entry:GetValue()) end
        end):SetIcon("icon16/page_paste.png")
    end
    ext.Invalidate = function() if view then release(view) end end
    return ext
end

-- gPeek's JSON/text/CSV/etc. extensions inherit its Lua viewer. Keep that
-- original extension as their base, while replacing only the Lua extension.
function M.Attach(panel)
    if not IsValid(panel) or not istable(panel.Extensions) then return false end
    local original = panel.Extensions.lua
    if not istable(original) or not isfunction(original.Initialize)
        or not isfunction(original.Browse) or not isfunction(original.Invalidate)
        or not isfunction(original.RightClick) then return false end
    panel.Extensions.agent_bridge_original_text_viewer = original
    panel.Extensions.lua = createExtension()
    return true
end

function M.CreateBrowser(parent)
    local control = vgui.GetControlTable("DAddonBrowser")
    if not istable(control) or not isfunction(control.Setup) then
        return nil, "gPeek is not available. Install and enable gPeek, then restart GMod."
    end
    -- Per-instance control table: never replace DAddonBrowser.Setup globally.
    local instance = {}
    for key, value in pairs(control) do instance[key] = value end
    local setup = control.Setup
    instance.Setup = function(panel, ...)
        local result = setup(panel, ...)
        panel.AgentBridgeEditorAvailable = M.Attach(panel)
        return result
    end
    local browser = vgui.CreateFromTable(instance, parent)
    if not IsValid(browser) then return nil, "Could not create the gPeek workspace." end
    if not browser.AgentBridgeEditorAvailable then
        browser:Remove()
        return nil, "This version of gPeek is not supported by Agent Editor."
    end
    return browser
end

function M.CreateTab()
    local browser, reason = M.CreateBrowser()
    if browser then return browser end
    local panel = vgui.Create("DPanel")
    local label = vgui.Create("DLabel", panel)
    label:Dock(TOP) label:DockMargin(12, 12, 12, 0) label:SetTall(48)
    label:SetWrap(true) label:SetDark(true) label:SetText(reason)
    return panel
end

function M.Register()
    if not spawnmenu or not isfunction(spawnmenu.AddCreationTab) then return end
    local name = "Agent Editor"
    local icon = "icon16/page_edit.png"
    local tooltip = "Browse addons and edit Lua drafts"
    spawnmenu.AddCreationTab(name, function() return M.CreateTab() end, icon, 998, tooltip)
    -- On hot reload the creation menu may already exist. Add only our own tab.
    if not IsValid(g_SpawnMenu) or not isfunction(g_SpawnMenu.GetCreationMenu) then return end
    local menu = g_SpawnMenu:GetCreationMenu()
    if not IsValid(menu) or not isfunction(menu.GetCreationTab) or menu:GetCreationTab(name)
        or not istable(menu.CreationTabs) or not isfunction(menu.AddSheet) then return end
    local host = vgui.Create("Panel")
    local tab = menu:AddSheet(name, host, icon, nil, nil, tooltip)
    menu.CreationTabs[name] = tab
    local child = M.CreateTab()
    child:SetParent(host)
    child:Dock(FILL)
    tab.ContentPanel = child
end

M.Register()
hook.Add("OnGamemodeLoaded", "AgentBridge.GPeekWorkspace", M.Register)
hook.Add("InitPostEntity", "AgentBridge.GPeekWorkspace", M.Register)
