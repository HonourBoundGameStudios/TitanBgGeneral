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

