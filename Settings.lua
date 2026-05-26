local addonName, ns = ...

local UNKNOWN_ICON = 134400 -- Interface\Icons\INV_Misc_QuestionMark
local ROW_HEIGHT = 26
local ROW_GAP = 2
local LIST_WIDTH = 540
local LIST_HEIGHT = 200

-- ============================================================
-- ROOT FRAME
-- ============================================================

local optionsFrame = CreateFrame("Frame", "DzakSMeldHelperOptionsFrame", UIParent)
optionsFrame:Hide()

local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("DzakSMeldHelper")

-- ============================================================
-- MASTER ENABLE
-- ============================================================

local enableCB = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
enableCB:SetSize(24, 24)
enableCB:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
enableCB.text = enableCB:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
enableCB.text:SetPoint("LEFT", enableCB, "RIGHT", 4, 0)
enableCB.text:SetText("Enabled")

enableCB:SetScript("OnShow", function(self)
    self:SetChecked(ns.IsEnabled())
end)
enableCB:SetScript("OnClick", function(self)
    ns.SetEnabled(self:GetChecked())
end)

-- ============================================================
-- WATCHED SPELLS SECTION
-- ============================================================

local wsTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
wsTitle:SetPoint("TOPLEFT", enableCB, "BOTTOMLEFT", 0, -20)
wsTitle:SetText("Watched Spells")

local wsDesc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsDesc:SetPoint("TOPLEFT", wsTitle, "BOTTOMLEFT", 0, -4)
wsDesc:SetText("Enemy spells that trigger the icon when cast on the player.")
wsDesc:SetTextColor(0.7, 0.7, 0.7)

local wsInput = CreateFrame("EditBox", nil, optionsFrame, "InputBoxTemplate")
wsInput:SetSize(120, 22)
wsInput:SetPoint("TOPLEFT", wsDesc, "BOTTOMLEFT", 8, -8)
wsInput:SetAutoFocus(false)
wsInput:SetNumeric(true)
wsInput:SetMaxLetters(8)
wsInput:SetTextInsets(4, 4, 0, 0)

local wsInputLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsInputLabel:SetPoint("BOTTOMLEFT", wsInput, "TOPLEFT", -4, 2)
wsInputLabel:SetText("Spell ID")

local wsAdd = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
wsAdd:SetSize(70, 22)
wsAdd:SetPoint("LEFT", wsInput, "RIGHT", 8, 0)
wsAdd:SetText("Add")

local wsReset = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
wsReset:SetSize(110, 22)
wsReset:SetPoint("LEFT", wsAdd, "RIGHT", 8, 0)
wsReset:SetText("Reset Defaults")

local wsScroll = CreateFrame("ScrollFrame", nil, optionsFrame, "UIPanelScrollFrameTemplate")
wsScroll:SetSize(LIST_WIDTH, LIST_HEIGHT)
wsScroll:SetPoint("TOPLEFT", wsInput, "BOTTOMLEFT", -8, -10)

local wsBg = wsScroll:CreateTexture(nil, "BACKGROUND")
wsBg:SetAllPoints()
wsBg:SetColorTexture(0, 0, 0, 0.3)

local wsContent = CreateFrame("Frame", nil, wsScroll)
wsContent:SetSize(LIST_WIDTH - 20, 1)
wsScroll:SetScrollChild(wsContent)

-- ============================================================
-- COUNTER SPELLS SECTION
-- ============================================================

local csTitle = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
csTitle:SetPoint("TOPLEFT", wsScroll, "BOTTOMLEFT", 8, -24)
csTitle:SetText("Counter Spells")

local csDesc = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
csDesc:SetPoint("TOPLEFT", csTitle, "BOTTOMLEFT", 0, -4)
csDesc:SetText("Defensive abilities suggested when a watched spell is incoming, gated by race.")
csDesc:SetTextColor(0.7, 0.7, 0.7)

local csSpellInput = CreateFrame("EditBox", nil, optionsFrame, "InputBoxTemplate")
csSpellInput:SetSize(120, 22)
csSpellInput:SetPoint("TOPLEFT", csDesc, "BOTTOMLEFT", 8, -8)
csSpellInput:SetAutoFocus(false)
csSpellInput:SetNumeric(true)
csSpellInput:SetMaxLetters(8)
csSpellInput:SetTextInsets(4, 4, 0, 0)

local csSpellLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
csSpellLabel:SetPoint("BOTTOMLEFT", csSpellInput, "TOPLEFT", -4, 2)
csSpellLabel:SetText("Spell ID")

local csRaceInput = CreateFrame("EditBox", nil, optionsFrame, "InputBoxTemplate")
csRaceInput:SetSize(140, 22)
csRaceInput:SetPoint("LEFT", csSpellInput, "RIGHT", 24, 0)
csRaceInput:SetAutoFocus(false)
csRaceInput:SetMaxLetters(32)
csRaceInput:SetTextInsets(4, 4, 0, 0)

local csRaceLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
csRaceLabel:SetPoint("BOTTOMLEFT", csRaceInput, "TOPLEFT", -4, 2)
csRaceLabel:SetText("Race (e.g. NightElf)")

local csAdd = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
csAdd:SetSize(70, 22)
csAdd:SetPoint("LEFT", csRaceInput, "RIGHT", 8, 0)
csAdd:SetText("Add")

local csReset = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
csReset:SetSize(110, 22)
csReset:SetPoint("LEFT", csAdd, "RIGHT", 8, 0)
csReset:SetText("Reset Defaults")

local csScroll = CreateFrame("ScrollFrame", nil, optionsFrame, "UIPanelScrollFrameTemplate")
csScroll:SetSize(LIST_WIDTH, LIST_HEIGHT)
csScroll:SetPoint("TOPLEFT", csSpellInput, "BOTTOMLEFT", -8, -10)

local csBg = csScroll:CreateTexture(nil, "BACKGROUND")
csBg:SetAllPoints()
csBg:SetColorTexture(0, 0, 0, 0.3)

local csContent = CreateFrame("Frame", nil, csScroll)
csContent:SetSize(LIST_WIDTH - 20, 1)
csScroll:SetScrollChild(csContent)

-- ============================================================
-- ROW BUILDERS (with simple pools)
-- ============================================================

local function FormatSpellLine(spellId, prefix)
    local info = C_Spell.GetSpellInfo(spellId)
    local name = info and info.name or "(unknown)"
    if prefix then
        return string.format("%s  |cffffff00%d|r  %s", prefix, spellId, name), info and info.iconID or UNKNOWN_ICON
    end
    return string.format("|cffffff00%d|r  %s", spellId, name), info and info.iconID or UNKNOWN_ICON
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(LIST_WIDTH - 24, ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetPoint("RIGHT", -36, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.remove:SetSize(28, 22)
    row.remove:SetPoint("RIGHT", -2, 0)
    row.remove:SetText("X")

    return row
end

local wsRowPool = {}
local csRowPool = {}

local function RebuildWatchedList()
    for _, row in ipairs(wsRowPool) do row:Hide() end

    local sorted = {}
    for spellId in pairs(DzakSMeldHelperDB.watchedSpells) do
        table.insert(sorted, spellId)
    end
    table.sort(sorted)

    for i, spellId in ipairs(sorted) do
        local row = wsRowPool[i]
        if not row then
            row = MakeRow(wsContent)
            wsRowPool[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_HEIGHT + ROW_GAP))
        row:Show()

        local text, iconID = FormatSpellLine(spellId, nil)
        row.icon:SetTexture(iconID)
        row.label:SetText(text)
        row.remove:SetScript("OnClick", function()
            ns.RemoveWatchedSpell(spellId)
            RebuildWatchedList()
        end)
    end

    wsContent:SetHeight(math.max(1, #sorted * (ROW_HEIGHT + ROW_GAP)))
end

local function RebuildCounterList()
    for _, row in ipairs(csRowPool) do row:Hide() end

    local entries = DzakSMeldHelperDB.counterSpells

    for i, entry in ipairs(entries) do
        local row = csRowPool[i]
        if not row then
            row = MakeRow(csContent)
            csRowPool[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW_HEIGHT + ROW_GAP))
        row:Show()

        local prefix = string.format("|cff88ddff[%s]|r", entry.race or "?")
        local text, iconID = FormatSpellLine(entry.spellId, prefix)
        row.icon:SetTexture(iconID)
        row.label:SetText(text)

        local race, spellId = entry.race, entry.spellId
        row.remove:SetScript("OnClick", function()
            ns.RemoveCounterSpell(race, spellId)
            RebuildCounterList()
        end)
    end

    csContent:SetHeight(math.max(1, #entries * (ROW_HEIGHT + ROW_GAP)))
end

-- ============================================================
-- ADD / RESET HANDLERS
-- ============================================================

local function AddWatchedFromInput()
    local spellId = tonumber(wsInput:GetText())
    if not spellId or spellId <= 0 then
        print("|cffff5555DzakSMeldHelper:|r invalid spell ID")
        return
    end
    ns.AddWatchedSpell(spellId)
    wsInput:SetText("")
    wsInput:ClearFocus()
    RebuildWatchedList()
end

wsAdd:SetScript("OnClick", AddWatchedFromInput)
wsInput:SetScript("OnEnterPressed", AddWatchedFromInput)
wsInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

wsReset:SetScript("OnClick", function()
    ns.ResetWatchedDefaults()
    RebuildWatchedList()
end)

local function AddCounterFromInput()
    local spellId = tonumber(csSpellInput:GetText())
    local race = (csRaceInput:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if not spellId or spellId <= 0 then
        print("|cffff5555DzakSMeldHelper:|r invalid spell ID")
        return
    end
    if race == "" then
        print("|cffff5555DzakSMeldHelper:|r race is required (e.g. NightElf)")
        return
    end
    if not ns.AddCounterSpell(race, spellId) then
        print("|cffff5555DzakSMeldHelper:|r that race/spellId combo is already in the list")
        return
    end
    csSpellInput:SetText("")
    csSpellInput:ClearFocus()
    csRaceInput:ClearFocus()
    RebuildCounterList()
end

csAdd:SetScript("OnClick", AddCounterFromInput)
csSpellInput:SetScript("OnEnterPressed", AddCounterFromInput)
csRaceInput:SetScript("OnEnterPressed", AddCounterFromInput)
csSpellInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
csRaceInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

csReset:SetScript("OnClick", function()
    ns.ResetCounterDefaults()
    RebuildCounterList()
end)

-- ============================================================
-- DEFAULT RACE INPUT VALUE = PLAYER'S RACE
-- ============================================================

optionsFrame:SetScript("OnShow", function()
    enableCB:SetChecked(ns.IsEnabled())
    if csRaceInput:GetText() == "" then
        csRaceInput:SetText(select(2, UnitRace("player")) or "")
    end
    RebuildWatchedList()
    RebuildCounterList()
end)

-- ============================================================
-- BLIZZARD SETTINGS REGISTRATION
-- ============================================================

local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, "DzakSMeldHelper")
Settings.RegisterAddOnCategory(category)

ns.OpenSettings = function()
    Settings.OpenToCategory(category:GetID())
end
