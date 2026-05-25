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

-- ******************************** PrepareBgGeneralMenu *******************************
---local Build the right-click dropdown menu (UIDropDownMenu scheme)
local function PrepareBgGeneralMenu()
    TitanPanelRightClickMenu_AddTitle(TitanPlugins[ADDON_ID].menuText)

    local level = TitanPanelRightClickMenu_GetDropdownLevel()

    TitanPanelRightClickMenu_AddToggleIcon(ADDON_ID, level)
    TitanPanelRightClickMenu_AddToggleRightSide(ADDON_ID, level)
    TitanPanelRightClickMenu_AddSpacer()
    TitanPanelRightClickMenu_AddHide(ADDON_ID, level)
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

-- ******************************** Build WSG Grid *******************************
local function BuildWsgGrid(parent, size, hGap, vGap)
    for col = 1, #wsgCols do
        local colData = wsgCols[col]
        for row = 1, #wsgRowActions do
            local rowAction = wsgRowActions[row]
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

-- ******************************** Toggle BG General Screen *******************************
local function ToggleBgGeneralScreen()
    if _G["BgGeneralWindow"] then
        _G["BgGeneralWindow"]:Hide()
        _G["BgGeneralWindow"] = nil
        return
    end

    local cols, rows  = 5, 6
    local size        = 22
    local hGap, vGap  = 5, 5
    local pad         = 10
    local titleH      = 16
    local titleGap    = 4
    local tabH        = 22
    local tabGap      = 4

    local gridW  = cols * size + (cols - 1) * hGap
    local gridH  = rows * size + (rows - 1) * vGap
    local totalW = pad * 2 + gridW
    local totalH = pad * 2 + titleH + titleGap + tabH + tabGap + gridH

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
    local tabW = (gridW - 4) / 2

    local tabAB = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAB:SetSize(tabW, tabH)
    tabAB:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, tabOffsetY)
    tabAB:SetText("AB")

    local tabWSG = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabWSG:SetSize(tabW, tabH)
    tabWSG:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + tabW + 4, tabOffsetY)
    tabWSG:SetText("WSG")

    -- Grid containers
    local gridOffsetY = tabOffsetY - tabH - tabGap

    local abContainer = CreateFrame("Frame", nil, frame)
    abContainer:SetSize(gridW, gridH)
    abContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, gridOffsetY)
    BuildAbGrid(abContainer, size, hGap, vGap)

    local wsgContainer = CreateFrame("Frame", nil, frame)
    wsgContainer:SetSize(gridW, gridH)
    wsgContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, gridOffsetY)
    BuildWsgGrid(wsgContainer, size, hGap, vGap)
    wsgContainer:Hide()

    tabAB:SetScript("OnClick", function()
        abContainer:Show()
        wsgContainer:Hide()
    end)
    tabWSG:SetScript("OnClick", function()
        abContainer:Hide()
        wsgContainer:Show()
    end)

    -- Auto-select tab based on current zone
    local zone = GetRealZoneText() or GetZoneText() or ""
    if zone:find("Warsong") then
        abContainer:Hide()
        wsgContainer:Show()
    end

    _G["BgGeneralWindow"] = frame
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

