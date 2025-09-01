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

--[[ 
   BgGeneral: A tiny movable window with one‐click callouts 
   slash: /bgcomm 
--]]

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

    -- Create window
    local frame = CreateFrame("Frame", "BgGeneralWindow", UIParent, "BackdropTemplate")
    frame:SetSize(300, 300)

    print("TitanBgGeneralSaved:", TitanBgGeneralSaved.point, TitanBgGeneralSaved.relativePoint, TitanBgGeneralSaved.xOfs, TitanBgGeneralSaved.yOfs)

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
        dbg:Out("Flow", "Saved BgGeneralWindow position to " .. tostring(point) .. ", " .. tostring(relativePoint) .. ", " .. tostring(xOfs) .. ", " .. tostring(yOfs))
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 4,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    -- 1) map node → icon texture
    local nodeIcons = {
        ["Stables"] = "Interface\\Icons\\Ability_Mount_RidingHorse",
        ["Gold Mine"] = "Interface\\Icons\\trade_mining",
        ["Blacksmith"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Lumber Mill"] = "Interface\\Icons\\INV_Crate_05",
        ["Farm"] = "Interface\\Icons\\INV_Misc_Food_Wheat_01"
    }

    -- 2) grid settings (6×6)
    local cols, rows = 6, 6
    local size = 16      -- square button size
    local hGap, vGap = 5, 5    -- spacing
    local pad = 10      -- padding around the grid

    -- compute & apply window size
    local totalW = pad * 2 + cols * size + (cols - 1) * hGap
    local totalH = pad * 2 + rows * size + (rows - 1) * vGap
    frame:SetSize(totalW, totalH)

    -- convenience to pick BG chat
    local function GetChatType()
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            return "INSTANCE_CHAT"
        elseif IsInRaid() then
            return "RAID"
        elseif IsInGroup() then
            return "PARTY"
        else
            return "SAY"
        end
    end

    -- 3) build 6×6 icon buttons
    for col = 1, cols do
        for row = 1, rows do
            local idx = (row - 1) * cols + col
            local nodeName = select(col, "Stables", "Gold Mine", "Blacksmith", "Lumber Mill", "Farm")
            local btn = CreateFrame("Button", "BgGenIconBtn" .. idx, frame)
            local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("CENTER", btn, "BOTTOMRIGHT", 0, 0)
            label:SetText(tostring(row)) -- or any label you want
            btn.label = label

            local xOff = pad + (col - 1) * (size + hGap)
            local yOff = -pad - (row - 1) * (size + vGap)

            btn:SetSize(size, size)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", xOff, yOff)

            -- icon texture
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(btn)
            tex:SetTexture(nodeIcons[nodeName])

            -- border on hover
            btn:SetScript("OnEnter", function(self)
                self.highlight = self.highlight or self:CreateTexture(nil, "HIGHLIGHT")
                self.highlight:SetAllPoints()
                self.highlight:SetColorTexture(1, 1, 1, 0.25)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(row .. " inc " .. nodeName, 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function(self)
                if self.highlight then
                    self.highlight:Hide()
                end
                GameTooltip:Hide()
            end)

            -- send the callout when clicked
            btn:SetScript("OnClick", function()
                SendChatMessage(row .. " inc " .. nodeName, GetChatType())
            end)
        end
    end

    -- register the frame so Toggle can hide it
    _G["BgGeneralWindow"] = frame
end

-- Toggle the main frame
local function BgGeneralTexturePicker()
    -- Hide if already shown
    if _G["BgGeneralTexturePicker"] then
        _G["BgGeneralTexturePicker"]:Hide()
        _G["BgGeneralTexturePicker"] = nil
        return
    end

    -- Create window
    local frame = CreateFrame("Frame", "BgGeneralTexturePicker", UIParent, "BackdropTemplate")
    frame:SetSize(400, 300)
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
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)

    -- scroll frame with all icon textures in the game
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(360, 1000) -- arbitrary height, will be adjusted
    scrollFrame:SetScrollChild(content)
    local iconSize = 32
    local iconsPerRow = 10
    local iconCount = 0

    for i = 1, GetNumSpellTabs() do
        local tabName, texture, offset, numSpells = GetSpellTabInfo(i)
        for j = 1, numSpells do
            local spellIndex = offset + j
            local spellName, rank, icon = GetSpellInfo(spellIndex)
            if icon then
                iconCount = iconCount + 1
                local btn = CreateFrame("Button", nil, content)
                btn:SetSize(iconSize, iconSize)
                local col = (iconCount - 1) % iconsPerRow
                local row = math.floor((iconCount - 1) / iconsPerRow)
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", col * (iconSize + 5), -row * (iconSize + 5))
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints(btn)
                tex:SetTexture(icon)
                btn:SetScript("OnEnter", function(self)
                    self.highlight = self.highlight or self:CreateTexture(nil, "HIGHLIGHT")
                    self.highlight:SetAllPoints()
                    self.highlight:SetColorTexture(1, 1, 1, 0.25)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(spellName .. (rank and (" (" .. rank .. ")") or ""), 1, 1, 1)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function(self)
                    if self.highlight then
                        self.highlight:Hide()
                    end
                    GameTooltip:Hide()
                end)
                btn:SetScript("OnClick", function()
                    print("Icon texture path: " .. icon)
                end)
            end
        end
    end

    -- register the frame so Toggle can hide it
    _G["BgGeneralTexturePicker"] = frame
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

