local addonName, ns = ...

-- ============================================================
-- DEFAULTS
-- These seed DzakSMeldHelperDB on first run. After that the user
-- manages the lists via the settings panel (with a Reset button
-- that restores from these defaults).
-- ============================================================

-- Spell IDs to react to. When an enemy on a nameplate starts casting one of
-- these and the cast targets the player, the counter-spell reminder icon
-- is shown. Source: AbilitiesToSMeld.txt
ns.DEFAULT_WATCHED_SPELLS = {
    [388940]  = true,
    [374352]  = true,
    [1282050] = true,
    [1244907] = true,
    [1263292] = true,
    [1260643] = true,
    [1252062] = true,
    [1258826] = true,
    [1262508] = true,
    [1263542] = true,
    [1253446] = true,
    [1216848] = true,
    [474528]  = true,
}

-- Counter-spell suggestions, gated by player race. Extend this list when
-- adding other class/race defensives.
ns.DEFAULT_COUNTER_SPELLS = {
    { race = "NightElf", spellId = 58984 }, -- Shadowmeld
}

local DETECTION_DELAY = 0.2 -- seconds to wait before re-querying cast target (mirrors TargetedSpells)
local GCD_GRACE = 1.5       -- a cooldown <= this is treated as just the GCD, i.e. ability is "ready"

-- ============================================================
-- STATE
-- ============================================================

local activeThreats = {} -- [unit] = true while a watched cast on the player is in progress
local playerName, playerRace

-- ============================================================
-- DB SEEDING
-- ============================================================

local function SeedDefaultsIfNeeded()
    DzakSMeldHelperDB = DzakSMeldHelperDB or {}
    if DzakSMeldHelperDB.enabled == nil then DzakSMeldHelperDB.enabled = true end
    if not DzakSMeldHelperDB.seeded then
        DzakSMeldHelperDB.watchedSpells = {}
        for spellId in pairs(ns.DEFAULT_WATCHED_SPELLS) do
            DzakSMeldHelperDB.watchedSpells[spellId] = true
        end
        DzakSMeldHelperDB.counterSpells = {}
        for _, entry in ipairs(ns.DEFAULT_COUNTER_SPELLS) do
            table.insert(DzakSMeldHelperDB.counterSpells, { race = entry.race, spellId = entry.spellId })
        end
        DzakSMeldHelperDB.seeded = true
    end
    DzakSMeldHelperDB.watchedSpells = DzakSMeldHelperDB.watchedSpells or {}
    DzakSMeldHelperDB.counterSpells = DzakSMeldHelperDB.counterSpells or {}
end
SeedDefaultsIfNeeded()

-- ============================================================
-- HELPERS (also exposed via ns.* for the settings panel)
-- ============================================================

function ns.IsEnabled()
    return DzakSMeldHelperDB.enabled ~= false
end

local function GetCounterSpellForCurrentPlayer()
    for _, entry in ipairs(DzakSMeldHelperDB.counterSpells) do
        if entry.race == playerRace then
            return entry
        end
    end
    return nil
end

local function IsSpellReady(spellId)
    local info = C_Spell.GetSpellCooldown(spellId)
    if not info or info.duration == 0 then
        return true
    end
    return info.duration <= GCD_GRACE
end

local function UnitIsIrrelevant(unit)
    if string.sub(unit, 1, 9) ~= "nameplate" then return true end
    if UnitInParty(unit) then return true end
    if UnitIsFriend(unit, "player") then return true end
    if not UnitAffectingCombat(unit) then return true end
    return false
end

local function GetCurrentCastSpellId(unit)
    local _, _, _, _, _, _, _, _, spellId = UnitCastingInfo(unit)
    if spellId then return spellId end
    _, _, _, _, _, _, _, spellId = UnitChannelInfo(unit)
    return spellId
end

-- ============================================================
-- ICON FRAME
-- ============================================================

local iconFrame

local function EnsureIconFrame()
    if iconFrame then return end
    local parent = ns.anchorFrame or UIParent
    iconFrame = CreateFrame("Frame", "DzakSMeldHelperIcon", parent)
    iconFrame:SetAllPoints(parent)
    iconFrame:SetFrameStrata("HIGH")
    iconFrame:Hide()

    local tex = iconFrame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim default Blizzard icon border
    iconFrame.icon = tex
end

local function ShowIconForSpell(spellId)
    EnsureIconFrame()
    iconFrame.icon:SetTexture(C_Spell.GetSpellTexture(spellId))
    iconFrame:Show()
end

local function HideIcon()
    if iconFrame then iconFrame:Hide() end
end

function ns.SetEnabled(value)
    DzakSMeldHelperDB.enabled = value and true or false
    if not value then
        wipe(activeThreats)
        HideIcon()
    end
    ns.Debug:print("settings", "enabled=", DzakSMeldHelperDB.enabled)
end

function ns.ResetWatchedDefaults()
    DzakSMeldHelperDB.watchedSpells = {}
    for spellId in pairs(ns.DEFAULT_WATCHED_SPELLS) do
        DzakSMeldHelperDB.watchedSpells[spellId] = true
    end
    ns.Debug:print("settings", "reset watched spells to defaults")
end

function ns.ResetCounterDefaults()
    DzakSMeldHelperDB.counterSpells = {}
    for _, entry in ipairs(ns.DEFAULT_COUNTER_SPELLS) do
        table.insert(DzakSMeldHelperDB.counterSpells, { race = entry.race, spellId = entry.spellId })
    end
    ns.Debug:print("settings", "reset counter spells to defaults")
end

function ns.AddWatchedSpell(spellId)
    DzakSMeldHelperDB.watchedSpells[spellId] = true
    ns.Debug:print("settings", "added watched", spellId)
end

function ns.RemoveWatchedSpell(spellId)
    DzakSMeldHelperDB.watchedSpells[spellId] = nil
    ns.Debug:print("settings", "removed watched", spellId)
end

function ns.AddCounterSpell(race, spellId)
    for _, entry in ipairs(DzakSMeldHelperDB.counterSpells) do
        if entry.race == race and entry.spellId == spellId then
            return false -- already present
        end
    end
    table.insert(DzakSMeldHelperDB.counterSpells, { race = race, spellId = spellId })
    ns.Debug:print("settings", "added counter", race, spellId)
    return true
end

function ns.RemoveCounterSpell(race, spellId)
    for i, entry in ipairs(DzakSMeldHelperDB.counterSpells) do
        if entry.race == race and entry.spellId == spellId then
            table.remove(DzakSMeldHelperDB.counterSpells, i)
            ns.Debug:print("settings", "removed counter", race, spellId)
            return true
        end
    end
    return false
end

-- ============================================================
-- DETECTION
-- ============================================================

local function TryShow(unit)
    if not ns.IsEnabled() then return end
    if UnitIsIrrelevant(unit) then return end

    local spellId = GetCurrentCastSpellId(unit)
    if not spellId then
        ns.Debug:print("detect", "skip unit=", unit, "reason=no-cast")
        return
    end

    local watched = DzakSMeldHelperDB.watchedSpells[spellId]
    local targetName = UnitSpellTargetName(unit)
    ns.Debug:print("detect", "unit=", unit, "spellId=", spellId, "watched=", watched, "target=", targetName)

    if not watched then return end
    if targetName ~= playerName then return end

    local counter = GetCounterSpellForCurrentPlayer()
    if not counter then
        ns.Debug:print("detect", "skip - no counter-spell for race=", playerRace)
        return
    end
    if not IsSpellReady(counter.spellId) then
        ns.Debug:print("detect", "skip - counter-spell", counter.spellId, "on cooldown")
        return
    end

    activeThreats[unit] = true
    ShowIconForSpell(counter.spellId)
    ns.Debug:print("show", "unit=", unit, "spellId=", spellId, "counter=", counter.spellId)
end

local function ClearUnit(unit)
    if not activeThreats[unit] then return end
    activeThreats[unit] = nil
    ns.Debug:print("clear", "unit=", unit)
    if next(activeThreats) == nil then
        HideIcon()
    end
end

-- ============================================================
-- EVENT HOOKUP
-- ============================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        playerName = UnitName("player")
        playerRace = select(2, UnitRace("player"))
        EnsureIconFrame()

        if not frame.bootstrapped then
            frame.bootstrapped = true
            frame:RegisterEvent("UNIT_SPELLCAST_START")
            frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
            frame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
            frame:RegisterEvent("UNIT_SPELLCAST_STOP")
            frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
            frame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
            frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
            frame:RegisterEvent("UNIT_TARGET")
            frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
            frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        end
        return
    end

    local unit = ...
    if not unit then return end

    if event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_EMPOWER_START"
        or event == "NAME_PLATE_UNIT_ADDED"
        or event == "UNIT_TARGET" then
        C_Timer.After(DETECTION_DELAY, function() TryShow(unit) end)
    elseif event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_EMPOWER_STOP"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "NAME_PLATE_UNIT_REMOVED" then
        ClearUnit(unit)
    end
end)

-- ============================================================
-- SLASH COMMAND
-- ============================================================

SLASH_DZAKSMELDHELPER1 = "/dsmh"
SlashCmdList["DZAKSMELDHELPER"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "" then
        if ns.OpenSettings then
            ns.OpenSettings()
        else
            print("|cffff5555DzakSMeldHelper:|r settings panel not loaded")
        end
    elseif msg == "test" then
        local counter = GetCounterSpellForCurrentPlayer()
        if counter then
            ShowIconForSpell(counter.spellId)
            print("|cff00ff00DzakSMeldHelper:|r showing test icon for spellId " .. counter.spellId)
        else
            print("|cffff0000DzakSMeldHelper:|r no counter-spell configured for your race (" .. tostring(playerRace) .. ")")
        end
    elseif msg == "hide" then
        HideIcon()
        wipe(activeThreats)
        print("|cff00ff00DzakSMeldHelper:|r hidden")
    elseif msg == "status" then
        print("|cff00ff00DzakSMeldHelper:|r status")
        print("  enabled: " .. tostring(ns.IsEnabled()))
        print("  player: " .. tostring(playerName) .. " (" .. tostring(playerRace) .. ")")
        local counter = GetCounterSpellForCurrentPlayer()
        if counter then
            print("  counter-spell: spellId " .. counter.spellId .. " ready=" .. tostring(IsSpellReady(counter.spellId)))
        else
            print("  counter-spell: none for this race")
        end
        local watched = 0
        for _ in pairs(DzakSMeldHelperDB.watchedSpells) do watched = watched + 1 end
        print("  watched spells: " .. watched)
        local active = 0
        for _ in pairs(activeThreats) do active = active + 1 end
        print("  active threats: " .. active)
    else
        print("|cff00ff00DzakSMeldHelper:|r commands:")
        print("  /dsmh            - open settings panel")
        print("  /dsmh test       - show the icon to verify position/size")
        print("  /dsmh hide       - hide the icon, clear state")
        print("  /dsmh status     - print enabled/player/counter-spell/watch-list state")
        print("  /dsmhdebug       - toggle debug tracing (on|off|<blank>=toggle)")
    end
end
