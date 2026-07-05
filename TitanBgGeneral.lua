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

-- REL-1: callout channel preference. "AUTO" = the smart priority in GetChatType;
-- otherwise a preferred channel that GetChatType uses only when it's actually
-- usable (e.g. RAID only in a raid), falling back to AUTO so a bad setting can't
-- silently swallow a callout.
local CHANNEL_CHOICES = {
    { key = "AUTO",          label = "Auto (smart)" },
    { key = "INSTANCE_CHAT", label = "Instance / BG" },
    { key = "RAID",          label = "Raid" },
    { key = "PARTY",         label = "Party" },
    { key = "SAY",           label = "Say" },
}
local function GetChannelOverride()
    return TitanBgGeneralSaved.channelOverride or "AUTO"
end

-- REL-2: optional audio alerts on critical advisor events. Opt-in (default off).
local function AreSoundsEnabled()
    return TitanBgGeneralSaved.sounds == true
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

    -- REL-2: sound alerts toggle
    local snd = UIDropDownMenu_CreateInfo()
    snd.text = "Sound alerts"
    snd.isNotRadio = true
    snd.checked = AreSoundsEnabled()
    snd.func = function() TitanBgGeneralSaved.sounds = not AreSoundsEnabled() end
    UIDropDownMenu_AddButton(snd, level)

    -- REL-1: callout channel override (radio group)
    TitanPanelRightClickMenu_AddSpacer()
    local chTitle = UIDropDownMenu_CreateInfo()
    chTitle.text = "Callout channel"
    chTitle.isTitle = true
    chTitle.notCheckable = true
    UIDropDownMenu_AddButton(chTitle, level)
    for _, ch in ipairs(CHANNEL_CHOICES) do
        local c = UIDropDownMenu_CreateInfo()
        c.text = ch.label
        c.checked = (GetChannelOverride() == ch.key)
        c.func = function() TitanBgGeneralSaved.channelOverride = ch.key end
        UIDropDownMenu_AddButton(c, level)
    end

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
    local inPvp = inInstance and instanceType == "pvp"
    -- REL-1: honour the channel override, but only when the channel is actually
    -- usable right now; otherwise fall through to the smart default so a callout
    -- is never silently dropped into a channel the player isn't in.
    local override = GetChannelOverride()
    if override == "INSTANCE_CHAT" and inPvp then return "INSTANCE_CHAT" end
    if override == "RAID" and IsInRaid() then return "RAID" end
    if override == "PARTY" and IsInGroup() then return "PARTY" end
    if override == "SAY" then return "SAY" end

    if inPvp then
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

-- ******************************** ThreatProvider (scoreboard poller) *******************************
-- Keeps the battlefield scoreboard fresh while in a BG so the enemy-intel table
-- (GetEnemyIntel) and the headcount always have data — even with the Analytics
-- recorder off (its own score poll is a dev default that gets stripped at release).
--
-- Ranking itself moved out (CMD-8): the Era scoreboard reports damageDone/
-- healingDone as 0 (VERIF-3), so the old scoreboard-based ccList/killList that
-- lived here were dead on Era. Real danger order now comes from the CLEU
-- aggregate in GetEnemyIntel/IntelPanel, with killingBlows as the cold-start
-- fallback. This module no longer ranks — it only requests score data on a ticker.
local ThreatProvider = {}
do
    local POLL_SECONDS = 10 -- Details ships 10s; plenty for cumulative scoreboard data
    local ticker

    function ThreatProvider.Start()
        if ticker then return end
        -- Resolve the scoreboard-request API at call time (BG entry, long after
        -- load): global first, C_PvP fallback, skip cleanly if absent. Passing a
        -- nil straight to NewTicker crashed here once ("bad argument #2") — resolve,
        -- guard, and wrap so it can't anymore.
        local RequestScores = RequestBattlefieldScoreData
            or (C_PvP and C_PvP.RequestBattlefieldScoreData)
        if not RequestScores then
            Titan_Debug.Out(ADDON_ID, "Events", "ThreatProvider: no RequestBattlefieldScoreData API on this flavor")
            return
        end
        ticker = C_Timer.NewTicker(POLL_SECONDS, function() RequestScores() end)
        RequestScores()
        Titan_Debug.Out(ADDON_ID, "Events", "ThreatProvider poller started")
    end

    function ThreatProvider.Stop()
        if not ticker then return end
        ticker:Cancel()
        ticker = nil
        Titan_Debug.Out(ADDON_ID, "Events", "ThreatProvider poller stopped")
    end
end

-- ******************************** DetailsProvider (VERIF-6) *******************************
-- Details! damage/healing enrichment. The Era scoreboard reports damageDone/
-- healingDone as 0 (VERIF-3), and our own CLEU aggregate only sees fights the
-- player was near. When Details! is installed it has been parsing the same combat
-- log the whole time, so GetCurrentCombat() yields per-actor totals that backfill
-- the enemy-intel damage/healing columns + threat ranking (GetEnemyIntel blends
-- them). Fully optional and defensive: every access is feature-guarded and
-- pcall-wrapped, returning nil so callers degrade to the CLEU aggregate / class
-- prior when Details! is absent or its API shape shifts. API verified against the
-- installed Details source: Details:GetCurrentCombat() -> combat:GetContainer(attr)
-- (DAMAGE=1, HEAL=2) -> container:ListActors() -> actor.nome / actor.total.
local DetailsProvider = {}
do
    local ATTR_DAMAGE, ATTR_HEAL = 1, 2

    function DetailsProvider.IsAvailable()
        return Details ~= nil and type(Details.GetCurrentCombat) == "function"
    end

    -- Fold one attribute container's actors into totals[name][field], keyed by both
    -- the full "Name-Realm" and the short "Name" so a scoreboard name in either
    -- form finds it. max() guards against a container listing an actor twice.
    local function readAttr(combat, attr, totals, field)
        local container = combat:GetContainer(attr)
        if not (container and container.ListActors) then return end
        for _, actor in container:ListActors() do
            local nome  = actor and actor.nome
            local total = actor and tonumber(actor.total)
            if nome and total and total > 0 then
                local rec = totals[nome]; if not rec then rec = {}; totals[nome] = rec end
                rec[field] = math.max(rec[field] or 0, total)
                local short = nome:match("^[^-]+")
                if short and short ~= nome then
                    local sr = totals[short]; if not sr then sr = {}; totals[short] = sr end
                    sr[field] = math.max(sr[field] or 0, total)
                end
            end
        end
    end

    -- name -> { damage = n, healing = n } for the current combat, or nil if Details
    -- is absent / has no data / errors. Enemy filtering is the caller's job (it only
    -- looks up names it already knows are enemies), so pets/NPCs here are harmless.
    function DetailsProvider.GetTotals()
        if not DetailsProvider.IsAvailable() then return nil end
        local ok, totals = pcall(function()
            local combat = Details:GetCurrentCombat()
            if not (combat and combat.GetContainer) then return nil end
            local t = {}
            readAttr(combat, ATTR_DAMAGE, t, "damage")
            readAttr(combat, ATTR_HEAL,   t, "healing")
            return t
        end)
        if not ok or not totals or next(totals) == nil then return nil end
        return totals
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
    -- INTEL-3: `/bgthreat brief` broadcasts the memory-only pre-match briefing to
    -- team chat (the leader's explicit, outward-facing action — auto entry only
    -- prints it locally).
    if msg and msg:lower():match("brief") then
        if IntelPanel and IntelPanel.ShowBriefing then IntelPanel.ShowBriefing(true) end
        return
    end
    print("|cffeda55fBG General|r " ..
        ((IntelPanel and IntelPanel.GetAdvisoryLine and IntelPanel.GetAdvisoryLine())
            or "intel not ready — enter a battleground"))
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
    -- Idempotent on the STATS (all peaks), so it is safe to call repeatedly during
    -- a match for durable mid-match banking (INTEL-2 — the dossier survives a
    -- /reload or disconnect, not just a clean BG exit). `bumpMet` counts the
    -- encounter and must be passed ONCE per match (at match end via Nemesis.Record),
    -- never on the periodic tick, or "times met" would inflate every 5 seconds.
    function Nemesis.Merge(threat, bumpMet)
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
                if bumpMet then rec.met = (rec.met or 0) + 1 end
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

    -- Match-end bank: merge the final stats AND count the encounter once. Called
    -- from Recorder.Stop; the mid-match tick uses Nemesis.Merge (no met bump).
    function Nemesis.Record(threat) Nemesis.Merge(threat, true) end

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

    -- VERIF-5: WSG flag-event capture. Records every BG system message verbatim
    -- (+ timestamp) so the exact string form Era emits is banked for the FlagState
    -- pattern table. Resolved in-game 2026-07-04: a carried-flag DROP always NAMES
    -- the player ("The Horde flag was dropped by <name>!") — the generic "The flag
    -- has been dropped!" never appears on Era. Faction casing splits ("Alliance
    -- Flag" vs "Horde flag"), which the FlagState [Ff]lag patterns already handle.
    -- WSG only; inert when the recorder is off.
    local function CaptureBgSystemMessage(msg)
        if not Analytics.IsEnabled() then return end
        if GetActiveBg() ~= "WSG" then return end
        if type(msg) ~= "string" or msg == "" then return end
        Analytics.Record("wsg_system_msg", { msg = msg, t = GetTime() })
        Analytics.Emit(("wsgmsg %s"):format(msg))
    end

    -- VERIF-5: on targeting a flag carrier, scan the target's helpful auras for
    -- the flag auras (Silverwing 23335 / Warsong 23333) and log the carrier name +
    -- spellID + which aura API actually returned it (C_UnitAuras vs UnitAura) — the
    -- second open flavour question. Only carriers are logged (a matched flag aura),
    -- so this stays quiet despite PLAYER_TARGET_CHANGED firing often; a per-target
    -- dedupe suppresses repeat records while the same carrier stays targeted.
    local WSG_FLAG_AURA = { [23335] = "Alliance", [23333] = "Horde" }
    local lastAuraKey
    local function ScanFlagAura(unit)
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 40 do
                local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
                if not a then break end
                if WSG_FLAG_AURA[a.spellId] then return "C_UnitAuras", a.spellId, a.name end
            end
        elseif UnitAura then
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HELPFUL")
                if not name then break end
                if WSG_FLAG_AURA[spellId] then return "UnitAura", spellId, name end
            end
        end
        return nil
    end
    local function CaptureCarrierAura()
        if not Analytics.IsEnabled() then return end
        if GetActiveBg() ~= "WSG" then return end
        if not UnitExists("target") then lastAuraKey = nil; return end
        local api, spellId, auraName = ScanFlagAura("target")
        if not api then lastAuraKey = nil; return end
        local name = UnitName("target")
        local key = (name or "?") .. ":" .. spellId
        if key == lastAuraKey then return end -- same carrier still targeted
        lastAuraKey = key
        Analytics.Record("wsg_carrier_aura", {
            name = name, spellId = spellId, auraName = auraName,
            flag = WSG_FLAG_AURA[spellId], api = api,
        })
        Analytics.Emit(("wsgaura %s aura=%d(%s) via=%s"):format(
            tostring(name), spellId, tostring(auraName), api))
    end

    local function OnEvent(_, event, arg1)
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
        elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
            or event == "CHAT_MSG_BG_SYSTEM_HORDE"
            or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
            CaptureBgSystemMessage(arg1)
        elseif event == "PLAYER_TARGET_CHANGED" then
            CaptureCarrierAura()
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
        frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE") -- VERIF-5 WSG capture
        frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
        frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
        frame:RegisterEvent("PLAYER_TARGET_CHANGED")
        lastAuraKey = nil
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
            Nemesis.Merge(threat) -- INTEL-2: durable mid-match banking (stats only; met counted at Stop)
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
            frame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
            frame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
            frame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
            frame:UnregisterEvent("PLAYER_TARGET_CHANGED")
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
        { key = "wsg",   label = "WSG",   tip = "WSG flag events captured — raw BG system messages + flag-carrier aura scans (name/spellID/API). WSG only (VERIF-5)." },
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
            wsg   = has("wsg_system_msg") or has("wsg_carrier_aura"),
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

-- ******************************** WSG FlagState (WSG-2/3/4) *******************************
-- Tracks both flag carriers + flag status from BG system chat, the way Capping
-- does it: CHAT_MSG_BG_SYSTEM_{ALLIANCE,HORDE,NEUTRAL} matched against enUS
-- trigger patterns (Research/wsg-flag-state-research.md, F1-F8). Carrier NAMES
-- come only from the pickup message — no clean API — so a missed event leaves a
-- stale name until the next transition or an aura confirm. A locale-independent
-- aura check (Silverwing 23335 / Warsong 23333) confirms a carrier when we hold a
-- unitID. enUS patterns first; other locales degrade to flag-state-without-names,
-- never error. Provider runs from BG entry so no transition is missed.
local FlagState = {}
do
    -- flags[F] = the flag OWNED BY faction F (Alliance flag = Silverwing, Horde
    -- flag = Warsong). Its carrier is an enemy OF F (the player running it).
    -- state: "base" | "carried" | "dropped".
    local flags = {
        Alliance = { state = "base", carrier = nil, since = 0 },
        Horde    = { state = "base", carrier = nil, since = 0 },
    }
    local score     = { Alliance = 0, Horde = 0 }
    local respawnAt  = nil  -- GetTime() a captured flag returns to base (12s, F6)
    local frame, registered

    -- enUS patterns (F8). %w+ = the flag's faction; (.+) = a player name.
    -- Unanchored :match (DBM's proven approach — the event delivers the whole line).
    local P = {
        pickup   = "The (%w+) [Ff]lag was picked up by (.+)!",
        returned = "The (%w+) [Ff]lag was returned to its base by (.+)!",
        dropped  = "The (%w+) [Ff]lag was dropped by (.+)!",
        captured = "(.+) captured the (%w+) [Ff]lag!",
        capFaction  = "The (%w+) ha%w+ captured the flag!",
        dropGeneric = "The flag has been dropped!",
        reset       = "The flag has been reset!",
    }

    local FLAG_AURA = { Alliance = 23335, Horde = 23333 } -- Silverwing / Warsong (F4)

    local function setFlag(faction, state, carrier)
        local f = flags[faction]
        if not f then return end
        f.state, f.carrier, f.since = state, carrier, GetTime()
    end

    -- faction = the FLAG that was captured; the scorer is that flag's enemy.
    local function onCapture(faction)
        local scorer = (faction == "Alliance") and "Horde" or "Alliance"
        score[scorer] = (score[scorer] or 0) + 1
        setFlag(faction, "base", nil)
        respawnAt = GetTime() + 12 -- F6: fixed 12s respawn after a capture
    end

    local function HandleMessage(msg)
        if not msg then return end
        local flag, who = msg:match(P.pickup)
        if flag then setFlag(flag, "carried", who); return end
        flag, who = msg:match(P.returned)
        if flag then setFlag(flag, "base", nil); return end
        flag, who = msg:match(P.dropped)
        if flag then setFlag(flag, "dropped", who); return end
        who, flag = msg:match(P.captured)
        if flag then onCapture(flag); return end
        flag = msg:match(P.capFaction)
        if flag then
            -- "The Alliance has captured the flag!" — Alliance scored, so the Horde flag was capped.
            onCapture(flag == "Alliance" and "Horde" or "Alliance"); return
        end
        if msg:match(P.dropGeneric) then
            -- Nameless drop (F8 action item): mark whichever flag is carried as
            -- dropped, keeping its last-known carrier so the name persists.
            for fac, f in pairs(flags) do
                if f.state == "carried" then setFlag(fac, "dropped", f.carrier) end
            end
            return
        end
        if msg:match(P.reset) then
            setFlag("Alliance", "base", nil); setFlag("Horde", "base", nil)
        end
    end

    -- Best-effort: a unit token currently resolving to `name`, so we can read
    -- health / confirm the flag aura. Names are Name or Name-Realm; match either.
    local function UnitForName(name)
        if not name then return nil end
        local short = name:match("^[^-]+") or name
        local function m(unit)
            local n = UnitExists(unit) and UnitName(unit)
            return (n and (n == name or n == short)) and unit or nil
        end
        local u = m("target") or m("mouseover") or m("focus")
        if u then return u end
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, np in ipairs(C_NamePlate.GetNamePlates()) do
                local unit = np.namePlateUnitToken
                if unit and m(unit) then return unit end
            end
        end
        return nil
    end

    -- Aura scan for the flag aura on a unit (F4). Wrapped so the API flavour
    -- (C_UnitAuras vs UnitAura) is resolved in one place. Returns true/false.
    local function HasFlagAura(unit, spellId)
        if not (unit and UnitExists(unit)) then return false end
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 40 do
                local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
                if not a then break end
                if a.spellId == spellId then return true end
            end
        elseif UnitAura then
            for i = 1, 40 do
                local n = { UnitAura(unit, i, "HELPFUL") }
                if not n[1] then break end
                if n[10] == spellId then return true end
            end
        end
        return false
    end

    -- Locale-independent carrier recovery (F4): when chat gave us no name (missed
    -- pickup, joined late), a visible unit bearing the flag's aura IS the carrier.
    -- Scans target/mouseover/focus + nameplates for FLAG_AURA[flagFaction].
    local function FindCarrierByAura(flagFaction)
        local spell = FLAG_AURA[flagFaction]
        if not spell then return nil end
        for _, u in ipairs({ "target", "mouseover", "focus" }) do
            if HasFlagAura(u, spell) then return UnitName(u) end
        end
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _, np in ipairs(C_NamePlate.GetNamePlates()) do
                local unit = np.namePlateUnitToken
                if unit and HasFlagAura(unit, spell) then return UnitName(unit) end
            end
        end
        return nil
    end

    -- health % (0-100) for a carrier name if we can currently see them, else nil.
    function FlagState.HealthPct(name)
        local u = UnitForName(name)
        if not u then return nil end
        local mx = UnitHealthMax(u)
        if not mx or mx == 0 then return nil end
        return math.floor(UnitHealth(u) / mx * 100 + 0.5)
    end

    -- WSG-4: authoritative capture scores. Prefer the client's world-state score
    -- (fixes the under-count when we joined after some captures had happened); fall
    -- back to our own capture-event counter. WSG world-state lists the two flag
    -- scores as "N/3"; standard order is Alliance then Horde. If neither number
    -- parses, the counter stands. (Order is the one WSG-4 assumption to spot-check.)
    function FlagState.GetScores()
        local ally, horde
        if GetNumWorldStateUI and GetWorldStateUIInfo then
            local nums = {}
            for i = 1, GetNumWorldStateUI() do
                local text = select(6, GetWorldStateUIInfo(i)) -- text field
                local cur = type(text) == "string" and text:match("^%s*(%d+)%s*/%s*%d+")
                if cur then nums[#nums + 1] = tonumber(cur) end
            end
            if #nums >= 2 then ally, horde = nums[1], nums[2] end
        end
        return ally or score.Alliance, horde or score.Horde
    end

    -- Player-POV snapshot for the WSG UI + callouts:
    --   efc = the enemy carrying OUR flag (Enemy Flag Carrier — kill target)
    --   ffc = our ally carrying THEIR flag (Friendly Flag Carrier — escort)
    -- Each: { name, state, health }. Plus score + a live respawn countdown.
    function FlagState.GetView()
        local myFac    = UnitFactionGroup("player")               -- "Alliance"/"Horde"
        local ourFlag  = myFac                                    -- our flag object
        local theirFlag = (myFac == "Alliance") and "Horde" or "Alliance"
        local our, their = flags[ourFlag] or {}, flags[theirFlag] or {}
        local respawn = respawnAt and math.max(0, math.ceil(respawnAt - GetTime())) or nil
        if respawn == 0 then respawn = nil end
        -- Aura fallback for a name chat never gave us (only while the flag is out).
        local efcName = our.carrier
        if not efcName and our.state ~= "base" then efcName = FindCarrierByAura(ourFlag) end
        local ffcName = their.carrier
        if not ffcName and their.state ~= "base" then ffcName = FindCarrierByAura(theirFlag) end
        local ally, horde = FlagState.GetScores()
        return {
            efc     = { name = efcName,   state = our.state or "base",
                        health = efcName and FlagState.HealthPct(efcName) or nil },
            ffc     = { name = ffcName, state = their.state or "base",
                        health = ffcName and FlagState.HealthPct(ffcName) or nil },
            score   = { ally = ally, horde = horde },
            respawn = respawn,
        }
    end

    -- A live unit token for the current EFC ("efc") or FFC ("ffc"), when one is
    -- visible (target/mouseover/nameplate) — used by CMD-3 to raid-mark the carrier.
    function FlagState.CarrierUnit(which)
        local v = FlagState.GetView()
        local name = (which == "ffc") and v.ffc.name or v.efc.name
        return name and UnitForName(name) or nil
    end

    function FlagState.Start()
        if GetActiveBg() ~= "WSG" then return end
        if not frame then frame = CreateFrame("Frame"); frame:SetScript("OnEvent", function(_, _, msg) HandleMessage(msg) end) end
        if not registered then
            frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
            frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
            frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
            registered = true
        end
        -- Fresh state each match (Start is idempotent per BG entry via the caller).
        setFlag("Alliance", "base", nil); setFlag("Horde", "base", nil)
        score.Alliance, score.Horde, respawnAt = 0, 0, nil
    end

    function FlagState.Stop()
        if frame and registered then
            frame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
            frame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
            frame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
            registered = false
        end
    end
end

-- WSG-3: live FC enrichment for a WSG callout, mirroring AbCalloutSuffix. For the
-- EFC / FC columns, append the live carrier name + health (+ "LOW" when badly
-- hurt, + "(dropped)") from FlagState, so a call reads "KILL EFC Kruelhand 34%
-- LOW" instead of a bare "KILL EFC". Plain ASCII (chat-safe, no "|"). Location
-- columns (MID/RAMP/TUN) and non-WSG return "".
local WSG_LOW_HP = 35
local function WsgCalloutSuffix(colAbbr)
    if GetActiveBg() ~= "WSG" then return "" end
    if colAbbr ~= "EFC" and colAbbr ~= "FC" then return "" end
    local v = FlagState.GetView()
    local fc = (colAbbr == "EFC") and v.efc or v.ffc
    if not (fc and fc.name and fc.state ~= "base") then return "" end
    local out = " " .. (fc.name:match("^[^-]+") or fc.name)
    if fc.health then
        out = out .. " " .. fc.health .. "%"
        if fc.health <= WSG_LOW_HP then out = out .. " LOW" end
    end
    if fc.state == "dropped" then out = out .. " (dropped)" end
    return out
end

-- ******************************** Custom callout overrides (CMD-4) *******************************
-- Per-cell override of the DEFAULT (unmodified) click message, keyed by grid+cell,
-- persisted under TitanBgGeneralSaved.customCallouts. Right-click any grid cell to
-- set one; a blank text reverts to the generated default. Modifier clicks (Shift/
-- Ctrl/Alt) always use their generated messages. Live suffixes (AB node state /
-- WSG FC) are still appended, so a custom base keeps its enrichment.
local function CalloutKey(gridId, a, b) return gridId .. ":" .. tostring(a) .. ":" .. tostring(b) end
local function GetCalloutOverride(key)
    local s = TitanBgGeneralSaved.customCallouts
    return (type(s) == "table") and s[key] or nil
end
local function SetCalloutOverride(key, text)
    local s = TitanBgGeneralSaved.customCallouts
    if type(s) ~= "table" then s = {}; TitanBgGeneralSaved.customCallouts = s end
    s[key] = (text and text:gsub("%s", "") ~= "") and text or nil
end
StaticPopupDialogs["TITANBGGENERAL_EDIT_CALLOUT"] = {
    text = "Custom callout (blank = default):",
    button1 = SAVE or "Save",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 240,
    OnShow = function(self, data)
        self.editBox:SetText((data and (GetCalloutOverride(data.key) or data.default)) or "")
        self.editBox:HighlightText()
    end,
    OnAccept = function(self, data)
        if data then SetCalloutOverride(data.key, self.editBox:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

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

            local key = CalloutKey("AB", abbr, row)
            local function defaultMsg() return row .. " " .. cellActions[row][col].default .. " " .. fullName end

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(UIParent, "ANCHOR_BOTTOMRIGHT")
                local override = GetCalloutOverride(key)
                local defLine = override and ("|cffffd100" .. override .. "|r (custom)")
                    or ("|cffffffff" .. cellActions[row][col].default .. " " .. row .. " or more")
                GameTooltip:SetText(
                    "|cff00ff00(Click)|r "                 .. defLine .. "\n" ..
                    "|cff00ff00(Shift+Click)|r |cffffffff" .. cellActions[row][col].shift   .. " " .. row .. " or more\n" ..
                    "|cff00ff00(Ctrl+Click)|r |cffffffff"  .. cellActions[row][col].ctrl    .. " " .. row .. " or more\n" ..
                    "|cff00ff00(Alt+Click)|r |cffffffff"   .. cellActions[row][col].alt     .. "\n" ..
                    "|cff808080(Right-click: customize this callout)|r"
                )
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    StaticPopup_Show("TITANBGGENERAL_EDIT_CALLOUT", nil, nil, { key = key, default = defaultMsg() })
                    return
                end
                local base
                if IsShiftKeyDown() then
                    base = row .. " " .. cellActions[row][col].shift .. " " .. fullName
                elseif IsControlKeyDown() then
                    base = row .. " " .. cellActions[row][col].ctrl .. " " .. fullName
                elseif IsAltKeyDown() then
                    base = row .. " " .. cellActions[row][col].alt .. " " .. fullName
                else
                    base = GetCalloutOverride(key) or defaultMsg()
                end
                SendChatMessage(base .. AbCalloutSuffix(abbr), GetChatType())
            end)
        end
    end
end

-- ******************************** Build Column Grid (WSG / AV) *******************************
-- Generic location-columns × action-rows grid; colDefs entries carry abbr/full/icon.
-- suffixFn(colAbbr) -> string is optional (WSG-3): appended to the sent callout
-- so a column can enrich its message with live state (WSG FC name/health). AV
-- passes none. gridId ("WSG"/"AV") keys per-cell custom overrides (CMD-4).
local function BuildColGrid(parent, size, hGap, vGap, colDefs, rowActions, suffixFn, gridId)
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
            local key = CalloutKey(gridId or "COL", colData.abbr, rowAction)

            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(UIParent, "ANCHOR_BOTTOMRIGHT")
                local override = GetCalloutOverride(key)
                local defLine = override and ("|cffffd100" .. override .. "|r (custom)")
                    or ("|cffffffff" .. msg_default)
                GameTooltip:SetText(
                    "|cff00ff00(Click)|r " .. defLine .. "\n" ..
                    "|cff00ff00(Shift)|r |cffffffff"  .. msg_shift   .. "\n" ..
                    "|cff00ff00(Ctrl)|r |cffffffff"   .. msg_ctrl    .. "\n" ..
                    "|cff00ff00(Alt)|r |cffffffff"    .. msg_alt     .. "\n" ..
                    "|cff808080(Right-click: customize this callout)|r"
                )
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    StaticPopup_Show("TITANBGGENERAL_EDIT_CALLOUT", nil, nil, { key = key, default = msg_default })
                    return
                end
                local msg
                if IsShiftKeyDown() then
                    msg = msg_shift
                elseif IsControlKeyDown() then
                    msg = msg_ctrl
                elseif IsAltKeyDown() then
                    msg = msg_alt
                else
                    msg = GetCalloutOverride(key) or msg_default
                end
                SendChatMessage(msg .. (suffixFn and suffixFn(colData.abbr) or ""), GetChatType())
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
    local dtotals = DetailsProvider.GetTotals() -- VERIF-6: Details! totals or nil
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
                -- SIGHT from the name alone (INTEL-1).
                local live = threat[name]
                -- VERIF-6: blend Details! totals (segment-wide, backfills enemies
                -- our own CLEU never saw) with the CLEU aggregate — take the larger
                -- of each. Details is totals-only, so a CLEU record (school split +
                -- healOthers) is still preferred for role; a Details-only enemy gets
                -- a totals record so role upgrades from class-prior to DPS/HEAL.
                local d = dtotals and (dtotals[name] or dtotals[name:match("^[^-]+") or name])
                local damage  = math.max((live and live.damage)  or 0, (d and d.damage)  or 0)
                local healing = math.max((live and live.healing) or 0, (d and d.healing) or 0)
                local t = live or (d and { damage = damage, healing = healing }) or Nemesis.Lookup(name)
                local seenThisMatch = (live ~= nil) or (d ~= nil)
                local role, healer, confirmed = ResolveRole(t, classToken)
                list[#list + 1] = {
                    name        = name,
                    classToken  = classToken,
                    kb          = kb or 0,
                    deaths      = deaths or 0,
                    damage      = damage,
                    healing     = healing,
                    role        = role,
                    healer      = healer,
                    confirmed   = confirmed,
                    remembered  = (not seenThisMatch) and t ~= nil or nil, -- role came from memory, not this match
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

-- ******************************** Team-Comp Strategy Engine (TEAM-1) *******************************
-- The team-composition layer ABOVE the 1v1 MATCHUP: MATCHUP says who *I* fight;
-- this says what the *raid* does. Diffs both rosters into comp signatures and
-- emits a plan (posture / FC / focus / split). Reuses the shipped readers —
-- GroupMembers (ours) + GetEnemyIntel (theirs) — never re-derives roster reading.
-- Research: Research/team-comp-strategy-research.md. Debug surface: /bgcomp.

-- Friendly roster reader, lifted to file scope so both the Plan board and the
-- comp engine share ONE implementation. In a BG the group is a raid → the 6th
-- GetRaidRosterInfo return is the locale-independent class token; solo/party
-- fall back to UnitClass's 2nd return (same token).
local function GroupMembers()
    local list = {}
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, n do
            local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
            if name then list[#list + 1] = { name = name, class = fileName } end
        end
    else
        list[#list + 1] = { name = UnitName("player"), class = select(2, UnitClass("player")) }
        for i = 1, n - 1 do
            local u = "party" .. i
            if UnitExists(u) then list[#list + 1] = { name = UnitName(u), class = select(2, UnitClass(u)) } end
        end
    end
    return list
end

local FC_LADDER      = { "DRUID", "WARRIOR", "HUNTER", "MAGE" } -- best flag carrier first (research B3)
local RANGED_CLASSES = { HUNTER = true }                        -- physical ranged
local CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true }
-- PALADIN/SHAMAN/DRUID hybrids fall to the melee bucket by default — a documented
-- count-level approximation (Research §Risks); the healer prior pulls the real
-- healers back out first, so only their DPS specs land in melee.

-- posture → per-BG plan copy. WSG split is of 10; AB (15v15) is a node policy.
local COMP_PLAN = {
    WSG = {
        PRESS    = { off = 7, def = 3, line = "stack offense, run the flag, out-heal them mid" },
        STANDARD = { off = 6, def = 4, line = "even split — win the first pick, then push" },
        TURTLE   = { off = 3, def = 7, line = "defend the FC, deny their cap, farm their GY" },
    },
    AB = {
        PRESS    = { line = "hold 3, contest a 4th, mass Blacksmith" },
        STANDARD = { line = "hold nearest 3, 1 on backline, mass Blacksmith" },
        TURTLE   = { line = "collapse to 3, defend, win on resource rate" },
    },
}

-- FC ladder class → carrier plan (WSG). The requiresHealer gate is load-bearing:
-- a Warrior FC is top-tier ONLY with a pocket healer, else it's the wrong pick.
local FC_PLAN = {
    DRUID   = { escort = "1 healer + 1 peel", requiresHealer = false, note = "shapeshift breaks snares/poly" },
    WARRIOR = { escort = "1 dedicated healer", requiresHealer = true,  note = "top-tier only with a pocket healer" },
    HUNTER  = { escort = "+1 defense",         requiresHealer = false, note = "kite carrier, weak under focus" },
    MAGE    = { escort = "+1 defense",         requiresHealer = false, note = "blink/nova carrier, squishy" },
}

-- Semantic posture colours (green = go, gold = neutral, orange = caution —
-- deliberately NOT enemy-red, which reads as "kill target"). Shared by the
-- /bgplan board and the main-panel headline (TEAM-3).
local POSTURE_COLOR = { PRESS = "|cff40ff40", STANDARD = "|cffffd100", TURTLE = "|cffff8040" }
local function PostureColor(p) return POSTURE_COLOR[p] or "|cffffffff" end

local function TitleClass(c) return c and (c:sub(1, 1) .. c:sub(2):lower()) or "?" end

-- Reduce a roster (list of { classToken, role? }) to a comp signature. Live role
-- from ResolveRole wins ("HEAL"/"CASTER"/"MELEE" = confirmed); everything else
-- ("heal?"/"DPS"/nil) falls to the class prior. `healers` is the prior ceiling
-- (over-counts shadow/boomkin/feral, biases toward TURTLE = the safe direction);
-- `confirmedHealers` is the CLEU-confirmed floor.
local function CompSignature(roster)
    local sig = { counts = {}, healers = 0, confirmedHealers = 0,
                  melee = 0, ranged = 0, caster = 0, size = 0, fc = {} }
    for _, p in ipairs(roster) do
        local c, role = p.classToken, p.role
        if c then
            sig.counts[c] = (sig.counts[c] or 0) + 1
            sig.size = sig.size + 1
            if role == "HEAL" then
                sig.healers = sig.healers + 1; sig.confirmedHealers = sig.confirmedHealers + 1
            elseif role == "CASTER" then
                sig.caster = sig.caster + 1
            elseif role == "MELEE" then
                sig.melee = sig.melee + 1
            elseif HEALER_CAPABLE[c] then      -- no confirmed role → class prior
                sig.healers = sig.healers + 1
            elseif CASTER_CLASSES[c] then
                sig.caster = sig.caster + 1
            elseif RANGED_CLASSES[c] then
                sig.ranged = sig.ranged + 1
            else
                sig.melee = sig.melee + 1
            end
        end
    end
    for _, fcClass in ipairs(FC_LADDER) do
        if (sig.counts[fcClass] or 0) > 0 then sig.fc[#sig.fc + 1] = fcClass end
    end
    return sig
end

-- (ourSig, theirSig, bg) → recommended plan. ΔH (healer differential) is the
-- master posture switch; FC pick walks our ladder honouring requiresHealer;
-- focus = enemy healer classes (by count) then their FC; split from COMP_PLAN.
local function ComputeTeamPlan(ourSig, theirSig, bg)
    local dH = ourSig.healers - theirSig.healers
    local posture = (dH >= 2 and "PRESS") or (dH <= -2 and "TURTLE") or "STANDARD"
    local haveHealer = ourSig.healers > 0

    local fc
    if bg == "WSG" then
        for _, cls in ipairs(ourSig.fc) do
            local p = FC_PLAN[cls]
            if p and (not p.requiresHealer or haveHealer) then
                fc = { class = cls, escort = p.escort, note = p.note }; break
            end
        end
        if not fc then
            fc = { class = ourSig.fc[1] or "ANY", escort = "extra defense",
                   note = "no ideal carrier — flag more defense" }
        end
        -- No healer at all → step the posture one notch toward TURTLE (elseif, so
        -- it never double-steps PRESS straight past STANDARD).
        if not haveHealer then
            if posture == "PRESS" then posture = "STANDARD"
            elseif posture == "STANDARD" then posture = "TURTLE" end
        end
    end

    -- focus = plain strings (chat/print, no colour codes); focusData = structured
    -- {class,count,fc} so the board can class-colour it. Same order/content.
    local focus, focusData = {}, {}
    local healerClasses = {}
    for c in pairs(theirSig.counts) do
        if HEALER_CAPABLE[c] then healerClasses[#healerClasses + 1] = c end
    end
    table.sort(healerClasses, function(a, b) return theirSig.counts[a] > theirSig.counts[b] end)
    for _, c in ipairs(healerClasses) do
        focus[#focus + 1] = ("%dx %s"):format(theirSig.counts[c], TitleClass(c))
        focusData[#focusData + 1] = { class = c, count = theirSig.counts[c] }
    end
    if theirSig.fc[1] then
        focus[#focus + 1] = TitleClass(theirSig.fc[1]) .. " (FC)"
        focusData[#focusData + 1] = { class = theirSig.fc[1], fc = true }
    end

    local copy = (COMP_PLAN[bg] or {})[posture] or {}
    local split
    if bg == "WSG" and copy.off then
        local off, def = copy.off, copy.def
        if theirSig.melee >= 5 then off, def = off - 1, def + 1 end -- peel-heavy enemy → +1 defense
        split = { off = off, def = def }
    end

    return {
        posture = posture, dH = dH, line = copy.line or "",
        fc = fc, focus = focus, focusData = focusData, split = split,
        ourHealers = ourSig.healers, theirHealers = theirSig.healers,
        theirConfirmed = theirSig.confirmedHealers,
    }
end

-- Assemble both signatures from the live readers and compute the plan, or
-- (nil, reason) when there isn't enough to advise. WSG/AB only for v1.
local function BuildTeamPlan()
    local bg = GetActiveBg()
    if bg ~= "WSG" and bg ~= "AB" then
        return nil, bg and (bg .. " not supported (WSG/AB only)") or "not in a battleground"
    end
    local theirs = {}
    for _, e in ipairs(GetEnemyIntel()) do
        theirs[#theirs + 1] = { classToken = e.classToken, role = e.role }
    end
    if #theirs == 0 then return nil, "enemy roster not loaded yet — open the scoreboard or wait a few seconds" end
    local ours = {}
    for _, m in ipairs(GroupMembers()) do ours[#ours + 1] = { classToken = m.class } end

    local ourSig, theirSig = CompSignature(ours), CompSignature(theirs)
    return ComputeTeamPlan(ourSig, theirSig, bg), nil, ourSig, theirSig
end

-- /bgcomp — debug surface for TEAM-1 (RED→GREEN without the TEAM-2 board UI).
-- Prints the computed plan locally; never sends to chat (that's TEAM-2's opt-in
-- Broadcast button).
local function PrintTeamPlan()
    local plan, reason = BuildTeamPlan()
    if not plan then
        print("|cffeda55fBG General|r comp: " .. (reason or "no plan"))
        return
    end
    local confirmNote = (plan.theirConfirmed < plan.theirHealers)
        and (" |cff808080(" .. plan.theirConfirmed .. " confirmed)|r") or ""
    print(("|cffeda55fBG General|r Comp plan |cffffd100[%s]|r %s  (healers %d vs %d, diff %+d%s)"):format(
        plan.posture, plan.line, plan.ourHealers, plan.theirHealers, plan.dH, confirmNote))
    if plan.fc then
        print(("  FC: %s — %s%s"):format(TitleClass(plan.fc.class), plan.fc.escort,
            (plan.fc.note ~= "") and (" (" .. plan.fc.note .. ")") or ""))
    end
    if plan.split then print(("  Split: O %d / D %d"):format(plan.split.off, plan.split.def)) end
    if #plan.focus > 0 then print("  Focus: " .. table.concat(plan.focus, ", ")) end
end

SLASH_TITANBGGENERALCOMP1 = "/bgcomp"
SlashCmdList["TITANBGGENERALCOMP"] = PrintTeamPlan

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

    -- CMD-6/8: pick the deadliest enemies. KILL = top real-damage dealers from the
    -- CLEU aggregate; CC = healers (confirmed via heal events, or class-prior "?").
    -- Cold-start fallback (CMD-8): with no CLEU damage yet — start of match, or the
    -- recorder off post-release — rank the KILL list by scoreboard killingBlows
    -- (a real Era field, unlike the always-0 damageDone) so the call still names
    -- the enemy's killers. Returns dps (enemy records, ranked) and heals (name strings).
    local function BuildThreatLists()
        local intel = GetEnemyIntel()
        local dps, heals = {}, {}
        for _, e in ipairs(intel) do
            if e.healer and #heals < 3 then
                heals[#heals + 1] = (e.name:match("^[^-]+") or e.name) .. (e.confirmed and "" or "?")
            elseif (e.damage or 0) > 0 then
                dps[#dps + 1] = e
            end
        end
        if #dps > 0 then
            table.sort(dps, function(a, b) return a.damage > b.damage end)
        else
            for _, e in ipairs(intel) do
                if not e.healer and (e.kb or 0) > 0 then dps[#dps + 1] = e end
            end
            table.sort(dps, function(a, b) return (a.kb or 0) > (b.kb or 0) end)
        end
        return dps, heals
    end

    -- One KILL-list label. Shows real damage when we have it, else "N KB" (the
    -- cold-start fallback metric). `crown` prefixes the chat {skull} raid token —
    -- pass false for local prints, where the token would show as literal text.
    local function KillLabel(e, crown)
        local metric = (e.damage or 0) > 0 and ShortNum(e.damage) or ((e.kb or 0) .. " KB")
        return (crown and "{skull}" or "")
            .. (e.name:match("^[^-]+") or e.name)
            .. " (" .. ClassLabel(e.classToken) .. " " .. metric .. ")"
    end

    -- CMD-6: call the deadliest enemies to chat, on the right channel via
    -- GetChatType (INSTANCE_CHAT in a BG). Plain text — colour codes don't render
    -- for other players.
    function IntelPanel.AnnounceThreats()
        local dps, heals = BuildThreatLists()
        local kill = {}
        for i = 1, math.min(3, #dps) do kill[i] = KillLabel(dps[i], i == 1) end
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

    -- CMD-8: the bare `/bgthreat` readout — the same KILL/CC selection, printed
    -- locally (colour ok, no {skull} chat token). Replaces the old ThreatProvider
    -- scoreboard ranking, which was dead on Era (damage/healing always 0).
    function IntelPanel.GetAdvisoryLine()
        local dps, heals = BuildThreatLists()
        if #dps == 0 and #heals == 0 then
            return "no enemy threat data yet (fight near them; rankings build over the match)"
        end
        local parts = {}
        if #dps > 0 then
            local names = {}
            for i = 1, math.min(3, #dps) do names[i] = KillLabel(dps[i], false) end
            parts[#parts + 1] = "|cffff5555KILL|r: " .. table.concat(names, ", ")
        end
        if #heals > 0 then parts[#parts + 1] = "|cff33ffffCC|r: " .. table.concat(heals, ", ") end
        return table.concat(parts, "   ")
    end

    -- INTEL-3: pre-match briefing built purely from the remembered dossier — no
    -- live combat data (the match hasn't started). Lists only the ACTIONABLE known
    -- enemies: healers to CC and standing nemeses to focus. Returns a chat-safe
    -- line, or nil when nobody on the enemy team has been met before.
    function IntelPanel.BuildBriefing()
        local cc, focus = {}, {}
        for _, e in ipairs(GetEnemyIntel()) do
            if e.remembered then -- role came from memory → we've fought them before
                local short = e.name:match("^[^-]+") or e.name
                if e.healer and #cc < 4 then
                    cc[#cc + 1] = short .. " (" .. ClassLabel(e.classToken) .. ")"
                elseif e.nemesis and #focus < 4 then
                    focus[#focus + 1] = "{skull}" .. short .. " (" .. ClassLabel(e.classToken) .. ")"
                end
            end
        end
        local parts = {}
        if #cc > 0    then parts[#parts + 1] = "CC: " .. table.concat(cc, ", ") end
        if #focus > 0 then parts[#parts + 1] = "Focus: " .. table.concat(focus, ", ") end
        if #parts == 0 then return nil end
        -- " // " separator, never a bare "|" (chat escape-code safe, per the CMD-6 bug).
        return "Pre-match intel >> " .. table.concat(parts, " // ")
    end

    -- Show the briefing. broadcast==true sends to team chat (GetChatType); else it
    -- prints locally to the leader. The auto pre-match path (broadcast=false) stays
    -- silent when nobody known is present; only the explicit command reports empty,
    -- and it reports to the user locally — never an empty message to the team.
    -- Returns true when a briefing was actually shown/sent, false otherwise — the
    -- auto path uses this to retry if the enemy roster had not loaded yet.
    function IntelPanel.ShowBriefing(broadcast)
        local line = IntelPanel.BuildBriefing()
        if not line then
            if broadcast then print("|cffeda55fBG General|r Pre-match intel: no known enemies on the board.") end
            return false
        end
        if broadcast then
            SendChatMessage(line, GetChatType())
        else
            print("|cffeda55fBG General|r " .. line)
        end
        return true
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

-- ******************************** Battle Plan board (CMD-1/2/3) *******************************
-- Leader tool (opened with /bgplan): assign each group member to a node/role,
-- broadcast the plan to the raid, fire opening-split presets (CMD-2), and drop
-- raid markers (CMD-3). Its own movable window so it never risks the callout
-- panel. Assignments persist under TitanBgGeneralSaved.plan keyed by name (stale
-- names are harmless). Native WoW look: DialogBox backdrop + UIPanelButtonTemplate.
local PlanBoard = {}
do
    local frame
    local MAX_ROWS = 25 -- covers WSG(10)/AB(15) fully; big AV raids truncate (noted)

    -- BG-aware assignment options cycled per member. "-" (unassigned) is implicit.
    local PLAN_ROLES = {
        AB      = { "Stables", "Gold Mine", "Blacksmith", "Lumber Mill", "Farm", "Roam", "Defense" },
        WSG     = { "FC Defense", "Offense", "Mid", "EFC Kill", "Flag Return", "Roam" },
        AV      = { "Offense", "Defense", "Snowfall", "Tower Point", "Iceblood", "Boss", "Roam" },
        default = { "Offense", "Defense", "Roam" },
    }
    local function roleList() return PLAN_ROLES[GetActiveBg() or ""] or PLAN_ROLES.default end

    -- CMD-2: one-click opening-split presets, editable + persisted. Defaults seed
    -- TitanBgGeneralSaved.openers[bg] the first time a BG is opened; edits stick.
    local OPENER_DEFAULTS = {
        AB      = { "5 Stables, 5 Blacksmith, rest Farm", "Zerg Blacksmith - everyone mid", "5 cap Stables, 10 to Gold Mine" },
        WSG     = { "8 mid 2 D", "3 defense, 7 offense", "Turtle - all D, farm their GY" },
        AV      = { "All south - cap Galv then push", "5 D at chokes, rest offense", "Rush Drek - ignore towers" },
        default = { "Group up - follow me", "Split into 2 groups", "Defense priority" },
    }

    local function store()
        local s = TitanBgGeneralSaved.plan
        if type(s) ~= "table" then s = {}; TitanBgGeneralSaved.plan = s end
        return s
    end

    -- Opener presets for the current BG, seeded from defaults on first use.
    local function openersStore()
        local s = TitanBgGeneralSaved.openers
        if type(s) ~= "table" then s = {}; TitanBgGeneralSaved.openers = s end
        local bg = GetActiveBg() or "default"
        if type(s[bg]) ~= "table" then
            local defs = OPENER_DEFAULTS[bg] or OPENER_DEFAULTS.default
            local copy = {}
            for i, v in ipairs(defs) do copy[i] = v end
            s[bg] = copy
        end
        return s[bg]
    end

    -- Next role in the cycle: nil -> first, last -> nil (back to unassigned).
    local function nextRole(cur)
        local roles = roleList()
        if cur == nil then return roles[1] end
        for i, r in ipairs(roles) do if r == cur then return roles[i + 1] end end
        return roles[1]
    end

    local function ClassColor(class)
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c and c.colorStr then return "|c" .. c.colorStr end
        return "|cffffffff"
    end

    -- PostureColor() is lifted to file scope (shared with the TEAM-3 panel headline).

    -- Current group as { name=, class= }. Solo shows just the player.
    -- GroupMembers() is lifted to file scope (shared with the TEAM-1 comp engine).

    -- Broadcast the plan grouped by assignment, chat-safe (" // ", never a bare "|").
    function PlanBoard.Broadcast()
        local groups, order = {}, {}
        for _, m in ipairs(GroupMembers()) do
            local label = store()[m.name]
            if label and label ~= "-" then
                if not groups[label] then groups[label] = {}; order[#order + 1] = label end
                groups[label][#groups[label] + 1] = m.name:match("^[^-]+") or m.name
            end
        end
        if #order == 0 then
            print("|cffeda55fBG General|r No assignments yet — click a member's role button, then Broadcast.")
            return
        end
        local parts = {}
        for _, label in ipairs(order) do parts[#parts + 1] = label .. ": " .. table.concat(groups[label], ", ") end
        SendChatMessage("Plan >> " .. table.concat(parts, " // "), GetChatType())
    end

    -- TEAM-2: broadcast the comp-strategy plan to BG chat (opt-in button, never
    -- automatic). Plain ASCII, " // " separators — a bare "|" is an invalid chat
    -- escape (SendChatMessage rejects it) and colour codes don't render for others.
    function PlanBoard.BroadcastPlan()
        local plan, reason = BuildTeamPlan()
        if not plan then
            print("|cffeda55fBG General|r " .. (reason or "no plan to broadcast"))
            return
        end
        local parts = { plan.posture .. ": " .. plan.line }
        if plan.fc then parts[#parts + 1] = "FC " .. TitleClass(plan.fc.class) .. " (" .. plan.fc.escort .. ")" end
        if plan.split then parts[#parts + 1] = ("O%d D%d"):format(plan.split.off, plan.split.def) end
        if #plan.focus > 0 then parts[#parts + 1] = "Focus " .. table.concat(plan.focus, ", ") end
        SendChatMessage("Plan >> " .. table.concat(parts, " // "), GetChatType())
    end

    -- CMD-3: raid markers. Marking needs raid lead/assist (party/BG is usually
    -- fine); SetRaidTarget silently no-ops otherwise, so warn once if we can tell.
    local function CanMark()
        if IsInRaid() and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            print("|cffeda55fBG General|r You need raid lead or assist to place markers.")
            return false
        end
        return true
    end

    function PlanBoard.MarkTarget(i)
        if not UnitExists("target") then
            print("|cffeda55fBG General|r No target to mark.")
            return
        end
        if not CanMark() then return end
        SetRaidTarget("target", i) -- 0 clears
    end

    function PlanBoard.MarkEFC()
        if GetActiveBg() ~= "WSG" then
            print("|cffeda55fBG General|r Skull-EFC is WSG-only (marks the enemy flag carrier).")
            return
        end
        local unit = FlagState.CarrierUnit and FlagState.CarrierUnit("efc")
        if not unit then
            print("|cffeda55fBG General|r EFC not visible — target or get near them, then try again.")
            return
        end
        if not CanMark() then return end
        SetRaidTarget(unit, 8) -- skull
    end

    function PlanBoard.Hide()
        if frame then frame:Hide() end
    end

    -- Build (or rebuild) the whole window: title bar, one row per member, action
    -- buttons. Rebuilt wholesale on open / Refresh / Clear so a changed group or
    -- BG is always reflected; assignments survive via the SavedVariables store.
    local function Build()
        if frame then frame:Hide(); frame = nil end
        local pad, rowH, W = 12, 20, 260
        local members = GroupMembers()
        local shown = math.min(#members, MAX_ROWS)

        frame = CreateFrame("Frame", "BgGeneralPlanWindow", UIParent, "BackdropTemplate")
        frame:SetWidth(W)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetToplevel(true)
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 4,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.85)

        if TitanBgGeneralSaved.planPoint then
            frame:SetPoint(TitanBgGeneralSaved.planPoint, UIParent, TitanBgGeneralSaved.planRelPoint,
                TitanBgGeneralSaved.planX or 0, TitanBgGeneralSaved.planY or 0)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
        end

        local titleBar = CreateFrame("Button", nil, frame)
        titleBar:SetHeight(16)
        titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
        titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -pad)
        titleBar:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then frame:StartMoving() end end)
        titleBar:SetScript("OnMouseUp", function(_, b)
            if b == "LeftButton" then
                frame:StopMovingOrSizing()
                local p, _, rp, x, y = frame:GetPoint()
                TitanBgGeneralSaved.planPoint, TitanBgGeneralSaved.planRelPoint = p, rp
                TitanBgGeneralSaved.planX, TitanBgGeneralSaved.planY = x, y
            end
        end)
        local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("CENTER", titleBar, "CENTER")
        title:SetText(("|cffeda55fBattle Plan|r  ·  %s"):format(GetActiveBg() or "no BG"))

        local y = -pad - 16 - 6

        -- TEAM-2: Suggested Plan — the TEAM-1 comp advice as the board headline
        -- (summary before detail). Recomputed every Build()/Refresh (the board's
        -- rebuild-on-refresh pattern; that is the "live-refine"). WSG/AB only —
        -- other states show why it is quiet.
        local plan, planReason = BuildTeamPlan()
        local spHdr = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        spHdr:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
        spHdr:SetText("|cffeda55fSuggested Plan|r")
        y = y - 15
        local function planLine(text, fontObj)
            local fs = frame:CreateFontString(nil, "OVERLAY", fontObj or "GameFontHighlightSmall")
            fs:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
            fs:SetWidth(W - pad * 2); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
            fs:SetText(text)
            y = y - (math.max(math.ceil(fs:GetStringHeight() or 0), 12) + 3)
        end
        if not plan then
            planLine("|cff808080" .. (planReason or "no plan yet") .. "|r")
        else
            local confirmNote = (plan.theirConfirmed < plan.theirHealers)
                and (", " .. plan.theirConfirmed .. " confirmed") or ""
            planLine(("%s%s|r  |cffffffff%s|r  |cff808080(heal %d v %d, %+d%s)|r"):format(
                PostureColor(plan.posture), plan.posture, plan.line,
                plan.ourHealers, plan.theirHealers, plan.dH, confirmNote))
            if plan.fc then
                planLine(("|cff808080FC:|r %s%s|r |cff808080— %s|r"):format(
                    ClassColor(plan.fc.class), TitleClass(plan.fc.class), plan.fc.escort))
            end
            if plan.split then
                planLine(("|cff808080Split:|r O %d |cff808080/|r D %d"):format(plan.split.off, plan.split.def))
            end
            if plan.focusData and #plan.focusData > 0 then
                local segs = {}
                for _, f in ipairs(plan.focusData) do
                    local label = (f.count and (f.count .. "x ") or "") .. TitleClass(f.class) .. (f.fc and " (FC)" or "")
                    segs[#segs + 1] = ClassColor(f.class) .. label .. "|r"
                end
                planLine("|cff808080Focus:|r " .. table.concat(segs, "|cff808080, |r"))
            end
            planLine("|cff707070estimated from class — sharpens as the fight develops|r", "GameFontDisableSmall")
        end
        -- Broadcast Plan (distinct from the assignment Broadcast in the action row).
        local bpBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        bpBtn:SetSize(W - pad * 2, rowH - 2)
        bpBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
        bpBtn:SetText("Broadcast Plan")
        bpBtn:SetScript("OnClick", function() PlanBoard.BroadcastPlan() end)
        if not plan then bpBtn:Disable() end
        y = y - rowH - 8

        for i = 1, shown do
            local m = members[i]
            local nameFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            nameFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
            nameFS:SetWidth(110); nameFS:SetJustifyH("LEFT"); nameFS:SetWordWrap(false)
            nameFS:SetText(ClassColor(m.class) .. (m.name:match("^[^-]+") or m.name) .. "|r")

            local roleBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            roleBtn:SetSize(W - pad * 2 - 110 - 4, rowH - 2)
            roleBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 110 + 4, y + 1)
            local function paint() roleBtn:SetText(store()[m.name] or "-") end
            paint()
            roleBtn:SetScript("OnClick", function()
                local nx = nextRole(store()[m.name])
                store()[m.name] = nx -- nil clears the key back to unassigned
                paint()
            end)
            y = y - rowH
        end
        if #members > shown then
            local moreFS = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            moreFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
            moreFS:SetText(("|cff808080+%d more (raid too large to list)|r"):format(#members - shown))
            y = y - 14
        end

        -- CMD-2: opening-split presets. Left-click broadcasts; right-click edits.
        y = y - 8
        local openHdr = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        openHdr:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
        openHdr:SetText("|cffeda55fOpeners|r  |cff808080(left-click send · right-click edit)|r")
        y = y - 16
        local bgKey = GetActiveBg() or "default"
        for i in ipairs(openersStore()) do
            local ob = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            ob:SetSize(W - pad * 2, rowH - 2)
            ob:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
            ob:SetText(openersStore()[i])
            ob:GetFontString():ClearAllPoints()
            ob:GetFontString():SetPoint("LEFT", ob, "LEFT", 6, 0)
            ob:GetFontString():SetPoint("RIGHT", ob, "RIGHT", -6, 0)
            ob:GetFontString():SetJustifyH("LEFT")
            ob:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            ob:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    StaticPopup_Show("TITANBGGENERAL_EDIT_OPENER", nil, nil, { bg = bgKey, idx = i })
                else
                    SendChatMessage(openersStore()[i], GetChatType())
                end
            end)
            y = y - rowH
        end

        -- CMD-3: raid markers. Icon row marks your current target; the row below
        -- clears the mark and (WSG) auto-skulls the enemy flag carrier.
        y = y - 8
        local mkHdr = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mkHdr:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, y)
        mkHdr:SetText("|cffeda55fMarkers|r  |cff808080(mark your target)|r")
        y = y - 16
        local icons, isize = 8, 22
        local igap = (W - pad * 2 - icons * isize) / (icons - 1)
        for idx = 1, icons do
            local mb = CreateFrame("Button", nil, frame)
            mb:SetSize(isize, isize)
            mb:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + (idx - 1) * (isize + igap), y)
            local tex = mb:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. idx)
            mb:SetScript("OnClick", function() PlanBoard.MarkTarget(idx) end)
            mb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText("Mark target with " .. (_G["RAID_TARGET_" .. idx] or ("icon " .. idx)))
                GameTooltip:Show()
            end)
            mb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        y = y - isize - 4
        local mkBtns = {
            { text = "Unmark target", on = function() PlanBoard.MarkTarget(0) end },
            { text = "Skull EFC",     on = function() PlanBoard.MarkEFC() end },
        }
        local mgap = 4
        local mbw = math.floor((W - pad * 2 - (#mkBtns - 1) * mgap) / #mkBtns)
        for i, b in ipairs(mkBtns) do
            local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            btn:SetSize(mbw, 20)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + (i - 1) * (mbw + mgap), y)
            btn:SetText(b.text)
            btn:SetScript("OnClick", b.on)
        end
        y = y - 20

        y = y - 6
        -- Action row: Broadcast / Clear / Refresh / Close.
        local btns = {
            { text = "Broadcast", on = function() PlanBoard.Broadcast() end },
            { text = "Clear",     on = function() TitanBgGeneralSaved.plan = {}; Build() end },
            { text = "Refresh",   on = function() Build() end },
            { text = "Close",     on = function() PlanBoard.Hide() end },
        }
        local gap = 4
        local bw = math.floor((W - pad * 2 - (#btns - 1) * gap) / #btns)
        for i, b in ipairs(btns) do
            local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            btn:SetSize(bw, 22)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + (i - 1) * (bw + gap), y)
            btn:SetText(b.text)
            btn:SetScript("OnClick", b.on)
        end
        y = y - 22 - pad

        frame:SetHeight(-y)
        frame:Show()
    end

    -- CMD-2: native text-input editor for an opener preset (right-click a preset).
    -- Writes straight to the BG-keyed store via the passed { bg, idx }, then rebuilds.
    StaticPopupDialogs["TITANBGGENERAL_EDIT_OPENER"] = {
        text = "Edit opening call:",
        button1 = SAVE or "Save",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 240,
        OnShow = function(self, data)
            local list = data and TitanBgGeneralSaved.openers and TitanBgGeneralSaved.openers[data.bg]
            self.editBox:SetText((list and list[data.idx]) or "")
            self.editBox:HighlightText()
        end,
        OnAccept = function(self, data)
            local text = self.editBox:GetText()
            local list = data and TitanBgGeneralSaved.openers and TitanBgGeneralSaved.openers[data.bg]
            if list and text and text:gsub("%s", "") ~= "" then list[data.idx] = text end
            Build()
        end,
        EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    function PlanBoard.Toggle()
        if frame and frame:IsShown() then PlanBoard.Hide() else Build() end
    end
end

SLASH_TITANBGGENERALPLAN1 = "/bgplan"
SlashCmdList["TITANBGGENERALPLAN"] = function() PlanBoard.Toggle() end

-- ******************************** Sound alerts (REL-2) *******************************
-- Optional audio cues on the critical advisor events, gated by the REL-1 "Sound
-- alerts" toggle (opt-in). Runs on its own 1s ticker (independent of the window)
-- so a cue fires even with the panel closed. Edge-detected — a cue plays once on
-- the transition, not every tick. Cues: an enemy assaulting an AB base (matches
-- the AB-5 DEFEND priority), our WSG flag getting taken, and the EFC dropping low.
local Alerts = {}
do
    local ticker, prev = nil, {}
    local CUE = {
        urgent = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959,
        flag   = (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960,
    }
    local function play(id) if AreSoundsEnabled() then PlaySound(id, "Master") end end

    local function Check()
        if not AreSoundsEnabled() then return end
        local bg = GetActiveBg()
        if bg == "AB" then
            local theirs = (UnitFactionGroup("player") == "Alliance") and "H" or "A"
            local underAttack = false
            for _, s in pairs(GetAbNodeStates()) do
                if s.contested and s.owner == theirs then underAttack = true; break end
            end
            if underAttack and not prev.abAttack then play(CUE.urgent) end
            prev.abAttack = underAttack
        elseif bg == "WSG" then
            local v = FlagState.GetView()
            local taken = v.efc.name ~= nil and v.efc.state == "carried"
            if taken and not prev.efcTaken then play(CUE.flag) end
            prev.efcTaken = taken
            local low = v.efc.health ~= nil and v.efc.health <= 35
            if low and not prev.efcLow then play(CUE.urgent) end
            prev.efcLow = low
        end
    end

    function Alerts.Start()
        if ticker then return end
        wipe(prev)
        ticker = C_Timer.NewTicker(1, Check)
    end
    function Alerts.Stop()
        if ticker then ticker:Cancel(); ticker = nil end
        wipe(prev)
    end
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

    -- WSG-2 FC status line: both flag carriers by name + health, in the same band
    -- as the AB strip. Shown only on the WSG tab; live from FlagState.GetView().
    -- EFC = the enemy carrying OUR flag (kill target, red); FFC = our ally carrying
    -- THEIR flag (escort, green). WSG-4 appends the capture score + 12s flag-respawn.
    local wsgStrip = CreateFrame("Frame", nil, frame)
    wsgStrip:SetAllPoints(frame)
    local wsgStripFS = wsgStrip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    wsgStripFS:SetPoint("TOP", frame, "TOP", 0, stripY)
    wsgStripFS:SetJustifyH("CENTER")
    wsgStripFS:SetWordWrap(false)
    wsgStrip:Hide()

    -- One carrier's segment: "EFC Name 45%", "EFC Name (dropped)", or a muted
    -- "our flag safe" when the flag is at base.
    local function fcSegment(label, fc, col, safeText)
        if fc.name and (fc.state == "carried" or fc.state == "dropped") then
            local short = fc.name:match("^[^-]+") or fc.name
            if fc.state == "dropped" then
                return col .. label .. " " .. short .. " |cffffd100(dropped)|r"
            end
            local hp = fc.health and (" " .. fc.health .. "%") or ""
            return col .. label .. " " .. short .. hp .. "|r"
        end
        return MUTE_COLOR .. safeText .. "|r"
    end

    local function RefreshWsgStrip()
        if not wsgStrip:IsShown() then return end
        local v = FlagState.GetView()
        local efc = fcSegment("EFC", v.efc, HORDE_COLOR, "our flag safe")
        local ffc = fcSegment("FFC", v.ffc, ALLY_COLOR, "their flag safe")
        -- WSG-4: capture score (caps-to-win is 3) + a live 12s flag-respawn
        -- countdown after a capture, so endgame calls can time the reset.
        local score = ("%s%d|r-%s%d|r"):format(ALLY_COLOR, v.score.ally or 0, HORDE_COLOR, v.score.horde or 0)
        local respawn = v.respawn and ("  |cffffd100flag %ds|r"):format(v.respawn) or ""
        wsgStripFS:SetText(("%s    %s    %s%s"):format(efc, ffc, score, respawn))
    end

    -- Grid containers (each sized to its own grid, centered in the window)
    local abContainer = CreateFrame("Frame", nil, frame)
    abContainer:SetSize(gridWidth(abCols), gridH)
    abContainer:SetPoint("TOP", frame, "TOP", 0, gridOffsetY)
    BuildAbGrid(abContainer, size, hGap, vGap)

    local wsgContainer = CreateFrame("Frame", nil, frame)
    wsgContainer:SetSize(gridWidth(#wsgCols), gridH)
    wsgContainer:SetPoint("TOP", frame, "TOP", 0, gridOffsetY)
    BuildColGrid(wsgContainer, size, hGap, vGap, wsgCols, wsgRowActions, WsgCalloutSuffix, "WSG")
    wsgContainer:Hide()

    local avContainer = CreateFrame("Frame", nil, frame)
    avContainer:SetSize(gridWidth(#avCols), gridH)
    avContainer:SetPoint("TOP", frame, "TOP", 0, gridOffsetY)
    BuildColGrid(avContainer, size, hGap, vGap, avCols, avRowActions, nil, "AV")
    avContainer:Hide()

    local function selectTab(container)
        abContainer:Hide()
        wsgContainer:Hide()
        avContainer:Hide()
        container:Show()
        if container == abContainer then abStrip:Show(); RefreshAbStrip() else abStrip:Hide() end
        if container == wsgContainer then wsgStrip:Show(); RefreshWsgStrip() else wsgStrip:Hide() end
    end

    tabAB:SetScript("OnClick", function() selectTab(abContainer) end)
    tabWSG:SetScript("OnClick", function() selectTab(wsgContainer) end)
    tabAV:SetScript("OnClick", function() selectTab(avContainer) end)

    -- Auto-select the tab for the battleground we're standing in
    local bgContainers = { AB = abContainer, WSG = wsgContainer, AV = avContainer }
    local activeBg = GetActiveBg()
    selectTab((activeBg and bgContainers[activeBg]) or abContainer)

    local gridBottom = gridOffsetY - gridH

    -- TEAM-3: live comp-plan headline, right on the panel that's already open in
    -- a BG — the posture at a glance, no slash command. Click opens the full
    -- Battle Plan board (FC / focus / split / broadcast). A leader reads this
    -- mid-fight; they never type /bgcomp.
    local planBtn = CreateFrame("Button", nil, frame)
    planBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, gridBottom - 2)
    planBtn:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    planBtn:SetHeight(16)
    planBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    local planFS = planBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    planFS:SetAllPoints(planBtn)
    planFS:SetJustifyH("CENTER"); planFS:SetWordWrap(false)
    planBtn:SetScript("OnClick", function() PlanBoard.Toggle() end)
    planBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Battle Plan — click for FC, focus, split & broadcast")
        GameTooltip:Show()
    end)
    planBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local function RefreshPlanLine()
        local plan = BuildTeamPlan()
        if plan then
            planFS:SetText(("%sPLAN %s|r  |cffffffff%s|r"):format(
                PostureColor(plan.posture), plan.posture, plan.line))
        else
            planFS:SetText("|cffeda55fBattle Plan|r  |cff808080(click to open)|r")
        end
    end

    -- AB-5 advice line (AB tab; blank otherwise), below the plan headline.
    local adviceFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    adviceFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, gridBottom - 2 - 17)
    adviceFS:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)
    adviceFS:SetJustifyH("CENTER")
    local function RefreshAdvice() adviceFS:SetText(GetAbAdvice() or "") end

    -- Intel section (summary + enemy table + Announce) below the advice line; its
    -- summary already shows bases/resources/headcount, replacing the old footer.
    local intelBottom = IntelPanel.Populate(frame, pad, gridBottom - 2 - 17 - 18)

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
            RefreshWsgStrip()
            RefreshAdvice()
            RefreshPlanLine()
        end
    end)
    IntelPanel.Refresh()
    DevPanel.Refresh()
    RefreshAbStrip()
    RefreshWsgStrip()
    RefreshAdvice()
    RefreshPlanLine()

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
local preBriefed = false -- INTEL-3: guard so the pre-match briefing fires once per BG entry
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
        Alerts.Start() -- REL-2: sound cues (self-gated on the opt-in toggle)
        -- WSG-2/3/4: flag-state provider runs only in WSG (self-gated in Start).
        if GetActiveBg() == "WSG" then FlagState.Start() else FlagState.Stop() end
        -- INTEL-3: auto pre-match briefing from memory. Delayed so the enemy
        -- roster has populated on the scoreboard before we read it; prints LOCALLY
        -- to the leader (broadcasting to team is the explicit `/bgthreat brief`).
        if not preBriefed then
            preBriefed = true
            -- Try at 6s; if the enemy roster had not loaded yet (nothing shown),
            -- retry once at +8s. Local print only, so a retry is harmless.
            local function tryBrief(attempt)
                if not (GetActiveBg() and IntelPanel and IntelPanel.ShowBriefing) then return end
                if not IntelPanel.ShowBriefing(false) and attempt < 2 then
                    C_Timer.After(8, function() tryBrief(attempt + 1) end)
                end
            end
            C_Timer.After(6, function() tryBrief(1) end)
        end
    else
        ThreatProvider.Stop()
        FlagState.Stop()
        Alerts.Stop()
        preBriefed = false
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

