-- ***************************************************************************
-- TitanBgGeneral.lua
--
-- Titan Panel - Battleground General Addon
-- Version: 1.0.0
-- Date: August 5th, 2025
-- Author: Honour Bound Game Studios Inc.
-- Description:
-- ***************************************************************************

local _G = getfenv(0);
local ADDON_ID = "BgGeneral"
local VERSION = "1.0.0"
local TITAN_BUTTON_NAME = "TitanPanel" .. ADDON_ID .. "Button"

-- ******************************** Debugging *******************************
Titan_Debug[ADDON_ID] = {}
Titan_Debug[ADDON_ID].Events = false
Titan_Debug[ADDON_ID].Flow   = false

-- DEV BUILD DEFAULT: always surface Lua errors (the in-game error popup) while
-- the addon is under construction, so nothing fails silently mid-match. Set as
-- early as possible to catch load-time errors too. ⚠ Strip this (or gate it
-- behind a setting) before release — tracked in Epic 5 / SmokeChecklist.
SetCVar("scriptErrors", "1")

-- ******************************** Variables *******************************
TitanBgGeneralSaved = TitanBgGeneralSaved or {}

-- Default true; reads defensively so players upgrading from older versions
-- (no autoOpen key saved) get the feature without a migration.
local function IsAutoOpenEnabled()
    return TitanBgGeneralSaved.autoOpen ~= false
end

local nodeIcons = {
    ["Stables"] = "Interface\\Icons\\Ability_Mount_RidingHorse",
    ["Gold Mine"] = "Interface\\Icons\\trade_mining",
    ["Blacksmith"] = "Interface\\Icons\\Trade_BlackSmithing",
    ["Lumber Mill"] = "Interface\\Icons\\INV_Axe_09",
    ["Farm"] = "Interface\\Icons\\INV_Misc_Food_Wheat_01"
}

local actions = {
    "INC", -- Incoming attack
    "DEF", -- Defend
    "HELP", -- Need help
    "SAFE", -- Safe/All clear
    "LOST", -- Node lost
    "CAP", -- Capture node
    "RETREAT", -- Retreat
    "GY", -- Graveyard callout
    "STACK", -- Stack here
    "SPREAD", -- Spread out
    "GROUP", -- Group up
    "RUSH", -- Rush target
    "SPLIT", -- Split push
    "CC" -- Crowd control needed
}

local nodeAbbrToName = {
    ST = "Stables",
    GM = "Gold Mine",
    BS = "Blacksmith",
    LM = "Lumber Mill",
    FM = "Farm"
}

local wsgCols = {
    { abbr = "EFC",  full = "EFC",    icon = "Interface\\Icons\\inv_misc_tournaments_symbol_scourge" },
    { abbr = "FC",   full = "FC",     icon = "Interface\\Icons\\spell_misc_hellifrepvphonorholdfavor" },
    { abbr = "MID",  full = "Mid",    icon = "Interface\\Icons\\Ability_Warrior_OffensiveStance" },
    { abbr = "RAMP", full = "Ramp",   icon = "Interface\\Icons\\Ability_Warrior_Charge" },
    { abbr = "TUN",  full = "Tunnel", icon = "Interface\\Icons\\Ability_Stealth" },
}
local wsgRowActions = { "INC", "DEF", "HELP", "KILL", "GO", "CAP" }

local avCols = {
    { abbr = "DB", full = "Dun Baldar",     icon = "Interface\\Icons\\INV_BannerPVP_02" },
    { abbr = "IW", full = "Icewing Bunker", icon = "Interface\\Icons\\Spell_Frost_FrostArmor02" },
    { abbr = "SH", full = "Stonehearth",    icon = "Interface\\Icons\\INV_Stone_15" },
    { abbr = "SF", full = "Snowfall GY",    icon = "Interface\\Icons\\Spell_Frost_IceStorm" },
    { abbr = "TP", full = "Tower Point",    icon = "Interface\\Icons\\Spell_Fire_Immolation" },
    { abbr = "IB", full = "Iceblood",       icon = "Interface\\Icons\\Spell_Frost_FrostShock" },
    { abbr = "FW", full = "Frostwolf",      icon = "Interface\\Icons\\INV_BannerPVP_01" },
}
local avRowActions = { "INC", "DEF", "HELP", "CAP", "GO", "RECAP" }

-- Battleground detection by instance map ID (locale-independent; covers the
-- classic maps and their retail variants — see Research/bg-detection-reference.md)
local BG_BY_MAP_ID = {
    [489]  = "WSG", [2106] = "WSG",
    [529]  = "AB",  [2107] = "AB",  [2177] = "AB",
    [30]   = "AV",  [2197] = "AV",
}

-- Returns "WSG" | "AB" | "AV" | nil — the single source of truth for
-- "which battleground am I standing in" (tab auto-select, button text, advisor).
local function GetActiveBg()
    local inInstance, instanceType = IsInInstance()
    if not (inInstance and instanceType == "pvp") then
        return nil
    end
    local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    return BG_BY_MAP_ID[instanceMapID]
end

-- ******************************** PrepareBgGeneralMenu *******************************
---local Build the right-click dropdown menu (UIDropDownMenu scheme)
local function PrepareBgGeneralMenu()
    TitanPanelRightClickMenu_AddTitle(TitanPlugins[ADDON_ID].menuText)

    local level = TitanPanelRightClickMenu_GetDropdownLevel()

    TitanPanelRightClickMenu_AddToggleIcon(ADDON_ID, level)
    TitanPanelRightClickMenu_AddToggleRightSide(ADDON_ID, level)

    local info = UIDropDownMenu_CreateInfo()
    info.text = "Auto-open in battlegrounds"
    info.isNotRadio = true
    info.checked = IsAutoOpenEnabled()
    info.func = function()
        TitanBgGeneralSaved.autoOpen = not IsAutoOpenEnabled()
    end
    UIDropDownMenu_AddButton(info, level)

    TitanPanelRightClickMenu_AddSpacer()
    TitanPanelRightClickMenu_AddHide(ADDON_ID, level)
end

-- ******************************** GetButtonText *******************************
-- Titan bar text: the active BG while inside one (e.g. "AB"), empty otherwise
-- so the bar stays icon-only out in the world. Label is hidden unless the
-- player enables Titan's "Show label text".
local function GetButtonText()
    local bg = GetActiveBg()
    if bg then
        return "BG: ", TitanUtils_GetGreenText(bg)
    end
    return "", ""
end

-- ******************************** OnLoad *******************************
---local Initialize the addon when loaded
local function OnLoad(self)
    self.registry = {
        id = ADDON_ID,
        category = "Combat",
        version = VERSION,
        menuText = "Battleground General",
        menuTextFunction = PrepareBgGeneralMenu,
        tooltipTitle = "Battleground General",
        tooltipTextFunction = GetTooltipText,
        buttonTextFunction = GetButtonText,
        icon = "Interface\\Icons\\INV_BannerPVP_01",
        iconWidth = 16,
        controlVariables = {
            ShowIcon = true,
            ShowLabelText = false,
            ShowColoredText = false,
            ShowRegularText = false,
            DisplayOnRightSide = false,
        },
        savedVariables = {
            ShowIcon = true,
            ShowLabelText = false,
            ShowColoredText = false,
            ShowRegularText = false,
            DisplayOnRightSide = false,
        },
    }
end

local function GetChatType()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    else
        return "SAY"
    end
end

-- ******************************** GetTooltipText *******************************
-- Function to generate the tooltip text when hovering over the button
-- This function will be called by Titan Panel to display detailed information.
function GetTooltipText()
    return "Battleground General Addon\nTracks your battleground stats and performance."
end

-- ******************************** ThreatProvider (CMD-6/7 skeleton) *******************************
-- Ranks enemy players from the battlefield scoreboard: healers (CC list, by
-- healingDone) and dangerous DPS (KILL list, by damageDone, killingBlows
-- tiebreak). Design: Research/enemy-threat-research.md (Recommendation).
--
-- ⚠ VERIFICATION GATE — not GREEN until the Era scoreboard /dump session
-- (Research/enemy-threat-research.md, Action Items). SCORE_POS below is
-- Details' shipped classic unpack — honor `rank` at position 7 shifts
-- everything after it vs the retail wiki shape. If the /dump disagrees,
-- fix SCORE_POS and nothing else. Until then output is debug-only
-- (/bgthreat prints locally; nothing is ever sent to chat from here).
local ThreatProvider = {}
do
    -- Positions in the classic GetBattlefieldScore(i) return list (UNVERIFIED on Era)
    local SCORE_POS = {
        name = 1, killingBlows = 2, faction = 6,
        classToken = 10, damageDone = 11, healingDone = 12,
    }

    -- Era class prior: only these classes can heal (faction split leaves 3 per side)
    local HEALER_CAPABLE = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }
    local H2D          = 1.5    -- healer ratio rule: healing > H2D × damage
    local HEAL_FLOOR   = 20000  -- minimum healingDone before ranking kicks in; calibrate at the /dump session
    local POLL_SECONDS = 10     -- Details ships 10s, BGE 2s; 10s is plenty for cumulative data
    local TOP_N        = 2

    local ticker, eventFrame
    local ccList, killList = {}, {}

    local function ReadScoreRow(i)
        -- Branch on API presence, not flavor (retail has structured score info)
        if C_PvP and C_PvP.GetScoreInfo then
            local s = C_PvP.GetScoreInfo(i)
            if not s or not s.name then return nil end
            return {
                name = s.name, killingBlows = s.killingBlows or 0, faction = s.faction,
                classToken = s.classToken,
                damageDone = s.damageDone or 0, healingDone = s.healingDone or 0,
            }
        end
        local r = { GetBattlefieldScore(i) }
        if not r[SCORE_POS.name] then return nil end
        -- type-checked so a wrong SCORE_POS degrades the ranking, never errors
        local token = r[SCORE_POS.classToken]
        return {
            name         = r[SCORE_POS.name],
            killingBlows = tonumber(r[SCORE_POS.killingBlows]) or 0,
            faction      = r[SCORE_POS.faction],
            classToken   = type(token) == "string" and token or nil,
            damageDone   = tonumber(r[SCORE_POS.damageDone]) or 0,
            healingDone  = tonumber(r[SCORE_POS.healingDone]) or 0,
        }
    end

    local function Rebuild()
        wipe(ccList)
        wipe(killList)
        -- Scoreboard faction is numeric: 0 = Horde, 1 = Alliance (locale-independent)
        local myFaction = (UnitFactionGroup("player") == "Horde") and 0 or 1

        local healers, others = {}, {}
        for i = 1, GetNumBattlefieldScores() do
            local row = ReadScoreRow(i)
            if row and row.faction ~= nil and row.faction ~= myFaction then
                local isHealer = HEALER_CAPABLE[row.classToken or ""]
                    and row.healingDone > H2D * row.damageDone
                    and row.healingDone > HEAL_FLOOR
                if isHealer then
                    healers[#healers + 1] = row
                else
                    others[#others + 1] = row
                end
            end
        end

        table.sort(healers, function(a, b) return a.healingDone > b.healingDone end)
        table.sort(others, function(a, b)
            if a.damageDone ~= b.damageDone then return a.damageDone > b.damageDone end
            return a.killingBlows > b.killingBlows
        end)

        for i = 1, math.min(TOP_N, #healers) do ccList[i] = healers[i] end
        for i = 1, math.min(TOP_N, #others) do killList[i] = others[i] end

        -- Cold start: nobody past HEAL_FLOOR yet — fall back to the class prior,
        -- marked as a guess (copies, so the same row can rank in KILL unmarked)
        if #ccList == 0 then
            for _, row in ipairs(others) do
                if #ccList < TOP_N and HEALER_CAPABLE[row.classToken or ""] then
                    ccList[#ccList + 1] = { name = row.name, classToken = row.classToken, likely = true }
                end
            end
        end
    end

    local function FormatRow(row)
        local shortName = row.name and row.name:match("^[^-]+") or "?" -- display only; full Name-Realm kept in the row
        local cls = row.classToken
            and (row.classToken:sub(1, 1) .. row.classToken:sub(2):lower()) or "?"
        return shortName .. " (" .. cls .. (row.likely and ", likely" or "") .. ")"
    end

    -- One advisory line — CMD-6's callout button will send this via GetChatType();
    -- until the gate clears, /bgthreat prints it locally.
    function ThreatProvider.GetAdvisoryLine()
        if #ccList == 0 and #killList == 0 then
            return "no enemy scoreboard data yet (enter a BG; rankings build over the first minutes)"
        end
        local parts = {}
        if #ccList > 0 then
            local names = {}
            for i, row in ipairs(ccList) do names[i] = FormatRow(row) end
            parts[#parts + 1] = "CC: " .. table.concat(names, ", ")
        end
        if #killList > 0 then
            local names = {}
            for i, row in ipairs(killList) do names[i] = FormatRow(row) end
            parts[#parts + 1] = "KILL: " .. table.concat(names, ", ")
        end
        return table.concat(parts, " | ")
    end

    function ThreatProvider.Start()
        if ticker then return end
        -- Resolve the scoreboard-request API at call time (BG entry, long after
        -- load). Passing this straight to NewTicker crashed when it was nil
        -- ("bad argument #2"); resolve + guard + wrap so it can't anymore.
        local RequestScores = RequestBattlefieldScoreData
            or (C_PvP and C_PvP.RequestBattlefieldScoreData)
        if not RequestScores then
            Titan_Debug.Out(ADDON_ID, "Events", "ThreatProvider: no RequestBattlefieldScoreData API on this flavor")
            return
        end
        if not eventFrame then
            eventFrame = CreateFrame("Frame")
            eventFrame:SetScript("OnEvent", Rebuild)
        end
        eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
        ticker = C_Timer.NewTicker(POLL_SECONDS, function() RequestScores() end)
        RequestScores()
        Titan_Debug.Out(ADDON_ID, "Events", "ThreatProvider started")
    end

    function ThreatProvider.Stop()
        if not ticker then return end
        ticker:Cancel()
        ticker = nil
        eventFrame:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
        wipe(ccList)
        wipe(killList)
        Titan_Debug.Out(ADDON_ID, "Events", "ThreatProvider stopped")
    end
end

-- Debug surface for the verification session (registered in CLAUDE.md globals):
-- prints locally, never sends to chat.
SLASH_TITANBGGENERALTHREAT1 = "/bgthreat"
SlashCmdList["TITANBGGENERALTHREAT"] = function()
    print("|cffeda55fBG General|r " .. ThreatProvider.GetAdvisoryLine())
end

-- ******************************** Analytics Recorder (VERIF-1 scaffold) *******************************
-- Passive in-game data recorder for closing the open research gates (scoreboard
-- shape, AB POI decode, WSG flag patterns, Era instance IDs — Epic 1.6). Raw
-- events land in TitanBgGeneralSaved.Analytics.log keyed by category;
-- /bganalytics prints a per-category summary after the session. Off by default
-- so it never records uninvited — flip with `/bganalytics on`. VERIF-2..6 feed
-- it by calling Analytics.Record(category, entry) unconditionally on their
-- events; Record is a no-op while disabled.
local Analytics = {}
do
    -- Lazily ensure the SavedVariables slot exists, then return it. SavedVariables
    -- are loaded before this file runs, so an upgrading player's existing data
    -- (if any) is preserved; a fresh install gets the default shape here.
    local function store()
        local s = TitanBgGeneralSaved.Analytics
        if type(s) ~= "table" then
            s = { enabled = false, log = {} }
            TitanBgGeneralSaved.Analytics = s
        end
        if type(s.log) ~= "table" then s.log = {} end
        return s
    end

    function Analytics.IsEnabled()
        return store().enabled == true
    end

    function Analytics.SetEnabled(on)
        store().enabled = on and true or false
    end

    -- Append one timestamped entry under a named category. No-op when disabled
    -- so callers (VERIF-2..6) can fire unconditionally on their events.
    function Analytics.Record(category, entry)
        if not Analytics.IsEnabled() then return end
        local s = store()
        local cat = s.log[category]
        if not cat then
            cat = {}
            s.log[category] = cat
        end
        cat[#cat + 1] = { t = time(), data = entry }
    end

    function Analytics.Clear()
        store().log = {}
    end

    function Analytics.PrintReport()
        local s = store()
        local state = s.enabled and "|cff00ff00on|r" or "|cffff0000off|r"
        print("|cffeda55fBG General|r analytics recorder: " .. state)
        local any = false
        for category, entries in pairs(s.log) do
            any = true
            print(("  %s: %d entr%s"):format(category, #entries, #entries == 1 and "y" or "ies"))
        end
        if not any then
            print("  no data recorded yet" .. (s.enabled and "" or " — enable with /bganalytics on"))
        end
        print("  commands: /bganalytics [on | off | clear | panel]")
    end
end

-- ******************************** Dev Panel (VERIF-7) *******************************
-- One/two-press control surface for the verification recorder, so a session
-- never needs typed slash commands mid-match. Opened with `/bganalytics panel`.
-- Buttons drive the Analytics module (reused, not reimplemented); future VERIF
-- items add their capture/snapshot buttons here. Dev-only — deliberately not
-- wired into the player-facing Titan menu, and held in a local so it adds no
-- global. Native WoW look: DialogBox backdrop + UIPanelButtonTemplate buttons.
local DevPanel = {}
do
    local frame, statusFS

    -- Persisted under the already-registered TitanBgGeneralSaved table:
    -- { point, relativePoint, xOfs, yOfs, shown } — position + last open/close state.
    local function PanelStore()
        local s = TitanBgGeneralSaved.devPanel
        if type(s) ~= "table" then
            s = {}
            TitanBgGeneralSaved.devPanel = s
        end
        return s
    end

    local function TotalEntries()
        local s = TitanBgGeneralSaved.Analytics
        local total = 0
        if s and type(s.log) == "table" then
            for _, entries in pairs(s.log) do total = total + #entries end
        end
        return total
    end

    local function Refresh()
        if not frame then return end
        local on = Analytics.IsEnabled()
        statusFS:SetText(("Recorder: %s     Entries: %d"):format(
            on and "|cff00ff00ON|r" or "|cffff0000OFF|r", TotalEntries()))
    end

    local function Build()
        local pad, btnW, btnH, gap = 12, 180, 24, 6
        local headerH = 16 + 6 + 14 + 10  -- title + gap + status + gap

        frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        frame:SetSize(btnW + pad * 2, 100) -- height finalised after layout
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
            local s = PanelStore()
            s.point, s.relativePoint, s.xOfs, s.yOfs = point, relativePoint, xOfs, yOfs
        end)
        -- Persist open/close so a /reload restores the panel as the user left it
        frame:SetScript("OnShow", function() PanelStore().shown = true end)
        frame:SetScript("OnHide", function() PanelStore().shown = false end)

        -- Restore saved position, else center
        local pos = PanelStore()
        if pos.point then
            frame:ClearAllPoints()
            frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.xOfs, pos.yOfs)
        else
            frame:SetPoint("CENTER")
        end
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 4,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0, 0, 0, 1)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", frame, "TOP", 0, -pad)
        title:SetText("|cffeda55fBG General — Dev|r")

        statusFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusFS:SetPoint("TOP", title, "BOTTOM", 0, -6)

        local y = -(pad + headerH)
        local function AddButton(text, onClick)
            local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            b:SetSize(btnW, btnH)
            b:SetPoint("TOP", frame, "TOP", 0, y)
            b:SetText(text)
            b:SetScript("OnClick", onClick)
            y = y - (btnH + gap)
            return b
        end

        -- Toggles the recorder gate (same as /bganalytics on|off); state shown in the status line
        AddButton("Toggle BG Analytics", function()
            Analytics.SetEnabled(not Analytics.IsEnabled())
            Refresh()
        end)
        AddButton("Clear Log",     function() Analytics.Clear(); Refresh() end)
        AddButton("Print Report",  function() Analytics.PrintReport() end)
        AddButton("Reload UI",     function() ReloadUI() end)
        AddButton("Close",         function() frame:Hide() end)

        frame:SetHeight(-y + pad - gap)
        -- Frame is created already shown, before OnShow was attached, so record it
        PanelStore().shown = true
    end

    function DevPanel.Toggle()
        if not frame then
            Build()
            Refresh()
            return -- Build leaves the frame shown
        end
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
            Refresh()
        end
    end

    -- Called on load/zone: reopen the panel only if it was open at last /reload
    function DevPanel.RestoreIfOpen()
        if not PanelStore().shown then return end
        if not frame then
            Build()
            Refresh()
        else
            frame:Show()
            Refresh()
        end
    end
end

-- Recorder control surface (registered in CLAUDE.md globals): prints locally,
-- never sends to chat. No arg = report; on/off toggles the gate; clear wipes;
-- panel opens the dev button panel (VERIF-7).
SLASH_TITANBGGENERALANALYTICS1 = "/bganalytics"
SlashCmdList["TITANBGGENERALANALYTICS"] = function(msg)
    local arg = (msg or ""):lower():match("^%s*(%S*)")
    if arg == "on" then
        Analytics.SetEnabled(true)
        print("|cffeda55fBG General|r analytics recorder |cff00ff00enabled|r")
    elseif arg == "off" then
        Analytics.SetEnabled(false)
        print("|cffeda55fBG General|r analytics recorder |cffff0000disabled|r")
    elseif arg == "clear" then
        Analytics.Clear()
        print("|cffeda55fBG General|r analytics log cleared")
    elseif arg == "panel" then
        DevPanel.Toggle()
    else
        Analytics.PrintReport()
    end
end

-- ******************************** Build AB Grid *******************************
local function BuildAbGrid(parent, size, hGap, vGap)
    local cols, rows = 5, 6

    local cellActions = {}
    for row = 1, rows do
        cellActions[row] = {}
        for col = 1, cols do
            cellActions[row][col] = {
                default = "INC",
                shift   = "DEF with",
                ctrl    = "HELP with",
                alt     = "SAFE",
            }
        end
    end

    for col = 1, cols do
        for row = 1, rows do
            local abbr     = select(col, "ST", "GM", "BS", "LM", "FM")
            local fullName = nodeAbbrToName[abbr]
            local btn      = CreateFrame("Button", nil, parent)
            btn:SetSize(size, size)
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", (col - 1) * (size + hGap), -(row - 1) * (size + vGap))

            local iconTex = nodeIcons[fullName]
            if iconTex then
                local icon = btn:CreateTexture(nil, "BACKGROUND")
                icon:SetTexture(iconTex)
                icon:SetAllPoints(btn)
                icon:SetAlpha(0.75)
            end

            local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
            label:SetText(abbr)
            label:SetPoint("CENTER", btn, "CENTER")
            label:SetWidth(size)

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(UIParent, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText(
                    "|cff00ff00(Click)|r |cffffffff"       .. cellActions[row][col].default .. " " .. row .. " or more\n" ..
                    "|cff00ff00(Shift+Click)|r |cffffffff" .. cellActions[row][col].shift   .. " " .. row .. " or more\n" ..
                    "|cff00ff00(Ctrl+Click)|r |cffffffff"  .. cellActions[row][col].ctrl    .. " " .. row .. " or more\n" ..
                    "|cff00ff00(Alt+Click)|r |cffffffff"   .. cellActions[row][col].alt     .. "\n"
                )
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btn:SetScript("OnClick", function()
                local action
                if IsShiftKeyDown() then
                    action = cellActions[row][col].shift
                elseif IsControlKeyDown() then
                    action = cellActions[row][col].ctrl
                elseif IsAltKeyDown() then
                    action = cellActions[row][col].alt
                else
                    action = cellActions[row][col].default
                end
                SendChatMessage(row .. " " .. action .. " " .. fullName, GetChatType())
            end)
        end
    end
end

-- ******************************** Build Column Grid (WSG / AV) *******************************
-- Generic location-columns × action-rows grid; colDefs entries carry abbr/full/icon.
local function BuildColGrid(parent, size, hGap, vGap, colDefs, rowActions)
    for col = 1, #colDefs do
        local colData = colDefs[col]
        for row = 1, #rowActions do
            local rowAction = rowActions[row]
            local btn = CreateFrame("Button", nil, parent)
            btn:SetSize(size, size)
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT", (col - 1) * (size + hGap), -(row - 1) * (size + vGap))

            if colData.icon then
                local icon = btn:CreateTexture(nil, "BACKGROUND")
                icon:SetTexture(colData.icon)
                icon:SetAllPoints(btn)
                icon:SetAlpha(0.75)
            end

            local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
            label:SetText(rowAction)
            label:SetPoint("CENTER", btn, "CENTER")
            label:SetWidth(size)

            local msg_default = rowAction .. " " .. colData.full
            local msg_shift   = rowAction .. " " .. colData.full .. " NOW"
            local msg_ctrl    = "HELP " .. colData.full
            local msg_alt     = colData.full

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(UIParent, "ANCHOR_BOTTOMRIGHT")
                GameTooltip:SetText(
                    "|cff00ff00(Click)|r |cffffffff" .. msg_default .. "\n" ..
                    "|cff00ff00(Shift)|r |cffffffff"  .. msg_shift   .. "\n" ..
                    "|cff00ff00(Ctrl)|r |cffffffff"   .. msg_ctrl    .. "\n" ..
                    "|cff00ff00(Alt)|r |cffffffff"    .. msg_alt     .. "\n"
                )
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btn:SetScript("OnClick", function()
                local msg
                if IsShiftKeyDown() then
                    msg = msg_shift
                elseif IsControlKeyDown() then
                    msg = msg_ctrl
                elseif IsAltKeyDown() then
                    msg = msg_alt
                else
                    msg = msg_default
                end
                SendChatMessage(msg, GetChatType())
            end)
        end
    end
end

-- ******************************** Show / Hide / Toggle BG General Screen *******************************
local function HideBgGeneralScreen()
    if _G["BgGeneralWindow"] then
        _G["BgGeneralWindow"]:Hide()
        _G["BgGeneralWindow"] = nil
    end
end

local function ShowBgGeneralScreen()
    if _G["BgGeneralWindow"] then
        return
    end

    local abCols      = 5
    local rows        = 6
    local size        = 22
    local hGap, vGap  = 5, 5
    local pad         = 10
    local titleH      = 16
    local titleGap    = 4
    local tabH        = 22
    local tabGap      = 4

    local function gridWidth(nCols) return nCols * size + (nCols - 1) * hGap end

    -- Window is sized to the widest grid; narrower grids center within it
    local maxCols = math.max(abCols, #wsgCols, #avCols)
    local gridW   = gridWidth(maxCols)
    local gridH   = rows * size + (rows - 1) * vGap
    local totalW  = pad * 2 + gridW
    local totalH  = pad * 2 + titleH + titleGap + tabH + tabGap + gridH

    local frame = CreateFrame("Frame", "BgGeneralWindow", UIParent, "BackdropTemplate")
    frame:SetSize(totalW, totalH)
    frame:SetMovable(true)
    frame:EnableMouse(true)

    if TitanBgGeneralSaved.point then
        frame:ClearAllPoints()
        frame:SetPoint(TitanBgGeneralSaved.point, UIParent, TitanBgGeneralSaved.relativePoint, TitanBgGeneralSaved.xOfs, TitanBgGeneralSaved.yOfs)
        Titan_Debug.Out(ADDON_ID, "Flow", "Restored BgGeneralWindow position")
    else
        frame:SetPoint("CENTER")
        Titan_Debug.Out(ADDON_ID, "Flow", "Set BgGeneralWindow position to CENTER (default)")
    end

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 4,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    -- Title bar — drag handle; OnMouseDown/Up avoids the ClearAllPoints jump that broke dragging
    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetHeight(titleH)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  pad, -pad)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
    titleBar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            frame:StartMoving()
        end
    end)
    titleBar:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            frame:StopMovingOrSizing()
            local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
            TitanBgGeneralSaved.point         = point
            TitanBgGeneralSaved.relativePoint = relativePoint
            TitanBgGeneralSaved.xOfs          = xOfs
            TitanBgGeneralSaved.yOfs          = yOfs
        end
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetText("|cffeda55fBG General|r  ·  drag here")
    titleText:SetPoint("CENTER", titleBar, "CENTER")

    -- Tab buttons
    local tabOffsetY = -pad - titleH - titleGap
    local tabW = (gridW - 2 * 4) / 3

    local tabAB = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAB:SetSize(tabW, tabH)
    tabAB:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, tabOffsetY)
    tabAB:SetText("AB")

    local tabWSG = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabWSG:SetSize(tabW, tabH)
    tabWSG:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + tabW + 4, tabOffsetY)
    tabWSG:SetText("WSG")

    local tabAV = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAV:SetSize(tabW, tabH)
    tabAV:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 2 * (tabW + 4), tabOffsetY)
    tabAV:SetText("AV")

    -- Grid containers (each sized to its own grid, centered in the window)
    local gridOffsetY = tabOffsetY - tabH - tabGap

    local abContainer = CreateFrame("Frame", nil, frame)
    abContainer:SetSize(gridWidth(abCols), gridH)
    abContainer:SetPoint("TOP", frame, "TOP", 0, gridOffsetY)
    BuildAbGrid(abContainer, size, hGap, vGap)

    local wsgContainer = CreateFrame("Frame", nil, frame)
    wsgContainer:SetSize(gridWidth(#wsgCols), gridH)
    wsgContainer:SetPoint("TOP", frame, "TOP", 0, gridOffsetY)
    BuildColGrid(wsgContainer, size, hGap, vGap, wsgCols, wsgRowActions)
    wsgContainer:Hide()

    local avContainer = CreateFrame("Frame", nil, frame)
    avContainer:SetSize(gridWidth(#avCols), gridH)
    avContainer:SetPoint("TOP", frame, "TOP", 0, gridOffsetY)
    BuildColGrid(avContainer, size, hGap, vGap, avCols, avRowActions)
    avContainer:Hide()

    local function selectTab(container)
        abContainer:Hide()
        wsgContainer:Hide()
        avContainer:Hide()
        container:Show()
    end

    tabAB:SetScript("OnClick", function() selectTab(abContainer) end)
    tabWSG:SetScript("OnClick", function() selectTab(wsgContainer) end)
    tabAV:SetScript("OnClick", function() selectTab(avContainer) end)

    -- Auto-select the tab for the battleground we're standing in
    local bgContainers = { AB = abContainer, WSG = wsgContainer, AV = avContainer }
    local activeBg = GetActiveBg()
    if activeBg and bgContainers[activeBg] then
        selectTab(bgContainers[activeBg])
    end

    _G["BgGeneralWindow"] = frame
end

local function ToggleBgGeneralScreen()
    if _G["BgGeneralWindow"] then
        HideBgGeneralScreen()
    else
        ShowBgGeneralScreen()
    end
end

---local Handle events registered to plugin
---@param button string
local function OnClick(_, button)
    if (button == "LeftButton") then
        ToggleBgGeneralScreen()
    end
end

-- ******************************** Create TitanBgGeneral Button *******************************
---local Create the Titan Panel button for the BG General addon
local function CreateTitanButton()
    if _G[TITAN_BUTTON_NAME] then
        return -- If already created, do nothing
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    local window = CreateFrame("Button", TITAN_BUTTON_NAME, frame, "TitanPanelComboTemplate")
    window:SetFrameStrata("FULLSCREEN")
    OnLoad(window)

    window:SetScript("OnShow", function(self)
        TitanPanelButton_OnShow(self);
    end)

    window:SetScript("OnClick", function(self, button)
        OnClick(self, button);
        TitanPanelButton_OnClick(self, button);
    end)
end

-- ******************************** Auto-open on BG entry *******************************
-- Fires after every loading screen (login, /reload, zoning); GetInstanceInfo()
-- is valid by then (see Research/bg-detection-reference.md). When the option is
-- off, the window is left entirely alone.
local autoOpenFrame = CreateFrame("Frame")
autoOpenFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
autoOpenFrame:SetScript("OnEvent", function()
    -- Refresh the Titan bar text (BG abbreviation) on every zone transition,
    -- independent of the auto-open option
    if _G[TITAN_BUTTON_NAME] then
        TitanPanelButton_UpdateButton(ADDON_ID)
    end

    -- ThreatProvider lifecycle: runs whenever we're in a BG, independent of
    -- the auto-open option (same gate the Node/Flag providers will use)
    if GetActiveBg() then
        ThreatProvider.Start()
    else
        ThreatProvider.Stop()
    end

    -- Dev panel: reopen across /reload if it was left open (position restored in Build)
    DevPanel.RestoreIfOpen()

    if not IsAutoOpenEnabled() then
        return
    end
    if GetActiveBg() then
        ShowBgGeneralScreen()
        Titan_Debug.Out(ADDON_ID, "Events", "Auto-opened BgGeneralWindow on BG entry")
    else
        HideBgGeneralScreen()
    end
end)

-- ******************************** Initialization *******************************
-- Check if Titan Panel's global ID exists before attempting to create frames
-- This ensures Titan Panel is loaded before we try to interact with it.
if TITAN_ID then
    Titan_Debug.Out(ADDON_ID, "Flow", "TitanBgGeneral: TITAN_ID found. Attempting to create button frame.")
    CreateTitanButton()
else
    -- If TITAN_ID is not immediately available, we might still be too early.
    -- This scenario is less likely with ##Dependencies, but good to be aware.
    Titan_Debug.Out(ADDON_ID, "Flow", "TitanBgGeneral: TITAN_ID not found at initial load. This addon might load before Titan Panel.")
    -- For robustness, you could add an ADDON_LOADED listener for "Titan" here
    -- if you consistently find TITAN_ID missing at this point.
    -- However, ##Dependencies: Titan in .toc should generally handle this.
end

