-- HoverMarks Forever
-- While the mouse is over your target frame, your chosen hotkeys set a raid
-- target marker on your target instead of doing what they are normally
-- bound to. Everything runs through secure handlers, so it works in combat.
-- Type /hmf to choose the hotkey for each marker.

local ADDON = ...
local VERSION = "1.2.2" -- keep in step with ## Version in the .toc
local NUM_MARKERS = 8
-- Order the markers are listed in the settings window:
-- skull, cross, square, diamond, star, triangle, moon, circle.
local ORDER = { 8, 7, 6, 3, 1, 4, 5, 2 }
-- Hotkey per marker (indexed by marker number, not by row); false means
-- the marker has no hotkey. Keys 1-8 follow the order above.
local DEFAULTS = { "5", "8", "4", "6", "7", "3", "2", "1" }
-- Defaults shipped by earlier versions, replaced on load if never changed.
local OLD_DEFAULTS = {
    { "1", "2", "3", "4", "5", "6", false, false },
    { "5", false, "4", "6", false, "3", "2", "1" },
}
local PREFIX = "HoverMarksForeverButton"
local MODIFIER_KEYS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
    LALT = true, RALT = true, LMETA = true, RMETA = true,
}
-- Target frames the addon attaches to, by global name: Blizzard's own and
-- the ones unit-frame addons create in its place. Every frame in this list
-- that exists gets a hover layer; names that do not exist are skipped. A
-- frame not listed here can be added in game with /hmf frame.
local TARGET_FRAMES = {
    "TargetFrame",            -- Blizzard
    "PitBull4_Frames_Target", -- PitBull 4
    "SUFUnittarget",          -- Shadowed Unit Frames
    "ElvUF_Target",           -- ElvUI
    "LUFUnittarget",          -- Luna Unit Frames
    "XPerl_Target",           -- Z-Perl / X-Perl
    "Perl_Target_Frame",      -- Perl Classic
    "UUF_Target",             -- Unhalted Unit Frames
    "GwTargetUnitFrame",      -- GW2 UI
    "oUF_TukuiTarget",        -- Tukui
    "TukuiTargetFrame",       -- Tukui (older)
    "oUF_Target",             -- generic oUF layouts
}

-- The "clear all" hotkey works anywhere, so it takes its key over
-- everywhere. It therefore starts unbound: the player picks a spare key.
local DEFAULT_CLEAR_KEY = false
-- One secure macro that removes every marker from every unit. Each marker
-- can only be on one unit at a time, so putting all eight on the player in
-- turn pulls them off everything else; the last line then clears the player.
local CLEAR_ALL_MACRO = "/tm [@player] 1\n/tm [@player] 2\n/tm [@player] 3\n/tm [@player] 4\n"
    .. "/tm [@player] 5\n/tm [@player] 6\n/tm [@player] 7\n/tm [@player] 8\n/tm [@player] 0"
local db = { binds = { unpack(DEFAULTS, 1, NUM_MARKERS) }, clearKey = DEFAULT_CLEAR_KEY, enabled = true, toggle = true }
local buttons = {}
local overlays = {}     -- host frame -> its hover layer
local overlayList = {}  -- the same hover layers, in the order they were made
local enterSnippet = "" -- secure code every hover layer runs on mouse enter
local buttonsBuilt, panel, pending, listening
local header -- secure frame holding the toggle's state, made with the buttons
-- Secure code that forgets the last mark; run when the mouse enters or
-- leaves a target frame, or the frame is hidden.
local RESET_TOGGLE = 'self:GetFrameRef("hmfheader"):SetAttribute("lastmark", 0)\n'
local quietUntil = 0 -- clear-all chat lines are hidden until this time (GetTime)

-- The "press again" toggle only knows which mark the last press applied.
-- This tries to read the target's real mark and use that instead, but on
-- WoW Forever the game reports the mark as a hidden ("secret") value, which
-- an addon cannot use. That counts as "no mark", so in practice this wipes
-- the memory whenever the target or its mark changes: a mark applied some
-- other way takes two presses to clear. Should the game ever stop hiding the
-- value, this starts working without any change. In combat the secure state
-- cannot be changed from addon code, so there it stays as the last press
-- left it.
local function SyncLastMark()
    if not header or InCombatLockdown() then return end
    local index = 0
    local ok, value = pcall(GetRaidTargetIndex, "target")
    if ok and not (issecretvalue and issecretvalue(value)) and type(value) == "number" then
        index = value
    end
    header:SetAttribute("lastmark", index)
end
local UpdateMinimapButton -- defined with the minimap button, further down
-- Owns the always-on binding for the clear-all hotkey.
local globalBinds = CreateFrame("Frame", "HoverMarksForeverGlobalBinds", UIParent)

local function Say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100HoverMarks Forever:|r " .. message)
end

---------------------------------------------------------------------------
-- Chat: hide the "X sets <mark> on Y" lines the clear-all macro causes
---------------------------------------------------------------------------

-- The clear-all key marks the player with each of the eight marks in turn,
-- and the game prints a chat line for every one. For two seconds after the
-- key is used, any chat line carrying a raid-target icon is hidden. At any
-- other time nothing is touched, so other players' marking still shows.
local function QuietClearAll(_, event, text)
    if GetTime() >= quietUntil then return false end
    if event == "CHAT_MSG_TARGETICONS" then return true end
    if issecretvalue and issecretvalue(text) then return false end
    return type(text) == "string" and text:find("RaidTargetingIcon", 1, true) ~= nil
end
do
    local addFilter = ChatFrame_AddMessageEventFilter
        or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if addFilter then
        addFilter("CHAT_MSG_TARGETICONS", QuietClearAll)
        addFilter("CHAT_MSG_SYSTEM", QuietClearAll)
    end
end

---------------------------------------------------------------------------
-- Secure side: hidden marker buttons and a hover layer on each target frame
---------------------------------------------------------------------------

local function MakeMarkerButton(name, action, marker)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    -- Acts on the key press itself, whatever the "cast on key down" setting
    -- is, and only once: the "press again" toggle below flips state on every
    -- click it sees, so it must never see both the press and the release.
    button:RegisterForClicks("AnyDown")
    button:SetAttribute("useOnKeyDown", true)
    button:SetAttribute("type", "raidtarget")
    button:SetAttribute("action", action)
    button:SetAttribute("marker", marker)
    button:SetAttribute("hmfmark", marker)
    button:SetAttribute("unit", "target")
    button:SetAttribute("checkselfcast", false)
    button:SetAttribute("checkfocuscast", false)
    return button
end

-- One hidden secure button per marker, which a hotkey "clicks" while
-- hovering, plus one that clears every marker and is bound all the time.
-- Must be called out of combat.
local function BuildButtons()
    if buttonsBuilt then return end
    -- The "press again to clear" toggle lives here, in secure code, so it
    -- works in combat and never has to read the target's current mark (which
    -- the game may hide from addons). It only remembers which mark the last
    -- press applied: pressing the same one again clears it instead.
    -- Attributes on this frame: toggleon (1 or 0) and lastmark (0 = none).
    header = CreateFrame("Frame", "HoverMarksForeverHeader", UIParent, "SecureHandlerBaseTemplate")
    header:SetAttribute("toggleon", 1)
    header:SetAttribute("lastmark", 0)
    for marker = 1, NUM_MARKERS do
        buttons[marker] = MakeMarkerButton(PREFIX .. marker, "set", marker)
        header:WrapScript(buttons[marker], "OnClick", [[
            local mark = self:GetAttribute("hmfmark")
            if control:GetAttribute("toggleon") == 1 and control:GetAttribute("lastmark") == mark then
                self:SetAttribute("action", "clear")
                self:SetAttribute("marker", 0)
                control:SetAttribute("lastmark", 0)
            else
                self:SetAttribute("action", "set")
                self:SetAttribute("marker", mark)
                control:SetAttribute("lastmark", mark)
            end
        ]])
    end
    local clear = CreateFrame("Button", PREFIX .. "Clear", UIParent, "SecureActionButtonTemplate")
    clear:RegisterForClicks("AnyDown", "AnyUp")
    clear:SetAttribute("type", "macro")
    clear:SetAttribute("macrotext", CLEAR_ALL_MACRO)
    -- Clearing everything also forgets the last mark, so the next press
    -- applies instead of "clearing" something that is already gone.
    header:WrapScript(clear, "OnClick", [[ control:SetAttribute("lastmark", 0) ]])
    -- Clearing everything this way briefly marks the player with each mark
    -- in turn, and the game prints a chat line for each. Hide those lines
    -- for a moment after the clear key is used (see QuietClearAll above).
    clear:HookScript("PreClick", function() quietUntil = GetTime() + 2 end)
    -- Clears only the current target's mark. It needs no knowledge of what
    -- mark the target has, so unlike "press again" it works on the first
    -- press every time.
    local clearTarget = CreateFrame("Button", PREFIX .. "ClearTarget", UIParent, "SecureActionButtonTemplate")
    clearTarget:RegisterForClicks("AnyDown")
    clearTarget:SetAttribute("useOnKeyDown", true)
    clearTarget:SetAttribute("type", "raidtarget")
    clearTarget:SetAttribute("action", "clear")
    clearTarget:SetAttribute("marker", 0)
    clearTarget:SetAttribute("unit", "target")
    clearTarget:SetAttribute("checkselfcast", false)
    clearTarget:SetAttribute("checkfocuscast", false)
    header:WrapScript(clearTarget, "OnClick", [[ control:SetAttribute("lastmark", 0) ]])
    buttonsBuilt = true
end

local function IsUsableFrame(object)
    if type(object) ~= "table" or type(object.GetObjectType) ~= "function" then return false end
    local ok, usable = pcall(function()
        return not (object.IsForbidden and object:IsForbidden()) and object.GetFrameLevel ~= nil
    end)
    return ok and usable
end

-- Invisible layer over one target frame. It only listens for the mouse
-- arriving and leaving; clicks fall through to the frame underneath.
local function Attach(host, hostName)
    local ok, overlay = pcall(function()
        local layer = CreateFrame("Frame", "HoverMarksForeverOverlay" .. (#overlayList + 1), host,
            "SecureHandlerEnterLeaveTemplate,SecureHandlerShowHideTemplate")
        layer:SetAllPoints(host)
        layer:SetFrameLevel(host:GetFrameLevel() + 20)
        layer:SetMouseClickEnabled(false)
        layer:SetMouseMotionEnabled(true)
        -- Keep tooltips and hover text on the frames underneath working.
        if layer.SetPropagateMouseMotion then
            pcall(layer.SetPropagateMouseMotion, layer, true)
        end
        -- Each hover starts the toggle afresh; out of combat it then reads
        -- the target's real mark (the hook runs after the secure code).
        layer:SetFrameRef("hmfheader", header)
        layer:HookScript("OnEnter", SyncLastMark)
        layer:SetAttribute("_onenter", enterSnippet)
        layer:SetAttribute("_onleave", RESET_TOGGLE .. "self:ClearBindings()")
        -- Losing the target while hovering hides the frame without a "leave".
        layer:SetAttribute("_onhide", RESET_TOGGLE .. "self:ClearBindings()")
        return layer
    end)
    if not ok then return end
    overlay.hostName = hostName
    overlays[host] = overlay
    overlayList[#overlayList + 1] = overlay
end

-- Attach to every known target frame that exists and is not yet covered.
-- Unit-frame addons can create theirs well after this addon loads, so this
-- is called again at login, on entering the world and on target changes.
-- Does nothing in combat, when protected frames cannot be created.
local function AttachAll()
    if InCombatLockdown() then return end
    BuildButtons()
    local function Try(name)
        local host = _G[name]
        if IsUsableFrame(host) and not overlays[host] then Attach(host, name) end
    end
    if db.customFrame then Try(db.customFrame) end
    for _, name in ipairs(TARGET_FRAMES) do Try(name) end
end

-- Push the chosen hotkeys into the secure frames. Not allowed in combat, so
-- a change made in combat waits until combat ends.
local function Apply()
    if InCombatLockdown() then
        pending = true
        return false
    end
    pending = nil
    AttachAll()
    local lines = {}
    -- The clear-all hotkey is bound all the time, not just while hovering.
    -- Priority binding, so it also wins over action-bar addons' own
    -- override bindings for that key.
    -- When the addon is switched off (minimap button), nothing is bound at
    -- all: no clear-all key and no hover hotkeys.
    ClearOverrideBindings(globalBinds)
    if db.enabled and db.clearKey then
        SetOverrideBindingClick(globalBinds, true, db.clearKey, PREFIX .. "Clear", "LeftButton")
    end
    -- "Press again to clear" on or off (see BuildButtons for how it works).
    if header then
        header:SetAttribute("toggleon", db.toggle and 1 or 0)
        header:SetAttribute("lastmark", 0)
    end
    -- Holding a modifier with a mark's key clears instead of applying:
    --   Ctrl  + key  clears every mark on every unit
    --   Shift + key  clears just the current target's mark
    -- These lines go first, so a mark whose own key already uses that
    -- modifier (and so would collide) still wins on that key.
    if db.enabled then
        for _, modifier in ipairs({ "CTRL", "SHIFT" }) do
            local clearButton = PREFIX .. (modifier == "CTRL" and "Clear" or "ClearTarget")
            for marker = 1, NUM_MARKERS do
                local key = db.binds[marker]
                if key then
                    local base = key:match("[^-]+$") or "-"
                    local prefix = key:sub(1, #key - #base)
                    if not prefix:find(modifier .. "-", 1, true) then
                        -- The key plus the extra modifier, in the game's
                        -- ALT-CTRL-SHIFT order.
                        local function Has(name)
                            return modifier == name or prefix:find(name .. "-", 1, true)
                        end
                        local combo = (Has("ALT") and "ALT-" or "") .. (Has("CTRL") and "CTRL-" or "")
                            .. (Has("SHIFT") and "SHIFT-" or "") .. base
                        lines[#lines + 1] = ("self:SetBindingClick(true, %q, %q, \"LeftButton\")")
                            :format(combo, clearButton)
                    end
                end
            end
        end
    end
    for marker = 1, NUM_MARKERS do
        local key = db.enabled and db.binds[marker]
        if key then
            lines[#lines + 1] = ("self:SetBindingClick(true, %q, %q, \"LeftButton\")")
                :format(key, PREFIX .. marker)
        end
    end
    enterSnippet = RESET_TOGGLE .. table.concat(lines, "\n")
    for _, overlay in ipairs(overlayList) do
        ClearOverrideBindings(overlay)
        overlay:SetAttribute("_onenter", enterSnippet)
    end
    SyncLastMark()
    return true
end

---------------------------------------------------------------------------
-- Settings window (/hmf)
---------------------------------------------------------------------------

local MARKER_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
-- Every bindable row has an id: a marker number (1-8) or CLEAR for the
-- hotkey that removes the marker. These helpers hide where each is stored.
local CLEAR = "clear"
local function GetBind(id)
    if id == CLEAR then return db.clearKey end
    return db.binds[id]
end
local function SetBind(id, key)
    if id == CLEAR then db.clearKey = key else db.binds[id] = key end
end
local function RowName(id)
    return id == CLEAR and "Clear All" or MARKER_NAMES[id]
end
local RESET_POPUP = "HOVERMARKSFOREVER_RESET"
local DEFAULT_Y = 60 -- opens a little above the middle of the screen

local function KeyLabel(key)
    if not key then return "|cff808080Unbound|r" end
    return (GetBindingText and GetBindingText(key)) or key
end

local function ClickSound()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

-- A clickable box with rounded corners (the same tooltip border art as the
-- window, at a smaller size). Its look always comes from three states, so
-- every box in the window behaves the same way:
-- active (gold), hovered (brighter), idle (quiet).
local BOX_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function PaintBox(box)
    if box.active then
        box:SetBackdropBorderColor(1, 0.82, 0, 1)
        box:SetBackdropColor(0.35, 0.27, 0.02, 1)
    elseif box.hovered then
        box:SetBackdropBorderColor(1, 1, 1, 1)
        box:SetBackdropColor(0.2, 0.2, 0.23, 1)
    else
        box:SetBackdropBorderColor(0.55, 0.55, 0.58, 1)
        box:SetBackdropColor(0.11, 0.11, 0.13, 1)
    end
end

local function ShowBoxTip(box)
    if not box.tipTitle then return end
    GameTooltip:SetOwner(box, "ANCHOR_RIGHT")
    local tipTitle = type(box.tipTitle) == "function" and box.tipTitle(box) or box.tipTitle
    GameTooltip:SetText(tipTitle, 1, 0.82, 0)
    local lines = type(box.tipLines) == "function" and box.tipLines(box) or box.tipLines
    for _, line in ipairs(lines or {}) do
        GameTooltip:AddLine(line, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function MakeBox(parent, width, height)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop(BOX_BACKDROP)
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.text:SetPoint("LEFT", 6, 0)
    box.text:SetPoint("RIGHT", -6, 0)
    box.text:SetJustifyH("CENTER")
    box.text:SetWordWrap(false)
    box:SetScript("OnEnter", function(self)
        self.hovered = true
        PaintBox(self)
        ShowBoxTip(self)
    end)
    box:SetScript("OnLeave", function(self)
        self.hovered = nil
        PaintBox(self)
        GameTooltip:Hide()
    end)
    PaintBox(box)
    return box
end

local function Refresh()
    if not panel then return end
    for id, row in pairs(panel.rows) do
        local key = GetBind(id)
        row.active = listening == id
        row.text:SetText(row.active and "|cffffd100Press a key|r" or KeyLabel(key))
        PaintBox(row)
        -- A row with no hotkey is shown faded, so it reads as "off".
        row.icon:SetDesaturated(not key and not row.active)
        row.icon:SetAlpha((key or row.active) and 1 or 0.45)
    end
    if panel.toggleBox then panel.toggleBox:SetChecked(db.toggle) end

    -- One status line, most urgent message first.
    if listening then
        panel.note:SetText("|cffffd100Press a key for " .. RowName(listening) .. ". Esc to cancel.|r")
    elseif pending then
        panel.note:SetText("|cffff8040Saved. Applies after combat.|r")
    else
        -- Nothing else to report: the section descriptions cover the rest.
        panel.note:SetText(db.enabled and "" or "|cffff4040HoverMarks is off.|r Click the minimap button to turn it on.")
    end
end

local function StopListening()
    listening = nil
    panel:EnableKeyboard(false)
    Refresh()
end

local function Commit()
    if not Apply() then
        Say("Saved. Applies after combat.")
    end
end

local function OnToggleClick(self)
    if listening then StopListening() end
    ClickSound()
    db.toggle = self:GetChecked() and true or false
    Commit()
    Refresh()
    if self.hovered then ShowBoxTip(self) end
end

local function OnKeyDown(_, key)
    if not listening or MODIFIER_KEYS[key] or key == "UNKNOWN" then return end
    if key == "ESCAPE" then
        StopListening()
        return
    end
    local combo = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    -- A hotkey can only do one thing: take it from any other row (markers
    -- and clear alike), and say so, since that row changes without being
    -- clicked.
    for id in pairs(panel.rows) do
        if id ~= listening and GetBind(id) == combo then
            SetBind(id, false)
            Say(("%s rebound from %s to %s."):format(KeyLabel(combo), RowName(id), RowName(listening)))
        end
    end
    SetBind(listening, combo)
    ClickSound()
    Commit()
    StopListening()
end

local function OnRowClick(self, mouseButton)
    if mouseButton == "RightButton" then
        listening = nil
        panel:EnableKeyboard(false)
        if GetBind(self.id) then
            SetBind(self.id, false)
            ClickSound()
            Commit()
        end
        Refresh()
    elseif listening == self.id then
        StopListening()
    else
        ClickSound()
        listening = self.id
        panel:EnableKeyboard(true)
        Refresh()
    end
    if self.hovered then ShowBoxTip(self) end
end

-- Row tooltip (markers and clear alike):
--   Hotkey: 1
--   —
--   Click to bind.
--   Right click to unbind.
local function RowTipTitle(row)
    return "Hotkey: " .. KeyLabel(GetBind(row.id))
end

local ROW_TIP_LINES = { "—", "Click to bind.", "Right click to unbind." }
local CLEAR_TIP_LINES = { "—", "Click to bind.", "Right click to unbind.", "Works anywhere, so this key stops doing its normal action." }

local function ResetToDefaults()
    db.binds = { unpack(DEFAULTS, 1, NUM_MARKERS) }
    db.clearKey = DEFAULT_CLEAR_KEY
    db.enabled = true
    db.toggle = true
    db.minimapAngle = nil
    if UpdateMinimapButton then UpdateMinimapButton() end
    db.pos = nil
    if panel then
        listening = nil
        panel:EnableKeyboard(false)
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
    Commit()
    Refresh()
    Say("Reset to defaults.")
end

StaticPopupDialogs[RESET_POPUP] = {
    text = "Reset HoverMarks Forever to defaults?",
    button1 = YES,
    button2 = NO,
    OnAccept = ResetToDefaults,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function BuildPanel()
    -- The window is portrait (340 x 502), sized to its content. Everything
    -- sits on the same two-column grid, filled left to right then down:
    -- markers 1 2 / 3 4 / 5 6 / 7 8 in ORDER; the clear hotkey sits centred below.
    --
    -- Vertical rhythm, measured down from the top edge. Gaps come from one
    -- scale: 8 inside a group, 12 below a rule, 14-18 above a rule,
    -- 26 before a new section.
    --    18  title (large, bright gold)              level 1
    --    52  strong rule
    --    68  "Marker Hover Hotkeys" heading (tan)    level 2
    --    84  its two-line description (small white)
    --   114  its note (small tan, up to two lines)
    --   152  faint rule
    --   164  four marker rows, 26 tall, 8 apart      level 3 (white values)
    --   318  "Clear All Markers" heading             level 2
    --   334  its two-line description
    --   372  faint rule
    --   392  the clear hotkey row                    level 3
    --   436  status line (small, grey)               level 4
    local TOGGLE_SPACE = 12 + 26 + 8              -- gap + switch height + gap below
    local WIDTH, HEIGHT = 340, 456 + TOGGLE_SPACE
    local NOTE_SPACE = 30                        -- room for a section's note
    local EDGE, GAP = 20, 28                     -- side margin, gap between columns
    local TOP, ROW = 134 + NOTE_SPACE, 34        -- first marker row, row pitch
    local ICON, BOX, BOX_HEIGHT = 26, 76, 26     -- marker icon, hotkey box
    local PAIR = ICON + 10 + BOX                 -- icon + gap + hotkey box
    local SECTION_GAP = 26                       -- space before a new section
    local HEADING_ABOVE, DESCRIPTION_ABOVE, RULE_ABOVE = 66, 50, 12 -- above content
    local COLUMN = (WIDTH - EDGE * 2 - GAP) / 2
    -- Left edge of the content in a column (0 or 1); shared by both sections.
    local function ColumnX(column)
        return EDGE + column * (COLUMN + GAP) + (COLUMN - PAIR) / 2
    end

    panel = CreateFrame("Frame", "HoverMarksForeverPanel", UIParent, "BackdropTemplate")
    panel:SetSize(WIDTH, HEIGHT)
    -- Reopens where it was last left; otherwise a little above the middle.
    local pos = db.pos
    if pos then
        panel:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
    end
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint(1)
        db.pos = { point, relativePoint, x, y }
    end)
    -- Clicking empty space in the window cancels a pending key press.
    panel:SetScript("OnMouseDown", function()
        if listening then StopListening() end
    end)
    panel:SetScript("OnKeyDown", OnKeyDown)
    panel:SetScript("OnHide", function()
        listening = nil
        panel:EnableKeyboard(false)
        if StaticPopup_Hide then StaticPopup_Hide(RESET_POPUP) end
    end)
    panel:EnableKeyboard(false)
    panel:Hide()
    tinsert(UISpecialFrames, "HoverMarksForeverPanel") -- Escape closes it

    -- Rounded corners come from the game's tooltip border art; the fill is
    -- inset so it does not poke out past the curve.
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 24, -- larger than a tooltip (16) for a rounder corner
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.07, 0.96)
    panel:SetBackdropBorderColor(0.8, 0.68, 0.35, 1)

    -- Header ---------------------------------------------------------------
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("HoverMarks Forever")

    -- The version is reference detail, so it is small and grey beside the
    -- title instead of sharing its size.
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
    version:SetText("v" .. VERSION)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    -- The close button art has about 5px of empty margin, so this puts its
    -- visible cross level with the Defaults button and the same distance in.
    close:SetPoint("TOPRIGHT", -9, -10)

    local function Separator(y, alpha)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", EDGE, y)
        line:SetPoint("TOPRIGHT", -EDGE, y)
        line:SetColorTexture(0.8, 0.68, 0.35, alpha)
    end
    Separator(-52, 0.6)

    -- A section is a centred heading, a description of what the controls
    -- below do (wrapped, two lines), and a faint rule, all placed relative to
    -- where the section's content starts so every section has identical
    -- spacing.
    -- A section may also carry a note: a quieter aside under the description.
    -- It pushes the heading and description up by NOTE_SPACE to make room.
    local function Section(text, description, contentTop, note)
        local lift = note and NOTE_SPACE or 0
        local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOP", 0, contentTop + HEADING_ABOVE + lift)
        heading:SetTextColor(0.86, 0.78, 0.58)
        heading:SetText(text)
        local function Paragraph(content)
            local line = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            line:SetWidth(WIDTH - EDGE * 2)
            line:SetJustifyH("CENTER")
            line:SetJustifyV("TOP")
            line:SetWordWrap(true)
            line:SetSpacing(2)
            line:SetText(content)
            return line
        end
        local detail = Paragraph(description)
        detail:SetPoint("TOP", 0, contentTop + DESCRIPTION_ABOVE + lift)
        if note then
            -- The game ships no italic typeface, so the note is set apart by
            -- colour instead: the same tan as the headings.
            local aside = Paragraph(note)
            aside:SetPoint("TOP", detail, "BOTTOM", 0, -6)
            aside:SetTextColor(0.86, 0.78, 0.58)
        end
        Separator(contentTop + RULE_ABOVE, 0.25)
    end

    -- Marker hotkeys ---------------------------------------------------------
    Section("Mark Hover Hotkeys", "Press your chosen hotkey while hovering over a\nTarget Frame to mark your target quickly.", -TOP,
        "These hotkeys will only be active when\nhovering over a target frame.")
    panel.rows = {}
    -- One bindable row: an icon and a hotkey box, with its top-left at x, y.
    local function MakeRow(id, texture, x, y)
        local row = MakeBox(panel, BOX, BOX_HEIGHT)
        row:SetPoint("TOPLEFT", x + ICON + 10, y)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.id = id
        row.tipTitle = RowTipTitle
        row.tipLines = ROW_TIP_LINES
        row:SetScript("OnClick", OnRowClick)

        row.icon = panel:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("TOPLEFT", x, y)
        row.icon:SetTexture(texture)

        -- The icon is part of the same control: clicking or hovering it (or
        -- the gap between it and the box) behaves exactly like the box.
        local iconButton = CreateFrame("Button", nil, panel)
        iconButton:SetPoint("TOPLEFT", x, y)
        iconButton:SetSize(ICON + 10, ICON)
        iconButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        iconButton:SetScript("OnClick", function(_, mouseButton)
            OnRowClick(row, mouseButton)
        end)
        iconButton:SetScript("OnEnter", function()
            row.hovered = true
            PaintBox(row)
            ShowBoxTip(row)
        end)
        iconButton:SetScript("OnLeave", function()
            row.hovered = nil
            PaintBox(row)
            GameTooltip:Hide()
        end)
        panel.rows[id] = row
    end

    -- Icon + 10 gap + hotkey box, centred as a pair in each column.
    for position, marker in ipairs(ORDER) do
        MakeRow(marker, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. marker,
            ColumnX((position - 1) % 2), -TOP - math.floor((position - 1) / 2) * ROW)
    end

    -- "Press again to clear" checkbox, centred under the marker rows: the
    -- game's standard check button with its label to the right. The label is
    -- part of the click area, so either one can be clicked.
    local LABEL = "Press again to clear"
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(LABEL)
    local width = 24 + 4 + label:GetStringWidth()
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", (WIDTH - width) / 2, -TOP - 3 * ROW - BOX_HEIGHT - 12)
    check:SetHitRectInsets(0, -(label:GetStringWidth() + 6), 0, 0)
    check.tipTitle = LABEL
    check.tipLines = {
        "—",
        "Pressing a mark's mouseover hotkey again clears that particular mark.",
        "The game hides a target's mark from addons, so this clears marks applied with these hotkeys. A mark applied any other way takes two presses.",
        "|cffdbc794Only works while your mouse is over a target frame.|r", -- the headings' beige
    }
    check:SetScript("OnClick", OnToggleClick)
    check:SetScript("OnEnter", function(self)
        self.hovered = true
        ShowBoxTip(self)
    end)
    check:SetScript("OnLeave", function(self)
        self.hovered = nil
        GameTooltip:Hide()
    end)
    panel.toggleBox = check

    -- Clear marker -----------------------------------------------------------
    -- Heading, description, rule, then a single row like the marker rows,
    -- centred in the window: one hotkey that removes every marker, anywhere.
    local clearY = -TOP - 3 * ROW - BOX_HEIGHT - TOGGLE_SPACE - SECTION_GAP - HEADING_ABOVE
    Section("Clear All Marks", "Press this hotkey anywhere to clear every mark at once. No target or hovering needed.", clearY)
    -- Sits a little lower than a marker row would, clear of the rule above,
    -- and 6px left of true centre: the box is visually heavier than the icon,
    -- so a mathematically centred pair looks pushed to the right.
    MakeRow(CLEAR, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", (WIDTH - PAIR) / 2 - 6, clearY - 8)
    panel.rows[CLEAR].tipLines = CLEAR_TIP_LINES


    -- Defaults sits in the header's top-left corner, level with the title and
    -- opposite the close button.
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(66, 22)
    reset:SetPoint("TOPLEFT", 14, -15)
    reset:SetText("Defaults")
    reset:SetScript("OnClick", function()
        if listening then StopListening() end
        StaticPopup_Show(RESET_POPUP)
    end)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Defaults", 1, 0.82, 0)
        GameTooltip:AddLine("Reset hotkeys and window position.",
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    -- Footer: the status line alone, centred like everything above it.
    note:SetPoint("LEFT", panel, "BOTTOMLEFT", EDGE, 20)
    note:SetPoint("RIGHT", panel, "BOTTOMRIGHT", -EDGE, 20)
    note:SetJustifyH("CENTER")
    note:SetWordWrap(false)
    panel.note = note
end

---------------------------------------------------------------------------
-- Slash commands
--   /hmf               open or close the settings window
--   /hmf frame         use the target frame under the mouse
--   /hmf frame <name>  use the frame with that global name
--   /hmf frame clear   forget the custom frame
--   /hmf frames        list the frames the addon is attached to
---------------------------------------------------------------------------

-- Name of the target unit frame under the mouse, if there is one. Walks up
-- from whatever the mouse is on to the first named frame whose unit is
-- "target".
local function TargetFrameUnderMouse()
    local ok, name = pcall(function()
        local foci = (GetMouseFoci and GetMouseFoci()) or { GetMouseFocus and GetMouseFocus() }
        for _, frame in ipairs(foci) do
            for _ = 1, 12 do
                if not IsUsableFrame(frame) then break end
                local frameName = frame.GetName and frame:GetName()
                local unit = frame.GetAttribute and frame:GetAttribute("unit")
                if frameName and unit == "target" and not frameName:find("^HoverMarksForever") then
                    return frameName
                end
                frame = frame:GetParent()
            end
        end
    end)
    return ok and name or nil
end

local function SetCustomFrame(name)
    if name == "" then
        name = TargetFrameUnderMouse()
        if not name then
            Say("Hover your target frame and type /hmf frame, or type /hmf frame <name>.")
            return
        end
    elseif name:lower() == "clear" then
        db.customFrame = nil
        Say("Custom frame forgotten. Type /reload to detach from it.")
        return
    end
    db.customFrame = name
    if not IsUsableFrame(_G[name]) then
        Say(("No frame called %s exists right now. Saved; it will attach when the frame appears."):format(name))
    elseif InCombatLockdown() then
        pending = true
        Say(("Saved %s. It will attach after combat."):format(name))
    else
        AttachAll()
        Say(overlays[_G[name]] and ("Attached to %s."):format(name)
            or ("Could not attach to %s."):format(name))
    end
end

local function ListFrames()
    if #overlayList == 0 then
        Say("Not attached to any target frame yet.")
        return
    end
    local names = {}
    for _, overlay in ipairs(overlayList) do names[#names + 1] = overlay.hostName end
    Say("Attached to: " .. table.concat(names, ", ") .. ".")
end

local function ToggleWindow()
    if not panel then BuildPanel() end
    if panel:IsShown() then
        panel:Hide()
    else
        Refresh()
        panel:Show()
    end
end

---------------------------------------------------------------------------
-- Minimap button
--   Left click   turn the addon on or off
--   Right click  open or close the settings window
--   Drag         move it round the minimap
---------------------------------------------------------------------------

-- The picture inside the minimap button's border: a simplified version of
-- the logo, made to read at about 18 pixels across.
local MINIMAP_ICON_TEXTURE = "Interface\\AddOns\\" .. ADDON .. "\\Media\\MinimapIcon"
local DEFAULT_MINIMAP_ANGLE = 215 -- degrees anticlockwise from east: lower left
local minimapButton

UpdateMinimapButton = function()
    if not minimapButton then return end
    -- Greyed out while the addon is off, so its state shows at a glance.
    minimapButton.icon:SetDesaturated(not db.enabled)
    minimapButton.icon:SetAlpha(db.enabled and 1 or 0.6)
    local angle = math.rad(db.minimapAngle or DEFAULT_MINIMAP_ANGLE)
    local radius = Minimap:GetWidth() / 2 + 5
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function ShowMinimapTip(self)
    -- Two columns: name and version on the first line (gold / grey), then
    -- each action in blue on the left with what it does in white on the right.
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("HoverMarks Forever", "v" .. VERSION, 1, 0.82, 0, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Left Click", "Toggle Addon", 0.2, 0.7, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Right Click", "Open Settings", 0.2, 0.7, 1, 1, 1, 1)
    GameTooltip:Show()
end

local function SetEnabled(enabled)
    db.enabled = enabled
    local applied = Apply()
    UpdateMinimapButton()
    Refresh()
    -- The whole notice, addon name included, is green for on and red for
    -- off, so it does not go through Say (which colours the name gold).
    local notice = "HoverMarks Forever is " .. (enabled and "enabled." or "disabled.")
        .. (applied and "" or " Applies after combat.")
    if enabled then
        DEFAULT_CHAT_FRAME:AddMessage(notice, 0.25, 1, 0.25)
    else
        DEFAULT_CHAT_FRAME:AddMessage(notice, 1, 0.25, 0.25)
    end
end

local function BuildMinimapButton()
    if minimapButton or not Minimap then return end
    local button = CreateFrame("Button", "HoverMarksForeverMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- The standard minimap button, built the same way every other addon's
    -- is: a dark round backing, the icon inside, the game's gold tracking
    -- border over the top, and the usual highlight on hover.
    --
    -- The border art differs between client generations, so the sizes and
    -- offsets come in two sets, copied from LibDBIcon (the library most
    -- addons use for this). Modern clients have the addon compartment and
    -- use the centred layout; older ones use the offset layout. Using the
    -- wrong set leaves the icon visibly off-centre in the ring.
    local modern = AddonCompartmentFrame ~= nil
    local backing = button:CreateTexture(nil, "BACKGROUND")
    backing:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(MINIMAP_ICON_TEXTURE)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", 0, 0)
    -- The icon keeps the library's centre point, with no shift, but is drawn
    -- 3px larger than the library's size. The artwork is a round disc, and
    -- at the library's size it is smaller than the ring's opening, leaving
    -- an uneven dark gap; slightly larger, the ring overlaps its edge.
    if modern then
        backing:SetSize(24, 24)
        backing:SetPoint("CENTER", 0, 0)
        button.icon:SetSize(21, 21)
        button.icon:SetPoint("CENTER")
        border:SetSize(50, 50)
    else
        backing:SetSize(20, 20)
        backing:SetPoint("TOPLEFT", 7, -5)
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("CENTER", button, "TOPLEFT", 15.5, -14.5)
        border:SetSize(53, 53)
    end

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ToggleWindow()
        else
            SetEnabled(not db.enabled)
        end
        if GameTooltip:IsOwned(self) then ShowMinimapTip(self) end
    end)
    button:SetScript("OnEnter", ShowMinimapTip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Dragging slides the button round the edge of the minimap.
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local centreX, centreY = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            db.minimapAngle = math.deg(math.atan2(cursorY / scale - centreY, cursorX / scale - centreX))
            UpdateMinimapButton()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button.modern = modern
    minimapButton = button
    UpdateMinimapButton()
end

-- Addon menu entry (the list opened from the minimap's addon button). The
-- game builds it from the ## AddonCompartmentFunc lines in the .toc, which
-- name these global functions. Same clicks as the minimap button.
function HoverMarksForever_OnAddonCompartmentClick(_, mouseButton)
    if mouseButton == "RightButton" then
        ToggleWindow()
    else
        SetEnabled(not db.enabled)
    end
end

function HoverMarksForever_OnAddonCompartmentEnter(_, menuButtonFrame)
    ShowMinimapTip(menuButtonFrame)
end

function HoverMarksForever_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end

SLASH_HOVERMARKSFOREVER1 = "/hmf"
SlashCmdList.HOVERMARKSFOREVER = function(message)
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = (command or ""):lower()
    if command == "frame" then
        SetCustomFrame(rest or "")
    elseif command == "frames" then
        ListFrames()
    elseif command == "" then
        ToggleWindow()
    else
        Say("Commands: /hmf (settings), /hmf frame, /hmf frame <name>, /hmf frame clear, /hmf frames.")
    end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

local function LoadSettings()
    if type(HoverMarksForeverDB) ~= "table" then HoverMarksForeverDB = {} end
    local saved = HoverMarksForeverDB
    if type(saved.binds) ~= "table" then
        saved.binds = { unpack(DEFAULTS, 1, NUM_MARKERS) }
    end
    for marker = 1, NUM_MARKERS do
        local key = saved.binds[marker]
        if type(key) ~= "string" or key == "" then saved.binds[marker] = false end
    end
    -- Hotkey that clears all markers; false means none. Before settings
    -- version 4 this was a hover-only key (and earlier a held modifier); it
    -- now takes its key over everywhere, so an old value is not carried
    -- across and the player chooses a key deliberately.
    saved.clearMod = nil
    if (tonumber(saved.version) or 0) < 4 or type(saved.clearKey) ~= "string" or saved.clearKey == "" then
        saved.clearKey = DEFAULT_CLEAR_KEY
    end
    -- Where the settings window was last dragged to; dropped if malformed.
    local pos = saved.pos
    if type(pos) ~= "table" or type(pos[1]) ~= "string" or type(pos[2]) ~= "string"
        or type(pos[3]) ~= "number" or type(pos[4]) ~= "number" then
        saved.pos = nil
    end
    -- Extra target frame chosen with /hmf frame; dropped if malformed.
    if type(saved.customFrame) ~= "string" or saved.customFrame == "" then
        saved.customFrame = nil
    end
    -- On unless the player switched it off with the minimap button.
    if saved.enabled ~= false then saved.enabled = true end
    -- Pressing a marker's key again clears it. On unless switched off.
    if saved.toggle ~= false then saved.toggle = true end
    -- Where the minimap button was dragged to, in degrees; nil = default.
    if type(saved.minimapAngle) ~= "number" then saved.minimapAngle = nil end
    -- Left over from a removed test command; cleared so it is not kept.
    saved.iconNudge = nil
    -- If the saved hotkeys are still an earlier version's defaults, move to
    -- the current defaults; customised hotkeys are kept.
    if (tonumber(saved.version) or 0) < 3 then
        for _, old in ipairs(OLD_DEFAULTS) do
            local untouched = true
            for marker = 1, NUM_MARKERS do
                if saved.binds[marker] ~= old[marker] then untouched = false end
            end
            if untouched then
                saved.binds = { unpack(DEFAULTS, 1, NUM_MARKERS) }
                break
            end
        end
    end
    saved.version = 4
    db = saved
end

-- Create the secure frames straight away where possible: this is always
-- allowed while the UI is loading, even after a /reload in combat.
AttachAll()

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("RAID_TARGET_UPDATE")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        LoadSettings()
        Apply()
    elseif event == "PLAYER_LOGIN" then
        Apply()
        BuildMinimapButton()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Unit-frame addons may build their target frame around now or a
        -- moment later, so look again shortly after.
        AttachAll()
        if C_Timer and C_Timer.After then C_Timer.After(3, AttachAll) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Cheap: a dozen name lookups. Catches frames created on first use.
        AttachAll()
        -- A new target: the toggle reads its real mark (out of combat).
        SyncLastMark()
    elseif event == "RAID_TARGET_UPDATE" then
        -- Someone changed a mark, so re-read the target's.
        SyncLastMark()
    elseif pending then
        -- Leaving combat with a change waiting.
        Apply()
        Refresh()
        SyncLastMark()
    else
        AttachAll()
        SyncLastMark()
    end
end)
