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
-- bare `/bgthreat` prints locally; `/bgthreat announce` calls the deadliest
-- enemies to BG chat (same action as the Intel panel's Announce Threats button).
SLASH_TITANBGGENERALTHREAT1 = "/bgthreat"
SlashCmdList["TITANBGGENERALTHREAT"] = function(msg)
    if msg and msg:lower():match("announce") then
        if IntelPanel and IntelPanel.AnnounceThreats then IntelPanel.AnnounceThreats() end
        return
    end
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

    -- Replace a category with a single latest entry — for snapshot-style data
    -- (full roster, CLEU threat aggregate) that should stay one row, not grow.
    function Analytics.ReplaceLatest(category, entry)
        if not Analytics.IsEnabled() then return end
        store().log[category] = { { t = time(), data = entry } }
    end

    function Analytics.Clear()
        store().log = {}
    end

    -- Latest entry's data for a snapshot category (e.g. cleu_threat), or nil.
    function Analytics.GetLatest(category)
        local cat = store().log[category]
        if cat and cat[#cat] then return cat[#cat].data end
        return nil
    end

    -- Live disk export. WoW Lua is sandboxed (no io.*) and SavedVariables only
    -- flush on /reload or logout — but the chat log (LoggingChat) writes to
    -- Logs/WoWChatLog.txt in near-real-time. So with live export on we enable
    -- chat logging and emit compact, prefixed lines a tool reads WITHOUT a
    -- reload. Low frequency by design (state changes + summaries, never the
    -- per-tick roster) so it doesn't flood the chat frame.
    local LIVE_PREFIX = "[TBG]"
    function Analytics.IsLiveExport()
        return store().liveExport == true
    end
    function Analytics.SetLiveExport(on)
        on = on and true or false
        store().liveExport = on
        -- Turning it on also turns on chat logging (the disk channel); we never
        -- turn LoggingChat off — the player may rely on it for their own logs.
        if on and LoggingChat and not LoggingChat() then LoggingChat(true) end
    end
    -- Emit one line to the chat log (via the default frame, which IS written to
    -- WoWChatLog.txt). No-op unless live export is armed.
    function Analytics.Emit(line)
        if not Analytics.IsLiveExport() then return end
        print(LIVE_PREFIX .. " " .. line)
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

-- ResolveRole (defined with the live intel far below) is forward-declared here so
-- the Nemesis dossier can classify a STORED record's role from the very same
-- behaviour logic the live panel uses — one source of truth, no duplicated
-- heuristic. Assigned (not re-localised) at its definition site.
local ResolveRole

-- ******************************** Nemesis DB (CMD-9) *******************************
-- Permanent cross-match record of the deadliest opponents, under
-- TitanBgGeneralSaved.nemeses (survives logout — distinct from the per-match
-- cleu_threat snapshot). Fed at match end from the CLEU aggregate (peak damage/
-- healing per name); read on BG entry to pre-mark known nemeses with the skull
-- before this match's combat data builds.
local Nemesis = {}
do
    local NEMESIS_DMG  = 15000 -- peak damage in a match that earns a standing skull
    local NEMESIS_HEAL = 10000 -- peak ally-healing (healOthers) that earns a healer skull (INTEL-1); calibrated on live data 2026-07-04 (a non-healer never reaches 10k ally-healing)
    local MAX_ENTRIES  = 300   -- cap; prune least-recently-seen beyond this
    local function store()
        local s = TitanBgGeneralSaved.nemeses
        if type(s) ~= "table" then s = {}; TitanBgGeneralSaved.nemeses = s end
        return s
    end

    -- Merge a match's CLEU threat table (keyed by name) into the permanent DB.
    function Nemesis.Record(threat)
        if type(threat) ~= "table" then return end
        local db, now = store(), time()
        for name, e in pairs(threat) do
            if name and ((e.damage or 0) > 0 or (e.healing or 0) > 0) then
                local rec = db[name] or {}
                rec.class = e.classToken or rec.class
                rec.dmg   = math.max(rec.dmg or 0, e.damage or 0)
                rec.heal  = math.max(rec.heal or 0, e.healing or 0)
                -- INTEL-1: keep the role signal (peaks per channel) so ResolveRole
                -- can recover healer/caster/melee from the stored record later.
                rec.healOthers  = math.max(rec.healOthers or 0, e.healOthers or 0)
                rec.magicDamage = math.max(rec.magicDamage or 0, e.magicDamage or 0)
                rec.physDamage  = math.max(rec.physDamage or 0, e.physDamage or 0)
                rec.met   = (rec.met or 0) + 1
                rec.last  = now
                db[name]  = rec
            end
        end
        -- Cap: drop the oldest-seen entries once over MAX_ENTRIES.
        local n = 0; for _ in pairs(db) do n = n + 1 end
        if n > MAX_ENTRIES then
            local arr = {}
            for k, v in pairs(db) do arr[#arr + 1] = { k = k, last = v.last or 0 } end
            table.sort(arr, function(a, b) return a.last < b.last end)
            for i = 1, n - MAX_ENTRIES do db[arr[i].k] = nil end
        end
    end

    function Nemesis.IsNemesis(name)
        local rec = name and store()[name]
        -- Deadly by damage OR by healing: a strong healer is a priority target
        -- too, and the damage-only gate used to forget them entirely (INTEL-1).
        return rec ~= nil and ((rec.dmg or 0) >= NEMESIS_DMG or (rec.healOthers or 0) >= NEMESIS_HEAL)
    end

    -- INTEL-1: the remembered dossier for a name, shaped like a live CLEU record
    -- so callers can run ResolveRole on it (role recall on sight) and read the
    -- accumulated peaks. nil when the name was never banked.
    function Nemesis.Lookup(name)
        local rec = name and store()[name]
        if not rec then return nil end
        return {
            name        = name,
            classToken  = rec.class,
            damage      = rec.dmg or 0,
            healing     = rec.heal or 0,
            -- Pass the role signal through as-is: nil (not 0) when a legacy record
            -- was banked before INTEL-1. ResolveRole keys "do I have school data?"
            -- off physDamage/magicDamage being non-nil; defaulting them to 0 here
            -- would force its new-record path and misread a healer as MELEE.
            healOthers  = rec.healOthers,
            magicDamage = rec.magicDamage,
            physDamage  = rec.physDamage,
            met         = rec.met or 0,
            last        = rec.last,
        }
    end

    function Nemesis.Clear() TitanBgGeneralSaved.nemeses = {}; print("|cffeda55fBG General|r nemesis DB cleared") end

    function Nemesis.Print()
        local arr = {}
        for k, v in pairs(store()) do arr[#arr + 1] = { name = k, v = v } end
        table.sort(arr, function(a, b) return (a.v.dmg or 0) > (b.v.dmg or 0) end)
        print(("|cffeda55fBG General|r nemeses: %d tracked (top by peak damage):"):format(#arr))
        for i = 1, math.min(15, #arr) do
            local r = arr[i]
            -- Classify the stored record with the same logic the live panel uses.
            local role = ResolveRole and (ResolveRole(Nemesis.Lookup(r.name), r.v.class)) or "?"
            print(("  %s  [%s]  dmg %d  heal %d  ho %d  met %d"):format(
                r.name:match("^[^-]+") or r.name, role,
                r.v.dmg or 0, r.v.heal or 0, r.v.healOthers or 0, r.v.met or 0))
        end
        if #arr == 0 then print("  (none yet)") end
    end
end

-- ******************************** Recorder capture hooks (VERIF-2/3) *******************************
-- Feeds the Analytics log from live events while in a BG. Every capture routes
-- through Analytics.Record (no-op when the recorder is off), so this is inert
-- unless the user armed it (/bganalytics on or the dev panel). Lifecycle is
-- driven from PLAYER_ENTERING_WORLD: Start on any pvp instance, Stop on leave.
local Recorder = {}
do
    local frame, active, scoreboardCaptured, snapshotTicker, poiBaselined
    local threat = {}  -- [name] = { name, classToken, damage, healing, heals }
    local lastPoi = {} -- [areaPoiID] = last-seen textureIndex, for change diffing

    -- Verified Era scoreboard positions (VERIF-3, 2026-06-14). damageDone(11)/
    -- healingDone(12) exist but are always 0 on Era — real numbers come from CLEU.
    local SB = {
        name = 1, killingBlows = 2, honorableKills = 3, deaths = 4, honorGained = 5,
        faction = 6, rank = 7, race = 8, classLoc = 9, classToken = 10,
        damageDone = 11, healingDone = 12,
    }

    -- SavedVariables only serialize primitives; keep values storable.
    local function storable(v)
        local t = type(v)
        if t == "string" or t == "number" or t == "boolean" then return v end
        return tostring(v)
    end

    -- VERIF-2: locale-independent zone IDs on BG entry. uiMapID/instanceMapID can
    -- be stale right after a loading screen, so this is called again at +3s.
    local function CaptureZone(delayed)
        if not Analytics.IsEnabled() then return end
        local name, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
        local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        Analytics.Record("zone", {
            delayed       = delayed and true or false,
            name          = name,
            instanceType  = instanceType,
            instanceMapID = instanceMapID,
            uiMapID       = uiMapID,
            recognizedBg  = GetActiveBg(),
        })
        if not delayed then
            Analytics.Emit(("zone %s bg=%s map=%s/%s"):format(
                tostring(name), tostring(GetActiveBg()), tostring(instanceMapID), tostring(uiMapID)))
        end
    end

    -- VERIF-3: full positional return shape of GetBattlefieldScore(1), once per
    -- session. select('#') preserves true arg count including embedded nils.
    local function CaptureScoreboardShape(...)
        local count = select("#", ...)
        local values = {}
        for i = 1, count do
            local v = select(i, ...)
            values[i] = { pos = i, type = type(v), value = storable(v) }
        end
        Analytics.Record("scoreboard_shape", {
            numScores = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0,
            count     = count,
            values    = values,
        })
    end

    -- CMD-8: decode every scoreboard row into a named-field roster (the full
    -- player list with locale-independent classToken + numeric faction).
    local function CaptureRoster()
        local n = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0
        if n < 1 or not GetBattlefieldScore then return end
        local players = {}
        for i = 1, n do
            local r = { GetBattlefieldScore(i) }
            local nm = r[SB.name]
            if nm then
                players[#players + 1] = {
                    name           = nm,
                    classToken     = type(r[SB.classToken]) == "string" and r[SB.classToken] or nil,
                    faction        = tonumber(r[SB.faction]),
                    killingBlows   = tonumber(r[SB.killingBlows]) or 0,
                    honorableKills = tonumber(r[SB.honorableKills]) or 0,
                    deaths         = tonumber(r[SB.deaths]) or 0,
                    damageDone     = tonumber(r[SB.damageDone]) or 0,  -- 0 on Era
                    healingDone    = tonumber(r[SB.healingDone]) or 0, -- 0 on Era
                }
            end
        end
        Analytics.ReplaceLatest("scoreboard_roster", {
            myFaction = (UnitFactionGroup("player") == "Horde") and 0 or 1,
            numScores = n,
            players   = players,
        })
    end

    -- CMD-8 / Spy technique: real damage & healing around the player from the
    -- combat log (the Era scoreboard reports 0). Aggregates per hostile player;
    -- heal events also flag healers, which the scoreboard can't on Era.
    local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
    local SCHOOL_PHYSICAL = 1 -- SCHOOL_MASK_PHYSICAL; anything else is a magic school
    local function enemyRec(name, guid)
        local e = threat[name]
        if not e then
            local _, classToken = GetPlayerInfoByGUID(guid)
            -- magic/phys split → caster vs melee; healOthers (heals on allies, not
            -- self) → real healer, excluding potion/healthstone/Drain-Life noise.
            -- See Research/spec-detection-research.md (behaviour-first role inference).
            e = { name = name, classToken = classToken, damage = 0, healing = 0, heals = 0,
                  healOthers = 0, magicDamage = 0, physDamage = 0 }
            threat[name] = e
        end
        return e
    end

    local function CleuEvent()
        if not Analytics.IsEnabled() then return end
        local info = { CombatLogGetCurrentEventInfo() }
        local sub, srcGUID, srcName, srcFlags, destGUID = info[2], info[4], info[5], info[6], info[8]
        if not (srcGUID and srcName and srcFlags) then return end
        if bit.band(srcFlags, HOSTILE) ~= HOSTILE then return end
        if strsub(srcGUID, 1, 6) ~= "Player" then return end -- enemy players only
        if sub == "SWING_DAMAGE" then
            local amt = tonumber(info[12]) or 0
            if amt > 0 then local e = enemyRec(srcName, srcGUID); e.damage = e.damage + amt; e.physDamage = e.physDamage + amt end
        elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE" then
            local amt = tonumber(info[15]) or 0
            if amt > 0 then
                local e = enemyRec(srcName, srcGUID)
                e.damage = e.damage + amt
                if (tonumber(info[14]) or 0) == SCHOOL_PHYSICAL then
                    e.physDamage = e.physDamage + amt
                else
                    e.magicDamage = e.magicDamage + amt
                end
            end
        elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
            local e = enemyRec(srcName, srcGUID)
            e.heals = e.heals + 1
            local amt = (tonumber(info[15]) or 0) - (tonumber(info[16]) or 0) -- effective heal
            if amt > 0 then
                e.healing = e.healing + amt
                if destGUID and destGUID ~= srcGUID then e.healOthers = e.healOthers + amt end
            end
        end
    end

    -- Snapshot the live CLEU aggregate into SavedVariables (replace-latest).
    local function CaptureThreat()
        local list = {}
        for _, e in pairs(threat) do list[#list + 1] = e end
        if #list > 0 then Analytics.ReplaceLatest("cleu_threat", { players = list }) end
    end

    -- Restore the live aggregate from the last snapshot — used on a /reload that
    -- lands back in the SAME match, so the gathered stats survive (they only reset
    -- on a genuinely new match or an explicit clear).
    local function RestoreThreat()
        local snap = Analytics.GetLatest and Analytics.GetLatest("cleu_threat")
        if not (snap and snap.players) then return end
        for _, e in ipairs(snap.players) do
            if e.name then
                threat[e.name] = {
                    name = e.name, classToken = e.classToken,
                    damage = e.damage or 0, healing = e.healing or 0, heals = e.heals or 0,
                    healOthers = e.healOthers or 0,
                    magicDamage = e.magicDamage or 0, physDamage = e.physDamage or 0,
                }
            end
        end
    end

    -- VERIF-4: AB node-state decode capture. On AREA_POIS_UPDATED in AB, read the
    -- map's POI list via C_AreaPoiInfo and log areaPoiID + name + textureIndex.
    -- Nodes are identified by areaPoiID (never the localized name); textureIndex
    -- encodes owner + assault state, which we decode from the captured diffs.
    -- The first capture logs the full baseline; later captures log only entries
    -- whose textureIndex changed — i.e. the state transitions to decode. Fills
    -- the Era decode table that unblocks AB-2..5.
    local function CapturePOIs()
        if not Analytics.IsEnabled() then return end
        if GetActiveBg() ~= "AB" then return end
        if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return end
        local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not uiMapID then return end
        local ids = C_AreaPoiInfo.GetAreaPOIForMap(uiMapID)
        if not ids then return end
        local list, changed = {}, {}
        for _, poiID in ipairs(ids) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, poiID)
            if info then
                -- atlasName drives state on retail (leftIcon/rightIcon), textureIndex
                -- on Era; capture both + the cap time left (minutes) per DBM-PvP.
                local entry = {
                    areaPoiID    = info.areaPoiID or poiID,
                    name         = info.name,
                    textureIndex = info.textureIndex,
                    atlasName    = info.atlasName,
                    timeLeft     = C_AreaPoiInfo.GetAreaPOITimeLeft and C_AreaPoiInfo.GetAreaPOITimeLeft(poiID) or nil,
                }
                -- State key = atlasName when present (retail), else textureIndex (Era).
                local stateKey = entry.atlasName or entry.textureIndex
                list[#list + 1] = entry
                if lastPoi[entry.areaPoiID] ~= stateKey then
                    changed[#changed + 1] = entry
                    lastPoi[entry.areaPoiID] = stateKey
                end
            end
        end
        if not poiBaselined then
            poiBaselined = true
            Analytics.Record("ab_poi", { uiMapID = uiMapID, baseline = true, pois = list })
            for _, e in ipairs(list) do
                Analytics.Emit(("poi base %s=%s"):format(tostring(e.name), tostring(e.textureIndex or e.atlasName)))
            end
        elseif #changed > 0 then
            Analytics.Record("ab_poi", { uiMapID = uiMapID, changed = changed })
            for _, e in ipairs(changed) do
                Analytics.Emit(("poi %s=%s"):format(tostring(e.name), tostring(e.textureIndex or e.atlasName)))
            end
        end
    end

    local function OnEvent(_, event)
        if event == "UPDATE_BATTLEFIELD_SCORE" then
            if not (GetNumBattlefieldScores and GetNumBattlefieldScores() >= 1) then return end
            if not scoreboardCaptured and Analytics.IsEnabled() then
                scoreboardCaptured = true
                CaptureScoreboardShape(GetBattlefieldScore(1))
            end
            CaptureRoster()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            CleuEvent()
        elseif event == "AREA_POIS_UPDATED" then
            CapturePOIs()
        end
    end

    -- Start/Stop are idempotent: PLAYER_ENTERING_WORLD fires several times per
    -- match, but we only arm once per BG session (active guard).
    function Recorder.Start()
        if active then return end
        active = true
        -- Dev default: auto-arm the recorder on every BG entry so a capture
        -- session never needs `/bganalytics on` first. Player-facing default is
        -- still off (Analytics scaffold) — strip this auto-arm at release, the
        -- same way the forced scriptErrors CVar gets stripped.
        Analytics.SetEnabled(true)
        -- ...and live-export to the chat log so data reaches the dev tool with no
        -- /reload (dev default — strip at release alongside the auto-arm).
        Analytics.SetLiveExport(true)
        scoreboardCaptured = false
        poiBaselined = false
        wipe(threat)
        wipe(lastPoi)

        -- Fresh log per match, but stats survive a /reload within the same match.
        -- Safety rule: only clear when we can POSITIVELY identify a different match
        -- — i.e. instanceMapID is valid AND differs from the stored marker. If the
        -- map ID is nil/stale (common for a beat after the post-reload loading
        -- screen), we NEVER clear; we restore. Destroying data on an ambiguous
        -- signal is the one outcome we must avoid. The marker is nilled in Stop on
        -- leaving, so a genuine new match (even same map) still clears.
        local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
        local s = TitanBgGeneralSaved.Analytics
        local newMatch = instanceMapID and s and s.activeMatchMap ~= instanceMapID
        if newMatch then
            Analytics.Clear()
        else
            -- Same match (or unknown map): bring the gathered CLEU stats back into
            -- the live table so they keep accumulating instead of starting at zero.
            RestoreThreat()
        end
        -- Only advance the marker on a confirmed map; never overwrite it with nil.
        if instanceMapID and s then
            s.activeMatchMap = instanceMapID
        end

        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", OnEvent)
        end
        frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        frame:RegisterEvent("AREA_POIS_UPDATED")
        CaptureZone(false)
        C_Timer.After(3, function() if active then CaptureZone(true) end end)
        CapturePOIs() -- baseline now; AREA_POIS_UPDATED may have fired pre-arm
        C_Timer.After(3, function() if active then CapturePOIs() end end)
        -- Periodically flush the CLEU aggregate AND poll the scoreboard so the
        -- roster/score streams fill without the user manually opening it: each
        -- request fires UPDATE_BATTLEFIELD_SCORE, which we capture. Resolve the
        -- request API once (global → C_PvP fallback; nil on some flavors → skip).
        local req = RequestBattlefieldScoreData or (C_PvP and C_PvP.RequestBattlefieldScoreData)
        snapshotTicker = C_Timer.NewTicker(5, function()
            CaptureThreat()
            if req then req() end
        end)
        if req then req() end
    end

    function Recorder.IsActive() return active == true end

    -- Live CLEU aggregate (real damage/healing + heal counts per enemy), keyed by
    -- name. Read-only view for the Intel overlay; scoreboard is 0 on Era so this
    -- is the only real damage/healing source. If the live table is empty (e.g.
    -- after a /reload outside a BG), serve the last on-disk snapshot so post-match
    -- stats stay viewable. A genuinely new match clears the snapshot in Start, so
    -- this never resurrects a previous match's data.
    function Recorder.GetThreat()
        if next(threat) == nil then RestoreThreat() end
        return threat
    end

    -- Explicit reset of the live aggregate (paired with Analytics.Clear so a
    -- "clear" wipes both the snapshot and what the Intel panel shows right now).
    function Recorder.ClearThreat() wipe(threat) end

    function Recorder.Stop()
        if not active then return end
        active = false
        if frame then
            frame:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE")
            frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            frame:UnregisterEvent("AREA_POIS_UPDATED")
        end
        if snapshotTicker then snapshotTicker:Cancel(); snapshotTicker = nil end
        CaptureThreat() -- final snapshot before the marker drops
        Nemesis.Record(threat) -- CMD-9: bank this match's enemies into the permanent DB

        -- Live-export a compact end-of-match summary (chat log → no /reload needed
        -- to see it): enemies tracked, top damage dealer, confirmed healers.
        if Analytics.IsLiveExport() then
            local healers, tracked, topName, topDmg = {}, 0, "?", 0
            for _, e in pairs(threat) do
                tracked = tracked + 1
                if (e.heals or 0) > 0 then healers[#healers + 1] = e.name:match("^[^-]+") or e.name end
                if (e.damage or 0) > topDmg then topDmg = e.damage; topName = e.name:match("^[^-]+") or e.name end
            end
            Analytics.Emit(("exit tracked=%d topdmg=%s(%d) healers=%s"):format(
                tracked, topName, topDmg, #healers > 0 and table.concat(healers, ",") or "none"))
        end
        -- Drop the match marker so re-entering the same BG counts as a new match
        if TitanBgGeneralSaved.Analytics then
            TitanBgGeneralSaved.Analytics.activeMatchMap = nil
        end
    end
end

-- Forward declarations for the single merged window — defined further down, but
-- referenced earlier by the dev controls (Close) and the /bganalytics handler.
local ShowBgGeneralScreen, HideBgGeneralScreen, ToggleBgGeneralScreen

-- ******************************** Dev Panel (VERIF-7) *******************************
-- One/two-press control surface for the verification recorder, so a session
-- never needs typed slash commands mid-match. Opened with `/bganalytics panel`.
-- Buttons drive the Analytics module (reused, not reimplemented); future VERIF
-- items add their capture/snapshot buttons here. Dev-only — deliberately not
-- wired into the player-facing Titan menu, and held in a local so it adds no
-- global. Native WoW look: DialogBox backdrop + UIPanelButtonTemplate buttons.
local DevPanel = {}
do
    local frame, statusFS, analyticsBtn
    local leds = {}  -- key -> { led, fs }

    local LED_ON  = "Interface\\COMMON\\Indicator-Green"
    local LED_OFF = "Interface\\COMMON\\Indicator-Gray"

    -- Live LED indicators: which capture streams are on / have data.
    local LED_DEFS = {
        { key = "rec",   label = "REC",   tip = "Recorder gate — green when analytics recording is enabled (/bganalytics on or the Toggle button)." },
        { key = "bg",    label = "BG",    tip = "Armed — green while you're inside a battleground (pvp instance); the recorder is live." },
        { key = "zone",  label = "ZONE",  tip = "Zone snapshot captured — instanceMapID + uiMapID logged for this match (VERIF-2)." },
        { key = "score", label = "SCORE", tip = "Scoreboard roster captured — full player list with classToken + faction. Open the scoreboard in-BG to populate (VERIF-3 / CMD-8)." },
        { key = "cleu",  label = "CLEU",  tip = "Combat-log threat captured — real damage/healing of nearby enemies; healers self-flag via heal events (CMD-8)." },
        { key = "poi",   label = "POI",   tip = "AB node POIs captured — areaPoiID + textureIndex snapshots that decode base owner / assault state. AB only (VERIF-4)." },
    }

    local function TotalEntries()
        local s = TitanBgGeneralSaved.Analytics
        local total = 0
        if s and type(s.log) == "table" then
            for _, entries in pairs(s.log) do total = total + #entries end
        end
        return total
    end

    -- Which LEDs are "active" right now (live recorder state + captured data).
    local function LedState()
        local s = TitanBgGeneralSaved.Analytics
        local log = (s and type(s.log) == "table") and s.log or {}
        local function has(cat) local e = log[cat]; return e ~= nil and #e > 0 end
        return {
            rec   = Analytics.IsEnabled(),
            bg    = Recorder.IsActive and Recorder.IsActive() or false,
            zone  = has("zone"),
            score = has("scoreboard_roster") or has("scoreboard_shape"),
            cleu  = has("cleu_threat"),
            poi   = has("ab_poi"),
        }
    end

    local function Refresh()
        if not frame then return end
        statusFS:SetText(("Entries: %d"):format(TotalEntries())) -- recorder state now shown by the REC LED
        if analyticsBtn then
            analyticsBtn:SetText(Analytics.IsEnabled() and "Record: ON" or "Record: OFF")
        end
        local st = LedState()
        for _, def in ipairs(LED_DEFS) do
            local p = leds[def.key]
            if p then
                local lit = st[def.key]
                p.led:SetTexture(lit and LED_ON or LED_OFF)
                p.led:SetAlpha(lit and 1 or 0.5)
                p.fs:SetTextColor(lit and 1 or 0.55, lit and 1 or 0.55, lit and 1 or 0.55)
            end
        end
    end

    -- Render the dev controls (status + LED row + button row) INTO a host frame,
    -- starting at host-relative y = topY. Returns the y below the section. The
    -- merged window owns the frame/backdrop/drag/ticker; this only draws children.
    function DevPanel.Populate(host, pad, topY)
        frame = host
        local width = host:GetWidth()
        local cellW, ledSize, cellGap = 34, 14, 2
        local rowW = #LED_DEFS * cellW + (#LED_DEFS - 1) * cellGap
        local y = topY

        local divider = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        divider:SetPoint("TOP", host, "TOP", 0, y)
        divider:SetText("|cff808080\226\128\148 dev \226\128\148|r")
        y = y - 16

        statusFS = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        statusFS:SetPoint("TOP", host, "TOP", 0, y)
        y = y - 16

        -- Live LED indicator row (glowing dot + tiny label), centered.
        local ledRow = CreateFrame("Frame", nil, host)
        ledRow:SetSize(rowW, ledSize + 11)
        ledRow:SetPoint("TOP", host, "TOP", 0, y)
        for i, def in ipairs(LED_DEFS) do
            local cell = CreateFrame("Frame", nil, ledRow)
            cell:SetSize(cellW, ledSize + 11)
            cell:SetPoint("LEFT", ledRow, "LEFT", (i - 1) * (cellW + cellGap), 0)
            cell:EnableMouse(true)
            local led = cell:CreateTexture(nil, "ARTWORK")
            led:SetSize(ledSize, ledSize)
            led:SetPoint("TOP", cell, "TOP", 0, 0)
            led:SetTexture(LED_OFF)
            local fs = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
            fs:SetPoint("TOP", led, "BOTTOM", 0, -1)
            fs:SetText(def.label)
            leds[def.key] = { led = led, fs = fs }

            cell:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(def.label, 1, 0.82, 0)
                GameTooltip:AddLine(def.tip, 1, 1, 1, true)
                local lit = LedState()[def.key]
                GameTooltip:AddLine(lit and "Active" or "Inactive",
                    lit and 0.1 or 0.7, lit and 1 or 0.7, lit and 0.1 or 0.7)
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        y = y - (ledSize + 11) - 6

        -- Button row (compact, horizontal so the merged window stays short).
        -- The recorder toggle ("rec") shows live ON/OFF state, set in Refresh.
        local btns = {
            { key = "rec",    onClick = function() Analytics.SetEnabled(not Analytics.IsEnabled()); Refresh() end },
            { key = "Clear",  onClick = function() Analytics.Clear(); Recorder.ClearThreat() end },
            { key = "Report", onClick = function() Analytics.PrintReport() end },
            { key = "Reload", onClick = function() ReloadUI() end },
            { key = "Close",  onClick = function() HideBgGeneralScreen() end },
        }
        local bgap, bh = 4, 22
        local bw = math.floor((width - pad * 2 - (#btns - 1) * bgap) / #btns)
        for i, b in ipairs(btns) do
            local btn = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
            btn:SetSize(bw, bh)
            btn:SetPoint("TOPLEFT", host, "TOPLEFT", pad + (i - 1) * (bw + bgap), y)
            btn:SetScript("OnClick", b.onClick)
            if b.key == "rec" then
                analyticsBtn = btn -- text set live in Refresh ("Record: ON"/"Record: OFF")
            else
                btn:SetText(b.key)
            end
        end
        y = y - bh

        return y
    end

    -- Public refresh, called by the merged window's ticker.
    DevPanel.Refresh = Refresh
end

-- Recorder control surface (registered in CLAUDE.md globals): prints locally,
-- never sends to chat. No arg = report; on/off toggles the gate; clear wipes;
-- panel opens the dev button panel (VERIF-7).
-- Forward declaration: the Live Intel overlay is defined later (it needs the
-- stats/intel helpers), but this slash handler and the BG-entry hook reference it.
local IntelPanel

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
        Recorder.ClearThreat()
        print("|cffeda55fBG General|r analytics log cleared")
    elseif arg == "panel" or arg == "intel" then
        -- Both now open the single merged window (callouts + intel + dev).
        if ToggleBgGeneralScreen then ToggleBgGeneralScreen() end
    elseif arg == "nemesis" then
        if (msg or ""):lower():match("clear") then Nemesis.Clear() else Nemesis.Print() end
    else
        Analytics.PrintReport()
    end
end

-- Forward-declared (defined with the live-stats block below) so the AB callout
-- can enrich its message with the clicked node's live owner / capture state.
local GetAbNodeStates

-- AB-4: live node-state suffix appended to an AB callout. Plain ASCII (chat-safe,
-- no "|"); shows the owner, or "<faction> capping M:SS" while contested.
local function AbCalloutSuffix(abbr)
    if GetActiveBg() ~= "AB" then return "" end
    local s = GetAbNodeStates and GetAbNodeStates()[abbr]
    if not s then return "" end
    if s.contested then
        local who = (s.owner == "A") and "Alliance" or "Horde"
        local t = s.remain or 0
        return (" - %s capping %d:%02d"):format(who, math.floor(t / 60), t % 60)
    elseif s.owner then
        return (s.owner == "A") and " - Alliance held" or " - Horde held"
    end
    return " - neutral"
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
                SendChatMessage(row .. " " .. action .. " " .. fullName .. AbCalloutSuffix(abbr), GetChatType())
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

-- ******************************** Live BG stats (AB) *******************************
-- Read-only live readouts for the main window footer. Sourced from confirmed APIs:
-- node ownership via C_AreaPoiInfo (textureIndex decoded with DBM-PvP's Era table),
-- resources via the classic AB score widgets (1893/1894), player counts from the
-- scoreboard the recorder already polls. All locale-independent (no name matching).
local ALLY_COLOR  = "|cff4d88ff" -- Alliance blue
local HORDE_COLOR = "|cffff4d4d" -- Horde red
local MUTE_COLOR  = "|cff808080"

-- DBM-PvP PvPGeneral.lua icons table, Classic-Era AB nodes (Mine/Lumber/Blacksmith/
-- Farm/Stables). 1=ally contested, 2=ally controlled, 3=horde contested, 4=horde
-- controlled. Identify state by textureIndex — never the localized node name.
local AB_NODE_STATE = {
    [17] = 1, [18] = 2, [19] = 3, [20] = 4, -- Mine
    [22] = 1, [23] = 2, [24] = 3, [25] = 4, -- Lumber Mill
    [27] = 1, [28] = 2, [29] = 3, [30] = 4, -- Blacksmith
    [32] = 1, [33] = 2, [34] = 3, [35] = 4, -- Farm
    [37] = 1, [38] = 2, [39] = 3, [40] = 4, -- Stables
}

local function GetAbBaseCounts()
    local out = { ally = 0, horde = 0, contested = 0, total = 0, ready = false }
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return out end
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not uiMapID then return out end
    local ids = C_AreaPoiInfo.GetAreaPOIForMap(uiMapID)
    if not ids then return out end
    for _, poiID in ipairs(ids) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, poiID)
        local st = info and AB_NODE_STATE[info.textureIndex]
        if not st and info and info.atlasName then -- retail fallback
            if info.atlasName:find("leftIcon") then st = 2
            elseif info.atlasName:find("rightIcon") then st = 4 end
        end
        if st then
            out.total = out.total + 1
            if st == 2 then out.ally = out.ally + 1
            elseif st == 4 then out.horde = out.horde + 1
            else out.contested = out.contested + 1 end
        end
    end
    out.ready = out.total > 0
    return out
end

-- AB-2: per-node ownership for the node-state strip, keyed by grid abbreviation
-- (ST/GM/BS/LM/FM). textureIndex decodes both node and state (VERIF-4 confirmed):
-- node = floor((ti-16)/5), state = (ti-16)%5 → 0 neutral, 1 A-contested,
-- 2 A-controlled, 3 H-contested, 4 H-controlled. owner = the controlling (or, when
-- contested, the assaulting) faction; contested = an assault is in progress.
local AB_NODE_BY_INDEX = { [0] = "GM", [1] = "LM", [2] = "BS", [3] = "FM", [4] = "ST" }
local AB_CAP_SECONDS = 64       -- Era capture time (VERIF-4 / DBM-PvP): contested → controlled
local abAssaultAt = {}          -- [abbr] = GetTime() first seen contested (Era has no real timeLeft)
-- (forward-declared above BuildAbGrid so the AB callout can enrich with node state)
function GetAbNodeStates()
    local states = {}
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and C_AreaPoiInfo.GetAreaPOIInfo) then return states end
    local uiMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not uiMapID then return states end
    local ids = C_AreaPoiInfo.GetAreaPOIForMap(uiMapID)
    if not ids then return states end
    for _, poiID in ipairs(ids) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, poiID)
        local ti = info and info.textureIndex
        if ti and ti >= 16 and ti <= 40 then
            local abbr  = AB_NODE_BY_INDEX[math.floor((ti - 16) / 5)]
            local state = (ti - 16) % 5
            if abbr then
                local owner, contested
                if     state == 1 then owner, contested = "A", true
                elseif state == 2 then owner = "A"
                elseif state == 3 then owner, contested = "H", true
                elseif state == 4 then owner = "H" end
                states[abbr] = { owner = owner, contested = contested or false, state = state }
            end
        end
    end
    -- Derive a capture countdown for contested nodes (timed from first sighting).
    local now = GetTime()
    for abbr, s in pairs(states) do
        if s.contested then
            if not abAssaultAt[abbr] then abAssaultAt[abbr] = now end
            s.remain = math.max(0, math.ceil(AB_CAP_SECONDS - (now - abAssaultAt[abbr])))
        else
            abAssaultAt[abbr] = nil
        end
    end
    return states
end

-- AB-5: rule-based advice line from live base control. On-screen only (colour
-- codes ok). Priority: stop an enemy cap → catch up when behind → hold when
-- ahead → grab a third when even. Returns a string, or nil (not AB / no data).
local function GetAbAdvice()
    if GetActiveBg() ~= "AB" then return nil end
    local states = GetAbNodeStates()
    if not next(states) then return nil end
    local mine   = (UnitFactionGroup("player") == "Alliance") and "A" or "H"
    local theirs = (mine == "A") and "H" or "A"
    local ours, them, enemyNode = 0, 0, nil
    local capNode, capRemain = nil, math.huge
    for abbr, s in pairs(states) do
        if s.contested then
            if s.owner == theirs and (s.remain or 99) < capRemain then -- enemy capping → urgent
                capNode, capRemain = abbr, s.remain or 0
            end
        elseif s.owner == mine then
            ours = ours + 1
        elseif s.owner == theirs then
            them = them + 1
            enemyNode = enemyNode or abbr
        end
    end
    local function nm(abbr) return nodeAbbrToName[abbr] or abbr end
    if capNode then
        return ("|cffff2020DEFEND %s - enemy capping %d:%02d!|r"):format(nm(capNode), math.floor(capRemain / 60), capRemain % 60)
    end
    if ours < them then
        return ("|cffffd100Behind %d-%d - attack %s|r"):format(ours, them, enemyNode and nm(enemyNode) or "a base")
    end
    if ours > them and ours >= 3 then
        return ("|cff33ff33Ahead %d-%d - hold & defend|r"):format(ours, them)
    end
    if ours == them then
        return ("|cffffffffEven %d-%d - grab a 3rd base|r"):format(ours, them)
    end
    return ("|cffffffff%d-%d - press the advantage|r"):format(ours, them)
end

-- Classic AB resource totals from the icon-and-text score widgets (DBM-PvP: 1893
-- Alliance, 1894 Horde; text is "current/max"). nil when the widgets are absent.
local function GetAbResources()
    local W = C_UIWidgetManager
    if not (W and W.GetIconAndTextWidgetVisualizationInfo) then return nil end
    local a = W.GetIconAndTextWidgetVisualizationInfo(1893)
    local h = W.GetIconAndTextWidgetVisualizationInfo(1894)
    if not (a and h and a.text and h.text) then return nil end
    return tonumber(a.text:match("(%d+)")), tonumber(h.text:match("(%d+)"))
end

-- Alliance/Horde headcount from the scoreboard (faction is return #6: 0=Horde,
-- 1=Alliance — numeric, locale-independent). The recorder already polls it.
local function GetPlayerCounts()
    local ally, horde = 0, 0
    local n = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0
    if n > 0 and GetBattlefieldScore then
        for i = 1, n do
            local faction = select(6, GetBattlefieldScore(i))
            if faction == 1 then ally = ally + 1
            elseif faction == 0 then horde = horde + 1 end
        end
    end
    return ally, horde
end

-- Era healing-capable classes (no spec detection on Era — class is the prior).
-- A live heal event (CLEU) upgrades this to a confirmed healer.
local HEALER_CAPABLE = { PRIEST = true, PALADIN = true, DRUID = true, SHAMAN = true }

-- CMD-7: Classic Era (1.12 balance) class-vs-class advice, keyed by classToken.
-- Ported from Research/classic-class-matchup-reference.md. favored = you're
-- favoured (ENGAGE); avoid = you're countered (AVOID); anything absent =
-- Neutral/contested → no call (false precision is worse than silence). Soft duel
-- logic — a live healer flag overrides it ("CC, don't chase"); see the reference
-- for BG modifiers (pocket healers, WOTF, consumables).
local MATCHUP = {
    WARRIOR = { favored = { "PRIEST", "SHAMAN", "DRUID" },            avoid = { "MAGE", "WARLOCK", "ROGUE" } },
    PALADIN = { favored = { "ROGUE", "WARLOCK" },                     avoid = { "MAGE", "HUNTER" } },
    HUNTER  = { favored = { "PALADIN", "PRIEST" },                    avoid = { "WARLOCK" } },
    ROGUE   = { favored = { "PRIEST", "WARRIOR", "SHAMAN" },          avoid = { "PALADIN" } },
    PRIEST  = { favored = { "MAGE", "DRUID" },                        avoid = { "WARRIOR", "ROGUE", "HUNTER" } },
    SHAMAN  = { favored = { "MAGE" },                                 avoid = { "WARRIOR", "WARLOCK", "ROGUE" } },
    MAGE    = { favored = { "WARRIOR", "PALADIN" },                   avoid = { "WARLOCK", "PRIEST", "SHAMAN", "DRUID" } },
    WARLOCK = { favored = { "WARRIOR", "MAGE", "SHAMAN", "DRUID", "HUNTER" }, avoid = { "PALADIN" } },
    DRUID   = { favored = { "MAGE" },                                 avoid = { "WARRIOR", "PRIEST", "WARLOCK" } },
}

-- Engage/Avoid call on one enemy for the player's class. A confirmed healer
-- overrides the matrix (CC them, don't duel). Returns "ENGAGE"/"AVOID"/"CC" or
-- nil (Neutral — render as nothing). myClass is resolved lazily + cached.
local _playerClass
local function EngageAdvice(enemyClassToken, isHealerConfirmed)
    if isHealerConfirmed then return "CC" end
    if not _playerClass then _, _playerClass = UnitClass("player") end
    local m = _playerClass and MATCHUP[_playerClass]
    if not (m and enemyClassToken) then return nil end
    for _, c in ipairs(m.favored) do if c == enemyClassToken then return "ENGAGE" end end
    for _, c in ipairs(m.avoid)   do if c == enemyClassToken then return "AVOID"  end end
    return nil
end

-- Behaviour-first role inference (Research/spec-detection-research.md): exact spec
-- is unobtainable for BG enemies on Era, so we classify ROLE from what the CLEU
-- aggregate has actually seen. Returns role, healerFlag (CC priority + sort),
-- confirmed (saw it, not a guess).
--   HEAL  — heals allies more than they damage  (kills the "any heal = healer" bug)
--   CASTER/MELEE — by which damage school dominates, once they've dealt damage
--   heal? — healer-capable class with no combat evidence yet (class prior)
--   DPS   — non-healer class, no evidence yet
function ResolveRole(t, classToken)
    local dmg = (t and t.damage) or 0
    if t and (t.physDamage ~= nil or t.magicDamage ~= nil) then
        -- New record: full behaviour data (ally-heal + magic/phys split).
        if (t.healOthers or 0) > 0 and (t.healOthers or 0) >= dmg then
            return "HEAL", true, true
        end
        if dmg > 0 then
            if (t.magicDamage or 0) > (t.physDamage or 0) then return "CASTER", false, false end
            return "MELEE", false, false
        end
    elseif t then
        -- Legacy snapshot (pre-upgrade): only totals — use healing dominance,
        -- class-guarded so a potion-popping warrior isn't called a healer. Can't
        -- tell caster vs melee without the school split, so DPS.
        if (t.healing or 0) > 0 and (t.healing or 0) >= dmg and HEALER_CAPABLE[classToken or ""] then
            return "HEAL", true, true
        end
        if dmg > 0 then return "DPS", false, false end
    end
    if HEALER_CAPABLE[classToken or ""] then
        return "heal?", true, false
    end
    return "DPS", false, false
end

-- Ranked enemy intel for the live dev overlay. Merges the scoreboard (class,
-- killing blows, deaths, faction — locale-independent positions) with the CLEU
-- aggregate (real damage/healing + role, the only such source on Era). Danger
-- order: healers first (CC priority), then real damage, then killing blows.
-- Returns the enemy faction's players only.
local function GetEnemyIntel()
    local myFaction = (UnitFactionGroup("player") == "Horde") and 0 or 1
    local threat = (Recorder.GetThreat and Recorder.GetThreat()) or {}
    local n = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0
    local list = {}
    if GetBattlefieldScore then
        for i = 1, n do
            -- 1 name, 2 KBs, 3 HKs, 4 deaths, 5 honor, 6 faction, ... 10 classToken
            local name, kb, _, deaths, _, faction = GetBattlefieldScore(i)
            local classToken = select(10, GetBattlefieldScore(i))
            if name and faction and faction ~= myFaction then
                -- Live combat record if we've fought them this match; otherwise
                -- fall back to the remembered dossier so role + advice show ON
                -- SIGHT from the name alone (INTEL-1). Damage/healing columns stay
                -- live-only (0 until they act this match) — memory drives the role.
                local live = threat[name]
                local t = live or Nemesis.Lookup(name)
                local role, healer, confirmed = ResolveRole(t, classToken)
                list[#list + 1] = {
                    name        = name,
                    classToken  = classToken,
                    kb          = kb or 0,
                    deaths      = deaths or 0,
                    damage      = (live and live.damage) or 0,
                    healing     = (live and live.healing) or 0,
                    role        = role,
                    healer      = healer,
                    confirmed   = confirmed,
                    remembered  = (not live) and t ~= nil or nil, -- role came from memory, not this match
                    advice      = EngageAdvice(classToken, confirmed),
                    nemesis     = Nemesis.IsNemesis(name), -- known heavy hitter / healer → skull on sight
                }
            end
        end
    end
    -- Post-match / left the BG: the scoreboard empties, so fall back to the
    -- retained CLEU aggregate (enemies-only by construction) so the stats stay
    -- viewable after the match. KB/deaths come from the scoreboard, so they read
    -- 0 here — damage/healing/role are the meaningful post-match numbers.
    if #list == 0 then
        for _, t in pairs(threat) do
            local role, healer, confirmed = ResolveRole(t, t.classToken)
            list[#list + 1] = {
                name       = t.name,
                classToken = t.classToken,
                kb         = 0,
                deaths     = 0,
                damage     = t.damage or 0,
                healing    = t.healing or 0,
                role       = role,
                healer     = healer,
                confirmed  = confirmed,
                advice     = EngageAdvice(t.classToken, confirmed),
                nemesis    = Nemesis.IsNemesis(t.name),
            }
        end
    end
    table.sort(list, function(a, b)
        if a.healer ~= b.healer then return a.healer end       -- healers to the top
        if a.damage ~= b.damage then return a.damage > b.damage end
        return a.kb > b.kb
    end)
    -- Flag the single deadliest (most damage dealt) so the panel can mark it with
    -- a skull — the "this one kicked our ass" enemy.
    local top, topDmg = nil, 0
    for _, e in ipairs(list) do
        if (e.damage or 0) > topDmg then topDmg = e.damage; top = e end
    end
    if top and topDmg > 0 then top.deadliest = true end
    return list
end

-- ******************************** Live Intel overlay (dev) *******************************
-- A large, movable dev overlay that follows the live battle in real time: base
-- control, resources, headcount, and a danger-ranked enemy table (class-coloured,
-- healers flagged). Deliberately a SEPARATE window so it can never break the
-- player-facing main panel. Dev-only: auto-shown on BG entry, toggled with
-- `/bganalytics intel`. Position + open state persist under TitanBgGeneralSaved.
-- (IntelPanel is forward-declared above for the slash handler / BG-entry hook.)
IntelPanel = {}
do
    local frame, summaryFS
    local headerCells, rowCells = {}, {}
    local MAX_ROWS = 15 -- AB is 15v15; enough to list the whole enemy team
    local LINE_H = 14

    -- True columns: one FontString per cell, fixed width + justify, so the table
    -- aligns regardless of the proportional game font (space-padding can't).
    local COLS = {
        { key = "mark", w = 20,  just = "CENTER", head = "" },  -- row icons (skull, …)
        { key = "num",  w = 22,  just = "RIGHT", head = "#" },
        { key = "name", w = 132, just = "LEFT",  head = "Enemy" },
        { key = "role", w = 60,  just = "LEFT",  head = "Role" },
        { key = "vs",   w = 52,  just = "LEFT",  head = "You" },
        { key = "dmg",  w = 56,  just = "RIGHT", head = "Dmg" },
        { key = "heal", w = 56,  just = "RIGHT", head = "Heal" },
        { key = "kb",   w = 32,  just = "RIGHT", head = "KB" },
        { key = "d",    w = 26,  just = "RIGHT", head = "D" },
    }
    local COL_GAP = 4
    local function ColX(c) -- left offset of column c (after the frame pad)
        local x = 0
        for j = 1, c - 1 do x = x + COLS[j].w + COL_GAP end
        return x
    end

    local function ClassColorCode(classToken)
        local c = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
        if c and c.colorStr then return "|c" .. c.colorStr end
        if c then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
        return "|cffffffff"
    end

    -- Role label + colour, driven by ResolveRole's classification.
    local ROLE_DISPLAY = {
        HEAL     = "|cff33ffffHEAL|r",              -- confirmed healer (cyan caps)
        ["heal?"] = "|cff66ccccheal?|r",            -- class-prior guess (lowercase + ?)
        CASTER   = "|cffcc99ffCASTER|r",            -- magic-school DPS (arcane purple)
        MELEE    = "|cffff9933MELEE|r",             -- physical DPS (orange)
        DPS      = "|cffbbbbbbDPS|r",               -- unknown, no evidence yet
    }
    local function RoleText(e) return ROLE_DISPLAY[e.role] or ROLE_DISPLAY.DPS end

    -- CMD-7 engage/avoid call (MATCHUP, healer-overridden). Neutral = nothing.
    local ADVICE_DISPLAY = {
        ENGAGE = "|cff33ff33Engage|r", -- you're favoured
        AVOID  = "|cffff3333Avoid|r",  -- you're countered
        CC     = "|cff33ffffCC|r",     -- healer — control, don't chase
    }
    local function AdviceText(e) return (e.advice and ADVICE_DISPLAY[e.advice]) or "|cff555555·|r" end

    -- Compact human number: 12345 -> 12.3k, keeps the column narrow at scale.
    local function ShortNum(n)
        n = n or 0
        if n >= 10000 then return ("%.0fk"):format(n / 1000) end
        if n >= 1000  then return ("%.1fk"):format(n / 1000) end
        return tostring(n)
    end
    local function NumCell(n) return (n and n > 0) and ShortNum(n) or "|cff555555-|r" end

    -- Marker column (leftmost): row icons. Skull = the deadliest enemy today;
    -- more markers (FC, target, assist…) slot in here later, keeping names aligned.
    local SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:13:13:0:0|t"
    local function MarkText(e)
        -- skull for this match's deadliest OR a known nemesis (CMD-9, on sight)
        if e.deadliest or e.nemesis then return SKULL end
        return ""
    end

    local function CellText(e, key, i)
        if key == "mark" then return MarkText(e) end
        if key == "num"  then return tostring(i) end
        if key == "name" then
            return ClassColorCode(e.classToken) .. (e.name:match("^[^-]+") or e.name) .. "|r"
        end
        if key == "role" then return RoleText(e) end
        if key == "vs"   then return AdviceText(e) end
        if key == "dmg"  then return NumCell(e.damage) end
        if key == "heal" then return NumCell(e.healing) end
        if key == "kb"   then return tostring(e.kb) end
        if key == "d"    then return tostring(e.deaths) end
        return ""
    end

    local function Refresh()
        if not frame or not frame:IsShown() then return end
        local intel = GetEnemyIntel()
        local healerCount = 0
        for _, e in ipairs(intel) do if e.healer then healerCount = healerCount + 1 end end
        if GetActiveBg() == "AB" then
            local b = GetAbBaseCounts()
            local aRes, hRes = GetAbResources()
            local aP, hP = GetPlayerCounts()
            summaryFS:SetFormattedText(
                "Bases %sA %d|r %sH %d|r%s   Res %s%s|r/%s%s|r   Players %s%d|r/%s%d|r   Enemies %d (|cff33ffff%d heal|r)",
                ALLY_COLOR, b.ally, HORDE_COLOR, b.horde,
                b.contested > 0 and ("|cffffd100 ("..b.contested.." c)|r") or "",
                ALLY_COLOR, aRes and tostring(aRes) or "?", HORDE_COLOR, hRes and tostring(hRes) or "?",
                ALLY_COLOR, aP, HORDE_COLOR, hP, #intel, healerCount)
        elseif #intel > 0 then
            -- Post-match (or left the BG): keep the last battle's stats on screen.
            summaryFS:SetFormattedText(
                "|cffffd100Post-match|r — last battle stats   Enemies %d (|cff33ffff%d heal|r)   (KB/D from scoreboard unavailable)",
                #intel, healerCount)
        else
            summaryFS:SetText(MUTE_COLOR .. "No stored battle stats yet — enter a battleground.|r")
        end
        for c, col in ipairs(COLS) do headerCells[c]:SetText(#intel > 0 and ("|cffeda55f" .. col.head .. "|r") or "") end
        for i = 1, MAX_ROWS do
            local e = intel[i]
            local cells = rowCells[i]
            for c, col in ipairs(COLS) do
                cells[c]:SetText(e and CellText(e, col.key, i) or "")
            end
        end
    end

    local function ClassLabel(token)
        if not token then return "?" end
        return token:sub(1, 1) .. token:sub(2):lower()
    end

    -- CMD-6: call the deadliest enemies to chat. KILL = top CLEU damage dealers;
    -- CC = healers (confirmed via heal events, or class-prior, marked "?"). Sent
    -- on the right channel via GetChatType (INSTANCE_CHAT in a BG). Plain text —
    -- colour codes don't render for other players.
    function IntelPanel.AnnounceThreats()
        local intel = GetEnemyIntel()
        local dps, heals = {}, {}
        for _, e in ipairs(intel) do
            if e.healer and #heals < 3 then
                heals[#heals + 1] = (e.name:match("^[^-]+") or e.name) .. (e.confirmed and "" or "?")
            elseif (e.damage or 0) > 0 then
                dps[#dps + 1] = e
            end
        end
        table.sort(dps, function(a, b) return a.damage > b.damage end)
        local kill = {}
        for i = 1, math.min(3, #dps) do
            local e = dps[i]
            -- {skull} is a chat raid-target token (renders as the icon, chat-safe);
            -- crown the #1 damage dealer with it.
            kill[i] = (i == 1 and "{skull}" or "")
                .. (e.name:match("^[^-]+") or e.name)
                .. " (" .. ClassLabel(e.classToken) .. " " .. ShortNum(e.damage) .. ")"
        end
        local parts = {}
        if #kill > 0  then parts[#parts + 1] = "KILL: " .. table.concat(kill, ", ") end
        if #heals > 0 then parts[#parts + 1] = "CC heal: " .. table.concat(heals, ", ") end
        if #parts == 0 then
            print("|cffeda55fBG General|r No enemy threat data yet — fight near them and it builds.")
            return
        end
        -- Separate groups with " // ", NOT " | " — a bare "|" is read as a chat
        -- escape code and SendChatMessage rejects it ("Invalid escape code").
        SendChatMessage("Enemy threats >> " .. table.concat(parts, " // "), GetChatType())
    end

    -- Width needed for the table = pad + last column's right edge + pad.
    function IntelPanel.Width(pad)
        return pad * 2 + ColX(#COLS) + COLS[#COLS].w
    end

    -- Render the intel section (summary + table + Announce) INTO a host frame,
    -- starting at host-relative y = topY. Returns the y below the section so the
    -- caller can stack the dev section under it. The merged window owns the frame,
    -- backdrop, drag, position and the refresh ticker — this only draws children.
    function IntelPanel.Populate(host, pad, topY)
        frame = host

        summaryFS = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        summaryFS:SetPoint("TOPLEFT", host, "TOPLEFT", pad, topY)
        summaryFS:SetPoint("RIGHT", host, "RIGHT", -pad, 0)
        summaryFS:SetJustifyH("LEFT")

        local headerY = topY - 18
        for c, col in ipairs(COLS) do
            local fs = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", host, "TOPLEFT", pad + ColX(c), headerY)
            fs:SetWidth(col.w); fs:SetJustifyH(col.just); fs:SetWordWrap(false)
            headerCells[c] = fs
        end

        for i = 1, MAX_ROWS do
            local rowY = headerY - 14 - (i - 1) * LINE_H
            local cells = {}
            for c, col in ipairs(COLS) do
                local fs = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("TOPLEFT", host, "TOPLEFT", pad + ColX(c), rowY)
                fs:SetWidth(col.w); fs:SetJustifyH(col.just); fs:SetWordWrap(false)
                cells[c] = fs
            end
            rowCells[i] = cells
        end
        local rowsBottom = headerY - 14 - MAX_ROWS * LINE_H

        local announce = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
        announce:SetSize(160, 22)
        announce:SetPoint("TOP", host, "TOP", 0, rowsBottom - 2)
        announce:SetText("Announce Threats")
        announce:SetScript("OnClick", IntelPanel.AnnounceThreats)

        return rowsBottom - 2 - 22
    end

    -- Public refresh, called by the merged window's ticker.
    IntelPanel.Refresh = Refresh
end

-- ******************************** Show / Hide / Toggle BG General Screen *******************************
-- Single merged window (was three frames): callout grid with AB/WSG/AV tabs on
-- top, the live enemy-intel table in the middle, dev controls at the bottom.
-- IntelPanel/DevPanel render their sections into this frame via Populate(); this
-- owns the frame, backdrop, drag, position, and the one refresh ticker.
function HideBgGeneralScreen()
    if _G["BgGeneralWindow"] then
        _G["BgGeneralWindow"]:Hide()
        _G["BgGeneralWindow"] = nil
    end
    TitanBgGeneralSaved.shown = false
end

function ShowBgGeneralScreen()
    if _G["BgGeneralWindow"] then
        return
    end

    local rows        = 6
    local size        = 22
    local hGap, vGap  = 5, 5
    local pad         = 12
    local titleH      = 16
    local titleGap    = 4
    local tabH        = 22
    local tabGap      = 6
    local abCols      = 5

    local function gridWidth(nCols) return nCols * size + (nCols - 1) * hGap end
    local maxCols = math.max(abCols, #wsgCols, #avCols)
    local gridW   = gridWidth(maxCols)
    local gridH   = rows * size + (rows - 1) * vGap

    -- Window width is driven by the widest section: the intel table.
    local W        = IntelPanel.Width(pad)
    local gridLeft = (W - gridW) / 2

    local frame = CreateFrame("Frame", "BgGeneralWindow", UIParent, "BackdropTemplate")
    frame:SetSize(W, 200) -- height finalised after the sections are laid out
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)

    if TitanBgGeneralSaved.point then
        frame:ClearAllPoints()
        frame:SetPoint(TitanBgGeneralSaved.point, UIParent, TitanBgGeneralSaved.relativePoint, TitanBgGeneralSaved.xOfs, TitanBgGeneralSaved.yOfs)
    else
        frame:SetPoint("CENTER")
    end

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 4,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.85) -- semi-transparent (user preference)

    -- Title bar — drag handle; OnMouseDown/Up avoids the ClearAllPoints jump that broke dragging
    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetHeight(titleH)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  pad, -pad)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
    titleBar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartMoving() end
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

    -- Tab buttons (centered over the grid)
    local tabOffsetY = -pad - titleH - titleGap
    local tabW = (gridW - 2 * 4) / 3

    local tabAB = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAB:SetSize(tabW, tabH)
    tabAB:SetPoint("TOPLEFT", frame, "TOPLEFT", gridLeft, tabOffsetY)
    tabAB:SetText("AB")

    local tabWSG = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabWSG:SetSize(tabW, tabH)
    tabWSG:SetPoint("TOPLEFT", frame, "TOPLEFT", gridLeft + tabW + 4, tabOffsetY)
    tabWSG:SetText("WSG")

    local tabAV = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    tabAV:SetSize(tabW, tabH)
    tabAV:SetPoint("TOPLEFT", frame, "TOPLEFT", gridLeft + 2 * (tabW + 4), tabOffsetY)
    tabAV:SetText("AV")

    -- AB-2 node-state strip: one owner marker per AB column, in a band between the
    -- tabs and the grid. Shown only on the AB tab; live-updated from the POI decode.
    local stripH = 15
    local stripY = tabOffsetY - tabH - 4
    local gridOffsetY = stripY - stripH

    local abAbbrOrder = { "ST", "GM", "BS", "LM", "FM" } -- matches the AB grid columns
    local abStrip = CreateFrame("Frame", nil, frame)
    abStrip:SetAllPoints(frame) -- holder so the cells show/hide as one with the AB tab
    local abStripCells = {}
    for c = 1, abCols do
        local fs = abStrip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", gridLeft + (c - 1) * (size + hGap), stripY)
        fs:SetWidth(size)
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        abStripCells[c] = fs
    end
    -- AB-3: while a node is contested, show its ~64s capture countdown (from
    -- GetAbNodeStates' derived timer) in place of the owner letter, faction-
    -- coloured by who's capturing.
    local function RefreshAbStrip()
        if not abStrip:IsShown() then return end
        local states = GetAbNodeStates()
        for c, abbr in ipairs(abAbbrOrder) do
            local s = states[abbr]
            local txt = MUTE_COLOR .. "\226\128\148|r" -- em dash = neutral / no data
            if s and s.contested then
                local col = s.owner == "A" and ALLY_COLOR or HORDE_COLOR -- who's capturing
                txt = col .. (s.remain or 0) .. "|r"
            elseif s and s.owner then
                txt = (s.owner == "A" and ALLY_COLOR or HORDE_COLOR) .. s.owner .. "|r"
            end
            abStripCells[c]:SetText(txt)
        end
    end

    -- Grid containers (each sized to its own grid, centered in the window)
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
        if container == abContainer then abStrip:Show(); RefreshAbStrip() else abStrip:Hide() end
    end

    tabAB:SetScript("OnClick", function() selectTab(abContainer) end)
    tabWSG:SetScript("OnClick", function() selectTab(wsgContainer) end)
    tabAV:SetScript("OnClick", function() selectTab(avContainer) end)

    -- Auto-select the tab for the battleground we're standing in
    local bgContainers = { AB = abContainer, WSG = wsgContainer, AV = avContainer }
    local activeBg = GetActiveBg()
    selectTab((activeBg and bgContainers[activeBg]) or abContainer)

    -- AB-5 advice line (AB tab; blank otherwise), between the grid and the table.
    local gridBottom = gridOffsetY - gridH
    local adviceFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    adviceFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, gridBottom - 2)
    adviceFS:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    adviceFS:SetJustifyH("CENTER")
    local function RefreshAdvice() adviceFS:SetText(GetAbAdvice() or "") end

    -- Intel section (summary + enemy table + Announce) below the advice line; its
    -- summary already shows bases/resources/headcount, replacing the old footer.
    local intelBottom = IntelPanel.Populate(frame, pad, gridBottom - 2 - 18)

    -- Dev section (status + LEDs + buttons) below the intel table.
    local devBottom   = DevPanel.Populate(frame, pad, intelBottom - 6)

    frame:SetHeight(-devBottom + pad)

    -- One ticker drives both live sections.
    frame:SetScript("OnUpdate", function(self, elapsed)
        self._acc = (self._acc or 0) + elapsed
        if self._acc >= 0.5 then
            self._acc = 0
            IntelPanel.Refresh()
            DevPanel.Refresh()
            RefreshAbStrip()
            RefreshAdvice()
        end
    end)
    IntelPanel.Refresh()
    DevPanel.Refresh()
    RefreshAbStrip()
    RefreshAdvice()

    TitanBgGeneralSaved.shown = true
    _G["BgGeneralWindow"] = frame
end

function ToggleBgGeneralScreen()
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

    -- Recorder lifecycle (VERIF-2/3): arm on ANY pvp instance — including map IDs
    -- GetActiveBg() doesn't recognise yet — so the zone snapshot can close the
    -- Era ID gaps. Inert unless the recorder is armed (gated in Analytics.Record).
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "pvp" then
        Recorder.Start()
    else
        Recorder.Stop()
    end

    -- Single merged window: auto-open on BG entry (if the option is on), else
    -- restore it across a /reload if it was left open. The intel + dev sections
    -- ride along inside it, so there are no separate panels to restore anymore.
    if GetActiveBg() then
        if IsAutoOpenEnabled() then
            ShowBgGeneralScreen()
            Titan_Debug.Out(ADDON_ID, "Events", "Auto-opened BgGeneralWindow on BG entry")
        end
    elseif TitanBgGeneralSaved.shown then
        ShowBgGeneralScreen() -- reopen where the user left it (out of BG)
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

