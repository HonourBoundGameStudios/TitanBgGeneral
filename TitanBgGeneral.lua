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
TitanBgGeneralSaved = {}

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

-- ******************************** GetTooltipText *******************************
-- Function to generate the tooltip text when hovering over the button
-- This function will be called by Titan Panel to display detailed information.
function GetTooltipText()
    return "Battleground General Addon\nTracks your battleground stats and performance."
end

-- Create a small movable window with two buttons
local function ToggleBgGeneralScreen()

    if _G["BgGeneralWindow"] then
        _G["BgGeneralWindow"]:Hide()
        _G["BgGeneralWindow"] = nil
        return
    end
    
    -- Detect which battleground the player is in
    local inInstance, instanceType = IsInInstance()
    
    dbg:Out("Flow", "ToggleBgGeneralScreen: inInstance=" .. tostring(inInstance) .. ", instanceType=" .. tostring(instanceType))
    
    local frame = CreateFrame("Frame", "BgGeneralWindow", UIParent, "BackdropTemplate")
    frame:SetSize(320, 200)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    -- Button 1
    local btn1 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn1:SetSize(80, 22)
    btn1:SetPoint("TOPLEFT", 20, -20)
    btn1:SetText("Button 1")
    btn1:SetScript("OnClick", function()
        print("Button 1 clicked")
    end)
    
    -- Close Button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        _G["BgGeneralWindow"] = nil
    end)
end

---local Handle events registered to plugin. Copies coordinates to chat line for shift-LeftClick
---@param self Button
---@param button string
local function OnClick(self, button)
    if (button == "LeftButton") then
        ToggleBgGeneralScreen()
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

