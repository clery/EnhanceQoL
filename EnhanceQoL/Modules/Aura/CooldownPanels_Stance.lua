local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.CooldownPanels = addon.Aura.CooldownPanels or {}
local CooldownPanels = addon.Aura.CooldownPanels

CooldownPanels.Stance = CooldownPanels.Stance or {}
local Stance = CooldownPanels.Stance

local STEALTH_ICON = "Interface\\Icons\\Ability_Stealth"
local DEFAULT_STEALTH_LABEL = _G.STEALTH or "Stealth"
local DEFAULT_STANCE_LABEL = _G.STANCE or "Stance"
local DEFAULT_BEAR_LABEL = _G.BEAR_FORM or "Bear Form"
local DEFAULT_CAT_LABEL = _G.CAT_FORM or "Cat Form"
local DEFAULT_MOONKIN_LABEL = _G.MOONKIN_FORM or "Moonkin Form"
local DEFAULT_DEVOTION_AURA_LABEL = _G.DEVOTION_AURA or "Devotion Aura"
local DEFAULT_CONCENTRATION_AURA_LABEL = _G.CONCENTRATION_AURA or "Concentration Aura"
local DEFAULT_CRUSADER_AURA_LABEL = _G.CRUSADER_AURA or "Crusader Aura"
local DEFAULT_BATTLE_STANCE_LABEL = _G.BATTLE_STANCE or "Battle Stance"
local DEFAULT_DEFENSIVE_STANCE_LABEL = _G.DEFENSIVE_STANCE or "Defensive Stance"
local DEFAULT_BERSERKER_STANCE_LABEL = _G.BERSERKER_STANCE or "Berserker Stance"
local BEAR_ICON = "Interface\\Icons\\Ability_Racial_BearForm"
local CAT_ICON = "Interface\\Icons\\Ability_Druid_CatForm"
local MOONKIN_ICON = 136036
local DEVOTION_AURA_ICON = "Interface\\Icons\\Spell_Holy_DevotionAura"
local CONCENTRATION_AURA_ICON = "Interface\\Icons\\Spell_Holy_MindSooth"
local CRUSADER_AURA_ICON = "Interface\\Icons\\Spell_Holy_CrusaderAura"
local BATTLE_STANCE_ICON = "Interface\\Icons\\Ability_Warrior_OffensiveStance"
local DEFENSIVE_STANCE_ICON = "Interface\\Icons\\Ability_Warrior_DefensiveStance"
local BERSERKER_STANCE_ICON = "Interface\\Icons\\Ability_Racial_Avatar"

local STANCE_DEFINITIONS = {
	DRUID_STEALTH = {
		id = "DRUID_STEALTH",
		classTag = "DRUID",
		stanceKey = "STEALTH",
		spellID = 5215, -- Prowl
		label = DEFAULT_STEALTH_LABEL,
		icon = STEALTH_ICON,
		condition = "[stealth] show; hide",
	},
	DRUID_BEAR = {
		id = "DRUID_BEAR",
		classTag = "DRUID",
		stanceKey = "BEAR",
		spellID = 5487, -- Bear Form
		label = DEFAULT_BEAR_LABEL,
		icon = BEAR_ICON,
		condition = "[form:1] show; hide",
	},
	DRUID_CAT = {
		id = "DRUID_CAT",
		classTag = "DRUID",
		stanceKey = "CAT",
		spellID = 768, -- Cat Form
		label = DEFAULT_CAT_LABEL,
		icon = CAT_ICON,
		condition = "[form:2] show; hide",
	},
	DRUID_MOONKIN = {
		id = "DRUID_MOONKIN",
		classTag = "DRUID",
		stanceKey = "MOONKIN",
		spellID = 24858, -- Moonkin Form
		label = DEFAULT_MOONKIN_LABEL,
		icon = MOONKIN_ICON,
		condition = "[form:4] show; hide",
	},
	ROGUE_STEALTH = {
		id = "ROGUE_STEALTH",
		classTag = "ROGUE",
		stanceKey = "STEALTH",
		spellID = 1784, -- Stealth
		label = DEFAULT_STEALTH_LABEL,
		icon = STEALTH_ICON,
		condition = "[stealth] show; hide",
	},
	PALADIN_DEVOTION_AURA = {
		id = "PALADIN_DEVOTION_AURA",
		classTag = "PALADIN",
		stanceKey = "DEVOTION_AURA",
		spellID = 465, -- Devotion Aura
		label = DEFAULT_DEVOTION_AURA_LABEL,
		icon = DEVOTION_AURA_ICON,
		condition = "[stance:2] show; hide",
	},
	PALADIN_CONCENTRATION_AURA = {
		id = "PALADIN_CONCENTRATION_AURA",
		classTag = "PALADIN",
		stanceKey = "CONCENTRATION_AURA",
		spellID = 317920, -- Concentration Aura
		label = DEFAULT_CONCENTRATION_AURA_LABEL,
		icon = CONCENTRATION_AURA_ICON,
		condition = "[stance:3] show; hide",
	},
	PALADIN_CRUSADER_AURA = {
		id = "PALADIN_CRUSADER_AURA",
		classTag = "PALADIN",
		stanceKey = "CRUSADER_AURA",
		spellID = 32223, -- Crusader Aura
		label = DEFAULT_CRUSADER_AURA_LABEL,
		icon = CRUSADER_AURA_ICON,
		condition = "[stance:1] show; hide",
	},
	WARRIOR_DEFENSIVE_STANCE = {
		id = "WARRIOR_DEFENSIVE_STANCE",
		classTag = "WARRIOR",
		stanceKey = "DEFENSIVE_STANCE",
		spellID = 386208,
		label = DEFAULT_DEFENSIVE_STANCE_LABEL,
		icon = DEFENSIVE_STANCE_ICON,
		condition = "[stance:1] show; hide",
	},
	WARRIOR_BATTLE_STANCE = {
		id = "WARRIOR_BATTLE_STANCE",
		classTag = "WARRIOR",
		stanceKey = "BATTLE_STANCE",
		spellID = 386164,
		label = DEFAULT_BATTLE_STANCE_LABEL,
		icon = BATTLE_STANCE_ICON,
		condition = "[noknown:386196,stance:2] show; hide",
	},
	WARRIOR_BERSERKER_STANCE = {
		id = "WARRIOR_BERSERKER_STANCE",
		classTag = "WARRIOR",
		stanceKey = "BERSERKER_STANCE",
		spellID = 386196,
		label = DEFAULT_BERSERKER_STANCE_LABEL,
		icon = BERSERKER_STANCE_ICON,
		condition = "[known:386196,stance:2] show; hide",
	},
}

local function getTrackerRuntime()
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.stanceTracker = runtime.stanceTracker or {
		drivers = {},
		states = {},
	}
	return runtime.stanceTracker
end

local function getPlayerClassTag()
	local classTag = addon.variables and addon.variables.unitClass
	if type(classTag) == "string" and classTag ~= "" then return classTag end
	if UnitClass then
		local _, english = UnitClass("player")
		if type(english) == "string" and english ~= "" then return english end
	end
	return nil
end

local function getClassLabel(classTag)
	if type(classTag) ~= "string" or classTag == "" then return classTag or "" end
	if _G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[classTag] then return _G.LOCALIZED_CLASS_NAMES_MALE[classTag] end
	if _G.LOCALIZED_CLASS_NAMES_FEMALE and _G.LOCALIZED_CLASS_NAMES_FEMALE[classTag] then return _G.LOCALIZED_CLASS_NAMES_FEMALE[classTag] end
	return classTag
end

local function normalizeSortLabel(value)
	if type(value) ~= "string" then return "" end
	if strlower then return strlower(value) end
	return string.lower(value)
end

local function getSpellDisplayData(spellID)
	local sid = tonumber(spellID)
	if not sid then return nil, nil end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(sid)
		if info then
			local name = info.name
			local icon = info.iconID or info.originalIconID
			if type(name) == "string" and name ~= "" then return name, icon end
			if icon then return nil, icon end
		end
	end
	if GetSpellInfo then
		local name, _, icon = GetSpellInfo(sid)
		if type(name) == "string" and name ~= "" then return name, icon end
		if icon then return nil, icon end
	end
	if C_Spell and C_Spell.GetSpellTexture then
		local icon = C_Spell.GetSpellTexture(sid)
		if icon then return nil, icon end
	end
	return nil, nil
end

local function getDefinitionLabel(def)
	if type(def) ~= "table" then return DEFAULT_STEALTH_LABEL end
	local name = def.spellID and select(1, getSpellDisplayData(def.spellID)) or nil
	if type(name) == "string" and name ~= "" then return name end
	return def.label or DEFAULT_STEALTH_LABEL
end

local function getDefinitionIcon(def)
	if type(def) ~= "table" then return STEALTH_ICON end
	local icon = def.spellID and select(2, getSpellDisplayData(def.spellID)) or nil
	if icon then return icon end
	return def.icon or STEALTH_ICON
end

local function normalizeStanceKey(value)
	if type(value) == "table" then
		local stanceID = value.stanceID or value.stanceId
		if type(stanceID) == "string" and stanceID ~= "" then value = stanceID end
		if type(value) == "table" then
			local classTag = value.stanceClass
			local stanceKey = value.stanceKey
			if type(classTag) == "string" and type(stanceKey) == "string" and classTag ~= "" and stanceKey ~= "" then value = classTag .. "_" .. stanceKey end
		end
	end
	if type(value) ~= "string" or value == "" then return nil end
	if strtrim then value = strtrim(value) end
	if value == "" then return nil end
	value = string.upper(value)
	if STANCE_DEFINITIONS[value] then return value end
	return nil
end

local function getFallbackClassTag(value)
	if type(value) == "table" then
		local stanceClass = value.stanceClass or value.classTag
		if type(stanceClass) == "string" and stanceClass ~= "" then return string.upper(stanceClass) end
		local stanceID = value.stanceID or value.stanceId
		if type(stanceID) == "string" and stanceID ~= "" then value = stanceID end
	end
	if type(value) ~= "string" or value == "" then return nil end
	if strtrim then value = strtrim(value) end
	if value == "" then return nil end
	value = string.upper(value)
	local classTag = value:match("^([A-Z]+)_")
	if type(classTag) == "string" and classTag ~= "" then return classTag end
	return nil
end

local function setTrackedState(stanceID, active)
	if type(stanceID) ~= "string" or stanceID == "" then return end
	local tracker = getTrackerRuntime()
	local normalized = active == true
	if tracker.states[stanceID] == normalized then return end
	tracker.states[stanceID] = normalized
	if CooldownPanels and CooldownPanels.RequestUpdate then CooldownPanels:RequestUpdate("Stance:" .. stanceID) end
end

local function ensureStateDriver(def)
	local tracker = getTrackerRuntime()
	local driver = tracker.drivers[def.id]
	if driver then return driver end
	driver = CreateFrame("Frame")
	driver:Hide()
	driver._eqolStanceID = def.id
	driver:SetScript("OnShow", function(self) setTrackedState(self._eqolStanceID, true) end)
	driver:SetScript("OnHide", function(self) setTrackedState(self._eqolStanceID, false) end)
	tracker.drivers[def.id] = driver
	tracker.states[def.id] = false
	return driver
end

local function registerDriversNow()
	if not RegisterStateDriver then return false end
	local tracker = getTrackerRuntime()
	local playerClass = getPlayerClassTag()
	for _, def in pairs(STANCE_DEFINITIONS) do
		local condition = type(def.condition) == "string" and def.condition or nil
		local canUseStateDriver = condition and condition ~= ""
		if def.classTag == playerClass and canUseStateDriver then
			local driver = ensureStateDriver(def)
			if driver._eqolRegistered ~= true or driver._eqolCondition ~= condition then
				if UnregisterStateDriver then pcall(UnregisterStateDriver, driver, "visibility") end
				RegisterStateDriver(driver, "visibility", condition)
				driver._eqolRegistered = true
				driver._eqolCondition = condition
			end
			setTrackedState(def.id, driver:IsShown())
		else
			local driver = tracker.drivers[def.id]
			if driver and driver._eqolRegistered == true and UnregisterStateDriver then pcall(UnregisterStateDriver, driver, "visibility") end
			if driver then
				driver._eqolRegistered = nil
				driver._eqolCondition = nil
				driver:Hide()
			end
			setTrackedState(def.id, false)
		end
	end
	tracker.pendingRegister = nil
	return true
end

local function scheduleRegisterAfterCombat()
	local tracker = getTrackerRuntime()
	tracker.pendingRegister = true
	if tracker.registerWatcher then
		tracker.registerWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:SetScript("OnEvent", function(self)
		if InCombatLockdown and InCombatLockdown() then return end
		local rt = getTrackerRuntime()
		if rt.pendingRegister then registerDriversNow() end
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end)
	tracker.registerWatcher = watcher
end

function Stance:EnsureStateDrivers()
	if not RegisterStateDriver then return false end
	if InCombatLockdown and InCombatLockdown() then
		scheduleRegisterAfterCombat()
		return false
	end
	return registerDriversNow()
end

function Stance:GetDefinition(value)
	local key = normalizeStanceKey(value)
	if not key then return nil end
	return STANCE_DEFINITIONS[key]
end

function Stance:GetMenuEntries()
	local grouped = {}
	for _, def in pairs(STANCE_DEFINITIONS) do
		local classTag = def and def.classTag
		if type(classTag) == "string" and classTag ~= "" then
			local classGroup = grouped[classTag]
			if not classGroup then
				classGroup = {
					classTag = classTag,
					label = getClassLabel(classTag),
					entries = {},
				}
				grouped[classTag] = classGroup
			end
			classGroup.entries[#classGroup.entries + 1] = {
				id = def.id,
				label = getDefinitionLabel(def),
				icon = getDefinitionIcon(def),
			}
		end
	end

	local menu = {}
	for _, classGroup in pairs(grouped) do
		table.sort(classGroup.entries, function(a, b)
			local labelA = normalizeSortLabel(a.label)
			local labelB = normalizeSortLabel(b.label)
			if labelA == labelB then return tostring(a.id or "") < tostring(b.id or "") end
			return labelA < labelB
		end)
		if #classGroup.entries > 0 then menu[#menu + 1] = classGroup end
	end

	table.sort(menu, function(a, b)
		local labelA = normalizeSortLabel(a.label)
		local labelB = normalizeSortLabel(b.label)
		if labelA == labelB then return tostring(a.classTag or "") < tostring(b.classTag or "") end
		return labelA < labelB
	end)

	return menu
end

function Stance:GetDefaultOverrides()
	return {
		alwaysShow = false,
		showWhenMissing = false,
		showCooldown = false,
		showCooldownText = false,
		glowReady = false,
		soundReady = false,
	}
end

function Stance:NormalizeEntry(entry)
	if type(entry) ~= "table" then return nil end
	local def = self:GetDefinition(entry)
	if not def then return nil end
	entry.type = "STANCE"
	entry.stanceID = def.id
	entry.stanceClass = def.classTag
	entry.stanceKey = def.stanceKey or "STANCE"
	entry.showWhenMissing = entry.showWhenMissing == true
	return def
end

function Stance:GetEntryName(entry)
	local def = self:GetDefinition(entry)
	if not def then return nil end
	return string.format("%s: %s", getClassLabel(def.classTag), getDefinitionLabel(def))
end

function Stance:GetEntryIcon(entry)
	local def = self:GetDefinition(entry)
	if not def then return nil end
	return getDefinitionIcon(def)
end

function Stance:IsEntryActive(entry)
	local def = self:GetDefinition(entry)
	local playerClass = getPlayerClassTag()
	local entryClass = (def and def.classTag) or getFallbackClassTag(entry)
	if entryClass and playerClass ~= entryClass then return false end
	if not def then return false end

	local condition = type(def.condition) == "string" and def.condition or nil
	if not condition or condition == "" then return false end

	self:EnsureStateDrivers()

	local tracker = getTrackerRuntime()
	local state = tracker.states[def.id]
	if state ~= nil then return state == true end

	if SecureCmdOptionParse then return SecureCmdOptionParse(condition) == "show" end
	if IsStealthed then return IsStealthed() == true end
	return false
end

function Stance:IsEntryRelevant(entry)
	local def = self:GetDefinition(entry)
	local playerClass = getPlayerClassTag()
	local entryClass = (def and def.classTag) or getFallbackClassTag(entry)
	if entryClass then return playerClass == entryClass end
	return def ~= nil and playerClass == def.classTag
end

function CooldownPanels:GetStanceMenuEntries() return Stance:GetMenuEntries() end
function CooldownPanels:GetStanceDefinition(value) return Stance:GetDefinition(value) end
function CooldownPanels:GetStanceDefaultOverrides() return Stance:GetDefaultOverrides() end
function CooldownPanels:NormalizeStanceEntry(entry) return Stance:NormalizeEntry(entry) end
function CooldownPanels:GetStanceEntryName(entry) return Stance:GetEntryName(entry) end
function CooldownPanels:GetStanceEntryIcon(entry) return Stance:GetEntryIcon(entry) end
function CooldownPanels:IsStanceEntryActive(entry) return Stance:IsEntryActive(entry) end
function CooldownPanels:IsStanceEntryRelevant(entry) return Stance:IsEntryRelevant(entry) end
function CooldownPanels:InitStanceTracker() return Stance:EnsureStateDrivers() end

function CooldownPanels:GetStanceTypeLabel() return DEFAULT_STANCE_LABEL end
