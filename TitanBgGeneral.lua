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
local dbg = Titan_Debug:New(ADDON_ID)
dbg:EnableDebug(true)
dbg:EnableTopic("Events", true)
dbg:EnableTopic("Flow", true)

-- ******************************** Variables *******************************
TitanBgGeneralSaved = TitanBgGeneralSaved or {}

local nodeIcons = {
    ["Stables"] = "Interface\\Icons\\Ability_Mount_RidingHorse",
    ["Gold Mine"] = "Interface\\Icons\\trade_mining",
    ["Blacksmith"] = "Interface\\Icons\\Trade_BlackSmithing",
    ["Lumber Mill"] = "Interface\\Icons\\INV_Crate_05",
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

-- Titan Panel registration
local function OnLoad(self)
    self.registry = {
        id = ADDON_ID,
        category = "Combat",
        version = VERSION,
        menuText = "Battleground General",
        buttonText = "Battleground General",
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

-- Toggle the main frame
local function ToggleBgGeneralScreen()
    -- Only show in battlegrounds/arenas
    --local inInst, instType = IsInInstance()
    --if not inInst or (instType ~= "pvp" and instType ~= "arena") then
    --    print("|cff99ccff[BgGeneral]|r You must be in a battleground or arena to use this.")
    --    return
    --end

    -- Hide if already shown
    if _G["BgGeneralWindow"] then
        _G["BgGeneralWindow"]:Hide()
        _G["BgGeneralWindow"] = nil
        return
    end
    
    local tooltipTimer
    local cols, rows = 5, 6
    local size = 22         -- square button size
    local hGap, vGap = 5, 5 -- spacing
    local pad = 10          -- padding around the grid

    local cellActions = {}
    
    for row = 1, rows do
        cellActions[row] = {}
        for col = 1, cols do
            cellActions[row][col] = 
            {
                default = "INC",
                shift = "DEF with",
                ctrl = "HELP with",
                alt = "SAFE"
            }
        end
    end    
    -- Create window
    local frame = CreateFrame("Frame", "BgGeneralWindow", UIParent, "BackdropTemplate")
    frame:SetSize(300, 300)

    -- Re-open at last position
    if TitanBgGeneralSaved.point then
        frame:SetPoint(TitanBgGeneralSaved.point, UIParent, TitanBgGeneralSaved.relativePoint, TitanBgGeneralSaved.xOfs, TitanBgGeneralSaved.yOfs)
        dbg:Out("Flow", "Restored BgGeneralWindow position to " .. tostring(TitanBgGeneralSaved.point) .. ", " .. tostring(TitanBgGeneralSaved.relativePoint) .. ", " .. tostring(TitanBgGeneralSaved.xOfs) .. ", " .. tostring(TitanBgGeneralSaved.yOfs))
    else
        frame:SetPoint("CENTER")
        dbg:Out("Flow", "Set BgGeneralWindow position to CENTER (default)")
    end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    
    frame:SetScript("OnDragStart", function(self)
        self:ClearAllPoints()
        self:StartMoving()
    end)
        
    frame:SetScript("OnDragStop", function(self)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        TitanBgGeneralSaved.point = point
        TitanBgGeneralSaved.relativePoint = relativePoint
        TitanBgGeneralSaved.xOfs = xOfs
        TitanBgGeneralSaved.yOfs = yOfs
    end)
    
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 4,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    -- compute & apply window size
    local totalW = pad * 2 + cols * size + (cols - 1) * hGap
    local totalH = pad * 2 + rows * size + (rows - 1) * vGap
    frame:SetSize(totalW, totalH)

    for col = 1, cols do
        for row = 1, rows do
            local idx = (row - 1) * cols + col
            local abbr = select(col, "ST", "GM", "BS", "LM", "FM")
            local fullName = nodeAbbrToName[abbr]
            local btn = CreateFrame("Button", "BgGenIconBtn" .. idx, frame)
            btn:SetSize(size, size)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + (col - 1) * (size + hGap), -pad - (row - 1) * (size + vGap))

            -- Add icon (always visible)
            local iconTex = nodeIcons[fullName]
            if iconTex then
                local icon = btn:CreateTexture(nil, "BACKGROUND")
                icon:SetTexture(iconTex)
                icon:SetAllPoints(btn)
                icon:SetAlpha(0.75)
            end

            -- Add label
            local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
            label:SetText(abbr or "")
            label:SetPoint("CENTER", btn, "CENTER")
            label:SetWidth(size)

            -- Tooltip scripts
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(UIParent, "ANCHOR_BOTTOMRIGHT")
                -- Determine tooltip text based on actions
                GameTooltip:SetText("|cff00ff00(Click)|r |cffffffff" .. cellActions[row][col].default .. " " .. row .. " or more\n" ..
                                    "|cff00ff00(Shift+Click)|r |cffffffff" ..cellActions[row][col].shift .. " ".. row .. " or more\n" ..
                                    "|cff00ff00(Ctrl+Click)|r |cffffffff" ..cellActions[row][col].ctrl .. " ".. row .. " or more\n" ..
                                    "|cff00ff00(Alt+Click)|r |cffffffff" ..cellActions[row][col].alt .. "\n")
                GameTooltip:Show()
            end)     
            btn:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

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

    -- register the frame so Toggle can hide it
    _G["BgGeneralWindow"] = frame
end

---local Handle events registered to plugin. Copies coordinates to chat line for shift-LeftClick
---@param self Button
---@param button string
local function OnClick(self, button)
    if (button == "LeftButton") then
        ToggleBgGeneralScreen()
    elseif (button == "RightButton") then
        BgGeneralTexturePicker()
    end
end

-- ******************************** Create TitanBgGeneral Button *******************************
---local Create the Titan Panel button for the Weapon Skills addon
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
    dbg:Out("Flow", "TitanWeaponSkills: TITAN_ID found. Attempting to create button frame.")
    CreateTitanButton()
else
    -- If TITAN_ID is not immediately available, we might still be too early.
    -- This scenario is less likely with ##Dependencies, but good to be aware.
    dbg:Out("Flow", "TitanWeaponSkills: TITAN_ID not found at initial load. This addon might load before Titan Panel.")
    -- For robustness, you could add an ADDON_LOADED listener for "Titan" here
    -- if you consistently find TITAN_ID missing at this point.
    -- However, ##Dependencies: Titan in .toc should generally handle this.
end

