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
local Helper = CooldownPanels.helper
local Keybinds = Helper.Keybinds
local Api = Helper.Api or {}
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Aura")
local LSM = LibStub("LibSharedMedia-3.0", true)
local Glow = addon.Glow
local GetVisibilityRuleMetadata = addon.functions and addon.functions.GetVisibilityRuleMetadata
local Masque

CooldownPanels.ENTRY_TYPE = {
	SPELL = "SPELL",
	ITEM = "ITEM",
	SLOT = "SLOT",
	STANCE = "STANCE",
	MACRO = "MACRO",
	CDM_AURA = "CDM_AURA",
}

CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE = CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE or {
	HIDE = "HIDE",
	SHOW = "SHOW",
	DESATURATE = "DESATURATE",
}

CooldownPanels.POWER_TYPE_TOKEN_BY_ID = CooldownPanels.POWER_TYPE_TOKEN_BY_ID
	or {
		[0] = "MANA",
		[1] = "RAGE",
		[2] = "FOCUS",
		[3] = "ENERGY",
		[4] = "COMBO_POINTS",
		[5] = "RUNES",
		[6] = "RUNIC_POWER",
		[7] = "SOUL_SHARDS",
		[8] = "LUNAR_POWER",
		[9] = "HOLY_POWER",
		[10] = "ALTERNATE",
		[11] = "MAELSTROM",
		[12] = "CHI",
		[13] = "INSANITY",
		[17] = "FURY",
		[18] = "PAIN",
		[19] = "ESSENCE",
	}

CooldownPanels.itemHighestRankByID = CooldownPanels.itemHighestRankByID
	or {
		-- Potion of Recklessness (rank1 -> rank2)
		[241289] = { 241289, 241288 },
		[241288] = { 241289, 241288 },
		-- Light's Potential (rank1 -> rank2)
		[241309] = { 241309, 241308 },
		[241308] = { 241309, 241308 },
		-- Lightfused Mana Potion (rank1 -> rank2)
		[241301] = { 241301, 241300 },
		[241300] = { 241301, 241300 },
	}

CooldownPanels.spellVariantGroupByID = CooldownPanels.spellVariantGroupByID or {}

CooldownPanels.staticSpellVariantGroups = CooldownPanels.staticSpellVariantGroups
	or {
		-- Blood Elf racial with class-specific spellIDs.
		{ 202719, 50613, 80483, 28730, 129597, 155145, 232633, 25046, 69179 },
		-- Orc racial with physical / hybrid / intellect variants.
		{ 20572, 33697, 33702 },
		-- Draenei racial with class-specific spellIDs.
		{ 59545, 59543, 59548, 121093, 59542, 59544, 59547, 28880, 370626, 416250 },
	}

function CooldownPanels:RegisterItemRankGroup(rankList)
	if type(rankList) ~= "table" then return false end
	local ids = {}
	for i = 1, #rankList do
		local itemID = tonumber(rankList[i])
		if itemID and itemID > 0 then ids[#ids + 1] = itemID end
	end
	if #ids < 2 then return false end
	local rankMap = self.itemHighestRankByID
	if type(rankMap) ~= "table" then
		rankMap = {}
		self.itemHighestRankByID = rankMap
	end
	for i = 1, #ids do
		rankMap[ids[i]] = ids
	end
	return true
end

function CooldownPanels:RegisterSpellVariantGroup(variantList)
	if type(variantList) ~= "table" then return false end
	local ids = {}
	local seen = {}
	for i = 1, #variantList do
		local spellID = tonumber(variantList[i])
		if spellID and spellID > 0 and not seen[spellID] then
			seen[spellID] = true
			ids[#ids + 1] = spellID
		end
	end
	if #ids < 2 then return false end
	local groupMap = self.spellVariantGroupByID
	if type(groupMap) ~= "table" then
		groupMap = {}
		self.spellVariantGroupByID = groupMap
	end
	for i = 1, #ids do
		groupMap[ids[i]] = ids
	end
	return true
end

function CooldownPanels:IngestRankGroupsByRank(entries, keyPrefix)
	if type(entries) ~= "table" then return false end
	local groups = {}
	for typeKey, list in pairs(entries) do
		if type(list) == "table" then
			for _, entry in ipairs(list) do
				local itemID = tonumber(entry and entry.id)
				local rank = tonumber(entry and entry.rank)
				if itemID and itemID > 0 and rank and rank > 0 then
					local rawKey = type(entry.key) == "string" and entry.key or tostring(itemID)
					local baseKey = rawKey:gsub("%d+$", "")
					local requiredLevel = tonumber(entry.requiredLevel) or 0
					local groupKey = string.format("%s:%s:%d:%s", keyPrefix or "rank", baseKey, requiredLevel, tostring(typeKey))
					groups[groupKey] = groups[groupKey] or {}
					groups[groupKey][rank] = itemID
				end
			end
		end
	end
	local added = false
	for _, byRank in pairs(groups) do
		local ordered = {}
		for rank = 1, 9 do
			local itemID = byRank[rank]
			if itemID then ordered[#ordered + 1] = itemID end
		end
		if #ordered >= 2 and self:RegisterItemRankGroup(ordered) then added = true end
	end
	return added
end

function CooldownPanels:IngestHealthPotionRankGroups()
	local healthList = addon.Health and addon.Health.healthList
	if type(healthList) ~= "table" then return false end
	local groups = {}
	for _, entry in ipairs(healthList) do
		local itemID = tonumber(entry and entry.id)
		local rawKey = type(entry and entry.key) == "string" and entry.key or nil
		if itemID and itemID > 0 and rawKey then
			local baseKey = rawKey:gsub("%d+$", "")
			if baseKey == "" then baseKey = rawKey end
			local requiredLevel = tonumber(entry.requiredLevel) or 0
			local groupKey = string.format("health:%s:%d", baseKey, requiredLevel)
			groups[groupKey] = groups[groupKey] or {}
			groups[groupKey][#groups[groupKey] + 1] = {
				id = itemID,
				heal = tonumber(entry.heal),
				rankSuffix = tonumber(rawKey:match("(%d+)$")),
			}
		end
	end
	local added = false
	for _, items in pairs(groups) do
		if #items >= 2 then
			table.sort(items, function(a, b)
				local aHeal = tonumber(a and a.heal)
				local bHeal = tonumber(b and b.heal)
				if aHeal and bHeal and aHeal ~= bHeal then return aHeal < bHeal end
				if aHeal and not bHeal then return true end
				if bHeal and not aHeal then return false end
				local aRank = tonumber(a and a.rankSuffix)
				local bRank = tonumber(b and b.rankSuffix)
				if aRank and bRank and aRank ~= bRank then return aRank < bRank end
				return (tonumber(a and a.id) or 0) < (tonumber(b and b.id) or 0)
			end)
		end
		local ordered = {}
		local seen = {}
		for i = 1, #items do
			local itemID = tonumber(items[i] and items[i].id)
			if itemID and itemID > 0 and not seen[itemID] then
				seen[itemID] = true
				ordered[#ordered + 1] = itemID
			end
		end
		if #ordered >= 2 and self:RegisterItemRankGroup(ordered) then added = true end
	end
	return added
end

function CooldownPanels:IngestFlaskRankGroups()
	local flasks = addon.Flasks
	if type(flasks) ~= "table" then return false end
	local added = false
	if self:IngestRankGroupsByRank(flasks.typeFlasks, "flask") then added = true end
	if self:IngestRankGroupsByRank(flasks.fleetingTypeFlasks, "flask_fleeting") then added = true end
	return added
end

function CooldownPanels:EnsureFoodRankGroupsLoaded()
	self.runtime = self.runtime or {}
	local state = self.runtime.itemRankSourcesLoaded
	if type(state) ~= "table" then
		state = { health = false, flasks = false }
		self.runtime.itemRankSourcesLoaded = state
	end
	if not state.health and self:IngestHealthPotionRankGroups() then state.health = true end
	if not state.flasks and self:IngestFlaskRankGroups() then state.flasks = true end
end

function CooldownPanels:GetCanonicalItemRankID(itemID)
	self:EnsureFoodRankGroupsLoaded()
	local numericID = tonumber(itemID)
	if not numericID then return nil, false, nil end
	local rankMap = CooldownPanels.itemHighestRankByID
	local group = rankMap and rankMap[numericID]
	if not group or type(group) ~= "table" or #group == 0 then return numericID, false, nil end
	local lowestRankID = tonumber(group[1]) or numericID
	return lowestRankID, lowestRankID ~= numericID, group
end

function CooldownPanels.ResolveEntryItemID(entry, itemID)
	CooldownPanels:EnsureFoodRankGroupsLoaded()
	local numericID = tonumber(itemID)
	if not numericID then return nil end
	if entry and entry.type == "ITEM" and addon.Health and addon.Health.functions and addon.Health.functions.resolveTrackedHealthstoneItem then
		numericID = addon.Health.functions.resolveTrackedHealthstoneItem(numericID) or numericID
	end
	if not (entry and entry.type == "ITEM" and entry.useHighestRank == true) then return numericID end
	local rankMap = CooldownPanels.itemHighestRankByID
	local group = rankMap and rankMap[numericID]
	if not group then return numericID end
	local runtime = CooldownPanels.runtime
	local itemCountCache = runtime and runtime.itemCountCache or nil
	local missingCache = false
	if itemCountCache then
		for i = #group, 1, -1 do
			local candidateID = tonumber(group[i])
			if candidateID then
				local cached = itemCountCache[candidateID]
				if cached and cached.count ~= nil then
					if cached.count > 0 then return candidateID end
				else
					missingCache = true
				end
			end
		end
		if not missingCache then return numericID end
	end
	for i = #group, 1, -1 do
		local candidateID = group[i]
		local count = Api.GetItemCount(candidateID, false, false) or 0
		if count > 0 then return candidateID end
	end
	return numericID
end

_G["BINDING_NAME_EQOL_TOGGLE_COOLDOWN_PANELS"] = L["CooldownPanelBindingToggle"] or "Toggle Cooldown Panel Editor"

CooldownPanels.runtime = CooldownPanels.runtime or {}

local curveDesat = C_CurveUtil.CreateCurve()
curveDesat:SetType(Enum.LuaCurveType.Step)
curveDesat:AddPoint(0, 0)
curveDesat:AddPoint(0.1, 1)

local curveAlpha = C_CurveUtil.CreateCurve()
curveAlpha:SetType(Enum.LuaCurveType.Step)
curveAlpha:AddPoint(0, 1)
curveAlpha:AddPoint(0.1, 0)

function CooldownPanels:NormalizeCDMAuraAlwaysShowMode(value, fallback)
	local mode = type(value) == "string" and string.upper(value) or nil
	local values = self.CDM_AURA_ALWAYS_SHOW_MODE or {}
	if mode == values.SHOW or mode == values.DESATURATE or mode == values.HIDE then return mode end
	return fallback or values.HIDE or "HIDE"
end

function CooldownPanels:GetCDMAuraAlwaysShowOptions()
	local values = self.CDM_AURA_ALWAYS_SHOW_MODE or {}
	return {
		{
			value = values.HIDE or "HIDE",
			label = L["CooldownPanelCDMAuraAlwaysShowModeHide"] or "Only show when active",
		},
		{
			value = values.SHOW or "SHOW",
			label = L["CooldownPanelCDMAuraAlwaysShowModeShow"] or (L["CooldownPanelAlwaysShow"] or "Always show"),
		},
		{
			value = values.DESATURATE or "DESATURATE",
			label = L["CooldownPanelCDMAuraAlwaysShowModeDesaturate"] or "Always show (desaturate if inactive)",
		},
	}
end

local function normalizeId(value)
	local num = tonumber(value)
	if num then return num end
	return value
end

local function getClassInfoById(classId)
	if GetClassInfo then return GetClassInfo(classId) end
	if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
		local info = C_CreatureInfo.GetClassInfo(classId)
		if info then return info.className, info.classFile, info.classID end
	end
	return nil
end

local function getClassSpecMenuData()
	local classes = {}
	local getSpecCount = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
	if not getSpecCount or not GetSpecializationInfoForClassID or not GetNumClasses then return classes end
	local sex = UnitSex and UnitSex("player") or nil
	local numClasses = GetNumClasses() or 0
	for classIndex = 1, numClasses do
		local className, classTag, classID = getClassInfoById(classIndex)
		if classID then
			local specCount = getSpecCount(classID) or 0
			if specCount > 0 then
				local specs = {}
				for specIndex = 1, specCount do
					local specID, specName, _, _, role = GetSpecializationInfoForClassID(classID, specIndex, sex)
					if specID then
						local isMelee = CooldownPanels and CooldownPanels.IsSpecQuickFilterMelee and CooldownPanels:IsSpecQuickFilterMelee(specID) or false
						local isCaster = role == "DAMAGER" and isMelee ~= true and classTag ~= "HUNTER"
						specs[#specs + 1] = {
							id = specID,
							name = specName or ("Spec " .. tostring(specID)),
							role = role,
							classTag = classTag,
							isMelee = isMelee,
							isCaster = isCaster,
						}
					end
				end
				if #specs > 0 then classes[#classes + 1] = {
					id = classID,
					name = className or classTag or tostring(classID),
					classTag = classTag,
					specs = specs,
				} end
			end
		end
	end
	if #classes > 1 then
		table.sort(classes, function(a, b)
			local an = a and a.name or ""
			local bn = b and b.name or ""
			if strcmputf8i then return strcmputf8i(an, bn) < 0 end
			return tostring(an):lower() < tostring(bn):lower()
		end)
	end
	return classes
end

local function getSpecNameById(specId)
	if GetSpecializationInfoForSpecID then
		local _, specName = GetSpecializationInfoForSpecID(specId)
		if specName and specName ~= "" then return specName end
	end
	return tostring(specId or "")
end

function CooldownPanels:IsSpecQuickFilterMelee(specId)
	specId = tonumber(specId)
	if not specId then return false end
	if specId == 70 or specId == 71 or specId == 72 or specId == 103 or specId == 251 or specId == 252 or specId == 255 then return true end
	if specId == 259 or specId == 260 or specId == 261 or specId == 263 or specId == 269 or specId == 577 then return true end
	return false
end

function CooldownPanels:GetSpecQuickFilterDefinitions(classMenuData)
	local definitions = {
		{ id = "HEALER", label = L["CooldownPanelSpecAllHealers"] or "All healers", specIds = {} },
		{ id = "TANK", label = L["CooldownPanelSpecAllTanks"] or "All tanks", specIds = {} },
		{ id = "MELEE", label = L["CooldownPanelSpecAllMelee"] or "All melee", specIds = {} },
		{ id = "CASTER", label = L["CooldownPanelSpecAllCasters"] or "All casters", specIds = {} },
	}

	for _, classData in ipairs(classMenuData or getClassSpecMenuData()) do
		for _, specData in ipairs(classData.specs or {}) do
			local specId = tonumber(specData.id)
			if specId and specId > 0 then
				if specData.role == "HEALER" then definitions[1].specIds[#definitions[1].specIds + 1] = specId end
				if specData.role == "TANK" then definitions[2].specIds[#definitions[2].specIds + 1] = specId end
				if specData.role == "DAMAGER" and specData.isMelee == true then definitions[3].specIds[#definitions[3].specIds + 1] = specId end
				if specData.isCaster == true then definitions[4].specIds[#definitions[4].specIds + 1] = specId end
			end
		end
	end

	return definitions
end

function CooldownPanels:HasAllPanelSpecFilterEntries(panel, specIds)
	if not panel or type(specIds) ~= "table" or #specIds == 0 then return false end
	local filter = panel.specFilter
	if type(filter) ~= "table" then return false end
	for _, specId in ipairs(specIds) do
		if filter[specId] ~= true then return false end
	end
	return true
end

function CooldownPanels:SetPanelSpecFilterEntries(panel, specIds, enabled)
	if not panel or type(specIds) ~= "table" then return false end
	panel.specFilter = panel.specFilter or {}
	local changed = false
	for _, specId in ipairs(specIds) do
		specId = tonumber(specId)
		if specId and specId > 0 then
			if enabled then
				if panel.specFilter[specId] ~= true then
					panel.specFilter[specId] = true
					changed = true
				end
			elseif panel.specFilter[specId] ~= nil then
				panel.specFilter[specId] = nil
				changed = true
			end
		end
	end
	return changed
end

function CooldownPanels:CommitPanelSpecFilter(panelId)
	self:RebuildSpellIndex()
	self:RefreshPanel(panelId)
	self:RefreshEditor()
end

local function getEffectiveSpellId(spellId)
	local id = tonumber(spellId)
	if not id then return nil end
	if Api.GetOverrideSpell then
		local overrideId = Api.GetOverrideSpell(id)
		if type(overrideId) == "number" and overrideId > 0 then return overrideId end
	end
	return id
end

local function getBaseSpellId(spellId)
	local id = tonumber(spellId)
	if not id then return nil end
	if Api.GetBaseSpell then
		local baseId = Api.GetBaseSpell(id)
		if type(baseId) == "number" and baseId > 0 then return baseId end
	end
	return id
end

function CooldownPanels:EnsureStaticSpellVariantGroupsLoaded()
	self.runtime = self.runtime or {}
	if self.runtime.staticSpellVariantGroupsLoaded == true then return end
	local groups = self.staticSpellVariantGroups
	for i = 1, #(groups or {}) do
		self:RegisterSpellVariantGroup(groups[i])
	end
	self.runtime.staticSpellVariantGroupsLoaded = true
end

function CooldownPanels:GetCanonicalSpellVariantID(spellId)
	self:EnsureStaticSpellVariantGroupsLoaded()
	local numericID = tonumber(spellId)
	if not numericID then return nil, false, nil end
	local baseSpellID = getBaseSpellId(numericID) or numericID
	local groupMap = self.spellVariantGroupByID
	local group = type(groupMap) == "table" and (groupMap[numericID] or groupMap[baseSpellID]) or nil
	if not group or type(group) ~= "table" or #group == 0 then return baseSpellID, false, nil end
	local canonicalID = tonumber(group[1]) or baseSpellID
	return canonicalID, canonicalID ~= baseSpellID, group
end

function CooldownPanels:ResolveKnownSpellVariantID(spellId)
	self:EnsureStaticSpellVariantGroupsLoaded()
	local numericID = tonumber(spellId)
	if not numericID then return nil, false, nil end
	local baseSpellID = getBaseSpellId(numericID) or numericID
	local groupMap = self.spellVariantGroupByID
	local group = type(groupMap) == "table" and (groupMap[numericID] or groupMap[baseSpellID]) or nil
	if not group or type(group) ~= "table" or #group == 0 then return baseSpellID, false, nil end
	if Api.IsSpellKnown and Api.IsSpellKnown(baseSpellID, false) then return baseSpellID, false, group end
	for i = 1, #group do
		local candidateID = tonumber(group[i])
		if candidateID and candidateID > 0 and Api.IsSpellKnown and Api.IsSpellKnown(candidateID, false) then return candidateID, candidateID ~= baseSpellID, group end
	end
	return baseSpellID, false, group
end

local function isSpellPassiveSafe(spellId, effectiveId)
	if not spellId or not Api.IsSpellPassiveFn then return false end
	local checkId = effectiveId or getEffectiveSpellId(spellId) or spellId
	if Api.IsSpellPassiveFn(checkId) then return true end
	if checkId ~= spellId and Api.IsSpellPassiveFn(spellId) then return true end
	return false
end

local function setPowerInsufficient(runtime, spellId, isUsable, insufficientPower)
	if not runtime or not spellId then return false end
	runtime.powerInsufficient = runtime.powerInsufficient or {}
	runtime.spellUnusable = runtime.spellUnusable or {}
	local usable = isUsable == true
	local powerValue = (insufficientPower == true) and true or nil
	local unusableValue = (not usable and insufficientPower ~= true) and true or nil
	local baseId = getBaseSpellId(spellId)
	local effectiveId = getEffectiveSpellId(spellId)
	local changed = false
	if baseId then
		if runtime.powerInsufficient[baseId] ~= powerValue then
			runtime.powerInsufficient[baseId] = powerValue
			changed = true
		end
		if runtime.spellUnusable[baseId] ~= unusableValue then
			runtime.spellUnusable[baseId] = unusableValue
			changed = true
		end
	end
	if effectiveId and effectiveId ~= baseId then
		if runtime.powerInsufficient[effectiveId] ~= powerValue then
			runtime.powerInsufficient[effectiveId] = powerValue
			changed = true
		end
		if runtime.spellUnusable[effectiveId] ~= unusableValue then
			runtime.spellUnusable[effectiveId] = unusableValue
			changed = true
		end
	end
	return changed
end

local function getSpellPowerCostNamesFromCosts(costs)
	if type(costs) ~= "table" then return nil end
	local names, seen = {}, {}
	for _, info in ipairs(costs) do
		local name = info and info.name
		if type(name) == "string" and name ~= "" then
			local upperName = string.upper(name)
			if upperName ~= "" and not seen[upperName] then
				seen[upperName] = true
				names[#names + 1] = upperName
			end
		end
		local powerType = info and tonumber(info.type)
		local token = powerType and CooldownPanels.POWER_TYPE_TOKEN_BY_ID and CooldownPanels.POWER_TYPE_TOKEN_BY_ID[powerType] or nil
		if token and token ~= "" and not seen[token] then
			seen[token] = true
			names[#names + 1] = token
		end
	end
	if #names == 0 then return nil end
	return names
end

local function getSpellPowerCostNames(spellId)
	if not spellId or not Api.GetSpellPowerCost then return nil end
	return getSpellPowerCostNamesFromCosts(Api.GetSpellPowerCost(spellId))
end

local function getRuntime(panelId)
	local runtime = CooldownPanels.runtime[panelId]
	if not runtime then
		runtime = {}
		CooldownPanels.runtime[panelId] = runtime
	end
	return runtime
end

local PanelVisibility = (function()
	local fallbackOptions = {
		{ value = "ALWAYS_IN_COMBAT", label = "In combat", order = 10 },
		{ value = "ALWAYS_OUT_OF_COMBAT", label = "Out of combat", order = 11 },
		{ value = "SKYRIDING_ACTIVE", label = "While skyriding", order = 25 },
		{ value = "SKYRIDING_INACTIVE", label = "Hide while skyriding", order = 26 },
		{ value = "FLYING_ACTIVE", label = L["visibilityRule_flying"] or "While flying", order = 27 },
		{ value = "FLYING_INACTIVE", label = L["visibilityRule_hideFlying"] or "Hide while flying", order = 28 },
		{ value = "PLAYER_CASTING", label = "While casting", order = 35 },
		{ value = "PLAYER_MOUNTED", label = "Mounted", order = 36 },
		{ value = "PLAYER_NOT_MOUNTED", label = "Not mounted", order = 37 },
		{ value = "PLAYER_HAS_TARGET", label = "When I have a target", order = 45 },
		{ value = "PLAYER_IN_GROUP", label = "In party/raid", order = 46 },
		{ value = "ALWAYS_HIDDEN", label = "Always hidden", order = 100 },
	}
	local optionCache
	local ruleMapCache
	local druidTravelFormSpellIds = {
		[783] = true,
		[1066] = true,
		[33943] = true,
		[40120] = true,
		[210053] = true,
	}

	local function copySelectionMap(selection)
		if type(selection) ~= "table" then return nil end
		local out
		for key, value in pairs(selection) do
			if value == true then
				out = out or {}
				out[key] = true
			end
		end
		return out
	end

	local function getRuleMap()
		if ruleMapCache then return ruleMapCache end
		local allowed = {}
		local metadata = GetVisibilityRuleMetadata and GetVisibilityRuleMetadata() or nil
		if type(metadata) == "table" then
			for key, data in pairs(metadata) do
				local applies = data and data.appliesTo
				if applies and applies.actionbar and key ~= "MOUSEOVER" then allowed[key] = true end
			end
		end
		for _, option in ipairs(fallbackOptions) do
			if option and option.value ~= "MOUSEOVER" then allowed[option.value] = true end
		end
		ruleMapCache = allowed
		return allowed
	end

	local function normalizeConfig(config)
		if type(config) ~= "table" then return nil end
		local allowed = getRuleMap()
		local out
		for key in pairs(allowed) do
			if config[key] == true then
				out = out or {}
				out[key] = true
			end
		end
		if not out then return nil end
		if out.ALWAYS_HIDDEN then return { ALWAYS_HIDDEN = true } end
		return out
	end

	local function getRuleOptions()
		if optionCache then return optionCache end
		local options = {}
		local seen = {}
		local metadata = GetVisibilityRuleMetadata and GetVisibilityRuleMetadata() or nil
		if type(metadata) == "table" then
			for key, data in pairs(metadata) do
				local applies = data and data.appliesTo
				if applies and applies.actionbar and key ~= "MOUSEOVER" then
					options[#options + 1] = {
						value = key,
						label = data.label or key,
						text = data.label or key,
						order = data.order or 999,
					}
					seen[key] = true
				end
			end
		end
		for _, option in ipairs(fallbackOptions) do
			if option and option.value and not seen[option.value] and option.value ~= "MOUSEOVER" then
				options[#options + 1] = {
					value = option.value,
					label = option.label or option.value,
					text = option.label or option.value,
					order = option.order or 999,
				}
				seen[option.value] = true
			end
		end
		table.sort(options, function(a, b)
			if a.order == b.order then
				local left = tostring(a.label or a.value or "")
				local right = tostring(b.label or b.value or "")
				if strcmputf8i then return strcmputf8i(left, right) < 0 end
				return left:lower() < right:lower()
			end
			return a.order < b.order
		end)
		optionCache = options
		return options
	end

	local function isInDruidTravelForm()
		local class = addon.variables and addon.variables.unitClass
		if class ~= "DRUID" then
			local _, eng
			if UnitClass then
				_, eng = UnitClass("player")
			end
			if eng ~= "DRUID" then return false end
		end
		if not GetShapeshiftForm then return false end
		local form = GetShapeshiftForm()
		if not form or form == 0 then return false end
		if GetShapeshiftFormID then
			local formID = GetShapeshiftFormID()
			if formID == DRUID_TRAVEL_FORM or formID == DRUID_ACQUATIC_FORM or formID == DRUID_FLIGHT_FORM or formID == 29 then return true end
		end
		local spellID = select(4, GetShapeshiftFormInfo(form))
		if spellID and druidTravelFormSpellIds[spellID] then return true end
		return form == 3
	end

	local function isPlayerMounted()
		if IsMounted and IsMounted() then return true end
		return isInDruidTravelForm()
	end

	local function isPlayerCasting()
		if UnitCastingInfo and UnitCastingInfo("player") then return true end
		if UnitChannelInfo and UnitChannelInfo("player") then return true end
		return false
	end

	local function isPlayerSkyriding()
		if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
			local _, canGlide = C_PlayerInfo.GetGlidingInfo()
			if canGlide ~= nil then return canGlide == true end
		end
		if SecureCmdOptionParse then
			if addon.variables and addon.variables.unitClass == "DRUID" then return SecureCmdOptionParse("[advflyable, mounted] 1; [advflyable, stance:3] 1; 0") == "1" end
			return SecureCmdOptionParse("[advflyable, mounted] 1; 0") == "1"
		end
		return addon.variables and addon.variables.isPlayerSkyriding == true
	end

	local function isPlayerFlying()
		if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
			local isGliding = C_PlayerInfo.GetGlidingInfo()
			if isGliding ~= nil then return isGliding == true end
		end
		if IsFlying and IsFlying() then return true end
		return false
	end

	local function hasShowRules(config)
		if not config then return false end
		return config.ALWAYS_IN_COMBAT
			or config.ALWAYS_OUT_OF_COMBAT
			or config.SKYRIDING_ACTIVE
			or config.FLYING_ACTIVE
			or config.PLAYER_CASTING
			or config.PLAYER_MOUNTED
			or config.PLAYER_NOT_MOUNTED
			or config.PLAYER_HAS_TARGET
			or config.PLAYER_IN_GROUP
	end

	local function shouldShow(config)
		local cfg = normalizeConfig(config)
		if not cfg then return true end
		if cfg.ALWAYS_HIDDEN then return false end

		local inCombat = false
		if InCombatLockdown and InCombatLockdown() then
			inCombat = true
		elseif UnitAffectingCombat then
			inCombat = UnitAffectingCombat("player") == true
		end
		local hasTarget = UnitExists and UnitExists("target") == true
		local inGroup = IsInGroup and IsInGroup() == true
		local mounted = isPlayerMounted()
		local casting = isPlayerCasting()
		local skyriding = isPlayerSkyriding()
		local flying = isPlayerFlying()

		if cfg.SKYRIDING_INACTIVE then
			if skyriding then return false end
			if not hasShowRules(cfg) then return true end
		end
		if cfg.FLYING_INACTIVE then
			if flying then return false end
			if not hasShowRules(cfg) then return true end
		end

		if cfg.SKYRIDING_ACTIVE and skyriding then return true end
		if cfg.FLYING_ACTIVE and flying then return true end
		if cfg.ALWAYS_IN_COMBAT and inCombat then return true end
		if cfg.ALWAYS_OUT_OF_COMBAT and not inCombat then return true end
		if cfg.PLAYER_CASTING and casting then return true end
		if cfg.PLAYER_MOUNTED and mounted then return true end
		if cfg.PLAYER_NOT_MOUNTED and not mounted then return true end
		if cfg.PLAYER_HAS_TARGET and hasTarget then return true end
		if cfg.PLAYER_IN_GROUP and inGroup then return true end

		return false
	end

	return {
		CopySelectionMap = copySelectionMap,
		NormalizeConfig = normalizeConfig,
		GetRuleOptions = getRuleOptions,
		ShouldShow = shouldShow,
	}
end)()

local updatePowerEventRegistration
local updateRangeCheckSpells
local updateItemCountCacheForItem
local ensureRoot
local ensurePanelAnchor
local panelAllowsSpec
local getPlayerSpecId
local ensureAssistedHighlightHook

local STRATA_INDEX = {}
for index, strata in ipairs(Helper.STRATA_ORDER or {}) do
	if type(strata) == "string" and strata ~= "" then STRATA_INDEX[strata] = index end
end

local function syncEditModeSelectionStrata(frame)
	if not (frame and frame.GetFrameStrata) then return end
	local selection = frame.Selection
	if not (selection and selection.SetFrameStrata) then return end
	if not frame._eqolSelectionBaseStrata then
		local baseStrata = Helper.NormalizeStrata((selection.GetFrameStrata and selection:GetFrameStrata()) or "MEDIUM", "MEDIUM")
		frame._eqolSelectionBaseStrata = baseStrata
		frame._eqolSelectionBaseStrataIndex = STRATA_INDEX[baseStrata] or STRATA_INDEX.MEDIUM or 3
	end
	local baseStrata = frame._eqolSelectionBaseStrata or "MEDIUM"
	local baseIndex = frame._eqolSelectionBaseStrataIndex or STRATA_INDEX[baseStrata] or STRATA_INDEX.MEDIUM or 3
	local currentStrata = Helper.NormalizeStrata(frame:GetFrameStrata(), baseStrata)
	local currentIndex = STRATA_INDEX[currentStrata]
	local targetStrata = (currentIndex and currentIndex > baseIndex) and currentStrata or baseStrata
	if selection.GetFrameStrata and selection:GetFrameStrata() ~= targetStrata then selection:SetFrameStrata(targetStrata) end
	if frame.editMoveHandle then
		frame.editMoveHandle:SetFrameStrata(targetStrata)
		frame.editMoveHandle:SetFrameLevel((selection.GetFrameLevel and selection:GetFrameLevel() or frame:GetFrameLevel()) + 20)
	end
	if frame.editPanelHandle then
		frame.editPanelHandle:SetFrameStrata(targetStrata)
		frame.editPanelHandle:SetFrameLevel((selection.GetFrameLevel and selection:GetFrameLevel() or frame:GetFrameLevel()) + 21)
	end
	if frame.editDropZone then
		frame.editDropZone:SetFrameStrata(frame:GetFrameStrata())
		frame.editDropZone:SetFrameLevel(frame:GetFrameLevel())
	end
end

local function refreshEditModePanelFrame(panelId, editModeId)
	local id = editModeId
	if not id and panelId then
		local runtime = getRuntime(panelId)
		id = runtime and runtime.editModeId
	end
	if not (id and EditMode and EditMode.RefreshFrame) then return end
	EditMode:RefreshFrame(id)
	local entry = EditMode and EditMode.frames and EditMode.frames[id]
	syncEditModeSelectionStrata(entry and entry.frame)
end

local function refreshEditModeSettingValues()
	local internal = addon.EditModeLib and addon.EditModeLib.internal
	if not internal then return end
	if internal.RequestRefreshSettingValues then
		internal:RequestRefreshSettingValues()
	elseif internal.RefreshSettingValues then
		internal:RefreshSettingValues()
	end
end

local function refreshEditModeSettings()
	local lib = addon.EditModeLib
	if not (lib and lib.internal) then return end
	if lib.internal.RequestRefreshSettings then
		lib.internal:RequestRefreshSettings()
	elseif lib.internal.RefreshSettings then
		lib.internal:RefreshSettings()
	end
	if lib.internal.RefreshSettingValues then lib.internal:RefreshSettingValues() end
end

CooldownPanels.MarkRelativeFrameEntriesDirty = function()
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime._eqolRelativeFrameEntriesVersion = (runtime._eqolRelativeFrameEntriesVersion or 0) + 1
end

local FAKE_CURSOR_FRAME_NAME = "EQOL_CooldownPanelsFakeCursor"
local FAKE_CURSOR_ATLAS = "Cursor_Point_32"
local FAKE_CURSOR_SIZE = 32
local FAKE_CURSOR_HOTSPOT_X = 0
local FAKE_CURSOR_HOTSPOT_Y = 0
local FAKE_CURSOR_DEFAULT_X = 0
local FAKE_CURSOR_DEFAULT_Y = 100
local fakeCursorFrame
local fakeCursorResetOnShow = true
local fakeCursorMode
local cursorFollowRunner
local cursorSpecRetryPending

local function ensureFakeCursorFrame()
	if fakeCursorFrame then return fakeCursorFrame end
	local frame = CreateFrame("Frame", FAKE_CURSOR_FRAME_NAME, UIParent)
	frame:SetSize(FAKE_CURSOR_SIZE, FAKE_CURSOR_SIZE)
	frame:SetFrameStrata("TOOLTIP")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	local tex = frame:CreateTexture(nil, "OVERLAY")
	tex:SetAtlas(FAKE_CURSOR_ATLAS, true)
	tex:ClearAllPoints()
	tex:SetSize(FAKE_CURSOR_SIZE, FAKE_CURSOR_SIZE)
	tex:SetPoint("CENTER", frame, "CENTER", (FAKE_CURSOR_SIZE * 0.5) - FAKE_CURSOR_HOTSPOT_X, FAKE_CURSOR_HOTSPOT_Y - (FAKE_CURSOR_SIZE * 0.5))
	frame.texture = tex

	frame:Hide()
	fakeCursorFrame = frame
	return frame
end

local function showFakeCursorFrame()
	local frame = ensureFakeCursorFrame()
	if fakeCursorResetOnShow or not frame._eqolHasPosition then
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", FAKE_CURSOR_DEFAULT_X, FAKE_CURSOR_DEFAULT_Y)
		frame._eqolHasPosition = true
		fakeCursorResetOnShow = false
	end
	frame:Show()
	return frame
end

local function hideFakeCursorFrame()
	if fakeCursorFrame then fakeCursorFrame:Hide() end
end

local function resetFakeCursorFrame()
	fakeCursorResetOnShow = true
	if fakeCursorFrame then fakeCursorFrame._eqolHasPosition = nil end
end

local function setFakeCursorMode(mode)
	if fakeCursorMode == mode then return end
	fakeCursorMode = mode
	if mode == "hidden" then
		hideFakeCursorFrame()
		return
	end
	local frame = ensureFakeCursorFrame()
	if mode == "edit" then
		showFakeCursorFrame()
		frame:SetAlpha(1)
		if frame.texture then frame.texture:Show() end
		frame:EnableMouse(true)
		frame:Show()
	elseif mode == "follow" then
		fakeCursorResetOnShow = false
		frame:SetAlpha(0)
		if frame.texture then frame.texture:Hide() end
		frame:EnableMouse(false)
		frame:Show()
	end
end

local function updateFakeCursorToMouse()
	local frame = ensureFakeCursorFrame()
	local x, y = Api.GetCursorPosition()
	if not x or not y then return end
	local scale = UIParent:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

local function startCursorFollow()
	if cursorFollowRunner and cursorFollowRunner:GetScript("OnUpdate") then return end
	local runner = cursorFollowRunner
	if not runner then
		runner = CreateFrame("Frame")
		cursorFollowRunner = runner
	end
	updateFakeCursorToMouse()
	runner:SetScript("OnUpdate", function(self)
		if CooldownPanels:IsInEditMode() then return end
		updateFakeCursorToMouse()
	end)
end

local function stopCursorFollow()
	if cursorFollowRunner then cursorFollowRunner:SetScript("OnUpdate", nil) end
end

local function panelUsesFakeCursor(panel)
	local anchor = ensurePanelAnchor(panel)
	local rel = anchor and anchor.relativeFrame
	return rel == FAKE_CURSOR_FRAME_NAME
end

local function hasSpecFilteredCursorPanels()
	local root = ensureRoot()
	if not root or not root.panels then return false end
	for _, panel in pairs(root.panels) do
		if panel and panelUsesFakeCursor(panel) and panel.enabled ~= false then
			local filter = panel.specFilter
			if type(filter) == "table" then
				for _, enabled in pairs(filter) do
					if enabled then return true end
				end
			end
		end
	end
	return false
end

local function scheduleCursorSpecRetry()
	if cursorSpecRetryPending then return end
	if not C_Timer or not C_Timer.After then return end
	cursorSpecRetryPending = true
	C_Timer.After(0.5, function()
		cursorSpecRetryPending = false
		if not hasSpecFilteredCursorPanels() then return end
		if getPlayerSpecId and getPlayerSpecId() then
			CooldownPanels:UpdateCursorAnchorState()
			return
		end
		scheduleCursorSpecRetry()
	end)
end

local function hasFakeCursorPanels()
	local root = ensureRoot()
	if not root or not root.panels then return false end
	for _, panel in pairs(root.panels) do
		if panel and panelUsesFakeCursor(panel) then
			if panel.enabled ~= false and panelAllowsSpec(panel) then return true end
		end
	end
	return false
end

function CooldownPanels:GetLayoutEditFakeCursorPanel()
	local runtime = CooldownPanels.runtime
	local editor = runtime and runtime.editor or nil
	if not (editor and editor.frame and editor.frame:IsShown()) then return nil end
	if editor.layoutEditActive ~= true then return nil end
	local panelId = normalizeId(editor.selectedPanelId)
	if not panelId then return nil end
	local panel = CooldownPanels:GetPanel(panelId)
	if panel and panelUsesFakeCursor(panel) then return panelId, panel end
	return nil
end

function CooldownPanels:UpdateCursorAnchorState()
	local layoutEditCursorPanelId = self:GetLayoutEditFakeCursorPanel()
	local wantsCursor = layoutEditCursorPanelId ~= nil or hasFakeCursorPanels()
	if wantsCursor then
		if layoutEditCursorPanelId then
			stopCursorFollow()
			setFakeCursorMode("edit")
			local frame = ensureFakeCursorFrame()
			frame:ClearAllPoints()
			frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			frame._eqolHasPosition = true
			fakeCursorResetOnShow = false
			frame:Show()
			local runtime = getRuntime(layoutEditCursorPanelId)
			CooldownPanels.ClearAppliedAnchorCache(runtime)
			self:ApplyPanelPosition(layoutEditCursorPanelId)
		elseif self:IsInEditMode() then
			stopCursorFollow()
			setFakeCursorMode("edit")
		else
			setFakeCursorMode("follow")
			startCursorFollow()
		end
		cursorSpecRetryPending = false
	else
		stopCursorFollow()
		setFakeCursorMode("hidden")
		if hasSpecFilteredCursorPanels() and getPlayerSpecId and not getPlayerSpecId() then scheduleCursorSpecRetry() end
	end
end

local function getMasqueGroup()
	if not Masque and LibStub then Masque = LibStub("Masque", true) end
	if not Masque then return nil end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	if not CooldownPanels.runtime.masqueGroup then CooldownPanels.runtime.masqueGroup = Masque:Group(parentAddonName, "Cooldown Panels", "CooldownPanels") end
	return CooldownPanels.runtime.masqueGroup
end

local ICON_BORDER_TEXTURE_DEFAULT = "DEFAULT"

local function iconBorderOptions()
	local list = {}
	local seen = {}
	local function add(value, label)
		local lv = tostring(value or ""):lower()
		if lv == "" or seen[lv] then return end
		seen[lv] = true
		list[#list + 1] = { value = value, label = label or value }
	end
	add(ICON_BORDER_TEXTURE_DEFAULT, _G.DEFAULT or (L and L["Default"]) or "Default")
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("border") or {}
	local hash = addon.functions and addon.functions.GetLSMMediaHash and addon.functions.GetLSMMediaHash("border") or {}
	for i = 1, #names do
		local name = names[i]
		local path = hash[name]
		if type(path) == "string" and path ~= "" then add(name, tostring(name)) end
	end
	return list
end

local function normalizeIconBorderTexture(value, fallback)
	if type(value) == "string" and value ~= "" then return value end
	if type(fallback) == "string" and fallback ~= "" then return fallback end
	return ICON_BORDER_TEXTURE_DEFAULT
end

local function resolveIconBorderTexture(value)
	local key = normalizeIconBorderTexture(value, ICON_BORDER_TEXTURE_DEFAULT)
	local ufHelper = addon.Aura and addon.Aura.UFHelper
	if ufHelper and ufHelper.resolveBorderTexture then return ufHelper.resolveBorderTexture(key) end
	if not key or key == "" or key == ICON_BORDER_TEXTURE_DEFAULT then return "Interface\\Buttons\\WHITE8x8" end
	if LSM and LSM.Fetch then
		local tex = LSM:Fetch("border", key)
		if type(tex) == "string" and tex ~= "" then return tex end
	end
	return key
end

function CooldownPanels:RegisterMasqueButtons()
	local group = getMasqueGroup()
	if not group then return end
	for _, runtime in pairs(self.runtime or {}) do
		local frame = runtime and runtime.frame
		if frame and frame._eqolPanelFrame and frame.icons then
			for _, icon in ipairs(frame.icons) do
				if icon and not icon._eqolMasqueAdded then
					local regions = {
						Icon = icon.texture,
						Cooldown = icon.cooldown,
						Normal = icon.msqNormal,
					}
					group:AddButton(icon, regions, "Action", true)
					icon._eqolMasqueAdded = true
				end
			end
		end
	end
end

function CooldownPanels:ReskinMasque()
	local group = getMasqueGroup()
	if group and group.ReSkin then group:ReSkin() end
end

local getEditor
local applyEditLayout
local refreshPanelsForSpell
local refreshPanelsForCharges
local normalizedRoots = setmetatable({}, { __mode = "k" })
local normalizedPanels = setmetatable({}, { __mode = "k" })
CooldownPanels._styleCacheRoots = CooldownPanels._styleCacheRoots
	or {
		cooldownTextPanel = setmetatable({}, { __mode = "k" }),
		cooldownTextEntry = setmetatable({}, { __mode = "k" }),
		stackTextPanel = setmetatable({}, { __mode = "k" }),
		stackTextEntry = setmetatable({}, { __mode = "k" }),
		chargesTextPanel = setmetatable({}, { __mode = "k" }),
		chargesTextEntry = setmetatable({}, { __mode = "k" }),
		glowPanel = setmetatable({}, { __mode = "k" }),
		glowEntry = setmetatable({}, { __mode = "k" }),
		pandemicGlowPanel = setmetatable({}, { __mode = "k" }),
		pandemicGlowEntry = setmetatable({}, { __mode = "k" }),
		procGlowPanel = setmetatable({}, { __mode = "k" }),
		procGlowEntry = setmetatable({}, { __mode = "k" }),
		iconLayoutEntry = setmetatable({}, { __mode = "k" }),
	}
CooldownPanels.POWER_USABLE_REFRESH_DELAY = CooldownPanels.POWER_USABLE_REFRESH_DELAY or 0.05

function CooldownPanels.FillCachedColor(cache, r, g, b, a)
	cache = cache or {}
	cache[1] = r or 1
	cache[2] = g or 1
	cache[3] = b or 1
	cache[4] = a or 1
	return cache
end

local function clearRuntimeLayoutShapeCache(runtime)
	if not runtime then return end
	runtime._eqolLastLayoutCount = nil
	runtime._eqolLayoutIconSize = nil
	runtime._eqolLayoutSpacing = nil
	runtime._eqolLayoutMode = nil
	runtime._eqolLayoutDirection = nil
	runtime._eqolLayoutWrapCount = nil
	runtime._eqolLayoutWrapDirection = nil
	runtime._eqolLayoutGrowthPoint = nil
	runtime._eqolLayoutRadialRadius = nil
	runtime._eqolLayoutRadialRotation = nil
	runtime._eqolLayoutRowSize1 = nil
	runtime._eqolLayoutRowSize2 = nil
	runtime._eqolLayoutRowSize3 = nil
	runtime._eqolLayoutRowSize4 = nil
	runtime._eqolLayoutRowSize5 = nil
	runtime._eqolLayoutRowSize6 = nil
	runtime._eqolLayoutIconBorderEnabled = nil
	runtime._eqolLayoutIconBorderTexture = nil
	runtime._eqolLayoutIconBorderSize = nil
	runtime._eqolLayoutIconBorderOffset = nil
	runtime._eqolLayoutIconBorderColorR = nil
	runtime._eqolLayoutIconBorderColorG = nil
	runtime._eqolLayoutIconBorderColorB = nil
	runtime._eqolLayoutIconBorderColorA = nil
end

CooldownPanels.ClearRuntimeResolvedLayoutCache = function(runtime)
	if not runtime then return end
	runtime._eqolResolvedRuntimeLayout = nil
end

CooldownPanels.ClearAppliedAnchorCache = function(runtime)
	if not runtime then return end
	runtime._eqolAnchorAppliedFrame = nil
	runtime._eqolAnchorPoint = nil
	runtime._eqolAnchorRelativePoint = nil
	runtime._eqolAnchorRelativeFrame = nil
	runtime._eqolAnchorX = nil
	runtime._eqolAnchorY = nil
end

local function didLayoutShapeChange(runtime, layout, layoutCount)
	if not runtime then return true end
	if not layout then
		local changed = runtime._eqolLastLayoutCount ~= layoutCount
		runtime._eqolLastLayoutCount = layoutCount
		return changed
	end
	local rowSizes = layout.rowSizes
	local rowSize1 = rowSizes and rowSizes[1] or nil
	local rowSize2 = rowSizes and rowSizes[2] or nil
	local rowSize3 = rowSizes and rowSizes[3] or nil
	local rowSize4 = rowSizes and rowSizes[4] or nil
	local rowSize5 = rowSizes and rowSizes[5] or nil
	local rowSize6 = rowSizes and rowSizes[6] or nil
	local fixedGridColumns = layout.fixedGridColumns
	local fixedGridRows = layout.fixedGridRows
	local borderColor = layout.iconBorderColor
	local borderColorR = borderColor and (borderColor.r or borderColor[1]) or nil
	local borderColorG = borderColor and (borderColor.g or borderColor[2]) or nil
	local borderColorB = borderColor and (borderColor.b or borderColor[3]) or nil
	local borderColorA = borderColor and (borderColor.a or borderColor[4]) or nil
	if
		runtime._eqolLastLayoutCount == layoutCount
		and runtime._eqolLayoutIconSize == layout.iconSize
		and runtime._eqolLayoutSpacing == layout.spacing
		and runtime._eqolLayoutMode == layout.layoutMode
		and runtime._eqolLayoutDirection == layout.direction
		and runtime._eqolLayoutWrapCount == layout.wrapCount
		and runtime._eqolLayoutWrapDirection == layout.wrapDirection
		and runtime._eqolLayoutGrowthPoint == layout.growthPoint
		and runtime._eqolLayoutRadialRadius == layout.radialRadius
		and runtime._eqolLayoutRadialRotation == layout.radialRotation
		and runtime._eqolLayoutRadialArcDegrees == layout.radialArcDegrees
		and runtime._eqolLayoutRowSize1 == rowSize1
		and runtime._eqolLayoutRowSize2 == rowSize2
		and runtime._eqolLayoutRowSize3 == rowSize3
		and runtime._eqolLayoutRowSize4 == rowSize4
		and runtime._eqolLayoutRowSize5 == rowSize5
		and runtime._eqolLayoutRowSize6 == rowSize6
		and runtime._eqolLayoutFixedGridColumns == fixedGridColumns
		and runtime._eqolLayoutFixedGridRows == fixedGridRows
		and runtime._eqolLayoutIconBorderEnabled == layout.iconBorderEnabled
		and runtime._eqolLayoutIconBorderTexture == layout.iconBorderTexture
		and runtime._eqolLayoutIconBorderSize == layout.iconBorderSize
		and runtime._eqolLayoutIconBorderOffset == layout.iconBorderOffset
		and runtime._eqolLayoutIconBorderColorR == borderColorR
		and runtime._eqolLayoutIconBorderColorG == borderColorG
		and runtime._eqolLayoutIconBorderColorB == borderColorB
		and runtime._eqolLayoutIconBorderColorA == borderColorA
	then
		return false
	end
	runtime._eqolLastLayoutCount = layoutCount
	runtime._eqolLayoutIconSize = layout.iconSize
	runtime._eqolLayoutSpacing = layout.spacing
	runtime._eqolLayoutMode = layout.layoutMode
	runtime._eqolLayoutDirection = layout.direction
	runtime._eqolLayoutWrapCount = layout.wrapCount
	runtime._eqolLayoutWrapDirection = layout.wrapDirection
	runtime._eqolLayoutGrowthPoint = layout.growthPoint
	runtime._eqolLayoutRadialRadius = layout.radialRadius
	runtime._eqolLayoutRadialRotation = layout.radialRotation
	runtime._eqolLayoutRadialArcDegrees = layout.radialArcDegrees
	runtime._eqolLayoutRowSize1 = rowSize1
	runtime._eqolLayoutRowSize2 = rowSize2
	runtime._eqolLayoutRowSize3 = rowSize3
	runtime._eqolLayoutRowSize4 = rowSize4
	runtime._eqolLayoutRowSize5 = rowSize5
	runtime._eqolLayoutRowSize6 = rowSize6
	runtime._eqolLayoutFixedGridColumns = fixedGridColumns
	runtime._eqolLayoutFixedGridRows = fixedGridRows
	runtime._eqolLayoutIconBorderEnabled = layout.iconBorderEnabled
	runtime._eqolLayoutIconBorderTexture = layout.iconBorderTexture
	runtime._eqolLayoutIconBorderSize = layout.iconBorderSize
	runtime._eqolLayoutIconBorderOffset = layout.iconBorderOffset
	runtime._eqolLayoutIconBorderColorR = borderColorR
	runtime._eqolLayoutIconBorderColorG = borderColorG
	runtime._eqolLayoutIconBorderColorB = borderColorB
	runtime._eqolLayoutIconBorderColorA = borderColorA
	return true
end

CooldownPanels.ResolveRuntimeLayout = function(runtime, frame, layout)
	if not runtime or not frame then return nil end
	local defaults = Helper.PANEL_LAYOUT_DEFAULTS
	local cache = runtime._eqolResolvedRuntimeLayout
	local readyGlowColor = layout.readyGlowColor
	local readyGlowR = readyGlowColor and (readyGlowColor.r or readyGlowColor[1]) or nil
	local readyGlowG = readyGlowColor and (readyGlowColor.g or readyGlowColor[2]) or nil
	local readyGlowB = readyGlowColor and (readyGlowColor.b or readyGlowColor[3]) or nil
	local readyGlowA = readyGlowColor and (readyGlowColor.a or readyGlowColor[4]) or nil
	local powerTintColor = layout.powerTintColor
	local powerTintSrcR = powerTintColor and (powerTintColor.r or powerTintColor[1]) or nil
	local powerTintSrcG = powerTintColor and (powerTintColor.g or powerTintColor[2]) or nil
	local powerTintSrcB = powerTintColor and (powerTintColor.b or powerTintColor[3]) or nil
	local powerTintSrcA = powerTintColor and (powerTintColor.a or powerTintColor[4]) or nil
	local unusableTintColor = layout.unusableTintColor
	local unusableTintSrcR = unusableTintColor and (unusableTintColor.r or unusableTintColor[1]) or nil
	local unusableTintSrcG = unusableTintColor and (unusableTintColor.g or unusableTintColor[2]) or nil
	local unusableTintSrcB = unusableTintColor and (unusableTintColor.b or unusableTintColor[3]) or nil
	local unusableTintSrcA = unusableTintColor and (unusableTintColor.a or unusableTintColor[4]) or nil
	local rangeOverlayColor = layout.rangeOverlayColor
	local rangeOverlaySrcR = rangeOverlayColor and (rangeOverlayColor.r or rangeOverlayColor[1]) or nil
	local rangeOverlaySrcG = rangeOverlayColor and (rangeOverlayColor.g or rangeOverlayColor[2]) or nil
	local rangeOverlaySrcB = rangeOverlayColor and (rangeOverlayColor.b or rangeOverlayColor[3]) or nil
	local rangeOverlaySrcA = rangeOverlayColor and (rangeOverlayColor.a or rangeOverlayColor[4]) or nil

	if
		cache
		and cache.frame == frame
		and cache.showTooltipsSource == layout.showTooltips
		and cache.keybindsEnabledSource == layout.keybindsEnabled
		and cache.showIconTextureSource == layout.showIconTexture
		and cache.noDesaturationSource == layout.noDesaturation
		and cache.checkPowerSource == layout.checkPower
		and cache.readyGlowRSource == readyGlowR
		and cache.readyGlowGSource == readyGlowG
		and cache.readyGlowBSource == readyGlowB
		and cache.readyGlowASource == readyGlowA
		and cache.powerTintRSource == powerTintSrcR
		and cache.powerTintGSource == powerTintSrcG
		and cache.powerTintBSource == powerTintSrcB
		and cache.powerTintASource == powerTintSrcA
		and cache.unusableTintRSource == unusableTintSrcR
		and cache.unusableTintGSource == unusableTintSrcG
		and cache.unusableTintBSource == unusableTintSrcB
		and cache.unusableTintASource == unusableTintSrcA
		and cache.rangeOverlayEnabledSource == layout.rangeOverlayEnabled
		and cache.rangeOverlayRSource == rangeOverlaySrcR
		and cache.rangeOverlayGSource == rangeOverlaySrcG
		and cache.rangeOverlayBSource == rangeOverlaySrcB
		and cache.rangeOverlayASource == rangeOverlaySrcA
		and cache.cooldownDrawEdgeSource == layout.cooldownDrawEdge
		and cache.cooldownDrawBlingSource == layout.cooldownDrawBling
		and cache.cooldownDrawSwipeSource == layout.cooldownDrawSwipe
		and cache.hideOnCooldownSource == layout.hideOnCooldown
		and cache.showOnCooldownSource == layout.showOnCooldown
		and cache.cooldownGcdDrawEdgeSource == layout.cooldownGcdDrawEdge
		and cache.cooldownGcdDrawBlingSource == layout.cooldownGcdDrawBling
		and cache.cooldownGcdDrawSwipeSource == layout.cooldownGcdDrawSwipe
	then
		return cache
	end

	local showTooltips = layout.showTooltips == true
	local showKeybinds = layout.keybindsEnabled == true
	local showIconTexture = layout.showIconTexture ~= false
	local noDesaturation = layout.noDesaturation == true
	local checkPower = layout.checkPower == true
	local staticFontPath, staticFontSize, staticFontStyle = Helper.GetCountFontDefaults(frame)
	local normalizedReadyGlow = Helper.NormalizeColor(layout.readyGlowColor, defaults.readyGlowColor)
	local powerTintR, powerTintG, powerTintB = Helper.ResolveColor(layout.powerTintColor, defaults.powerTintColor)
	local unusableTintR, unusableTintG, unusableTintB = Helper.ResolveColor(layout.unusableTintColor, defaults.unusableTintColor)
	local rangeOverlayEnabled = layout.rangeOverlayEnabled == true
	local rangeOverlayR, rangeOverlayG, rangeOverlayB, rangeOverlayA = Helper.ResolveColor(layout.rangeOverlayColor, defaults.rangeOverlayColor)
	local drawEdge = layout.cooldownDrawEdge ~= false
	local drawBling = layout.cooldownDrawBling ~= false
	local drawSwipe = layout.cooldownDrawSwipe ~= false
	local hideOnCooldown = layout.hideOnCooldown == true
	local showOnCooldown = layout.showOnCooldown == true
	if showOnCooldown then hideOnCooldown = false end
	local gcdDrawEdge = layout.cooldownGcdDrawEdge == true
	local gcdDrawBling = layout.cooldownGcdDrawBling == true
	local gcdDrawSwipe = layout.cooldownGcdDrawSwipe == true

	cache = cache or {}
	cache.frame = frame
	cache.showTooltipsSource = layout.showTooltips
	cache.keybindsEnabledSource = layout.keybindsEnabled
	cache.showIconTextureSource = layout.showIconTexture
	cache.noDesaturationSource = layout.noDesaturation
	cache.checkPowerSource = layout.checkPower
	cache.readyGlowRSource = readyGlowR
	cache.readyGlowGSource = readyGlowG
	cache.readyGlowBSource = readyGlowB
	cache.readyGlowASource = readyGlowA
	cache.powerTintRSource = powerTintSrcR
	cache.powerTintGSource = powerTintSrcG
	cache.powerTintBSource = powerTintSrcB
	cache.powerTintASource = powerTintSrcA
	cache.unusableTintRSource = unusableTintSrcR
	cache.unusableTintGSource = unusableTintSrcG
	cache.unusableTintBSource = unusableTintSrcB
	cache.unusableTintASource = unusableTintSrcA
	cache.rangeOverlayEnabledSource = layout.rangeOverlayEnabled
	cache.rangeOverlayRSource = rangeOverlaySrcR
	cache.rangeOverlayGSource = rangeOverlaySrcG
	cache.rangeOverlayBSource = rangeOverlaySrcB
	cache.rangeOverlayASource = rangeOverlaySrcA
	cache.cooldownDrawEdgeSource = layout.cooldownDrawEdge
	cache.cooldownDrawBlingSource = layout.cooldownDrawBling
	cache.cooldownDrawSwipeSource = layout.cooldownDrawSwipe
	cache.hideOnCooldownSource = layout.hideOnCooldown
	cache.showOnCooldownSource = layout.showOnCooldown
	cache.cooldownGcdDrawEdgeSource = layout.cooldownGcdDrawEdge
	cache.cooldownGcdDrawBlingSource = layout.cooldownGcdDrawBling
	cache.cooldownGcdDrawSwipeSource = layout.cooldownGcdDrawSwipe
	cache.showTooltips = showTooltips
	cache.showKeybinds = showKeybinds
	cache.showIconTexture = showIconTexture
	cache.noDesaturation = noDesaturation
	cache.checkPower = checkPower
	cache.staticFontPath = staticFontPath
	cache.staticFontSize = staticFontSize
	cache.staticFontStyle = staticFontStyle
	cache.readyGlowColor = cache.readyGlowColor or {}
	cache.readyGlowColor[1] = normalizedReadyGlow[1]
	cache.readyGlowColor[2] = normalizedReadyGlow[2]
	cache.readyGlowColor[3] = normalizedReadyGlow[3]
	cache.readyGlowColor[4] = normalizedReadyGlow[4]
	cache.powerTintR = powerTintR
	cache.powerTintG = powerTintG
	cache.powerTintB = powerTintB
	cache.unusableTintR = unusableTintR
	cache.unusableTintG = unusableTintG
	cache.unusableTintB = unusableTintB
	cache.rangeOverlayEnabled = rangeOverlayEnabled
	cache.rangeOverlayR = rangeOverlayR
	cache.rangeOverlayG = rangeOverlayG
	cache.rangeOverlayB = rangeOverlayB
	cache.rangeOverlayA = rangeOverlayA
	cache.drawEdge = drawEdge
	cache.drawBling = drawBling
	cache.drawSwipe = drawSwipe
	cache.hideOnCooldown = hideOnCooldown
	cache.showOnCooldown = showOnCooldown
	cache.gcdDrawEdge = gcdDrawEdge
	cache.gcdDrawBling = gcdDrawBling
	cache.gcdDrawSwipe = gcdDrawSwipe
	runtime._eqolResolvedRuntimeLayout = cache
	return cache
end

ensurePanelAnchor = function(panel)
	if not panel then return nil end
	panel.anchor = panel.anchor or {}
	local anchor = panel.anchor
	if anchor.point == nil then anchor.point = panel.point or "CENTER" end
	if anchor.relativePoint == nil then anchor.relativePoint = anchor.point end
	if anchor.x == nil then anchor.x = panel.x or 0 end
	if anchor.y == nil then anchor.y = panel.y or 0 end
	anchor.relativeFrame = Helper.NormalizeRelativeFrameName(anchor.relativeFrame)
	panel.point = anchor.point or panel.point
	panel.x = anchor.x or panel.x
	panel.y = anchor.y or panel.y
	return anchor
end

local function anchorUsesUIParent(anchor) return not anchor or (anchor.relativeFrame or "UIParent") == "UIParent" end

local function resolveAnchorFrame(anchor)
	local relativeName = Helper.NormalizeRelativeFrameName(anchor and anchor.relativeFrame)
	if relativeName == "UIParent" then return UIParent end
	if relativeName == FAKE_CURSOR_FRAME_NAME then return ensureFakeCursorFrame() end
	local generic = Helper.GENERIC_ANCHORS[relativeName]
	if generic then
		local ufCfg = addon.db and addon.db.ufFrames
		if ufCfg and generic.ufKey and ufCfg[generic.ufKey] and ufCfg[generic.ufKey].enabled then
			local ufFrame = _G[generic.uf]
			if ufFrame then return ufFrame end
		end
		local blizzFrame = _G[generic.blizz]
		if blizzFrame then return blizzFrame end
	end
	local anchorHelper = CooldownPanels.AnchorHelper
	if anchorHelper and anchorHelper.ResolveExternalFrame then
		local externalFrame = anchorHelper:ResolveExternalFrame(relativeName)
		if externalFrame then return externalFrame end
	end
	local frame = _G[relativeName]
	if frame then return frame end
	return UIParent
end

local function panelFrameName(panelId) return "EQOL_CooldownPanel" .. tostring(panelId) end

local function frameNameToPanelId(frameName)
	if type(frameName) ~= "string" then return nil end
	local id = frameName:match("^EQOL_CooldownPanel(%d+)$")
	return id and tonumber(id) or nil
end

CooldownPanels.WouldCauseRelativeFrameLoop = function(panelKey, candidateName, root)
	local targetId = frameNameToPanelId(candidateName)
	if not targetId then return false end
	if targetId == panelKey then return true end
	local panels = root and root.panels or nil
	local seen = {}
	local currentId = targetId
	local limit = 20
	while currentId and limit > 0 do
		if seen[currentId] then break end
		seen[currentId] = true
		if currentId == panelKey then return true end
		local other = panels and panels[currentId] or nil
		if other and root and not normalizedPanels[other] then
			Helper.NormalizePanel(other, root.defaults)
			normalizedPanels[other] = true
		end
		local otherAnchor = other and ensurePanelAnchor(other)
		currentId = frameNameToPanelId(otherAnchor and otherAnchor.relativeFrame)
		limit = limit - 1
	end
	return false
end

CooldownPanels.GetRelativeFrameCache = function(runtimePanel, panel, panelKey)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local shared = CooldownPanels.runtime
	local version = shared._eqolRelativeFrameEntriesVersion or 0
	local anchor = ensurePanelAnchor(panel)
	local cur = Helper.NormalizeRelativeFrameName(anchor and anchor.relativeFrame)
	local root = ensureRoot()
	local cache = runtimePanel and runtimePanel._eqolRelativeFrameCache or nil
	if cache and cache.version == version and cache.root == root and cache.current == cur then return cache end
	local entries = {}
	local valid = {}
	local seen = {}
	local function add(key, label)
		if not key or key == "" or seen[key] then return end
		if CooldownPanels.WouldCauseRelativeFrameLoop(panelKey, key, root) then return end
		seen[key] = true
		valid[key] = true
		entries[#entries + 1] = { key = key, label = label or key }
	end

	add("UIParent", "UIParent")
	add(FAKE_CURSOR_FRAME_NAME, _G.CURSOR or "Cursor")
	for _, key in ipairs(Helper.GENERIC_ANCHOR_ORDER) do
		local info = Helper.GENERIC_ANCHORS[key]
		if info then add(key, info.label) end
	end
	if _G and _G.EssentialCooldownViewer then add("EssentialCooldownViewer", COOLDOWN_VIEWER_SETTINGS_CATEGORY_ESSENTIAL) end
	if _G and _G.UtilityCooldownViewer then add("UtilityCooldownViewer", COOLDOWN_VIEWER_SETTINGS_CATEGORY_UTILITY) end

	local anchorHelper = CooldownPanels.AnchorHelper
	if anchorHelper and anchorHelper.CollectAnchorEntries then
		anchorHelper:CollectAnchorEntries(entries, seen)
		for i = 1, #entries do
			local entry = entries[i]
			if entry and entry.key and entry.key ~= "" then
				seen[entry.key] = true
				valid[entry.key] = true
			end
		end
	end

	if root and root.panels then
		for id, other in pairs(root.panels) do
			local otherId = normalizeId(id)
			if otherId ~= panelKey then
				local label = string.format("Panel %s: %s", tostring(otherId), other and other.name or "Cooldown Panel")
				add(panelFrameName(otherId), label)
			end
		end
	end

	if cur and not seen[cur] then
		local label = anchorHelper and anchorHelper.GetAnchorLabel and anchorHelper:GetAnchorLabel(cur)
		add(cur, label or cur)
	end

	cache = { version = version, root = root, current = cur, entries = entries, valid = valid }
	if runtimePanel then runtimePanel._eqolRelativeFrameCache = cache end
	return cache
end

CooldownPanels.ValidateRelativeFrameChoice = function(panel, panelKey, runtimePanel)
	local anchor = ensurePanelAnchor(panel)
	if not anchor then return "UIParent" end
	local cur = Helper.NormalizeRelativeFrameName(anchor.relativeFrame)
	local cache = CooldownPanels.GetRelativeFrameCache(runtimePanel, panel, panelKey)
	if cache.valid and cache.valid[cur] then return cur end
	if anchor.relativeFrame ~= "UIParent" then
		anchor.relativeFrame = "UIParent"
		CooldownPanels.MarkRelativeFrameEntriesDirty()
	end
	return "UIParent"
end

local function normalizeSoundName(value)
	if type(value) ~= "string" or value == "" then return (Helper and Helper.ENTRY_DEFAULTS and Helper.ENTRY_DEFAULTS.soundReadyFile) or "None" end
	return value
end

local function getSoundLabel(value)
	local soundName = normalizeSoundName(value)
	if soundName == "None" then return L["None"] or _G.NONE or "None" end
	return soundName
end

local function getSoundButtonText(value) return (L["CooldownPanelSound"] or "Sound") .. ": " .. getSoundLabel(value) end

local function getSoundOptions()
	local list = {}
	local seen = {}
	local function add(name)
		if type(name) ~= "string" or name == "" then return end
		local key = string.lower(name)
		if seen[key] then return end
		seen[key] = true
		list[#list + 1] = name
	end
	local names = addon.functions and addon.functions.GetLSMMediaNames and addon.functions.GetLSMMediaNames("sound") or {}
	for i = 1, #names do
		add(names[i])
	end
	add((LSM and LSM.DefaultMedia and LSM.DefaultMedia.sound) or nil)
	add((Helper and Helper.ENTRY_DEFAULTS and Helper.ENTRY_DEFAULTS.soundReadyFile) or nil)
	for i, name in ipairs(list) do
		if name == "None" then
			table.remove(list, i)
			table.insert(list, 1, name)
			break
		end
	end
	return list
end

local function resolveSoundFile(soundName)
	local value = normalizeSoundName(soundName)
	if value == "None" then return nil end
	if LSM and LSM.Fetch then
		local file = LSM:Fetch("sound", value, true)
		if file then return file end
	end
	return value
end

local function playSoundName(soundName)
	if not soundName or soundName == "" then return end
	local numeric = tonumber(soundName)
	if numeric and PlaySound then
		PlaySound(numeric, "Master")
		return
	end
	local file = resolveSoundFile(soundName)
	if file and PlaySoundFile then PlaySoundFile(file, "Master") end
end

function CooldownPanels:GetEntrySoundConfig(entry, requestedMode)
	if type(entry) ~= "table" then return nil end
	local entryType = entry.type
	local mode = requestedMode
	if mode == nil and entryType ~= "MACRO" and entryType ~= "STANCE" and entryType ~= "CDM_AURA" then mode = "ready" end
	if mode == "ready" and entryType ~= "MACRO" and entryType ~= "STANCE" and entryType ~= "CDM_AURA" then
		return mode, "soundReady", "soundReadyFile", L["CooldownPanelSoundReady"] or "Sound when ready"
	end
	return nil
end

local function setExampleCooldown(cooldown)
	if not cooldown then return end
	local setAsPercent = _G.CooldownFrame_SetDisplayAsPercentage
	if setAsPercent then
		setAsPercent(cooldown, Helper.EXAMPLE_COOLDOWN_PERCENT)
	elseif cooldown.SetCooldown and Api.GetTime then
		local duration = 100
		cooldown:SetCooldown(Api.GetTime() - (duration * Helper.EXAMPLE_COOLDOWN_PERCENT), duration, 1)
	end
	cooldown._eqolPreviewCooldown = true
	if cooldown.Pause then cooldown:Pause() end
end

local function clearPreviewCooldown(cooldown)
	if not cooldown or not cooldown._eqolPreviewCooldown then return end
	cooldown._eqolPreviewCooldown = nil
	if cooldown.Clear then cooldown:Clear() end
	if cooldown.Resume then cooldown:Resume() end
end

local getPreviewEntryIds
local function getPreviewCount(panel)
	if not panel or type(panel.order) ~= "table" then return Helper.DEFAULT_PREVIEW_COUNT end
	if Helper.IsFixedLayout(panel.layout) then
		local count = Helper.GetFixedSlotCount(panel, true)
		if count > Helper.MAX_PREVIEW_COUNT then return Helper.MAX_PREVIEW_COUNT end
		return count
	end
	local entries = getPreviewEntryIds and getPreviewEntryIds(panel) or nil
	if not entries then
		local count = #panel.order
		if count <= 0 then return Helper.DEFAULT_PREVIEW_COUNT end
		if count > Helper.MAX_PREVIEW_COUNT then return Helper.MAX_PREVIEW_COUNT end
		return count
	end
	local count = #entries
	if count <= 0 then return 0 end
	if count > Helper.MAX_PREVIEW_COUNT then return Helper.MAX_PREVIEW_COUNT end
	return count
end

local function getEditorPreviewCount(panel, previewFrame, baseLayout, entries)
	if not panel or type(panel.order) ~= "table" then return Helper.DEFAULT_PREVIEW_COUNT end
	local layoutMode = Helper.NormalizeLayoutMode(baseLayout and baseLayout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode)
	local count
	if layoutMode == "FIXED" then
		count = Helper.GetFixedSlotCount(panel, true)
	elseif entries then
		count = #entries
		if count <= 0 then return 0 end
	else
		count = #panel.order
		if count <= 0 then return Helper.DEFAULT_PREVIEW_COUNT end
	end
	if not previewFrame then return count end

	if layoutMode == "RADIAL" then return count end

	local spacing = Helper.ClampInt((baseLayout and baseLayout.spacing) or 0, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS.spacing)
	local step = Helper.PREVIEW_ICON_SIZE + spacing
	if step <= 0 then return count end
	local width = previewFrame:GetWidth() or 0
	local height = previewFrame:GetHeight() or 0
	if width <= 0 or height <= 0 then return count end

	local cols = math.floor((width + spacing) / step)
	local rows = math.floor((height + spacing) / step)
	if cols < 1 then cols = 1 end
	if rows < 1 then rows = 1 end
	local capacity = cols * rows
	if capacity <= 0 then return count end
	return math.min(count, capacity)
end

function CooldownPanels.NormalizeMacroName(name)
	if type(name) ~= "string" then return nil end
	if strtrim then name = strtrim(name) end
	if name == "" then return nil end
	return name
end

function CooldownPanels.NormalizePanelGroupName(name)
	if type(name) ~= "string" then return nil end
	if strtrim then name = strtrim(name) end
	if name == "" then return nil end
	return name
end

function CooldownPanels.GetFixedGroups(panel)
	if not panel then return {} end
	panel.layout = panel.layout or {}
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	return cache and cache.groups or Helper.NormalizeFixedGroups(panel.layout)
end

function CooldownPanels.GetFixedGroupName(group)
	if type(group) ~= "table" then return nil end
	local name = type(group.name) == "string" and group.name or nil
	if name and strtrim then name = strtrim(name) end
	if name == "" then name = nil end
	return name or ("Group " .. tostring(group.id or "?"))
end

function CooldownPanels.GetFixedGroupById(panel, groupId)
	if not panel then return nil end
	return Helper.GetFixedGroupById(panel, groupId)
end

function CooldownPanels.GetFixedGroupAtCell(panel, column, row, ignoreGroupId)
	if not panel then return nil end
	return Helper.GetFixedGroupAtCell(panel, column, row, ignoreGroupId)
end

function CooldownPanels.GetFixedGroupMode(group) return Helper.GetFixedGroupMode(group) end

function CooldownPanels.IsFixedGroupStatic(group) return Helper.FixedGroupUsesStaticSlots(group) end

function CooldownPanels.GetFixedGroupModeLabel(group) return CooldownPanels.IsFixedGroupStatic(group) and (L["CooldownPanelStatic"] or "Static") or (L["CooldownPanelDynamic"] or "Dynamic") end

function CooldownPanels.GetFixedGroupDisplayLabel(group)
	local name = CooldownPanels.GetFixedGroupName(group)
	return string.format("%s [%s]", tostring(name or "Group"), CooldownPanels.GetFixedGroupModeLabel(group))
end

function CooldownPanels.BumpFixedGroupEffectiveLayoutVersion(panel)
	if type(panel) ~= "table" then return end
	panel._eqolFixedGroupEffectiveLayoutVersion = (panel._eqolFixedGroupEffectiveLayoutVersion or 0) + 1
end

function CooldownPanels:ClearFixedGroupEffectiveLayoutCache(panelId, groupId)
	panelId = normalizeId(panelId)
	if not panelId then return end
	local runtime = getRuntime(panelId)
	local cache = runtime and runtime._eqolFixedGroupEffectiveLayouts or nil
	if not cache then return end
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if groupId then
		cache[groupId] = nil
	else
		for key in pairs(cache) do
			cache[key] = nil
		end
	end
end

function CooldownPanels:GetFixedGroupLayoutOverrides(panel, groupOrId, create)
	local group = type(groupOrId) == "table" and groupOrId or (panel and CooldownPanels.GetFixedGroupById(panel, groupOrId) or nil)
	if not group then return nil end
	local overrides = Helper.NormalizeFixedGroupLayoutOverrides(group.layoutOverrides)
	if overrides then
		group.layoutOverrides = overrides
	elseif create == true then
		overrides = {}
		group.layoutOverrides = overrides
	else
		group.layoutOverrides = nil
	end
	return overrides
end

function CooldownPanels:GetFixedGroupEffectiveLayout(panelId, groupId, buildCache)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if buildCache and groupId and buildCache[groupId] then return buildCache[groupId] end
	local panel = panelId and self:GetPanel(panelId) or nil
	local layout = panel and panel.layout or nil
	local fixedLayoutCache = panel and Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	local group = groupId and fixedLayoutCache and fixedLayoutCache.groupById and fixedLayoutCache.groupById[groupId] or (panel and groupId and CooldownPanels.GetFixedGroupById(panel, groupId) or nil)
	if not (panelId and panel and layout and group) then return layout end
	if buildCache and buildCache[group.id] then return buildCache[group.id] end
	local overrides = self:GetFixedGroupLayoutOverrides(panel, group, false)
	if not overrides then
		self:ClearFixedGroupEffectiveLayoutCache(panelId, group.id)
		if buildCache then buildCache[group.id] = layout end
		return layout
	end
	local runtime = getRuntime(panelId)
	runtime._eqolFixedGroupEffectiveLayouts = runtime._eqolFixedGroupEffectiveLayouts or {}
	local effective = runtime._eqolFixedGroupEffectiveLayouts[group.id]
	if not effective then
		effective = {}
		runtime._eqolFixedGroupEffectiveLayouts[group.id] = effective
	end
	local version = panel._eqolFixedGroupEffectiveLayoutVersion or 0
	if effective._eqolVersion == version and effective._eqolLayoutRef == layout and effective._eqolOverridesRef == overrides then
		if buildCache then buildCache[group.id] = effective end
		return effective
	end
	for key in pairs(effective) do
		effective[key] = nil
	end
	for key, value in pairs(layout) do
		effective[key] = value
	end
	for key, value in pairs(overrides) do
		effective[key] = value
	end
	effective._eqolVersion = version
	effective._eqolLayoutRef = layout
	effective._eqolOverridesRef = overrides
	if buildCache then buildCache[group.id] = effective end
	return effective
end

function CooldownPanels:GetEntryEffectiveLayout(panelId, entry, buildCache, panel)
	local layout = panel and panel.layout or nil
	if not layout then
		panelId = normalizeId(panelId)
		panel = panelId and self:GetPanel(panelId) or nil
		layout = panel and panel.layout or nil
	end
	if not entry then return layout end
	local groupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
	if not groupId then return layout end
	return self:GetFixedGroupEffectiveLayout(panelId, groupId, buildCache) or layout
end

function CooldownPanels:IsFixedCellWithinBounds(panel, column, row)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and column and row) then return false end
	local columns, rows = Helper.GetFixedGridBounds(panel, false)
	if columns <= 0 or rows <= 0 then return false end
	return column >= 1 and column <= columns and row >= 1 and row <= rows
end

function CooldownPanels.GetEntryFixedPlacement(panel, entryOrId)
	local entry = entryOrId
	if type(entryOrId) ~= "table" then entry = panel and panel.entries and panel.entries[entryOrId] or nil end
	if not entry then return nil end
	local column = Helper.NormalizeSlotCoordinate(entry.slotColumn)
	local row = Helper.NormalizeSlotCoordinate(entry.slotRow)
	if not (column and row) then return nil end
	local group = CooldownPanels.GetFixedGroupById(panel, entry.fixedGroupId)
	if group then
		if not CooldownPanels.IsFixedGroupStatic(group) then return nil end
		if column < group.column or column > (group.column + group.columns - 1) or row < group.row or row > (group.row + group.rows - 1) then return nil end
		return {
			groupId = group.id,
			column = column,
			row = row,
		}
	end
	return {
		groupId = nil,
		column = column,
		row = row,
	}
end

function CooldownPanels.AssignEntryFixedPlacement(entry, placement)
	if not entry then return end
	entry.fixedGroupId = placement and Helper.NormalizeFixedGroupId(placement.groupId) or nil
	entry.slotColumn = placement and Helper.NormalizeSlotCoordinate(placement.column) or nil
	entry.slotRow = placement and Helper.NormalizeSlotCoordinate(placement.row) or nil
	entry.slotIndex = nil
end

function CooldownPanels:SyncEntryFixedGroupState(panel, entry)
	if not (panel and entry) then return end
	local group = CooldownPanels.GetFixedGroupById(panel, entry.fixedGroupId)
	if group then
		entry.fixedGroupId = group.id
	else
		entry.fixedGroupId = nil
	end
	Helper.SyncEntryFixedGroupIconState(panel, entry, group)
end

function CooldownPanels:GetEntryAtUngroupedFixedCell(panel, column, row, skipEntryId)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and column and row) then return nil end
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	local key = tostring(column) .. ":" .. tostring(row)
	local cachedId = cache and cache.entryAtUngroupedCell and cache.entryAtUngroupedCell[key] or nil
	if cachedId and cachedId ~= skipEntryId then return cachedId, panel.entries and panel.entries[cachedId] or nil end
	for _, entryId in ipairs(panel.order or {}) do
		if entryId ~= skipEntryId then
			local entry = panel.entries and panel.entries[entryId]
			if
				entry
				and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == nil
				and Helper.NormalizeSlotCoordinate(entry.slotColumn) == column
				and Helper.NormalizeSlotCoordinate(entry.slotRow) == row
			then
				return entryId, entry
			end
		end
	end
	return nil
end

function CooldownPanels:GetEntryAtStaticGroupCell(panel, groupId, column, row, skipEntryId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and groupId and column and row) then return nil end
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	local key = tostring(column) .. ":" .. tostring(row)
	local groupCells = cache and cache.entryAtStaticGroupCell and cache.entryAtStaticGroupCell[groupId] or nil
	local cachedId = groupCells and groupCells[key] or nil
	if cachedId and cachedId ~= skipEntryId then return cachedId, panel.entries and panel.entries[cachedId] or nil end
	for _, entryId in ipairs(panel.order or {}) do
		if entryId ~= skipEntryId then
			local entry = panel.entries and panel.entries[entryId]
			if
				entry
				and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == groupId
				and Helper.NormalizeSlotCoordinate(entry.slotColumn) == column
				and Helper.NormalizeSlotCoordinate(entry.slotRow) == row
			then
				return entryId, entry
			end
		end
	end
	return nil
end

function CooldownPanels:FindFirstFreeUngroupedFixedCell(panel, skipEntryId, skipEntryId2)
	if not panel then return nil end
	local columns, rows = Helper.GetFixedGridBounds(panel, false)
	if columns <= 0 or rows <= 0 then return nil end
	for row = 1, rows do
		for column = 1, columns do
			if not CooldownPanels.GetFixedGroupAtCell(panel, column, row) then
				local occupantId = self:GetEntryAtUngroupedFixedCell(panel, column, row, skipEntryId)
				if not occupantId or occupantId == skipEntryId2 then return column, row end
			end
		end
	end
	return nil
end

function CooldownPanels:FindFirstFreeStaticGroupCell(panel, groupId, skipEntryId, skipEntryId2)
	if not panel then return nil end
	local group = CooldownPanels.GetFixedGroupById(panel, groupId)
	if not (group and CooldownPanels.IsFixedGroupStatic(group)) then return nil end
	for row = group.row, group.row + group.rows - 1 do
		for column = group.column, group.column + group.columns - 1 do
			if CooldownPanels:IsFixedCellWithinBounds(panel, column, row) then
				local occupantId = self:GetEntryAtStaticGroupCell(panel, group.id, column, row, skipEntryId)
				if not occupantId or occupantId == skipEntryId2 then return column, row end
			end
		end
	end
	return nil
end

function CooldownPanels:ResolveFixedEntryAddOverrides(panel, overrides)
	if not (panel and Helper.IsFixedLayout(panel.layout)) then return overrides, nil end
	local resolved = {}
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			resolved[key] = value
		end
	end
	local slotColumn = Helper.NormalizeSlotCoordinate(resolved.slotColumn)
	local slotRow = Helper.NormalizeSlotCoordinate(resolved.slotRow)
	local targetGroup = resolved.fixedGroupId and CooldownPanels.GetFixedGroupById(panel, resolved.fixedGroupId) or nil
	if targetGroup then
		resolved.fixedGroupId = targetGroup.id
		if CooldownPanels.IsFixedGroupStatic(targetGroup) then
			if slotColumn and slotRow and not CooldownPanels.RectContainsCell(targetGroup.column, targetGroup.row, targetGroup.columns, targetGroup.rows, slotColumn, slotRow) then
				return nil, L["CooldownPanelFixedTargetInvalid"] or "Target slot is outside the selected group."
			end
			if not (slotColumn and slotRow) or self:GetEntryAtStaticGroupCell(panel, targetGroup.id, slotColumn, slotRow) then
				slotColumn, slotRow = self:FindFirstFreeStaticGroupCell(panel, targetGroup.id)
			end
			if not (slotColumn and slotRow) then return nil, L["CooldownPanelFixedGroupFull"] or "Fixed group is full." end
			resolved.slotColumn = slotColumn
			resolved.slotRow = slotRow
			resolved.slotIndex = nil
		else
			resolved.slotColumn = nil
			resolved.slotRow = nil
			resolved.slotIndex = nil
		end
		return resolved, nil
	end
	if slotColumn and slotRow and not self:IsFixedCellWithinBounds(panel, slotColumn, slotRow) then return nil, L["CooldownPanelFixedTargetInvalid"] or "Target slot is outside the panel bounds." end
	if not (slotColumn and slotRow) or CooldownPanels.GetFixedGroupAtCell(panel, slotColumn, slotRow) or self:GetEntryAtUngroupedFixedCell(panel, slotColumn, slotRow) then
		slotColumn, slotRow = self:FindFirstFreeUngroupedFixedCell(panel)
	end
	if not (slotColumn and slotRow) then return nil, L["CooldownPanelFixedPanelFull"] or "Fixed panel is full." end
	resolved.fixedGroupId = nil
	resolved.slotColumn = slotColumn
	resolved.slotRow = slotRow
	resolved.slotIndex = nil
	return resolved, nil
end

function CooldownPanels:GetFixedEntryAddError(panel, overrides)
	local _, fixedError = self:ResolveFixedEntryAddOverrides(panel, overrides)
	return fixedError
end

function CooldownPanels:GetFixedDropEntryOverrides(panelId, targetSlot)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	if not (panel and targetSlot and Helper.IsFixedLayout(panel.layout)) then return nil end
	local column = Helper.NormalizeSlotCoordinate(targetSlot.column or targetSlot.slotColumn or targetSlot.x)
	local row = Helper.NormalizeSlotCoordinate(targetSlot.row or targetSlot.slotRow or targetSlot.y)
	if not (column and row) then return nil end
	local overrides = {
		slotColumn = column,
		slotRow = row,
		slotIndex = nil,
	}
	local group = CooldownPanels.GetFixedGroupAtCell(panel, column, row)
	if group then
		overrides.fixedGroupId = group.id
		if not CooldownPanels.IsFixedGroupStatic(group) then
			overrides.slotColumn = nil
			overrides.slotRow = nil
		end
	end
	return overrides
end

function CooldownPanels.GetFixedGridColumnCount(panel)
	if not panel then return 0 end
	local columns = select(1, Helper.GetFixedGridBounds(panel, false)) or 0
	return columns
end

function CooldownPanels.GetFixedGridCellIndex(panel, column, row)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and column and row) then return nil, 0 end
	local columns = CooldownPanels.GetFixedGridColumnCount(panel)
	if columns <= 0 then return nil, columns end
	return ((row - 1) * columns) + column, columns
end

function CooldownPanels.GetFixedGroupCells(group)
	local cells = {}
	if type(group) ~= "table" then return cells end
	if CooldownPanels.IsFixedGroupStatic(group) ~= true and Helper.GetFixedGroupOrderedCells then return Helper.GetFixedGroupOrderedCells(group) end
	for row = 0, (group.rows or 0) - 1 do
		for column = 0, (group.columns or 0) - 1 do
			cells[#cells + 1] = {
				column = group.column + column,
				row = group.row + row,
			}
		end
	end
	return cells
end

function CooldownPanels.GetFixedGroupEntriesInOrder(panel, groupId, skipEntryId)
	local entries = {}
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not (panel and groupId) then return entries end
	local cache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	local cachedEntries = cache and cache.groupEntryIds and cache.groupEntryIds[groupId] or nil
	if cachedEntries then
		for i = 1, #cachedEntries do
			local candidateId = cachedEntries[i]
			if candidateId ~= skipEntryId then entries[#entries + 1] = candidateId end
		end
		return entries
	end
	for _, candidateId in ipairs(panel.order or {}) do
		if candidateId ~= skipEntryId then
			local entry = panel.entries and panel.entries[candidateId]
			if entry and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == groupId then entries[#entries + 1] = candidateId end
		end
	end
	return entries
end

function CooldownPanels:GetFixedGroupLabel(panelId, groupId)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	return group and CooldownPanels.GetFixedGroupName(group) or nil
end

function CooldownPanels:FindNextFixedGroupId(panel)
	if not panel then return nil end
	local groups = CooldownPanels.GetFixedGroups(panel)
	local used = {}
	for i = 1, #groups do
		local group = groups[i]
		if group and group.id then used[group.id] = true end
	end
	local nextIndex = 1
	while used["group" .. tostring(nextIndex)] do
		nextIndex = nextIndex + 1
	end
	return "group" .. tostring(nextIndex), nextIndex
end

function CooldownPanels:DoesFixedGroupRectOverlap(panel, column, row, columns, rows, ignoreGroupId)
	if not panel then return true end
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	columns = Helper.NormalizeFixedGridSize(columns, 0)
	rows = Helper.NormalizeFixedGridSize(rows, 0)
	if not (column and row) or columns <= 0 or rows <= 0 then return true end
	local targetRight = column + columns - 1
	local targetBottom = row + rows - 1
	for _, group in ipairs(CooldownPanels.GetFixedGroups(panel)) do
		if group and group.id ~= Helper.NormalizeFixedGroupId(ignoreGroupId) then
			local groupRight = group.column + group.columns - 1
			local groupBottom = group.row + group.rows - 1
			local overlaps = not (targetRight < group.column or groupRight < column or targetBottom < group.row or groupBottom < row)
			if overlaps then return true end
		end
	end
	return false
end

function CooldownPanels.RectContainsCell(column, row, columns, rows, targetColumn, targetRow)
	if not (column and row and columns and rows and targetColumn and targetRow) then return false end
	return targetColumn >= column and targetColumn <= (column + columns - 1) and targetRow >= row and targetRow <= (row + rows - 1)
end

function CooldownPanels:CanCreateFixedGroup(panelId, column, row, columns, rows)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	if not panel then return false end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	if not Helper.IsFixedLayout(panel.layout) then return false end
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	columns = Helper.NormalizeFixedGridSize(columns, 0)
	rows = Helper.NormalizeFixedGridSize(rows, 0)
	if not (column and row) or columns <= 0 or rows <= 0 then return false end
	local gridColumns, gridRows = Helper.GetFixedGridBounds(panel, false)
	if gridColumns <= 0 or gridRows <= 0 then return false end
	if (column + columns - 1) > gridColumns or (row + rows - 1) > gridRows then return false end
	if self:DoesFixedGroupRectOverlap(panel, column, row, columns, rows, nil) then return false end
	for _, entry in pairs(panel.entries or {}) do
		if entry and Helper.NormalizeFixedGroupId(entry.fixedGroupId) ~= nil then
			local entryGroup = CooldownPanels.GetFixedGroupById(panel, entry.fixedGroupId)
			if entryGroup and CooldownPanels.RectContainsCell(column, row, columns, rows, entryGroup.column, entryGroup.row) then return false end
		end
	end
	return true
end

function CooldownPanels:CreateFixedGroup(panelId, column, row, columns, rows, name)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	if not panel then return nil end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	if not Helper.IsFixedLayout(layout) then return nil end
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	columns = Helper.NormalizeFixedGridSize(columns, 0)
	rows = Helper.NormalizeFixedGridSize(rows, 0)
	if not (column and row) or columns <= 0 or rows <= 0 then return nil end
	if self:DoesFixedGroupRectOverlap(panel, column, row, columns, rows, nil) then return nil end
	layout.fixedGroups = layout.fixedGroups or {}
	local groupId, nextIndex = self:FindNextFixedGroupId(panel)
	if not groupId then return nil end
	local groupName = CooldownPanels.NormalizePanelGroupName(name) or ("Group " .. tostring(nextIndex or #layout.fixedGroups + 1))
	local group = {
		id = groupId,
		name = groupName,
		column = column,
		row = row,
		columns = columns,
		rows = rows,
		mode = "DYNAMIC",
		dynamicStartPoint = "TOPLEFT",
		dynamicDirection = "RIGHT",
		iconSize = nil,
		layoutOverrides = nil,
	}
	layout.fixedGroups[#layout.fixedGroups + 1] = group
	Helper.NormalizeFixedGroups(layout)

	for _, entryId in ipairs(panel.order or {}) do
		local entry = panel.entries and panel.entries[entryId]
		if entry then
			local currentGroupId = Helper.NormalizeFixedGroupId(entry.fixedGroupId)
			if currentGroupId == nil then
				local slotColumn = Helper.NormalizeSlotCoordinate(entry.slotColumn)
				local slotRow = Helper.NormalizeSlotCoordinate(entry.slotRow)
				if CooldownPanels.RectContainsCell(column, row, columns, rows, slotColumn, slotRow) then entry.fixedGroupId = groupId end
			end
		end
	end

	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	self:InvalidateLayoutEditGrid(panelId)
	return groupId
end

function CooldownPanels:RenameFixedGroup(panelId, groupId, name)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	local normalizedName = CooldownPanels.NormalizePanelGroupName(name)
	if not (group and normalizedName) then return false end
	if group.name == normalizedName then return false end
	group.name = normalizedName
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:DeleteFixedGroup(panelId, groupId)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	if not panel then return false end
	local layout = panel.layout or {}
	local groups = CooldownPanels.GetFixedGroups(panel)
	local group, groupIndex = CooldownPanels.GetFixedGroupById(panel, groupId)
	if not (group and groupIndex) then return false end
	local memberIds = CooldownPanels.GetFixedGroupEntriesInOrder(panel, group.id)
	local cells = CooldownPanels.GetFixedGroupCells(group)
	for i = 1, #memberIds do
		local entry = panel.entries and panel.entries[memberIds[i]]
		if entry then
			entry.fixedGroupId = nil
			local cell = cells[i]
			if cell then
				entry.slotColumn = cell.column
				entry.slotRow = cell.row
				entry.slotIndex = nil
			else
				entry.slotColumn = nil
				entry.slotRow = nil
				entry.slotIndex = nil
			end
		end
	end
	table.remove(layout.fixedGroups, groupIndex)
	Helper.NormalizeFixedGroups(layout)
	self:ClearFixedGroupEffectiveLayoutCache(panelId, group.id)
	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:SetFixedGroupMode(panelId, groupId, mode)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	mode = Helper.NormalizeFixedGroupMode(mode, "DYNAMIC")
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not (panel and group) then return false, "GROUP_NOT_FOUND" end
	if CooldownPanels.GetFixedGroupMode(group) == mode then return false, "UNCHANGED" end
	if mode == "STATIC" then
		local members = CooldownPanels.GetFixedGroupEntriesInOrder(panel, group.id)
		local capacity = Helper.GetFixedGroupCapacity(group)
		if #members > capacity then return false, "GROUP_FULL" end
	end
	group.mode = mode
	Helper.NormalizeFixedGroups(panel.layout)
	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:SetFixedGroupDynamicStartPoint(panelId, groupId, startPoint)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not (panel and group) then return false end
	local currentStartPoint = Helper.NormalizeFixedGroupStartPoint(group.dynamicStartPoint, "TOPLEFT")
	local currentDirection = Helper.NormalizeFixedGroupDynamicDirection(currentStartPoint, group.dynamicDirection, nil)
	local nextStartPoint = Helper.NormalizeFixedGroupStartPoint(startPoint, currentStartPoint)
	local nextDirection = Helper.NormalizeFixedGroupDynamicDirection(nextStartPoint, currentDirection, nil)
	if currentStartPoint == nextStartPoint and currentDirection == nextDirection then return false end
	group.dynamicStartPoint = nextStartPoint
	group.dynamicDirection = nextDirection
	Helper.NormalizeFixedGroups(panel.layout)
	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:SetFixedGroupDynamicDirection(panelId, groupId, direction)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not (panel and group) then return false end
	local startPoint = Helper.NormalizeFixedGroupStartPoint(group.dynamicStartPoint, "TOPLEFT")
	local currentDirection = Helper.NormalizeFixedGroupDynamicDirection(startPoint, group.dynamicDirection, nil)
	local nextDirection = Helper.NormalizeFixedGroupDynamicDirection(startPoint, direction, currentDirection)
	if currentDirection == nextDirection then return false end
	group.dynamicDirection = nextDirection
	Helper.NormalizeFixedGroups(panel.layout)
	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:SetFixedGroupIconSize(panelId, groupId, iconSize)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not (panel and group) then return false end
	local normalizedSize = Helper.NormalizeFixedGroupIconSize(iconSize)
	local currentSize = Helper.NormalizeFixedGroupIconSize(group.iconSize)
	if currentSize == normalizedSize then return false end
	group.iconSize = normalizedSize
	for _, entryId in ipairs(panel.order or {}) do
		local entry = panel.entries and panel.entries[entryId]
		if entry and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == group.id then self:SyncEntryFixedGroupState(panel, entry) end
	end
	Helper.NormalizeFixedGroups(panel.layout)
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:SetFixedGroupLayoutOverride(panelId, groupId, field, value)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if type(field) ~= "string" then return false end
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not (panel and group) then return false end
	local layout = panel.layout or Helper.PANEL_LAYOUT_DEFAULTS
	local currentLayout = self:GetFixedGroupEffectiveLayout(panelId, group.id)
	local overrides = self:GetFixedGroupLayoutOverrides(panel, group, true)
	local currentValue
	local baseValue
	local nextValue

	if field == "iconOffsetX" then
		baseValue = 0
		currentValue = Helper.ClampInt(currentLayout and currentLayout.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
		nextValue = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	elseif field == "iconOffsetY" then
		baseValue = 0
		currentValue = Helper.ClampInt(currentLayout and currentLayout.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
		nextValue = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	elseif field == "procGlowEnabled" then
		baseValue = self:ResolveEntryProcGlowEnabled(layout, nil)
		currentValue = self:ResolveEntryProcGlowEnabled(currentLayout, nil)
		nextValue = value ~= false
	elseif field == "hideGlowOutOfCombat" then
		baseValue = layout.hideGlowOutOfCombat == true
		currentValue = currentLayout and currentLayout.hideGlowOutOfCombat == true or false
		nextValue = value == true
	elseif field == "procGlowStyle" then
		baseValue = select(1, self:ResolveEntryProcGlowVisual(layout, nil))
		currentValue = select(1, self:ResolveEntryProcGlowVisual(currentLayout, nil))
		nextValue = Helper.NormalizeGlowStyle(value, baseValue)
	elseif field == "procGlowInset" then
		baseValue = select(2, self:ResolveEntryProcGlowVisual(layout, nil))
		currentValue = select(2, self:ResolveEntryProcGlowVisual(currentLayout, nil))
		nextValue = Helper.NormalizeGlowInset(value, baseValue)
	elseif field == "readyGlowCheckPower" then
		baseValue = self:ResolveEntryReadyGlowCheckPower(layout, nil)
		currentValue = self:ResolveEntryReadyGlowCheckPower(currentLayout, nil)
		nextValue = value == true
	elseif field == "readyGlowStyle" then
		baseValue = select(3, self:ResolveEntryGlowStyle(layout, nil))
		currentValue = select(3, self:ResolveEntryGlowStyle(currentLayout, nil))
		nextValue = Helper.NormalizeGlowStyle(value, baseValue)
	elseif field == "readyGlowInset" then
		baseValue = select(4, self:ResolveEntryGlowStyle(layout, nil))
		currentValue = select(4, self:ResolveEntryGlowStyle(currentLayout, nil))
		nextValue = Helper.NormalizeGlowInset(value, baseValue)
	elseif field == "readyGlowColor" then
		baseValue = select(2, self:ResolveEntryGlowStyle(layout, nil))
		currentValue = select(2, self:ResolveEntryGlowStyle(currentLayout, nil))
		nextValue = Helper.NormalizeColor(value, baseValue)
	elseif field == "pandemicGlowStyle" then
		baseValue = select(2, self:ResolveEntryPandemicGlowVisual(layout, nil))
		currentValue = select(2, self:ResolveEntryPandemicGlowVisual(currentLayout, nil))
		nextValue = Helper.NormalizeGlowStyle(value, baseValue)
	elseif field == "pandemicGlowInset" then
		baseValue = select(3, self:ResolveEntryPandemicGlowVisual(layout, nil))
		currentValue = select(3, self:ResolveEntryPandemicGlowVisual(currentLayout, nil))
		nextValue = Helper.NormalizeGlowInset(value, baseValue)
	elseif field == "pandemicGlowColor" then
		baseValue = select(1, self:ResolveEntryPandemicGlowVisual(layout, nil))
		currentValue = select(1, self:ResolveEntryPandemicGlowVisual(currentLayout, nil))
		nextValue = Helper.NormalizeColor(value, baseValue)
	else
		return false
	end

	local function valuesEqual(left, right)
		if type(left) == "table" or type(right) == "table" then
			local l = Helper.NormalizeColor(left, { 0, 0, 0, 0 })
			local r = Helper.NormalizeColor(right, { 0, 0, 0, 0 })
			return l[1] == r[1] and l[2] == r[2] and l[3] == r[3] and l[4] == r[4]
		end
		return left == right
	end

	if valuesEqual(currentValue, nextValue) then return false end
	if valuesEqual(nextValue, baseValue) then
		overrides[field] = nil
	else
		overrides[field] = nextValue
	end
	group.layoutOverrides = Helper.NormalizeFixedGroupLayoutOverrides(overrides)
	CooldownPanels.BumpFixedGroupEffectiveLayoutVersion(panel)
	self:ClearFixedGroupEffectiveLayoutCache(panelId, group.id)
	if field == "readyGlowCheckPower" then self:RebuildPowerIndex() end
	self:InvalidateLayoutEditGrid(panelId)
	return true
end

function CooldownPanels:MoveFixedGroup(panelId, groupId, column, row)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	if not panel then return false, "PANEL_NOT_FOUND" end
	local group = CooldownPanels.GetFixedGroupById(panel, groupId)
	if not group then return false, "GROUP_NOT_FOUND" end
	local sourceColumn = group.column
	local sourceRow = group.row
	local groupColumns = group.columns
	local groupRows = group.rows
	local staticGroup = CooldownPanels.IsFixedGroupStatic(group)
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (column and row) then return false, "INVALID_TARGET" end
	if column == sourceColumn and row == sourceRow then return false, "NO_CHANGE" end
	local gridColumns, gridRows = Helper.GetFixedGridBounds(panel, false)
	if gridColumns <= 0 or gridRows <= 0 then return false, "GRID_BOUNDS_INVALID" end
	if (column + groupColumns - 1) > gridColumns or (row + groupRows - 1) > gridRows then return false, "OUT_OF_BOUNDS" end
	if self:DoesFixedGroupRectOverlap(panel, column, row, groupColumns, groupRows, groupId) then return false, "OVERLAP" end
	for _, entryId in ipairs(panel.order or {}) do
		local entry = panel.entries and panel.entries[entryId]
		if entry and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == nil then
			local slotColumn = Helper.NormalizeSlotCoordinate(entry.slotColumn)
			local slotRow = Helper.NormalizeSlotCoordinate(entry.slotRow)
			if CooldownPanels.RectContainsCell(column, row, groupColumns, groupRows, slotColumn, slotRow) then return false, "UNGROUPED_OCCUPIED" end
		end
	end
	local deltaColumn = column - sourceColumn
	local deltaRow = row - sourceRow
	if staticGroup and (deltaColumn ~= 0 or deltaRow ~= 0) then
		for _, entryId in ipairs(panel.order or {}) do
			local entry = panel.entries and panel.entries[entryId]
			if entry and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == groupId then
				local slotColumn = Helper.NormalizeSlotCoordinate(entry.slotColumn)
				local slotRow = Helper.NormalizeSlotCoordinate(entry.slotRow)
				if slotColumn and slotRow then
					entry.slotColumn = slotColumn + deltaColumn
					entry.slotRow = slotRow + deltaRow
					entry.slotIndex = nil
				end
			end
		end
	end
	group = CooldownPanels.GetFixedGroupById(panel, groupId)
	if not group then return false, "GROUP_NOT_FOUND_REFETCH" end
	group.column = column
	group.row = row
	Helper.NormalizeFixedGroups(panel.layout)
	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	self:InvalidateLayoutEditGrid(panelId)
	return true, nil
end

function CooldownPanels.ResolveMacroEntry(entry)
	if not entry or entry.type ~= "MACRO" then return nil end
	local function resolveMacroSpellId(token)
		if token == nil then return nil end
		if type(token) == "number" then
			if token > 0 then return token end
			return nil
		end
		if type(token) ~= "string" or token == "" then return nil end
		local numeric = tonumber(token)
		if numeric and numeric > 0 then return numeric end
		if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
			local spellId = C_Spell.GetSpellIDForSpellIdentifier(token)
			if type(spellId) == "number" and spellId > 0 then return spellId end
		end
		if Api.GetSpellInfoFn then
			local _, _, _, _, _, _, spellId = Api.GetSpellInfoFn(token)
			if type(spellId) == "number" and spellId > 0 then return spellId end
		end
		return nil
	end
	local function resolveMacroItemId(token)
		if token == nil then return nil end
		if type(token) == "number" then
			if token > 0 then return token end
			return nil
		end
		if type(token) ~= "string" or token == "" then return nil end
		local numeric = tonumber(token)
		if numeric and numeric > 0 then return numeric end
		local fromLink = token:match("item:(%d+)")
		if fromLink then
			local itemId = tonumber(fromLink)
			if itemId and itemId > 0 then return itemId end
		end
		if Api.GetItemInfoInstantFn then
			local itemId = Api.GetItemInfoInstantFn(token)
			if type(itemId) == "number" and itemId > 0 then return itemId end
		end
		return nil
	end
	local macroID = tonumber(entry.macroID)
	local macroName = CooldownPanels.NormalizeMacroName(entry.macroName)
	local lookup = nil

	-- Prefer stored macroID. Name lookups can collide when multiple macros share a name.
	if macroID and macroID > 0 then
		if Api.GetMacroInfo then
			local infoName = Api.GetMacroInfo(macroID)
			if infoName then
				lookup = macroID
				macroName = CooldownPanels.NormalizeMacroName(infoName) or macroName
			end
		else
			lookup = macroID
		end
	end

	if not lookup and macroName and Api.GetMacroIndexByName then
		local byName = Api.GetMacroIndexByName(macroName)
		if type(byName) == "number" and byName > 0 then
			macroID = byName
			lookup = byName
		end
	end
	if not lookup and macroName then lookup = macroName end
	if not lookup then return nil end

	local resolved = {
		macroID = macroID,
		macroName = macroName,
	}
	if Api.GetMacroInfo then
		local infoName, icon = Api.GetMacroInfo(lookup)
		resolved.macroName = CooldownPanels.NormalizeMacroName(infoName) or resolved.macroName
		resolved.icon = icon
		if (not resolved.macroID) and resolved.macroName and Api.GetMacroIndexByName then
			local byName = Api.GetMacroIndexByName(resolved.macroName)
			if type(byName) == "number" and byName > 0 then resolved.macroID = byName end
		end
	end

	local macroSpellToken = nil
	if Api.GetMacroSpell then
		macroSpellToken = Api.GetMacroSpell(lookup)
		local spellId = resolveMacroSpellId(macroSpellToken)
		if spellId then
			local baseSpellId = getBaseSpellId(spellId) or spellId
			resolved.kind = "SPELL"
			resolved.spellID = baseSpellId
			return resolved
		end
	end

	local macroItemName = nil
	local macroItemLink = nil
	if Api.GetMacroItem then
		macroItemName, macroItemLink = Api.GetMacroItem(lookup)
		local itemId = resolveMacroItemId(macroItemLink) or resolveMacroItemId(macroItemName)
		if itemId then
			resolved.kind = "ITEM"
			resolved.itemID = itemId
			return resolved
		end
	end

	return resolved
end

local function getEntryIcon(entry)
	if not entry or type(entry) ~= "table" then return Helper.PREVIEW_ICON end
	if entry.type == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.GetEntryIcon then
			local icon = cdmAuras:GetEntryIcon(entry)
			if icon then return icon end
		end
	end
	if entry.type == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		if macro then
			if macro.kind == "SPELL" and macro.spellID then return getEntryIcon({ type = "SPELL", spellID = macro.spellID }) end
			if macro.kind == "ITEM" and macro.itemID then return getEntryIcon({ type = "ITEM", itemID = macro.itemID }) end
			if macro.icon then return macro.icon end
		end
		return Helper.PREVIEW_ICON
	end
	if entry.type == "SPELL" and entry.spellID then
		local spellId = getEffectiveSpellId(entry.spellID) or entry.spellID
		local runtime = CooldownPanels.runtime
		runtime = runtime or {}
		CooldownPanels.runtime = runtime
		runtime.iconCache = runtime.iconCache or {}
		local cache = runtime.iconCache
		local cacheKey = "S:" .. tostring(spellId)
		local cached = cache[cacheKey]
		if cached then return cached end
		local icon = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellId)) or Helper.PREVIEW_ICON
		cache[cacheKey] = icon
		return icon
	end
	if entry.type == "ITEM" and entry.itemID then
		local runtime = CooldownPanels.runtime
		runtime = runtime or {}
		CooldownPanels.runtime = runtime
		runtime.iconCache = runtime.iconCache or {}
		local cache = runtime.iconCache
		local cacheKey = "I:" .. tostring(entry.itemID)
		local cached = cache[cacheKey]
		if cached then return cached end
		local icon
		if Api.GetItemIconByID then icon = Api.GetItemIconByID(entry.itemID) end
		if not icon and Api.GetItemInfoInstantFn then
			local _, _, _, _, instantIcon = Api.GetItemInfoInstantFn(entry.itemID)
			icon = instantIcon
		end
		icon = icon or Helper.PREVIEW_ICON
		cache[cacheKey] = icon
		return icon
	end
	if entry.type == "SLOT" and entry.slotID and Api.GetInventoryItemID then
		local itemID = Api.GetInventoryItemID("player", entry.slotID)
		if itemID then
			local runtime = CooldownPanels.runtime
			runtime = runtime or {}
			CooldownPanels.runtime = runtime
			runtime.iconCache = runtime.iconCache or {}
			local cache = runtime.iconCache
			local cacheKey = "I:" .. tostring(itemID)
			local cached = cache[cacheKey]
			if cached then return cached end
			local icon
			if Api.GetItemIconByID then icon = Api.GetItemIconByID(itemID) end
			if not icon and Api.GetItemInfoInstantFn then
				local _, _, _, _, instantIcon = Api.GetItemInfoInstantFn(itemID)
				icon = instantIcon
			end
			icon = icon or Helper.PREVIEW_ICON
			cache[cacheKey] = icon
			return icon
		end
	end
	if entry.type == "STANCE" and CooldownPanels.GetStanceEntryIcon then
		local icon = CooldownPanels:GetStanceEntryIcon(entry)
		if icon then return icon end
	end
	return Helper.PREVIEW_ICON
end

local SLOT_LABELS = {}
local SLOT_MENU_ENTRIES
local SLOT_DEFS = {
	{ name = "HeadSlot", label = _G.HEADSLOT or "Head" },
	{ name = "NeckSlot", label = _G.NECKSLOT or "Neck" },
	{ name = "ShoulderSlot", label = _G.SHOULDERSLOT or "Shoulder" },
	{ name = "BackSlot", label = _G.BACKSLOT or "Back" },
	{ name = "ChestSlot", label = _G.CHESTSLOT or "Chest" },
	{ name = "ShirtSlot", label = _G.SHIRTSLOT or "Shirt" },
	{ name = "TabardSlot", label = _G.TABARDSLOT or "Tabard" },
	{ name = "WristSlot", label = _G.WRISTSLOT or "Wrist" },
	{ name = "HandsSlot", label = _G.HANDSSLOT or "Hands" },
	{ name = "WaistSlot", label = _G.WAISTSLOT or "Waist" },
	{ name = "LegsSlot", label = _G.LEGSSLOT or "Legs" },
	{ name = "FeetSlot", label = _G.FEETSLOT or "Feet" },
	{ name = "Finger0Slot", label = string.format("%s 1", _G.FINGER0SLOT or "Finger") },
	{ name = "Finger1Slot", label = string.format("%s 2", _G.FINGER1SLOT or "Finger") },
	{ name = "Trinket0Slot", label = string.format("%s 1", _G.TRINKET0SLOT or "Trinket") },
	{ name = "Trinket1Slot", label = string.format("%s 2", _G.TRINKET1SLOT or "Trinket") },
	{ name = "MainHandSlot", label = _G.MAINHANDSLOT or "Main Hand" },
	{ name = "SecondaryHandSlot", label = _G.SECONDARYHANDSLOT or "Off Hand" },
	{ name = "RangedSlot", label = _G.RANGEDSLOT or "Ranged" },
}

local function getSlotMenuEntries()
	if SLOT_MENU_ENTRIES then return SLOT_MENU_ENTRIES end
	SLOT_MENU_ENTRIES = {}
	if not Api.GetInventorySlotInfo then return SLOT_MENU_ENTRIES end
	for _, def in ipairs(SLOT_DEFS) do
		local ok, slotId = pcall(Api.GetInventorySlotInfo, def.name)
		if ok and slotId then
			local label = def.label or def.name
			SLOT_LABELS[slotId] = label
			SLOT_MENU_ENTRIES[#SLOT_MENU_ENTRIES + 1] = { id = slotId, label = label }
		end
	end
	return SLOT_MENU_ENTRIES
end

local function getSlotLabel(slotId)
	if not next(SLOT_LABELS) then getSlotMenuEntries() end
	return SLOT_LABELS[slotId] or ("Slot " .. tostring(slotId))
end

local function getSpellName(spellId)
	if not spellId then return nil end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellId)
		if info and info.name then return info.name end
	end
	if GetSpellInfo then
		local name = GetSpellInfo(spellId)
		if name then return name end
	end
	return nil
end

local function getItemName(itemId)
	if not itemId then return nil end
	if C_Item and C_Item.GetItemNameByID then
		local name = C_Item.GetItemNameByID(itemId)
		if name then return name end
	end
	if C_Item and C_Item.GetItemInfo then
		local name = C_Item.GetItemInfo(itemId)
		if name then return name end
	end
	return nil
end

local function getEntryName(entry)
	if not entry then return "" end
	if entry.type == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.GetEntryName then
			local name = cdmAuras:GetEntryName(entry)
			if name and name ~= "" then return name end
		end
	end
	if entry.type == "SPELL" then
		local spellId = getEffectiveSpellId(entry.spellID) or entry.spellID
		local name = getSpellName(spellId)
		return name or ("Spell " .. tostring(entry.spellID or ""))
	end
	if entry.type == "ITEM" then
		local name = getItemName(entry.itemID)
		return name or ("Item " .. tostring(entry.itemID or ""))
	end
	if entry.type == "SLOT" then return getSlotLabel(entry.slotID) end
	if entry.type == "STANCE" and CooldownPanels.GetStanceEntryName then
		local name = CooldownPanels:GetStanceEntryName(entry)
		if name and name ~= "" then return name end
		return (CooldownPanels.GetStanceTypeLabel and CooldownPanels:GetStanceTypeLabel()) or (_G.STANCE or "Stance")
	end
	if entry.type == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		if macro and macro.macroName then return macro.macroName end
		return (_G.MACRO or "Macro") .. " " .. tostring(entry.macroID or "")
	end
	return "Entry"
end

local function getEntryTypeLabel(entryType)
	local key = entryType and tostring(entryType):upper() or nil
	if key == "SPELL" then return _G.STAT_CATEGORY_SPELL or _G.SPELLS or "Spell" end
	if key == "ITEM" then return _G.AUCTION_HOUSE_HEADER_ITEM or _G.ITEMS or "Item" end
	if key == "SLOT" then return L["CooldownPanelSlotType"] or "Slot" end
	if key == "STANCE" then return (CooldownPanels.GetStanceTypeLabel and CooldownPanels:GetStanceTypeLabel()) or (_G.STANCE or "Stance") end
	if key == "MACRO" then return _G.MACRO or "Macro" end
	if key == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.GetEntryTypeLabel then
			local label = cdmAuras:GetEntryTypeLabel(key)
			if label and label ~= "" then return label end
		end
	end
	return entryType or ""
end

function CooldownPanels:GetEntryStandaloneTitle(entry)
	local name = getEntryName(entry)
	local typeLabel = getEntryTypeLabel(entry and entry.type)
	if name and name ~= "" and typeLabel and typeLabel ~= "" then return string.format(L["CooldownPanelStandaloneEntryTitle"] or "%s - %s", name, typeLabel) end
	return name or typeLabel or ""
end

getPlayerSpecId = function()
	if not (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) then return nil end
	local specIndex = C_SpecializationInfo.GetSpecialization()
	if not specIndex then return nil end
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local specId = C_SpecializationInfo.GetSpecializationInfo(specIndex)
		if type(specId) == "number" and specId > 0 then return specId end
	end
	if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
		local info = C_SpecializationInfo.GetSpecializationInfo(specIndex)
		if type(info) == "table" and type(info.specID) == "number" and info.specID > 0 then return info.specID end
		if type(info) == "number" and info > 0 then return info end
	end
	return nil
end

local function getPlayerClassSpecMap()
	local classId = UnitClass and select(3, UnitClass("player")) or nil
	if not classId then return nil end
	local getSpecCount = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
	if not getSpecCount or not GetSpecializationInfoForClassID then return nil end
	local specs = {}
	local sex = UnitSex and UnitSex("player") or nil
	local specCount = getSpecCount(classId) or 0
	for specIndex = 1, specCount do
		local specID = GetSpecializationInfoForClassID(classId, specIndex, sex)
		if specID then specs[specID] = true end
	end
	return specs
end

local function panelHasSpecFilter(panel)
	local filter = panel and panel.specFilter
	if type(filter) ~= "table" then return false end
	for _, enabled in pairs(filter) do
		if enabled then return true end
	end
	return false
end

panelAllowsSpec = function(panel)
	if not panelHasSpecFilter(panel) then return true end
	local specId = getPlayerSpecId()
	if not specId then return false end
	local filter = panel and panel.specFilter
	return filter and filter[specId] == true
end

local function panelMatchesPlayerClass(panel, classSpecs)
	if not panelHasSpecFilter(panel) then return true end
	if not classSpecs or not next(classSpecs) then return true end
	for specId, enabled in pairs(panel.specFilter) do
		if enabled and classSpecs[specId] then return true end
	end
	return false
end

local function getSpecFilterLabel(panel)
	if not panelHasSpecFilter(panel) then return L["CooldownPanelSpecAny"] or "All specs" end
	local labels = {}
	if panel and panel.specFilter then
		for specId, enabled in pairs(panel.specFilter) do
			if enabled then labels[#labels + 1] = getSpecNameById(specId) end
		end
	end
	table.sort(labels)
	if #labels == 0 then return L["CooldownPanelSpecAny"] or "All specs" end
	return table.concat(labels, ", ")
end

local function isSpellKnownSafe(spellId)
	if not spellId then return false end
	if Api and Api.IsSpellKnown then
		local known = Api.IsSpellKnown(spellId, true)
		if known then return true end
		local overrideId = getEffectiveSpellId(spellId)
		if overrideId and overrideId ~= spellId then return Api.IsSpellKnown(overrideId, true) and true or false end
		return false
	end
	return true
end

local function spellExistsSafe(spellId)
	if not spellId then return false end
	if Api.DoesSpellExist then return Api.DoesSpellExist(spellId) and true or false end
	if C_Spell and C_Spell.GetSpellInfo then return C_Spell.GetSpellInfo(spellId) ~= nil end
	if Api.GetSpellInfoFn then return Api.GetSpellInfoFn(spellId) ~= nil end
	return true
end

local function showErrorMessage(msg)
	if UIErrorsFrame and msg then UIErrorsFrame:AddMessage(msg, 1, 0.2, 0.2, 1) end
end

ensureRoot = function()
	if not addon.db then return nil end
	if type(addon.db.cooldownPanels) ~= "table" then addon.db.cooldownPanels = Helper.CreateRoot() end
	local root = addon.db.cooldownPanels
	local needsNormalize = not normalizedRoots[root] or type(root.panels) ~= "table" or type(root.order) ~= "table" or type(root.defaults) ~= "table"
	if needsNormalize then
		Helper.NormalizeRoot(root)
		root._eqolEditorGroupsReady = nil
		root._eqolEditorGroupOrderDirty = true
		local runtime = CooldownPanels.runtime
		if runtime and runtime._eqolPanelIdCacheRoot == root then
			runtime._eqolPanelIdCache = nil
			runtime._eqolPanelIdCacheRoot = nil
		end
		normalizedRoots[root] = true
	end
	if CooldownPanels.EnsureEditorGroupStorage then CooldownPanels.EnsureEditorGroupStorage(root) end
	return root
end

CooldownPanels.EnsureEditorGroupStorage = function(root)
	if not root then return nil end
	if type(root.editorGroups) ~= "table" then
		root.editorGroups = {}
		root._eqolEditorGroupsReady = nil
		root._eqolEditorGroupOrderDirty = true
	end
	if type(root.editorGroupOrder) ~= "table" then
		root.editorGroupOrder = {}
		root._eqolEditorGroupsReady = nil
		root._eqolEditorGroupOrderDirty = true
	end
	if root._eqolEditorGroupsReady == true then
		if root._eqolEditorGroupOrderDirty == true then CooldownPanels:SortEditorGroupOrder(root) end
		return root
	end

	local groups = root.editorGroups
	local order = root.editorGroupOrder
	local groupsByName = {}

	for groupId, group in pairs(groups) do
		if type(group) ~= "table" then
			groups[groupId] = { id = groupId, name = "Group " .. tostring(groupId) }
			group = groups[groupId]
		end
		group.id = normalizeId(group.id) or normalizeId(groupId) or groupId
		group.name = CooldownPanels.NormalizePanelGroupName(group.name) or ("Group " .. tostring(group.id))
		group.parentGroupId = normalizeId(group.parentGroupId)
		groupsByName[group.name] = group.id
	end

	for groupId, group in pairs(groups) do
		local parentGroupId = normalizeId(group.parentGroupId)
		if parentGroupId == groupId or not groups[parentGroupId] then parentGroupId = nil end
		group.parentGroupId = parentGroupId
	end

	for groupId, group in pairs(groups) do
		local seen = { [groupId] = true }
		local parentGroupId = normalizeId(group.parentGroupId)
		while parentGroupId do
			if seen[parentGroupId] then
				group.parentGroupId = nil
				break
			end
			seen[parentGroupId] = true
			local parentGroup = groups[parentGroupId]
			parentGroupId = parentGroup and normalizeId(parentGroup.parentGroupId) or nil
		end
	end

	Helper.SyncOrder(order, groups)

	local panels = root.panels or {}
	for panelId, panel in pairs(panels) do
		if type(panel) == "table" then
			local groupId = normalizeId(panel.editorGroupId)
			if groupId and groups[groupId] then
				panel.editorGroupId = groupId
			else
				panel.editorGroupId = nil
			end

			local legacyName = CooldownPanels.NormalizePanelGroupName(panel.editorGroup)
			if legacyName and not panel.editorGroupId then
				local existingId = groupsByName[legacyName]
				if not existingId then
					existingId = Helper.GetNextNumericId(groups)
					groups[existingId] = { id = existingId, name = legacyName }
					order[#order + 1] = existingId
					groupsByName[legacyName] = existingId
				end
				panel.editorGroupId = existingId
			end
			panel.editorGroup = nil
		end
	end

	Helper.SyncOrder(order, groups)
	root._eqolEditorGroupsReady = true
	root._eqolEditorGroupOrderDirty = true
	CooldownPanels:SortEditorGroupOrder(root)
	return root
end

function CooldownPanels.GetEditorGroup(root, groupId)
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	groupId = normalizeId(groupId)
	return root and root.editorGroups and groupId and root.editorGroups[groupId] or nil
end

function CooldownPanels.GetEditorGroupName(root, groupId)
	local group = CooldownPanels.GetEditorGroup(root, groupId)
	return group and group.name or nil
end

function CooldownPanels.IsEditorGroupNameBefore(a, b)
	local left = CooldownPanels.NormalizePanelGroupName(a) or ""
	local right = CooldownPanels.NormalizePanelGroupName(b) or ""
	if strcmputf8i then
		local cmp = strcmputf8i(left, right)
		if cmp ~= 0 then return cmp < 0 end
	end
	local leftLower = tostring(left):lower()
	local rightLower = tostring(right):lower()
	if leftLower ~= rightLower then return leftLower < rightLower end
	return tostring(left) < tostring(right)
end

function CooldownPanels:SortEditorGroupOrder(root)
	if not root then return nil end
	if type(root.editorGroups) ~= "table" then root.editorGroups = {} end
	if type(root.editorGroupOrder) ~= "table" then root.editorGroupOrder = {} end
	if root._eqolEditorGroupsReady == true and root._eqolEditorGroupOrderDirty ~= true then return root.editorGroupOrder end
	Helper.SyncOrder(root.editorGroupOrder, root.editorGroups)
	table.sort(root.editorGroupOrder, function(leftId, rightId)
		local leftGroup = root.editorGroups[leftId]
		local rightGroup = root.editorGroups[rightId]
		local leftName = leftGroup and leftGroup.name or tostring(leftId or "")
		local rightName = rightGroup and rightGroup.name or tostring(rightId or "")
		if leftName == rightName then return (tonumber(leftId) or 0) < (tonumber(rightId) or 0) end
		return CooldownPanels.IsEditorGroupNameBefore(leftName, rightName)
	end)
	root._eqolEditorGroupOrderDirty = nil
	return root.editorGroupOrder
end

function CooldownPanels:CanSetEditorGroupParent(root, groupId, parentGroupId)
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	groupId = normalizeId(groupId)
	parentGroupId = normalizeId(parentGroupId)
	if not (root and groupId and root.editorGroups and root.editorGroups[groupId]) then return false end
	if parentGroupId == nil then return true end
	if not root.editorGroups[parentGroupId] or parentGroupId == groupId then return false end
	while parentGroupId do
		if parentGroupId == groupId then return false end
		local parentGroup = root.editorGroups[parentGroupId]
		parentGroupId = parentGroup and normalizeId(parentGroup.parentGroupId) or nil
	end
	return true
end

function CooldownPanels:BuildEditorGroupHierarchy(root)
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	local groups = root and root.editorGroups or {}
	local order = root and root.editorGroupOrder or {}
	local childrenByParent = { ["__root"] = {} }
	local depthByGroup = {}

	local function getParentKey(parentGroupId)
		parentGroupId = normalizeId(parentGroupId)
		if parentGroupId ~= nil then return tostring(parentGroupId) end
		return "__root"
	end

	for _, groupId in ipairs(order) do
		local group = groups[groupId]
		if group then
			local key = getParentKey(group.parentGroupId)
			local bucket = childrenByParent[key]
			if not bucket then
				bucket = {}
				childrenByParent[key] = bucket
			end
			bucket[#bucket + 1] = groupId
		end
	end

	local function assignDepth(parentGroupId, depth)
		local key = getParentKey(parentGroupId)
		for _, childGroupId in ipairs(childrenByParent[key] or {}) do
			if depthByGroup[childGroupId] == nil then
				depthByGroup[childGroupId] = depth
				assignDepth(childGroupId, depth + 1)
			end
		end
	end

	assignDepth(nil, 0)
	return childrenByParent, depthByGroup
end

function CooldownPanels:GetEditorGroupDescendantIdSet(root, groupId)
	local descendants = {}
	groupId = normalizeId(groupId)
	if not groupId then return descendants end
	local childrenByParent = self:BuildEditorGroupHierarchy(root)

	local function collect(parentGroupId)
		local key = parentGroupId ~= nil and tostring(parentGroupId) or "__root"
		for _, childGroupId in ipairs(childrenByParent[key] or {}) do
			descendants[childGroupId] = true
			collect(childGroupId)
		end
	end

	collect(groupId)
	return descendants
end

function CooldownPanels:PopulateEditorGroupRadioMenu(menu, root, selectedGroupId, onSelect, options)
	if not (menu and onSelect) then return false end
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	selectedGroupId = normalizeId(selectedGroupId)
	local childrenByParent, depthByGroup = self:BuildEditorGroupHierarchy(root)
	local skipGroupIds = options and options.skipGroupIds or nil
	local hasGroups = false

	local function appendChoices(parentGroupId)
		local key = parentGroupId ~= nil and tostring(parentGroupId) or "__root"
		for _, groupId in ipairs(childrenByParent[key] or {}) do
			local group = root.editorGroups and root.editorGroups[groupId] or nil
			if group then
				local skip = skipGroupIds and skipGroupIds[groupId] == true
				if not skip then
					hasGroups = true
					local depth = depthByGroup[groupId] or 0
					local prefix = depth > 0 and string.rep("> ", depth) or ""
					local label = prefix .. (group.name or ("Group " .. tostring(groupId)))
					local targetGroupId = normalizeId(groupId)
					menu:CreateRadio(label, function() return selectedGroupId == targetGroupId end, function() onSelect(targetGroupId) end)
				end
				appendChoices(groupId)
			end
		end
	end

	appendChoices(nil)
	return hasGroups
end

function CooldownPanels:CreateEditorGroup(name, parentGroupId)
	local root = ensureRoot()
	if not root then return nil end
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	local groups = root.editorGroups
	local order = root.editorGroupOrder
	local groupId = Helper.GetNextNumericId(groups)
	local groupName = CooldownPanels.NormalizePanelGroupName(name) or (L["CooldownPanelNewGroup"] or "New Group")
	parentGroupId = normalizeId(parentGroupId)
	if parentGroupId and not groups[parentGroupId] then parentGroupId = nil end
	groups[groupId] = { id = groupId, name = groupName, parentGroupId = parentGroupId }
	order[#order + 1] = groupId
	root._eqolEditorGroupOrderDirty = true
	self:SortEditorGroupOrder(root)
	return groupId
end

function CooldownPanels:RenameEditorGroup(groupId, name)
	local root = ensureRoot()
	local group = CooldownPanels.GetEditorGroup(root, groupId)
	if not group then return false end
	name = CooldownPanels.NormalizePanelGroupName(name)
	if not name then return false end
	group.name = name
	root._eqolEditorGroupOrderDirty = true
	self:SortEditorGroupOrder(root)
	return true
end

function CooldownPanels:DeleteEditorGroup(groupId)
	local root = ensureRoot()
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	groupId = normalizeId(groupId)
	if not (root and root.editorGroups and groupId and root.editorGroups[groupId]) then return false end
	local parentGroupId = normalizeId(root.editorGroups[groupId].parentGroupId)
	root.editorGroups[groupId] = nil
	Helper.SyncOrder(root.editorGroupOrder, root.editorGroups)
	for _, group in pairs(root.editorGroups or {}) do
		if group and normalizeId(group.parentGroupId) == groupId then group.parentGroupId = parentGroupId end
	end
	for _, panel in pairs(root.panels or {}) do
		if panel and normalizeId(panel.editorGroupId) == groupId then panel.editorGroupId = parentGroupId end
	end
	root._eqolEditorGroupOrderDirty = true
	return true
end

function CooldownPanels:SetEditorGroupParent(groupId, parentGroupId)
	local root = ensureRoot()
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	groupId = normalizeId(groupId)
	parentGroupId = normalizeId(parentGroupId)
	local group = root and root.editorGroups and groupId and root.editorGroups[groupId] or nil
	if not group then return false end
	if parentGroupId == nil then
		group.parentGroupId = nil
		root._eqolEditorGroupOrderDirty = true
		return true
	end
	if not self:CanSetEditorGroupParent(root, groupId, parentGroupId) then return false end
	group.parentGroupId = parentGroupId
	root._eqolEditorGroupOrderDirty = true
	return true
end

function CooldownPanels:GetEditorPanelGroupState(editor)
	if not editor then return {} end
	editor.panelGroupState = editor.panelGroupState or {}
	return editor.panelGroupState
end

function CooldownPanels:GetEditorPanelGroupStateKey(groupId)
	groupId = normalizeId(groupId)
	if groupId ~= nil then return tostring(groupId) end
	return "__ungrouped"
end

function CooldownPanels:IsEditorPanelGroupCollapsed(editor, groupId)
	local state = self:GetEditorPanelGroupState(editor)
	return state[self:GetEditorPanelGroupStateKey(groupId)] == true
end

function CooldownPanels:ToggleEditorPanelGroupCollapsed(editor, groupId)
	local state = self:GetEditorPanelGroupState(editor)
	local key = self:GetEditorPanelGroupStateKey(groupId)
	if state[key] == true then
		state[key] = nil
	else
		state[key] = true
	end
	return state[key] == true
end

function CooldownPanels:SetPanelEditorGroup(panelId, groupId)
	local root = ensureRoot()
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	panelId = normalizeId(panelId)
	local panel = root and root.panels and panelId and root.panels[panelId] or nil
	if not panel then return false end
	groupId = normalizeId(groupId)
	if groupId and not (root.editorGroups and root.editorGroups[groupId]) then groupId = nil end
	panel.editorGroupId = groupId
	return true
end

local function markRootOrderDirty(root)
	if root then
		root._orderDirty = true
		CooldownPanels.MarkRelativeFrameEntriesDirty()
		local runtime = CooldownPanels.runtime
		if runtime and runtime._eqolPanelIdCacheRoot == root then
			runtime._eqolPanelIdCache = nil
			runtime._eqolPanelIdCacheRoot = nil
		end
	end
end

local function syncRootOrderIfDirty(root, force)
	if not root then return false end
	if not force then
		if not root._orderDirty then return false end
		if InCombatLockdown and InCombatLockdown() then return false end
	end
	Helper.SyncOrder(root.order, root.panels)
	root._orderDirty = nil
	local runtime = CooldownPanels.runtime
	if runtime and runtime._eqolPanelIdCacheRoot == root then
		runtime._eqolPanelIdCache = nil
		runtime._eqolPanelIdCacheRoot = nil
	end
	return true
end

CooldownPanels.GetCachedPanelIds = function(root)
	if not root then return {} end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	local cached = runtime._eqolPanelIdCache
	if cached and runtime._eqolPanelIdCacheRoot == root then return cached end

	local panelIds = {}
	local seen = {}
	for _, panelId in ipairs(root.order or {}) do
		if root.panels[panelId] and not seen[panelId] then
			seen[panelId] = true
			panelIds[#panelIds + 1] = panelId
		end
	end
	for panelId in pairs(root.panels or {}) do
		if not seen[panelId] then
			seen[panelId] = true
			panelIds[#panelIds + 1] = panelId
		end
	end

	runtime._eqolPanelIdCache = panelIds
	runtime._eqolPanelIdCacheRoot = root
	return panelIds
end

function CooldownPanels:EnsureDB() return ensureRoot() end

function CooldownPanels:GetRoot() return ensureRoot() end

function CooldownPanels:GetPanel(panelId)
	local root = ensureRoot()
	if not root then return nil end
	panelId = normalizeId(panelId)
	local panel = root.panels and root.panels[panelId]
	if panel and not normalizedPanels[panel] then
		Helper.NormalizePanel(panel, root.defaults)
		normalizedPanels[panel] = true
	end
	return panel
end

function CooldownPanels:GetPanelOrder()
	local root = ensureRoot()
	if not root then return nil end
	return root.order
end

function CooldownPanels:SetPanelOrder(order)
	local root = ensureRoot()
	if not root or type(order) ~= "table" then return end
	root.order = order
	markRootOrderDirty(root)
	syncRootOrderIfDirty(root, true)
end

function CooldownPanels:SetSelectedPanel(panelId)
	local root = ensureRoot()
	if not root then return end
	panelId = normalizeId(panelId)
	if root.panels and root.panels[panelId] then root.selectedPanel = panelId end
end

function CooldownPanels:GetSelectedPanel()
	local root = ensureRoot()
	if not root then return nil end
	return root.selectedPanel
end

function CooldownPanels:CreatePanel(name)
	local root = ensureRoot()
	if not root then return nil end
	local id = Helper.GetNextNumericId(root.panels)
	local panel = Helper.CreatePanel(name, root.defaults)
	panel.id = id
	root.panels[id] = panel
	root.order[#root.order + 1] = id
	markRootOrderDirty(root)
	Keybinds.MarkPanelsDirty()
	if not root.selectedPanel then root.selectedPanel = id end
	self:RegisterEditModePanel(id)
	self:RebuildSpellIndex()
	self:RefreshPanel(id)
	return id, panel
end

function CooldownPanels:DuplicatePanel(panelId)
	local root = ensureRoot()
	panelId = normalizeId(panelId)
	if not root or not root.panels or not panelId then return nil end
	local source = root.panels[panelId]
	if not source then return nil end

	local id = Helper.GetNextNumericId(root.panels)
	local panel = Helper.CopyTableDeep(source)
	if type(panel) ~= "table" then return nil end
	panel.id = id

	local usedNames = {}
	for _, existingPanel in pairs(root.panels or {}) do
		local existingName = existingPanel and existingPanel.name
		if type(existingName) == "string" and existingName ~= "" then usedNames[existingName] = true end
	end
	local baseName = (type(source.name) == "string" and source.name ~= "" and source.name) or (L["CooldownPanelNewPanel"] or "New Panel")
	local copyLabel = L["Copy"] or "Copy"
	panel.name = string.format("%s %s", baseName, copyLabel)
	if usedNames[panel.name] then
		local suffix = 2
		repeat
			panel.name = string.format("%s %s %d", baseName, copyLabel, suffix)
			suffix = suffix + 1
		until not usedNames[panel.name]
	end

	local anchor = ensurePanelAnchor(panel)
	if anchor then
		anchor.x = (tonumber(anchor.x) or tonumber(panel.x) or 0) + 24
		anchor.y = (tonumber(anchor.y) or tonumber(panel.y) or 0) - 24
		panel.point = anchor.point or panel.point or "CENTER"
		panel.x = anchor.x
		panel.y = anchor.y
	else
		panel.x = (tonumber(panel.x) or 0) + 24
		panel.y = (tonumber(panel.y) or 0) - 24
	end

	Helper.NormalizePanel(panel, root.defaults)
	for _, entry in pairs(panel.entries or {}) do
		Helper.NormalizeEntry(entry, root.defaults)
	end

	root.panels[id] = panel
	local inserted = false
	for index, currentId in ipairs(root.order or {}) do
		if currentId == panelId then
			table.insert(root.order, index + 1, id)
			inserted = true
			break
		end
	end
	if not inserted then root.order[#root.order + 1] = id end
	markRootOrderDirty(root)
	Keybinds.MarkPanelsDirty()
	self:RegisterEditModePanel(id)
	self:RebuildSpellIndex()
	local cdmAuras = CooldownPanels.CDMAuras
	if cdmAuras and cdmAuras.HandleRootRefresh then cdmAuras:HandleRootRefresh() end
	self:UpdateCursorAnchorState()
	self:RefreshPanel(id)
	return id, panel
end

function CooldownPanels:DeletePanel(panelId)
	local root = ensureRoot()
	panelId = normalizeId(panelId)
	if not root or not root.panels or not root.panels[panelId] then return end
	self:HideLayoutEntryStandaloneMenu(panelId)
	self:HideLayoutPanelStandaloneMenu(panelId)
	self:HideLayoutFixedGroupStandaloneMenu(panelId)
	root.panels[panelId] = nil
	markRootOrderDirty(root)
	syncRootOrderIfDirty(root, true)
	Keybinds.MarkPanelsDirty()
	if root.selectedPanel == panelId then root.selectedPanel = root.order[1] end
	local runtime = CooldownPanels.runtime and CooldownPanels.runtime[panelId]
	if runtime then
		if runtime.editModeId and EditMode and EditMode.UnregisterFrame then pcall(EditMode.UnregisterFrame, EditMode, runtime.editModeId) end
		if runtime.frame then
			runtime.frame:Hide()
			runtime.frame:SetParent(nil)
			runtime.frame = nil
		end
		CooldownPanels.runtime[panelId] = nil
	end
	self:RebuildSpellIndex()
	local cdmAuras = CooldownPanels.CDMAuras
	if cdmAuras and cdmAuras.HandleRootRefresh then cdmAuras:HandleRootRefresh() end
	self:UpdateCursorAnchorState()
end

function CooldownPanels:AddEntry(panelId, entryType, idValue, overrides)
	local root = ensureRoot()
	if not root then return nil end
	panelId = normalizeId(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return nil end
	local typeKey = entryType and tostring(entryType):upper() or nil
	if typeKey ~= "SPELL" and typeKey ~= "ITEM" and typeKey ~= "SLOT" and typeKey ~= "STANCE" and typeKey ~= "MACRO" and typeKey ~= "CDM_AURA" then return nil end
	local entryValue = idValue
	local numericValue = tonumber(idValue)
	local itemWasHigherRank = false
	if typeKey == "SPELL" or typeKey == "ITEM" or typeKey == "SLOT" then
		if not numericValue then return nil end
		if typeKey == "SPELL" then
			numericValue = getBaseSpellId(numericValue) or numericValue
			numericValue = self:ResolveKnownSpellVariantID(numericValue) or numericValue
		elseif typeKey == "ITEM" then
			local canonicalItemID, wasHigherRank = self:GetCanonicalItemRankID(numericValue)
			numericValue = canonicalItemID
			itemWasHigherRank = wasHigherRank == true
		end
		entryValue = numericValue
	elseif typeKey == "STANCE" then
		local stanceDef = CooldownPanels.GetStanceDefinition and CooldownPanels:GetStanceDefinition(idValue) or nil
		if not stanceDef then return nil end
		entryValue = stanceDef.id
	elseif typeKey == "MACRO" then
		if numericValue then
			entryValue = numericValue
		elseif type(entryValue) ~= "string" then
			return nil
		end
	elseif typeKey == "CDM_AURA" then
		entryValue = idValue
	end
	if Helper.IsFixedLayout(panel.layout) then
		local resolvedOverrides, fixedError = self:ResolveFixedEntryAddOverrides(panel, overrides)
		if fixedError then return nil end
		overrides = resolvedOverrides
	end
	local entryId = Helper.GetNextNumericId(panel.entries)
	local entry = Helper.CreateEntry(typeKey, entryValue, root.defaults)
	if typeKey == "CDM_AURA" and not (entry and entry.cooldownID) then return nil end
	entry.id = entryId
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			entry[key] = value
		end
	end
	if entry.type == "ITEM" and itemWasHigherRank then entry.useHighestRank = true end
	if entry.type == "MACRO" then
		entry.macroID = tonumber(entry.macroID)
		entry.macroName = CooldownPanels.NormalizeMacroName(entry.macroName)
	elseif entry.type == "STANCE" and CooldownPanels.NormalizeStanceEntry then
		CooldownPanels:NormalizeStanceEntry(entry)
	elseif entry.type == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.NormalizeEntry then cdmAuras:NormalizeEntry(entry, root.defaults) end
	end
	panel.entries[entryId] = entry
	panel.order[#panel.order + 1] = entryId
	Helper.InvalidateFixedLayoutCache(panel)
	if Helper.IsFixedLayout(panel.layout) then Helper.EnsureFixedSlotAssignments(panel) end
	if entry.type == "ITEM" and entry.itemID then
		updateItemCountCacheForItem(entry.itemID)
	elseif entry.type == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		if macro and macro.kind == "ITEM" and macro.itemID then updateItemCountCacheForItem(macro.itemID) end
	end
	self:RebuildSpellIndex()
	if entry.type == "CDM_AURA" then
		local cdmAuras = self.CDMAuras
		if cdmAuras and cdmAuras.HandleRootRefresh then cdmAuras:HandleRootRefresh() end
	end
	self:RefreshPanel(panelId)
	return entryId, entry
end

function CooldownPanels:FindEntryByValue(panelId, entryType, idValue)
	panelId = normalizeId(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return nil end
	local typeKey = entryType and tostring(entryType):upper() or nil
	if typeKey == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.FindEntryByValue then return cdmAuras:FindEntryByValue(panel, idValue) end
		return nil
	end
	local numericValue = tonumber(idValue)
	local canonicalSpellValue = nil
	if typeKey == "SPELL" and numericValue then canonicalSpellValue = self:GetCanonicalSpellVariantID(numericValue) or numericValue end
	if typeKey == "ITEM" and numericValue then
		local canonicalItemID = self:GetCanonicalItemRankID(numericValue)
		numericValue = canonicalItemID or numericValue
	end
	local macroName = CooldownPanels.NormalizeMacroName(type(idValue) == "string" and idValue or nil)
	local stanceDef = typeKey == "STANCE" and CooldownPanels.GetStanceDefinition and CooldownPanels:GetStanceDefinition(idValue) or nil
	local stanceID = stanceDef and stanceDef.id or nil
	if typeKey ~= "SPELL" and typeKey ~= "ITEM" and typeKey ~= "SLOT" and typeKey ~= "STANCE" and typeKey ~= "MACRO" then return nil end
	for entryId, entry in pairs(panel.entries or {}) do
		if entry and entry.type == typeKey then
			if typeKey == "SPELL" then
				local entrySpellID = tonumber(entry.spellID)
				local canonicalEntrySpellID = entrySpellID and (self:GetCanonicalSpellVariantID(entrySpellID) or entrySpellID) or nil
				if canonicalEntrySpellID and canonicalSpellValue and canonicalEntrySpellID == canonicalSpellValue then return entryId, entry end
			end
			if typeKey == "ITEM" then
				local entryItemID = tonumber(entry.itemID)
				if entryItemID then
					local canonicalEntryItemID = self:GetCanonicalItemRankID(entryItemID) or entryItemID
					if canonicalEntryItemID == numericValue then return entryId, entry end
				end
			end
			if typeKey == "SLOT" and entry.slotID == numericValue then return entryId, entry end
			if typeKey == "STANCE" and stanceID and entry.stanceID == stanceID then return entryId, entry end
			if typeKey == "MACRO" then
				local entryMacroID = tonumber(entry.macroID)
				local entryMacroName = CooldownPanels.NormalizeMacroName(entry.macroName)
				if numericValue and entryMacroID == numericValue then return entryId, entry end
				if macroName and entryMacroName and macroName == entryMacroName then return entryId, entry end
			end
		end
	end
	return nil
end

function CooldownPanels:RemoveEntry(panelId, entryId)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel = self:GetPanel(panelId)
	if not panel or not panel.entries or not panel.entries[entryId] then return end
	local state = CooldownPanels.runtime and CooldownPanels.runtime.layoutEntryStandaloneMenu or nil
	if state and normalizeId(state.panelId) == panelId and normalizeId(state.entryId) == entryId then self:HideLayoutEntryStandaloneMenu(panelId) end
	panel.entries[entryId] = nil
	local runtime = CooldownPanels.runtime
	if runtime and runtime.actionDisplayCounts then runtime.actionDisplayCounts[Helper.GetEntryKey(panelId, entryId)] = nil end
	Helper.SyncOrder(panel.order, panel.entries)
	Helper.InvalidateFixedLayoutCache(panel)
	self:RebuildSpellIndex()
	local cdmAuras = CooldownPanels.CDMAuras
	if cdmAuras and cdmAuras.HandleRootRefresh then cdmAuras:HandleRootRefresh() end
	self:RefreshPanel(panelId)
end

function CooldownPanels:RebuildSpellIndex()
	self:InvalidateSpellQueryCaches()
	local root = ensureRoot()
	local runtime = self.runtime or {}
	local index = {}
	local enabledPanels = {}
	local enabledPanelIds = {}
	local enabledPanelsBySpec = {}
	local enabledPanelIdsBySpec = {}
	local itemPanels = {}
	local itemUsesPanels = {}
	local itemTrackedIds = {}
	local itemUsesTrackedIds = {}
	local rangeCheckSpells = {}
	self:EnsureFoodRankGroupsLoaded()
	local activeSpecId = getPlayerSpecId()
	local classSpecs = getPlayerClassSpecMap()
	if classSpecs then
		for specId in pairs(classSpecs) do
			enabledPanelsBySpec[specId] = {}
			enabledPanelIdsBySpec[specId] = {}
		end
	end
	if activeSpecId and not enabledPanelsBySpec[activeSpecId] then
		enabledPanelsBySpec[activeSpecId] = {}
		enabledPanelIdsBySpec[activeSpecId] = {}
	end
	if root and root.panels then
		syncRootOrderIfDirty(root)
		for _, panelId in ipairs(CooldownPanels.GetCachedPanelIds(root)) do
			local panel = root.panels[panelId]
			if panel and panel.enabled ~= false then
				if panelHasSpecFilter(panel) then
					local filter = panel.specFilter
					for specId, bucket in pairs(enabledPanelsBySpec) do
						if filter and filter[specId] == true then
							bucket[panelId] = true
							enabledPanelIdsBySpec[specId][#enabledPanelIdsBySpec[specId] + 1] = panelId
						end
					end
				else
					for specId, bucket in pairs(enabledPanelsBySpec) do
						bucket[panelId] = true
						enabledPanelIdsBySpec[specId][#enabledPanelIdsBySpec[specId] + 1] = panelId
					end
				end
			end
			if panel and panel.enabled ~= false and panelAllowsSpec(panel) then
				enabledPanels[panelId] = true
				enabledPanelIds[#enabledPanelIds + 1] = panelId
				local layout = panel.layout
				local wantsRangeCheck = layout and layout.rangeOverlayEnabled == true
				for _, entry in pairs(panel.entries or {}) do
					local spellId
					local trackedItemId
					if entry and entry.type == "SPELL" and entry.spellID then
						spellId = tonumber(entry.spellID)
					elseif entry and entry.type == "MACRO" then
						local macro = CooldownPanels.ResolveMacroEntry(entry)
						if macro and macro.kind == "SPELL" and macro.spellID then
							spellId = tonumber(macro.spellID)
						elseif macro and macro.kind == "ITEM" and entry.showCooldown ~= false then
							itemPanels[panelId] = true
						end
						if macro and macro.kind == "ITEM" then
							trackedItemId = tonumber(macro.itemID)
							if entry.showItemUses == true then itemUsesPanels[panelId] = true end
						end
					end
					if spellId then
						local effectiveId = getEffectiveSpellId(spellId) or spellId
						if not isSpellPassiveSafe(spellId, effectiveId) then
							index[spellId] = index[spellId] or {}
							index[spellId][panelId] = true
							if wantsRangeCheck then rangeCheckSpells[spellId] = true end
							if effectiveId and effectiveId ~= spellId then
								index[effectiveId] = index[effectiveId] or {}
								index[effectiveId][panelId] = true
							end
						end
					end
					if entry and (entry.type == "ITEM" or entry.type == "SLOT") and entry.showCooldown ~= false then itemPanels[panelId] = true end
					if entry and entry.type == "ITEM" and entry.showItemUses == true then itemUsesPanels[panelId] = true end
					if entry and entry.type == "ITEM" then trackedItemId = tonumber(entry.itemID) or trackedItemId end
					if trackedItemId then
						local trackUses = entry and entry.showItemUses == true
						local tracked = false
						if entry and entry.type == "ITEM" and entry.useHighestRank == true then
							local rankMap = self.itemHighestRankByID
							local group = rankMap and rankMap[trackedItemId] or nil
							if type(group) == "table" then
								for i = 1, #group do
									local candidateId = tonumber(group[i])
									if candidateId then
										itemTrackedIds[candidateId] = true
										if trackUses then itemUsesTrackedIds[candidateId] = true end
										tracked = true
									end
								end
							end
						end
						if not tracked then
							itemTrackedIds[trackedItemId] = true
							if trackUses then itemUsesTrackedIds[trackedItemId] = true end
						end
					end
				end
			end
		end
	end
	self.runtime = runtime
	runtime.disabledPanelIds = runtime.disabledPanelIds or {}
	for i = 1, #runtime.disabledPanelIds do
		runtime.disabledPanelIds[i] = nil
	end
	for panelId in pairs(runtime.enabledPanels or {}) do
		if not enabledPanels[panelId] then runtime.disabledPanelIds[#runtime.disabledPanelIds + 1] = panelId end
	end
	runtime.activeSpecId = activeSpecId
	runtime.enabledPanelsBySpec = enabledPanelsBySpec
	runtime.enabledPanelIdsBySpec = enabledPanelIdsBySpec
	runtime.spellIndex = index
	runtime.enabledPanels = enabledPanels
	runtime.enabledPanelIds = enabledPanelIds
	runtime.itemPanels = itemPanels
	runtime.itemUsesPanels = itemUsesPanels
	runtime.itemTrackedIds = itemTrackedIds
	runtime.itemUsesTrackedIds = itemUsesTrackedIds
	if updateRangeCheckSpells then updateRangeCheckSpells(rangeCheckSpells) end
	self:RebuildPowerIndex()
	self:RebuildChargesIndex()
	local cdmAuras = self.CDMAuras
	if cdmAuras and cdmAuras.UpdateEventRegistration then cdmAuras:UpdateEventRegistration() end
	if self.UpdateEventRegistration then self:UpdateEventRegistration() end
	return index
end

function CooldownPanels:RebuildPowerIndex()
	local root = ensureRoot()
	local runtime = self.runtime
	local enabledPanels = runtime and runtime.enabledPanels or nil
	local enabledPanelIds = runtime and runtime.enabledPanelIds or nil
	local powerIndex = {}
	local powerCostNames = {}
	local powerCheckSpells = {}
	local powerPanelsBySpell = {}
	local powerCheckActive = false
	if root and root.panels then
		if enabledPanelIds then
			for i = 1, #enabledPanelIds do
				local panelId = enabledPanelIds[i]
				local panel = root.panels[panelId]
				local layout = panel and panel.layout or {}
				if panel and (not enabledPanels or enabledPanels[panelId]) then
					local effectiveLayoutCache = {}
					for _, entry in pairs(panel.entries or {}) do
						local trackEntryPower = false
						if entry then
							local entryLayout = self:GetEntryEffectiveLayout(panelId, entry, effectiveLayoutCache, panel) or layout
							trackEntryPower = self:ResolveEntryCheckPower(entryLayout, entry)
								or self:ResolveEntryHideWhenNoResource(entryLayout, entry)
								or (entry.type == "SPELL" and entry.glowReady == true and self:ResolveEntryReadyGlowCheckPower(entryLayout, entry))
						end
						if entry and trackEntryPower then
							local baseId
							if entry.type == "SPELL" and entry.spellID then
								baseId = tonumber(entry.spellID)
							elseif entry.type == "MACRO" then
								local macro = CooldownPanels.ResolveMacroEntry(entry)
								if macro and macro.kind == "SPELL" and macro.spellID then baseId = tonumber(macro.spellID) end
							end
							if baseId then
								powerCheckActive = true
								local effectiveId = getEffectiveSpellId(baseId) or baseId
								if not isSpellPassiveSafe(baseId, effectiveId) then
									powerCheckSpells[effectiveId] = true
									powerPanelsBySpell[effectiveId] = powerPanelsBySpell[effectiveId] or {}
									powerPanelsBySpell[effectiveId][panelId] = true
									local costs = Api.GetSpellPowerCost and Api.GetSpellPowerCost(effectiveId)
									if type(costs) == "table" then
										local names = getSpellPowerCostNamesFromCosts(costs)
										if names then
											powerCostNames[baseId] = names
											for _, name in ipairs(names) do
												local key = string.upper(name)
												if key ~= "" then
													powerIndex[key] = powerIndex[key] or {}
													powerIndex[key][effectiveId] = true
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		else
			for panelId, panel in pairs(root.panels) do
				local layout = panel.layout or {}
				if panel.enabled ~= false and panelAllowsSpec(panel) then
					local normalizedPanelId = normalizeId(panelId)
					local effectiveLayoutCache = {}
					for _, entry in pairs(panel.entries or {}) do
						local trackEntryPower = false
						if entry then
							local entryLayout = self:GetEntryEffectiveLayout(normalizedPanelId, entry, effectiveLayoutCache, panel) or layout
							trackEntryPower = self:ResolveEntryCheckPower(entryLayout, entry)
								or self:ResolveEntryHideWhenNoResource(entryLayout, entry)
								or (entry.type == "SPELL" and entry.glowReady == true and self:ResolveEntryReadyGlowCheckPower(entryLayout, entry))
						end
						if entry and trackEntryPower then
							local baseId
							if entry.type == "SPELL" and entry.spellID then
								baseId = tonumber(entry.spellID)
							elseif entry.type == "MACRO" then
								local macro = CooldownPanels.ResolveMacroEntry(entry)
								if macro and macro.kind == "SPELL" and macro.spellID then baseId = tonumber(macro.spellID) end
							end
							if baseId then
								powerCheckActive = true
								local effectiveId = getEffectiveSpellId(baseId) or baseId
								if not isSpellPassiveSafe(baseId, effectiveId) then
									powerCheckSpells[effectiveId] = true
									powerPanelsBySpell[effectiveId] = powerPanelsBySpell[effectiveId] or {}
									powerPanelsBySpell[effectiveId][normalizedPanelId] = true
									local costs = Api.GetSpellPowerCost and Api.GetSpellPowerCost(effectiveId)
									if type(costs) == "table" then
										local names = getSpellPowerCostNamesFromCosts(costs)
										if names then
											powerCostNames[baseId] = names
											for _, name in ipairs(names) do
												local key = string.upper(name)
												if key ~= "" then
													powerIndex[key] = powerIndex[key] or {}
													powerIndex[key][effectiveId] = true
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	if powerCheckActive and not next(powerCheckSpells) then powerCheckActive = false end
	self.runtime = self.runtime or {}
	runtime = self.runtime
	runtime.powerIndex = powerIndex
	runtime.powerCostNames = powerCostNames
	runtime.powerCheckSpells = powerCheckSpells
	runtime.powerPanelsBySpell = powerPanelsBySpell
	runtime.powerCheckActive = powerCheckActive == true
	runtime.powerInsufficient = runtime.powerInsufficient or {}
	wipe(runtime.powerInsufficient)
	runtime.spellUnusable = runtime.spellUnusable or {}
	wipe(runtime.spellUnusable)
	updatePowerEventRegistration()
	if Api.IsSpellUsableFn then
		for spellId in pairs(powerCheckSpells) do
			local checkId = getEffectiveSpellId(spellId) or spellId
			local isUsable, insufficientPower = Api.IsSpellUsableFn(checkId)
			setPowerInsufficient(runtime, checkId, isUsable, insufficientPower)
		end
	end
end

function CooldownPanels:RebuildChargesIndex()
	local root = ensureRoot()
	local runtime = self.runtime
	local enabledPanels = runtime and runtime.enabledPanels or nil
	local enabledPanelIds = runtime and runtime.enabledPanelIds or nil
	local chargesIndex = {}
	local chargesPanels = {}
	if root and root.panels then
		if enabledPanelIds then
			for i = 1, #enabledPanelIds do
				local panelId = enabledPanelIds[i]
				local panel = root.panels[panelId]
				if panel and (not enabledPanels or enabledPanels[panelId]) then
					for _, entry in pairs(panel.entries or {}) do
						local baseId
						if entry and entry.showCharges == true then
							if entry.type == "SPELL" and entry.spellID then
								baseId = tonumber(entry.spellID)
							elseif entry.type == "MACRO" then
								local macro = CooldownPanels.ResolveMacroEntry(entry)
								if macro and macro.kind == "SPELL" and macro.spellID then baseId = tonumber(macro.spellID) end
							end
						end
						if baseId then
							local effectiveId = getEffectiveSpellId(baseId) or baseId
							if not isSpellPassiveSafe(baseId, effectiveId) then
								chargesPanels[panelId] = true
								if Api.GetSpellChargesInfo then
									local info = Api.GetSpellChargesInfo(effectiveId)
									if type(info) == "table" then
										chargesIndex[effectiveId] = chargesIndex[effectiveId] or {}
										chargesIndex[effectiveId][panelId] = true
										if effectiveId ~= baseId then
											chargesIndex[baseId] = chargesIndex[baseId] or {}
											chargesIndex[baseId][panelId] = true
										end
									end
								end
							end
						end
					end
				end
			end
		else
			for panelId, panel in pairs(root.panels) do
				if panel and panel.enabled ~= false and panelAllowsSpec(panel) then
					for _, entry in pairs(panel.entries or {}) do
						local baseId
						if entry and entry.showCharges == true then
							if entry.type == "SPELL" and entry.spellID then
								baseId = tonumber(entry.spellID)
							elseif entry.type == "MACRO" then
								local macro = CooldownPanels.ResolveMacroEntry(entry)
								if macro and macro.kind == "SPELL" and macro.spellID then baseId = tonumber(macro.spellID) end
							end
						end
						if baseId then
							local effectiveId = getEffectiveSpellId(baseId) or baseId
							if not isSpellPassiveSafe(baseId, effectiveId) then
								chargesPanels[panelId] = true
								if Api.GetSpellChargesInfo then
									local info = Api.GetSpellChargesInfo(effectiveId)
									if type(info) == "table" then
										chargesIndex[effectiveId] = chargesIndex[effectiveId] or {}
										chargesIndex[effectiveId][panelId] = true
										if effectiveId ~= baseId then
											chargesIndex[baseId] = chargesIndex[baseId] or {}
											chargesIndex[baseId][panelId] = true
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	self.runtime = self.runtime or {}
	runtime = self.runtime
	runtime.chargesIndex = chargesIndex
	runtime.chargesPanels = chargesPanels
	runtime.chargesActive = next(chargesIndex) and true or false
	runtime.chargesState = runtime.chargesState or {}
	for spellId in pairs(runtime.chargesState) do
		if not chargesIndex[spellId] then runtime.chargesState[spellId] = nil end
	end
end

function CooldownPanels:NormalizeAll()
	local root = ensureRoot()
	if not root then return end
	Helper.NormalizeRoot(root)
	root._eqolEditorGroupsReady = nil
	root._eqolEditorGroupOrderDirty = true
	normalizedRoots[root] = true
	Helper.SyncOrder(root.order, root.panels)
	root._orderDirty = nil
	for panelId, panel in pairs(root.panels) do
		if panel and panel.id == nil then panel.id = panelId end
		Helper.NormalizePanel(panel, root.defaults)
		Helper.InvalidateFixedLayoutCache(panel)
		normalizedPanels[panel] = true
		Helper.SyncOrder(panel.order, panel.entries)
		for entryId, entry in pairs(panel.entries) do
			if entry and entry.id == nil then entry.id = entryId end
			Helper.NormalizeEntry(entry, root.defaults)
			if entry and entry.type == "SPELL" and entry.spellID then entry.spellID = self:ResolveKnownSpellVariantID(entry.spellID) or entry.spellID end
			if entry and entry.type == "ITEM" then
				local canonicalItemID, wasHigherRank = self:GetCanonicalItemRankID(entry.itemID)
				if canonicalItemID then entry.itemID = canonicalItemID end
				if wasHigherRank then entry.useHighestRank = true end
			end
		end
		local seenSpellVariantEntries = nil
		local removedDuplicateVariantEntry = false
		for _, entryId in ipairs(panel.order or {}) do
			local entry = panel.entries and panel.entries[entryId]
			if entry and entry.type == "SPELL" and entry.spellID then
				local canonicalSpellID, _, spellGroup = self:GetCanonicalSpellVariantID(entry.spellID)
				if canonicalSpellID and spellGroup then
					seenSpellVariantEntries = seenSpellVariantEntries or {}
					if seenSpellVariantEntries[canonicalSpellID] then
						panel.entries[entryId] = nil
						local runtime = CooldownPanels.runtime
						if runtime and runtime.actionDisplayCounts then runtime.actionDisplayCounts[Helper.GetEntryKey(panelId, entryId)] = nil end
						removedDuplicateVariantEntry = true
					else
						seenSpellVariantEntries[canonicalSpellID] = entryId
					end
				end
			end
		end
		if removedDuplicateVariantEntry then
			Helper.SyncOrder(panel.order, panel.entries)
			Helper.InvalidateFixedLayoutCache(panel)
		end
		if Helper.IsFixedLayout(panel.layout) then Helper.EnsureFixedSlotAssignments(panel) end
	end
	self:RebuildSpellIndex()
	local cdmAuras = CooldownPanels.CDMAuras
	if cdmAuras and cdmAuras.HandleRootRefresh then cdmAuras:HandleRootRefresh() end
end

function CooldownPanels:AddEntrySafe(panelId, entryType, idValue, overrides)
	local typeKey = entryType and tostring(entryType):upper() or nil
	local function addWithFixedChecks(finalType, finalValue, finalOverrides)
		local panel = self:GetPanel(panelId)
		local resolvedOverrides = finalOverrides
		local fixedError = nil
		if panel and Helper.IsFixedLayout(panel.layout) then
			resolvedOverrides, fixedError = self:ResolveFixedEntryAddOverrides(panel, finalOverrides)
		end
		if fixedError then
			showErrorMessage(fixedError)
			return nil
		end
		return self:AddEntry(panelId, finalType, finalValue, resolvedOverrides)
	end
	if typeKey == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.AddEntrySafe then return cdmAuras:AddEntrySafe(panelId, idValue, overrides) end
		return nil
	end
	local numericValue = tonumber(idValue)
	local baseValue = numericValue
	if typeKey == "SPELL" and numericValue then
		baseValue = getBaseSpellId(numericValue) or numericValue
		if not spellExistsSafe(numericValue) and not spellExistsSafe(baseValue) then
			showErrorMessage(L["CooldownPanelSpellInvalid"] or "Spell does not exist.")
			return nil
		end
		baseValue = self:ResolveKnownSpellVariantID(baseValue) or baseValue
	end
	if typeKey == "STANCE" then
		local stanceDef = CooldownPanels.GetStanceDefinition and CooldownPanels:GetStanceDefinition(idValue) or nil
		if not stanceDef then
			local stanceLabel = (CooldownPanels.GetStanceTypeLabel and CooldownPanels:GetStanceTypeLabel()) or (_G.STANCE or "Stance")
			showErrorMessage((stanceLabel or (_G.STANCE or "Stance")) .. " does not exist.")
			return nil
		end
		if self:FindEntryByValue(panelId, typeKey, stanceDef.id) then
			showErrorMessage(L["CooldownPanelEntry"] and (L["CooldownPanelEntry"] .. " already exists.") or "Entry already exists.")
			return nil
		end
		local finalOverrides = {}
		if type(overrides) == "table" then
			for key, value in pairs(overrides) do
				finalOverrides[key] = value
			end
		end
		local defaults = CooldownPanels.GetStanceDefaultOverrides and CooldownPanels:GetStanceDefaultOverrides() or nil
		if type(defaults) == "table" then
			for key, value in pairs(defaults) do
				if finalOverrides[key] == nil then finalOverrides[key] = value end
			end
		end
		return addWithFixedChecks(typeKey, stanceDef.id, finalOverrides)
	end
	if typeKey == "MACRO" then
		local macroName = nil
		if type(overrides) == "table" then macroName = CooldownPanels.NormalizeMacroName(overrides.macroName) end
		if not macroName then macroName = CooldownPanels.NormalizeMacroName(type(idValue) == "string" and idValue or nil) end
		if not macroName and numericValue and Api.GetMacroInfo then
			local infoName = Api.GetMacroInfo(numericValue)
			macroName = CooldownPanels.NormalizeMacroName(infoName)
		end
		if numericValue and not macroName then
			showErrorMessage((_G.MACRO or "Macro") .. " does not exist.")
			return nil
		end
		if not numericValue and macroName and Api.GetMacroIndexByName then
			local macroId = Api.GetMacroIndexByName(macroName)
			if type(macroId) == "number" and macroId > 0 then
				numericValue = macroId
				baseValue = macroId
			end
		end
		if not numericValue and not macroName then
			showErrorMessage((_G.MACRO or "Macro") .. " does not exist.")
			return nil
		end
		if self:FindEntryByValue(panelId, typeKey, numericValue or macroName) then
			showErrorMessage(L["CooldownPanelEntry"] and (L["CooldownPanelEntry"] .. " already exists.") or "Entry already exists.")
			return nil
		end
		local finalOverrides = {}
		if type(overrides) == "table" then
			for key, value in pairs(overrides) do
				finalOverrides[key] = value
			end
		end
		finalOverrides.macroName = macroName
		return addWithFixedChecks(typeKey, numericValue or idValue, finalOverrides)
	end
	local finalOverrides = overrides
	if typeKey == "ITEM" and numericValue then
		local canonicalItemID, wasHigherRank = self:GetCanonicalItemRankID(baseValue)
		if canonicalItemID then baseValue = canonicalItemID end
		if wasHigherRank then
			finalOverrides = {}
			if type(overrides) == "table" then
				for key, value in pairs(overrides) do
					finalOverrides[key] = value
				end
			end
			finalOverrides.useHighestRank = true
		end
	end
	if self:FindEntryByValue(panelId, typeKey, baseValue) then
		showErrorMessage(L["CooldownPanelEntry"] and (L["CooldownPanelEntry"] .. " already exists.") or "Entry already exists.")
		return nil
	end
	return addWithFixedChecks(typeKey, baseValue, finalOverrides)
end

function CooldownPanels:HandleCursorDrop(panelId, targetSlot)
	panelId = normalizeId(panelId or self:GetSelectedPanel())
	if not panelId then return false end
	local cursorType, cursorId, _, cursorSpellId = Api.GetCursorInfo()
	if not cursorType then return false end
	local dropOverrides = targetSlot and self:GetFixedDropEntryOverrides(panelId, targetSlot) or nil
	local requiresPostAddMove = false
	if dropOverrides and dropOverrides.fixedGroupId then
		local panel = self:GetPanel(panelId)
		local targetGroup = panel and CooldownPanels.GetFixedGroupById(panel, dropOverrides.fixedGroupId) or nil
		requiresPostAddMove = targetGroup and not CooldownPanels.IsFixedGroupStatic(targetGroup) or false
	end
	local function mergeDropOverrides(baseOverrides)
		if not dropOverrides then return baseOverrides end
		local merged = {}
		if type(baseOverrides) == "table" then
			for key, value in pairs(baseOverrides) do
				merged[key] = value
			end
		end
		for key, value in pairs(dropOverrides) do
			merged[key] = value
		end
		return merged
	end

	local added = false
	local addedEntryId
	if cursorType == "spell" then
		local spellId = cursorSpellId or cursorId
		if spellId then addedEntryId = self:AddEntrySafe(panelId, "SPELL", spellId, mergeDropOverrides()) end
	elseif cursorType == "item" then
		if cursorId then addedEntryId = self:AddEntrySafe(panelId, "ITEM", cursorId, mergeDropOverrides()) end
	elseif cursorType == "macro" then
		if cursorId then
			local macroName = Api.GetMacroInfo and Api.GetMacroInfo(cursorId) or nil
			addedEntryId = self:AddEntrySafe(panelId, "MACRO", cursorId, mergeDropOverrides({ macroName = macroName }))
		end
	elseif cursorType == "action" and Api.GetActionInfo then
		local actionType, actionId = Api.GetActionInfo(cursorId)
		if actionType == "spell" then
			addedEntryId = self:AddEntrySafe(panelId, "SPELL", actionId, mergeDropOverrides())
		elseif actionType == "item" then
			addedEntryId = self:AddEntrySafe(panelId, "ITEM", actionId, mergeDropOverrides())
		elseif actionType == "macro" then
			local macroID = tonumber(actionId)
			local macroName = Api.GetActionText and CooldownPanels.NormalizeMacroName(Api.GetActionText(cursorId)) or nil
			if macroName and Api.GetMacroIndexByName then
				local byName = Api.GetMacroIndexByName(macroName)
				if type(byName) == "number" and byName > 0 then macroID = byName end
			end
			if not macroName and macroID and Api.GetMacroInfo then macroName = CooldownPanels.NormalizeMacroName(Api.GetMacroInfo(macroID)) end
			addedEntryId = self:AddEntrySafe(panelId, "MACRO", macroID or macroName, mergeDropOverrides({ macroName = macroName }))
		end
	end

	added = addedEntryId ~= nil
	if added and targetSlot and requiresPostAddMove then self:MoveEntryToFixedSlot(panelId, addedEntryId, targetSlot) end
	if added then Api.ClearCursor() end
	return added
end

function CooldownPanels:SelectPanel(panelId)
	local root = ensureRoot()
	if not root then return end
	panelId = normalizeId(panelId)
	if not root.panels or not root.panels[panelId] then return end
	local previousPanelId = root.selectedPanel
	if previousPanelId and previousPanelId ~= panelId then self:HideLayoutEntryStandaloneMenu(previousPanelId) end
	if previousPanelId and previousPanelId ~= panelId then self:HideLayoutPanelStandaloneMenu(previousPanelId) end
	if previousPanelId and previousPanelId ~= panelId then self:HideLayoutFixedGroupStandaloneMenu(previousPanelId) end
	root.selectedPanel = panelId
	local editor = getEditor()
	if editor then
		editor.selectedPanelId = panelId
		editor.selectedEntryId = nil
	end
	local needsLiveRefresh = self:IsInEditMode() == true or self:IsAnyPanelLayoutEditActive()
	if needsLiveRefresh then
		if previousPanelId and previousPanelId ~= panelId and self:GetPanel(previousPanelId) then self:RefreshPanel(previousPanelId) end
		self:RefreshPanel(panelId)
	end
	self:UpdateCursorAnchorState()
	self:RefreshEditor()
end

function CooldownPanels:SelectEntry(entryId)
	entryId = normalizeId(entryId)
	local editor = getEditor()
	if not editor then return end
	editor.selectedEntryId = entryId
	local panelId = editor.selectedPanelId
	if panelId then
		local runtime = getRuntime(panelId)
		runtime.editModeEntryId = entryId
	end
	refreshEditModeSettingValues()
	self:RefreshEditor()
end

function CooldownPanels:IsPanelLayoutEditAvailable(panelId)
	panelId = normalizeId(panelId)
	if not panelId then return false end
	local panel = self:GetPanel(panelId)
	if not panel then return false end
	return panelUsesFakeCursor(panel) ~= true
end

function CooldownPanels:IsPanelLayoutEditActive(panelId)
	panelId = normalizeId(panelId)
	if not panelId then return false end
	local editor = getEditor()
	if not (editor and editor.frame and editor.frame:IsShown()) then return false end
	if editor.layoutEditActive ~= true then return false end
	if normalizeId(editor.selectedPanelId) ~= panelId then return false end
	return self:IsPanelLayoutEditAvailable(panelId)
end

function CooldownPanels:IsAnyPanelLayoutEditActive()
	local editor = getEditor()
	return editor and editor.frame and editor.frame:IsShown() and editor.layoutEditActive == true
end

function CooldownPanels:SetEditorLayoutEditEnabled(enabled)
	local editor = getEditor()
	if not editor then return end
	enabled = enabled == true
	if enabled and not self:IsPanelLayoutEditAvailable(editor.selectedPanelId) then
		self:RefreshEditor()
		return
	end
	if editor.layoutEditActive == enabled then
		self:RefreshEditor()
		return
	end
	local previousPanelId = normalizeId(editor._eqolLayoutPanelId)
	editor.layoutEditActive = enabled
	local nextPanelId = enabled and normalizeId(editor.selectedPanelId) or nil
	editor._eqolLayoutPanelId = nextPanelId
	if not enabled then self:HideLayoutEntryStandaloneMenu(previousPanelId or editor.selectedPanelId) end
	if not enabled then self:HideLayoutPanelStandaloneMenu(previousPanelId or editor.selectedPanelId) end
	if not enabled then self:HideLayoutFixedGroupStandaloneMenu(previousPanelId or editor.selectedPanelId) end
	if previousPanelId and self:GetPanel(previousPanelId) then self:RefreshPanel(previousPanelId) end
	if nextPanelId and self:GetPanel(nextPanelId) then self:RefreshPanel(nextPanelId) end
	self:UpdateCursorAnchorState()
	self:RefreshEditor()
end

function CooldownPanels:PreparePanelForFixedLayoutEdit(panelId)
	panelId = normalizeId(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return false end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	if Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) == "RADIAL" then return false end
	local changed = false
	if not Helper.IsFixedLayout(layout) then
		layout.layoutMode = "FIXED"
		if Helper.NormalizeFixedGridSize(layout.fixedGridColumns, 0) <= 0 then
			local gridColumns = Helper.ClampInt(layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
			if gridColumns <= 0 then gridColumns = math.min(math.max(type(panel.order) == "table" and #panel.order or 0, 4), 12) end
			layout.fixedGridColumns = gridColumns
		end
		changed = true
	end
	local maxColumn, maxRow = Helper.EnsureFixedSlotAssignments(panel)
	local nextColumns = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, 0)
	local nextRows = Helper.NormalizeFixedGridSize(layout.fixedGridRows, 0)
	if nextColumns <= 0 then nextColumns = math.max(maxColumn or 0, 1) end
	if nextRows <= 0 then nextRows = math.max(maxRow or 0, 1) end
	if layout.fixedGridColumns ~= nextColumns then
		layout.fixedGridColumns = nextColumns
		changed = true
	end
	if layout.fixedGridRows ~= nextRows then
		layout.fixedGridRows = nextRows
		changed = true
	end
	if changed then
		local runtime = getRuntime(panelId)
		self:SyncEditModeDataFromPanel(panelId, runtime and runtime.editModeId)
		refreshEditModeSettingValues()
	end
	return changed
end

function CooldownPanels:ProxyEditModeDragStart(panelId)
	panelId = normalizeId(panelId)
	local runtime = panelId and getRuntime(panelId) or nil
	local frame = runtime and runtime.frame
	local selection = frame and frame.Selection
	local onMouseDown = selection and selection.GetScript and selection:GetScript("OnMouseDown") or nil
	if onMouseDown then
		onMouseDown(selection, "LeftButton")
	elseif selection and selection.OnMouseDown then
		selection:OnMouseDown()
	end
	local onDragStart = selection and selection.GetScript and selection:GetScript("OnDragStart") or nil
	if onDragStart then
		onDragStart(selection)
	elseif selection and selection.OnDragStart then
		selection:OnDragStart()
	elseif frame and frame.OnDragStart then
		frame:OnDragStart()
	end
end

function CooldownPanels:ProxyEditModeDragStop(panelId)
	panelId = normalizeId(panelId)
	local runtime = panelId and getRuntime(panelId) or nil
	local frame = runtime and runtime.frame
	local selection = frame and frame.Selection
	local onDragStop = selection and selection.GetScript and selection:GetScript("OnDragStop") or nil
	if onDragStop then
		onDragStop(selection)
	elseif selection and selection.OnDragStop then
		selection:OnDragStop()
	elseif frame and frame.OnDragStop then
		frame:OnDragStop()
	end
end

function CooldownPanels:BeginStandalonePanelDrag(panelId)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	local frame = runtime and runtime.frame
	if not (panel and frame and self:IsPanelLayoutEditActive(panelId)) then return false end
	local anchor = ensurePanelAnchor(panel)
	local usesFakeCursor = panelUsesFakeCursor(panel)
	if not anchorUsesUIParent(anchor) and not usesFakeCursor then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if usesFakeCursor then
		self:UpdateCursorAnchorState()
		local point = Helper.NormalizeAnchor(anchor and anchor.point, panel.point or "CENTER")
		local relativePoint = Helper.NormalizeAnchor(anchor and anchor.relativePoint, point)
		local x = tonumber(anchor and anchor.x) or 0
		local y = tonumber(anchor and anchor.y) or 0
		runtime._eqolStandalonePanelDragUsesFakeCursor = true
		CooldownPanels.ClearAppliedAnchorCache(runtime)
		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, relativePoint, x, y)
	else
		runtime._eqolStandalonePanelDragUsesFakeCursor = nil
	end
	if frame.SetMovable then frame:SetMovable(true) end
	if frame.EnableMouse then
		runtime._eqolStandalonePanelDragMouseEnabled = true
		frame:EnableMouse(true)
	end
	runtime._eqolStandalonePanelDragging = true
	frame:StartMoving()
	return true
end

function CooldownPanels:FinishStandalonePanelDrag(panelId)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	local frame = runtime and runtime.frame
	if not (panel and frame and runtime and runtime._eqolStandalonePanelDragging) then return false end
	runtime._eqolStandalonePanelDragging = nil
	frame:StopMovingOrSizing()
	if runtime._eqolStandalonePanelDragMouseEnabled then
		runtime._eqolStandalonePanelDragMouseEnabled = nil
		frame:EnableMouse(false)
	end
	local anchor = ensurePanelAnchor(panel)
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	point = Helper.NormalizeAnchor(point, anchor and anchor.point or "CENTER")
	relativePoint = Helper.NormalizeAnchor(relativePoint, anchor and anchor.relativePoint or point)
	x = tonumber(x) or 0
	y = tonumber(y) or 0
	if runtime._eqolStandalonePanelDragUsesFakeCursor then
		anchor.point = point
		anchor.relativePoint = relativePoint
		anchor.x = x
		anchor.y = y
		panel.point = anchor.point or panel.point or "CENTER"
		panel.x = anchor.x or panel.x or 0
		panel.y = anchor.y or panel.y or 0
		runtime._eqolStandalonePanelDragUsesFakeCursor = nil
	else
		self:HandlePositionChanged(panelId, {
			point = point,
			relativePoint = relativePoint,
			x = x,
			y = y,
		})
	end
	CooldownPanels.ClearAppliedAnchorCache(runtime)
	self:ApplyPanelPosition(panelId)
	self:SyncEditModeDataFromPanel(panelId, runtime.editModeId)
	refreshEditModePanelFrame(panelId, runtime.editModeId)
	refreshEditModeSettingValues()
	return true
end

function CooldownPanels.ShowIconTooltip(self)
	if not self or not self._eqolTooltipEnabled then return end
	local entry = self._eqolTooltipEntry
	if not entry or not GameTooltip then return end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local resolvedEntry = entry
	if entry.type == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		if macro and macro.kind == "SPELL" and macro.spellID then
			resolvedEntry = { type = "SPELL", spellID = macro.spellID }
		elseif macro and macro.kind == "ITEM" and macro.itemID then
			resolvedEntry = { type = "ITEM", itemID = macro.itemID }
		end
	end
	if resolvedEntry.type == "SPELL" and resolvedEntry.spellID and GameTooltip.SetSpellByID then
		GameTooltip:SetSpellByID(getEffectiveSpellId(resolvedEntry.spellID) or resolvedEntry.spellID)
	elseif resolvedEntry.type == "CDM_AURA" and resolvedEntry.spellID and GameTooltip.SetSpellByID then
		GameTooltip:SetSpellByID(getEffectiveSpellId(resolvedEntry.spellID) or resolvedEntry.spellID)
	elseif resolvedEntry.type == "ITEM" and resolvedEntry.itemID and GameTooltip.SetItemByID then
		GameTooltip:SetItemByID(resolvedEntry.itemID)
	elseif resolvedEntry.type == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		if macro and macro.macroName then
			GameTooltip:SetText(macro.macroName)
		else
			GameTooltip:SetText(_G.MACRO or "Macro")
		end
	elseif entry.type == "SLOT" and entry.slotID then
		local shown = false
		if GameTooltip.SetInventoryItem then shown = GameTooltip:SetInventoryItem("player", entry.slotID) end
		if not shown then GameTooltip:SetText(getSlotLabel(entry.slotID)) end
	elseif entry.type == "STANCE" or entry.type == "CDM_AURA" then
		GameTooltip:SetText(getEntryName(entry))
	else
		return
	end
	GameTooltip:Show()
end

function CooldownPanels.HideIconTooltip()
	if GameTooltip then GameTooltip:Hide() end
end

function CooldownPanels.SetIconTooltipMouseState(icon, enabled)
	if not icon then return end
	local mouseEnabled = enabled == true
	if icon.SetMouseClickEnabled then
		if icon._eqolTooltipMouseClickEnabled ~= mouseEnabled then
			icon:SetMouseClickEnabled(mouseEnabled)
			icon._eqolTooltipMouseClickEnabled = mouseEnabled
		end
	end
	if icon.SetMouseMotionEnabled and icon._eqolTooltipMouseMotionEnabled ~= mouseEnabled then
		icon:SetMouseMotionEnabled(mouseEnabled)
		icon._eqolTooltipMouseMotionEnabled = mouseEnabled
	end
	if icon.EnableMouse and icon._eqolTooltipMouseEnabled ~= mouseEnabled then
		icon:EnableMouse(mouseEnabled)
		icon._eqolTooltipMouseEnabled = mouseEnabled
	end
	if not mouseEnabled and GameTooltip and GameTooltip.IsOwned and GameTooltip.Hide and GameTooltip:IsOwned(icon) then GameTooltip:Hide() end
end

function CooldownPanels.ApplyIconTooltip(icon, entry, enabled)
	if not icon then return end
	local tooltipEnabled = enabled == true and entry ~= nil
	if icon._eqolTooltipEntry == entry and icon._eqolTooltipEnabled == tooltipEnabled then return end
	icon._eqolTooltipEntry = entry
	icon._eqolTooltipEnabled = tooltipEnabled
	CooldownPanels.SetIconTooltipMouseState(icon, tooltipEnabled)
end

function CooldownPanels:GetCooldownFontDefaults(frame)
	local icon = frame and frame.icons and frame.icons[1]
	local fontString = icon and icon.cooldown and icon.cooldown.GetCountdownFontString and icon.cooldown:GetCountdownFontString()
	if fontString and fontString.GetFont then
		local fontPath, fontSize, fontStyle = fontString:GetFont()
		if fontPath then return fontPath, fontSize, fontStyle end
	end
	return Helper.GetCountFontDefaults(frame)
end

function CooldownPanels:GetGlobalFontConfigKey()
	if addon.functions and addon.functions.GetGlobalFontConfigKey then return addon.functions.GetGlobalFontConfigKey() end
	return "__EQOL_GLOBAL_FONT__"
end

function CooldownPanels:GetFontDropdownValue(value)
	if addon.functions and addon.functions.IsGlobalFontConfigValue and addon.functions.IsGlobalFontConfigValue(value) then return self:GetGlobalFontConfigKey() end
	if type(value) == "string" and value ~= "" then return value end
	return self:GetGlobalFontConfigKey()
end

function CooldownPanels:ResolveEntryCooldownTextStyle(layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	local panelCache = CooldownPanels._styleCacheRoots.cooldownTextPanel[layout]
	local srcFont = layout and layout.cooldownTextFont or nil
	local srcSize = layout and layout.cooldownTextSize or nil
	local srcStyle = layout and layout.cooldownTextStyle or nil
	local srcColor = layout and layout.cooldownTextColor or nil
	local srcX = layout and layout.cooldownTextX or nil
	local srcY = layout and layout.cooldownTextY or nil
	if
		not panelCache
		or panelCache.fallbackFontPath ~= fallbackFontPath
		or panelCache.fallbackFontSize ~= fallbackFontSize
		or panelCache.fallbackFontStyle ~= fallbackFontStyle
		or panelCache.srcFont ~= srcFont
		or panelCache.srcSize ~= srcSize
		or panelCache.srcStyle ~= srcStyle
		or panelCache.srcColor ~= srcColor
		or panelCache.srcX ~= srcX
		or panelCache.srcY ~= srcY
	then
		panelCache = panelCache or {}
		panelCache.fallbackFontPath = fallbackFontPath
		panelCache.fallbackFontSize = fallbackFontSize
		panelCache.fallbackFontStyle = fallbackFontStyle
		panelCache.srcFont = srcFont
		panelCache.srcSize = srcSize
		panelCache.srcStyle = srcStyle
		panelCache.srcColor = srcColor
		panelCache.srcX = srcX
		panelCache.srcY = srcY
		panelCache.fontPath = Helper.ResolveFontPath(srcFont, fallbackFontPath)
		panelCache.fontSize = Helper.ClampInt(srcSize, 6, 64, fallbackFontSize or 12)
		panelCache.fontStyleChoice = Helper.NormalizeFontStyleChoice(srcStyle, fallbackFontStyle)
		panelCache.fontStyle = Helper.NormalizeFontStyle(panelCache.fontStyleChoice, fallbackFontStyle) or ""
		local r, g, b, a = Helper.ResolveColor(srcColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)
		panelCache.fontColor = CooldownPanels.FillCachedColor(panelCache.fontColor, r, g, b, a)
		panelCache.fontX = Helper.ClampInt(srcX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
		panelCache.fontY = Helper.ClampInt(srcY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
		panelCache.version = (panelCache.version or 0) + 1
		CooldownPanels._styleCacheRoots.cooldownTextPanel[layout] = panelCache
	end
	if not entry or entry.cooldownTextUseGlobal ~= false then return panelCache.fontPath, panelCache.fontSize, panelCache.fontStyle, panelCache.fontColor, panelCache.fontX, panelCache.fontY end
	local cache = CooldownPanels._styleCacheRoots.cooldownTextEntry[entry]
	if
		not cache
		or cache.panelVersion ~= panelCache.version
		or cache.srcFont ~= entry.cooldownTextFont
		or cache.srcSize ~= entry.cooldownTextSize
		or cache.srcStyle ~= entry.cooldownTextStyle
		or cache.srcColor ~= entry.cooldownTextColor
		or cache.srcX ~= entry.cooldownTextX
		or cache.srcY ~= entry.cooldownTextY
	then
		cache = cache or {}
		cache.panelVersion = panelCache.version
		cache.srcFont = entry.cooldownTextFont
		cache.srcSize = entry.cooldownTextSize
		cache.srcStyle = entry.cooldownTextStyle
		cache.srcColor = entry.cooldownTextColor
		cache.srcX = entry.cooldownTextX
		cache.srcY = entry.cooldownTextY
		cache.fontPath = Helper.ResolveFontPath(entry.cooldownTextFont, panelCache.fontPath)
		cache.fontSize = Helper.ClampInt(entry.cooldownTextSize, 6, 64, panelCache.fontSize)
		local fontStyleChoice = Helper.NormalizeFontStyleChoice(entry.cooldownTextStyle, panelCache.fontStyleChoice)
		cache.fontStyle = Helper.NormalizeFontStyle(fontStyleChoice, panelCache.fontStyle) or ""
		local r, g, b, a = Helper.ResolveColor(entry.cooldownTextColor, panelCache.fontColor)
		cache.fontColor = CooldownPanels.FillCachedColor(cache.fontColor, r, g, b, a)
		cache.fontX = Helper.ClampInt(entry.cooldownTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelCache.fontX)
		cache.fontY = Helper.ClampInt(entry.cooldownTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelCache.fontY)
		CooldownPanels._styleCacheRoots.cooldownTextEntry[entry] = cache
	end
	return cache.fontPath, cache.fontSize, cache.fontStyle, cache.fontColor, cache.fontX, cache.fontY
end

function CooldownPanels:ApplyEntryCooldownTextStyle(icon, layout, entry)
	if not (icon and icon.cooldown and icon.cooldown.GetCountdownFontString) then return end
	local fontString = icon.cooldown:GetCountdownFontString()
	if not fontString then return end
	if not icon.cooldown._eqolCooldownTextDefaults then
		local fontPath, fontSize, fontStyle = fontString:GetFont()
		icon.cooldown._eqolCooldownTextDefaults = {
			font = fontPath,
			size = fontSize,
			style = fontStyle,
		}
	end
	local defaults = icon.cooldown._eqolCooldownTextDefaults
	local fontPath, fontSize, fontStyle, fontColor, fontX, fontY =
		self:ResolveEntryCooldownTextStyle(layout, entry, defaults and defaults.font, defaults and defaults.size, defaults and defaults.style)
	if fontString._eqolCooldownFont ~= fontPath or fontString._eqolCooldownFontSize ~= fontSize or fontString._eqolCooldownFontStyle ~= fontStyle then
		fontString:SetFont(fontPath, fontSize, fontStyle)
		fontString._eqolCooldownFont = fontPath
		fontString._eqolCooldownFontSize = fontSize
		fontString._eqolCooldownFontStyle = fontStyle
	end
	if fontString._eqolCooldownAnchor ~= "CENTER" or fontString._eqolCooldownX ~= fontX or fontString._eqolCooldownY ~= fontY then
		fontString:ClearAllPoints()
		fontString:SetPoint("CENTER", icon.cooldown, "CENTER", fontX, fontY)
		fontString._eqolCooldownAnchor = "CENTER"
		fontString._eqolCooldownX = fontX
		fontString._eqolCooldownY = fontY
	end
	local r = fontColor[1] or 1
	local g = fontColor[2] or 1
	local b = fontColor[3] or 1
	local a = fontColor[4] or 1
	if fontString._eqolCooldownColorR ~= r or fontString._eqolCooldownColorG ~= g or fontString._eqolCooldownColorB ~= b or fontString._eqolCooldownColorA ~= a then
		fontString:SetTextColor(r, g, b, a)
		fontString._eqolCooldownColorR = r
		fontString._eqolCooldownColorG = g
		fontString._eqolCooldownColorB = b
		fontString._eqolCooldownColorA = a
	end
end

function CooldownPanels:ResolveEntryStackTextStyle(layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	local panelCache = CooldownPanels._styleCacheRoots.stackTextPanel[layout]
	local srcFont = layout and layout.stackFont or nil
	local srcSize = layout and layout.stackFontSize or nil
	local srcStyle = layout and layout.stackFontStyle or nil
	local srcColor = layout and layout.stackColor or nil
	local srcAnchor = layout and layout.stackAnchor or nil
	local srcX = layout and layout.stackX or nil
	local srcY = layout and layout.stackY or nil
	if
		not panelCache
		or panelCache.fallbackFontPath ~= fallbackFontPath
		or panelCache.fallbackFontSize ~= fallbackFontSize
		or panelCache.fallbackFontStyle ~= fallbackFontStyle
		or panelCache.srcFont ~= srcFont
		or panelCache.srcSize ~= srcSize
		or panelCache.srcStyle ~= srcStyle
		or panelCache.srcColor ~= srcColor
		or panelCache.srcAnchor ~= srcAnchor
		or panelCache.srcX ~= srcX
		or panelCache.srcY ~= srcY
	then
		panelCache = panelCache or {}
		panelCache.fallbackFontPath = fallbackFontPath
		panelCache.fallbackFontSize = fallbackFontSize
		panelCache.fallbackFontStyle = fallbackFontStyle
		panelCache.srcFont = srcFont
		panelCache.srcSize = srcSize
		panelCache.srcStyle = srcStyle
		panelCache.srcColor = srcColor
		panelCache.srcAnchor = srcAnchor
		panelCache.srcX = srcX
		panelCache.srcY = srcY
		panelCache.fontPath = Helper.ResolveFontPath(srcFont, fallbackFontPath)
		panelCache.fontSize = Helper.ClampInt(srcSize, 6, 64, fallbackFontSize or 12)
		panelCache.fontStyleChoice = Helper.NormalizeFontStyleChoice(srcStyle, fallbackFontStyle)
		panelCache.fontStyle = Helper.NormalizeFontStyle(panelCache.fontStyleChoice, fallbackFontStyle) or ""
		local r, g, b, a = Helper.ResolveColor(srcColor, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
		panelCache.fontColor = CooldownPanels.FillCachedColor(panelCache.fontColor, r, g, b, a)
		panelCache.anchor = Helper.NormalizeAnchor(srcAnchor, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor or "BOTTOMRIGHT")
		panelCache.x = Helper.ClampInt(srcX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.stackX or 0)
		panelCache.y = Helper.ClampInt(srcY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.stackY or 0)
		panelCache.version = (panelCache.version or 0) + 1
		CooldownPanels._styleCacheRoots.stackTextPanel[layout] = panelCache
	end
	if not entry or entry.stackStyleUseGlobal ~= false then
		return panelCache.fontPath, panelCache.fontSize, panelCache.fontStyle, panelCache.fontColor, panelCache.anchor, panelCache.x, panelCache.y
	end
	local cache = CooldownPanels._styleCacheRoots.stackTextEntry[entry]
	if
		not cache
		or cache.panelVersion ~= panelCache.version
		or cache.srcFont ~= entry.stackFont
		or cache.srcSize ~= entry.stackFontSize
		or cache.srcStyle ~= entry.stackFontStyle
		or cache.srcColor ~= entry.stackColor
		or cache.srcAnchor ~= entry.stackAnchor
		or cache.srcX ~= entry.stackX
		or cache.srcY ~= entry.stackY
	then
		cache = cache or {}
		cache.panelVersion = panelCache.version
		cache.srcFont = entry.stackFont
		cache.srcSize = entry.stackFontSize
		cache.srcStyle = entry.stackFontStyle
		cache.srcColor = entry.stackColor
		cache.srcAnchor = entry.stackAnchor
		cache.srcX = entry.stackX
		cache.srcY = entry.stackY
		cache.fontPath = Helper.ResolveFontPath(entry.stackFont, panelCache.fontPath)
		cache.fontSize = Helper.ClampInt(entry.stackFontSize, 6, 64, panelCache.fontSize)
		local fontStyleChoice = Helper.NormalizeFontStyleChoice(entry.stackFontStyle, panelCache.fontStyleChoice)
		cache.fontStyle = Helper.NormalizeFontStyle(fontStyleChoice, panelCache.fontStyle) or ""
		local r, g, b, a = Helper.ResolveColor(entry.stackColor, panelCache.fontColor)
		cache.fontColor = CooldownPanels.FillCachedColor(cache.fontColor, r, g, b, a)
		cache.anchor = Helper.NormalizeAnchor(entry.stackAnchor, panelCache.anchor)
		cache.x = Helper.ClampInt(entry.stackX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelCache.x)
		cache.y = Helper.ClampInt(entry.stackY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelCache.y)
		CooldownPanels._styleCacheRoots.stackTextEntry[entry] = cache
	end
	return cache.fontPath, cache.fontSize, cache.fontStyle, cache.fontColor, cache.anchor, cache.x, cache.y
end

function CooldownPanels:ApplyEntryStackTextStyle(icon, layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	if not (icon and icon.count) then return end
	local fontPath, fontSize, fontStyle, fontColor, anchor, x, y = self:ResolveEntryStackTextStyle(layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	if icon.count._eqolStackAnchor ~= anchor or icon.count._eqolStackX ~= x or icon.count._eqolStackY ~= y then
		icon.count:ClearAllPoints()
		icon.count:SetPoint(anchor, icon, anchor, x, y)
		icon.count._eqolStackAnchor = anchor
		icon.count._eqolStackX = x
		icon.count._eqolStackY = y
	end
	if icon.count._eqolStackFont ~= fontPath or icon.count._eqolStackFontSize ~= fontSize or icon.count._eqolStackFontStyle ~= fontStyle then
		icon.count:SetFont(fontPath, fontSize, fontStyle)
		icon.count._eqolStackFont = fontPath
		icon.count._eqolStackFontSize = fontSize
		icon.count._eqolStackFontStyle = fontStyle
	end
	local r = fontColor[1] or 1
	local g = fontColor[2] or 1
	local b = fontColor[3] or 1
	local a = fontColor[4] or 1
	if icon.count._eqolStackColorR ~= r or icon.count._eqolStackColorG ~= g or icon.count._eqolStackColorB ~= b or icon.count._eqolStackColorA ~= a then
		icon.count:SetTextColor(r, g, b, a)
		icon.count._eqolStackColorR = r
		icon.count._eqolStackColorG = g
		icon.count._eqolStackColorB = b
		icon.count._eqolStackColorA = a
	end
end

function CooldownPanels:ResolveEntryChargesTextStyle(layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	local panelCache = CooldownPanels._styleCacheRoots.chargesTextPanel[layout]
	local srcFont = layout and layout.chargesFont or nil
	local srcSize = layout and layout.chargesFontSize or nil
	local srcStyle = layout and layout.chargesFontStyle or nil
	local srcColor = layout and layout.chargesColor or nil
	local srcAnchor = layout and layout.chargesAnchor or nil
	local srcX = layout and layout.chargesX or nil
	local srcY = layout and layout.chargesY or nil
	if
		not panelCache
		or panelCache.fallbackFontPath ~= fallbackFontPath
		or panelCache.fallbackFontSize ~= fallbackFontSize
		or panelCache.fallbackFontStyle ~= fallbackFontStyle
		or panelCache.srcFont ~= srcFont
		or panelCache.srcSize ~= srcSize
		or panelCache.srcStyle ~= srcStyle
		or panelCache.srcColor ~= srcColor
		or panelCache.srcAnchor ~= srcAnchor
		or panelCache.srcX ~= srcX
		or panelCache.srcY ~= srcY
	then
		panelCache = panelCache or {}
		panelCache.fallbackFontPath = fallbackFontPath
		panelCache.fallbackFontSize = fallbackFontSize
		panelCache.fallbackFontStyle = fallbackFontStyle
		panelCache.srcFont = srcFont
		panelCache.srcSize = srcSize
		panelCache.srcStyle = srcStyle
		panelCache.srcColor = srcColor
		panelCache.srcAnchor = srcAnchor
		panelCache.srcX = srcX
		panelCache.srcY = srcY
		panelCache.fontPath = Helper.ResolveFontPath(srcFont, fallbackFontPath)
		panelCache.fontSize = Helper.ClampInt(srcSize, 6, 64, fallbackFontSize or 12)
		panelCache.fontStyleChoice = Helper.NormalizeFontStyleChoice(srcStyle, fallbackFontStyle)
		panelCache.fontStyle = Helper.NormalizeFontStyle(panelCache.fontStyleChoice, fallbackFontStyle) or ""
		local r, g, b, a = Helper.ResolveColor(srcColor, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
		panelCache.fontColor = CooldownPanels.FillCachedColor(panelCache.fontColor, r, g, b, a)
		panelCache.anchor = Helper.NormalizeAnchor(srcAnchor, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor or "TOP")
		panelCache.x = Helper.ClampInt(srcX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.chargesX or 0)
		panelCache.y = Helper.ClampInt(srcY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.chargesY or 0)
		panelCache.version = (panelCache.version or 0) + 1
		CooldownPanels._styleCacheRoots.chargesTextPanel[layout] = panelCache
	end
	if not entry or entry.chargesStyleUseGlobal ~= false then
		return panelCache.fontPath, panelCache.fontSize, panelCache.fontStyle, panelCache.fontColor, panelCache.anchor, panelCache.x, panelCache.y
	end
	local cache = CooldownPanels._styleCacheRoots.chargesTextEntry[entry]
	if
		not cache
		or cache.panelVersion ~= panelCache.version
		or cache.srcFont ~= entry.chargesFont
		or cache.srcSize ~= entry.chargesFontSize
		or cache.srcStyle ~= entry.chargesFontStyle
		or cache.srcColor ~= entry.chargesColor
		or cache.srcAnchor ~= entry.chargesAnchor
		or cache.srcX ~= entry.chargesX
		or cache.srcY ~= entry.chargesY
	then
		cache = cache or {}
		cache.panelVersion = panelCache.version
		cache.srcFont = entry.chargesFont
		cache.srcSize = entry.chargesFontSize
		cache.srcStyle = entry.chargesFontStyle
		cache.srcColor = entry.chargesColor
		cache.srcAnchor = entry.chargesAnchor
		cache.srcX = entry.chargesX
		cache.srcY = entry.chargesY
		cache.fontPath = Helper.ResolveFontPath(entry.chargesFont, panelCache.fontPath)
		cache.fontSize = Helper.ClampInt(entry.chargesFontSize, 6, 64, panelCache.fontSize)
		local fontStyleChoice = Helper.NormalizeFontStyleChoice(entry.chargesFontStyle, panelCache.fontStyleChoice)
		cache.fontStyle = Helper.NormalizeFontStyle(fontStyleChoice, panelCache.fontStyle) or ""
		local r, g, b, a = Helper.ResolveColor(entry.chargesColor, panelCache.fontColor)
		cache.fontColor = CooldownPanels.FillCachedColor(cache.fontColor, r, g, b, a)
		cache.anchor = Helper.NormalizeAnchor(entry.chargesAnchor, panelCache.anchor)
		cache.x = Helper.ClampInt(entry.chargesX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelCache.x)
		cache.y = Helper.ClampInt(entry.chargesY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelCache.y)
		CooldownPanels._styleCacheRoots.chargesTextEntry[entry] = cache
	end
	return cache.fontPath, cache.fontSize, cache.fontStyle, cache.fontColor, cache.anchor, cache.x, cache.y
end

function CooldownPanels:ApplyEntryChargesTextStyle(icon, layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	if not (icon and icon.charges) then return end
	local fontPath, fontSize, fontStyle, fontColor, anchor, x, y = self:ResolveEntryChargesTextStyle(layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	if icon.charges._eqolChargesAnchor ~= anchor or icon.charges._eqolChargesX ~= x or icon.charges._eqolChargesY ~= y then
		icon.charges:ClearAllPoints()
		icon.charges:SetPoint(anchor, icon, anchor, x, y)
		icon.charges._eqolChargesAnchor = anchor
		icon.charges._eqolChargesX = x
		icon.charges._eqolChargesY = y
	end
	if icon.charges._eqolChargesFont ~= fontPath or icon.charges._eqolChargesFontSize ~= fontSize or icon.charges._eqolChargesFontStyle ~= fontStyle then
		icon.charges:SetFont(fontPath, fontSize, fontStyle)
		icon.charges._eqolChargesFont = fontPath
		icon.charges._eqolChargesFontSize = fontSize
		icon.charges._eqolChargesFontStyle = fontStyle
	end
	local r = fontColor[1] or 1
	local g = fontColor[2] or 1
	local b = fontColor[3] or 1
	local a = fontColor[4] or 1
	if icon.charges._eqolChargesColorR ~= r or icon.charges._eqolChargesColorG ~= g or icon.charges._eqolChargesColorB ~= b or icon.charges._eqolChargesColorA ~= a then
		icon.charges:SetTextColor(r, g, b, a)
		icon.charges._eqolChargesColorR = r
		icon.charges._eqolChargesColorG = g
		icon.charges._eqolChargesColorB = b
		icon.charges._eqolChargesColorA = a
	end
end

function CooldownPanels:ResolveEntryStaticTextStyle(layout, entry, fallbackFontPath, fallbackFontSize, fallbackFontStyle)
	local panelFontPath = Helper.ResolveFontPath(layout and layout.staticTextFont, fallbackFontPath)
	local panelFontSize = Helper.ClampInt(layout and layout.staticTextSize, 6, 64, (layout and layout.staticTextSize) or Helper.PANEL_LAYOUT_DEFAULTS.staticTextSize or fallbackFontSize or 12)
	local panelFontStyleChoice =
		Helper.NormalizeFontStyleChoice(layout and layout.staticTextStyle, layout and layout.staticTextStyle or Helper.PANEL_LAYOUT_DEFAULTS.staticTextStyle or fallbackFontStyle)
	local panelFontStyle = Helper.NormalizeFontStyle(panelFontStyleChoice, fallbackFontStyle) or ""
	local panelFontColor = Helper.NormalizeColor(layout and layout.staticTextColor, Helper.PANEL_LAYOUT_DEFAULTS.staticTextColor or { 1, 1, 1, 1 })
	local panelAnchor = Helper.NormalizeAnchor(layout and layout.staticTextAnchor, Helper.PANEL_LAYOUT_DEFAULTS.staticTextAnchor or "CENTER")
	local panelX = Helper.ClampInt(layout and layout.staticTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.staticTextX or 0)
	local panelY = Helper.ClampInt(layout and layout.staticTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.staticTextY or 0)
	if not entry or entry.staticTextUseGlobal ~= false then return panelFontPath, panelFontSize, panelFontStyle, panelFontColor, panelAnchor, panelX, panelY end
	local fontPath = Helper.ResolveFontPath(entry.staticTextFont, panelFontPath)
	local fontSize = Helper.ClampInt(entry.staticTextSize, 6, 64, panelFontSize)
	local fontStyleChoice = Helper.NormalizeFontStyleChoice(entry.staticTextStyle, panelFontStyleChoice)
	local fontStyle = Helper.NormalizeFontStyle(fontStyleChoice, panelFontStyle) or ""
	local fontColor = Helper.NormalizeColor(entry.staticTextColor, panelFontColor)
	local anchor = Helper.NormalizeAnchor(entry.staticTextAnchor, panelAnchor)
	local x = Helper.ClampInt(entry.staticTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelX)
	local y = Helper.ClampInt(entry.staticTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, panelY)
	return fontPath, fontSize, fontStyle, fontColor, anchor, x, y
end

function CooldownPanels:ResolveEntryGlowStyle(layout, entry)
	local panelCache = CooldownPanels._styleCacheRoots.glowPanel[layout]
	local srcColor = layout and layout.readyGlowColor or nil
	local srcStyle = layout and layout.readyGlowStyle or nil
	local srcInset = layout and layout.readyGlowInset or nil
	if not panelCache or panelCache.srcColor ~= srcColor or panelCache.srcStyle ~= srcStyle or panelCache.srcInset ~= srcInset then
		panelCache = panelCache or {}
		panelCache.srcColor = srcColor
		panelCache.srcStyle = srcStyle
		panelCache.srcInset = srcInset
		local r, g, b, a = Helper.ResolveColor(srcColor, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
		panelCache.color = CooldownPanels.FillCachedColor(panelCache.color, r, g, b, a)
		panelCache.style = Helper.NormalizeGlowStyle(srcStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle)
		panelCache.inset = Helper.NormalizeGlowInset(srcInset, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0)
		panelCache.version = (panelCache.version or 0) + 1
		CooldownPanels._styleCacheRoots.glowPanel[layout] = panelCache
	end
	if not entry or entry.glowUseGlobal ~= false then return 0, panelCache.color, panelCache.style, panelCache.inset end
	local cache = CooldownPanels._styleCacheRoots.glowEntry[entry]
	if not cache or cache.panelVersion ~= panelCache.version or cache.srcColor ~= entry.glowColor or cache.srcStyle ~= entry.glowStyle or cache.srcInset ~= entry.glowInset then
		cache = cache or {}
		cache.panelVersion = panelCache.version
		cache.srcColor = entry.glowColor
		cache.srcStyle = entry.glowStyle
		cache.srcInset = entry.glowInset
		local r, g, b, a = Helper.ResolveColor(entry.glowColor, panelCache.color)
		cache.color = CooldownPanels.FillCachedColor(cache.color, r, g, b, a)
		cache.style = Helper.NormalizeGlowStyle(entry.glowStyle, panelCache.style)
		cache.inset = Helper.NormalizeGlowInset(entry.glowInset, panelCache.inset)
		CooldownPanels._styleCacheRoots.glowEntry[entry] = cache
	end
	return 0, cache.color, cache.style, cache.inset
end

function CooldownPanels:ResolveEntryReadyGlowCheckPower(layout, entry)
	local panelValue = layout and layout.readyGlowCheckPower == true
	if not entry or entry.glowUseGlobal ~= false then return panelValue end
	return entry.readyGlowCheckPower == true
end

function CooldownPanels:ResolveEntryPandemicGlowColor(layout, entry)
	local color = self:ResolveEntryPandemicGlowVisual(layout, entry)
	return color
end

function CooldownPanels:ResolveEntryPandemicGlowVisual(layout, entry)
	local _, panelReadyColor, panelReadyStyle, panelReadyInset = self:ResolveEntryGlowStyle(layout, nil)
	local panelCache = CooldownPanels._styleCacheRoots.pandemicGlowPanel[layout]
	local srcColor = layout and layout.pandemicGlowColor or nil
	local srcStyle = layout and layout.pandemicGlowStyle or nil
	local srcInset = layout and layout.pandemicGlowInset or nil
	if
		not panelCache
		or panelCache.srcColor ~= srcColor
		or panelCache.srcStyle ~= srcStyle
		or panelCache.srcInset ~= srcInset
		or panelCache.readyColor ~= panelReadyColor
		or panelCache.readyStyle ~= panelReadyStyle
		or panelCache.readyInset ~= panelReadyInset
	then
		panelCache = panelCache or {}
		panelCache.srcColor = srcColor
		panelCache.srcStyle = srcStyle
		panelCache.srcInset = srcInset
		panelCache.readyColor = panelReadyColor
		panelCache.readyStyle = panelReadyStyle
		panelCache.readyInset = panelReadyInset
		local r, g, b, a = Helper.ResolveColor(srcColor, panelReadyColor)
		panelCache.color = CooldownPanels.FillCachedColor(panelCache.color, r, g, b, a)
		panelCache.style = Helper.NormalizeGlowStyle(srcStyle, panelReadyStyle)
		panelCache.inset = Helper.NormalizeGlowInset(srcInset, panelReadyInset)
		panelCache.version = (panelCache.version or 0) + 1
		CooldownPanels._styleCacheRoots.pandemicGlowPanel[layout] = panelCache
	end
	if not entry or entry.glowUseGlobal ~= false then return panelCache.color, panelCache.style, panelCache.inset end
	local cache = CooldownPanels._styleCacheRoots.pandemicGlowEntry[entry]
	if not cache or cache.panelVersion ~= panelCache.version or cache.srcColor ~= entry.pandemicGlowColor or cache.srcStyle ~= entry.pandemicGlowStyle or cache.srcInset ~= entry.pandemicGlowInset then
		cache = cache or {}
		cache.panelVersion = panelCache.version
		cache.srcColor = entry.pandemicGlowColor
		cache.srcStyle = entry.pandemicGlowStyle
		cache.srcInset = entry.pandemicGlowInset
		local r, g, b, a = Helper.ResolveColor(entry.pandemicGlowColor, panelCache.color)
		cache.color = CooldownPanels.FillCachedColor(cache.color, r, g, b, a)
		cache.style = Helper.NormalizeGlowStyle(entry.pandemicGlowStyle, panelCache.style)
		cache.inset = Helper.NormalizeGlowInset(entry.pandemicGlowInset, panelCache.inset)
		CooldownPanels._styleCacheRoots.pandemicGlowEntry[entry] = cache
	end
	return cache.color, cache.style, cache.inset
end

function CooldownPanels:ResolveEntryProcGlowVisual(layout, entry)
	local _, _, panelReadyStyle, panelReadyInset = self:ResolveEntryGlowStyle(layout, nil)
	local panelCache = CooldownPanels._styleCacheRoots.procGlowPanel[layout]
	local srcStyle = layout and layout.procGlowStyle or nil
	local srcInset = layout and layout.procGlowInset or nil
	if not panelCache or panelCache.srcStyle ~= srcStyle or panelCache.srcInset ~= srcInset or panelCache.readyStyle ~= panelReadyStyle or panelCache.readyInset ~= panelReadyInset then
		panelCache = panelCache or {}
		panelCache.srcStyle = srcStyle
		panelCache.srcInset = srcInset
		panelCache.readyStyle = panelReadyStyle
		panelCache.readyInset = panelReadyInset
		panelCache.style = Helper.NormalizeGlowStyle(srcStyle, panelReadyStyle)
		panelCache.inset = Helper.NormalizeGlowInset(srcInset, panelReadyInset)
		panelCache.version = (panelCache.version or 0) + 1
		CooldownPanels._styleCacheRoots.procGlowPanel[layout] = panelCache
	end
	if not entry or entry.procGlowUseGlobal ~= false then return panelCache.style, panelCache.inset end
	local cache = CooldownPanels._styleCacheRoots.procGlowEntry[entry]
	if not cache or cache.panelVersion ~= panelCache.version or cache.srcStyle ~= entry.procGlowStyle or cache.srcInset ~= entry.procGlowInset then
		cache = cache or {}
		cache.panelVersion = panelCache.version
		cache.srcStyle = entry.procGlowStyle
		cache.srcInset = entry.procGlowInset
		cache.style = Helper.NormalizeGlowStyle(entry.procGlowStyle, panelCache.style)
		cache.inset = Helper.NormalizeGlowInset(entry.procGlowInset, panelCache.inset)
		CooldownPanels._styleCacheRoots.procGlowEntry[entry] = cache
	end
	return cache.style, cache.inset
end

function CooldownPanels:ResolveEntryProcGlowEnabled(layout, entry)
	local panelValue = not (layout and layout.procGlowEnabled == false)
	if not entry or entry.procGlowUseGlobal ~= false then return panelValue end
	return entry.procGlowEnabled ~= false
end

function CooldownPanels:ClearEntryStateTexture(entry)
	if type(entry) ~= "table" then return end
	entry.stateTextureInput = ""
	entry.stateTextureType = nil
	entry.stateTextureAtlas = nil
	entry.stateTextureFileID = nil
end

function CooldownPanels:ApplyEntryStateTextureInput(entry, value)
	if type(entry) ~= "table" then return false, nil end
	local input = Helper.NormalizeTextureInput(value)
	if input == "" then
		self:ClearEntryStateTexture(entry)
		return true, nil
	end

	local resolvedType, resolvedValue = Helper.ResolveTextureInput(input)
	if not resolvedType then return false, string.format(L["CooldownPanelStateTextureInvalid"] or "Texture '%s' was not found. Use a valid atlas name or FileDataID.", input) end

	entry.stateTextureInput = input
	entry.stateTextureType = resolvedType
	if resolvedType == "ATLAS" then
		entry.stateTextureAtlas = resolvedValue
		entry.stateTextureFileID = nil
	else
		entry.stateTextureFileID = resolvedValue
		entry.stateTextureAtlas = nil
	end
	return true, nil
end

function CooldownPanels:ResolveEntryStateTexture(entry)
	if type(entry) ~= "table" then return nil end
	local input = Helper.NormalizeTextureInput(entry.stateTextureInput)
	if input == "" then return nil end

	local textureType = type(entry.stateTextureType) == "string" and strupper(entry.stateTextureType) or nil
	local textureValue
	if textureType == "ATLAS" and type(entry.stateTextureAtlas) == "string" and entry.stateTextureAtlas ~= "" then
		textureValue = entry.stateTextureAtlas
	elseif textureType == "FILEID" then
		local fileID = tonumber(entry.stateTextureFileID)
		if fileID and fileID > 0 then textureValue = fileID end
	end

	if not textureValue then
		local resolvedType, resolvedValue = Helper.ResolveTextureInput(input)
		if not resolvedType then
			self:ClearEntryStateTexture(entry)
			return nil
		end
		textureType = resolvedType
		textureValue = resolvedValue
		entry.stateTextureInput = input
		entry.stateTextureType = resolvedType
		if resolvedType == "ATLAS" then
			entry.stateTextureAtlas = resolvedValue
			entry.stateTextureFileID = nil
		else
			entry.stateTextureFileID = resolvedValue
			entry.stateTextureAtlas = nil
		end
	end

	local scale = Helper.ClampNumber(entry.stateTextureScale, 0.1, 8, 1)
	local width = Helper.ClampNumber(entry.stateTextureWidth, 0.1, 8, 1)
	local height = Helper.ClampNumber(entry.stateTextureHeight, 0.1, 8, 1)
	local angle = Helper.ClampNumber(entry.stateTextureAngle, 0, 360, 0)
	local doubleTexture = entry.stateTextureDouble == true
	local mirror = entry.stateTextureMirror == true
	local mirrorSecond = entry.stateTextureMirrorSecond == true
	local spacingX = Helper.ClampInt(entry.stateTextureSpacingX, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)
	local spacingY = Helper.ClampInt(entry.stateTextureSpacingY, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)
	return textureType, textureValue, width, height, scale, angle, doubleTexture, mirror, mirrorSecond, spacingX, spacingY
end

function CooldownPanels:HasConfiguredStateTexture(entry)
	if type(entry) ~= "table" then return false end
	local input = Helper.NormalizeTextureInput(entry.stateTextureInput)
	if input == "" then return false end
	local textureType = type(entry.stateTextureType) == "string" and strupper(entry.stateTextureType) or nil
	if textureType == "ATLAS" then return type(entry.stateTextureAtlas) == "string" and entry.stateTextureAtlas ~= "" end
	if textureType == "FILEID" then
		local fileID = tonumber(entry.stateTextureFileID)
		return fileID ~= nil and fileID > 0
	end
	local resolvedType = self:ResolveEntryStateTexture(entry)
	return resolvedType ~= nil
end

function CooldownPanels:ResolveEntryNoDesaturation(layout, entry)
	local panelValue = layout and layout.noDesaturation == true
	if not entry or entry.noDesaturationUseGlobal ~= false then return panelValue end
	return entry.noDesaturation == true
end

function CooldownPanels:ResolveEntryCooldownVisibility(layout, entry)
	local hideOnCooldown = layout and layout.hideOnCooldown == true
	local showOnCooldown = layout and layout.showOnCooldown == true
	if showOnCooldown then hideOnCooldown = false end
	if not entry or entry.cooldownVisibilityUseGlobal ~= false then return hideOnCooldown, showOnCooldown end
	hideOnCooldown = entry.hideOnCooldown == true
	showOnCooldown = entry.showOnCooldown == true
	if showOnCooldown then hideOnCooldown = false end
	return hideOnCooldown, showOnCooldown
end

function CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, entry)
	local values = self.CDM_AURA_ALWAYS_SHOW_MODE or {}
	local panelValue = self:NormalizeCDMAuraAlwaysShowMode(layout and layout.cdmAuraAlwaysShowMode, Helper.PANEL_LAYOUT_DEFAULTS.cdmAuraAlwaysShowMode or values.HIDE or "HIDE")
	if not entry or entry.type ~= "CDM_AURA" or entry.cdmAuraAlwaysShowUseGlobal ~= false then return panelValue end
	return self:NormalizeCDMAuraAlwaysShowMode(entry.cdmAuraAlwaysShowMode, panelValue)
end

function CooldownPanels:ResolveEntryCheckPower(layout, entry)
	local panelValue = layout and layout.checkPower == true
	if not entry or entry.checkPowerUseGlobal ~= false then return panelValue end
	return entry.checkPower == true
end

function CooldownPanels:ResolveEntryHideWhenNoResource(layout, entry)
	local panelValue = layout and layout.hideWhenNoResource == true
	if not entry then return panelValue end
	local entryType = entry.type
	if entryType == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		entryType = (macro and macro.kind) or entryType
	end
	if entryType ~= "SPELL" then return false end
	if entry.hideWhenNoResourceUseGlobal ~= false then return panelValue end
	return entry.hideWhenNoResource == true
end

function CooldownPanels:ResolveEntryShowIconTexture(layout, entry)
	local panelValue = not (layout and layout.showIconTexture == false)
	if not entry then return panelValue end
	if self:HasConfiguredStateTexture(entry) then return false end
	if entry.hideIcon == true then return false end
	if entry.showIconTextureUseGlobal == false then return true end
	return panelValue
end

function CooldownPanels:ShouldShowEditorGhostIcon(layout, entry, showIconTexture, editorContext)
	if editorContext ~= true or not entry then return false end
	if showIconTexture == false then return true end
	return Helper.ClampInt(layout and layout.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) ~= 0
		or Helper.ClampInt(layout and layout.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) ~= 0
		or Helper.ClampInt(entry.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) ~= 0
		or Helper.ClampInt(entry.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0) ~= 0
end

function CooldownPanels:ResolveEntryCooldownVisuals(layout, entry)
	local panelShowChargesCooldown = layout and layout.showChargesCooldown == true
	local panelDrawEdge = not (layout and layout.cooldownDrawEdge == false)
	local panelDrawBling = not (layout and layout.cooldownDrawBling == false)
	local panelDrawSwipe = not (layout and layout.cooldownDrawSwipe == false)
	local panelGcdDrawEdge = layout and layout.cooldownGcdDrawEdge == true
	local panelGcdDrawBling = layout and layout.cooldownGcdDrawBling == true
	local panelGcdDrawSwipe = layout and layout.cooldownGcdDrawSwipe == true
	if not entry or entry.cooldownVisualsUseGlobal ~= false then
		return panelShowChargesCooldown, panelDrawEdge, panelDrawBling, panelDrawSwipe, panelGcdDrawEdge, panelGcdDrawBling, panelGcdDrawSwipe
	end
	return entry.showChargesCooldown == true,
		entry.cooldownDrawEdge == true,
		entry.cooldownDrawBling == true,
		entry.cooldownDrawSwipe == true,
		entry.cooldownGcdDrawEdge == true,
		entry.cooldownGcdDrawBling == true,
		entry.cooldownGcdDrawSwipe == true
end

function CooldownPanels:ResolveEntryIconVisualLayout(layout, entry, baseSize)
	if type(entry) == "number" and baseSize == nil and type(layout) == "table" and layout.id ~= nil and layout.type ~= nil then
		baseSize = entry
		entry = layout
		layout = nil
	end
	local fallbackSize = Helper.ClampInt(baseSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
	local layoutOffsetX = Helper.ClampInt(layout and layout.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	local layoutOffsetY = Helper.ClampInt(layout and layout.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	if not entry then return fallbackSize, layoutOffsetX, layoutOffsetY end
	local cache = CooldownPanels._styleCacheRoots.iconLayoutEntry[entry]
	if
		not cache
		or cache.baseSize ~= fallbackSize
		or cache.layoutOffsetX ~= layoutOffsetX
		or cache.layoutOffsetY ~= layoutOffsetY
		or cache.iconSizeUseGlobal ~= entry.iconSizeUseGlobal
		or cache.iconSize ~= entry.iconSize
		or cache.iconOffsetX ~= entry.iconOffsetX
		or cache.iconOffsetY ~= entry.iconOffsetY
	then
		cache = cache or {}
		cache.baseSize = fallbackSize
		cache.layoutOffsetX = layoutOffsetX
		cache.layoutOffsetY = layoutOffsetY
		cache.iconSizeUseGlobal = entry.iconSizeUseGlobal
		cache.iconSize = entry.iconSize
		cache.iconOffsetX = entry.iconOffsetX
		cache.iconOffsetY = entry.iconOffsetY
		cache.size = entry.iconSizeUseGlobal == false and Helper.ClampInt(entry.iconSize, 12, 128, fallbackSize) or fallbackSize
		cache.offsetX = layoutOffsetX + Helper.ClampInt(entry.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
		cache.offsetY = layoutOffsetY + Helper.ClampInt(entry.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
		CooldownPanels._styleCacheRoots.iconLayoutEntry[entry] = cache
	end
	return cache.size, cache.offsetX, cache.offsetY
end

function CooldownPanels:ApplyEntryIconVisualLayout(icon, layout, entry)
	if not icon then return end
	local slotAnchor = icon.slotAnchor
	local baseSize = Helper.ClampInt(icon._eqolBaseSlotSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
	local size, offsetX, offsetY = self:ResolveEntryIconVisualLayout(layout, entry, baseSize)
	local currentWidth, currentHeight = icon:GetSize()
	local previewBlingSize = icon.previewBling and (size * 1.5) or nil
	if
		icon._eqolVisualSize == size
		and currentWidth == size
		and currentHeight == size
		and icon._eqolVisualAnchor == slotAnchor
		and icon._eqolVisualOffsetX == offsetX
		and icon._eqolVisualOffsetY == offsetY
		and ((not icon.previewGlowBorder) or icon.previewGlowBorder._eqolSize == size)
		and ((not icon.previewBling) or (icon.previewBling._eqolVisualAnchor == icon and icon.previewBling._eqolVisualSize == previewBlingSize))
	then
		return
	end
	if icon._eqolVisualSize ~= size or currentWidth ~= size or currentHeight ~= size then
		icon:SetSize(size, size)
		icon._eqolVisualSize = size
	end
	if slotAnchor then
		local point, relativeTo, relativePoint, currentX, currentY = icon:GetPoint(1)
		local needsAnchorUpdate = icon:GetNumPoints() ~= 1
			or icon._eqolVisualAnchor ~= slotAnchor
			or icon._eqolVisualOffsetX ~= offsetX
			or icon._eqolVisualOffsetY ~= offsetY
			or point ~= "CENTER"
			or relativeTo ~= slotAnchor
			or relativePoint ~= "CENTER"
			or currentX ~= offsetX
			or currentY ~= offsetY
		if needsAnchorUpdate then
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", slotAnchor, "CENTER", offsetX, offsetY)
			icon._eqolVisualAnchor = slotAnchor
			icon._eqolVisualOffsetX = offsetX
			icon._eqolVisualOffsetY = offsetY
		end
	end
	CooldownPanels.UpdatePreviewGlowBorderLayout(icon, size)
	if icon.previewBling then
		if icon.previewBling._eqolVisualAnchor ~= icon then
			icon.previewBling:ClearAllPoints()
			icon.previewBling:SetPoint("CENTER", icon, "CENTER", 0, 0)
			icon.previewBling._eqolVisualAnchor = icon
		end
		if icon.previewBling._eqolVisualSize ~= previewBlingSize then
			icon.previewBling:SetSize(previewBlingSize, previewBlingSize)
			icon.previewBling._eqolVisualSize = previewBlingSize
		end
	end
end

function CooldownPanels:ApplyEditorGhostIcon(icon)
	local texture = icon and icon.editorGhostTexture or nil
	local source = icon and icon.texture or nil
	if not texture or not source then return end
	texture:SetTexture(source:GetTexture())
	texture:SetTexCoord(source:GetTexCoord())
	texture:SetShown(true)
	texture:SetDesaturated(true)
	texture:SetAlpha(0.32)
	texture._eqolGhostShown = true
end

function CooldownPanels:HideEditorGhostIcon(icon)
	local texture = icon and icon.editorGhostTexture or nil
	if not texture then return end
	if texture._eqolGhostShown ~= true then return end
	texture:SetTexture(nil)
	texture:Hide()
	texture._eqolGhostShown = false
end

local function applyStaticText(icon, layout, entry, defaultFontPath, defaultFontSize, defaultFontStyle, cooldownActive)
	if not icon or not icon.staticText then return end
	if not entry or type(entry.staticText) ~= "string" or entry.staticText == "" then
		icon.staticText:Hide()
		return
	end
	if entry.staticTextShowOnCooldown == true and not cooldownActive then
		icon.staticText:Hide()
		return
	end
	local text = entry.staticText
	if text:find("\\n", 1, true) then text = text:gsub("\\n", "\n") end
	if text:find("|n", 1, true) then text = text:gsub("|n", "\n") end
	local fontPath, fontSize, fontStyle, fontColor, anchor, x, y = CooldownPanels:ResolveEntryStaticTextStyle(layout, entry, defaultFontPath, defaultFontSize, defaultFontStyle)
	icon.staticText:SetFont(fontPath, fontSize, fontStyle)
	icon.staticText:SetTextColor(fontColor[1] or 1, fontColor[2] or 1, fontColor[3] or 1, fontColor[4] or 1)
	icon.staticText:ClearAllPoints()
	icon.staticText:SetPoint(anchor, icon.overlay, anchor, x, y)
	icon.staticText:SetText(text)
	icon.staticText:Show()
end

local function applyStateTexture(icon, data)
	local texture = icon and icon.stateTexture or nil
	local textureSecond = icon and icon.stateTextureSecond or nil
	if not texture then return end
	if not (data and data.stateTextureShown == true and data.stateTextureType and data.stateTextureValue) then
		texture:Hide()
		if textureSecond then textureSecond:Hide() end
		return
	end

	local scale = Helper.ClampNumber(data.stateTextureScale, 0.1, 8, 1)
	local widthScale = Helper.ClampNumber(data.stateTextureWidth, 0.1, 8, 1)
	local heightScale = Helper.ClampNumber(data.stateTextureHeight, 0.1, 8, 1)
	local angle = Helper.ClampNumber(data.stateTextureAngle, 0, 360, 0)
	local doubleTexture = data.stateTextureDouble == true
	local mirror = data.stateTextureMirror == true
	local mirrorSecond = data.stateTextureMirrorSecond == true
	local spacingX = Helper.ClampInt(data.stateTextureSpacingX, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)
	local spacingY = Helper.ClampInt(data.stateTextureSpacingY, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)
	local atlasInfo = data.stateTextureType == "ATLAS" and Api.GetAtlasInfo and Api.GetAtlasInfo(data.stateTextureValue) or nil
	local baseWidth, baseHeight
	if atlasInfo and atlasInfo.width and atlasInfo.height then
		baseWidth = atlasInfo.width
		baseHeight = atlasInfo.height
	else
		baseWidth, baseHeight = icon:GetSize()
		baseWidth = baseWidth or 36
		baseHeight = baseHeight or 36
	end
	local width = baseWidth * scale * widthScale
	local height = baseHeight * scale * heightScale

	local function applyRegion(region, offsetX, offsetY, mirrored)
		if not region then return end
		region:ClearAllPoints()
		region:SetPoint("CENTER", icon, "CENTER", offsetX or 0, offsetY or 0)
		region:SetSize(width, height)
		if data.stateTextureType == "ATLAS" then
			local atlas = data.stateTextureValue
			region:SetTexture(nil)
			region:SetAtlas(atlas, true)
			if atlasInfo then
				local left = atlasInfo.leftTexCoord or 0
				local right = atlasInfo.rightTexCoord or 1
				local top = atlasInfo.topTexCoord or 0
				local bottom = atlasInfo.bottomTexCoord or 1
				if mirrored then
					region:SetTexCoord(right, left, top, bottom)
				else
					region:SetTexCoord(left, right, top, bottom)
				end
			end
		else
			local fileID = tonumber(data.stateTextureValue)
			region:SetTexture(nil)
			region:SetTexture(fileID)
			if mirrored then
				region:SetTexCoord(1, 0, 0, 1)
			else
				region:SetTexCoord(0, 1, 0, 1)
			end
		end
		if region.SetRotation then region:SetRotation(math.rad(angle)) end
		region:Show()
	end

	if doubleTexture and textureSecond then
		local halfX = spacingX / 2
		local halfY = spacingY / 2
		local secondMirrored = (mirrorSecond and not mirror) or ((not mirrorSecond) and mirror)
		applyRegion(texture, -halfX, -halfY, mirror)
		applyRegion(textureSecond, halfX, halfY, secondMirrored)
	else
		applyRegion(texture, 0, 0, mirror)
		if textureSecond then textureSecond:Hide() end
	end
end

local function createIconFrame(parent)
	local icon = CreateFrame("Frame", nil, parent)
	icon:Hide()
	icon:EnableMouse(false)
	icon:SetScript("OnEnter", CooldownPanels.ShowIconTooltip)
	icon:SetScript("OnLeave", CooldownPanels.HideIconTooltip)

	icon.slotAnchor = CreateFrame("Frame", nil, parent)
	icon.slotAnchor:EnableMouse(false)
	icon.slotAnchorHandle = CreateFrame("Button", nil, icon.slotAnchor)
	icon.slotAnchorHandle:SetAllPoints(icon.slotAnchor)
	icon.slotAnchorHandle:EnableMouse(false)
	icon.slotAnchorHandle:Hide()

	icon.editorGhostTexture = icon.slotAnchor:CreateTexture(nil, "ARTWORK")
	icon.editorGhostTexture:SetAllPoints(icon.slotAnchor)
	icon.editorGhostTexture:Hide()

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints(icon)

	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints(icon)
	icon.cooldown:SetHideCountdownNumbers(true)

	icon.overlay = CreateFrame("Frame", nil, icon)
	icon.overlay:SetAllPoints(icon)
	icon.overlay:SetFrameStrata(icon.cooldown:GetFrameStrata() or icon:GetFrameStrata())
	icon.overlay:SetFrameLevel((icon.cooldown:GetFrameLevel() or icon:GetFrameLevel()) + 5)
	icon.overlay:EnableMouse(false)

	icon.layoutHandle = CreateFrame("Button", nil, icon)
	icon.layoutHandle:SetAllPoints(icon)
	icon.layoutHandle:SetFrameStrata(icon.overlay:GetFrameStrata() or icon:GetFrameStrata())
	icon.layoutHandle:SetFrameLevel((icon.overlay:GetFrameLevel() or icon:GetFrameLevel()) + 20)
	icon.layoutHandle:EnableMouse(false)
	icon.layoutHandle:Hide()

	icon.border = CreateFrame("Frame", nil, icon, "BackdropTemplate")
	icon.border:SetFrameStrata(icon.cooldown:GetFrameStrata() or icon:GetFrameStrata())
	icon.border:SetFrameLevel((icon.cooldown:GetFrameLevel() or icon:GetFrameLevel()) + 1)
	icon.border:EnableMouse(false)
	icon.border:Hide()

	icon.count = icon.overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.count:SetPoint("BOTTOMRIGHT", icon.overlay, "BOTTOMRIGHT", -1, 1)
	icon.count:Hide()

	icon.charges = icon.overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.charges:SetPoint("TOP", icon.overlay, "TOP", 0, -1)
	icon.charges:Hide()

	icon.rangeOverlay = icon.overlay:CreateTexture(nil, "BACKGROUND")
	icon.rangeOverlay:SetAllPoints(icon.overlay)
	icon.rangeOverlay:Hide()

	icon.stateTexture = icon:CreateTexture(nil, "ARTWORK", nil, 1)
	icon.stateTexture:SetBlendMode("BLEND")
	icon.stateTexture:Hide()

	icon.stateTextureSecond = icon:CreateTexture(nil, "ARTWORK", nil, 1)
	icon.stateTextureSecond:SetBlendMode("BLEND")
	icon.stateTextureSecond:Hide()

	icon.keybind = icon.overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.keybind:SetPoint("TOPLEFT", icon.overlay, "TOPLEFT", 2, -2)
	icon.keybind:Hide()

	icon.staticText = icon.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	icon.staticText:SetPoint("CENTER", icon.overlay, "CENTER", 0, 0)
	icon.staticText:SetJustifyH("CENTER")
	icon.staticText:SetJustifyV("MIDDLE")
	if icon.staticText.SetWordWrap then icon.staticText:SetWordWrap(true) end
	icon.staticText:Hide()

	icon.msqNormal = icon:CreateTexture(nil, "OVERLAY")
	icon.msqNormal:SetAllPoints(icon)
	icon.msqNormal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	icon.msqNormal:Hide()

	icon.previewGlowBorder = CreateFrame("Frame", nil, icon, "BackdropTemplate")
	icon.previewGlowBorder:SetFrameStrata(icon.cooldown:GetFrameStrata() or icon:GetFrameStrata())
	icon.previewGlowBorder:SetFrameLevel((icon.cooldown:GetFrameLevel() or icon:GetFrameLevel()) + 2)
	icon.previewGlowBorder:EnableMouse(false)
	icon.previewGlowBorder:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 2,
		insets = { left = 0, right = 0, top = 0, bottom = 0 },
	})
	icon.previewGlowBorder:SetBackdropColor(0, 0, 0, 0)
	icon.previewGlowBorder:Hide()

	icon.previewBling = icon:CreateTexture(nil, "OVERLAY")
	icon.previewBling:SetTexture("Interface\\Cooldown\\star4")
	icon.previewBling:SetVertexColor(0.3, 0.6, 1, 0.9)
	icon.previewBling:SetBlendMode("ADD")
	icon.previewBling:Hide()

	icon.previewSoundBorder = CreateFrame("Frame", nil, icon.overlay, "BackdropTemplate")
	icon.previewSoundBorder:SetSize(14, 14)
	icon.previewSoundBorder:SetPoint("TOPRIGHT", icon.overlay, "TOPRIGHT", -1, -1)
	icon.previewSoundBorder:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	icon.previewSoundBorder:SetBackdropColor(0, 0, 0, 0.55)
	icon.previewSoundBorder:SetBackdropBorderColor(0.9, 0.9, 0.9, 0.9)
	icon.previewSoundBorder:Hide()

	icon.previewSound = icon.previewSoundBorder:CreateTexture(nil, "OVERLAY")
	icon.previewSound:SetTexture("Interface\\Common\\VoiceChat-Speaker")
	icon.previewSound:SetSize(12, 12)
	icon.previewSound:SetPoint("CENTER", icon.previewSoundBorder, "CENTER", 0, 0)
	icon.previewSound:SetAlpha(0.95)

	if not (parent and parent._eqolIsPreview) then
		local group = getMasqueGroup()
		if group then
			local regions = {
				Icon = icon.texture,
				Cooldown = icon.cooldown,
				Normal = icon.msqNormal,
			}
			group:AddButton(icon, regions, "Action", true)
			icon._eqolMasqueAdded = true
			icon._eqolMasqueNeedsReskin = true
		end
	end

	return icon
end

function CooldownPanels.HidePreviewGlowBorder(icon)
	local border = icon and icon.previewGlowBorder
	if border then border:Hide() end
end

function CooldownPanels.UpdatePreviewGlowBorderLayout(icon, rowSize)
	local border = icon and icon.previewGlowBorder
	if not border then return end

	local size = tonumber(rowSize) or 24
	local edgeSize = math.min(6, math.max(2, math.floor((size * 0.08) + 0.5)))
	local offset = math.min(6, math.max(1, math.floor((size * 0.1) + 0.5)))

	if border._eqolEdgeSize ~= edgeSize then
		border:SetBackdrop({
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = edgeSize,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		border:SetBackdropColor(0, 0, 0, 0)
		border._eqolEdgeSize = edgeSize
	end

	if border._eqolOffset ~= offset or border._eqolSize ~= size then
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", icon, "TOPLEFT", -offset, offset)
		border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
		border._eqolOffset = offset
		border._eqolSize = size
	end
end

function CooldownPanels.ShowPreviewGlowBorder(icon, glowColor)
	local border = icon and icon.previewGlowBorder
	if not border then return end

	local fallbackColor = (Helper and Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor) or { 1, 0.82, 0.2, 1 }
	local color = Helper.NormalizeColor(glowColor, fallbackColor)
	CooldownPanels.UpdatePreviewGlowBorderLayout(icon, icon:GetWidth())
	border:SetBackdropBorderColor(color[1] or 1, color[2] or 0.82, color[3] or 0.2, color[4] or 1)
	border:Show()
end

local function ensureIconCount(frame, count)
	frame.icons = frame.icons or {}
	local icons = frame.icons
	local previousCount = tonumber(frame._eqolEnsuredIconCount) or 0
	for i = 1, count do
		if not icons[i] then
			icons[i] = createIconFrame(frame)
			icons[i]:Hide()
		end
	end
	if count < previousCount then
		for i = count + 1, previousCount do
			local icon = icons[i]
			if icon then icon:Hide() end
		end
	end
	frame._eqolEnsuredIconCount = count
end

local ASSISTED_HIGHLIGHT_CONFIG = {
	atlas = "RotationHelper_Ants_Flipbook_2x",
	rows = 6,
	columns = 5,
	frames = 30,
	duration = 1.0,
	scale = 1.45,
	fallbackTexture = "Interface\\Buttons\\UI-ActionButton-Border",
}

local function resizeAssistedHighlight(frame)
	if not frame then return end
	local highlight = frame._eqolAssistedHighlight
	if not (highlight and highlight.Texture) then return end
	local width, height = frame:GetSize()
	if not width or width <= 0 or not height or height <= 0 then return end
	highlight.Texture:SetSize(width * ASSISTED_HIGHLIGHT_CONFIG.scale, height * ASSISTED_HIGHLIGHT_CONFIG.scale)
end

local function ensureAssistedHighlight(frame)
	if not frame then return nil end
	local highlight = frame._eqolAssistedHighlight
	if highlight then
		resizeAssistedHighlight(frame)
		return highlight
	end

	highlight = CreateFrame("Frame", nil, frame.overlay or frame)
	highlight:SetAllPoints(frame)
	highlight:EnableMouse(false)
	highlight:SetFrameStrata((frame.overlay and frame.overlay:GetFrameStrata()) or frame:GetFrameStrata())
	highlight:SetFrameLevel(((frame.overlay and frame.overlay:GetFrameLevel()) or frame:GetFrameLevel()) + 8)

	local tex = highlight:CreateTexture(nil, "OVERLAY")
	tex:SetPoint("CENTER", frame, "CENTER", 0, 0)
	if tex.SetBlendMode then tex:SetBlendMode("ADD") end
	local atlasApplied = tex.SetAtlas and tex:SetAtlas(ASSISTED_HIGHLIGHT_CONFIG.atlas, true)
	if not atlasApplied then
		tex:SetTexture(ASSISTED_HIGHLIGHT_CONFIG.fallbackTexture)
		tex:SetVertexColor(0.35, 0.75, 1, 0.95)
	end
	highlight.Texture = tex
	resizeAssistedHighlight(frame)

	local anim = highlight:CreateAnimationGroup()
	anim:SetLooping("REPEAT")
	anim:SetToFinalAlpha(true)
	highlight.Anim = anim

	local alphaAnim = anim:CreateAnimation("Alpha")
	alphaAnim:SetChildKey("Texture")
	alphaAnim:SetFromAlpha(1)
	alphaAnim:SetToAlpha(1)
	alphaAnim:SetDuration(0.001)
	alphaAnim:SetOrder(0)

	local flipAnim
	if anim.CreateAnimation then
		local ok, created = pcall(anim.CreateAnimation, anim, "FlipBook")
		if ok then flipAnim = created end
	end
	if flipAnim and flipAnim.SetFlipBookRows then
		flipAnim:SetChildKey("Texture")
		flipAnim:SetDuration(ASSISTED_HIGHLIGHT_CONFIG.duration)
		flipAnim:SetOrder(0)
		flipAnim:SetFlipBookRows(ASSISTED_HIGHLIGHT_CONFIG.rows)
		flipAnim:SetFlipBookColumns(ASSISTED_HIGHLIGHT_CONFIG.columns)
		flipAnim:SetFlipBookFrames(ASSISTED_HIGHLIGHT_CONFIG.frames)
		flipAnim:SetFlipBookFrameWidth(0)
		flipAnim:SetFlipBookFrameHeight(0)
		highlight.FlipAnim = flipAnim
	end

	highlight:SetAlpha(0)
	highlight:Show()
	frame._eqolAssistedHighlight = highlight
	return highlight
end

local function setAssistedHighlight(frame, enabled)
	if not frame then return end
	if enabled ~= true then
		frame._eqolAssistedHighlightShown = nil
		local existing = frame._eqolAssistedHighlight
		if existing then
			existing:SetAlpha(0)
			if existing.Anim and existing.Anim.IsPlaying and existing.Anim:IsPlaying() then existing.Anim:Stop() end
		end
		return
	end

	local highlight = ensureAssistedHighlight(frame)
	if not highlight then return end
	resizeAssistedHighlight(frame)
	if frame._eqolAssistedHighlightShown == true then
		highlight:SetAlpha(1)
		if highlight.Anim and highlight.Anim.IsPlaying and not highlight.Anim:IsPlaying() then highlight.Anim:Play() end
		return
	end
	frame._eqolAssistedHighlightShown = true
	highlight:SetAlpha(1)
	if highlight.Anim and highlight.Anim.IsPlaying and not highlight.Anim:IsPlaying() then highlight.Anim:Play() end
end

local function setGlow(frame, enabled, glowColor, glowKey, glowCondition, glowAlphaOn, glowAlphaOff, glowStyle, glowInset)
	if not frame then return end
	glowKey = glowKey or "EQOL_SIMPLE"
	local alphaOn = glowAlphaOn == nil and 1 or glowAlphaOn
	local alphaOff = glowAlphaOff == nil and 0 or glowAlphaOff
	frame._eqolGlowState = frame._eqolGlowState or {}
	local state = frame._eqolGlowState[glowKey]
	if not state then
		state = {}
		frame._eqolGlowState[glowKey] = state
	end
	local wasEnabled = state.enabled == true
	if not enabled then
		if not wasEnabled then return end
		state.enabled = false
		state.color = nil
		state.style = nil
		state.inset = nil
		state.requestedColorR = nil
		state.requestedColorG = nil
		state.requestedColorB = nil
		state.requestedColorA = nil
		state.requestedStyle = nil
		state.requestedInset = nil
		state.condition = nil
		state.alphaOn = nil
		state.alphaOff = nil
		if Glow then Glow.Stop(frame, glowKey) end
		return
	end
	local requestedColorR = glowColor and (glowColor[1] or glowColor.r) or nil
	local requestedColorG = glowColor and (glowColor[2] or glowColor.g) or nil
	local requestedColorB = glowColor and (glowColor[3] or glowColor.b) or nil
	local requestedColorA = glowColor and (glowColor[4] or glowColor.a) or nil
	local issecretvalue = Api and Api.issecretvalue
	local hasSecretCondition = issecretvalue and ((glowCondition ~= nil and issecretvalue(glowCondition)) or (state.condition ~= nil and issecretvalue(state.condition)))
	if
		wasEnabled
		and state.requestedColorR == requestedColorR
		and state.requestedColorG == requestedColorG
		and state.requestedColorB == requestedColorB
		and state.requestedColorA == requestedColorA
		and state.requestedStyle == glowStyle
		and state.requestedInset == glowInset
		and not hasSecretCondition
		and state.condition == glowCondition
		and state.alphaOn == alphaOn
		and state.alphaOff == alphaOff
	then
		return
	end
	local fallbackColor = (Helper and Helper.PANEL_LAYOUT_DEFAULTS and Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor) or { 1, 0.82, 0.2, 1 }
	local normalizedGlowColor = Helper.NormalizeColor(glowColor, fallbackColor)
	local normalizedGlowStyle = Helper.NormalizeGlowStyle(glowStyle, "BLIZZARD")
	local normalizedGlowInset = Helper.NormalizeGlowInset(glowInset, 0)
	local colorChanged = false
	local styleChanged = state.style ~= normalizedGlowStyle
	local insetChanged = state.inset ~= normalizedGlowInset
	local currentGlowColor = state.color
	colorChanged = not currentGlowColor
		or currentGlowColor[1] ~= normalizedGlowColor[1]
		or currentGlowColor[2] ~= normalizedGlowColor[2]
		or currentGlowColor[3] ~= normalizedGlowColor[3]
		or currentGlowColor[4] ~= normalizedGlowColor[4]
	if Glow and (not wasEnabled or colorChanged or styleChanged or insetChanged) then
		Glow.Start(frame, glowKey, normalizedGlowStyle, { color = normalizedGlowColor, cooldown = frame.cooldown, inset = normalizedGlowInset })
	end
	state.enabled = true
	state.style = normalizedGlowStyle
	state.inset = normalizedGlowInset
	state.requestedColorR = requestedColorR
	state.requestedColorG = requestedColorG
	state.requestedColorB = requestedColorB
	state.requestedColorA = requestedColorA
	state.requestedStyle = glowStyle
	state.requestedInset = glowInset
	state.condition = glowCondition
	state.alphaOn = alphaOn
	state.alphaOff = alphaOff
	if normalizedGlowColor then
		state.color = state.color or {}
		state.color[1] = normalizedGlowColor[1]
		state.color[2] = normalizedGlowColor[2]
		state.color[3] = normalizedGlowColor[3]
		state.color[4] = normalizedGlowColor[4]
	else
		state.color = nil
	end
	if Glow then
		if glowCondition ~= nil then
			Glow.SetAlphaFromBoolean(frame, glowKey, glowCondition, alphaOn, alphaOff)
		else
			Glow.SetAlpha(frame, glowKey, alphaOn)
		end
	end
end

function CooldownPanels.StopAllIconGlows(frame)
	if not frame then return end
	frame._eqolGlowState = nil
	if Glow then Glow.StopAll(frame) end
end

function CooldownPanels.GetReadyGlowPrimedState(runtime)
	if type(runtime) ~= "table" then return nil end
	local primed = runtime.readyGlowPrimed or runtime.itemReadyPrimed
	if type(primed) ~= "table" then primed = {} end
	runtime.readyGlowPrimed = primed
	runtime.itemReadyPrimed = primed
	return primed
end

function CooldownPanels.ClearReadyGlowEntryState(panelId, entryId, clearPrimed)
	if not panelId or not entryId then return end
	local runtime = getRuntime(panelId)
	runtime.readyAt = runtime.readyAt or {}
	runtime.glowTimers = runtime.glowTimers or {}
	runtime.readyAt[entryId] = nil
	local timer = runtime.glowTimers[entryId]
	if timer and timer.Cancel then timer:Cancel() end
	runtime.glowTimers[entryId] = nil
	if clearPrimed then
		local primed = CooldownPanels.GetReadyGlowPrimedState(runtime)
		if primed then primed[entryId] = nil end
	end
end

local function triggerReadyGlow(panelId, entryId, glowDuration)
	if not panelId or not entryId then return end
	local runtime = getRuntime(panelId)
	runtime.readyAt = runtime.readyAt or {}
	runtime.glowTimers = runtime.glowTimers or {}
	CooldownPanels.ClearReadyGlowEntryState(panelId, entryId, false)

	local now = Api.GetTime and Api.GetTime() or 0
	runtime.readyAt[entryId] = now
end

local function onCooldownDone(self)
	if not self then return end

	-- Never trigger sound/glow for GCD-only cooldowns.
	local isGCD = self._eqolCooldownIsGCD == true

	if not isGCD then
		-- Sound should only fire once per displayed cooldown.
		if self._eqolSoundReady then
			playSoundName(self._eqolSoundName)
			self._eqolSoundReady = nil
		end

		-- Glow trigger is purely event-driven (robust in secret environments).
		if self._eqolGlowReady then triggerReadyGlow(self._eqolPanelId, self._eqolEntryId, self._eqolGlowDuration) end
	end

	if CooldownPanels and CooldownPanels.RefreshPanel then CooldownPanels:RequestPanelRefresh(self._eqolPanelId) end
	-- if CooldownPanels and CooldownPanels.RequestUpdate then CooldownPanels:RequestUpdate() end
end

local function isSafeNumber(value) return type(value) == "number" and (not Api.issecretvalue or not Api.issecretvalue(value)) end

local function isSafeGreaterThan(value, threshold)
	if not isSafeNumber(value) or not isSafeNumber(threshold) then return false end
	return value > threshold
end

local function isSafeLessThan(a, b)
	if not isSafeNumber(a) or not isSafeNumber(b) then return false end
	return a < b
end

local function isSafeNotFalse(value)
	if Api.issecretvalue and Api.issecretvalue(value) then return true end
	return value ~= false
end

local function isCooldownActive(startTime, duration)
	if not isSafeNumber(startTime) or not isSafeNumber(duration) then return false end
	if duration <= 0 or startTime <= 0 then return false end
	if not Api.GetTime then return false end
	return (startTime + duration) > Api.GetTime()
end

function CooldownPanels.IsSpellCooldownInfoActive(cooldownIsActive, cooldownEnabled, startTime, duration)
	if not (Api.issecretvalue and Api.issecretvalue(cooldownIsActive)) and type(cooldownIsActive) == "boolean" then return cooldownIsActive end
	if not isSafeNotFalse(cooldownEnabled) then return false end
	return isCooldownActive(startTime, duration)
end

function CooldownPanels.IsChargeInfoActive(chargesInfo)
	if type(chargesInfo) ~= "table" then return false end
	if not (Api.issecretvalue and Api.issecretvalue(chargesInfo.isActive)) and type(chargesInfo.isActive) == "boolean" then return chargesInfo.isActive end
	if Api.issecretvalue and (Api.issecretvalue(chargesInfo.currentCharges) or Api.issecretvalue(chargesInfo.maxCharges)) then
		return true
	end
	return isSafeLessThan(chargesInfo.currentCharges, chargesInfo.maxCharges)
end

local function getDurationRemaining(duration)
	if not duration then return nil end
	local remaining = duration.GetRemainingDuration(duration, Api.DurationModifierRealTime)
	if isSafeNumber(remaining) then return remaining end
	return nil
end

local function getSpellCooldownInfo(spellID)
	if not spellID or not Api.GetSpellCooldownInfo then return 0, 0, false, 1, nil, false end
	local a, b, c, d = Api.GetSpellCooldownInfo(spellID)
	if type(a) == "table" then
		local startTime = a.startTime or 0
		local duration = a.duration or 0
		local isEnabled = a.isEnabled
		local isOnGCD = type(a.isOnGCD) == "boolean" and a.isOnGCD or nil
		local isActive = type(a.isActive) == "boolean" and a.isActive or CooldownPanels.IsSpellCooldownInfoActive(nil, isEnabled, startTime, duration)
		return startTime, duration, isEnabled, a.modRate or 1, isOnGCD, isActive
	end
	local startTime = a or 0
	local duration = b or 0
	local isEnabled = c
	return startTime, duration, isEnabled, d or 1, nil, CooldownPanels.IsSpellCooldownInfoActive(nil, isEnabled, startTime, duration)
end

local getSpellCooldownDurationObject

function CooldownPanels:EnsureSpellQueryCaches()
	self.runtime = self.runtime or {}
	local runtime = self.runtime
	runtime.spellCooldownDurationCache = runtime.spellCooldownDurationCache or {}
	runtime.spellCooldownInfoCache = runtime.spellCooldownInfoCache or {}
	runtime.spellChargesInfoCache = runtime.spellChargesInfoCache or {}
	runtime.spellPassStateCache = runtime.spellPassStateCache or {}
	return runtime
end

function CooldownPanels:BeginSpellQueryBatch()
	local runtime = self:EnsureSpellQueryCaches()
	local depth = (runtime.spellQueryBatchDepth or 0) + 1
	runtime.spellQueryBatchDepth = depth
	if depth == 1 then runtime.spellQueryPass = (runtime.spellQueryPass or 0) + 1 end
	return runtime.spellQueryPass
end

function CooldownPanels:EndSpellQueryBatch()
	local runtime = self.runtime
	if not runtime then return end
	local depth = tonumber(runtime.spellQueryBatchDepth) or 0
	if depth <= 1 then
		runtime.spellQueryBatchDepth = nil
	else
		runtime.spellQueryBatchDepth = depth - 1
	end
end

function CooldownPanels:EnsureSpellQueryPass()
	local runtime = self:EnsureSpellQueryCaches()
	if (runtime.spellQueryBatchDepth or 0) <= 0 then runtime.spellQueryPass = (runtime.spellQueryPass or 0) + 1 end
	return runtime.spellQueryPass
end

function CooldownPanels:BeginSpellQueryPass() return self:EnsureSpellQueryPass() end

function CooldownPanels:GetSpellPassState(spellId)
	if not spellId then return nil end
	local runtime = self:EnsureSpellQueryCaches()
	local pass = runtime.spellQueryPass
	if not pass then return nil end
	local cache = runtime.spellPassStateCache
	local state = cache[spellId]
	if state and state.pass == pass then return state end
	state = state or {}
	state.pass = pass
	state.infoLoaded = nil
	state.durationLoaded = nil
	state.chargesLoaded = nil
	state.chargeDurationLoaded = nil
	state.cooldownStart = nil
	state.cooldownDuration = nil
	state.cooldownEnabled = nil
	state.cooldownRate = nil
	state.cooldownGCD = nil
	state.cooldownIsActive = nil
	state.cooldownDurationObject = nil
	state.chargesInfo = nil
	state.chargeDurationObject = nil
	cache[spellId] = state
	return state
end

function CooldownPanels:BeginRuntimeQueryBatch()
	self:BeginSpellQueryBatch()
	local cdmAuras = self.CDMAuras
	if cdmAuras and cdmAuras.BeginRuntimePass then cdmAuras:BeginRuntimePass() end
end

function CooldownPanels:EndRuntimeQueryBatch()
	local cdmAuras = self.CDMAuras
	if cdmAuras and cdmAuras.EndRuntimePass then cdmAuras:EndRuntimePass() end
	self:EndSpellQueryBatch()
end

function CooldownPanels:IsRuntimeQueryBatchActive()
	local runtime = self.runtime
	return runtime and (runtime.spellQueryBatchDepth or 0) > 0 or false
end

function CooldownPanels:InvalidateSpellQueryCaches(kind, spellId)
	local runtime = self.runtime
	if not runtime then return end
	if kind == "duration" or kind == nil then
		if spellId ~= nil then
			runtime.spellCooldownDurationCache = runtime.spellCooldownDurationCache or {}
			runtime.spellCooldownDurationCache[spellId] = nil
		else
			runtime.spellCooldownDurationCache = {}
		end
	end
	if kind == "info" or kind == nil then
		if spellId ~= nil then
			runtime.spellCooldownInfoCache = runtime.spellCooldownInfoCache or {}
			runtime.spellCooldownInfoCache[spellId] = nil
		else
			runtime.spellCooldownInfoCache = {}
		end
	end
	if kind == "charges" or kind == nil then
		if spellId ~= nil then
			runtime.spellChargesInfoCache = runtime.spellChargesInfoCache or {}
			runtime.spellChargesInfoCache[spellId] = nil
		else
			runtime.spellChargesInfoCache = {}
		end
	end
	if kind == "chargeDuration" or kind == nil then
		if spellId ~= nil then
			runtime.spellChargeDurationCache = runtime.spellChargeDurationCache or {}
			runtime.spellChargeDurationCache[spellId] = nil
		else
			runtime.spellChargeDurationCache = {}
		end
	end
	if runtime.spellPassStateCache then
		if spellId ~= nil then
			runtime.spellPassStateCache[spellId] = nil
		elseif kind == nil then
			runtime.spellPassStateCache = {}
		end
	end
end

function CooldownPanels:GetCachedSpellCooldownDurationObject(spellId)
	if not spellId then return nil end
	local runtime = self:EnsureSpellQueryCaches()
	local pass = runtime.spellQueryPass
	if not pass then return getSpellCooldownDurationObject(spellId) end
	local cache = runtime.spellCooldownDurationCache
	local cached = cache[spellId]
	if cached and cached.pass == pass then return cached.value end
	cached = cached or {}
	cache[spellId] = cached
	cached.pass = pass
	cached.value = getSpellCooldownDurationObject(spellId)
	return cached.value
end

function CooldownPanels:GetCachedSpellCooldownInfo(spellId)
	if not spellId then return 0, 0, false, 1, nil, false end
	local runtime = self:EnsureSpellQueryCaches()
	local pass = runtime.spellQueryPass
	if not pass then return getSpellCooldownInfo(spellId) end
	local cache = runtime.spellCooldownInfoCache
	local cached = cache[spellId]
	if cached and cached.pass == pass then return cached.startTime, cached.duration, cached.enabled, cached.modRate, cached.isOnGCD, cached.isActive end
	cached = cached or {}
	cache[spellId] = cached
	cached.pass = pass
	cached.startTime, cached.duration, cached.enabled, cached.modRate, cached.isOnGCD, cached.isActive = getSpellCooldownInfo(spellId)
	return cached.startTime, cached.duration, cached.enabled, cached.modRate, cached.isOnGCD, cached.isActive
end

function CooldownPanels:GetCachedSpellChargesInfo(spellId)
	if not spellId or not Api.GetSpellChargesInfo then return nil end
	local runtime = self:EnsureSpellQueryCaches()
	local pass = runtime.spellQueryPass
	if not pass then return Api.GetSpellChargesInfo(spellId) end
	local cache = runtime.spellChargesInfoCache
	local cached = cache[spellId]
	if cached and cached.pass == pass then return cached.value end
	cached = cached or {}
	cache[spellId] = cached
	cached.pass = pass
	cached.value = Api.GetSpellChargesInfo(spellId)
	return cached.value
end

function CooldownPanels:GetCachedSpellChargeDurationObject(spellId)
	if not spellId or not (C_Spell and C_Spell.GetSpellChargeDuration) then return nil end
	local runtime = self:EnsureSpellQueryCaches()
	local pass = runtime.spellQueryPass
	if not pass then return C_Spell.GetSpellChargeDuration(spellId) end
	local cache = runtime.spellChargeDurationCache
	if not cache then
		cache = {}
		runtime.spellChargeDurationCache = cache
	end
	local cached = cache[spellId]
	if cached and cached.pass == pass then return cached.value end
	cached = cached or {}
	cache[spellId] = cached
	cached.pass = pass
	cached.value = C_Spell.GetSpellChargeDuration(spellId)
	return cached.value
end

local function getItemCooldownInfo(itemID, slotID)
	if slotID and Api.GetInventoryItemCooldown then
		local start, duration, enabled = Api.GetInventoryItemCooldown("player", slotID)
		if start and duration then return start, duration, enabled end
	end
	if not itemID or not Api.GetItemCooldownFn then return 0, 0, false end
	local start, duration, enabled = Api.GetItemCooldownFn(itemID)
	return start or 0, duration or 0, enabled
end

function CooldownPanels:GetItemUseSpellID(itemID)
	if not itemID then return nil end
	self.runtime = self.runtime or {}
	local runtime = self.runtime
	runtime.itemUseSpellCache = runtime.itemUseSpellCache or {}
	local cached = runtime.itemUseSpellCache[itemID]
	if cached ~= nil then return cached or nil end
	if not Api.GetItemSpell then return nil end
	local _, spellId = Api.GetItemSpell(itemID)
	spellId = tonumber(spellId)
	if spellId then runtime.itemUseSpellCache[itemID] = spellId end
	return spellId
end

function CooldownPanels:IsCooldownMatchingGlobalCooldown(cooldownStart, cooldownDuration)
	if not isCooldownActive(cooldownStart, cooldownDuration) then return false end
	local gcdStart, gcdDuration = self:GetCachedSpellCooldownInfo(61304)
	if not isCooldownActive(gcdStart, gcdDuration) then return false end
	return cooldownStart == gcdStart and cooldownDuration == gcdDuration
end

function CooldownPanels:IsItemCooldownOnGCD(itemID, cooldownStart, cooldownDuration)
	if not self:IsCooldownMatchingGlobalCooldown(cooldownStart, cooldownDuration) then return false end
	local spellId = self:GetItemUseSpellID(itemID)
	if not spellId then return false end
	local spellStart, spellDuration = self:GetCachedSpellCooldownInfo(spellId)
	return self:IsCooldownMatchingGlobalCooldown(spellStart, spellDuration)
end

getSpellCooldownDurationObject = function(spellID)
	if not spellID or not Api.GetSpellCooldownDuration then return nil end
	return Api.GetSpellCooldownDuration(spellID)
end

local function hasItem(itemID)
	if not itemID then return false end
	if Api.IsEquippedItem and Api.IsEquippedItem(itemID) then return true end
	local count = Api.GetItemCount(itemID, false, false)
	if count and count > 0 then return true end
	return false
end

local function itemHasUseSpell(itemID) return CooldownPanels.GetItemUseSpellID and CooldownPanels:GetItemUseSpellID(itemID) ~= nil or false end

local function createPanelFrame(panelId, panel)
	local frame = CreateFrame("Button", "EQOL_CooldownPanel" .. tostring(panelId), UIParent)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(false)
	frame.panelId = panelId
	frame.icons = {}
	frame._eqolPanelFrame = true

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.1, 0.6, 0.6, 0.2)
	bg:Hide()
	frame.bg = bg

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("CENTER")
	label:SetText(panel and panel.name or "Cooldown Panel")
	label:Hide()
	frame.label = label

	local editDropZone = CreateFrame("Button", nil, frame)
	editDropZone:SetAllPoints(frame)
	editDropZone:SetFrameLevel(frame:GetFrameLevel())
	editDropZone:EnableMouse(false)
	editDropZone:RegisterForClicks("LeftButtonUp")
	editDropZone:SetScript("OnReceiveDrag", function(self)
		if not (CooldownPanels and CooldownPanels:IsPanelLayoutEditActive(self.panelId)) then return end
		if CooldownPanels:HandleCursorDrop(self.panelId) then
			CooldownPanels:RefreshPanel(self.panelId)
			if CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
		end
	end)
	editDropZone:SetScript("OnMouseUp", function(self, btn)
		if btn ~= "LeftButton" then return end
		if not (CooldownPanels and CooldownPanels:IsPanelLayoutEditActive(self.panelId)) then return end
		if CooldownPanels:HandleCursorDrop(self.panelId) then
			CooldownPanels:RefreshPanel(self.panelId)
			if CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
			return
		end
		CooldownPanels:SelectPanel(self.panelId)
	end)
	editDropZone:Hide()
	editDropZone.panelId = panelId
	frame.editDropZone = editDropZone

	local editGrid = CreateFrame("Frame", nil, frame)
	editGrid:SetAllPoints(frame)
	editGrid:SetFrameLevel((frame:GetFrameLevel() or 0) + 1)
	editGrid:EnableMouse(false)
	editGrid.cells = {}
	editGrid:Hide()
	frame.editGrid = editGrid

	local editMoveHandle = CreateFrame("Button", nil, frame, "BackdropTemplate")
	editMoveHandle:SetSize(72, 16)
	editMoveHandle:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	editMoveHandle:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	editMoveHandle:SetBackdropColor(0, 0, 0, 0.72)
	editMoveHandle:SetBackdropBorderColor(0.95, 0.82, 0.25, 0.95)
	editMoveHandle:RegisterForClicks("LeftButtonUp")
	editMoveHandle:RegisterForDrag("LeftButton")
	editMoveHandle:EnableMouse(false)
	editMoveHandle:Hide()
	editMoveHandle.panelId = panelId
	editMoveHandle.label = editMoveHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	editMoveHandle.label:SetPoint("CENTER")
	editMoveHandle.label:SetText(L["CooldownPanelMoveHandle"] or "Move")
	editMoveHandle.label:SetTextColor(1, 0.86, 0.24, 1)
	editMoveHandle:SetScript("OnMouseDown", function(self, btn)
		if btn ~= "LeftButton" then return end
		CooldownPanels:SelectPanel(self.panelId)
	end)
	editMoveHandle:SetScript("OnClick", function(self) CooldownPanels:SelectPanel(self.panelId) end)
	editMoveHandle:SetScript("OnDragStart", function(self)
		CooldownPanels:SelectPanel(self.panelId)
		CooldownPanels:ProxyEditModeDragStart(self.panelId)
	end)
	editMoveHandle:SetScript("OnDragStop", function(self) CooldownPanels:ProxyEditModeDragStop(self.panelId) end)
	frame.editMoveHandle = editMoveHandle

	local editPanelHandle = CreateFrame("Button", nil, frame, "BackdropTemplate")
	editPanelHandle:SetSize(72, 16)
	editPanelHandle:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	editPanelHandle:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	editPanelHandle:SetBackdropColor(0, 0, 0, 0.72)
	editPanelHandle:SetBackdropBorderColor(0.95, 0.82, 0.25, 0.95)
	editPanelHandle:RegisterForClicks("LeftButtonUp")
	editPanelHandle:RegisterForDrag("LeftButton")
	editPanelHandle:EnableMouse(false)
	editPanelHandle:Hide()
	editPanelHandle.panelId = panelId
	editPanelHandle.label = editPanelHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	editPanelHandle.label:SetPoint("CENTER")
	editPanelHandle.label:SetText(L["CooldownPanelPanelHandle"] or "Panel")
	editPanelHandle.label:SetTextColor(1, 0.86, 0.24, 1)
	editPanelHandle:SetScript("OnMouseDown", function(self, btn)
		if btn ~= "LeftButton" then return end
		self._eqolDragged = nil
		CooldownPanels:SelectPanel(self.panelId)
	end)
	editPanelHandle:SetScript("OnClick", function(self, btn)
		if btn ~= "LeftButton" then return end
		if self._eqolDragged then
			self._eqolDragged = nil
			return
		end
		if not (CooldownPanels and CooldownPanels:IsPanelLayoutEditActive(self.panelId)) then return end
		CooldownPanels:SelectPanel(self.panelId)
		CooldownPanels:OpenLayoutPanelStandaloneMenu(self.panelId, self)
	end)
	editPanelHandle:SetScript("OnDragStart", function(self)
		if not (CooldownPanels and CooldownPanels:IsPanelLayoutEditActive(self.panelId)) then return end
		self._eqolDragged = CooldownPanels:BeginStandalonePanelDrag(self.panelId) and true or nil
		CooldownPanels:SelectPanel(self.panelId)
	end)
	editPanelHandle:SetScript("OnDragStop", function(self)
		if not (CooldownPanels and CooldownPanels:IsPanelLayoutEditActive(self.panelId)) then return end
		CooldownPanels:FinishStandalonePanelDrag(self.panelId)
	end)
	frame.editPanelHandle = editPanelHandle

	frame:RegisterForClicks("LeftButtonUp")
	frame:SetScript("OnReceiveDrag", function(self)
		if not (CooldownPanels and CooldownPanels.IsInEditMode and CooldownPanels:IsInEditMode()) then return end
		if CooldownPanels:HandleCursorDrop(self.panelId) then
			CooldownPanels:RefreshPanel(self.panelId)
			if CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
		end
	end)
	frame:SetScript("OnMouseUp", function(self, btn)
		if btn ~= "LeftButton" then return end
		if not (CooldownPanels and CooldownPanels.IsInEditMode and CooldownPanels:IsInEditMode()) then return end
		if CooldownPanels:HandleCursorDrop(self.panelId) then
			CooldownPanels:RefreshPanel(self.panelId)
			if CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
		end
	end)

	return frame
end

function CooldownPanels.PanelHasUngroupedEntryInRect(panel, column, row, columns, rows)
	if not panel then return false end
	for _, entry in pairs(panel.entries or {}) do
		if entry and Helper.NormalizeFixedGroupId(entry.fixedGroupId) == nil then
			local slotColumn = Helper.NormalizeSlotCoordinate(entry.slotColumn)
			local slotRow = Helper.NormalizeSlotCoordinate(entry.slotRow)
			if CooldownPanels.RectContainsCell(column, row, columns, rows, slotColumn, slotRow) then return true end
		end
	end
	return false
end

function CooldownPanels.ClearFixedGroupDragState(runtime)
	if not runtime then return end
	local frame = runtime.frame
	local grid = frame and frame.editGrid or nil
	if grid and grid:GetScript("OnUpdate") then grid:SetScript("OnUpdate", nil) end
	runtime._eqolFixedGroupDrag = nil
end

function CooldownPanels:GetFixedGroupDragRect(panelId)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	local drag = runtime and runtime._eqolFixedGroupDrag or nil
	if not (panel and drag and Helper.IsFixedLayout(panel.layout)) then return nil end
	local currentColumn = Helper.NormalizeSlotCoordinate(drag.currentColumn or drag.startColumn)
	local currentRow = Helper.NormalizeSlotCoordinate(drag.currentRow or drag.startRow)
	if drag.mode == "create" then
		local startColumn = Helper.NormalizeSlotCoordinate(drag.startColumn)
		local startRow = Helper.NormalizeSlotCoordinate(drag.startRow)
		if not (startColumn and startRow and currentColumn and currentRow) then return nil end
		local column = math.min(startColumn, currentColumn)
		local row = math.min(startRow, currentRow)
		local columns = math.abs(currentColumn - startColumn) + 1
		local rows = math.abs(currentRow - startRow) + 1
		return {
			mode = "create",
			column = column,
			row = row,
			columns = columns,
			rows = rows,
			valid = self:CanCreateFixedGroup(panelId, column, row, columns, rows),
		}
	elseif drag.mode == "move" then
		local group = CooldownPanels.GetFixedGroupById(panel, drag.groupId)
		if not (group and currentColumn and currentRow) then return nil end
		local column = currentColumn - ((drag.anchorColumn or 1) - 1)
		local row = currentRow - ((drag.anchorRow or 1) - 1)
		local gridColumns, gridRows = Helper.GetFixedGridBounds(panel, false)
		local valid = column >= 1
			and row >= 1
			and gridColumns > 0
			and gridRows > 0
			and (column + group.columns - 1) <= gridColumns
			and (row + group.rows - 1) <= gridRows
			and not self:DoesFixedGroupRectOverlap(panel, column, row, group.columns, group.rows, group.id)
		if valid and CooldownPanels.PanelHasUngroupedEntryInRect(panel, column, row, group.columns, group.rows) then valid = false end
		return {
			mode = "move",
			groupId = group.id,
			column = column,
			row = row,
			columns = group.columns,
			rows = group.rows,
			valid = valid,
		}
	end
	return nil
end

function CooldownPanels:CancelFixedGroupDrag(panelId)
	panelId = normalizeId(panelId)
	local runtime = panelId and getRuntime(panelId) or nil
	if not runtime or not runtime._eqolFixedGroupDrag then return false end
	CooldownPanels.ClearFixedGroupDragState(runtime)
	local panel = self:GetPanel(panelId)
	local slotCount = panel and Helper.GetFixedSlotCount(panel, false) or 0
	self:UpdateLayoutEditGrid(panelId, slotCount)
	return true
end

function CooldownPanels:EnableFixedGroupDragTracking(panelId)
	panelId = normalizeId(panelId)
	local runtime = panelId and getRuntime(panelId) or nil
	local frame = runtime and runtime.frame or nil
	local grid = frame and frame.editGrid or nil
	if not (runtime and grid) then return false end
	grid:SetScript("OnUpdate", function()
		local activeRuntime = getRuntime(panelId)
		if not (activeRuntime and activeRuntime._eqolFixedGroupDrag) then
			grid:SetScript("OnUpdate", nil)
			return
		end
		local targetSlot = CooldownPanels:GetLayoutEditCursorSlot(panelId)
		if targetSlot then CooldownPanels:UpdateFixedGroupDragTarget(panelId, targetSlot.column, targetSlot.row) end
	end)
	return true
end

function CooldownPanels:StartFixedGroupDraw(panelId, column, row)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and runtime and column and row and Helper.IsFixedLayout(panel.layout)) then return false end
	runtime._eqolFixedGroupDrag = {
		mode = "create",
		startColumn = column,
		startRow = row,
		currentColumn = column,
		currentRow = row,
	}
	self:EnableFixedGroupDragTracking(panelId)
	self:UpdateLayoutEditGrid(panelId, Helper.GetFixedSlotCount(panel, false))
	return true
end

function CooldownPanels:StartFixedGroupMove(panelId, groupId, column, row)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not (panel and runtime and group and column and row and Helper.IsFixedLayout(panel.layout)) then return false end
	local anchorColumn = math.max(1, math.min(group.columns, column - group.column + 1))
	local anchorRow = math.max(1, math.min(group.rows, row - group.row + 1))
	runtime._eqolFixedGroupDrag = {
		mode = "move",
		groupId = group.id,
		startColumn = column,
		startRow = row,
		currentColumn = column,
		currentRow = row,
		anchorColumn = anchorColumn,
		anchorRow = anchorRow,
	}
	self:EnableFixedGroupDragTracking(panelId)
	self:UpdateLayoutEditGrid(panelId, Helper.GetFixedSlotCount(panel, false))
	return true
end

function CooldownPanels:InvalidateLayoutEditGrid(panelId)
	panelId = normalizeId(panelId)
	local runtime = panelId and getRuntime(panelId) or nil
	if not runtime then return end
	runtime._eqolLayoutEditGridCount = nil
	runtime._eqolLayoutEditGridActive = nil
	runtime._eqolLayoutEditGridDirty = true
end

function CooldownPanels:UpdateFixedGroupDragTarget(panelId, column, row)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	local drag = runtime and runtime._eqolFixedGroupDrag or nil
	column = Helper.NormalizeSlotCoordinate(column)
	row = Helper.NormalizeSlotCoordinate(row)
	if not (panel and drag and column and row) then return false end
	if drag.currentColumn == column and drag.currentRow == row then return false end
	drag.currentColumn = column
	drag.currentRow = row
	self:UpdateLayoutEditGrid(panelId, Helper.GetFixedSlotCount(panel, false))
	return true
end

function CooldownPanels:FinishFixedGroupDrag(panelId)
	panelId = normalizeId(panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local runtime = panelId and getRuntime(panelId) or nil
	local drag = runtime and runtime._eqolFixedGroupDrag or nil
	if not (panel and runtime and drag) then return false end
	local rect = self:GetFixedGroupDragRect(panelId)
	CooldownPanels.ClearFixedGroupDragState(runtime)
	self:UpdateLayoutEditGrid(panelId, Helper.GetFixedSlotCount(panel, false))
	if not (rect and rect.valid) then return false end
	if drag.mode == "create" then
		local groupId = self:CreateFixedGroup(panelId, rect.column, rect.row, rect.columns, rect.rows)
		if groupId then
			clearRuntimeLayoutShapeCache(runtime)
			self:RefreshPanelForCurrentEditContext(panelId, true)
			return true
		end
	elseif drag.mode == "move" then
		local moved, reason = self:MoveFixedGroup(panelId, drag.groupId, rect.column, rect.row)
		if moved then
			clearRuntimeLayoutShapeCache(runtime)
			self:RefreshPanelForCurrentEditContext(panelId, true)
			return true
		end
	end
	return false
end

function CooldownPanels:UpdateLayoutEditGrid(panelId, slotCount)
	local runtime = getRuntime(panelId)
	local frame = runtime and runtime.frame
	local panel = self:GetPanel(panelId)
	local grid = frame and frame.editGrid
	local showGrid = grid and panel and self:IsPanelLayoutEditActive(panelId) and Helper.IsFixedLayout(panel.layout)
	if not grid then return end
	slotCount = tonumber(slotCount) or 0
	if not showGrid or slotCount < 1 then
		grid:Hide()
		for i = 1, #(grid.cells or {}) do
			local cell = grid.cells[i]
			if cell then cell:Hide() end
		end
		return
	end
	grid:Show()
	grid.cells = grid.cells or {}
	local fixedLayoutCache = Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	local gridColumns = fixedLayoutCache and fixedLayoutCache.boundsColumns or select(1, Helper.GetFixedGridBounds(panel, false))
	local groups = CooldownPanels.GetFixedGroups(panel)
	for i = 1, slotCount do
		local icon = frame.icons and frame.icons[i]
		local cell = grid.cells[i]
		if not cell then
			cell = CreateFrame("Frame", nil, grid, "BackdropTemplate")
			cell:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Buttons\\WHITE8x8",
				edgeSize = 1,
			})
			cell:SetBackdropColor(0.08, 0.2, 0.24, 0.08)
			cell:SetBackdropBorderColor(1, 1, 1, 0.14)
			cell:EnableMouse(false)
			grid.cells[i] = cell
		end
		if icon then
			local cellAnchor = icon.slotAnchor or icon
			local cellColumn = gridColumns and gridColumns > 0 and (((i - 1) % gridColumns) + 1) or i
			local cellRow = gridColumns and gridColumns > 0 and (math.floor((i - 1) / gridColumns) + 1) or 1
			local group = CooldownPanels.GetFixedGroupAtCell(panel, cellColumn, cellRow)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", cellAnchor, "TOPLEFT", 0, 0)
			cell:SetPoint("BOTTOMRIGHT", cellAnchor, "BOTTOMRIGHT", 0, 0)
			cell._eqolLayoutSlotColumn = cellColumn
			cell._eqolLayoutSlotRow = cellRow
			if group then
				if CooldownPanels.IsFixedGroupStatic(group) then
					cell:SetBackdropColor(0.15, 0.22, 0.34, 0.18)
					cell:SetBackdropBorderColor(0.42, 0.62, 0.92, 0.32)
				else
					cell:SetBackdropColor(0.18, 0.28, 0.34, 0.16)
					cell:SetBackdropBorderColor(0.8, 0.68, 0.22, 0.28)
				end
			else
				cell:SetBackdropColor(0.08, 0.2, 0.24, 0.08)
				cell:SetBackdropBorderColor(1, 1, 1, 0.14)
			end
			cell:Show()
		else
			cell._eqolLayoutSlotColumn = nil
			cell._eqolLayoutSlotRow = nil
			cell:Hide()
		end
	end
	for i = slotCount + 1, #grid.cells do
		local cell = grid.cells[i]
		if cell then
			cell._eqolLayoutSlotColumn = nil
			cell._eqolLayoutSlotRow = nil
			cell:Hide()
		end
	end

	grid.groupOverlays = grid.groupOverlays or {}
	for i = 1, #groups do
		local group = groups[i]
		local overlay = grid.groupOverlays[i]
		if not overlay then
			overlay = CreateFrame("Frame", nil, grid, "BackdropTemplate")
			overlay:SetBackdrop({
				bgFile = "Interface\\Buttons\\WHITE8x8",
				edgeFile = "Interface\\Buttons\\WHITE8x8",
				edgeSize = 1,
			})
			overlay:SetBackdropColor(0.85, 0.72, 0.22, 0.06)
			overlay:SetBackdropBorderColor(0.9, 0.78, 0.24, 0.55)
			overlay:EnableMouse(false)
			overlay.label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			overlay.label:SetPoint("TOPLEFT", overlay, "TOPLEFT", 4, -3)
			overlay.label:SetTextColor(1, 0.88, 0.34, 0.9)
			grid.groupOverlays[i] = overlay
		end
		local startIndex = CooldownPanels.GetFixedGridCellIndex(panel, group.column, group.row)
		local endIndex = CooldownPanels.GetFixedGridCellIndex(panel, group.column + group.columns - 1, group.row + group.rows - 1)
		local startIcon = startIndex and frame.icons and frame.icons[startIndex] or nil
		local endIcon = endIndex and frame.icons and frame.icons[endIndex] or nil
		if startIcon and endIcon then
			local startAnchor = startIcon.slotAnchor or startIcon
			local endAnchor = endIcon.slotAnchor or endIcon
			overlay:ClearAllPoints()
			overlay:SetPoint("TOPLEFT", startAnchor, "TOPLEFT", 1, -1)
			overlay:SetPoint("BOTTOMRIGHT", endAnchor, "BOTTOMRIGHT", -1, 1)
			if CooldownPanels.IsFixedGroupStatic(group) then
				overlay:SetBackdropColor(0.35, 0.52, 0.92, 0.08)
				overlay:SetBackdropBorderColor(0.45, 0.64, 0.95, 0.55)
				overlay.label:SetTextColor(0.78, 0.86, 1, 0.95)
			else
				overlay:SetBackdropColor(0.85, 0.72, 0.22, 0.06)
				overlay:SetBackdropBorderColor(0.9, 0.78, 0.24, 0.55)
				overlay.label:SetTextColor(1, 0.88, 0.34, 0.9)
			end
			overlay.label:SetText(CooldownPanels.GetFixedGroupDisplayLabel(group))
			overlay:Show()
		else
			overlay:Hide()
		end
	end
	for i = #groups + 1, #(grid.groupOverlays or {}) do
		local overlay = grid.groupOverlays[i]
		if overlay then overlay:Hide() end
	end

	if not grid.selectionOverlay then
		local overlay = CreateFrame("Frame", nil, grid, "BackdropTemplate")
		overlay:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		overlay:EnableMouse(false)
		overlay:Hide()
		grid.selectionOverlay = overlay
	end
	local dragRect = CooldownPanels:GetFixedGroupDragRect(panelId)
	if dragRect then
		local startIndex = CooldownPanels.GetFixedGridCellIndex(panel, dragRect.column, dragRect.row)
		local endIndex = CooldownPanels.GetFixedGridCellIndex(panel, dragRect.column + dragRect.columns - 1, dragRect.row + dragRect.rows - 1)
		local startIcon = startIndex and frame.icons and frame.icons[startIndex] or nil
		local endIcon = endIndex and frame.icons and frame.icons[endIndex] or nil
		if startIcon and endIcon then
			local startAnchor = startIcon.slotAnchor or startIcon
			local endAnchor = endIcon.slotAnchor or endIcon
			grid.selectionOverlay:ClearAllPoints()
			grid.selectionOverlay:SetPoint("TOPLEFT", startAnchor, "TOPLEFT", 1, -1)
			grid.selectionOverlay:SetPoint("BOTTOMRIGHT", endAnchor, "BOTTOMRIGHT", -1, 1)
			if dragRect.valid then
				grid.selectionOverlay:SetBackdropColor(0.2, 0.7, 0.3, 0.14)
				grid.selectionOverlay:SetBackdropBorderColor(0.2, 0.85, 0.35, 0.9)
			else
				grid.selectionOverlay:SetBackdropColor(0.8, 0.15, 0.15, 0.12)
				grid.selectionOverlay:SetBackdropBorderColor(0.9, 0.2, 0.2, 0.9)
			end
			grid.selectionOverlay:Show()
		else
			grid.selectionOverlay:Hide()
		end
	else
		grid.selectionOverlay:Hide()
	end
end

local function getGridDimensions(count, wrapCount, primaryHorizontal)
	if count < 1 then count = 1 end
	if wrapCount and wrapCount > 0 then
		if primaryHorizontal then
			local cols = math.min(count, wrapCount)
			local rows = math.floor((count + wrapCount - 1) / wrapCount)
			return cols, rows
		end
		local rows = math.min(count, wrapCount)
		local cols = math.floor((count + wrapCount - 1) / wrapCount)
		return cols, rows
	end
	if primaryHorizontal then return count, 1 end
	return 1, count
end

local function getPanelRowCount(panel, layout)
	if not panel or not layout then return 1, true end
	local count
	if Helper.IsFixedLayout(layout) then
		local _, rows = Helper.GetFixedGridBounds(panel, false)
		return rows > 0 and rows or 1, true
	else
		count = panel.order and #panel.order or 0
	end
	if count < 1 then count = 1 end
	local wrapCount = Helper.ClampInt(layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
	local direction = Helper.NormalizeDirection(layout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction)
	local primaryHorizontal = direction == "LEFT" or direction == "RIGHT"
	local _, rows = getGridDimensions(count, wrapCount, primaryHorizontal)
	return rows, primaryHorizontal
end

local function containsId(list, id)
	if type(list) ~= "table" then return false end
	for _, value in ipairs(list) do
		if value == id then return true end
	end
	return false
end

local function setCooldownDrawState(cooldown, drawEdge, drawBling, drawSwipe)
	if not cooldown then return end
	if cooldown.SetDrawEdge and cooldown._eqolDrawEdge ~= drawEdge then
		cooldown:SetDrawEdge(drawEdge)
		cooldown._eqolDrawEdge = drawEdge
	end
	if cooldown.SetDrawBling and cooldown._eqolDrawBling ~= drawBling then
		cooldown:SetDrawBling(drawBling)
		cooldown._eqolDrawBling = drawBling
	end
	if cooldown.SetDrawSwipe and cooldown._eqolDrawSwipe ~= drawSwipe then
		cooldown:SetDrawSwipe(drawSwipe)
		cooldown._eqolDrawSwipe = drawSwipe
	end
end

local function applyIconBorder(icon, layout)
	if not icon or not icon.border then return end
	local border = icon.border
	local defaults = Helper.PANEL_LAYOUT_DEFAULTS
	local enabled = layout and layout.iconBorderEnabled == true
	if not enabled then
		border:Hide()
		return
	end

	local edgeSize = Helper.ClampInt(layout.iconBorderSize, 1, 64, defaults.iconBorderSize or 1)
	local offset = Helper.ClampInt(layout.iconBorderOffset, -64, 64, defaults.iconBorderOffset or 0)
	local textureKey = normalizeIconBorderTexture(layout.iconBorderTexture, defaults.iconBorderTexture)
	local edgeFile = resolveIconBorderTexture(textureKey)
	local color = Helper.NormalizeColor(layout.iconBorderColor, defaults.iconBorderColor)

	if border._eqolBorderEdgeFile ~= edgeFile or border._eqolBorderEdgeSize ~= edgeSize then
		border:SetBackdrop({
			edgeFile = edgeFile,
			edgeSize = edgeSize,
			insets = { left = 0, right = 0, top = 0, bottom = 0 },
		})
		border:SetBackdropColor(0, 0, 0, 0)
		border._eqolBorderEdgeFile = edgeFile
		border._eqolBorderEdgeSize = edgeSize
	end

	if border._eqolBorderOffset ~= offset then
		border:ClearAllPoints()
		border:SetPoint("TOPLEFT", icon, "TOPLEFT", -offset, offset)
		border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", offset, -offset)
		border._eqolBorderOffset = offset
	end

	border:SetBackdropBorderColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
	border:Show()
end

local function applyIconLayout(frame, count, layout)
	if not frame then return end
	local iconSize = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
	local spacing = Helper.ClampInt(layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS.spacing)
	local layoutMode = Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode)
	local direction = Helper.NormalizeDirection(layout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction)
	local wrapCount = Helper.ClampInt(layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
	local wrapDirection = Helper.NormalizeDirection(layout.wrapDirection, Helper.PANEL_LAYOUT_DEFAULTS.wrapDirection or "DOWN")
	local growthPoint = Helper.NormalizeGrowthPoint(layout.growthPoint, Helper.PANEL_LAYOUT_DEFAULTS.growthPoint)
	local primaryHorizontal = direction == "LEFT" or direction == "RIGHT"
	local stackAnchor = Helper.NormalizeAnchor(layout.stackAnchor, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor)
	local stackX = Helper.ClampInt(layout.stackX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.stackX)
	local stackY = Helper.ClampInt(layout.stackY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.stackY)
	local chargesAnchor = Helper.NormalizeAnchor(layout.chargesAnchor, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor)
	local chargesX = Helper.ClampInt(layout.chargesX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.chargesX)
	local chargesY = Helper.ClampInt(layout.chargesY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.chargesY)
	local keybindAnchor = Helper.NormalizeAnchor(layout.keybindAnchor, Helper.PANEL_LAYOUT_DEFAULTS.keybindAnchor)
	local keybindX = Helper.ClampInt(layout.keybindX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.keybindX)
	local keybindY = Helper.ClampInt(layout.keybindY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.keybindY)
	local drawEdge = layout.cooldownDrawEdge ~= false
	local drawBling = layout.cooldownDrawBling ~= false
	local drawSwipe = layout.cooldownDrawSwipe ~= false
	local cooldownTextFont = layout.cooldownTextFont
	local cooldownTextSize = layout.cooldownTextSize
	local cooldownTextStyle = layout.cooldownTextStyle
	local cooldownTextColor = Helper.NormalizeColor(layout.cooldownTextColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)
	local cooldownTextX = Helper.ClampInt(layout.cooldownTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
	local cooldownTextY = Helper.ClampInt(layout.cooldownTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)

	local cols, rows = 1, 1
	local baseIconSize = iconSize
	local rowSizes = {}
	local rowOffsets = {}
	local rowWidths = {}
	local width = 0
	local height = 0
	local radialRadius = nil
	local radialRotation = nil
	local radialArcDegrees = nil
	local radialStep = nil
	local radialBaseAngle = nil

	if layoutMode == "RADIAL" then
		radialRadius = Helper.ClampInt(layout.radialRadius, 0, Helper.RADIAL_RADIUS_RANGE or 600, Helper.PANEL_LAYOUT_DEFAULTS.radialRadius)
		radialRotation = Helper.ClampNumber(layout.radialRotation, -Helper.RADIAL_ROTATION_RANGE, Helper.RADIAL_ROTATION_RANGE, Helper.PANEL_LAYOUT_DEFAULTS.radialRotation)
		radialArcDegrees = Helper.ClampInt(layout.radialArcDegrees, Helper.RADIAL_ARC_DEGREES_MIN or 15, Helper.RADIAL_ARC_DEGREES_MAX or 360, Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360)
		if radialArcDegrees >= (Helper.RADIAL_ARC_DEGREES_MAX or 360) then
			radialStep = count > 0 and ((2 * math.pi) / count) or 0
		else
			radialStep = count > 1 and (math.rad(radialArcDegrees) / (count - 1)) or 0
		end
		radialBaseAngle = (math.pi / 2) - math.rad(radialRotation or 0)
		width = math.max(baseIconSize, radialRadius * 2)
		height = width
	else
		cols, rows = getGridDimensions(count, wrapCount, primaryHorizontal)
		if primaryHorizontal then
			local totalHeight = 0
			for rowIndex = 1, rows do
				local rowSize = baseIconSize
				if type(layout.rowSizes) == "table" then
					local override = tonumber(layout.rowSizes[rowIndex])
					if override then rowSize = Helper.ClampInt(override, 12, 128, baseIconSize) end
				end
				rowSizes[rowIndex] = rowSize
				rowOffsets[rowIndex] = totalHeight
				local rowCols = cols
				if wrapCount and wrapCount > 0 then
					local fillIndex = rowIndex
					if wrapDirection == "UP" then fillIndex = rows - rowIndex + 1 end
					rowCols = math.min(wrapCount, count - ((fillIndex - 1) * wrapCount))
					if rowCols < 1 then rowCols = 1 end
				end
				local rowWidth = (rowCols * rowSize) + ((rowCols - 1) * spacing)
				rowWidths[rowIndex] = rowWidth
				if rowWidth > width then width = rowWidth end
				totalHeight = totalHeight + rowSize + spacing
			end
			if rows > 0 then height = totalHeight - spacing end
		else
			local step = baseIconSize + spacing
			width = (cols * baseIconSize) + ((cols - 1) * spacing)
			height = (rows * baseIconSize) + ((rows - 1) * spacing)
			for rowIndex = 1, rows do
				rowSizes[rowIndex] = baseIconSize
				rowOffsets[rowIndex] = (rowIndex - 1) * step
				rowWidths[rowIndex] = width
			end
		end
	end

	if width <= 0 then width = baseIconSize end
	if height <= 0 then height = baseIconSize end

	frame:SetSize(width, height)
	ensureIconCount(frame, count)
	local fontPath, fontSize, fontStyle = Helper.GetCountFontDefaults(frame)
	local countFontPath = Helper.ResolveFontPath(layout.stackFont, fontPath)
	local countFontSize = Helper.ClampInt(layout.stackFontSize, 6, 64, fontSize or 12)
	local countFontStyle = Helper.NormalizeFontStyle(layout.stackFontStyle, fontStyle)
	local countFontColor = Helper.NormalizeColor(layout.stackColor, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
	local chargesFontPath, chargesFontSize, chargesFontStyle = Helper.GetChargesFontDefaults(frame)
	local chargesPath = Helper.ResolveFontPath(layout.chargesFont, chargesFontPath)
	local chargesSize = Helper.ClampInt(layout.chargesFontSize, 6, 64, chargesFontSize or 12)
	local chargesStyle = Helper.NormalizeFontStyle(layout.chargesFontStyle, chargesFontStyle)
	local chargesFontColor = Helper.NormalizeColor(layout.chargesColor, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
	local keybindFontPath = Helper.ResolveFontPath(layout.keybindFont, countFontPath)
	local keybindFontSize = Helper.ClampInt(layout.keybindFontSize, 6, 64, Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize or math.min(countFontSize, 10))
	local keybindFontStyle = Helper.NormalizeFontStyle(layout.keybindFontStyle, countFontStyle)

	local function getAnchorComponents(point)
		local h = "CENTER"
		if point and point:find("LEFT") then
			h = "LEFT"
		elseif point and point:find("RIGHT") then
			h = "RIGHT"
		end
		local v = "CENTER"
		if point and point:find("TOP") then
			v = "TOP"
		elseif point and point:find("BOTTOM") then
			v = "BOTTOM"
		end
		return h, v
	end
	local function getGrowthOffset(point, gridWidth, gridHeight)
		local h, v = getAnchorComponents(point)
		local x = 0
		if h == "CENTER" then x = -(gridWidth / 2) end
		if h == "RIGHT" then x = -gridWidth end
		local y = 0
		if v == "CENTER" then
			y = (gridHeight / 2)
		elseif v == "BOTTOM" then
			y = gridHeight
		end
		return x, y, h, v
	end
	local growthOffsetX, growthOffsetY, anchorH, anchorV = getGrowthOffset(growthPoint, width, height)

	local function applyIconCommon(icon, rowSize)
		local slotAnchor = icon.slotAnchor or icon
		slotAnchor:SetSize(rowSize, rowSize)
		icon._eqolBaseSlotSize = rowSize
		icon:SetSize(rowSize, rowSize)
		if slotAnchor ~= icon then
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", slotAnchor, "CENTER", 0, 0)
		end
		icon._eqolVisualSize = nil
		icon._eqolVisualAnchor = nil
		icon._eqolVisualOffsetX = nil
		icon._eqolVisualOffsetY = nil
		if icon._eqolMasqueNeedsReskin then
			local group = getMasqueGroup()
			if group and group.ReSkin then group:ReSkin(icon) end
			icon._eqolMasqueNeedsReskin = nil
		end
		applyIconBorder(icon, layout)
		if icon.count then
			icon.count:ClearAllPoints()
			icon.count:SetPoint(stackAnchor, icon, stackAnchor, stackX, stackY)
			icon.count:SetFont(countFontPath, countFontSize, countFontStyle)
			icon.count:SetTextColor(countFontColor[1] or 1, countFontColor[2] or 1, countFontColor[3] or 1, countFontColor[4] or 1)
		end
		if icon.charges then
			icon.charges:ClearAllPoints()
			icon.charges:SetPoint(chargesAnchor, icon, chargesAnchor, chargesX, chargesY)
			icon.charges:SetFont(chargesPath, chargesSize, chargesStyle)
			icon.charges:SetTextColor(chargesFontColor[1] or 1, chargesFontColor[2] or 1, chargesFontColor[3] or 1, chargesFontColor[4] or 1)
		end
		if icon.keybind then
			icon.keybind:ClearAllPoints()
			icon.keybind:SetPoint(keybindAnchor, icon, keybindAnchor, keybindX, keybindY)
			icon.keybind:SetFont(keybindFontPath, keybindFontSize, keybindFontStyle)
		end
		setCooldownDrawState(icon.cooldown, drawEdge, drawBling, drawSwipe)
		if icon.cooldown and icon.cooldown.GetCountdownFontString then
			local fontString = icon.cooldown:GetCountdownFontString()
			if fontString then
				if not icon.cooldown._eqolCooldownTextDefaults then
					local fontPath, fontSize, fontStyle = fontString:GetFont()
					icon.cooldown._eqolCooldownTextDefaults = {
						font = fontPath,
						size = fontSize,
						style = fontStyle,
					}
				end
				local defaults = icon.cooldown._eqolCooldownTextDefaults
				local fontPath = Helper.ResolveFontPath(cooldownTextFont, defaults and defaults.font)
				local fontSize = Helper.ClampInt(cooldownTextSize, 6, 64, defaults and defaults.size or 12)
				local fontStyle = Helper.NormalizeFontStyle(cooldownTextStyle, defaults and defaults.style) or ""
				fontString:SetFont(fontPath, fontSize, fontStyle)
				fontString:ClearAllPoints()
				fontString:SetPoint("CENTER", icon.cooldown, "CENTER", cooldownTextX, cooldownTextY)
				fontString:SetTextColor(cooldownTextColor[1] or 1, cooldownTextColor[2] or 1, cooldownTextColor[3] or 1, cooldownTextColor[4] or 1)
			end
		end
		CooldownPanels.UpdatePreviewGlowBorderLayout(icon, rowSize)
		if icon.previewBling then
			icon.previewBling:ClearAllPoints()
			icon.previewBling:SetPoint("CENTER", icon, "CENTER", 0, 0)
			icon.previewBling:SetSize(rowSize * 1.5, rowSize * 1.5)
		end
		resizeAssistedHighlight(icon)
	end

	if layoutMode == "RADIAL" then
		local centerRadius = (radialRadius or 0) - (baseIconSize / 2)
		if centerRadius < 0 then centerRadius = 0 end
		for i = 1, count do
			local icon = frame.icons[i]
			local slotAnchor = icon.slotAnchor or icon
			applyIconCommon(icon, baseIconSize)
			local x, y = 0, 0
			if count > 1 then
				local angle = radialBaseAngle - ((i - 1) * (radialStep or 0))
				x = math.cos(angle) * centerRadius
				y = math.sin(angle) * centerRadius
			end
			slotAnchor:ClearAllPoints()
			slotAnchor:SetPoint("CENTER", frame, "CENTER", x, y)
			if slotAnchor ~= icon then
				icon:ClearAllPoints()
				icon:SetPoint("CENTER", slotAnchor, "CENTER", 0, 0)
			end
		end
		return
	end

	for i = 1, count do
		local icon = frame.icons[i]
		local slotAnchor = icon.slotAnchor or icon
		local primaryIndex = i - 1
		local secondaryIndex = 0
		if wrapCount and wrapCount > 0 then
			primaryIndex = (i - 1) % wrapCount
			secondaryIndex = math.floor((i - 1) / wrapCount)
		end

		local col, row
		if primaryHorizontal then
			col = primaryIndex
			row = secondaryIndex
		else
			local colCount = wrapCount and wrapCount > 0 and math.min(wrapCount, count - (secondaryIndex * wrapCount)) or count
			local rowOffset = anchorV == "CENTER" and ((rows - colCount) / 2) or 0
			row = primaryIndex + rowOffset
			col = secondaryIndex
		end

		if primaryHorizontal and direction == "LEFT" then
			col = (cols - 1) - col
		elseif (not primaryHorizontal) and direction == "UP" then
			row = (rows - 1) - row
		end

		if primaryHorizontal then
			if wrapDirection == "UP" then row = (rows - 1) - row end
		else
			if wrapDirection == "LEFT" then col = (cols - 1) - col end
		end

		local rowIndex = row + 1
		local rowSize = rowSizes[rowIndex] or baseIconSize
		local rowOffset = rowOffsets[rowIndex] or (row * (baseIconSize + spacing))
		local rowWidth = rowWidths[rowIndex] or width
		local rowAlignOffset = 0
		if primaryHorizontal then
			if anchorH == "CENTER" then
				rowAlignOffset = (width - rowWidth) / 2
			elseif anchorH == "RIGHT" then
				rowAlignOffset = width - rowWidth
			end
		end
		local anchorXAdjust = 0
		if anchorH == "CENTER" then
			anchorXAdjust = rowSize / 2
		elseif anchorH == "RIGHT" then
			anchorXAdjust = rowSize
		end
		local anchorYAdjust = 0
		if anchorV == "CENTER" then
			anchorYAdjust = -(rowSize / 2)
		elseif anchorV == "BOTTOM" then
			anchorYAdjust = -rowSize
		end
		local stepX = primaryHorizontal and (rowSize + spacing) or (baseIconSize + spacing)

		applyIconCommon(icon, rowSize)
		slotAnchor:ClearAllPoints()
		slotAnchor:SetPoint(growthPoint, frame, growthPoint, growthOffsetX + anchorXAdjust + rowAlignOffset + (col * stepX), growthOffsetY + anchorYAdjust - rowOffset)
		if slotAnchor ~= icon then
			icon:ClearAllPoints()
			icon:SetPoint("CENTER", slotAnchor, "CENTER", 0, 0)
		end
	end
end

local function applyPanelBorder(frame)
	local borderLayer, borderSubLevel = "BORDER", 0
	local borderPath = "Interface\\AddOns\\EnhanceQoL\\Assets\\PanelBorder_"
	local cornerSize = 70
	local edgeThickness = 70
	local cornerOffsets = 13

	local function makeTex(key, layer, subLevel)
		local tex = frame:CreateTexture(nil, layer or borderLayer, nil, subLevel or borderSubLevel)
		tex:SetTexture(borderPath .. key .. ".tga")
		tex:SetAlpha(0.95)
		return tex
	end

	local tl = makeTex("tl", borderLayer, borderSubLevel + 1)
	tl:SetSize(cornerSize, cornerSize)
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -cornerOffsets, cornerOffsets)

	local tr = makeTex("tr", borderLayer, borderSubLevel + 1)
	tr:SetSize(cornerSize, cornerSize)
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", cornerOffsets + 8, cornerOffsets)

	local bl = makeTex("bl", borderLayer, borderSubLevel + 1)
	bl:SetSize(cornerSize, cornerSize)
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -cornerOffsets, -cornerOffsets)

	local br = makeTex("br", borderLayer, borderSubLevel + 1)
	br:SetSize(cornerSize, cornerSize)
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", cornerOffsets + 8, -cornerOffsets)

	local top = makeTex("t", borderLayer, borderSubLevel)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
	top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
	top:SetHeight(edgeThickness)
	top:SetHorizTile(true)

	local bottom = makeTex("b", borderLayer, borderSubLevel)
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
	bottom:SetHeight(edgeThickness)
	bottom:SetHorizTile(true)

	local left = makeTex("l", borderLayer, borderSubLevel)
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
	left:SetWidth(edgeThickness)
	left:SetVertTile(true)

	local right = makeTex("r", borderLayer, borderSubLevel)
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
	right:SetWidth(edgeThickness)
	right:SetVertTile(true)
end

local function applyInsetBorder(frame, offset)
	if not frame then return end
	offset = offset or 10

	local layer, subLevel = "BORDER", 2
	local path = "Interface\\AddOns\\EnhanceQoL\\Assets\\border_round_"
	local cornerSize = 36
	local edgeSize = 36

	frame.eqolInsetParts = frame.eqolInsetParts or {}
	local parts = frame.eqolInsetParts

	local function tex(name)
		if not parts[name] then parts[name] = frame:CreateTexture(nil, layer, nil, subLevel) end
		local t = parts[name]
		t:SetAlpha(0.7)
		t:SetTexture(path .. name .. ".tga")
		t:SetDrawLayer(layer, subLevel)
		return t
	end

	local tl = tex("tl")
	tl:SetSize(cornerSize, cornerSize)
	tl:ClearAllPoints()
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -offset)

	local tr = tex("tr")
	tr:SetSize(cornerSize, cornerSize)
	tr:ClearAllPoints()
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -offset, -offset)

	local bl = tex("bl")
	bl:SetSize(cornerSize, cornerSize)
	bl:ClearAllPoints()
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", offset, offset)

	local br = tex("br")
	br:SetSize(cornerSize, cornerSize)
	br:ClearAllPoints()
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -offset, offset)

	local top = tex("t")
	top:ClearAllPoints()
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
	top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
	top:SetHeight(edgeSize)
	top:SetHorizTile(true)

	local bottom = tex("b")
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
	bottom:SetHeight(edgeSize)
	bottom:SetHorizTile(true)

	local left = tex("l")
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
	left:SetWidth(edgeSize)
	left:SetVertTile(true)

	local right = tex("r")
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
	right:SetWidth(edgeSize)
	right:SetVertTile(true)
end

local function showEditorDragIcon(editor, texture)
	if not editor then return end
	if not editor.dragIcon then
		local frame = CreateFrame("Frame", nil, UIParent)
		frame:SetSize(34, 34)
		frame:SetFrameStrata("TOOLTIP")
		frame.texture = frame:CreateTexture(nil, "OVERLAY")
		frame.texture:SetAllPoints()
		editor.dragIcon = frame
	end
	editor.dragIcon.texture:SetTexture(texture or Helper.PREVIEW_ICON)
	editor.dragIcon:SetScript("OnUpdate", function(f)
		local x, y = Api.GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	end)
	editor.dragIcon:Show()
end

local function hideEditorDragIcon(editor)
	if not editor or not editor.dragIcon then return end
	editor.dragIcon:SetScript("OnUpdate", nil)
	editor.dragIcon:Hide()
end

function CooldownPanels:GetCursorPositionOnUIParent()
	if not (Api.GetCursorPosition and UIParent and UIParent.GetEffectiveScale) then return nil, nil end
	local x, y = Api.GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	if not (x and y and scale and scale > 0) then return nil, nil end
	return x / scale, y / scale
end

function CooldownPanels:GetLayoutEntryCandidatesAtCursor(panelId)
	panelId = normalizeId(panelId)
	if not panelId then return nil end
	local cursorX, cursorY = self:GetCursorPositionOnUIParent()
	if not (cursorX and cursorY) then return nil end
	local runtime = getRuntime(panelId)
	local frame = runtime and runtime.frame or nil
	local icons = frame and frame.icons or nil
	if not icons then return nil end

	local candidates = {}
	local seen = {}
	for i = #icons, 1, -1 do
		local icon = icons[i]
		local candidateEntryId = normalizeId(icon and (icon.entryId or (icon.cooldown and icon.cooldown._eqolEntryId)) or nil)
		if candidateEntryId and not seen[candidateEntryId] and icon and icon.IsShown and icon:IsShown() then
			local left = icon.GetLeft and icon:GetLeft() or nil
			local right = icon.GetRight and icon:GetRight() or nil
			local top = icon.GetTop and icon:GetTop() or nil
			local bottom = icon.GetBottom and icon:GetBottom() or nil
			if left and right and top and bottom and cursorX >= left and cursorX <= right and cursorY <= top and cursorY >= bottom then
				candidates[#candidates + 1] = {
					entryId = candidateEntryId,
					icon = icon,
					anchorFrame = (icon.layoutHandle and icon.layoutHandle.IsShown and icon.layoutHandle:IsShown()) and icon.layoutHandle or icon,
					frameLevel = icon.GetFrameLevel and icon:GetFrameLevel() or 0,
					index = i,
				}
				seen[candidateEntryId] = true
			end
		end
	end

	table.sort(candidates, function(a, b)
		if (a.frameLevel or 0) ~= (b.frameLevel or 0) then return (a.frameLevel or 0) > (b.frameLevel or 0) end
		return (a.index or 0) > (b.index or 0)
	end)

	return candidates
end

function CooldownPanels:ShowLayoutEntryChooserMenu(owner, panelId, candidates)
	if not (owner and panelId and candidates and #candidates > 1 and Api.MenuUtil and Api.MenuUtil.CreateContextMenu) then return false end
	local panel = self:GetPanel(panelId)
	if not panel then return false end

	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_LAYOUT_ENTRY_PICKER")
		if rootDescription.SetScrollMode then rootDescription:SetScrollMode(260) end
		rootDescription:CreateTitle("Select entry")
		for _, candidate in ipairs(candidates) do
			local entryId = normalizeId(candidate and candidate.entryId)
			local entry = entryId and panel.entries and panel.entries[entryId] or nil
			if entry then
				local label = CooldownPanels:GetEntryStandaloneTitle(entry)
				local slotColumn = Helper.NormalizeSlotCoordinate(entry.slotColumn)
				local slotRow = Helper.NormalizeSlotCoordinate(entry.slotRow)
				local iconToken = getEntryIcon(entry)
				local iconType = type(iconToken)
				if slotColumn and slotRow then label = string.format("%s [%d,%d]", label, slotColumn, slotRow) end
				if (iconType == "string" and iconToken ~= "") or iconType == "number" then label = string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t %s", tostring(iconToken), label) end
				rootDescription:CreateButton(label, function()
					CooldownPanels:SelectPanel(panelId)
					CooldownPanels:SelectEntry(entryId)
					CooldownPanels:OpenLayoutEntryStandaloneMenu(panelId, entryId, candidate.anchorFrame or candidate.icon or owner)
				end)
			end
		end
	end)

	return true
end

local function showSlotMenu(owner, panelId)
	if not panelId or not Api.MenuUtil or not Api.MenuUtil.CreateContextMenu then return end
	local slotEntries = getSlotMenuEntries()
	local stanceEntries = CooldownPanels.GetStanceMenuEntries and CooldownPanels:GetStanceMenuEntries() or nil
	local cdmAuras = CooldownPanels.CDMAuras
	local hasCDMMenu = cdmAuras and cdmAuras.AppendAddMenu
	if ((not slotEntries) or #slotEntries == 0) and ((not stanceEntries) or #stanceEntries == 0) and not hasCDMMenu then return end
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_ENTRY_ADD")
		rootDescription:CreateTitle(L["CooldownPanelAddSlot"] or "Add more")
		if slotEntries and #slotEntries > 0 then
			local slotMenu = rootDescription:CreateButton(L["CooldownPanelSlotType"] or _G.SLOT or "Slot")
			for _, slot in ipairs(slotEntries) do
				slotMenu:CreateButton(slot.label, function()
					CooldownPanels:AddEntrySafe(panelId, "SLOT", slot.id)
					CooldownPanels:RefreshEditor()
				end)
			end
		end
		if stanceEntries and #stanceEntries > 0 then
			local stanceMenu = rootDescription:CreateButton((CooldownPanels.GetStanceTypeLabel and CooldownPanels:GetStanceTypeLabel()) or (_G.STANCE or "Stance"))
			for _, classData in ipairs(stanceEntries) do
				local classMenu = stanceMenu:CreateButton(classData.label or tostring(classData.classTag or "Class"))
				for _, stance in ipairs(classData.entries or {}) do
					local menuLabel = stance.label or (_G.STEALTH or "Stealth")
					local iconToken = stance.icon
					local iconType = type(iconToken)
					if (iconType == "string" and iconToken ~= "") or iconType == "number" then menuLabel = string.format("|T%s:14:14:0:0:64:64:4:60:4:60|t %s", tostring(iconToken), menuLabel) end
					classMenu:CreateButton(menuLabel, function()
						local overrides = CooldownPanels.GetStanceDefaultOverrides and CooldownPanels:GetStanceDefaultOverrides() or nil
						CooldownPanels:AddEntrySafe(panelId, "STANCE", stance.id, overrides)
						CooldownPanels:RefreshEditor()
					end)
				end
			end
		end
		if hasCDMMenu then cdmAuras:AppendAddMenu(rootDescription, panelId) end
	end)
end

local function getSpellIdFromCooldownManagerChild(child)
	if not child then return nil end
	local spellId
	if type(child.GetSpellID) == "function" then
		local ok, value = pcall(child.GetSpellID, child)
		if ok then spellId = tonumber(value) end
	end
	if not spellId and type(child.GetSpellId) == "function" then
		local ok, value = pcall(child.GetSpellId, child)
		if ok then spellId = tonumber(value) end
	end
	if not spellId and type(child.GetSpell) == "function" then
		local ok, value = pcall(child.GetSpell, child)
		if ok then spellId = tonumber(value) end
	end
	if not spellId and type(child.GetData) == "function" then
		local ok, data = pcall(child.GetData, child)
		if ok and type(data) == "table" then spellId = tonumber(data.spellID or data.spellId or data.spell) end
	end
	if not spellId and type(child) == "table" then spellId = tonumber(child.spellID or child.spellId or child.spell) end
	return spellId
end

local ensureImportCDMPopup

local function getCooldownManagerSourceLabel(sourceKind)
	local cdmAuras = CooldownPanels.CDMAuras
	if cdmAuras and cdmAuras.GetImportSourceLabel then
		local label = cdmAuras:GetImportSourceLabel(sourceKind)
		if label then return label end
	end
	if sourceKind == "UTILITY" then return L["CooldownPanelImportCDMUtility"] or "Utility Cooldowns" end
	return L["CooldownPanelImportCDMEssential"] or COOLDOWN_VIEWER_SETTINGS_CATEGORY_ESSENTIAL
end

local function getCooldownManagerLayoutChildren(sourceKind)
	local viewerName = sourceKind == "UTILITY" and "UtilityCooldownViewer" or "EssentialCooldownViewer"
	local sourceLabel = getCooldownManagerSourceLabel(sourceKind)
	local viewer = _G[viewerName]
	if type(viewer) ~= "table" then return nil, sourceLabel, "SOURCE_NOT_FOUND" end
	local containers = {
		viewer.oldGridSettings,
		viewer.gridSettings,
		viewer.currentGridSettings,
		viewer.settings,
		viewer,
	}
	for i = 1, #containers do
		local container = containers[i]
		local layoutChildren = container and container.layoutChildren
		if type(layoutChildren) == "table" then return layoutChildren, sourceLabel end
	end
	return nil, sourceLabel, "SOURCE_NOT_FOUND"
end

local function importCooldownManagerSpells(panelId, sourceKind)
	panelId = normalizeId(panelId)
	local panel = CooldownPanels:GetPanel(panelId)
	if not panel then return nil, "PANEL_NOT_FOUND" end
	local layoutChildren, sourceLabel, sourceErr = getCooldownManagerLayoutChildren(sourceKind)
	if sourceErr then return nil, sourceErr, sourceLabel end
	local root = ensureRoot()
	if not root then return nil, "NO_DB" end
	panel.entries = panel.entries or {}
	panel.order = panel.order or {}

	local existingBySpellId = {}
	for _, entry in pairs(panel.entries) do
		if entry and entry.type == "SPELL" and entry.spellID then
			local canonicalSpellID = CooldownPanels:GetCanonicalSpellVariantID(entry.spellID) or tonumber(entry.spellID)
			if canonicalSpellID then existingBySpellId[canonicalSpellID] = true end
		end
	end

	local function importChild(child, stats)
		local spellId = getSpellIdFromCooldownManagerChild(child)
		if not spellId then
			stats.invalid = stats.invalid + 1
			return
		end
		local baseSpellId = getBaseSpellId(spellId) or spellId
		if not spellExistsSafe(baseSpellId) then
			stats.invalid = stats.invalid + 1
			return
		end
		local resolvedSpellId = CooldownPanels:ResolveKnownSpellVariantID(baseSpellId) or baseSpellId
		local canonicalSpellID = CooldownPanels:GetCanonicalSpellVariantID(resolvedSpellId) or resolvedSpellId
		if existingBySpellId[canonicalSpellID] then
			stats.duplicates = stats.duplicates + 1
			return
		end
		if CooldownPanels:GetFixedEntryAddError(panel, nil) then
			stats.invalid = stats.invalid + 1
			return
		end
		local entryId = Helper.GetNextNumericId(panel.entries)
		local entry = Helper.CreateEntry("SPELL", resolvedSpellId, root.defaults)
		entry.id = entryId
		panel.entries[entryId] = entry
		panel.order[#panel.order + 1] = entryId
		existingBySpellId[canonicalSpellID] = true
		stats.added = stats.added + 1
	end

	local stats = { added = 0, duplicates = 0, invalid = 0, seen = 0 }
	if #layoutChildren > 0 then
		for i = 1, #layoutChildren do
			stats.seen = stats.seen + 1
			importChild(layoutChildren[i], stats)
		end
	else
		local numericKeys = {}
		for key in pairs(layoutChildren) do
			if type(key) == "number" then numericKeys[#numericKeys + 1] = key end
		end
		table.sort(numericKeys)
		for _, key in ipairs(numericKeys) do
			stats.seen = stats.seen + 1
			importChild(layoutChildren[key], stats)
		end
	end

	if stats.added > 0 then
		Helper.SyncOrder(panel.order, panel.entries)
		CooldownPanels:RebuildSpellIndex()
		CooldownPanels:RefreshPanel(panelId)
	end
	stats.sourceLabel = sourceLabel
	return stats
end

local function showImportCDMMenu(owner, panelId)
	if not panelId or not Api.MenuUtil or not Api.MenuUtil.CreateContextMenu then return end
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_IMPORT_CDM")
		rootDescription:CreateTitle(L["CooldownPanelImportCDMMenuTitle"] or "Import from Cooldown Manager")
		rootDescription:CreateButton(getCooldownManagerSourceLabel("ESSENTIAL"), function()
			ensureImportCDMPopup()
			StaticPopup_Show("EQOL_COOLDOWN_PANEL_IMPORT_CDM", getCooldownManagerSourceLabel("ESSENTIAL"), nil, {
				panelId = panelId,
				sourceKind = "ESSENTIAL",
				sourceLabel = getCooldownManagerSourceLabel("ESSENTIAL"),
			})
		end)
		rootDescription:CreateButton(getCooldownManagerSourceLabel("UTILITY"), function()
			ensureImportCDMPopup()
			StaticPopup_Show("EQOL_COOLDOWN_PANEL_IMPORT_CDM", getCooldownManagerSourceLabel("UTILITY"), nil, {
				panelId = panelId,
				sourceKind = "UTILITY",
				sourceLabel = getCooldownManagerSourceLabel("UTILITY"),
			})
		end)
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.ImportEntries then
			rootDescription:CreateButton(getCooldownManagerSourceLabel("BUFF_ICON"), function()
				ensureImportCDMPopup()
				StaticPopup_Show("EQOL_COOLDOWN_PANEL_IMPORT_CDM", getCooldownManagerSourceLabel("BUFF_ICON"), nil, {
					panelId = panelId,
					sourceKind = "BUFF_ICON",
					sourceLabel = getCooldownManagerSourceLabel("BUFF_ICON"),
				})
			end)
			rootDescription:CreateButton(getCooldownManagerSourceLabel("BUFF_BAR"), function()
				ensureImportCDMPopup()
				StaticPopup_Show("EQOL_COOLDOWN_PANEL_IMPORT_CDM", getCooldownManagerSourceLabel("BUFF_BAR"), nil, {
					panelId = panelId,
					sourceKind = "BUFF_BAR",
					sourceLabel = getCooldownManagerSourceLabel("BUFF_BAR"),
				})
			end)
		end
	end)
end

local function showSpecMenu(owner, panelId)
	if not panelId or not Api.MenuUtil or not Api.MenuUtil.CreateContextMenu then return end
	local panel = CooldownPanels:GetPanel(panelId)
	if not panel then return end
	local classMenuData = getClassSpecMenuData()
	local quickFilterDefinitions = CooldownPanels:GetSpecQuickFilterDefinitions(classMenuData)
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_SPECS")
		rootDescription:CreateTitle(L["CooldownPanelSpecFilter"] or "Show only for spec")
		rootDescription:CreateCheckbox(L["CooldownPanelSpecAny"] or "All specs", function() return not panelHasSpecFilter(panel) end, function()
			panel.specFilter = {}
			CooldownPanels:CommitPanelSpecFilter(panelId)
		end)

		local hasQuickFilters = false
		for _, quickFilter in ipairs(quickFilterDefinitions or {}) do
			if type(quickFilter.specIds) == "table" and #quickFilter.specIds > 0 then
				hasQuickFilters = true
				break
			end
		end
		if hasQuickFilters then
			rootDescription:CreateDivider()
			rootDescription:CreateTitle(L["CooldownPanelSpecQuickSelect"] or "Quick select")
			for _, quickFilter in ipairs(quickFilterDefinitions or {}) do
				if type(quickFilter.specIds) == "table" and #quickFilter.specIds > 0 then
					rootDescription:CreateCheckbox(quickFilter.label, function() return CooldownPanels:HasAllPanelSpecFilterEntries(panel, quickFilter.specIds) end, function()
						local enable = not CooldownPanels:HasAllPanelSpecFilterEntries(panel, quickFilter.specIds)
						if CooldownPanels:SetPanelSpecFilterEntries(panel, quickFilter.specIds, enable) then CooldownPanels:CommitPanelSpecFilter(panelId) end
					end)
				end
			end
			rootDescription:CreateDivider()
		end

		for _, classData in ipairs(classMenuData) do
			local classMenu = rootDescription:CreateButton(classData.name)
			for _, specData in ipairs(classData.specs or {}) do
				classMenu:CreateCheckbox(specData.name, function() return panel.specFilter and panel.specFilter[specData.id] == true end, function()
					panel.specFilter = panel.specFilter or {}
					if panel.specFilter[specData.id] then
						panel.specFilter[specData.id] = nil
					else
						panel.specFilter[specData.id] = true
					end
					CooldownPanels:CommitPanelSpecFilter(panelId)
				end)
			end
		end
	end)
end

local function showPanelFilterMenu(owner)
	if not Api.MenuUtil or not Api.MenuUtil.CreateContextMenu then return end
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_FILTERS")
		rootDescription:CreateTitle(L["CooldownPanelPanelFilters"] or "Panel filters")
		rootDescription:CreateCheckbox(L["CooldownPanelOnlyMyClass"] or "Only show Panels of my Class", function() return addon.db and addon.db.cooldownPanelsFilterClass == true end, function()
			if addon.db then addon.db.cooldownPanelsFilterClass = addon.db.cooldownPanelsFilterClass ~= true end
			CooldownPanels:RefreshEditor()
		end)
		rootDescription:CreateCheckbox(L["CooldownPanelHideEmptyGroups"] or "Hide empty groups", function() return addon.db and addon.db.cooldownPanelsHideEmptyGroups == true end, function()
			if addon.db then addon.db.cooldownPanelsHideEmptyGroups = addon.db.cooldownPanelsHideEmptyGroups ~= true end
			CooldownPanels:RefreshEditor()
		end)
	end)
end

local function showSoundMenu(owner, panelId, entryId)
	if not panelId or not entryId or not Api.MenuUtil or not Api.MenuUtil.CreateContextMenu then return end
	local panel = CooldownPanels:GetPanel(panelId)
	local entry = panel and panel.entries and panel.entries[entryId]
	if not entry then return end
	local _, _, soundField, title = CooldownPanels:GetEntrySoundConfig(entry)
	if not soundField then return end
	local options = getSoundOptions()
	if not options or #options == 0 then return end
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:SetTag("MENU_EQOL_COOLDOWN_PANEL_SOUND")
		if rootDescription.SetScrollMode then rootDescription:SetScrollMode(260) end
		rootDescription:CreateTitle(title or (L["CooldownPanelSoundReady"] or "Sound when ready"))
		for _, soundName in ipairs(options) do
			local label = getSoundLabel(soundName)
			rootDescription:CreateRadio(label, function() return normalizeSoundName(entry[soundField]) == soundName end, function()
				entry[soundField] = soundName
				playSoundName(soundName)
				CooldownPanels:RefreshPanel(panelId)
				CooldownPanels:RefreshEditor()
			end)
		end
	end)
end

function CooldownPanels:GetLayoutEntryStandaloneMenuState(create)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local state = CooldownPanels.runtime.layoutEntryStandaloneMenu
	if state == nil and create ~= false then
		state = {}
		CooldownPanels.runtime.layoutEntryStandaloneMenu = state
	end
	return state
end

function CooldownPanels:ClearLayoutEntryStandaloneMenuState()
	local state = self:GetLayoutEntryStandaloneMenuState(false)
	if not state then return end
	for key in pairs(state) do
		state[key] = nil
	end
end

function CooldownPanels:GetLayoutEntryStandaloneDialogEntry(panelId, entryId)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel = self:GetPanel(panelId)
	local entry = panel and panel.entries and panel.entries[entryId] or nil
	return panel, entry
end

function CooldownPanels:GetLayoutEntryStandaloneEffectiveType(entry)
	local effectiveType = entry and entry.type or nil
	if effectiveType == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		effectiveType = (macro and macro.kind) or "MACRO"
	end
	return effectiveType
end

function CooldownPanels:HideLayoutEntryStandaloneMenu(panelId)
	local lib = addon.EditModeLib
	local state = self:GetLayoutEntryStandaloneMenuState(false)
	local trackedPanelId = normalizeId(state and state.panelId)
	if panelId and trackedPanelId and trackedPanelId ~= normalizeId(panelId) then return false end
	local hostFrame = state and state.hostFrame or (trackedPanelId and getRuntime(trackedPanelId).frame) or nil
	local hidden = false
	if lib and lib.HideStandaloneSettingsDialog then hidden = lib:HideStandaloneSettingsDialog(hostFrame) end
	self:ClearLayoutEntryStandaloneMenuState()
	return hidden
end

function CooldownPanels:RefreshLayoutEntryStandaloneMenu()
	local lib = addon.EditModeLib
	local state = self:GetLayoutEntryStandaloneMenuState(false)
	if not state or not state.hostFrame then return end
	if not (lib and lib.IsStandaloneSettingsDialogShown and lib:IsStandaloneSettingsDialogShown(state.hostFrame)) then
		self:ClearLayoutEntryStandaloneMenuState()
		return
	end
	local panelId = normalizeId(state.panelId)
	local entryId = normalizeId(state.entryId)
	local panel, entry = self:GetLayoutEntryStandaloneDialogEntry(panelId, entryId)
	local editor = getEditor()
	local selectedPanelId = normalizeId(editor and editor.selectedPanelId)
	local selectedEntryId = normalizeId(editor and editor.selectedEntryId)
	if not panel or not entry or not self:IsPanelLayoutEditActive(panelId) or selectedPanelId ~= panelId or selectedEntryId ~= entryId then self:HideLayoutEntryStandaloneMenu(panelId) end
end

function CooldownPanels:GetStandaloneDialogSpawnPosition(anchorFrame, fallbackFrame, offsetX, offsetY)
	local source = anchorFrame or fallbackFrame or UIParent
	local xOffset = tonumber(offsetX) or 0
	local yOffset = tonumber(offsetY) or 0
	if not source then return {
		point = "TOPLEFT",
		relativePoint = "TOPLEFT",
		relativeTo = UIParent,
		x = xOffset,
		y = yOffset,
	} end

	local right = source.GetRight and source:GetRight() or nil
	local top = source.GetTop and source:GetTop() or nil
	local sourceScale = (source.GetEffectiveScale and source:GetEffectiveScale()) or 1
	local parentScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1

	if right and top then
		return {
			point = "TOPLEFT",
			relativePoint = "BOTTOMLEFT",
			relativeTo = UIParent,
			x = (right * sourceScale / parentScale) + xOffset,
			y = (top * sourceScale / parentScale) + yOffset,
		}
	end

	return {
		point = "TOPLEFT",
		relativePoint = "TOPRIGHT",
		relativeTo = source,
		x = xOffset,
		y = yOffset,
	}
end

function CooldownPanels:OpenLayoutEntryStandaloneMenu(panelId, entryId, anchorFrame)
	local lib = addon.EditModeLib
	if not (lib and lib.ShowStandaloneSettingsDialog and SettingType) then return end
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	if not (panelId and entryId) then return end
	if not self:IsPanelLayoutEditActive(panelId) then return end
	self:HideLayoutPanelStandaloneMenu(panelId)
	self:HideLayoutFixedGroupStandaloneMenu(panelId)

	local panel, entry = self:GetLayoutEntryStandaloneDialogEntry(panelId, entryId)
	local runtime = getRuntime(panelId)
	local hostFrame = runtime and runtime.frame or nil
	if not (panel and entry and hostFrame) then return end
	local spawnPosition = self:GetStandaloneDialogSpawnPosition(anchorFrame, hostFrame, 12, 0)
	local defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle = Helper.GetCountFontDefaults(hostFrame)
	local defaultCooldownFontPath, defaultCooldownFontSize, defaultCooldownFontStyle = self:GetCooldownFontDefaults(hostFrame)
	local defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle = defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle
	local defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle = Helper.GetChargesFontDefaults(hostFrame)

	local function allowsStandaloneEntryReadySound(effectiveType) return effectiveType and effectiveType ~= "MACRO" and effectiveType ~= "STANCE" and effectiveType ~= "CDM_AURA" end

	local function getPanel() return CooldownPanels:GetPanel(panelId) end

	local function getLayout()
		local currentPanel = getPanel()
		return currentPanel and currentPanel.layout or nil
	end

	local function getEntry()
		local currentPanel, currentEntry = CooldownPanels:GetLayoutEntryStandaloneDialogEntry(panelId, entryId)
		return currentPanel, currentEntry
	end

	local function getEffectiveType()
		local _, currentEntry = getEntry()
		return CooldownPanels:GetLayoutEntryStandaloneEffectiveType(currentEntry)
	end

	local refreshEntryDialogPending = false

	local function isStandaloneDialogDragActive()
		if type(IsMouseButtonDown) ~= "function" then return false end
		return IsMouseButtonDown("LeftButton") == true
	end

	local function updateEntryDialog()
		local state = CooldownPanels:GetLayoutEntryStandaloneMenuState(false)
		local activeDialog = state and state.dialog
		if state and normalizeId(state.panelId) == panelId and normalizeId(state.entryId) == entryId and activeDialog then
			local _, currentEntry = getEntry()
			local title = currentEntry and CooldownPanels:GetEntryStandaloneTitle(currentEntry) or nil
			if activeDialog.context then activeDialog.context.title = title end
			if activeDialog.Title and title then activeDialog.Title:SetText(title) end
			if activeDialog.UpdateSettings then activeDialog:UpdateSettings() end
			if activeDialog.UpdateButtons then activeDialog:UpdateButtons() end
			if activeDialog.Layout then activeDialog:Layout() end
		end
	end

	local function scheduleEntryDialogRefresh()
		if refreshEntryDialogPending then return end
		if not (C_Timer and C_Timer.After) then
			updateEntryDialog()
			return
		end
		refreshEntryDialogPending = true
		C_Timer.After(0, function()
			refreshEntryDialogPending = false
			local state = CooldownPanels:GetLayoutEntryStandaloneMenuState(false)
			if not state or normalizeId(state.panelId) ~= panelId or normalizeId(state.entryId) ~= entryId then return end
			if isStandaloneDialogDragActive() then
				scheduleEntryDialogRefresh()
				return
			end
			updateEntryDialog()
		end)
	end

	local function refreshEntryViews()
		CooldownPanels:RefreshPanel(panelId)
		if CooldownPanels.IsEditorOpen and CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
		if isStandaloneDialogDragActive() then
			scheduleEntryDialogRefresh()
			return
		end
		updateEntryDialog()
	end

	local function refreshEntryPreview()
		CooldownPanels:RefreshPanel(panelId)
		if CooldownPanels.IsEditorOpen and CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
	end

	local function setEntryField(field, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		if currentEntry[field] == value then return end
		currentEntry[field] = value
		refreshEntryViews()
	end

	local function setEntryBoolean(field, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local normalized = value == true
		if (currentEntry[field] == true) == normalized then return end
		currentEntry[field] = normalized and true or false
		CooldownPanels:HandleEntryBooleanMutation(panelId, entryId, currentEntry, field)
		refreshEntryViews()
	end

	local function setAlwaysShowLike(value)
		local layout = getLayout()
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local normalized = value == true
		if currentEntry.type == "STANCE" then
			if (currentEntry.showWhenMissing == true) == normalized then return end
			currentEntry.showWhenMissing = normalized and true or false
		elseif currentEntry.type == "CDM_AURA" then
			local mode = normalized and (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.SHOW or "SHOW")
				or (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.HIDE or "HIDE")
			local resolvedMode = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, currentEntry)
			if currentEntry.cdmAuraAlwaysShowUseGlobal == false and resolvedMode == mode then return end
			currentEntry.cdmAuraAlwaysShowUseGlobal = false
			currentEntry.cdmAuraAlwaysShowMode = mode
			currentEntry.alwaysShow = normalized and true or false
		else
			if (currentEntry.alwaysShow == true) == normalized then return end
			currentEntry.alwaysShow = normalized and true or false
		end
		refreshEntryViews()
	end

	local function refreshReadyGlowState(currentEntry)
		if not currentEntry then return end
		local runtimeState = getRuntime(panelId)
		local hadReady = runtimeState and runtimeState.readyAt and runtimeState.readyAt[entryId] ~= nil
		CooldownPanels.ClearReadyGlowEntryState(panelId, entryId, false)
		local primed = CooldownPanels.GetReadyGlowPrimedState(runtimeState)
		if primed then primed[entryId] = nil end
		if currentEntry.glowReady and hadReady then
			local resolvedDuration = CooldownPanels:ResolveEntryGlowStyle(getLayout(), currentEntry)
			triggerReadyGlow(panelId, entryId, resolvedDuration)
			if primed then primed[entryId] = true end
		end
	end

	local function setGlowOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.glowUseGlobal == useGlobal then return end
		currentEntry.glowUseGlobal = useGlobal
		CooldownPanels:RebuildPowerIndex()
		refreshReadyGlowState(currentEntry)
		refreshEntryViews()
	end

	local function setProcGlowOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.procGlowUseGlobal == useGlobal then return end
		currentEntry.procGlowUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setProcGlowEnabled(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local normalized = value == true
		if currentEntry.procGlowEnabled == normalized then return end
		currentEntry.procGlowEnabled = normalized
		refreshEntryViews()
	end

	local function setProcGlowStyle(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local layout = getLayout()
		local panelStyle = CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)
		local normalized = Helper.NormalizeGlowStyle(value, panelStyle)
		currentEntry.procGlowStyle = normalized == panelStyle and nil or normalized
		refreshEntryViews()
	end

	local function setProcGlowInset(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local layout = getLayout()
		local _, panelInset = CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)
		local normalized = Helper.NormalizeGlowInset(value, panelInset)
		currentEntry.procGlowInset = normalized == panelInset and nil or normalized
		refreshEntryViews()
	end

	local function setGlowStyle(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local layout = getLayout()
		local _, _, panelStyle = CooldownPanels:ResolveEntryGlowStyle(layout, nil)
		local normalized = Helper.NormalizeGlowStyle(value, panelStyle)
		currentEntry.glowStyle = normalized == panelStyle and nil or normalized
		refreshEntryViews()
	end

	local function setPandemicGlowStyle(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local layout = getLayout()
		local _, panelStyle = CooldownPanels:ResolveEntryPandemicGlowVisual(layout, nil)
		local normalized = Helper.NormalizeGlowStyle(value, panelStyle)
		currentEntry.pandemicGlowStyle = normalized == panelStyle and nil or normalized
		refreshEntryViews()
	end

	local function setGlowInset(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local layout = getLayout()
		local _, _, _, panelInset = CooldownPanels:ResolveEntryGlowStyle(layout, nil)
		local normalized = Helper.NormalizeGlowInset(value, panelInset)
		currentEntry.glowInset = normalized == panelInset and nil or normalized
		refreshEntryViews()
	end

	local function setPandemicGlowInset(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local layout = getLayout()
		local _, _, panelInset = CooldownPanels:ResolveEntryPandemicGlowVisual(layout, nil)
		local normalized = Helper.NormalizeGlowInset(value, panelInset)
		currentEntry.pandemicGlowInset = normalized == panelInset and nil or normalized
		refreshEntryViews()
	end

	local function setGlowColor(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		currentEntry.glowColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
		refreshEntryViews()
	end

	local function setStaticText(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local text = value or ""
		if currentEntry.staticText == text then return end
		currentEntry.staticText = text
		refreshEntryViews()
	end

	local function isStateTextureSupported()
		local effectiveType = getEffectiveType()
		return effectiveType == "SPELL" or effectiveType == "CDM_AURA"
	end

	local function entryHasStateTexture()
		local _, currentEntry = getEntry()
		return CooldownPanels:HasConfiguredStateTexture(currentEntry)
	end

	local function entryUsesDoubleStateTexture()
		local _, currentEntry = getEntry()
		return currentEntry and currentEntry.stateTextureDouble == true or false
	end

	local function setStateTextureInput(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local ok, err = CooldownPanels:ApplyEntryStateTextureInput(currentEntry, value)
		if not ok then
			showErrorMessage(err)
			refreshEntryViews()
			return
		end
		refreshEntryPreview()
	end

	local function setStateTextureField(field, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		if currentEntry[field] == value then return end
		currentEntry[field] = value
		refreshEntryPreview()
	end

	local function setCooldownTextOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.cooldownTextUseGlobal == useGlobal then return end
		currentEntry.cooldownTextUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setStaticTextOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.staticTextUseGlobal == useGlobal then return end
		currentEntry.staticTextUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setShowIconOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.showIconTextureUseGlobal == useGlobal then return end
		currentEntry.showIconTextureUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setCooldownVisualsOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.cooldownVisualsUseGlobal == useGlobal then return end
		currentEntry.cooldownVisualsUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setCooldownVisibilityOverrideEnabled(value)
		local layout = getLayout()
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.cooldownVisibilityUseGlobal == useGlobal then return end
		if not useGlobal then
			currentEntry.hideOnCooldown, currentEntry.showOnCooldown = CooldownPanels:ResolveEntryCooldownVisibility(layout, currentEntry)
		end
		currentEntry.cooldownVisibilityUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setCooldownVisibility(field, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local hideOnCooldown = currentEntry.hideOnCooldown == true
		local showOnCooldown = currentEntry.showOnCooldown == true
		if field == "hideOnCooldown" then
			hideOnCooldown = value == true
			if hideOnCooldown then showOnCooldown = false end
		elseif field == "showOnCooldown" then
			showOnCooldown = value == true
			if showOnCooldown then hideOnCooldown = false end
		else
			return
		end
		if currentEntry.hideOnCooldown == hideOnCooldown and currentEntry.showOnCooldown == showOnCooldown then return end
		currentEntry.hideOnCooldown = hideOnCooldown
		currentEntry.showOnCooldown = showOnCooldown
		refreshEntryViews()
	end

	local function setIconSizeOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.iconSizeUseGlobal == useGlobal then return end
		currentEntry.iconSizeUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setNoDesaturationOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.noDesaturationUseGlobal == useGlobal then return end
		currentEntry.noDesaturationUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setHideWhenNoResourceOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.hideWhenNoResourceUseGlobal == useGlobal then return end
		currentEntry.hideWhenNoResourceUseGlobal = useGlobal
		CooldownPanels:RebuildPowerIndex()
		refreshEntryViews()
	end

	local function setCDMAuraAlwaysShowOverrideEnabled(value)
		local layout = getLayout()
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.cdmAuraAlwaysShowUseGlobal == useGlobal then return end
		if not useGlobal then currentEntry.cdmAuraAlwaysShowMode = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, currentEntry) end
		currentEntry.cdmAuraAlwaysShowUseGlobal = useGlobal
		currentEntry.alwaysShow = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, currentEntry)
			~= (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.HIDE or "HIDE")
		refreshEntryViews()
	end

	local function setCDMAuraAlwaysShowMode(_, value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local normalized = CooldownPanels:NormalizeCDMAuraAlwaysShowMode(value, CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.HIDE or "HIDE")
		if currentEntry.cdmAuraAlwaysShowMode == normalized then return end
		currentEntry.cdmAuraAlwaysShowMode = normalized
		currentEntry.alwaysShow = normalized ~= (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.HIDE or "HIDE")
		refreshEntryViews()
	end

	local function setStackStyleOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.stackStyleUseGlobal == useGlobal then return end
		currentEntry.stackStyleUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setChargesStyleOverrideEnabled(value)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local useGlobal = value ~= true
		if currentEntry.chargesStyleUseGlobal == useGlobal then return end
		currentEntry.chargesStyleUseGlobal = useGlobal
		refreshEntryViews()
	end

	local function setSoundReadyFile(soundName)
		local _, currentEntry = getEntry()
		if not currentEntry then return end
		local _, _, soundField = CooldownPanels:GetEntrySoundConfig(currentEntry)
		if not soundField then return end
		local normalized = normalizeSoundName(soundName)
		if normalizeSoundName(currentEntry[soundField]) == normalized then return end
		currentEntry[soundField] = normalized
		playSoundName(normalized)
		refreshEntryViews()
	end

	local function getCooldownTextFontSelection()
		local _, currentEntry = getEntry()
		return CooldownPanels:GetFontDropdownValue(currentEntry and currentEntry.cooldownTextFont)
	end

	local function getResolvedCooldownTextStyleChoice()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local panelChoice = Helper.NormalizeFontStyleChoice(layout and layout.cooldownTextStyle, defaultCooldownFontStyle)
		if currentEntry and currentEntry.cooldownTextUseGlobal == false then return Helper.NormalizeFontStyleChoice(currentEntry.cooldownTextStyle, panelChoice) end
		return panelChoice
	end

	local function getResolvedCooldownTextColor()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, _, color = CooldownPanels:ResolveEntryCooldownTextStyle(layout, currentEntry, defaultCooldownFontPath, defaultCooldownFontSize, defaultCooldownFontStyle)
		return color
	end

	local function getStaticTextFontSelection()
		local _, currentEntry = getEntry()
		return CooldownPanels:GetFontDropdownValue(currentEntry and currentEntry.staticTextFont)
	end

	local function getResolvedStaticTextStyleChoice()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local panelChoice = Helper.NormalizeFontStyleChoice(layout and layout.staticTextStyle, Helper.PANEL_LAYOUT_DEFAULTS.staticTextStyle or defaultStaticFontStyle)
		if currentEntry and currentEntry.staticTextUseGlobal == false then return Helper.NormalizeFontStyleChoice(currentEntry.staticTextStyle, panelChoice) end
		return panelChoice
	end

	local function getResolvedStaticTextColor()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, _, color = CooldownPanels:ResolveEntryStaticTextStyle(layout, currentEntry, defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle)
		return color
	end

	local function getStackFontSelection()
		local _, currentEntry = getEntry()
		return CooldownPanels:GetFontDropdownValue(currentEntry and currentEntry.stackFont)
	end

	local function getResolvedStackStyleChoice()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local panelChoice = Helper.NormalizeFontStyleChoice(layout and layout.stackFontStyle, defaultCountFontStyle)
		if currentEntry and currentEntry.stackStyleUseGlobal == false then return Helper.NormalizeFontStyleChoice(currentEntry.stackFontStyle, panelChoice) end
		return panelChoice
	end

	local function getResolvedStackColor()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, _, color = CooldownPanels:ResolveEntryStackTextStyle(layout, currentEntry, defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
		return color
	end

	local function getChargesFontSelection()
		local _, currentEntry = getEntry()
		return CooldownPanels:GetFontDropdownValue(currentEntry and currentEntry.chargesFont)
	end

	local function getResolvedChargesStyleChoice()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local panelChoice = Helper.NormalizeFontStyleChoice(layout and layout.chargesFontStyle, defaultChargesFontStyle)
		if currentEntry and currentEntry.chargesStyleUseGlobal == false then return Helper.NormalizeFontStyleChoice(currentEntry.chargesFontStyle, panelChoice) end
		return panelChoice
	end

	local function getResolvedChargesColor()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, _, color = CooldownPanels:ResolveEntryChargesTextStyle(layout, currentEntry, defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
		return color
	end

	local function getResolvedGlowColor()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, color = CooldownPanels:ResolveEntryGlowStyle(layout, currentEntry)
		return color
	end

	local function getResolvedGlowStyle()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, style = CooldownPanels:ResolveEntryGlowStyle(layout, currentEntry)
		return style
	end

	local function getResolvedGlowInset()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, _, inset = CooldownPanels:ResolveEntryGlowStyle(layout, currentEntry)
		return inset
	end

	local function getResolvedPandemicGlowColor()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return CooldownPanels:ResolveEntryPandemicGlowColor(layout, currentEntry)
	end

	local function getResolvedPandemicGlowStyle()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, style = CooldownPanels:ResolveEntryPandemicGlowVisual(layout, currentEntry)
		return style
	end

	local function getResolvedPandemicGlowInset()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, _, inset = CooldownPanels:ResolveEntryPandemicGlowVisual(layout, currentEntry)
		return inset
	end

	local function getResolvedProcGlowEnabled()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return CooldownPanels:ResolveEntryProcGlowEnabled(layout, currentEntry)
	end

	local function getResolvedProcGlowStyle()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local style = CooldownPanels:ResolveEntryProcGlowVisual(layout, currentEntry)
		return style
	end

	local function getResolvedProcGlowInset()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		local _, inset = CooldownPanels:ResolveEntryProcGlowVisual(layout, currentEntry)
		return inset
	end

	local function getResolvedReadyGlowCheckPower()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return CooldownPanels:ResolveEntryReadyGlowCheckPower(layout, currentEntry)
	end

	local function entryUsesConfiguredGlow(currentEntry)
		if not currentEntry or currentEntry.type == "MACRO" then return false end
		if currentEntry.type == "SPELL" then return true end
		if currentEntry.type == "CDM_AURA" then return currentEntry.glowReady == true or currentEntry.pandemicGlow == true end
		return currentEntry.glowReady == true
	end

	local function getResolvedNoDesaturation()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return CooldownPanels:ResolveEntryNoDesaturation(layout, currentEntry)
	end

	local function getResolvedHideOnCooldown()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return select(1, CooldownPanels:ResolveEntryCooldownVisibility(layout, currentEntry))
	end

	local function getResolvedShowOnCooldown()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return select(2, CooldownPanels:ResolveEntryCooldownVisibility(layout, currentEntry))
	end

	local function getResolvedHideWhenNoResource()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return CooldownPanels:ResolveEntryHideWhenNoResource(layout, currentEntry)
	end

	local function getResolvedCDMAuraAlwaysShowMode()
		local layout = getLayout()
		local _, currentEntry = getEntry()
		return CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, currentEntry)
	end

	local function getResolvedIconSize()
		local layout = getLayout()
		local runtimeState = getRuntime(panelId)
		local currentIcon = runtimeState and runtimeState.entryToIcon and runtimeState.entryToIcon[entryId] or nil
		local baseSize = currentIcon and currentIcon._eqolBaseSlotSize or Helper.ClampInt(layout and layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
		local _, currentEntry = getEntry()
		local size = CooldownPanels:ResolveEntryIconVisualLayout(layout, currentEntry, baseSize)
		return size
	end

	local initialEffectiveType = getEffectiveType()
	local settings = {
		{
			name = L["Display"] or "Display",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneDisplay",
			defaultCollapsed = false,
		},
		{
			name = (initialEffectiveType == "STANCE" and (L["CooldownPanelShowWhenMissing"] or "Show when missing")) or (L["CooldownPanelAlwaysShow"] or "Always show"),
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "ITEM" or effectiveType == "STANCE"
			end,
			get = function()
				local _, currentEntry = getEntry()
				if not currentEntry then return false end
				if currentEntry.type == "STANCE" then return currentEntry.showWhenMissing == true end
				return currentEntry.alwaysShow ~= false
			end,
			set = function(_, value) setAlwaysShowLike(value) end,
		},
		{
			name = L["CooldownPanelOverwritePanelCDMAuraAlwaysShow"] or "Overwrite panel tracked aura display",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() == "CDM_AURA" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.cdmAuraAlwaysShowUseGlobal == false or false
			end,
			set = function(_, value) setCDMAuraAlwaysShowOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelCDMAuraAlwaysShowMode"] or "Tracked aura display",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneDisplay",
			height = 180,
			isShown = function() return getEffectiveType() == "CDM_AURA" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cdmAuraAlwaysShowUseGlobal == false)
			end,
			get = function() return getResolvedCDMAuraAlwaysShowMode() end,
			set = function(_, value) setCDMAuraAlwaysShowMode(nil, value) end,
			generator = function(_, root)
				for _, option in ipairs(CooldownPanels:GetCDMAuraAlwaysShowOptions()) do
					root:CreateRadio(option.label, function() return getResolvedCDMAuraAlwaysShowMode() == option.value end, function() setCDMAuraAlwaysShowMode(nil, option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() ~= "CDM_AURA" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.cooldownVisibilityUseGlobal == false or false
			end,
			set = function(_, value) setCooldownVisibilityOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelHideOnCooldown"] or "Hide on cooldown",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() ~= "CDM_AURA" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisibilityUseGlobal == false)
			end,
			get = function() return getResolvedHideOnCooldown() end,
			set = function(_, value) setCooldownVisibility("hideOnCooldown", value) end,
		},
		{
			name = L["CooldownPanelShowOnCooldown"] or "Show on cooldown",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() ~= "CDM_AURA" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisibilityUseGlobal == false)
			end,
			get = function() return getResolvedShowOnCooldown() end,
			set = function(_, value) setCooldownVisibility("showOnCooldown", value) end,
		},
		{
			name = L["CooldownPanelShowItemCount"] or "Show item count",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() == "ITEM" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showItemCount ~= false or false
			end,
			set = function(_, value) setEntryBoolean("showItemCount", value) end,
		},
		{
			name = L["CooldownPanelShowItemUses"] or "Show item uses",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() == "ITEM" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showItemUses == true or false
			end,
			set = function(_, value) setEntryBoolean("showItemUses", value) end,
		},
		{
			name = L["CooldownPanelUseHighestRank"] or "Use highest rank",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function()
				local _, currentEntry = getEntry()
				if not currentEntry or currentEntry.type ~= "ITEM" then return false end
				CooldownPanels:EnsureFoodRankGroupsLoaded()
				local itemID = tonumber(currentEntry.itemID)
				local rankMap = CooldownPanels.itemHighestRankByID
				return itemID and rankMap and rankMap[itemID] ~= nil
			end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.useHighestRank == true or false
			end,
			set = function(_, value) setEntryBoolean("useHighestRank", value) end,
		},
		{
			name = L["CooldownPanelShowWhenEmpty"] or "Show when empty",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() == "ITEM" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showWhenEmpty == true or false
			end,
			set = function(_, value) setEntryBoolean("showWhenEmpty", value) end,
		},
		{
			name = L["CooldownPanelShowWhenNoCooldown"] or "Show even without cooldown",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			isShown = function() return getEffectiveType() == "SLOT" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showWhenNoCooldown == true or false
			end,
			set = function(_, value) setEntryBoolean("showWhenNoCooldown", value) end,
		},
		{
			name = L["CooldownPanelHideIcon"] or "Hide icon",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and (currentEntry.hideIcon == true or CooldownPanels:HasConfiguredStateTexture(currentEntry)) or false
			end,
			disabled = function() return entryHasStateTexture() end,
			set = function(_, value) setEntryBoolean("hideIcon", value) end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			disabled = function() return entryHasStateTexture() end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showIconTextureUseGlobal == false or false
			end,
			set = function(_, value) setShowIconOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalSize"] or "Overwrite global size",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneDisplay",
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.iconSizeUseGlobal == false or false
			end,
			set = function(_, value) setIconSizeOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelIconSize"] or "Icon size",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneDisplay",
			minValue = 12,
			maxValue = 128,
			valueStep = 1,
			allowInput = true,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.iconSizeUseGlobal == false)
			end,
			get = function() return getResolvedIconSize() end,
			set = function(_, value)
				local _, currentEntry = getEntry()
				if not currentEntry then return end
				local size = Helper.ClampInt(value, 12, 128, getResolvedIconSize())
				if currentEntry.iconSize == size then return end
				currentEntry.iconSize = size
				refreshEntryViews()
			end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelIconOffsetX"] or "Icon X",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneDisplay",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.STATE_TEXTURE_SPACING_RANGE or 2000,
			valueStep = 1,
			allowInput = true,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampInt(currentEntry and currentEntry.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
			end,
			set = function(_, value) setEntryField("iconOffsetX", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelIconOffsetY"] or "Icon Y",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneDisplay",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.STATE_TEXTURE_SPACING_RANGE or 2000,
			valueStep = 1,
			allowInput = true,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampInt(currentEntry and currentEntry.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
			end,
			set = function(_, value) setEntryField("iconOffsetY", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelStacksHeader"] or "Stacks / Item Count",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneStacks",
			defaultCollapsed = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
		},
		{
			name = L["CooldownPanelShowStacks"] or "Show stack count",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStacks",
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA"
			end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showStacks == true or false
			end,
			set = function(_, value) setEntryBoolean("showStacks", value) end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStacks",
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.stackStyleUseGlobal == false or false
			end,
			set = function(_, value) setStackStyleOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelCountAnchor"] or "Count anchor",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneStacks",
			height = 160,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, anchor = CooldownPanels:ResolveEntryStackTextStyle(getLayout(), select(2, getEntry()), defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
				return anchor
			end,
			set = function(_, value) setEntryField("stackAnchor", Helper.NormalizeAnchor(value, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor or "BOTTOMRIGHT")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.AnchorOptions) do
					root:CreateRadio(option.label, function()
						local _, _, _, _, anchor = CooldownPanels:ResolveEntryStackTextStyle(getLayout(), select(2, getEntry()), defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
						return anchor == option.value
					end, function() setEntryField("stackAnchor", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelCountOffsetX"] or "Count X",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStacks",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, x = CooldownPanels:ResolveEntryStackTextStyle(getLayout(), select(2, getEntry()), defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
				return x
			end,
			set = function(_, value) setEntryField("stackX", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelCountOffsetY"] or "Count Y",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStacks",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, _, y = CooldownPanels:ResolveEntryStackTextStyle(getLayout(), select(2, getEntry()), defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
				return y
			end,
			set = function(_, value) setEntryField("stackY", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["Font"] or "Font",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneStacks",
			height = 220,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function() return getStackFontSelection() end,
			set = function(_, value) setEntryField("stackFont", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GetFontOptions(defaultCountFontPath)) do
					root:CreateRadio(option.label, function() return getStackFontSelection() == option.value end, function() setEntryField("stackFont", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelFontStyle"] or "Font style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneStacks",
			height = 120,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function() return getResolvedStackStyleChoice() end,
			set = function(_, value) setEntryField("stackFontStyle", Helper.NormalizeFontStyleChoice(value, Helper.PANEL_LAYOUT_DEFAULTS.stackFontStyle or "OUTLINE")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.FontStyleOptions) do
					root:CreateRadio(option.label, function() return getResolvedStackStyleChoice() == option.value end, function() setEntryField("stackFontStyle", option.value) end)
				end
			end,
		},
		{
			name = _G.COLOR or "Color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneStacks",
			hasOpacity = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function()
				local color = getResolvedStackColor()
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value) setEntryField("stackColor", Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })) end,
		},
		{
			name = L["FontSize"] or "Font size",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStacks",
			minValue = 6,
			maxValue = 64,
			valueStep = 1,
			allowInput = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "CDM_AURA" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.stackStyleUseGlobal == false)
			end,
			get = function()
				local _, size = CooldownPanels:ResolveEntryStackTextStyle(getLayout(), select(2, getEntry()), defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
				return size
			end,
			set = function(_, value) setEntryField("stackFontSize", Helper.ClampInt(value, 6, 64, defaultCountFontSize or 12)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelChargesHeader"] or "Charges",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneCharges",
			defaultCollapsed = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
		},
		{
			name = L["CooldownPanelShowCharges"] or "Show charges",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCharges",
			isShown = function() return getEffectiveType() == "SPELL" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showCharges == true or false
			end,
			set = function(_, value) setEntryBoolean("showCharges", value) end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCharges",
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.chargesStyleUseGlobal == false or false
			end,
			set = function(_, value) setChargesStyleOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelChargesAnchor"] or "Charges anchor",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneCharges",
			height = 160,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, anchor = CooldownPanels:ResolveEntryChargesTextStyle(getLayout(), select(2, getEntry()), defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
				return anchor
			end,
			set = function(_, value) setEntryField("chargesAnchor", Helper.NormalizeAnchor(value, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor or "TOP")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.AnchorOptions) do
					root:CreateRadio(option.label, function()
						local _, _, _, _, anchor =
							CooldownPanels:ResolveEntryChargesTextStyle(getLayout(), select(2, getEntry()), defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
						return anchor == option.value
					end, function() setEntryField("chargesAnchor", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelChargesOffsetX"] or "Charges X",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneCharges",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, x = CooldownPanels:ResolveEntryChargesTextStyle(getLayout(), select(2, getEntry()), defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
				return x
			end,
			set = function(_, value) setEntryField("chargesX", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelChargesOffsetY"] or "Charges Y",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneCharges",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, _, y = CooldownPanels:ResolveEntryChargesTextStyle(getLayout(), select(2, getEntry()), defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
				return y
			end,
			set = function(_, value) setEntryField("chargesY", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["Font"] or "Font",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneCharges",
			height = 220,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function() return getChargesFontSelection() end,
			set = function(_, value) setEntryField("chargesFont", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GetFontOptions(defaultChargesFontPath)) do
					root:CreateRadio(option.label, function() return getChargesFontSelection() == option.value end, function() setEntryField("chargesFont", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelFontStyle"] or "Font style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneCharges",
			height = 120,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function() return getResolvedChargesStyleChoice() end,
			set = function(_, value) setEntryField("chargesFontStyle", Helper.NormalizeFontStyleChoice(value, Helper.PANEL_LAYOUT_DEFAULTS.chargesFontStyle or "OUTLINE")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.FontStyleOptions) do
					root:CreateRadio(option.label, function() return getResolvedChargesStyleChoice() == option.value end, function() setEntryField("chargesFontStyle", option.value) end)
				end
			end,
		},
		{
			name = _G.COLOR or "Color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneCharges",
			hasOpacity = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function()
				local color = getResolvedChargesColor()
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value) setEntryField("chargesColor", Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })) end,
		},
		{
			name = L["FontSize"] or "Font size",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneCharges",
			minValue = 6,
			maxValue = 64,
			valueStep = 1,
			allowInput = true,
			isShown = function()
				local effectiveType = getEffectiveType()
				return effectiveType == "SPELL" or effectiveType == "ITEM"
			end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.chargesStyleUseGlobal == false)
			end,
			get = function()
				local _, size = CooldownPanels:ResolveEntryChargesTextStyle(getLayout(), select(2, getEntry()), defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
				return size
			end,
			set = function(_, value) setEntryField("chargesFontSize", Helper.ClampInt(value, 6, 64, defaultChargesFontSize or 12)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelCooldownHeader"] or "Cooldown",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneCooldownVisuals",
			defaultCollapsed = true,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.cooldownVisualsUseGlobal == false or false
			end,
			set = function(_, value) setCooldownVisualsOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelShowChargesCooldown"] or "Show charges cooldown",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("showChargesCooldown", value) end,
		},
		{
			name = L["CooldownPanelDrawEdge"] or "Draw edge",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("cooldownDrawEdge", value) end,
		},
		{
			name = L["CooldownPanelDrawBling"] or "Draw bling",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, _, value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("cooldownDrawBling", value) end,
		},
		{
			name = L["CooldownPanelDrawSwipe"] or "Draw swipe",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, _, _, value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("cooldownDrawSwipe", value) end,
		},
		{
			name = L["CooldownPanelDrawEdgeGcd"] or "Draw edge on GCD",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, _, _, _, value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("cooldownGcdDrawEdge", value) end,
		},
		{
			name = L["CooldownPanelDrawBlingGcd"] or "Draw bling on GCD",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, _, _, _, _, value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("cooldownGcdDrawBling", value) end,
		},
		{
			name = L["CooldownPanelDrawSwipeGcd"] or "Draw swipe on GCD",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownVisuals",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.cooldownVisualsUseGlobal == false)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, _, _, _, _, _, value = CooldownPanels:ResolveEntryCooldownVisuals(getLayout(), currentEntry)
				return value
			end,
			set = function(_, value) setEntryBoolean("cooldownGcdDrawSwipe", value) end,
		},
		{
			name = L["CooldownPanelOverlaysHeader"] or "Overlays",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneOverlays",
			defaultCollapsed = true,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneOverlays",
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.noDesaturationUseGlobal == false or false
			end,
			set = function(_, value) setNoDesaturationOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelNoDesaturation"] or "No desaturation",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneOverlays",
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.noDesaturationUseGlobal == false)
			end,
			get = function() return getResolvedNoDesaturation() end,
			set = function(_, value) setEntryBoolean("noDesaturation", value) end,
		},
		{
			name = L["CooldownPanelOverwritePanelCheckPower"] or "Overwrite panel power check",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneOverlays",
			isShown = function() return getEffectiveType() == "SPELL" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.checkPowerUseGlobal == false or false
			end,
			set = function(_, value)
				local _, currentEntry = getEntry()
				if not currentEntry then return end
				local useGlobal = value ~= true
				if currentEntry.checkPowerUseGlobal == useGlobal then return end
				currentEntry.checkPowerUseGlobal = useGlobal
				CooldownPanels:RebuildPowerIndex()
				refreshEntryViews()
			end,
		},
		{
			name = L["CooldownPanelCheckPower"] or "Check power",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneOverlays",
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.checkPowerUseGlobal == false)
			end,
			get = function() return CooldownPanels:ResolveEntryCheckPower(getLayout(), select(2, getEntry())) == true end,
			set = function(_, value) setEntryBoolean("checkPower", value) end,
		},
		{
			name = L["CooldownPanelOverwritePanelHideWhenNoResource"] or "Overwrite panel hide when no resource",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneOverlays",
			isShown = function() return getEffectiveType() == "SPELL" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.hideWhenNoResourceUseGlobal == false or false
			end,
			set = function(_, value) setHideWhenNoResourceOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelHideWhenNoResource"] or "Hide when no resource",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneOverlays",
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.hideWhenNoResourceUseGlobal == false)
			end,
			get = function() return getResolvedHideWhenNoResource() == true end,
			set = function(_, value) setEntryBoolean("hideWhenNoResource", value) end,
		},
		{
			name = L["CooldownPanelCooldownText"] or "Cooldown text",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneCooldownText",
			defaultCollapsed = true,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
		},
		{
			name = L["CooldownPanelShowCooldownText"] or "Show cooldown text",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownText",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.showCooldownText ~= false or false
			end,
			set = function(_, value) setEntryBoolean("showCooldownText", value) end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneCooldownText",
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.cooldownTextUseGlobal == false or false
			end,
			set = function(_, value) setCooldownTextOverrideEnabled(value) end,
		},
		{
			name = L["Font"] or "Font",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneCooldownText",
			height = 220,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.showCooldownText ~= false and currentEntry.cooldownTextUseGlobal == false)
			end,
			get = function() return getCooldownTextFontSelection() end,
			set = function(_, value) setEntryField("cooldownTextFont", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GetFontOptions(defaultCooldownFontPath)) do
					root:CreateRadio(option.label, function() return getCooldownTextFontSelection() == option.value end, function() setEntryField("cooldownTextFont", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelCooldownTextStyle"] or "Cooldown text outline",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneCooldownText",
			height = 120,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.showCooldownText ~= false and currentEntry.cooldownTextUseGlobal == false)
			end,
			get = function() return getResolvedCooldownTextStyleChoice() end,
			set = function(_, value) setEntryField("cooldownTextStyle", Helper.NormalizeFontStyleChoice(value, "NONE")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.FontStyleOptions) do
					root:CreateRadio(option.label, function() return getResolvedCooldownTextStyleChoice() == option.value end, function() setEntryField("cooldownTextStyle", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelCooldownTextColor"] or "Cooldown text color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneCooldownText",
			hasOpacity = true,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.showCooldownText ~= false and currentEntry.cooldownTextUseGlobal == false)
			end,
			get = function()
				local color = getResolvedCooldownTextColor()
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value) setEntryField("cooldownTextColor", Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)) end,
		},
		{
			name = L["FontSize"] or "Font size",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneCooldownText",
			minValue = 6,
			maxValue = 64,
			valueStep = 1,
			allowInput = true,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.showCooldownText ~= false and currentEntry.cooldownTextUseGlobal == false)
			end,
			get = function()
				local _, size = CooldownPanels:ResolveEntryCooldownTextStyle(getLayout(), select(2, getEntry()), defaultCooldownFontPath, defaultCooldownFontSize, defaultCooldownFontStyle)
				return size
			end,
			set = function(_, value) setEntryField("cooldownTextSize", Helper.ClampInt(value, 6, 64, defaultCooldownFontSize or 12)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelCooldownTextOffsetX"] or "Cooldown text offset X",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneCooldownText",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.showCooldownText ~= false and currentEntry.cooldownTextUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, x = CooldownPanels:ResolveEntryCooldownTextStyle(getLayout(), select(2, getEntry()), defaultCooldownFontPath, defaultCooldownFontSize, defaultCooldownFontStyle)
				return x
			end,
			set = function(_, value) setEntryField("cooldownTextX", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelCooldownTextOffsetY"] or "Cooldown text offset Y",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneCooldownText",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function() return getEffectiveType() ~= "STANCE" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.showCooldownText ~= false and currentEntry.cooldownTextUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, y = CooldownPanels:ResolveEntryCooldownTextStyle(getLayout(), select(2, getEntry()), defaultCooldownFontPath, defaultCooldownFontSize, defaultCooldownFontStyle)
				return y
			end,
			set = function(_, value) setEntryField("cooldownTextY", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelStaticText"] or "Static text",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneStaticText",
			defaultCollapsed = true,
			isShown = function() return true end,
		},
		{
			name = L["CooldownPanelStaticText"] or "Static text",
			kind = SettingType.Input,
			parentId = "cooldownPanelStandaloneStaticText",
			inputWidth = 220,
			isShown = function() return true end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.staticText or ""
			end,
			set = function(_, value) setStaticText(_, value) end,
			default = "",
			maxChars = 32,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStaticText",
			isShown = function() return true end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.staticTextUseGlobal == false or false
			end,
			set = function(_, value) setStaticTextOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelStaticTextDuringCD"] or "Show text during CD",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStaticText",
			isShown = function() return true end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.staticTextShowOnCooldown == true or false
			end,
			set = function(_, value) setEntryBoolean("staticTextShowOnCooldown", value) end,
		},
		{
			name = L["Font"] or "Font",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneStaticText",
			height = 220,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function() return getStaticTextFontSelection() end,
			set = function(_, value) setEntryField("staticTextFont", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GetFontOptions(defaultStaticFontPath)) do
					root:CreateRadio(option.label, function() return getStaticTextFontSelection() == option.value end, function() setEntryField("staticTextFont", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelFontStyle"] or "Font style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneStaticText",
			height = 120,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function() return getResolvedStaticTextStyleChoice() end,
			set = function(_, value) setEntryField("staticTextStyle", Helper.NormalizeFontStyleChoice(value, Helper.PANEL_LAYOUT_DEFAULTS.staticTextStyle or "OUTLINE")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.FontStyleOptions) do
					root:CreateRadio(option.label, function() return getResolvedStaticTextStyleChoice() == option.value end, function() setEntryField("staticTextStyle", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelStaticTextColor"] or _G.COLOR or "Color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneStaticText",
			hasOpacity = true,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function()
				local color = getResolvedStaticTextColor()
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value) setEntryField("staticTextColor", Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.staticTextColor or { 1, 1, 1, 1 })) end,
		},
		{
			name = L["FontSize"] or "Font size",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStaticText",
			minValue = 6,
			maxValue = 64,
			valueStep = 1,
			allowInput = true,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function()
				local _, size = CooldownPanels:ResolveEntryStaticTextStyle(getLayout(), select(2, getEntry()), defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle)
				return size
			end,
			set = function(_, value) setEntryField("staticTextSize", Helper.ClampInt(value, 6, 64, defaultStaticFontSize or 12)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["Anchor"] or "Anchor",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneStaticText",
			height = 160,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, anchor = CooldownPanels:ResolveEntryStaticTextStyle(getLayout(), select(2, getEntry()), defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle)
				return anchor
			end,
			set = function(_, value) setEntryField("staticTextAnchor", Helper.NormalizeAnchor(value, Helper.PANEL_LAYOUT_DEFAULTS.staticTextAnchor or "CENTER")) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.AnchorOptions) do
					root:CreateRadio(option.label, function()
						local _, _, _, _, anchor = CooldownPanels:ResolveEntryStaticTextStyle(getLayout(), select(2, getEntry()), defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle)
						return anchor == option.value
					end, function() setEntryField("staticTextAnchor", option.value) end)
				end
			end,
		},
		{
			name = L["Text X Offset"] or "Text X Offset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStaticText",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, x = CooldownPanels:ResolveEntryStaticTextStyle(getLayout(), select(2, getEntry()), defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle)
				return x
			end,
			set = function(_, value) setEntryField("staticTextX", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["Text Y Offset"] or "Text Y Offset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStaticText",
			minValue = -Helper.OFFSET_RANGE,
			maxValue = Helper.OFFSET_RANGE,
			valueStep = 1,
			allowInput = true,
			isShown = function() return true end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.staticTextUseGlobal == false)
			end,
			get = function()
				local _, _, _, _, _, _, y = CooldownPanels:ResolveEntryStaticTextStyle(getLayout(), select(2, getEntry()), defaultStaticFontPath, defaultStaticFontSize, defaultStaticFontStyle)
				return y
			end,
			set = function(_, value) setEntryField("staticTextY", Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelStateTexture"] or "State texture",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneStateTexture",
			defaultCollapsed = true,
			isShown = function() return isStateTextureSupported() end,
		},
		{
			name = L["CooldownPanelStateTextureInput"] or "Texture ID / Atlas",
			kind = SettingType.Input,
			parentId = "cooldownPanelStandaloneStateTexture",
			inputWidth = 220,
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.stateTextureInput or ""
			end,
			set = setStateTextureInput,
			default = "",
			maxChars = 128,
		},
		{
			name = L["CooldownPanelStateTextureDouble"] or "Double texture",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStateTexture",
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.stateTextureDouble == true or false
			end,
			set = function(_, value) setStateTextureField("stateTextureDouble", value == true) end,
		},
		{
			name = L["CooldownPanelStateTextureMirror"] or "Mirror texture",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStateTexture",
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.stateTextureMirror == true or false
			end,
			set = function(_, value) setStateTextureField("stateTextureMirror", value == true) end,
		},
		{
			name = L["CooldownPanelStateTextureMirrorSecond"] or "Mirror second texture",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneStateTexture",
			isShown = function() return isStateTextureSupported() and entryUsesDoubleStateTexture() end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.stateTextureMirrorSecond ~= false or false
			end,
			set = function(_, value) setStateTextureField("stateTextureMirrorSecond", value == true) end,
		},
		{
			name = L["CooldownPanelStateTextureScale"] or "Texture scale",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStateTexture",
			minValue = 0.1,
			maxValue = 8,
			valueStep = 0.05,
			allowInput = true,
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampNumber(currentEntry and currentEntry.stateTextureScale, 0.1, 8, 1)
			end,
			set = function(_, value) setStateTextureField("stateTextureScale", Helper.ClampNumber(value, 0.1, 8, 1)) end,
			formatter = function(value)
				local num = tonumber(value) or 1
				return string.format("%.2fx", num)
			end,
		},
		{
			name = L["CooldownPanelStateTextureWidth"] or "Texture width",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStateTexture",
			minValue = 0.1,
			maxValue = 8,
			valueStep = 0.05,
			allowInput = true,
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampNumber(currentEntry and currentEntry.stateTextureWidth, 0.1, 8, 1)
			end,
			set = function(_, value) setStateTextureField("stateTextureWidth", Helper.ClampNumber(value, 0.1, 8, 1)) end,
			formatter = function(value)
				local num = tonumber(value) or 1
				return string.format("%.2fx", num)
			end,
		},
		{
			name = L["CooldownPanelStateTextureHeight"] or "Texture height",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStateTexture",
			minValue = 0.1,
			maxValue = 8,
			valueStep = 0.05,
			allowInput = true,
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampNumber(currentEntry and currentEntry.stateTextureHeight, 0.1, 8, 1)
			end,
			set = function(_, value) setStateTextureField("stateTextureHeight", Helper.ClampNumber(value, 0.1, 8, 1)) end,
			formatter = function(value)
				local num = tonumber(value) or 1
				return string.format("%.2fx", num)
			end,
		},
		{
			name = L["CooldownPanelStateTextureAngle"] or "Texture angle",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStateTexture",
			minValue = 0,
			maxValue = 360,
			valueStep = 1,
			allowInput = true,
			isShown = function() return isStateTextureSupported() end,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampNumber(currentEntry and currentEntry.stateTextureAngle, 0, 360, 0)
			end,
			set = function(_, value) setStateTextureField("stateTextureAngle", Helper.ClampNumber(value, 0, 360, 0)) end,
			formatter = function(value) return string.format("%d°", math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelStateTextureSpacingX"] or "Texture spacing X",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStateTexture",
			minValue = 0,
			maxValue = Helper.STATE_TEXTURE_SPACING_RANGE or 2000,
			valueStep = 1,
			allowInput = true,
			isShown = function() return isStateTextureSupported() and entryUsesDoubleStateTexture() end,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampInt(currentEntry and currentEntry.stateTextureSpacingX, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)
			end,
			set = function(_, value) setStateTextureField("stateTextureSpacingX", Helper.ClampInt(value, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelStateTextureSpacingY"] or "Texture spacing Y",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneStateTexture",
			minValue = 0,
			maxValue = Helper.STATE_TEXTURE_SPACING_RANGE or 2000,
			valueStep = 1,
			allowInput = true,
			isShown = function() return isStateTextureSupported() and entryUsesDoubleStateTexture() end,
			get = function()
				local _, currentEntry = getEntry()
				return Helper.ClampInt(currentEntry and currentEntry.stateTextureSpacingY, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)
			end,
			set = function(_, value) setStateTextureField("stateTextureSpacingY", Helper.ClampInt(value, 0, Helper.STATE_TEXTURE_SPACING_RANGE or 2000, 0)) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = _G.GLOW or "Glow",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneGlow",
			defaultCollapsed = true,
			isShown = function() return getEffectiveType() ~= "MACRO" end,
		},
		{
			name = (initialEffectiveType == "STANCE" and (_G.GLOW or "Glow"))
				or (initialEffectiveType == "CDM_AURA" and (L["CooldownPanelGlowActive"] or "Glow when active"))
				or (L["CooldownPanelGlowReady"] or "Glow when ready"),
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneGlow",
			isShown = function() return getEffectiveType() ~= "MACRO" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.glowReady == true or false
			end,
			set = function(_, value) setEntryBoolean("glowReady", value) end,
		},
		{
			name = L["CooldownPanelGlowPandemic"] or "Pandemic glow",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneGlow",
			isShown = function() return getEffectiveType() == "CDM_AURA" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.pandemicGlow == true or false
			end,
			set = function(_, value) setEntryBoolean("pandemicGlow", value) end,
		},
		{
			name = L["CooldownPanelOverwriteGlobalDefault"] or "Overwrite global default",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneGlow",
			isShown = function() return getEffectiveType() ~= "MACRO" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.glowUseGlobal == false or false
			end,
			set = function(_, value) setGlowOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelReadyGlowCheckPower"] or "Require resource for ready glow",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneGlow",
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.glowReady == true and currentEntry.glowUseGlobal == false)
			end,
			get = function() return getResolvedReadyGlowCheckPower() == true end,
			set = function(_, value) setEntryBoolean("readyGlowCheckPower", value) end,
		},
		{
			name = L["CooldownPanelOverwritePanelProcGlow"] or "Overwrite panel proc glow",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneGlow",
			isShown = function() return getEffectiveType() == "SPELL" end,
			get = function()
				local _, currentEntry = getEntry()
				return currentEntry and currentEntry.procGlowUseGlobal == false or false
			end,
			set = function(_, value) setProcGlowOverrideEnabled(value) end,
		},
		{
			name = L["CooldownPanelProcGlow"] or "Proc glow",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneGlow",
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.procGlowUseGlobal == false)
			end,
			get = function() return getResolvedProcGlowEnabled() == true end,
			set = setProcGlowEnabled,
		},
		{
			name = L["CooldownPanelProcGlowStyle"] or "Proc glow style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneGlow",
			height = 180,
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.procGlowUseGlobal == false)
			end,
			get = function() return getResolvedProcGlowStyle() end,
			set = setProcGlowStyle,
			generator = function(_, root)
				for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
					local label = L[option.labelKey] or option.fallback
					root:CreateRadio(label, function() return getResolvedProcGlowStyle() == option.value end, function() setProcGlowStyle(nil, option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelProcGlowInset"] or "Proc glow inset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneGlow",
			minValue = -(Helper.GLOW_INSET_RANGE or 20),
			maxValue = Helper.GLOW_INSET_RANGE or 20,
			valueStep = 1,
			allowInput = true,
			isShown = function() return getEffectiveType() == "SPELL" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.procGlowUseGlobal == false)
			end,
			get = function() return getResolvedProcGlowInset() end,
			set = setProcGlowInset,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelGlowStyle"] or "Glow style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneGlow",
			height = 180,
			isShown = function() return getEffectiveType() ~= "MACRO" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and entryUsesConfiguredGlow(currentEntry) and currentEntry.glowUseGlobal == false)
			end,
			get = function() return getResolvedGlowStyle() end,
			set = setGlowStyle,
			generator = function(_, root)
				for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
					local label = L[option.labelKey] or option.fallback
					root:CreateRadio(label, function() return getResolvedGlowStyle() == option.value end, function() setGlowStyle(nil, option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelGlowStylePandemic"] or "Pandemic glow style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneGlow",
			height = 180,
			isShown = function() return getEffectiveType() == "CDM_AURA" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.pandemicGlow == true and currentEntry.glowUseGlobal == false)
			end,
			get = function() return getResolvedPandemicGlowStyle() end,
			set = setPandemicGlowStyle,
			generator = function(_, root)
				for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
					local label = L[option.labelKey] or option.fallback
					root:CreateRadio(label, function() return getResolvedPandemicGlowStyle() == option.value end, function() setPandemicGlowStyle(nil, option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelGlowInset"] or "Glow inset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneGlow",
			minValue = -(Helper.GLOW_INSET_RANGE or 20),
			maxValue = Helper.GLOW_INSET_RANGE or 20,
			valueStep = 1,
			allowInput = true,
			isShown = function() return getEffectiveType() ~= "MACRO" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and entryUsesConfiguredGlow(currentEntry) and currentEntry.glowUseGlobal == false)
			end,
			get = function() return getResolvedGlowInset() end,
			set = setGlowInset,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelGlowInsetPandemic"] or "Pandemic glow inset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneGlow",
			minValue = -(Helper.GLOW_INSET_RANGE or 20),
			maxValue = Helper.GLOW_INSET_RANGE or 20,
			valueStep = 1,
			allowInput = true,
			isShown = function() return getEffectiveType() == "CDM_AURA" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.pandemicGlow == true and currentEntry.glowUseGlobal == false)
			end,
			get = function() return getResolvedPandemicGlowInset() end,
			set = setPandemicGlowInset,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelGlowColorGeneric"] or "Glow color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneGlow",
			hasOpacity = true,
			isShown = function() return getEffectiveType() ~= "MACRO" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and entryUsesConfiguredGlow(currentEntry) and currentEntry.glowUseGlobal == false)
			end,
			get = function()
				local color = getResolvedGlowColor()
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = setGlowColor,
		},
		{
			name = L["CooldownPanelGlowColorPandemic"] or "Pandemic glow color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneGlow",
			hasOpacity = true,
			isShown = function() return getEffectiveType() == "CDM_AURA" end,
			disabled = function()
				local _, currentEntry = getEntry()
				return not (currentEntry and currentEntry.pandemicGlow == true and currentEntry.glowUseGlobal == false)
			end,
			get = function()
				local color = getResolvedPandemicGlowColor()
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value)
				local _, currentEntry = getEntry()
				if not currentEntry then return end
				local fallbackColor = getResolvedGlowColor()
				local normalized = Helper.NormalizeColor(value, fallbackColor)
				if normalized[1] == fallbackColor[1] and normalized[2] == fallbackColor[2] and normalized[3] == fallbackColor[3] and normalized[4] == fallbackColor[4] then
					currentEntry.pandemicGlowColor = nil
				else
					currentEntry.pandemicGlowColor = normalized
				end
				refreshEntryViews()
			end,
		},
		{
			name = L["CooldownPanelSound"] or "Sound",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneSound",
			defaultCollapsed = true,
			isShown = function() return allowsStandaloneEntryReadySound(getEffectiveType()) end,
		},
		{
			name = L["CooldownPanelSoundReady"] or "Sound when ready",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneSound",
			isShown = function() return allowsStandaloneEntryReadySound(getEffectiveType()) end,
			get = function()
				local _, currentEntry = getEntry()
				local _, enabledField = CooldownPanels:GetEntrySoundConfig(currentEntry)
				return currentEntry and enabledField and currentEntry[enabledField] == true or false
			end,
			set = function(_, value)
				local _, currentEntry = getEntry()
				local _, enabledField = CooldownPanels:GetEntrySoundConfig(currentEntry)
				if enabledField then setEntryBoolean(enabledField, value) end
			end,
		},
		{
			name = L["CooldownPanelSound"] or "Sound",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneSound",
			height = 260,
			isShown = function() return allowsStandaloneEntryReadySound(getEffectiveType()) end,
			disabled = function()
				local _, currentEntry = getEntry()
				local _, enabledField = CooldownPanels:GetEntrySoundConfig(currentEntry)
				return not (currentEntry and enabledField and currentEntry[enabledField] == true)
			end,
			get = function()
				local _, currentEntry = getEntry()
				local _, _, soundField = CooldownPanels:GetEntrySoundConfig(currentEntry)
				return normalizeSoundName(currentEntry and soundField and currentEntry[soundField])
			end,
			set = function(_, value) setSoundReadyFile(value) end,
			generator = function(_, root)
				for _, soundName in ipairs(getSoundOptions()) do
					local label = getSoundLabel(soundName)
					root:CreateRadio(label, function()
						local _, currentEntry = getEntry()
						local _, _, soundField = CooldownPanels:GetEntrySoundConfig(currentEntry)
						return normalizeSoundName(currentEntry and soundField and currentEntry[soundField]) == soundName
					end, function() setSoundReadyFile(soundName) end)
				end
			end,
		},
	}

	local buttons = {
		{
			text = L["CooldownPanelRemoveEntry"] or "Remove entry",
			click = function()
				CooldownPanels:HideLayoutEntryStandaloneMenu(panelId)
				CooldownPanels:RemoveEntry(panelId, entryId)
				local editor = getEditor()
				if editor and normalizeId(editor.selectedPanelId) == panelId and normalizeId(editor.selectedEntryId) == entryId then editor.selectedEntryId = nil end
				CooldownPanels:RefreshEditor()
			end,
		},
	}

	local dialog = lib:ShowStandaloneSettingsDialog(hostFrame, {
		title = self:GetEntryStandaloneTitle(entry),
		settings = settings,
		buttons = buttons,
		showReset = false,
		showSettingsReset = false,
		settingsMaxHeight = 520,
		point = spawnPosition.point,
		relativePoint = spawnPosition.relativePoint,
		relativeTo = spawnPosition.relativeTo,
		x = spawnPosition.x,
		y = spawnPosition.y,
		onHide = function() CooldownPanels:ClearLayoutEntryStandaloneMenuState() end,
	})
	if dialog then
		local state = self:GetLayoutEntryStandaloneMenuState()
		state.panelId = panelId
		state.entryId = entryId
		state.hostFrame = hostFrame
		state.dialog = dialog
	end
end

function CooldownPanels:GetLayoutPanelStandaloneMenuState(create)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local state = CooldownPanels.runtime.layoutPanelStandaloneMenu
	if state == nil and create ~= false then
		state = {}
		CooldownPanels.runtime.layoutPanelStandaloneMenu = state
	end
	return state
end

function CooldownPanels:ClearLayoutPanelStandaloneMenuState()
	local state = self:GetLayoutPanelStandaloneMenuState(false)
	if not state then return end
	for key in pairs(state) do
		state[key] = nil
	end
end

function CooldownPanels:IsLayoutPanelStandaloneMenuAvailable(panelId)
	panelId = normalizeId(panelId)
	if not panelId or not self:IsPanelLayoutEditActive(panelId) then return false end
	local runtime = getRuntime(panelId)
	return runtime and runtime.editModeSettings ~= nil or false
end

function CooldownPanels:HideLayoutPanelStandaloneMenu(panelId)
	local lib = addon.EditModeLib
	local state = self:GetLayoutPanelStandaloneMenuState(false)
	local trackedPanelId = normalizeId(state and state.panelId)
	if panelId and trackedPanelId and trackedPanelId ~= normalizeId(panelId) then return false end
	local hostFrame = state and state.hostFrame or (trackedPanelId and getRuntime(trackedPanelId).frame) or nil
	local hidden = false
	if lib and lib.HideStandaloneSettingsDialog then hidden = lib:HideStandaloneSettingsDialog(hostFrame) end
	self:ClearLayoutPanelStandaloneMenuState()
	return hidden
end

function CooldownPanels:RefreshLayoutPanelStandaloneMenu()
	local lib = addon.EditModeLib
	local state = self:GetLayoutPanelStandaloneMenuState(false)
	if not state or not state.hostFrame then return end
	if not (lib and lib.IsStandaloneSettingsDialogShown and lib:IsStandaloneSettingsDialogShown(state.hostFrame)) then
		self:ClearLayoutPanelStandaloneMenuState()
		return
	end
	local panelId = normalizeId(state.panelId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local editor = getEditor()
	local selectedPanelId = normalizeId(editor and editor.selectedPanelId)
	if not panel or not self:IsLayoutPanelStandaloneMenuAvailable(panelId) or selectedPanelId ~= panelId then self:HideLayoutPanelStandaloneMenu(panelId) end
end

function CooldownPanels:OpenLayoutPanelStandaloneMenu(panelId, anchorFrame)
	local lib = addon.EditModeLib
	if not (lib and lib.ShowStandaloneSettingsDialog and SettingType) then return end
	panelId = normalizeId(panelId)
	if not (panelId and self:IsLayoutPanelStandaloneMenuAvailable(panelId)) then return end
	self:HideLayoutEntryStandaloneMenu(panelId)
	self:HideLayoutFixedGroupStandaloneMenu(panelId)

	self:RegisterEditModePanel(panelId)
	local registeredRuntime = getRuntime(panelId)
	local registeredPanel = self:GetPanel(panelId)
	local registeredHostFrame = registeredRuntime and registeredRuntime.frame or nil
	local registeredSettings = registeredRuntime and registeredRuntime.editModeSettings or nil
	if not (registeredPanel and registeredHostFrame and registeredSettings) then return end

	local spawnPosition = self:GetStandaloneDialogSpawnPosition(anchorFrame, registeredHostFrame, 12, 0)
	local dialog = lib:ShowStandaloneSettingsDialog(registeredHostFrame, {
		title = registeredPanel.name or "Cooldown Panel",
		settings = registeredSettings,
		showReset = false,
		showSettingsReset = false,
		settingsMaxHeight = registeredRuntime.editModeSettingsMaxHeight or 620,
		point = spawnPosition.point,
		relativePoint = spawnPosition.relativePoint,
		relativeTo = spawnPosition.relativeTo,
		x = spawnPosition.x,
		y = spawnPosition.y,
		onHide = function() CooldownPanels:ClearLayoutPanelStandaloneMenuState() end,
	})
	if dialog then
		local state = self:GetLayoutPanelStandaloneMenuState()
		state.panelId = panelId
		state.hostFrame = registeredHostFrame
		state.dialog = dialog
	end
end

function CooldownPanels:GetLayoutFixedGroupStandaloneMenuState(create)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local state = CooldownPanels.runtime.layoutFixedGroupStandaloneMenu
	if state == nil and create ~= false then
		state = {}
		CooldownPanels.runtime.layoutFixedGroupStandaloneMenu = state
	end
	return state
end

function CooldownPanels:ClearLayoutFixedGroupStandaloneMenuState()
	local state = self:GetLayoutFixedGroupStandaloneMenuState(false)
	if not state then return end
	for key in pairs(state) do
		state[key] = nil
	end
end

function CooldownPanels:IsLayoutFixedGroupStandaloneMenuAvailable(panelId, groupId)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not (panelId and groupId and self:IsPanelLayoutEditActive(panelId)) then return false end
	local panel = self:GetPanel(panelId)
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	return group ~= nil
end

function CooldownPanels:HideLayoutFixedGroupStandaloneMenu(panelId)
	local lib = addon.EditModeLib
	local state = self:GetLayoutFixedGroupStandaloneMenuState(false)
	local trackedPanelId = normalizeId(state and state.panelId)
	if panelId and trackedPanelId and trackedPanelId ~= normalizeId(panelId) then return false end
	local hostFrame = state and state.hostFrame or (trackedPanelId and getRuntime(trackedPanelId).frame) or nil
	local hidden = false
	if lib and lib.HideStandaloneSettingsDialog then hidden = lib:HideStandaloneSettingsDialog(hostFrame) end
	self:ClearLayoutFixedGroupStandaloneMenuState()
	return hidden
end

function CooldownPanels:RefreshLayoutFixedGroupStandaloneMenu()
	local lib = addon.EditModeLib
	local state = self:GetLayoutFixedGroupStandaloneMenuState(false)
	if not state or not state.hostFrame then return end
	if not (lib and lib.IsStandaloneSettingsDialogShown and lib:IsStandaloneSettingsDialogShown(state.hostFrame)) then
		self:ClearLayoutFixedGroupStandaloneMenuState()
		return
	end
	local panelId = normalizeId(state.panelId)
	local groupId = Helper.NormalizeFixedGroupId(state.groupId)
	local panel = panelId and self:GetPanel(panelId) or nil
	local group = panel and groupId and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	local editor = getEditor()
	local selectedPanelId = normalizeId(editor and editor.selectedPanelId)
	if not group or not self:IsPanelLayoutEditActive(panelId) or selectedPanelId ~= panelId then
		self:HideLayoutFixedGroupStandaloneMenu(panelId)
		return
	end
	local dialog = state.dialog
	if dialog then
		local title = CooldownPanels.GetFixedGroupDisplayLabel(group)
		if dialog.context then dialog.context.title = title end
		if dialog.Title and title then dialog.Title:SetText(title) end
		if dialog.UpdateSettings then dialog:UpdateSettings() end
		if dialog.UpdateButtons then dialog:UpdateButtons() end
		if dialog.Layout then dialog:Layout() end
	end
end

function CooldownPanels:ScheduleLayoutFixedGroupStandaloneMenuRefresh(panelId, groupId)
	local state = self:GetLayoutFixedGroupStandaloneMenuState(false)
	if not state then return end
	if state.refreshPending then return end
	if not (C_Timer and C_Timer.After) then
		self:RefreshLayoutFixedGroupStandaloneMenu()
		return
	end
	state.refreshPending = true
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	C_Timer.After(0, function()
		local currentState = CooldownPanels:GetLayoutFixedGroupStandaloneMenuState(false)
		if currentState then currentState.refreshPending = nil end
		if not currentState then return end
		if normalizeId(currentState.panelId) ~= panelId then return end
		if Helper.NormalizeFixedGroupId(currentState.groupId) ~= groupId then return end
		CooldownPanels:RefreshLayoutFixedGroupStandaloneMenu()
	end)
end

function CooldownPanels:BuildLayoutFixedGroupStandaloneSettings(panelId, groupId)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not (panelId and groupId and SettingType) then return nil end

	local function getPanelAndGroup()
		local panel = CooldownPanels:GetPanel(panelId)
		local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
		return panel, group
	end
	local function getLayout()
		local panel = CooldownPanels:GetPanel(panelId)
		if not panel then return Helper.PANEL_LAYOUT_DEFAULTS end
		return CooldownPanels:GetFixedGroupEffectiveLayout(panelId, groupId) or panel.layout or Helper.PANEL_LAYOUT_DEFAULTS
	end
	local function refresh()
		CooldownPanels:RefreshPanelForCurrentEditContext(panelId, true)
		CooldownPanels:RefreshLayoutFixedGroupStandaloneMenu()
	end
	local function setMode(mode)
		local changed, reason = CooldownPanels:SetFixedGroupMode(panelId, groupId, mode)
		if changed then
			refresh()
		elseif reason == "GROUP_FULL" then
			showErrorMessage(L["CooldownPanelFixedGroupFull"] or "Fixed group is full.")
		end
	end
	local function setOverride(field, value)
		if not CooldownPanels:SetFixedGroupLayoutOverride(panelId, groupId, field, value) then return end
		if field == "iconOffsetX" or field == "iconOffsetY" then
			CooldownPanels:RefreshPanelForCurrentEditContext(panelId, false)
			return
		end
		refresh()
	end

	return {
		{
			name = L["CooldownPanelFixedGroupHeader"] or "Group",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneFixedGroupGeneral",
			defaultCollapsed = false,
		},
		{
			name = L["CooldownPanelRename"] or "Name",
			kind = SettingType.Input,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			labelWidth = 80,
			inputWidth = 220,
			get = function()
				local _, group = getPanelAndGroup()
				return group and CooldownPanels.GetFixedGroupName(group) or ""
			end,
			set = function(_, value)
				local normalized = CooldownPanels.NormalizePanelGroupName(value)
				if normalized and CooldownPanels:RenameFixedGroup(panelId, groupId, normalized) then refresh() end
			end,
			default = "",
			maxChars = 32,
		},
		{
			name = L["CooldownPanelMode"] or "Mode",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			height = 80,
			get = function()
				local _, group = getPanelAndGroup()
				return group and CooldownPanels.GetFixedGroupMode(group) or "DYNAMIC"
			end,
			set = function(_, value) setMode(value) end,
			generator = function(_, root)
				root:CreateRadio(L["CooldownPanelDynamic"] or "Dynamic", function()
					local _, group = getPanelAndGroup()
					return not CooldownPanels.IsFixedGroupStatic(group)
				end, function() setMode("DYNAMIC") end)
				root:CreateRadio(L["CooldownPanelStatic"] or "Static", function()
					local _, group = getPanelAndGroup()
					return CooldownPanels.IsFixedGroupStatic(group)
				end, function() setMode("STATIC") end)
			end,
		},
		{
			name = L["CooldownPanelStartPoint"] or "Start point",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			height = 120,
			disabled = function()
				local _, group = getPanelAndGroup()
				return group == nil or CooldownPanels.IsFixedGroupStatic(group)
			end,
			get = function()
				local _, group = getPanelAndGroup()
				return Helper.NormalizeFixedGroupStartPoint(group and group.dynamicStartPoint, "TOPLEFT")
			end,
			set = function(_, value)
				if CooldownPanels:SetFixedGroupDynamicStartPoint(panelId, groupId, value) then refresh() end
			end,
			generator = function(_, root)
				local _, group = getPanelAndGroup()
				local current = Helper.NormalizeFixedGroupStartPoint(group and group.dynamicStartPoint, "TOPLEFT")
				for _, option in ipairs(Helper.FixedGroupStartPointOptions or {}) do
					root:CreateRadio(option.label, function() return current == option.value end, function()
						if CooldownPanels:SetFixedGroupDynamicStartPoint(panelId, groupId, option.value) then refresh() end
					end)
				end
			end,
		},
		{
			name = L["CooldownPanelGrowthDirection"] or "Growth direction",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			height = 90,
			disabled = function()
				local _, group = getPanelAndGroup()
				return group == nil or CooldownPanels.IsFixedGroupStatic(group)
			end,
			get = function()
				local _, group = getPanelAndGroup()
				local startPoint = Helper.NormalizeFixedGroupStartPoint(group and group.dynamicStartPoint, "TOPLEFT")
				return Helper.NormalizeFixedGroupDynamicDirection(startPoint, group and group.dynamicDirection, nil)
			end,
			set = function(_, value)
				if CooldownPanels:SetFixedGroupDynamicDirection(panelId, groupId, value) then refresh() end
			end,
			generator = function(_, root)
				local _, group = getPanelAndGroup()
				local startPoint = Helper.NormalizeFixedGroupStartPoint(group and group.dynamicStartPoint, "TOPLEFT")
				local current = Helper.NormalizeFixedGroupDynamicDirection(startPoint, group and group.dynamicDirection, nil)
				for _, option in ipairs(Helper.GetFixedGroupDynamicDirectionOptions(startPoint)) do
					root:CreateRadio(option.label, function() return current == option.value end, function()
						if CooldownPanels:SetFixedGroupDynamicDirection(panelId, groupId, option.value) then refresh() end
					end)
				end
			end,
		},
		{
			name = L["CooldownPanelIconOffsetX"] or "Icon X",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			minValue = -(Helper.OFFSET_RANGE or 200),
			maxValue = Helper.OFFSET_RANGE or 200,
			valueStep = 1,
			allowInput = true,
			get = function()
				local layout = getLayout()
				return Helper.ClampInt(layout and layout.iconOffsetX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
			end,
			set = function(_, value) setOverride("iconOffsetX", value) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelIconOffsetY"] or "Icon Y",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			minValue = -(Helper.OFFSET_RANGE or 200),
			maxValue = Helper.OFFSET_RANGE or 200,
			valueStep = 1,
			allowInput = true,
			get = function()
				local layout = getLayout()
				return Helper.ClampInt(layout and layout.iconOffsetY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
			end,
			set = function(_, value) setOverride("iconOffsetY", value) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelUseCustomIconSize"] or "Use custom icon size",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			get = function()
				local _, group = getPanelAndGroup()
				return group and Helper.NormalizeFixedGroupIconSize(group.iconSize) ~= nil or false
			end,
			set = function(_, value)
				local panel, group = getPanelAndGroup()
				if not (panel and group) then return end
				local nextSize = nil
				if value == true then
					nextSize = Helper.NormalizeFixedGroupIconSize(group.iconSize) or Helper.ClampInt(panel.layout and panel.layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
				end
				if CooldownPanels:SetFixedGroupIconSize(panelId, groupId, nextSize) then refresh() end
			end,
		},
		{
			name = L["CooldownPanelIconSize"] or "Icon size",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneFixedGroupGeneral",
			minValue = 12,
			maxValue = 128,
			valueStep = 1,
			allowInput = true,
			disabled = function()
				local _, group = getPanelAndGroup()
				return not (group and Helper.NormalizeFixedGroupIconSize(group.iconSize) ~= nil)
			end,
			get = function()
				local panel, group = getPanelAndGroup()
				local fallback = Helper.ClampInt(panel and panel.layout and panel.layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
				return group and (Helper.NormalizeFixedGroupIconSize(group.iconSize) or fallback) or fallback
			end,
			set = function(_, value)
				if CooldownPanels:SetFixedGroupIconSize(panelId, groupId, value) then refresh() end
			end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = _G.GLOW or "Glow",
			kind = SettingType.Collapsible,
			id = "cooldownPanelStandaloneFixedGroupGlow",
			defaultCollapsed = false,
		},
		{
			name = L["CooldownPanelProcGlow"] or "Proc glow",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			get = function()
				local layout = getLayout()
				return CooldownPanels:ResolveEntryProcGlowEnabled(layout, nil)
			end,
			set = function(_, value) setOverride("procGlowEnabled", value) end,
		},
		{
			name = L["CooldownPanelHideGlowOutOfCombat"] or "Hide glow out of combat",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			get = function()
				local layout = getLayout()
				return layout and layout.hideGlowOutOfCombat == true or false
			end,
			set = function(_, value) setOverride("hideGlowOutOfCombat", value) end,
		},
		{
			name = L["CooldownPanelProcGlowStyle"] or "Proc glow style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			height = 180,
			get = function()
				local layout = getLayout()
				return select(1, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil))
			end,
			set = function(_, value) setOverride("procGlowStyle", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
					local label = L[option.labelKey] or option.fallback
					root:CreateRadio(label, function()
						local layout = getLayout()
						return select(1, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)) == option.value
					end, function() setOverride("procGlowStyle", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelProcGlowInset"] or "Proc glow inset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			minValue = -(Helper.GLOW_INSET_RANGE or 20),
			maxValue = Helper.GLOW_INSET_RANGE or 20,
			valueStep = 1,
			allowInput = true,
			get = function()
				local layout = getLayout()
				return select(2, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil))
			end,
			set = function(_, value) setOverride("procGlowInset", value) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelReadyGlowCheckPower"] or "Require resource for ready glow",
			kind = SettingType.Checkbox,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			get = function()
				local layout = getLayout()
				return CooldownPanels:ResolveEntryReadyGlowCheckPower(layout, nil)
			end,
			set = function(_, value) setOverride("readyGlowCheckPower", value) end,
		},
		{
			name = L["CooldownPanelGlowStyle"] or "Glow style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			height = 180,
			get = function()
				local layout = getLayout()
				return select(3, CooldownPanels:ResolveEntryGlowStyle(layout, nil))
			end,
			set = function(_, value) setOverride("readyGlowStyle", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
					local label = L[option.labelKey] or option.fallback
					root:CreateRadio(label, function()
						local layout = getLayout()
						return select(3, CooldownPanels:ResolveEntryGlowStyle(layout, nil)) == option.value
					end, function() setOverride("readyGlowStyle", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelGlowInset"] or "Glow inset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			minValue = -(Helper.GLOW_INSET_RANGE or 20),
			maxValue = Helper.GLOW_INSET_RANGE or 20,
			valueStep = 1,
			allowInput = true,
			get = function()
				local layout = getLayout()
				return select(4, CooldownPanels:ResolveEntryGlowStyle(layout, nil))
			end,
			set = function(_, value) setOverride("readyGlowInset", value) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelGlowColor"] or "Ready glow color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			hasOpacity = true,
			get = function()
				local layout = getLayout()
				local color = select(2, CooldownPanels:ResolveEntryGlowStyle(layout, nil))
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value) setOverride("readyGlowColor", value) end,
		},
		{
			name = L["CooldownPanelGlowStylePandemic"] or "Pandemic glow style",
			kind = SettingType.Dropdown,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			height = 180,
			get = function()
				local layout = getLayout()
				return select(2, CooldownPanels:ResolveEntryPandemicGlowVisual(layout, nil))
			end,
			set = function(_, value) setOverride("pandemicGlowStyle", value) end,
			generator = function(_, root)
				for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
					local label = L[option.labelKey] or option.fallback
					root:CreateRadio(label, function()
						local layout = getLayout()
						return select(2, CooldownPanels:ResolveEntryPandemicGlowVisual(layout, nil)) == option.value
					end, function() setOverride("pandemicGlowStyle", option.value) end)
				end
			end,
		},
		{
			name = L["CooldownPanelGlowInsetPandemic"] or "Pandemic glow inset",
			kind = SettingType.Slider,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			minValue = -(Helper.GLOW_INSET_RANGE or 20),
			maxValue = Helper.GLOW_INSET_RANGE or 20,
			valueStep = 1,
			allowInput = true,
			get = function()
				local layout = getLayout()
				return select(3, CooldownPanels:ResolveEntryPandemicGlowVisual(layout, nil))
			end,
			set = function(_, value) setOverride("pandemicGlowInset", value) end,
			formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
		},
		{
			name = L["CooldownPanelGlowColorPandemic"] or "Pandemic glow color",
			kind = SettingType.Color,
			parentId = "cooldownPanelStandaloneFixedGroupGlow",
			hasOpacity = true,
			get = function()
				local layout = getLayout()
				local color = select(1, CooldownPanels:ResolveEntryPandemicGlowVisual(layout, nil))
				return { r = color[1], g = color[2], b = color[3], a = color[4] }
			end,
			set = function(_, value) setOverride("pandemicGlowColor", value) end,
		},
	}
end

function CooldownPanels:OpenLayoutFixedGroupStandaloneMenu(panelId, groupId, anchorFrame)
	local lib = addon.EditModeLib
	if not (lib and lib.ShowStandaloneSettingsDialog and SettingType) then return end
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not self:IsLayoutFixedGroupStandaloneMenuAvailable(panelId, groupId) then return end
	self:HideLayoutEntryStandaloneMenu(panelId)
	self:HideLayoutPanelStandaloneMenu(panelId)
	self:HideLayoutFixedGroupStandaloneMenu(panelId)

	local panel = self:GetPanel(panelId)
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	local runtime = getRuntime(panelId)
	local hostFrame = runtime and runtime.frame or nil
	local settings = self:BuildLayoutFixedGroupStandaloneSettings(panelId, groupId)
	if not (group and hostFrame and settings) then return end

	local spawnPosition = self:GetStandaloneDialogSpawnPosition(anchorFrame, hostFrame, 12, 0)
	local buttons = {
		{
			text = DELETE or "Delete",
			click = function()
				local currentPanel = CooldownPanels:GetPanel(panelId)
				local currentGroup = currentPanel and CooldownPanels.GetFixedGroupById(currentPanel, groupId) or nil
				local groupName = currentGroup and CooldownPanels.GetFixedGroupName(currentGroup) or nil
				CooldownPanels:HideLayoutFixedGroupStandaloneMenu(panelId)
				CooldownPanels:EnsureFixedGroupDeletePopup()
				StaticPopup_Show("EQOL_COOLDOWN_PANEL_FIXED_GROUP_DELETE", groupName, nil, { panelId = panelId, groupId = groupId })
			end,
		},
	}
	local dialog = lib:ShowStandaloneSettingsDialog(hostFrame, {
		title = CooldownPanels.GetFixedGroupDisplayLabel(group),
		settings = settings,
		buttons = buttons,
		showReset = false,
		showSettingsReset = false,
		settingsMaxHeight = 560,
		point = spawnPosition.point,
		relativePoint = spawnPosition.relativePoint,
		relativeTo = spawnPosition.relativeTo,
		x = spawnPosition.x,
		y = spawnPosition.y,
		onHide = function() CooldownPanels:ClearLayoutFixedGroupStandaloneMenuState() end,
	})
	if dialog then
		local state = self:GetLayoutFixedGroupStandaloneMenuState()
		state.panelId = panelId
		state.groupId = groupId
		state.hostFrame = hostFrame
		state.dialog = dialog
		self:ScheduleLayoutFixedGroupStandaloneMenuRefresh(panelId, groupId)
	end
end

getEditor = function()
	local runtime = CooldownPanels.runtime and CooldownPanels.runtime["editor"]
	return runtime and runtime.editor or nil
end

local function applyEditorPosition(frame)
	if not frame or not addon or not addon.db then return end
	local point = addon.db.cooldownPanelsEditorPoint
	local x = addon.db.cooldownPanelsEditorX
	local y = addon.db.cooldownPanelsEditorY
	if not point or x == nil or y == nil then return end
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, point, x, y)
end

local function saveEditorPosition(frame)
	if not frame or not addon or not addon.db then return end
	local point, _, _, x, y = frame:GetPoint()
	if not point or x == nil or y == nil then return end
	addon.db.cooldownPanelsEditorPoint = point
	addon.db.cooldownPanelsEditorX = x
	addon.db.cooldownPanelsEditorY = y
end

function CooldownPanels:IsEditorFrameTooFarOffscreen(frame)
	if not (frame and UIParent and frame.GetLeft and frame.GetRight and frame.GetTop and frame.GetBottom) then return false end
	local left = frame:GetLeft()
	local right = frame:GetRight()
	local top = frame:GetTop()
	local bottom = frame:GetBottom()
	if not (left and right and top and bottom) then return false end
	local screenWidth = UIParent:GetWidth() or 0
	local screenHeight = UIParent:GetHeight() or 0
	if screenWidth <= 0 or screenHeight <= 0 then return false end
	local visibleLeft = math.max(left, 0)
	local visibleRight = math.min(right, screenWidth)
	local visibleBottom = math.max(bottom, 0)
	local visibleTop = math.min(top, screenHeight)
	local visibleWidth = visibleRight - visibleLeft
	local visibleHeight = visibleTop - visibleBottom
	local frameWidth = frame:GetWidth() or 0
	local frameHeight = frame:GetHeight() or 0
	local minVisibleWidth = math.min(frameWidth, math.max(160, math.floor(frameWidth * 0.25)))
	local minVisibleHeight = math.min(frameHeight, math.max(60, math.floor(frameHeight * 0.15)))
	return visibleWidth < minVisibleWidth or visibleHeight < minVisibleHeight
end

function CooldownPanels:ResetEditorPosition(frame)
	if not (frame and UIParent) then return end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	saveEditorPosition(frame)
end

function CooldownPanels:EnsureEditorFramePosition(frame)
	if not (frame and UIParent) then return end
	if frame:GetNumPoints() == 0 then frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	if self:IsEditorFrameTooFarOffscreen(frame) then self:ResetEditorPosition(frame) end
end

local ensureDeletePopup
local ensureCopyPopup

function CooldownPanels:SyncEditModeDataFromPanel(panelId, editModeId)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = self.runtime and self.runtime[panelId]
	local id = editModeId or (runtime and runtime.editModeId)
	if not (id and EditMode and EditMode.EnsureLayoutData and EditMode.GetActiveLayoutName) then return end

	local anchor = ensurePanelAnchor(panel)
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	local layoutName = EditMode:GetActiveLayoutName()
	local data = EditMode:EnsureLayoutData(id, layoutName)
	if not data then return end

	if anchor then
		local point = anchor.point or panel.point or "CENTER"
		local relativePoint = anchor.relativePoint or point
		local x = anchor.x or 0
		local y = anchor.y or 0
		data.point = point
		data.relativePoint = relativePoint
		data.x = x
		data.y = y
		if EditMode.SetValue then
			EditMode:SetValue(id, "point", point, layoutName, true)
			EditMode:SetValue(id, "relativePoint", relativePoint, layoutName, true)
			EditMode:SetValue(id, "x", x, layoutName, true)
			EditMode:SetValue(id, "y", y, layoutName, true)
		end
	end

	local baseIconSize = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
	data.iconSize = layout.iconSize
	data.spacing = layout.spacing
	data.layoutMode = Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode)
	data.fixedSlotCount = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0)
	data.fixedGridRows = Helper.NormalizeFixedGridSize(layout.fixedGridRows, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0)
	data.direction = Helper.NormalizeDirection(layout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction)
	data.wrapCount = layout.wrapCount or 0
	data.wrapDirection = Helper.NormalizeDirection(layout.wrapDirection, Helper.PANEL_LAYOUT_DEFAULTS.wrapDirection or "DOWN")
	data.rowSize1 = (layout.rowSizes and layout.rowSizes[1]) or baseIconSize
	data.rowSize2 = (layout.rowSizes and layout.rowSizes[2]) or baseIconSize
	data.rowSize3 = (layout.rowSizes and layout.rowSizes[3]) or baseIconSize
	data.rowSize4 = (layout.rowSizes and layout.rowSizes[4]) or baseIconSize
	data.rowSize5 = (layout.rowSizes and layout.rowSizes[5]) or baseIconSize
	data.rowSize6 = (layout.rowSizes and layout.rowSizes[6]) or baseIconSize
	data.growthPoint = Helper.NormalizeGrowthPoint(layout.growthPoint, Helper.PANEL_LAYOUT_DEFAULTS.growthPoint)
	data.radialRadius = Helper.ClampInt(layout.radialRadius, 0, Helper.RADIAL_RADIUS_RANGE or 600, Helper.PANEL_LAYOUT_DEFAULTS.radialRadius)
	data.radialRotation = Helper.ClampNumber(layout.radialRotation, -(Helper.RADIAL_ROTATION_RANGE or 360), Helper.RADIAL_ROTATION_RANGE or 360, Helper.PANEL_LAYOUT_DEFAULTS.radialRotation)
	data.radialArcDegrees = Helper.ClampInt(layout.radialArcDegrees, Helper.RADIAL_ARC_DEGREES_MIN or 15, Helper.RADIAL_ARC_DEGREES_MAX or 360, Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360)
	data.rangeOverlayEnabled = layout.rangeOverlayEnabled == true
	data.rangeOverlayColor = layout.rangeOverlayColor or Helper.PANEL_LAYOUT_DEFAULTS.rangeOverlayColor
	data.noDesaturation = layout.noDesaturation == true
	data.cdmAuraAlwaysShowMode = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, nil)
	data.hideGlowOutOfCombat = layout.hideGlowOutOfCombat == true
	data.readyGlowCheckPower = layout.readyGlowCheckPower == true
	data.checkPower = layout.checkPower == true
	data.powerTintColor = layout.powerTintColor or Helper.PANEL_LAYOUT_DEFAULTS.powerTintColor
	data.strata = Helper.NormalizeStrata(layout.strata, Helper.PANEL_LAYOUT_DEFAULTS.strata)
	data.stackAnchor = Helper.NormalizeAnchor(layout.stackAnchor, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor)
	data.stackX = layout.stackX or Helper.PANEL_LAYOUT_DEFAULTS.stackX
	data.stackY = layout.stackY or Helper.PANEL_LAYOUT_DEFAULTS.stackY
	data.stackFont = layout.stackFont or data.stackFont
	data.stackFontSize = layout.stackFontSize or data.stackFontSize
	data.stackFontStyle = Helper.NormalizeFontStyleChoice(layout.stackFontStyle, data.stackFontStyle)
	data.stackColor = Helper.NormalizeColor(layout.stackColor, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
	data.chargesAnchor = Helper.NormalizeAnchor(layout.chargesAnchor, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor)
	data.chargesX = layout.chargesX or Helper.PANEL_LAYOUT_DEFAULTS.chargesX
	data.chargesY = layout.chargesY or Helper.PANEL_LAYOUT_DEFAULTS.chargesY
	data.chargesFont = layout.chargesFont or data.chargesFont
	data.chargesFontSize = layout.chargesFontSize or data.chargesFontSize
	data.chargesFontStyle = Helper.NormalizeFontStyleChoice(layout.chargesFontStyle, data.chargesFontStyle)
	data.chargesColor = Helper.NormalizeColor(layout.chargesColor, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
	data.chargesHideWhenZero = layout.chargesHideWhenZero == true
	data.keybindsEnabled = layout.keybindsEnabled == true
	data.keybindsIgnoreItems = layout.keybindsIgnoreItems == true
	data.keybindAnchor = Helper.NormalizeAnchor(layout.keybindAnchor, Helper.PANEL_LAYOUT_DEFAULTS.keybindAnchor)
	data.keybindX = layout.keybindX or Helper.PANEL_LAYOUT_DEFAULTS.keybindX
	data.keybindY = layout.keybindY or Helper.PANEL_LAYOUT_DEFAULTS.keybindY
	data.keybindFont = layout.keybindFont or data.keybindFont
	data.keybindFontSize = layout.keybindFontSize or data.keybindFontSize
	data.keybindFontStyle = Helper.NormalizeFontStyleChoice(layout.keybindFontStyle, data.keybindFontStyle)
	data.cooldownDrawEdge = layout.cooldownDrawEdge ~= false
	data.cooldownDrawBling = layout.cooldownDrawBling ~= false
	data.cooldownDrawSwipe = layout.cooldownDrawSwipe ~= false
	data.showChargesCooldown = layout.showChargesCooldown == true
	data.cooldownGcdDrawEdge = layout.cooldownGcdDrawEdge == true
	data.cooldownGcdDrawBling = layout.cooldownGcdDrawBling == true
	data.cooldownGcdDrawSwipe = layout.cooldownGcdDrawSwipe == true
	data.opacityOutOfCombat = Helper.NormalizeOpacity(layout.opacityOutOfCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityOutOfCombat)
	data.opacityInCombat = Helper.NormalizeOpacity(layout.opacityInCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityInCombat)
	data.showTooltips = layout.showTooltips == true
	data.showIconTexture = layout.showIconTexture ~= false
	data.iconBorderEnabled = layout.iconBorderEnabled == true
	data.iconBorderTexture = normalizeIconBorderTexture(layout.iconBorderTexture, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderTexture)
	data.iconBorderSize = Helper.ClampInt(layout.iconBorderSize, 1, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderSize)
	data.iconBorderOffset = Helper.ClampInt(layout.iconBorderOffset, -64, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderOffset)
	data.iconBorderColor = layout.iconBorderColor or Helper.PANEL_LAYOUT_DEFAULTS.iconBorderColor
	data.hideOnCooldown = layout.hideOnCooldown == true
	data.showOnCooldown = layout.showOnCooldown == true
	data.visibility = PanelVisibility.CopySelectionMap(PanelVisibility.NormalizeConfig(layout.visibility))
	data.cooldownTextFont = layout.cooldownTextFont or data.cooldownTextFont
	data.cooldownTextSize = layout.cooldownTextSize or data.cooldownTextSize
	data.cooldownTextStyle = Helper.NormalizeFontStyleChoice(layout.cooldownTextStyle, data.cooldownTextStyle)
	data.cooldownTextColor = Helper.NormalizeColor(layout.cooldownTextColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)
	data.cooldownTextX = layout.cooldownTextX or 0
	data.cooldownTextY = layout.cooldownTextY or 0
end

local function copyPanelSettings(targetPanelId, sourcePanelId)
	local root = ensureRoot()
	if not root or not root.panels then return false end
	local target = root.panels[targetPanelId]
	local source = root.panels[sourcePanelId]
	if not target or not source then return false end

	local function replaceTableContents(dst, src)
		if type(dst) ~= "table" then dst = {} end
		if wipe then
			wipe(dst)
		else
			for key in pairs(dst) do
				dst[key] = nil
			end
		end
		if type(src) == "table" then
			for key, value in pairs(src) do
				dst[key] = value
			end
		end
		return dst
	end

	local copier = CopyTable or Helper.CopyTableShallow
	target.layout = replaceTableContents(target.layout, copier(source.layout or {}))
	target.anchor = replaceTableContents(target.anchor, copier(source.anchor or {}))
	target.point = source.point
	target.x = source.x
	target.y = source.y

	Helper.NormalizePanel(target, root.defaults)
	CooldownPanels.MarkRelativeFrameEntriesDirty()
	CooldownPanels:RebuildSpellIndex()
	CooldownPanels:ApplyPanelPosition(targetPanelId)
	local runtime = CooldownPanels.runtime and CooldownPanels.runtime[targetPanelId]
	CooldownPanels:SyncEditModeDataFromPanel(targetPanelId, runtime and runtime.editModeId)
	refreshEditModePanelFrame(targetPanelId, runtime and runtime.editModeId)
	refreshEditModeSettings()
	refreshEditModeSettingValues()
	CooldownPanels:RefreshPanel(targetPanelId)
	CooldownPanels:RefreshEditor()
	return true
end

local function applySettingsIcon(texture)
	if not texture then return end
	local source = QuestScrollFrame and QuestScrollFrame.SettingsDropdown and QuestScrollFrame.SettingsDropdown.icon
	if source then
		local atlas = source.GetAtlas and source:GetAtlas()
		if atlas and atlas ~= "" then
			if texture.SetAtlas then texture:SetAtlas(atlas, true) end
			return
		end
		local tex = source.GetTexture and source:GetTexture()
		if tex then
			texture:SetTexture(tex)
			return
		end
	end
	texture:SetTexture("Interface\\Buttons\\UI-OptionsButton")
end

local function ensureEditor()
	local runtime = getRuntime("editor")
	if runtime.editor then return runtime.editor end

	local frame = CreateFrame("Frame", "EQOL_CooldownPanelsEditor", UIParent, "BackdropTemplate")
	frame:SetSize(980, 560)
	frame:SetPoint("CENTER")
	applyEditorPosition(frame)
	frame:SetClampedToScreen(false)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetFrameStrata("DIALOG")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		saveEditorPosition(self)
	end)
	frame:Hide()

	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 10)
	frame.bg:SetTexture("Interface\\AddOns\\EnhanceQoL\\Assets\\background_dark.tga")
	frame.bg:SetAlpha(0.9)
	applyPanelBorder(frame)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -12)
	frame.title:SetText(L["CooldownPanelEditor"] or "Cooldown Panel Editor")
	frame.title:SetFont((addon.variables and addon.variables.defaultFont) or frame.title:GetFont(), 16, "OUTLINE")

	frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.subtitle:SetPoint("TOP", frame, "TOP", 0, -12)
	frame.subtitle:SetJustifyH("CENTER")
	frame.subtitle:SetText(L["CooldownPanelEditModeHeader"] or "Configure the Panels in Edit Mode")
	frame.subtitle:SetTextColor(0.8, 0.8, 0.8, 1)

	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 20, 13)
	frame.close:SetScript("OnClick", function() frame:Hide() end)

	local left = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	left:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -44)
	left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 16)
	left:SetWidth(220)
	left.bg = left:CreateTexture(nil, "BACKGROUND")
	left.bg:SetAllPoints(left)
	left.bg:SetTexture("Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga")
	left.bg:SetAlpha(0.85)
	applyInsetBorder(left, -4)
	frame.left = left

	local panelTitle = Helper.CreateLabel(left, L["CooldownPanelPanels"] or "Panels", 12, "OUTLINE")
	panelTitle:SetPoint("TOPLEFT", left, "TOPLEFT", 12, -12)

	if addon.db and addon.db.cooldownPanelsFilterClass == nil then addon.db.cooldownPanelsFilterClass = false end
	if addon.db and addon.db.cooldownPanelsHideEmptyGroups == nil then addon.db.cooldownPanelsHideEmptyGroups = false end
	local filterButton = CreateFrame("Button", nil, left)
	filterButton:SetSize(18, 18)
	filterButton:SetPoint("TOPRIGHT", left, "TOPRIGHT", -10, -10)
	filterButton.icon = filterButton:CreateTexture(nil, "ARTWORK")
	filterButton.icon:SetAllPoints(filterButton)
	filterButton.icon:SetAlpha(0.9)
	applySettingsIcon(filterButton.icon)
	filterButton.highlight = filterButton:CreateTexture(nil, "HIGHLIGHT")
	filterButton.highlight:SetAllPoints(filterButton)
	filterButton.highlight:SetColorTexture(1, 1, 1, 0.12)
	filterButton:SetScript("OnClick", function(self) showPanelFilterMenu(self) end)

	local panelScroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
	panelScroll:SetPoint("TOPLEFT", panelTitle, "BOTTOMLEFT", 0, -8)
	panelScroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -26, 72)
	local panelContent = CreateFrame("Frame", nil, panelScroll)
	panelContent:SetSize(1, 1)
	panelScroll:SetScrollChild(panelContent)
	panelContent:SetWidth(panelScroll:GetWidth() or 1)
	panelScroll:SetScript("OnSizeChanged", function(self) panelContent:SetWidth(self:GetWidth() or 1) end)

	local addGroup = Helper.CreateButton(left, L["CooldownPanelAddGroup"] or "Add Group", 96, 22)
	addGroup:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 12, 40)

	local addPanel = Helper.CreateButton(left, L["CooldownPanelAddPanel"] or "Add Panel", 96, 22)
	addPanel:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 12, 12)

	local deletePanel = Helper.CreateButton(left, L["CooldownPanelDeletePanel"] or "Delete Panel", 96, 22)
	deletePanel:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -12, 12)

	local right = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -44)
	right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
	right:SetWidth(260)
	right.bg = right:CreateTexture(nil, "BACKGROUND")
	right.bg:SetAllPoints(right)
	right.bg:SetTexture("Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga")
	right.bg:SetAlpha(0.85)
	applyInsetBorder(right, -4)
	frame.right = right

	local rightScroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
	rightScroll:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -10)
	rightScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -28, 12)
	local rightContent = CreateFrame("Frame", nil, rightScroll)
	rightContent:SetSize(1, 1)
	rightScroll:SetScrollChild(rightContent)
	rightContent:SetWidth(rightScroll:GetWidth() or 1)
	rightScroll:SetScript("OnSizeChanged", function(self) rightContent:SetWidth(self:GetWidth() or 1) end)

	local panelHeader = Helper.CreateLabel(rightContent, L["CooldownPanelPanels"] or "Panels", 12, "OUTLINE")
	panelHeader:SetPoint("TOPLEFT", rightContent, "TOPLEFT", 2, -2)
	panelHeader:SetTextColor(0.9, 0.9, 0.9, 1)

	local panelNameLabel = Helper.CreateLabel(rightContent, L["CooldownPanelPanelName"] or "Panel name", 11, "OUTLINE")
	panelNameLabel:SetPoint("TOPLEFT", panelHeader, "BOTTOMLEFT", 0, -8)
	panelNameLabel:SetTextColor(0.9, 0.9, 0.9, 1)

	local panelNameBox = Helper.CreateEditBox(rightContent, 200, 20)
	panelNameBox:SetPoint("TOPLEFT", panelNameLabel, "BOTTOMLEFT", 0, -4)

	local panelEnabled = Helper.CreateCheck(rightContent, L["CooldownPanelEnabled"] or "Enabled")
	panelEnabled:SetPoint("TOPLEFT", panelNameBox, "BOTTOMLEFT", -2, -6)

	local panelSpecLabel = Helper.CreateLabel(rightContent, L["CooldownPanelSpecFilter"] or "Show only for spec", 11, "OUTLINE")
	panelSpecLabel:SetPoint("TOPLEFT", panelEnabled, "BOTTOMLEFT", 2, -8)
	panelSpecLabel:SetTextColor(0.9, 0.9, 0.9, 1)

	local panelSpecButton = Helper.CreateButton(rightContent, L["CooldownPanelSpecAny"] or "All specs", 200, 20)
	panelSpecButton:SetPoint("TOPLEFT", panelSpecLabel, "BOTTOMLEFT", 0, -4)

	local entryHeader = Helper.CreateLabel(rightContent, L["CooldownPanelEntry"] or "Entry", 12, "OUTLINE")
	entryHeader:SetPoint("TOPLEFT", panelSpecButton, "BOTTOMLEFT", 2, -16)
	entryHeader:SetTextColor(0.9, 0.9, 0.9, 1)

	local entryEmptyHint = rightContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	entryEmptyHint:SetPoint("TOPLEFT", entryHeader, "BOTTOMLEFT", 2, -8)
	entryEmptyHint:SetWidth(200)
	entryEmptyHint:SetJustifyH("LEFT")
	entryEmptyHint:SetJustifyV("TOP")
	if entryEmptyHint.SetWordWrap then entryEmptyHint:SetWordWrap(true) end
	entryEmptyHint:SetText(L["CooldownPanelSelectEntryHint"] or "Click a spell/item/macro/slot/stance to modify")
	entryEmptyHint:SetTextColor(0.75, 0.75, 0.75, 1)
	entryEmptyHint:Hide()

	local entryIcon = rightContent:CreateTexture(nil, "ARTWORK")
	entryIcon:SetSize(36, 36)
	entryIcon:SetPoint("TOPLEFT", entryHeader, "BOTTOMLEFT", 0, -6)
	entryIcon:SetTexture(Helper.PREVIEW_ICON)

	local entryName = rightContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	entryName:SetPoint("LEFT", entryIcon, "RIGHT", 8, 8)
	entryName:SetWidth(180)
	entryName:SetJustifyH("LEFT")
	entryName:SetTextColor(1, 1, 1, 1)

	local entryType = rightContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	entryType:SetPoint("TOPLEFT", entryName, "BOTTOMLEFT", 0, -2)
	entryType:SetJustifyH("LEFT")

	local entryIdBox = Helper.CreateEditBox(rightContent, 120, 20)
	entryIdBox:SetPoint("TOPLEFT", entryIcon, "BOTTOMLEFT", 0, -8)
	entryIdBox:SetNumeric(true)

	local cbCooldownText = Helper.CreateCheck(rightContent, L["CooldownPanelShowCooldownText"] or "Show cooldown text")
	cbCooldownText:SetPoint("TOPLEFT", entryIdBox, "BOTTOMLEFT", -2, -6)

	local cbAlwaysShow = Helper.CreateCheck(rightContent, L["CooldownPanelAlwaysShow"] or "Always show")
	cbAlwaysShow:SetPoint("TOPLEFT", cbCooldownText, "BOTTOMLEFT", 0, -4)

	local cbCharges = Helper.CreateCheck(rightContent, L["CooldownPanelShowCharges"] or "Show charges")
	cbCharges:SetPoint("TOPLEFT", cbCooldownText, "BOTTOMLEFT", 0, -4)

	local cbStacks = Helper.CreateCheck(rightContent, L["CooldownPanelShowStacks"] or "Show stack count")
	cbStacks:SetPoint("TOPLEFT", cbCharges, "BOTTOMLEFT", 0, -4)

	local cbItemCount = Helper.CreateCheck(rightContent, L["CooldownPanelShowItemCount"] or "Show item count")
	cbItemCount:SetPoint("TOPLEFT", cbCooldownText, "BOTTOMLEFT", 0, -4)

	local cbItemUses = Helper.CreateCheck(rightContent, L["CooldownPanelShowItemUses"] or "Show item uses")
	cbItemUses:SetPoint("TOPLEFT", cbItemCount, "BOTTOMLEFT", 0, -4)

	local cbUseHighestRank = Helper.CreateCheck(rightContent, L["CooldownPanelUseHighestRank"] or "Use highest rank")
	cbUseHighestRank:SetPoint("TOPLEFT", cbItemUses, "BOTTOMLEFT", 0, -4)

	local cbShowWhenEmpty = Helper.CreateCheck(rightContent, L["CooldownPanelShowWhenEmpty"] or "Show when empty")
	cbShowWhenEmpty:SetPoint("TOPLEFT", cbUseHighestRank, "BOTTOMLEFT", 0, -4)

	local cbShowWhenNoCooldown = Helper.CreateCheck(rightContent, L["CooldownPanelShowWhenNoCooldown"] or "Show even without cooldown")
	cbShowWhenNoCooldown:SetPoint("TOPLEFT", cbShowWhenEmpty, "BOTTOMLEFT", 0, -4)

	local staticTextLabel = Helper.CreateLabel(rightContent, L["CooldownPanelStaticText"] or "Static text", 11, "OUTLINE")
	staticTextLabel:SetPoint("TOPLEFT", cbShowWhenNoCooldown, "BOTTOMLEFT", 2, -8)
	staticTextLabel:SetTextColor(0.9, 0.9, 0.9, 1)

	local staticTextBox = Helper.CreateEditBox(rightContent, 180, 20)
	staticTextBox:SetPoint("TOPLEFT", staticTextLabel, "BOTTOMLEFT", -2, -4)

	local cbStaticTextDuringCD = Helper.CreateCheck(rightContent, L["CooldownPanelStaticTextDuringCD"] or "Show text during CD")
	cbStaticTextDuringCD:SetPoint("TOPLEFT", staticTextBox, "BOTTOMLEFT", -2, -6)

	local cbGlow = Helper.CreateCheck(rightContent, L["CooldownPanelGlowReady"] or "Glow when ready")
	cbGlow:SetPoint("TOPLEFT", cbStacks, "BOTTOMLEFT", 0, -4)

	local cbPandemicGlow = Helper.CreateCheck(rightContent, L["CooldownPanelGlowPandemic"] or "Pandemic glow")
	cbPandemicGlow:SetPoint("TOPLEFT", cbGlow, "BOTTOMLEFT", 0, -4)

	local cbSound = Helper.CreateCheck(rightContent, L["CooldownPanelSoundReady"] or "Sound when ready")
	cbSound:SetPoint("TOPLEFT", cbPandemicGlow, "BOTTOMLEFT", 0, -6)

	local soundButton = Helper.CreateButton(rightContent, "", 180, 20)
	soundButton:SetPoint("TOPLEFT", cbSound, "BOTTOMLEFT", 18, -6)

	local removeEntry = Helper.CreateButton(rightContent, L["CooldownPanelRemoveEntry"] or "Remove entry", 180, 22)
	removeEntry:SetPoint("TOP", cbSound, "BOTTOM", 0, -12)

	local middle = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 16, 0)
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", -16, 0)
	middle.bg = middle:CreateTexture(nil, "BACKGROUND")
	middle.bg:SetAllPoints(middle)
	middle.bg:SetTexture("Interface\\AddOns\\EnhanceQoL\\Assets\\background_gray.tga")
	middle.bg:SetAlpha(0.85)
	applyInsetBorder(middle, -4)
	frame.middle = middle

	local previewTitle = Helper.CreateLabel(middle, L["CooldownPanelPreview"] or "Preview", 12, "OUTLINE")
	previewTitle:SetPoint("TOPLEFT", middle, "TOPLEFT", 12, -12)

	local previewFrame = CreateFrame("Frame", nil, middle, "BackdropTemplate")
	previewFrame:SetPoint("TOPLEFT", middle, "TOPLEFT", 12, -36)
	previewFrame:SetPoint("TOPRIGHT", middle, "TOPRIGHT", -12, -36)
	previewFrame:SetHeight(190)
	previewFrame:SetClipsChildren(true)
	previewFrame.bg = previewFrame:CreateTexture(nil, "BACKGROUND")
	previewFrame.bg:SetAllPoints(previewFrame)
	previewFrame.bg:SetColorTexture(0, 0, 0, 0.3)
	applyInsetBorder(previewFrame, -6)

	local previewCanvas = CreateFrame("Frame", nil, previewFrame)
	previewCanvas._eqolIsPreview = true
	previewCanvas:SetPoint("CENTER", previewFrame, "CENTER")
	previewCanvas:SetFrameLevel((previewFrame:GetFrameLevel() or 0) + 2)
	previewFrame.canvas = previewCanvas

	local previewHint = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	previewHint:SetPoint("CENTER", previewFrame, "CENTER")
	previewHint:SetText(L["CooldownPanelDropHint"] or "Drop spells, items, or macros here")
	previewHint:SetTextColor(0.7, 0.7, 0.7, 1)
	previewFrame.dropHint = previewHint

	local dropZone = CreateFrame("Button", nil, previewFrame)
	dropZone:SetAllPoints(previewFrame)
	dropZone:SetFrameLevel((previewFrame:GetFrameLevel() or 0) + 1)
	dropZone:RegisterForClicks("LeftButtonUp")
	dropZone:SetScript("OnReceiveDrag", function()
		if CooldownPanels:HandleCursorDrop(runtime.editor and runtime.editor.selectedPanelId) then CooldownPanels:RefreshEditor() end
	end)
	dropZone:SetScript("OnMouseUp", function(_, btn)
		if btn == "LeftButton" then
			if CooldownPanels:HandleCursorDrop(runtime.editor and runtime.editor.selectedPanelId) then CooldownPanels:RefreshEditor() end
		end
	end)
	dropZone.highlight = dropZone:CreateTexture(nil, "HIGHLIGHT")
	dropZone.highlight:SetAllPoints(dropZone)
	dropZone.highlight:SetColorTexture(0.2, 0.6, 0.6, 0.15)
	previewFrame.dropZone = dropZone
	local previewHintLabel = middle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	previewHintLabel:SetPoint("BOTTOMRIGHT", previewFrame, "TOPRIGHT", -2, 6)
	previewHintLabel:SetJustifyH("RIGHT")
	previewHintLabel:SetText(L["CooldownPanelPreviewHint"] or "Drag spells/items/macros here to add")

	local entryTitle = Helper.CreateLabel(middle, L["CooldownPanelEntries"] or "Entries", 12, "OUTLINE")
	entryTitle:SetPoint("TOPLEFT", previewFrame, "BOTTOMLEFT", 0, -12)

	local entryScroll = CreateFrame("ScrollFrame", nil, middle, "UIPanelScrollFrameTemplate")
	entryScroll:SetPoint("TOPLEFT", entryTitle, "BOTTOMLEFT", 0, -8)
	entryScroll:SetPoint("BOTTOMRIGHT", middle, "BOTTOMRIGHT", -26, 80)
	local entryContent = CreateFrame("Frame", nil, entryScroll)
	entryContent:SetSize(1, 1)
	entryScroll:SetScrollChild(entryContent)
	entryContent:SetWidth(entryScroll:GetWidth() or 1)
	entryScroll:SetScript("OnSizeChanged", function(self) entryContent:SetWidth(self:GetWidth() or 1) end)

	local entryHint = middle:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	entryHint:SetPoint("BOTTOMRIGHT", entryScroll, "TOPRIGHT", -2, 6)
	entryHint:SetJustifyH("RIGHT")
	entryHint:SetText(L["CooldownPanelEntriesHint"] or "Drag entries to reorder")

	local addSpellLabel = Helper.CreateLabel(middle, L["CooldownPanelAddSpellID"] or "Add Spell ID", 11, "OUTLINE")
	addSpellLabel:SetPoint("BOTTOMLEFT", middle, "BOTTOMLEFT", 12, 46)
	addSpellLabel:SetTextColor(0.9, 0.9, 0.9, 1)

	local addSpellBox = Helper.CreateEditBox(middle, 80, 20)
	addSpellBox:SetPoint("LEFT", addSpellLabel, "RIGHT", 6, 0)
	addSpellBox:SetNumeric(true)

	local addItemLabel = Helper.CreateLabel(middle, L["CooldownPanelAddItemID"] or "Add Item ID", 11, "OUTLINE")
	addItemLabel:SetPoint("BOTTOMLEFT", middle, "BOTTOMLEFT", 12, 20)
	addItemLabel:SetTextColor(0.9, 0.9, 0.9, 1)

	local addItemBox = Helper.CreateEditBox(middle, 80, 20)
	addItemBox:SetPoint("LEFT", addItemLabel, "RIGHT", 6, 0)
	addItemBox:SetNumeric(true)

	local bottomActionButtonWidth = 120
	local bottomActionButtonHeight = 20

	local editModeButton = Helper.CreateButton(middle, _G.HUD_EDIT_MODE_MENU or L["CooldownPanelEditModeButton"] or "Edit Mode", bottomActionButtonWidth, bottomActionButtonHeight)
	editModeButton:SetPoint("BOTTOMRIGHT", middle, "BOTTOMRIGHT", -12, 44)

	local layoutEditButton = Helper.CreateButton(middle, L["CooldownPanelLayoutEdit"] or "Layout edit", bottomActionButtonWidth, bottomActionButtonHeight)
	layoutEditButton:SetPoint("RIGHT", editModeButton, "LEFT", -8, 0)

	local slotButton = Helper.CreateButton(middle, L["CooldownPanelAddSlot"] or "Add more", bottomActionButtonWidth, bottomActionButtonHeight)
	slotButton:SetPoint("BOTTOMRIGHT", middle, "BOTTOMRIGHT", -12, 18)

	local importCDMButton = Helper.CreateButton(middle, L["CooldownPanelImportCDM"] or "Import CDM", bottomActionButtonWidth, bottomActionButtonHeight)
	importCDMButton:SetPoint("RIGHT", slotButton, "LEFT", -8, 0)

	local function updateEditModeButton()
		if not editModeButton then return end
		if InCombatLockdown and InCombatLockdown() or addon.functions.isRestrictedContent() then
			editModeButton:Disable()
		else
			editModeButton:Enable()
		end
	end

	editModeButton:SetScript("OnClick", function()
		if InCombatLockdown and InCombatLockdown() or addon.functions.isRestrictedContent() then return end
		if CooldownPanels and CooldownPanels.IsAnyPanelLayoutEditActive and CooldownPanels:IsAnyPanelLayoutEditActive() then CooldownPanels:SetEditorLayoutEditEnabled(false) end
		if EditModeManagerFrame and ShowUIPanel then ShowUIPanel(EditModeManagerFrame) end
	end)

	frame:SetScript("OnShow", function()
		CooldownPanels:EnsureEditorFramePosition(frame)
		frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		updateEditModeButton()
		CooldownPanels:RefreshEditor()
	end)
	frame:SetScript("OnHide", function()
		frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
		frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		saveEditorPosition(frame)
		CooldownPanels:HideLayoutEntryStandaloneMenu()
		CooldownPanels:HideLayoutPanelStandaloneMenu()
		CooldownPanels:HideLayoutFixedGroupStandaloneMenu()
		if runtime and runtime.editor then
			local previousLayoutPanelId = normalizeId(runtime.editor._eqolLayoutPanelId or runtime.editor.selectedPanelId)
			hideEditorDragIcon(runtime.editor)
			runtime.editor.draggingEntry = nil
			runtime.editor.dragEntryId = nil
			runtime.editor.dragTargetId = nil
			runtime.editor.dragPreviewSlot = nil
			runtime.editor.layoutEditActive = nil
			runtime.editor._eqolLayoutPanelId = nil
			if previousLayoutPanelId and CooldownPanels:GetPanel(previousLayoutPanelId) then CooldownPanels:RefreshPanel(previousLayoutPanelId) end
		end
	end)
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then updateEditModeButton() end
	end)

	runtime.editor = {
		frame = frame,
		layoutEditActive = nil,
		selectedPanelId = nil,
		selectedEntryId = nil,
		panelRows = {},
		entryRows = {},
		panelList = { scroll = panelScroll, content = panelContent },
		entryList = { scroll = entryScroll, content = entryContent },
		previewFrame = previewFrame,
		previewHintLabel = previewHintLabel,
		entryHint = entryHint,
		addGroup = addGroup,
		addPanel = addPanel,
		deletePanel = deletePanel,
		addSpellBox = addSpellBox,
		addItemBox = addItemBox,
		layoutEditButton = layoutEditButton,
		slotButton = slotButton,
		importCDMButton = importCDMButton,
		filterButton = filterButton,
		inspector = {
			scroll = rightScroll,
			content = rightContent,
			panelHeader = panelHeader,
			panelName = panelNameBox,
			panelEnabled = panelEnabled,
			panelSpecLabel = panelSpecLabel,
			panelSpecButton = panelSpecButton,
			entryHeader = entryHeader,
			entryEmptyHint = entryEmptyHint,
			entryIcon = entryIcon,
			entryName = entryName,
			entryType = entryType,
			entryId = entryIdBox,
			cbCooldownText = cbCooldownText,
			cbAlwaysShow = cbAlwaysShow,
			cbCharges = cbCharges,
			cbStacks = cbStacks,
			cbItemCount = cbItemCount,
			cbItemUses = cbItemUses,
			cbUseHighestRank = cbUseHighestRank,
			cbShowWhenEmpty = cbShowWhenEmpty,
			cbShowWhenNoCooldown = cbShowWhenNoCooldown,
			staticTextLabel = staticTextLabel,
			staticTextBox = staticTextBox,
			cbStaticTextDuringCD = cbStaticTextDuringCD,
			cbGlow = cbGlow,
			cbPandemicGlow = cbPandemicGlow,
			cbSound = cbSound,
			soundButton = soundButton,
			removeEntry = removeEntry,
		},
	}

	local editor = runtime.editor

	addGroup:SetScript("OnClick", function()
		if CooldownPanels.ShowEditorGroupCreatePopup then CooldownPanels:ShowEditorGroupCreatePopup() end
	end)

	addPanel:SetScript("OnClick", function()
		local newName = L["CooldownPanelNewPanel"] or "New Panel"
		local panelId = CooldownPanels:CreatePanel(newName)
		if panelId then CooldownPanels:SelectPanel(panelId) end
	end)

	deletePanel:SetScript("OnClick", function()
		local panelId = editor.selectedPanelId
		if not panelId then return end
		local panel = CooldownPanels:GetPanel(panelId)
		ensureDeletePopup()
		StaticPopup_Show("EQOL_COOLDOWN_PANEL_DELETE", panel and panel.name or nil, nil, { panelId = panelId })
	end)

	addSpellBox:SetScript("OnEnterPressed", function(self)
		local panelId = editor.selectedPanelId
		local value = tonumber(self:GetText())
		if panelId and value then CooldownPanels:AddEntrySafe(panelId, "SPELL", value) end
		self:SetText("")
		self:ClearFocus()
		CooldownPanels:RefreshEditor()
	end)

	addItemBox:SetScript("OnEnterPressed", function(self)
		local panelId = editor.selectedPanelId
		local value = tonumber(self:GetText())
		if panelId and value then CooldownPanels:AddEntrySafe(panelId, "ITEM", value) end
		self:SetText("")
		self:ClearFocus()
		CooldownPanels:RefreshEditor()
	end)

	layoutEditButton:SetScript("OnClick", function() CooldownPanels:SetEditorLayoutEditEnabled(editor.layoutEditActive ~= true) end)

	slotButton:SetScript("OnClick", function(self) showSlotMenu(self, editor.selectedPanelId) end)
	importCDMButton:SetScript("OnClick", function(self)
		local panelId = editor.selectedPanelId
		if not panelId then return end
		showImportCDMMenu(self, panelId)
	end)

	local function commitPanelNameChange(self)
		local panelId = editor.selectedPanelId
		local panel = panelId and CooldownPanels:GetPanel(panelId)
		local text = self:GetText()
		if panel and text and text ~= "" and text ~= panel.name then
			panel.name = text
			CooldownPanels.MarkRelativeFrameEntriesDirty()
			local runtimePanel = CooldownPanels.runtime and CooldownPanels.runtime[panelId]
			if runtimePanel and runtimePanel.frame then runtimePanel.frame.editModeName = text end
			if runtimePanel and runtimePanel.editModeId and EditMode and EditMode.frames and EditMode.frames[runtimePanel.editModeId] then EditMode.frames[runtimePanel.editModeId].title = text end
			refreshEditModePanelFrame(panelId, runtimePanel and runtimePanel.editModeId)
			refreshEditModeSettings()
			CooldownPanels:RefreshPanel(panelId)
		end
	end

	panelNameBox:SetScript("OnEnterPressed", function(self)
		commitPanelNameChange(self)
		self:ClearFocus()
		CooldownPanels:RefreshEditor()
	end)
	panelNameBox:SetScript("OnEditFocusLost", function(self)
		commitPanelNameChange(self)
		CooldownPanels:RefreshEditor()
	end)
	panelNameBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		CooldownPanels:RefreshEditor()
	end)

	panelEnabled:SetScript("OnClick", function(self)
		local panelId = editor.selectedPanelId
		local panel = panelId and CooldownPanels:GetPanel(panelId)
		if panel then
			panel.enabled = self:GetChecked() and true or false
			CooldownPanels:RebuildSpellIndex()
			Keybinds.MarkPanelsDirty()
			CooldownPanels:RefreshPanel(panelId)
			CooldownPanels:UpdateCursorAnchorState()
			CooldownPanels:RefreshEditor()
		end
	end)

	panelSpecButton:SetScript("OnClick", function(self) showSpecMenu(self, editor.selectedPanelId) end)

	entryIdBox:SetScript("OnEnterPressed", function(self)
		local panelId = editor.selectedPanelId
		local entryId = editor.selectedEntryId
		local panel = panelId and CooldownPanels:GetPanel(panelId)
		local entry = panel and panel.entries and panel.entries[entryId]
		local value = tonumber(self:GetText())
		if not panel or not entry then
			self:ClearFocus()
			CooldownPanels:RefreshEditor()
			return
		end
		if entry.type == "STANCE" or entry.type == "CDM_AURA" then
			self:ClearFocus()
			CooldownPanels:RefreshEditor()
			return
		end
		if not value then
			self:ClearFocus()
			CooldownPanels:RefreshEditor()
			return
		end
		local newValue = value
		local enableHighestRank = false
		if entry.type == "SPELL" then
			local baseValue = getBaseSpellId(value) or value
			if not spellExistsSafe(value) and not spellExistsSafe(baseValue) then
				showErrorMessage(L["CooldownPanelSpellInvalid"] or "Spell does not exist.")
				self:ClearFocus()
				CooldownPanels:RefreshEditor()
				return
			end
			newValue = CooldownPanels:ResolveKnownSpellVariantID(baseValue) or baseValue
		elseif entry.type == "ITEM" then
			local canonicalItemID, wasHigherRank = CooldownPanels:GetCanonicalItemRankID(newValue)
			if canonicalItemID then newValue = canonicalItemID end
			enableHighestRank = wasHigherRank == true
		end
		local existingId = CooldownPanels:FindEntryByValue(panelId, entry.type, newValue)
		if existingId and existingId ~= entryId then
			showErrorMessage("Entry already exists.")
			self:ClearFocus()
			CooldownPanels:RefreshEditor()
			return
		end
		if entry.type == "SPELL" then
			entry.spellID = newValue
		elseif entry.type == "ITEM" then
			entry.itemID = newValue
			if enableHighestRank then entry.useHighestRank = true end
		elseif entry.type == "SLOT" then
			entry.slotID = newValue
		elseif entry.type == "MACRO" then
			entry.macroID = newValue
			local macroName = Api.GetMacroInfo and Api.GetMacroInfo(newValue) or nil
			entry.macroName = CooldownPanels.NormalizeMacroName(macroName) or entry.macroName
		end
		self:ClearFocus()
		CooldownPanels:RebuildSpellIndex()
		CooldownPanels:RefreshPanel(panelId)
		CooldownPanels:RefreshEditor()
	end)
	entryIdBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		CooldownPanels:RefreshEditor()
	end)

	local function bindEntryToggle(cb, field)
		cb:SetScript("OnClick", function(self)
			local panelId = editor.selectedPanelId
			local entryId = editor.selectedEntryId
			local panel = panelId and CooldownPanels:GetPanel(panelId)
			local entry = panel and panel.entries and panel.entries[entryId]
			if not entry then return end
			entry[field] = self:GetChecked() and true or false
			CooldownPanels:HandleEntryBooleanMutation(panelId, entryId, entry, field)
			CooldownPanels:RefreshPanel(panelId)
			CooldownPanels:RefreshEditor()
		end)
	end

	bindEntryToggle(cbCharges, "showCharges")
	bindEntryToggle(cbStacks, "showStacks")
	bindEntryToggle(cbCooldownText, "showCooldownText")
	cbAlwaysShow:SetScript("OnClick", function(self)
		local panelId = editor.selectedPanelId
		local entryId = editor.selectedEntryId
		local panel = panelId and CooldownPanels:GetPanel(panelId)
		local entry = panel and panel.entries and panel.entries[entryId]
		if not entry then return end
		if entry.type == "STANCE" then
			entry.showWhenMissing = self:GetChecked() and true or false
		elseif entry.type == "CDM_AURA" then
			local layout = panel and panel.layout or nil
			local mode = self:GetChecked() and (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.SHOW or "SHOW")
				or (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.HIDE or "HIDE")
			local resolvedMode = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, entry)
			if entry.cdmAuraAlwaysShowUseGlobal == false and resolvedMode == mode then return end
			entry.cdmAuraAlwaysShowUseGlobal = false
			entry.cdmAuraAlwaysShowMode = mode
			entry.alwaysShow = self:GetChecked() and true or false
		else
			entry.alwaysShow = self:GetChecked() and true or false
		end
		CooldownPanels:RefreshPanel(panelId)
		CooldownPanels:RefreshEditor()
	end)
	bindEntryToggle(cbItemCount, "showItemCount")
	bindEntryToggle(cbItemUses, "showItemUses")
	bindEntryToggle(cbUseHighestRank, "useHighestRank")
	bindEntryToggle(cbShowWhenEmpty, "showWhenEmpty")
	bindEntryToggle(cbShowWhenNoCooldown, "showWhenNoCooldown")
	bindEntryToggle(cbStaticTextDuringCD, "staticTextShowOnCooldown")
	bindEntryToggle(cbGlow, "glowReady")
	bindEntryToggle(cbPandemicGlow, "pandemicGlow")
	cbSound:SetScript("OnClick", function(self)
		local panelId = editor.selectedPanelId
		local entryId = editor.selectedEntryId
		local panel = panelId and CooldownPanels:GetPanel(panelId)
		local entry = panel and panel.entries and panel.entries[entryId]
		local _, enabledField = CooldownPanels:GetEntrySoundConfig(entry)
		if not (entry and enabledField) then return end
		entry[enabledField] = self:GetChecked() and true or false
		CooldownPanels:RefreshPanel(panelId)
		CooldownPanels:RefreshEditor()
	end)

	local function applyStaticTextValue(self)
		local panelId = editor.selectedPanelId
		local entryId = editor.selectedEntryId
		local panel = panelId and CooldownPanels:GetPanel(panelId)
		local entry = panel and panel.entries and panel.entries[entryId]
		if not entry then
			self:ClearFocus()
			return
		end
		local text = self:GetText() or ""
		if entry.staticText == text then
			self:ClearFocus()
			return
		end
		entry.staticText = text
		self:ClearFocus()
		CooldownPanels:RefreshPanel(panelId)
		CooldownPanels:RefreshEditor()
	end

	staticTextBox:SetScript("OnEnterPressed", applyStaticTextValue)
	staticTextBox:SetScript("OnEditFocusLost", applyStaticTextValue)
	staticTextBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		CooldownPanels:RefreshEditor()
	end)

	soundButton:SetScript("OnClick", function(self)
		local panelId = editor.selectedPanelId
		local entryId = editor.selectedEntryId
		if panelId and entryId then showSoundMenu(self, panelId, entryId) end
	end)

	removeEntry:SetScript("OnClick", function()
		local panelId = editor.selectedPanelId
		local entryId = editor.selectedEntryId
		if panelId and entryId then
			CooldownPanels:RemoveEntry(panelId, entryId)
			editor.selectedEntryId = nil
			CooldownPanels:RefreshEditor()
		end
	end)

	local cdmAuras = CooldownPanels.CDMAuras
	if cdmAuras and cdmAuras.AttachEditor then cdmAuras:AttachEditor(runtime.editor) end

	return runtime.editor
end

ensureDeletePopup = function()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_DELETE"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_DELETE"] = {
		text = L["CooldownPanelDeletePanel"] or "Delete Panel?",
		button1 = YES,
		button2 = CANCEL,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(self, data)
			if not data or not data.panelId then return end
			CooldownPanels:DeletePanel(data.panelId)
			CooldownPanels:RefreshEditor()
		end,
	}
end

ensureImportCDMPopup = function()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_IMPORT_CDM"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_IMPORT_CDM"] = {
		text = L["CooldownPanelImportCDMConfirm"] or "Import all entries from %s?",
		button1 = YES,
		button2 = NO,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(_, data)
			if not data or not data.panelId then return end
			local sourceKind = data.sourceKind or "ESSENTIAL"
			local sourceLabel = data.sourceLabel or getCooldownManagerSourceLabel(sourceKind)
			local result, err, resolvedSourceLabel
			local cdmAuras = CooldownPanels.CDMAuras
			if (sourceKind == "BUFF_ICON" or sourceKind == "BUFF_BAR") and cdmAuras and cdmAuras.ImportEntries then
				result, err, resolvedSourceLabel = cdmAuras:ImportEntries(data.panelId, sourceKind)
			else
				result, err, resolvedSourceLabel = importCooldownManagerSpells(data.panelId, sourceKind)
			end
			local errorSourceLabel = resolvedSourceLabel or sourceLabel
			if not result then
				if err == "SOURCE_NOT_FOUND" then
					showErrorMessage(string.format(L["CooldownPanelImportCDMNoSource"] or "Cooldown Manager data not found for %s.", tostring(errorSourceLabel or sourceLabel)))
				elseif err == "PANEL_NOT_FOUND" then
					showErrorMessage(L["CooldownPanelImportCDMNoPanel"] or "No panel selected.")
				end
			else
				print(
					string.format(
						"[EnhanceQoL] " .. (L["CooldownPanelImportCDMResult"] or "Imported %d entries from %s (%d duplicates, %d skipped)."),
						result.added or 0,
						tostring(result.sourceLabel or sourceLabel),
						result.duplicates or 0,
						result.invalid or 0
					)
				)
			end
			CooldownPanels:RefreshEditor()
		end,
	}
end

ensureCopyPopup = function()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_COPY_SETTINGS"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_COPY_SETTINGS"] = {
		text = L["CooldownPanelCopySettingsConfirm"] or "Copy settings from %s to this panel?",
		button1 = YES,
		button2 = CANCEL,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(self, data)
			if not data or not data.targetPanelId or not data.sourcePanelId then return end
			copyPanelSettings(data.targetPanelId, data.sourcePanelId)
		end,
	}
end

function CooldownPanels:EnsureEditorGroupCreatePopup()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_CREATE"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_CREATE"] = {
		text = L["CooldownPanelCreateGroupPrompt"] or "Create group",
		button1 = OKAY,
		button2 = CANCEL,
		hasEditBox = true,
		editBoxWidth = 240,
		enterClicksFirstButton = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnShow = function(self)
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			if editBox then
				editBox:SetText("")
				editBox:SetFocus()
				if editBox.HighlightText then editBox:HighlightText() end
			end
		end,
		OnAccept = function(self, data)
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local text = editBox and editBox:GetText()
			local parentGroupId = data and normalizeId(data.parentGroupId) or nil
			local groupId = CooldownPanels:CreateEditorGroup(text, parentGroupId)
			if groupId and CooldownPanels.IsEditorOpen and CooldownPanels:IsEditorOpen() then
				local editor = getEditor()
				if editor and parentGroupId ~= nil then CooldownPanels:GetEditorPanelGroupState(editor)[CooldownPanels:GetEditorPanelGroupStateKey(parentGroupId)] = nil end
				CooldownPanels:RefreshEditor()
			end
		end,
	}
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_CREATE"].EditBoxOnEnterPressed = function(editBox)
		local parent = editBox and editBox.GetParent and editBox:GetParent()
		if parent and parent.button1 and parent.button1:IsEnabled() then parent.button1:Click() end
	end
end

function CooldownPanels:EnsureEditorGroupRenamePopup()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_RENAME"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_RENAME"] = {
		text = L["CooldownPanelRenameGroupPrompt"] or "Rename group",
		button1 = OKAY,
		button2 = CANCEL,
		hasEditBox = true,
		editBoxWidth = 240,
		enterClicksFirstButton = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnShow = function(self, data)
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local root = ensureRoot()
			local currentName = data and CooldownPanels.GetEditorGroupName(root, data.groupId) or ""
			if editBox then
				editBox:SetText(currentName or "")
				editBox:SetFocus()
				if editBox.HighlightText then editBox:HighlightText() end
			end
		end,
		OnAccept = function(self, data)
			if not (data and data.groupId) then return end
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local text = editBox and editBox:GetText()
			if CooldownPanels:RenameEditorGroup(data.groupId, text) and CooldownPanels.IsEditorOpen and CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
		end,
	}
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_RENAME"].EditBoxOnEnterPressed = function(editBox)
		local parent = editBox and editBox.GetParent and editBox:GetParent()
		if parent and parent.button1 and parent.button1:IsEnabled() then parent.button1:Click() end
	end
end

function CooldownPanels:EnsureEditorGroupDeletePopup()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_DELETE"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_GROUP_DELETE"] = {
		text = L["CooldownPanelDeleteGroupPrompt"] or "Delete group %s? Panels will stay ungrouped.",
		button1 = YES,
		button2 = CANCEL,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(_, data)
			if not (data and data.groupId) then return end
			if CooldownPanels:DeleteEditorGroup(data.groupId) and CooldownPanels.IsEditorOpen and CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
		end,
	}
end

function CooldownPanels:ShowEditorGroupCreatePopup(parentGroupId)
	parentGroupId = normalizeId(parentGroupId)
	self:EnsureEditorGroupCreatePopup()
	StaticPopup_Show("EQOL_COOLDOWN_PANEL_GROUP_CREATE", nil, nil, { parentGroupId = parentGroupId })
end

function CooldownPanels:ShowEditorGroupRenamePopup(groupId)
	groupId = normalizeId(groupId)
	if not groupId then return end
	self:EnsureEditorGroupRenamePopup()
	StaticPopup_Show("EQOL_COOLDOWN_PANEL_GROUP_RENAME", nil, nil, { groupId = groupId })
end

function CooldownPanels:EnsureFixedGroupRenamePopup()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_RENAME"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_RENAME"] = {
		text = L["CooldownPanelRenameGroupPrompt"] or "Rename group",
		button1 = OKAY,
		button2 = CANCEL,
		hasEditBox = true,
		editBoxWidth = 240,
		enterClicksFirstButton = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnShow = function(self, data)
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local currentName = data and CooldownPanels:GetFixedGroupLabel(data.panelId, data.groupId) or ""
			if editBox then
				editBox:SetText(currentName or "")
				editBox:SetFocus()
				if editBox.HighlightText then editBox:HighlightText() end
			end
		end,
		OnAccept = function(self, data)
			if not (data and data.panelId and data.groupId) then return end
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local text = editBox and editBox:GetText()
			if CooldownPanels:RenameFixedGroup(data.panelId, data.groupId, text) then
				CooldownPanels:RefreshPanel(data.panelId)
				CooldownPanels:RefreshEditor()
			end
		end,
	}
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_RENAME"].EditBoxOnEnterPressed = function(editBox)
		local parent = editBox and editBox.GetParent and editBox:GetParent()
		if parent and parent.button1 and parent.button1:IsEnabled() then parent.button1:Click() end
	end
end

function CooldownPanels:EnsureFixedGroupDeletePopup()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_DELETE"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_DELETE"] = {
		text = L["CooldownPanelDeleteGroupPrompt"] or "Delete group %s? Entries will become static fixed slots.",
		button1 = YES,
		button2 = CANCEL,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(_, data)
			if not (data and data.panelId and data.groupId) then return end
			CooldownPanels:HideLayoutFixedGroupStandaloneMenu(data.panelId)
			if CooldownPanels:DeleteFixedGroup(data.panelId, data.groupId) then
				local runtime = getRuntime(data.panelId)
				if runtime then clearRuntimeLayoutShapeCache(runtime) end
				CooldownPanels:RefreshPanelForCurrentEditContext(data.panelId, true)
			end
		end,
	}
end

function CooldownPanels:EnsureFixedGroupIconSizePopup()
	if StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_ICON_SIZE"] then return end
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_ICON_SIZE"] = {
		text = L["CooldownPanelFixedGroupIconSizePrompt"] or "Set group icon size (leave empty for panel size)",
		button1 = OKAY,
		button2 = CANCEL,
		hasEditBox = true,
		editBoxWidth = 180,
		enterClicksFirstButton = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnShow = function(self, data)
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local panel = data and data.panelId and CooldownPanels:GetPanel(data.panelId) or nil
			local group = panel and CooldownPanels.GetFixedGroupById(panel, data.groupId) or nil
			local size = group and Helper.NormalizeFixedGroupIconSize(group.iconSize) or nil
			if editBox then
				editBox:SetText(size and tostring(size) or "")
				editBox:SetFocus()
				if editBox.HighlightText then editBox:HighlightText() end
			end
		end,
		OnAccept = function(self, data)
			if not (data and data.panelId and data.groupId) then return end
			local editBox = self.editBox or self.GetEditBox and self:GetEditBox()
			local text = editBox and editBox:GetText() or ""
			if strtrim then text = strtrim(text) end
			local nextSize = text ~= "" and Helper.NormalizeFixedGroupIconSize(tonumber(text)) or nil
			if text ~= "" and nextSize == nil then
				showErrorMessage(L["CooldownPanelFixedGroupIconSizeInvalid"] or "Icon size must be between 12 and 128.")
				return
			end
			if CooldownPanels:SetFixedGroupIconSize(data.panelId, data.groupId, nextSize) then
				CooldownPanels:RefreshPanel(data.panelId)
				CooldownPanels:RefreshEditor()
			end
		end,
	}
	StaticPopupDialogs["EQOL_COOLDOWN_PANEL_FIXED_GROUP_ICON_SIZE"].EditBoxOnEnterPressed = function(editBox)
		local parent = editBox and editBox.GetParent and editBox:GetParent()
		if parent and parent.button1 and parent.button1:IsEnabled() then parent.button1:Click() end
	end
end

function CooldownPanels:ShowFixedGroupRenamePopup(panelId, groupId)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not (panelId and groupId) then return end
	self:EnsureFixedGroupRenamePopup()
	StaticPopup_Show("EQOL_COOLDOWN_PANEL_FIXED_GROUP_RENAME", nil, nil, { panelId = panelId, groupId = groupId })
end

function CooldownPanels:ShowFixedGroupIconSizePopup(panelId, groupId)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not (panelId and groupId) then return end
	self:EnsureFixedGroupIconSizePopup()
	StaticPopup_Show("EQOL_COOLDOWN_PANEL_FIXED_GROUP_ICON_SIZE", nil, nil, { panelId = panelId, groupId = groupId })
end

function CooldownPanels:ShowFixedGroupMenu(owner, panelId, groupId)
	panelId = normalizeId(panelId)
	groupId = Helper.NormalizeFixedGroupId(groupId)
	if not (owner and panelId and groupId and Api.MenuUtil and Api.MenuUtil.CreateContextMenu) then return end
	local panel = self:GetPanel(panelId)
	local group = panel and CooldownPanels.GetFixedGroupById(panel, groupId) or nil
	if not group then return end
	local groupName = CooldownPanels.GetFixedGroupName(group)
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:CreateTitle(CooldownPanels.GetFixedGroupDisplayLabel(group))
		rootDescription:CreateDivider()
		local modeMenu = rootDescription:CreateButton(L["CooldownPanelMode"] or "Mode")
		modeMenu:CreateRadio(L["CooldownPanelDynamic"] or "Dynamic", function() return not CooldownPanels.IsFixedGroupStatic(group) end, function()
			if CooldownPanels:SetFixedGroupMode(panelId, groupId, "DYNAMIC") then
				CooldownPanels:RefreshPanel(panelId)
				CooldownPanels:RefreshEditor()
			end
		end)
		modeMenu:CreateRadio(L["CooldownPanelStatic"] or "Static", function() return CooldownPanels.IsFixedGroupStatic(group) end, function()
			local changed, reason = CooldownPanels:SetFixedGroupMode(panelId, groupId, "STATIC")
			if changed then
				CooldownPanels:RefreshPanel(panelId)
				CooldownPanels:RefreshEditor()
			elseif reason == "GROUP_FULL" then
				showErrorMessage(L["CooldownPanelFixedGroupFull"] or "Fixed group is full.")
			end
		end)
		local sizeMenu = rootDescription:CreateButton(L["CooldownPanelIconSize"] or "Icon size")
		sizeMenu:CreateRadio(L["CooldownPanelUsePanelSize"] or "Use panel size", function() return Helper.NormalizeFixedGroupIconSize(group.iconSize) == nil end, function()
			if CooldownPanels:SetFixedGroupIconSize(panelId, groupId, nil) then
				CooldownPanels:RefreshPanel(panelId)
				CooldownPanels:RefreshEditor()
			end
		end)
		for _, preset in ipairs({ 24, 30, 36, 42, 48, 56 }) do
			local size = preset
			sizeMenu:CreateRadio(tostring(size), function() return Helper.NormalizeFixedGroupIconSize(group.iconSize) == size end, function()
				if CooldownPanels:SetFixedGroupIconSize(panelId, groupId, size) then
					CooldownPanels:RefreshPanel(panelId)
					CooldownPanels:RefreshEditor()
				end
			end)
		end
		sizeMenu:CreateButton(L["CooldownPanelCustom"] or "Custom", function() CooldownPanels:ShowFixedGroupIconSizePopup(panelId, groupId) end)
		rootDescription:CreateDivider()
		rootDescription:CreateButton(L["CooldownPanelRename"] or "Rename", function() CooldownPanels:ShowFixedGroupRenamePopup(panelId, groupId) end)
		rootDescription:CreateButton(DELETE or "Delete", function()
			CooldownPanels:EnsureFixedGroupDeletePopup()
			StaticPopup_Show("EQOL_COOLDOWN_PANEL_FIXED_GROUP_DELETE", groupName, nil, { panelId = panelId, groupId = groupId })
		end)
	end)
end

function CooldownPanels:ShowEditorGroupMenu(owner, groupId)
	groupId = normalizeId(groupId)
	if not (owner and groupId and Api.MenuUtil and Api.MenuUtil.CreateContextMenu) then return end
	local root = ensureRoot()
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	local group = root and root.editorGroups and root.editorGroups[groupId] or nil
	local groupName = group and group.name or ("Group " .. tostring(groupId))
	local currentParentId = group and normalizeId(group.parentGroupId) or nil
	local blockedGroupIds = CooldownPanels:GetEditorGroupDescendantIdSet(root, groupId)
	blockedGroupIds[groupId] = true
	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:CreateTitle(groupName)
		rootDescription:CreateDivider()
		rootDescription:CreateButton(L["CooldownPanelAddSubgroup"] or "Add Subgroup", function() CooldownPanels:ShowEditorGroupCreatePopup(groupId) end)
		local parentMenu = rootDescription:CreateButton(L["CooldownPanelMoveToGroup"] or "Move to group")
		parentMenu:CreateRadio(L["CooldownPanelTopLevel"] or "Top level", function() return currentParentId == nil end, function()
			if CooldownPanels:SetEditorGroupParent(groupId, nil) then CooldownPanels:RefreshEditor() end
		end)
		CooldownPanels:PopulateEditorGroupRadioMenu(parentMenu, root, currentParentId, function(targetGroupId)
			if CooldownPanels:SetEditorGroupParent(groupId, targetGroupId) then
				local editor = getEditor()
				if editor then CooldownPanels:GetEditorPanelGroupState(editor)[CooldownPanels:GetEditorPanelGroupStateKey(targetGroupId)] = nil end
				CooldownPanels:RefreshEditor()
			end
		end, { skipGroupIds = blockedGroupIds })
		rootDescription:CreateDivider()
		rootDescription:CreateButton(L["CooldownPanelRename"] or "Rename", function() CooldownPanels:ShowEditorGroupRenamePopup(groupId) end)
		rootDescription:CreateButton(DELETE or "Delete", function()
			CooldownPanels:EnsureEditorGroupDeletePopup()
			StaticPopup_Show("EQOL_COOLDOWN_PANEL_GROUP_DELETE", groupName, nil, { groupId = groupId })
		end)
	end)
end

function CooldownPanels:ShowPanelGroupAssignMenu(owner, panelId)
	panelId = normalizeId(panelId)
	if not (owner and panelId and Api.MenuUtil and Api.MenuUtil.CreateContextMenu) then return end
	local root = ensureRoot()
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	local panel = root and root.panels and root.panels[panelId] or nil
	if not panel then return end
	self:SortEditorGroupOrder(root)

	Api.MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		rootDescription:CreateTitle(panel.name or ("Panel " .. tostring(panelId)))
		rootDescription:CreateDivider()
		rootDescription:CreateButton(L["CooldownPanelDuplicate"] or "Duplicate", function()
			local duplicatedPanelId = CooldownPanels:DuplicatePanel(panelId)
			if duplicatedPanelId then CooldownPanels:SelectPanel(duplicatedPanelId) end
		end)

		local currentGroupId = normalizeId(panel.editorGroupId)
		local groupMenu = rootDescription:CreateButton(L["CooldownPanelAddToGroup"] or "Add to group")
		groupMenu:CreateRadio(L["CooldownPanelUngrouped"] or "Ungrouped", function() return currentGroupId == nil end, function()
			if CooldownPanels:SetPanelEditorGroup(panelId, nil) then CooldownPanels:RefreshEditor() end
		end)

		local hasGroups = CooldownPanels:PopulateEditorGroupRadioMenu(groupMenu, root, currentGroupId, function(targetGroupId)
			if CooldownPanels:SetPanelEditorGroup(panelId, targetGroupId) then CooldownPanels:RefreshEditor() end
		end)

		if not hasGroups then
			groupMenu:CreateButton(L["CooldownPanelNoGroups"] or "No groups", function() end)
			rootDescription:CreateButton(L["CooldownPanelAddGroup"] or "Add Group", function() CooldownPanels:ShowEditorGroupCreatePopup() end)
		end
	end)
end

local function updateRowVisual(row, selected)
	if not row or not row.bg then return end
	if row._eqolPanelListKind == "bucket" then
		row.bg:SetColorTexture(0, 0, 0, 0.3)
		return
	end
	if selected then
		row.bg:SetColorTexture(0.1, 0.6, 0.6, 0.35)
	else
		row.bg:SetColorTexture(0, 0, 0, 0.2)
	end
end

local function movePanelInOrder(root, panelId, targetPanelId)
	if not root or not root.order then return false end
	if not panelId or not targetPanelId or panelId == targetPanelId then return false end
	local fromIndex, toIndex
	for i, id in ipairs(root.order) do
		if id == panelId then fromIndex = i end
		if id == targetPanelId then toIndex = i end
	end
	if not fromIndex or not toIndex then return false end
	table.remove(root.order, fromIndex)
	if fromIndex < toIndex then toIndex = toIndex - 1 end
	table.insert(root.order, toIndex, panelId)
	markRootOrderDirty(root)
	return true
end

local function findFirstPanelForClass(root, classSpecs)
	if not root or not root.order then return nil end
	for _, panelId in ipairs(root.order) do
		local panel = root.panels and root.panels[panelId]
		if panel and panelMatchesPlayerClass(panel, classSpecs) then return panelId end
	end
	return nil
end

local function refreshPanelList(editor, root, classSpecs)
	local list = editor.panelList
	if not list then return end
	root = CooldownPanels.EnsureEditorGroupStorage(root)
	local content = list.content
	local rowHeight = 28
	local spacing = 4
	local index = 0
	local filterByClass = addon.db and addon.db.cooldownPanelsFilterClass == true
	local hideEmptyGroups = addon.db and addon.db.cooldownPanelsHideEmptyGroups == true
	local groups = root.editorGroups or {}
	local groupedPanelIds = {}
	local ungroupedPanelIds = {}
	local entries = {}
	local showUngroupedBucket = false

	CooldownPanels:SortEditorGroupOrder(root)
	local childrenByParent = CooldownPanels:BuildEditorGroupHierarchy(root)

	for _, groupId in ipairs(root.editorGroupOrder or {}) do
		if groups[groupId] then groupedPanelIds[groupId] = {} end
	end

	for _, panelId in ipairs(root.order or {}) do
		local panel = root.panels and root.panels[panelId]
		if panel and (not filterByClass or panelMatchesPlayerClass(panel, classSpecs)) then
			local groupId = normalizeId(panel.editorGroupId)
			if groupId and groups[groupId] then
				local bucket = groupedPanelIds[groupId]
				if not bucket then
					bucket = {}
					groupedPanelIds[groupId] = bucket
				end
				bucket[#bucket + 1] = panelId
			else
				ungroupedPanelIds[#ungroupedPanelIds + 1] = panelId
			end
		end
	end

	showUngroupedBucket = #ungroupedPanelIds > 0 or editor.draggingPanel == true

	local function getHierarchyKey(groupId)
		groupId = normalizeId(groupId)
		if groupId ~= nil then return tostring(groupId) end
		return "__root"
	end

	local visibleGroupCounts = {}

	local function getVisibleGroupCount(groupId)
		if visibleGroupCounts[groupId] ~= nil then return visibleGroupCounts[groupId] end
		local count = #(groupedPanelIds[groupId] or {})
		for _, childGroupId in ipairs(childrenByParent[getHierarchyKey(groupId)] or {}) do
			count = count + getVisibleGroupCount(childGroupId)
		end
		visibleGroupCounts[groupId] = count
		return count
	end

	local function appendBucket(groupId, label, count, depth)
		local collapsed = CooldownPanels:IsEditorPanelGroupCollapsed(editor, groupId)
		entries[#entries + 1] = {
			kind = "bucket",
			groupId = groupId,
			label = label,
			count = count or 0,
			collapsed = collapsed,
			depth = depth or 0,
		}
		return collapsed ~= true
	end

	local function appendGroup(groupId, depth)
		local group = groups[groupId]
		if not group then return end
		local count = getVisibleGroupCount(groupId)
		if hideEmptyGroups and count <= 0 and editor.draggingPanel ~= true then return end
		if not appendBucket(groupId, group.name or ("Group " .. tostring(groupId)), count, depth) then return end
		for _, childGroupId in ipairs(childrenByParent[getHierarchyKey(groupId)] or {}) do
			appendGroup(childGroupId, depth + 1)
		end
		for _, panelId in ipairs(groupedPanelIds[groupId] or {}) do
			entries[#entries + 1] = {
				kind = "panel",
				groupId = groupId,
				panelId = panelId,
				panel = root.panels and root.panels[panelId] or nil,
				depth = (depth or 0) + 1,
			}
		end
	end

	if showUngroupedBucket and appendBucket(nil, L["CooldownPanelUngrouped"] or "Ungrouped", #ungroupedPanelIds, 0) then
		for _, panelId in ipairs(ungroupedPanelIds) do
			entries[#entries + 1] = {
				kind = "panel",
				groupId = nil,
				panelId = panelId,
				panel = root.panels and root.panels[panelId] or nil,
				depth = 1,
			}
		end
	end
	for _, groupId in ipairs(childrenByParent["__root"] or {}) do
		appendGroup(groupId, 0)
	end

	for _, entry in ipairs(entries) do
		index = index + 1
		local row = editor.panelRows[index]
		if not row then
			row = Helper.CreateRowButton(content, rowHeight)
			row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			row.label:SetTextColor(1, 1, 1, 1)

			row.count = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			row.count:SetPoint("RIGHT", row, "RIGHT", -8, 0)

			row.toggle = row:CreateTexture(nil, "ARTWORK")
			row.toggle:SetSize(12, 12)
			row.toggle:Hide()

			row.toggleFrame = CreateFrame("Button", nil, row)
			row.toggleFrame:SetSize(18, 18)
			row.toggleFrame:SetPoint("LEFT", row, "LEFT", 4, 0)
			row.toggleFrame:Hide()
			row.toggleFrame:SetScript("OnClick", function(self)
				local parent = self:GetParent()
				if not (parent and parent._eqolPanelListKind == "bucket") then return end
				CooldownPanels:ToggleEditorPanelGroupCollapsed(editor, parent.groupId)
				CooldownPanels:RefreshEditor()
			end)
			row.toggleFrame:SetScript("OnEnter", function(self)
				local parent = self:GetParent()
				if parent and parent.highlight then parent.highlight:Show() end
			end)
			row.toggleFrame:SetScript("OnLeave", function(self)
				local parent = self:GetParent()
				if parent and parent.highlight then parent.highlight:Hide() end
			end)

			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			row:RegisterForDrag("LeftButton")
			row:SetScript("OnDragStart", function(self)
				if self._eqolPanelListKind ~= "panel" then return end
				editor.dragPanelId = self.panelId
				editor.dragTargetPanelId = nil
				editor.dragTargetHasBucket = nil
				editor.dragTargetBucketId = nil
				editor.draggingPanel = true
				CooldownPanels:RefreshEditor()
				showEditorDragIcon(editor, Helper.PREVIEW_ICON)
				self:SetAlpha(0.6)
			end)
			row:SetScript("OnDragStop", function(self)
				self:SetAlpha(1)
				if not editor.draggingPanel then return end
				editor.draggingPanel = nil
				hideEditorDragIcon(editor)
				local fromId = editor.dragPanelId
				local targetPanelId = editor.dragTargetPanelId
				local hasBucketTarget = editor.dragTargetHasBucket == true
				local targetBucketId = editor.dragTargetBucketId
				editor.dragPanelId = nil
				editor.dragTargetPanelId = nil
				editor.dragTargetHasBucket = nil
				editor.dragTargetBucketId = nil
				if not fromId then
					CooldownPanels:RefreshEditor()
					return
				end
				local sourcePanel = root.panels and root.panels[fromId] or nil
				if sourcePanel then
					if targetPanelId and targetPanelId ~= fromId then
						local targetPanel = root.panels and root.panels[targetPanelId] or nil
						if targetPanel then
							sourcePanel.editorGroupId = normalizeId(targetPanel.editorGroupId)
							movePanelInOrder(root, fromId, targetPanelId)
						end
					elseif hasBucketTarget then
						sourcePanel.editorGroupId = normalizeId(targetBucketId)
						for _, candidateId in ipairs(root.order or {}) do
							if candidateId ~= fromId then
								local candidatePanel = root.panels and root.panels[candidateId] or nil
								if candidatePanel and normalizeId(candidatePanel.editorGroupId) == normalizeId(targetBucketId) then
									movePanelInOrder(root, fromId, candidateId)
									break
								end
							end
						end
					end
				end
				CooldownPanels:RefreshEditor()
			end)
			row:SetScript("OnEnter", function(self)
				if not editor.draggingPanel then return end
				if self._eqolPanelListKind == "panel" then
					editor.dragTargetPanelId = self.panelId
					editor.dragTargetHasBucket = nil
					editor.dragTargetBucketId = nil
				else
					editor.dragTargetPanelId = nil
					editor.dragTargetHasBucket = true
					editor.dragTargetBucketId = self.groupId
				end
				if self.bg then self.bg:SetColorTexture(0.2, 0.7, 0.2, 0.35) end
			end)
			row:SetScript("OnLeave", function(self)
				if not editor.draggingPanel then return end
				if self._eqolPanelListKind == "panel" then
					if editor.dragTargetPanelId == self.panelId then editor.dragTargetPanelId = nil end
					updateRowVisual(self, self.panelId == editor.selectedPanelId)
				else
					editor.dragTargetHasBucket = nil
					editor.dragTargetBucketId = nil
					updateRowVisual(self, false)
				end
			end)
			row:SetScript("OnClick", function(self, button)
				if self._eqolPanelListKind == "bucket" then
					if button == "RightButton" then
						if self.groupId then CooldownPanels:ShowEditorGroupMenu(self, self.groupId) end
						return
					end
					CooldownPanels:ToggleEditorPanelGroupCollapsed(editor, self.groupId)
					CooldownPanels:RefreshEditor()
					return
				end
				if button == "RightButton" then
					if self.panelId then CooldownPanels:ShowPanelGroupAssignMenu(self, self.panelId) end
					return
				end
				if self.panelId then CooldownPanels:SelectPanel(self.panelId) end
			end)
			editor.panelRows[index] = row
		end

		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * (rowHeight + spacing)))
		row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((index - 1) * (rowHeight + spacing)))
		row:SetAlpha(1)
		row:Show()

		if entry.kind == "bucket" then
			local depth = entry.depth or 0
			row._eqolPanelListKind = "bucket"
			row.panelId = nil
			row.groupId = entry.groupId
			row.toggle:Show()
			row.toggleFrame:Show()
			row.toggleFrame:ClearAllPoints()
			row.toggleFrame:SetPoint("LEFT", row, "LEFT", 4 + (depth * 14), 0)
			row.toggle:ClearAllPoints()
			row.toggle:SetPoint("CENTER", row.toggleFrame, "CENTER", 0, 0)
			row.toggle:SetAtlas(entry.collapsed and "NPE_ArrowRight" or "NPE_ArrowDown")
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", 24 + (depth * 14), 0)
			row.label:SetText(entry.label or (L["CooldownPanelUngrouped"] or "Ungrouped"))
			row.label:SetTextColor(1, 0.9, 0.6, 1)
			row.count:SetText(tostring(entry.count or 0))
			row.count:SetTextColor(0.9, 0.9, 0.9, 1)
			updateRowVisual(row, false)
		else
			local depth = entry.depth or 1
			local panelId = entry.panelId
			local panel = entry.panel
			row._eqolPanelListKind = "panel"
			row.panelId = panelId
			row.groupId = entry.groupId
			row.toggle:Hide()
			row.toggleFrame:Hide()
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", row, "LEFT", 22 + (depth * 14), 0)
			row.label:SetText((panel and panel.name) or ("Panel " .. tostring(panelId)))
			row.label:SetTextColor(1, 1, 1, 1)
			row.count:SetText(tostring(panel and panel.order and #panel.order or 0))
			row.count:SetTextColor(0.7, 0.7, 0.7, 1)
			updateRowVisual(row, panelId == editor.selectedPanelId)
		end
	end

	for i = index + 1, #editor.panelRows do
		editor.panelRows[i]:Hide()
	end

	local totalHeight = index * (rowHeight + spacing)
	content:SetHeight(totalHeight > 1 and totalHeight or 1)
end

local function moveEntryInOrder(panel, entryId, targetEntryId)
	if not panel or not panel.order then return false end
	if not entryId or not targetEntryId or entryId == targetEntryId then return false end
	local fromIndex, toIndex
	for i, id in ipairs(panel.order) do
		if id == entryId then fromIndex = i end
		if id == targetEntryId then toIndex = i end
	end
	if not fromIndex or not toIndex then return false end
	table.remove(panel.order, fromIndex)
	if fromIndex < toIndex then toIndex = toIndex - 1 end
	table.insert(panel.order, toIndex, entryId)
	Helper.InvalidateFixedLayoutCache(panel)
	return true
end

function CooldownPanels.MoveEntryToOrderIndex(panel, entryId, targetIndex)
	if not panel or not panel.order then return false end
	targetIndex = tonumber(targetIndex)
	if not targetIndex then return false end
	local fromIndex
	for i, id in ipairs(panel.order) do
		if id == entryId then
			fromIndex = i
			break
		end
	end
	if not fromIndex then return false end
	local maxIndex = #panel.order + 1
	if targetIndex < 1 then
		targetIndex = 1
	elseif targetIndex > maxIndex then
		targetIndex = maxIndex
	end
	if fromIndex == targetIndex or fromIndex + 1 == targetIndex then return false end
	table.remove(panel.order, fromIndex)
	if fromIndex < targetIndex then targetIndex = targetIndex - 1 end
	if targetIndex > #panel.order + 1 then targetIndex = #panel.order + 1 end
	table.insert(panel.order, targetIndex, entryId)
	Helper.InvalidateFixedLayoutCache(panel)
	return true
end

function CooldownPanels:MoveEntryToFixedSlot(panelId, entryId, targetSlot)
	panelId = normalizeId(panelId)
	entryId = normalizeId(entryId)
	local panel = self:GetPanel(panelId)
	if not panel or not panel.entries then return false end
	local targetColumn, targetRow
	if type(targetSlot) == "table" then
		targetColumn = Helper.NormalizeSlotCoordinate(targetSlot.column or targetSlot.slotColumn or targetSlot.x)
		targetRow = Helper.NormalizeSlotCoordinate(targetSlot.row or targetSlot.slotRow or targetSlot.y)
	else
		local normalizedTargetSlot = Helper.NormalizeSlotIndex(targetSlot)
		if normalizedTargetSlot then
			local gridColumns = Helper.NormalizeFixedGridSize(panel.layout and panel.layout.fixedGridColumns, 0)
			if gridColumns <= 0 then
				local _, _, builtColumns = Helper.BuildFixedSlotEntryIds(panel, nil, false)
				gridColumns = builtColumns or 0
			end
			if gridColumns > 0 then
				targetColumn = ((normalizedTargetSlot - 1) % gridColumns) + 1
				targetRow = math.floor((normalizedTargetSlot - 1) / gridColumns) + 1
			end
		end
	end
	if not (targetColumn and targetRow) then return false end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	if Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) == "RADIAL" then return false end
	if not Helper.IsFixedLayout(layout) then
		layout.layoutMode = "FIXED"
		Helper.InvalidateFixedLayoutCache(panel)
		local gridColumns = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, 0)
		if gridColumns <= 0 then
			gridColumns = Helper.ClampInt(layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
			if not gridColumns or gridColumns <= 0 then gridColumns = math.min(math.max(type(panel.order) == "table" and #panel.order or 0, 4), 12) end
			layout.fixedGridColumns = gridColumns
		end
		Helper.EnsureFixedSlotAssignments(panel)
		if Helper.NormalizeFixedGridSize(layout.fixedGridRows, 0) <= 0 then
			local _, maxRow = Helper.EnsureFixedSlotAssignments(panel)
			layout.fixedGridRows = math.max(maxRow or 0, 1)
		end
	end
	Helper.EnsureFixedSlotAssignments(panel)
	if not self:IsFixedCellWithinBounds(panel, targetColumn, targetRow) then return false end
	local fromEntry = panel.entries[entryId]
	if not fromEntry then return false end
	local fromPlacement = CooldownPanels.GetEntryFixedPlacement(panel, fromEntry)
	local fromGroupId = Helper.NormalizeFixedGroupId(fromEntry.fixedGroupId)
	local targetGroup = CooldownPanels.GetFixedGroupAtCell(panel, targetColumn, targetRow)
	if targetGroup then
		if CooldownPanels.IsFixedGroupStatic(targetGroup) then
			if fromPlacement and fromPlacement.groupId == targetGroup.id and fromPlacement.column == targetColumn and fromPlacement.row == targetRow then return false end
			local targetOccupantId, targetOccupant = self:GetEntryAtStaticGroupCell(panel, targetGroup.id, targetColumn, targetRow, entryId)
			if targetOccupant then
				local swapPlacement = fromPlacement
				if not swapPlacement or (swapPlacement.groupId == targetGroup.id and swapPlacement.column == targetColumn and swapPlacement.row == targetRow) then
					local freeColumn, freeRow = self:FindFirstFreeStaticGroupCell(panel, targetGroup.id, entryId)
					if not (freeColumn and freeRow) then return false end
					swapPlacement = {
						groupId = targetGroup.id,
						column = freeColumn,
						row = freeRow,
					}
				end
				CooldownPanels.AssignEntryFixedPlacement(targetOccupant, swapPlacement)
				self:SyncEntryFixedGroupState(panel, targetOccupant)
			end
			CooldownPanels.AssignEntryFixedPlacement(fromEntry, {
				groupId = targetGroup.id,
				column = targetColumn,
				row = targetRow,
			})
			self:SyncEntryFixedGroupState(panel, fromEntry)
			Helper.InvalidateFixedLayoutCache(panel)
			Helper.EnsureFixedSlotAssignments(panel)
			return true
		end
		local targetLocalIndex = Helper.GetFixedGroupLocalIndex(targetGroup, targetColumn, targetRow) or (#CooldownPanels.GetFixedGroupEntriesInOrder(panel, targetGroup.id, entryId) + 1)
		local changed = false
		if fromGroupId ~= targetGroup.id then
			fromEntry.fixedGroupId = targetGroup.id
			changed = true
		end
		fromEntry.slotColumn = nil
		fromEntry.slotRow = nil
		fromEntry.slotIndex = nil
		self:SyncEntryFixedGroupState(panel, fromEntry)
		local groupMemberIds = CooldownPanels.GetFixedGroupEntriesInOrder(panel, targetGroup.id, entryId)
		local desiredIndex = math.max(1, math.min(targetLocalIndex, #groupMemberIds + 1))
		if desiredIndex <= #groupMemberIds then
			if moveEntryInOrder(panel, entryId, groupMemberIds[desiredIndex]) then changed = true end
		else
			local lastIndex
			for i, id in ipairs(panel.order or {}) do
				if id ~= entryId then
					local candidate = panel.entries and panel.entries[id]
					if candidate and Helper.NormalizeFixedGroupId(candidate.fixedGroupId) == targetGroup.id then lastIndex = i end
				end
			end
			if CooldownPanels.MoveEntryToOrderIndex(panel, entryId, (lastIndex or #panel.order) + 1) then changed = true end
		end
		if changed then Helper.InvalidateFixedLayoutCache(panel) end
		Helper.EnsureFixedSlotAssignments(panel)
		return changed
	end
	if fromPlacement and fromPlacement.groupId == nil and fromPlacement.column == targetColumn and fromPlacement.row == targetRow then return false end
	local swapId, swapEntry = self:GetEntryAtUngroupedFixedCell(panel, targetColumn, targetRow, entryId)
	if swapEntry then
		local swapPlacement = fromPlacement
		if not swapPlacement or (swapPlacement.groupId == nil and swapPlacement.column == targetColumn and swapPlacement.row == targetRow) then
			local freeColumn, freeRow = self:FindFirstFreeUngroupedFixedCell(panel, entryId)
			if not (freeColumn and freeRow) then return false end
			swapPlacement = {
				groupId = nil,
				column = freeColumn,
				row = freeRow,
			}
		end
		CooldownPanels.AssignEntryFixedPlacement(swapEntry, swapPlacement)
		self:SyncEntryFixedGroupState(panel, swapEntry)
	end
	CooldownPanels.AssignEntryFixedPlacement(fromEntry, {
		groupId = nil,
		column = targetColumn,
		row = targetRow,
	})
	self:SyncEntryFixedGroupState(panel, fromEntry)
	Helper.InvalidateFixedLayoutCache(panel)
	Helper.EnsureFixedSlotAssignments(panel)
	return true
end

function CooldownPanels:GetLayoutEditCursorSlot(panelId)
	panelId = normalizeId(panelId)
	if not panelId then return nil end
	local runtime = getRuntime(panelId)
	local frame = runtime and runtime.frame
	if not frame or not frame.icons then return nil end
	local cursorX, cursorY = self:GetCursorPositionOnUIParent()
	if not (cursorX and cursorY) then return nil end
	local grid = frame.editGrid
	if grid and grid.cells then
		for i = 1, #grid.cells do
			local cell = grid.cells[i]
			if cell and cell.IsShown and cell:IsShown() then
				local left = cell.GetLeft and cell:GetLeft()
				local right = cell.GetRight and cell:GetRight()
				local top = cell.GetTop and cell:GetTop()
				local bottom = cell.GetBottom and cell:GetBottom()
				if left and right and top and bottom and cursorX >= left and cursorX <= right and cursorY <= top and cursorY >= bottom then
					local column = Helper.NormalizeSlotCoordinate(cell._eqolLayoutSlotColumn)
					local row = Helper.NormalizeSlotCoordinate(cell._eqolLayoutSlotRow)
					if column and row then return { column = column, row = row } end
				end
			end
		end
	end
	for i = 1, #frame.icons do
		local icon = frame.icons[i]
		local handle = icon and icon.layoutHandle
		if handle and handle.IsShown and handle:IsShown() then
			local bounds = icon or handle
			local left = bounds and bounds.GetLeft and bounds:GetLeft()
			local right = bounds and bounds.GetRight and bounds:GetRight()
			local top = bounds and bounds.GetTop and bounds:GetTop()
			local bottom = bounds and bounds.GetBottom and bounds:GetBottom()
			if left and right and top and bottom and cursorX >= left and cursorX <= right and cursorY <= top and cursorY >= bottom then
				local column = Helper.NormalizeSlotCoordinate(handle._eqolLayoutSlotColumn)
				local row = Helper.NormalizeSlotCoordinate(handle._eqolLayoutSlotRow)
				if column and row then return { column = column, row = row } end
			end
		end
	end
	return nil
end

local function refreshEntryList(editor, panel)
	local list = editor.entryList
	if not list then return end
	local content = list.content
	local rowHeight = 30
	local spacing = 4
	local index = 0

	if panel and panel.order then
		for _, entryId in ipairs(panel.order or {}) do
			local entry = panel.entries and panel.entries[entryId]
			if entry then
				index = index + 1
				local row = editor.entryRows[index]
				if not row then
					row = Helper.CreateRowButton(content, rowHeight)
					row.icon = row:CreateTexture(nil, "ARTWORK")
					row.icon:SetSize(22, 22)
					row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

					row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
					row.label:SetTextColor(1, 1, 1, 1)

					row.kind = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
					row.kind:SetPoint("RIGHT", row, "RIGHT", -6, 0)
					row:RegisterForDrag("LeftButton")
					row:SetScript("OnDragStart", function(self)
						if not editor.selectedPanelId then return end
						editor.dragEntryId = self.entryId
						editor.dragTargetId = nil
						editor.dragPreviewSlot = nil
						editor.draggingEntry = true
						showEditorDragIcon(editor, self.icon and self.icon:GetTexture())
						self:SetAlpha(0.6)
					end)
					row:SetScript("OnDragStop", function(self)
						self:SetAlpha(1)
						if not editor.draggingEntry then return end
						editor.draggingEntry = nil
						hideEditorDragIcon(editor)
						local fromId = editor.dragEntryId
						local targetId = editor.dragTargetId
						local panelId = editor.selectedPanelId
						local targetSlot = editor.dragPreviewSlot or CooldownPanels:GetLayoutEditCursorSlot(panelId)
						editor.dragEntryId = nil
						editor.dragTargetId = nil
						editor.dragPreviewSlot = nil
						if not fromId then
							CooldownPanels:RefreshEditor()
							return
						end
						local activePanel = panelId and CooldownPanels:GetPanel(panelId) or nil
						if activePanel and targetSlot then
							if CooldownPanels:MoveEntryToFixedSlot(panelId, fromId, targetSlot) then CooldownPanels:RefreshPanel(panelId) end
						elseif activePanel and targetId and fromId ~= targetId and moveEntryInOrder(activePanel, fromId, targetId) then
							CooldownPanels:RefreshPanel(panelId)
						end
						CooldownPanels:RefreshEditor()
					end)
					row:SetScript("OnEnter", function(self)
						if editor.draggingEntry then
							editor.dragTargetId = self.entryId
							if self.bg then self.bg:SetColorTexture(0.2, 0.7, 0.2, 0.35) end
						end
					end)
					row:SetScript("OnLeave", function(self)
						if editor.draggingEntry then updateRowVisual(self, self.entryId == editor.selectedEntryId) end
					end)
					editor.entryRows[index] = row
				end
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * (rowHeight + spacing)))
				row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -((index - 1) * (rowHeight + spacing)))

				row.entryId = entryId
				row.icon:SetTexture(getEntryIcon(entry))
				local label = getEntryName(entry)
				local group = CooldownPanels.GetFixedGroupById(panel, entry.fixedGroupId)
				local groupLabel = group and CooldownPanels.GetFixedGroupDisplayLabel(group) or nil
				if groupLabel then label = string.format("%s {%s}", label, groupLabel) end
				row.label:SetText(label)
				row.kind:SetText(getEntryTypeLabel(entry.type))
				row:Show()

				updateRowVisual(row, entryId == editor.selectedEntryId)
				row:SetScript("OnClick", function() CooldownPanels:SelectEntry(entryId) end)
			end
		end
	end

	for i = index + 1, #editor.entryRows do
		editor.entryRows[i]:Hide()
	end

	local totalHeight = index * (rowHeight + spacing)
	content:SetHeight(totalHeight > 1 and totalHeight or 1)
end

local function entryIsAvailableForPreview(entry)
	if not entry or type(entry) ~= "table" then return false end
	if entry.type == "CDM_AURA" then
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.EntryIsAvailableForPreview then return cdmAuras:EntryIsAvailableForPreview(entry) end
		return false
	end
	if entry.type == "SPELL" then
		if not entry.spellID then return false end
		return true
	elseif entry.type == "ITEM" then
		local itemID = CooldownPanels.ResolveEntryItemID(entry, entry.itemID)
		if not itemID then return false end
		if itemHasUseSpell and not itemHasUseSpell(itemID) then return false end
		if entry.showWhenEmpty == true then return true end
		return hasItem(itemID)
	elseif entry.type == "SLOT" then
		if entry.slotID and Api.GetInventoryItemID then
			local itemId = Api.GetInventoryItemID("player", entry.slotID)
			if not itemId then return entry.showWhenNoCooldown == true end
			if itemHasUseSpell and itemHasUseSpell(itemId) then return true end
			return entry.showWhenNoCooldown == true
		end
		return false
	elseif entry.type == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		if not macro then return false end
		if macro.kind == "SPELL" and macro.spellID then return true end
		if macro.kind == "ITEM" and macro.itemID then
			if itemHasUseSpell and not itemHasUseSpell(macro.itemID) then return false end
			return true
		end
		return false
	end
	return true
end

getPreviewEntryIds = function(panel)
	if not panel or type(panel.order) ~= "table" then return nil end
	if #panel.order == 0 then return nil end
	if Helper.IsFixedLayout(panel.layout) then
		local slots = Helper.BuildFixedSlotEntryIds(panel)
		return slots
	end
	local list = {}
	for _, entryId in ipairs(panel.order) do
		local entry = panel.entries and panel.entries[entryId]
		if entry and entryIsAvailableForPreview(entry) then list[#list + 1] = entryId end
	end
	return list
end

local function getPreviewLayout(panel, previewFrame, count)
	local baseLayout = (panel and panel.layout) or Helper.PANEL_LAYOUT_DEFAULTS
	local previewLayout = Helper.CopyTableShallow(baseLayout)
	local layoutMode = Helper.NormalizeLayoutMode(baseLayout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode)
	local baseIconSize = Helper.ClampInt(baseLayout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
	local scale = baseIconSize > 0 and (Helper.PREVIEW_ICON_SIZE / baseIconSize) or 1
	previewLayout.iconSize = Helper.PREVIEW_ICON_SIZE
	if type(baseLayout.rowSizes) == "table" then
		previewLayout.rowSizes = {}
		for index, size in pairs(baseLayout.rowSizes) do
			local num = tonumber(size)
			if num then previewLayout.rowSizes[index] = Helper.ClampInt(num * scale, 12, 128, Helper.PREVIEW_ICON_SIZE) end
		end
	end
	local baseRadius = Helper.ClampInt(baseLayout.radialRadius, 0, Helper.RADIAL_RADIUS_RANGE or 600, Helper.PANEL_LAYOUT_DEFAULTS.radialRadius)
	previewLayout.radialRadius = Helper.ClampInt(baseRadius * scale, 0, Helper.RADIAL_RADIUS_RANGE or 600, baseRadius)
	local stackSize = tonumber(previewLayout.stackFontSize or Helper.PANEL_LAYOUT_DEFAULTS.stackFontSize) or Helper.PANEL_LAYOUT_DEFAULTS.stackFontSize
	previewLayout.stackFontSize = math.max(stackSize, Helper.PREVIEW_COUNT_FONT_MIN)
	local chargesSize = tonumber(previewLayout.chargesFontSize or Helper.PANEL_LAYOUT_DEFAULTS.chargesFontSize) or Helper.PANEL_LAYOUT_DEFAULTS.chargesFontSize
	previewLayout.chargesFontSize = math.max(chargesSize, Helper.PREVIEW_COUNT_FONT_MIN)
	local keybindSize = tonumber(previewLayout.keybindFontSize or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize) or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize
	previewLayout.keybindFontSize = math.max(keybindSize, Helper.PREVIEW_COUNT_FONT_MIN)

	if not previewFrame or not count or count < 1 then return previewLayout end

	local iconSize = Helper.PREVIEW_ICON_SIZE
	local spacing = Helper.ClampInt(baseLayout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS.spacing)

	local width = previewFrame:GetWidth() or 0
	local height = previewFrame:GetHeight() or 0
	local step = iconSize + spacing
	if width <= 0 or height <= 0 or step <= 0 then return previewLayout end

	if layoutMode == "RADIAL" then
		local padding = 8
		local maxRadius = math.floor((math.min(width, height) - padding) / 2)
		if maxRadius < 0 then maxRadius = 0 end
		previewLayout.radialRadius = Helper.ClampInt(previewLayout.radialRadius, 0, maxRadius, previewLayout.radialRadius)
		return previewLayout
	end

	local direction = Helper.NormalizeDirection(baseLayout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction)
	local wrapCount = Helper.ClampInt(baseLayout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)

	local primaryHorizontal = direction == "LEFT" or direction == "RIGHT"
	local available = primaryHorizontal and width or height
	local maxPrimary = math.floor((available + spacing) / step)
	if maxPrimary < 1 then maxPrimary = 1 end

	if wrapCount == 0 then
		if count > maxPrimary then previewLayout.wrapCount = maxPrimary end
	else
		previewLayout.wrapCount = math.min(wrapCount, maxPrimary)
	end

	return previewLayout
end

local function refreshPreview(editor, panel)
	if not editor.previewFrame then return end
	local preview = editor.previewFrame
	local canvas = preview.canvas or preview
	if not panel then
		if editor.previewHintLabel then editor.previewHintLabel:Hide() end
		ensureIconCount(canvas, 0)
		canvas:SetSize(1, 1)
		canvas:ClearAllPoints()
		canvas:SetPoint("CENTER", preview, "CENTER")
		if preview.dropHint then
			local root = CooldownPanels:GetRoot()
			local hasPanels = root and ((root.order and #root.order > 0) or (root.panels and next(root.panels)))
			preview.dropHint:SetText(hasPanels and (L["CooldownPanelSelectPanel"] or "Select a panel to edit.") or (L["CooldownPanelCreatePanel"] or "Create a Panel"))
			preview.dropHint:Show()
		end
		return
	end

	local panelId = normalizeId(panel.id)
	local hasEntries = (panel.order and #panel.order or 0) > 0
	local baseLayout = (panel and panel.layout) or Helper.PANEL_LAYOUT_DEFAULTS
	local fixedLayout = Helper.IsFixedLayout(baseLayout)
	local previewLayoutSource = baseLayout
	if editor.previewHintLabel then
		editor.previewHintLabel:SetText(L["CooldownPanelPreviewHint"] or "Drag spells/items/macros here to add")
		editor.previewHintLabel:SetShown(hasEntries)
	end
	if editor.entryHint then editor.entryHint:SetText(L["CooldownPanelEntriesHint"] or "Drag entries to reorder") end
	local previewEntryIds, count
	if not hasEntries then
		count = 0
	elseif fixedLayout then
		previewEntryIds = {}
		for _, entryId in ipairs(panel.order or {}) do
			local entry = panel.entries and panel.entries[entryId] or nil
			if entry and entryIsAvailableForPreview(entry) then previewEntryIds[#previewEntryIds + 1] = entryId end
		end
		count = #previewEntryIds
		previewLayoutSource = Helper.CopyTableShallow(baseLayout)
		previewLayoutSource.layoutMode = "GRID"
		previewLayoutSource.direction = "RIGHT"
		previewLayoutSource.wrapDirection = "DOWN"
		previewLayoutSource.wrapCount = 0
	else
		count = getEditorPreviewCount(panel, preview, baseLayout)
	end
	local layout = getPreviewLayout({ layout = previewLayoutSource }, preview, count)
	applyIconLayout(canvas, count, layout)
	canvas:ClearAllPoints()
	canvas:SetPoint("CENTER", preview, "CENTER")
	local showKeybinds = layout.keybindsEnabled == true
	local staticFontPath, staticFontSize, staticFontStyle = Helper.GetCountFontDefaults(canvas)
	local defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle = staticFontPath, staticFontSize, staticFontStyle
	local defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle = Helper.GetChargesFontDefaults(canvas)
	local effectiveLayoutCache = {}

	preview.entryByIndex = preview.entryByIndex or {}
	for i = 1, count do
		local entryId
		if fixedLayout then
			entryId = previewEntryIds and previewEntryIds[i] or nil
		else
			entryId = (previewEntryIds and previewEntryIds[i]) or (panel.order and panel.order[i])
		end
		local entry = entryId and panel.entries and panel.entries[entryId] or nil
		local effectiveType = entry and entry.type or nil
		if effectiveType == "MACRO" then
			local macro = CooldownPanels.ResolveMacroEntry(entry)
			effectiveType = (macro and macro.kind) or "MACRO"
		end
		local entryLayout = entry and CooldownPanels:GetEntryEffectiveLayout(panelId, entry, effectiveLayoutCache, panel) or baseLayout
		local icon = canvas.icons[i]
		local showCooldown = entry and entry.showCooldown ~= false
		local staticCooldown = entry and entry.staticTextShowOnCooldown == true or false
		local showEntryIconTexture = entry and CooldownPanels:ResolveEntryShowIconTexture(entryLayout, entry) or true
		local showGhostIcon = entry and CooldownPanels:ShouldShowEditorGhostIcon(entryLayout, entry, showEntryIconTexture, true) or false
		local stateTextureType, stateTextureValue, stateTextureWidth, stateTextureHeight, stateTextureScale, stateTextureAngle, stateTextureDouble, stateTextureMirror, stateTextureMirrorSecond, stateTextureSpacingX, stateTextureSpacingY
		if entry then
			stateTextureType, stateTextureValue, stateTextureWidth, stateTextureHeight, stateTextureScale, stateTextureAngle, stateTextureDouble, stateTextureMirror, stateTextureMirrorSecond, stateTextureSpacingX, stateTextureSpacingY =
				CooldownPanels:ResolveEntryStateTexture(entry)
		end
		icon:Show()
		icon.entryId = entryId
		icon._eqolPreviewCellColumn = i
		icon._eqolPreviewCellRow = 1
		icon._eqolTooltipEntry = entry
		icon._eqolTooltipEnabled = entry ~= nil
		CooldownPanels:ApplyEntryIconVisualLayout(icon, entryLayout, entry)
		CooldownPanels:HideEditorGhostIcon(icon)
		icon.texture:SetTexture(entry and getEntryIcon(entry) or Helper.PREVIEW_ICON)
		icon.texture:SetShown(showEntryIconTexture)
		icon.texture:SetVertexColor(1, 1, 1)
		icon.texture:SetDesaturated(false)
		icon.texture:SetAlpha(1)
		if icon.cooldown.SetReverse then icon.cooldown:SetReverse(effectiveType == "CDM_AURA") end
		if icon.cooldown.SetUseAuraDisplayTime then icon.cooldown:SetUseAuraDisplayTime(effectiveType == "CDM_AURA") end
		icon.cooldown:Clear()
		icon.count:Hide()
		icon.charges:Hide()
		if icon.rangeOverlay then icon.rangeOverlay:Hide() end
		if icon.keybind then icon.keybind:Hide() end
		if icon.stateTexture then
			applyStateTexture(icon, {
				stateTextureShown = entry ~= nil and stateTextureType ~= nil,
				stateTextureType = stateTextureType,
				stateTextureValue = stateTextureValue,
				stateTextureWidth = stateTextureWidth,
				stateTextureHeight = stateTextureHeight,
				stateTextureScale = stateTextureScale,
				stateTextureAngle = stateTextureAngle,
				stateTextureDouble = stateTextureDouble,
				stateTextureMirror = stateTextureMirror,
				stateTextureMirrorSecond = stateTextureMirrorSecond,
				stateTextureSpacingX = stateTextureSpacingX,
				stateTextureSpacingY = stateTextureSpacingY,
			})
		end
		CooldownPanels.HidePreviewGlowBorder(icon)
		if icon.previewBling then icon.previewBling:Hide() end
		if icon.previewSoundBorder then icon.previewSoundBorder:Hide() end
		icon:EnableMouse(false)
		icon._eqolPreviewSlotIndex = nil
		icon._eqolPreviewSlotColumn = nil
		icon._eqolPreviewSlotRow = nil
		icon:SetScript("OnEnter", CooldownPanels.ShowIconTooltip)
		icon:SetScript("OnLeave", CooldownPanels.HideIconTooltip)
		icon:SetScript("OnDragStart", nil)
		icon:SetScript("OnDragStop", nil)
		icon:SetScript("OnReceiveDrag", nil)
		icon:SetScript("OnMouseUp", nil)
		if not entry then
			if icon.staticText then
				icon.staticText:ClearAllPoints()
				icon.staticText:SetPoint("CENTER", icon.overlay, "CENTER", 0, 0)
				icon.staticText:SetFont(staticFontPath, math.max(11, staticFontSize or 12), staticFontStyle or "")
				icon.staticText:SetTextColor(0.62, 0.62, 0.62, 0.9)
				icon.staticText:SetText(tostring(i))
				icon.staticText:Show()
			end
			icon.texture:SetDesaturated(true)
			icon.texture:SetAlpha(fixedLayout and 0.18 or 0.08)
			CooldownPanels.ApplyIconTooltip(icon, nil, false)
			preview.entryByIndex[i] = nil
		else
			CooldownPanels:ApplyEntryCooldownTextStyle(icon, entryLayout, entry)
			CooldownPanels:ApplyEntryStackTextStyle(icon, entryLayout, entry, defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
			CooldownPanels:ApplyEntryChargesTextStyle(icon, entryLayout, entry, defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
			applyStaticText(icon, entryLayout, entry, staticFontPath, staticFontSize, staticFontStyle, staticCooldown)
			icon.texture:SetShown(showEntryIconTexture)
			if showGhostIcon then CooldownPanels:ApplyEditorGhostIcon(icon) end
			preview.entryByIndex[i] = entryId
		end
		if entry then
			if effectiveType == "SPELL" then
				if entry.showCharges then
					icon.charges:SetText("2")
					icon.charges:Show()
				end
				if entry.showStacks then
					icon.count:SetText("3")
					icon.count:Show()
				end
			elseif effectiveType == "CDM_AURA" then
				local cdmAuras = CooldownPanels.CDMAuras
				if cdmAuras and cdmAuras.ApplyPreview then
					cdmAuras:ApplyPreview(icon, entry)
				elseif entry.showStacks then
					icon.count:SetText("2")
					icon.count:Show()
				end
			elseif effectiveType == "ITEM" then
				if entry.showItemCount ~= false then
					icon.count:SetText("20")
					icon.count:Show()
				end
			end
			if entryLayout.keybindsEnabled == true and icon.keybind then
				local keyText = Keybinds.GetEntryKeybindText(entry, entryLayout)
				if not keyText and entry and entry.type == "SPELL" then keyText = "K" end
				if keyText then
					icon.keybind:SetText(keyText)
					icon.keybind:Show()
				else
					icon.keybind:Hide()
				end
			elseif icon.keybind then
				icon.keybind:Hide()
			end
			if entry.type ~= "MACRO" and (entry.glowReady or entry.pandemicGlow) and icon.previewGlowBorder then
				local previewEntryGlowColor = (entry.type == "CDM_AURA" and entry.pandemicGlow == true and entry.glowReady ~= true and CooldownPanels:ResolveEntryPandemicGlowColor(entryLayout, entry))
					or select(2, CooldownPanels:ResolveEntryGlowStyle(entryLayout, entry))
				CooldownPanels.ShowPreviewGlowBorder(icon, previewEntryGlowColor)
			end
			do
				local _, previewSoundEnabledField = CooldownPanels:GetEntrySoundConfig(entry)
				if previewSoundEnabledField and entry[previewSoundEnabledField] == true and icon.previewSoundBorder then icon.previewSoundBorder:Show() end
			end
		end
	end

	for i = count + 1, #(canvas.icons or {}) do
		local icon = canvas.icons[i]
		if icon then
			icon:Hide()
			icon.entryId = nil
			icon._eqolTooltipEntry = nil
			icon._eqolTooltipEnabled = nil
			CooldownPanels:HideEditorGhostIcon(icon)
			if icon.staticText then icon.staticText:Hide() end
			if icon.cooldown and icon.cooldown.Clear then icon.cooldown:Clear() end
			if icon.stateTexture then icon.stateTexture:Hide() end
			if icon.stateTextureSecond then icon.stateTextureSecond:Hide() end
		end
	end

	if preview.dropHint then preview.dropHint:SetShown(not hasEntries and not fixedLayout) end
end

local function layoutInspectorToggles(inspector, entry)
	if not inspector then return end
	local function hideToggle(cb)
		if not cb then return end
		cb:Hide()
		cb:Disable()
		cb:SetChecked(false)
	end
	local function hideControl(control)
		if not control then return end
		control:Hide()
		if control.Disable then control:Disable() end
	end
	if not entry then
		hideToggle(inspector.cbCooldownText)
		hideToggle(inspector.cbAlwaysShow)
		hideToggle(inspector.cbCharges)
		hideToggle(inspector.cbStacks)
		hideToggle(inspector.cbItemCount)
		hideToggle(inspector.cbItemUses)
		hideToggle(inspector.cbUseHighestRank)
		hideToggle(inspector.cbShowWhenEmpty)
		hideToggle(inspector.cbShowWhenNoCooldown)
		hideControl(inspector.staticTextLabel)
		hideControl(inspector.staticTextBox)
		hideToggle(inspector.cbStaticTextDuringCD)
		hideToggle(inspector.cbGlow)
		hideToggle(inspector.cbPandemicGlow)
		hideToggle(inspector.cbSound)
		hideControl(inspector.soundButton)
		if inspector.content and inspector.scroll then
			local height = inspector.scroll:GetHeight() or 1
			inspector.content:SetHeight(height)
		end
		return
	end

	local prev = inspector.entryId
	local effectiveType = entry and entry.type or nil
	local entryAnchor = inspector.entryIcon or inspector.entryId or inspector.entryType
	if effectiveType == "MACRO" then
		local macro = CooldownPanels.ResolveMacroEntry(entry)
		effectiveType = (macro and macro.kind) or "MACRO"
	end
	local cdmAuras = CooldownPanels.CDMAuras
	if effectiveType == "CDM_AURA" then
		prev = (cdmAuras and cdmAuras.LayoutInspector and cdmAuras:LayoutInspector(inspector, entry, entryAnchor)) or entryAnchor
	elseif effectiveType == "STANCE" or effectiveType == "SLOT" then
		prev = entryAnchor
		if cdmAuras and cdmAuras.LayoutInspector then cdmAuras:LayoutInspector(inspector, nil, prev) end
	else
		if cdmAuras and cdmAuras.LayoutInspector then cdmAuras:LayoutInspector(inspector, nil, prev) end
	end
	local function place(control, show, offsetX, offsetY)
		if not control then return end
		control:ClearAllPoints()
		control:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", offsetX or 0, offsetY or -6)
		if show then
			control:Show()
			if control.Enable then control:Enable() end
			prev = control
		else
			control:Hide()
			if control.Disable then control:Disable() end
		end
	end

	place(inspector.cbCooldownText, effectiveType ~= "STANCE", -2)
	if effectiveType == "SPELL" then
		place(inspector.cbAlwaysShow, false)
		place(inspector.cbCharges, true)
		place(inspector.cbStacks, true)
		place(inspector.cbItemCount, false)
		place(inspector.cbItemUses, false)
		place(inspector.cbUseHighestRank, false)
		place(inspector.cbShowWhenEmpty, false)
		place(inspector.cbShowWhenNoCooldown, false)
	elseif effectiveType == "ITEM" then
		place(inspector.cbAlwaysShow, true)
		place(inspector.cbCharges, false)
		place(inspector.cbStacks, false)
		place(inspector.cbItemCount, true)
		place(inspector.cbItemUses, true)
		CooldownPanels:EnsureFoodRankGroupsLoaded()
		local itemID = tonumber(entry and entry.itemID)
		local rankMap = CooldownPanels.itemHighestRankByID
		place(inspector.cbUseHighestRank, entry and entry.type == "ITEM" and itemID and rankMap and rankMap[itemID] ~= nil)
		place(inspector.cbShowWhenEmpty, true)
		place(inspector.cbShowWhenNoCooldown, false)
	elseif effectiveType == "SLOT" then
		place(inspector.cbAlwaysShow, false)
		place(inspector.cbCharges, false)
		place(inspector.cbStacks, false)
		place(inspector.cbItemCount, false)
		place(inspector.cbItemUses, false)
		place(inspector.cbUseHighestRank, false)
		place(inspector.cbShowWhenEmpty, false)
		place(inspector.cbShowWhenNoCooldown, true)
	elseif effectiveType == "CDM_AURA" then
		place(inspector.cbAlwaysShow, true)
		place(inspector.cbCharges, false)
		place(inspector.cbStacks, true)
		place(inspector.cbItemCount, false)
		place(inspector.cbItemUses, false)
		place(inspector.cbUseHighestRank, false)
		place(inspector.cbShowWhenEmpty, false)
		place(inspector.cbShowWhenNoCooldown, false)
	elseif effectiveType == "STANCE" then
		place(inspector.cbAlwaysShow, true)
		place(inspector.cbCharges, false)
		place(inspector.cbStacks, false)
		place(inspector.cbItemCount, false)
		place(inspector.cbItemUses, false)
		place(inspector.cbUseHighestRank, false)
		place(inspector.cbShowWhenEmpty, false)
		place(inspector.cbShowWhenNoCooldown, false)
	else
		place(inspector.cbAlwaysShow, false)
		place(inspector.cbCharges, false)
		place(inspector.cbStacks, false)
		place(inspector.cbItemCount, false)
		place(inspector.cbItemUses, false)
		place(inspector.cbUseHighestRank, false)
		place(inspector.cbShowWhenEmpty, false)
		place(inspector.cbShowWhenNoCooldown, false)
	end
	local allowStaticText = true
	place(inspector.staticTextLabel, allowStaticText, 2, -8)
	place(inspector.staticTextBox, allowStaticText, -2, -4)
	place(inspector.cbStaticTextDuringCD, allowStaticText, -2, -6)
	local showGlowToggle = entry.type ~= "MACRO"
	local showPandemicGlowToggle = effectiveType == "CDM_AURA"
	local showReadyEffects = entry.type ~= "MACRO" and entry.type ~= "STANCE" and entry.type ~= "CDM_AURA"
	local _, soundEnabledField = CooldownPanels:GetEntrySoundConfig(entry)
	local showSoundEffects = soundEnabledField ~= nil
	place(inspector.cbGlow, showGlowToggle)
	place(inspector.cbPandemicGlow, showPandemicGlowToggle)
	place(inspector.cbSound, showSoundEffects, 0, -6)
	if showSoundEffects and inspector.soundButton then
		inspector.soundButton:ClearAllPoints()
		inspector.soundButton:SetPoint("TOPLEFT", inspector.cbSound, "BOTTOMLEFT", 18, -6)
		if entry[soundEnabledField] == true then
			inspector.soundButton:Show()
			inspector.soundButton:Enable()
			prev = inspector.soundButton
		else
			inspector.soundButton:Hide()
			inspector.soundButton:Disable()
		end
	elseif inspector.soundButton then
		inspector.soundButton:Hide()
		inspector.soundButton:Disable()
	end

	if inspector.soundButton and inspector.soundButton:IsShown() then prev = inspector.soundButton end
	if inspector.removeEntry then
		inspector.removeEntry:ClearAllPoints()
		if inspector.content and inspector.content.GetTop and prev and prev.GetBottom then
			local top = inspector.content:GetTop()
			local bottom = prev:GetBottom()
			if top and bottom then
				inspector.removeEntry:SetPoint("TOP", inspector.content, "TOP", 0, (bottom - top) - 12)
			else
				inspector.removeEntry:SetPoint("TOP", prev, "BOTTOM", 0, -12)
			end
		else
			inspector.removeEntry:SetPoint("TOP", prev, "BOTTOM", 0, -12)
		end
		inspector.removeEntry:Show()
		if inspector.removeEntry.Enable then inspector.removeEntry:Enable() end
	end

	if inspector.content and inspector.panelHeader and inspector.removeEntry then
		local top = inspector.panelHeader:GetTop()
		local bottom = inspector.removeEntry:GetBottom()
		if top and bottom then
			local height = (top - bottom) + 20
			local minHeight = inspector.scroll and inspector.scroll:GetHeight() or 1
			if height < minHeight then height = minHeight end
			if height < 1 then height = 1 end
			inspector.content:SetHeight(height)
		end
	end
end

local function refreshInspector(editor, panel, entry)
	local inspector = editor.inspector
	if not inspector then return end

	if panel then
		inspector.panelName:SetText(panel.name or "")
		inspector.panelEnabled:SetChecked(panel.enabled ~= false)
		inspector.panelName:Enable()
		inspector.panelEnabled:Enable()
		if inspector.panelSpecButton then
			Helper.SetButtonTextEllipsized(inspector.panelSpecButton, getSpecFilterLabel(panel))
			inspector.panelSpecButton:Enable()
		end
		if inspector.panelSpecLabel then inspector.panelSpecLabel:Show() end
	else
		inspector.panelName:SetText("")
		inspector.panelName:Disable()
		inspector.panelEnabled:SetChecked(false)
		inspector.panelEnabled:Disable()
		if inspector.panelSpecButton then
			Helper.SetButtonTextEllipsized(inspector.panelSpecButton, L["CooldownPanelSpecAny"] or "All specs")
			inspector.panelSpecButton:Disable()
		end
		if inspector.panelSpecLabel then inspector.panelSpecLabel:Hide() end
	end

	if entry then
		if inspector.entryHeader then inspector.entryHeader:Show() end
		if inspector.entryEmptyHint then inspector.entryEmptyHint:Hide() end
		if inspector.entryIcon then inspector.entryIcon:Show() end
		if inspector.entryName then inspector.entryName:Show() end
		if inspector.entryType then inspector.entryType:Show() end

		inspector.entryIcon:SetTexture(getEntryIcon(entry))
		inspector.entryName:SetText(getEntryName(entry))
		inspector.entryType:SetText(getEntryTypeLabel(entry.type))
		local entryIdText = tostring(entry.spellID or entry.itemID or entry.slotID or entry.stanceID or entry.macroID or "")
		local cdmAuras = CooldownPanels.CDMAuras
		if entry.type == "CDM_AURA" and cdmAuras and cdmAuras.GetEntryIdText then entryIdText = tostring(cdmAuras:GetEntryIdText(entry) or "") end
		inspector.entryId:SetText(entryIdText)
		local effectiveType = entry and entry.type or nil
		if effectiveType == "MACRO" then
			local macro = CooldownPanels.ResolveMacroEntry(entry)
			effectiveType = (macro and macro.kind) or "MACRO"
		end
		local showEntryIdBox = effectiveType ~= "STANCE" and effectiveType ~= "SLOT" and effectiveType ~= "CDM_AURA"
		if inspector.entryId then
			if showEntryIdBox then
				inspector.entryId:Show()
				inspector.entryId:Enable()
			else
				inspector.entryId:Hide()
				inspector.entryId:Disable()
			end
			if inspector.entryId.SetNumeric then inspector.entryId:SetNumeric(showEntryIdBox) end
		end
		if inspector.cbAlwaysShow and inspector.cbAlwaysShow.Text then
			if effectiveType == "STANCE" then
				inspector.cbAlwaysShow.Text:SetText(L["CooldownPanelShowWhenMissing"] or "Show when missing")
			else
				inspector.cbAlwaysShow.Text:SetText(L["CooldownPanelAlwaysShow"] or "Always show")
			end
		end
		if inspector.cbGlow and inspector.cbGlow.Text then
			if effectiveType == "STANCE" then
				inspector.cbGlow.Text:SetText(_G.GLOW or "Glow")
			elseif effectiveType == "CDM_AURA" then
				inspector.cbGlow.Text:SetText(L["CooldownPanelGlowActive"] or "Glow when active")
			else
				inspector.cbGlow.Text:SetText(L["CooldownPanelGlowReady"] or "Glow when ready")
			end
		end
		if inspector.cbPandemicGlow and inspector.cbPandemicGlow.Text then inspector.cbPandemicGlow.Text:SetText(L["CooldownPanelGlowPandemic"] or "Pandemic glow") end
		if inspector.cbSound and inspector.cbSound.Text then
			local _, _, _, soundLabel = CooldownPanels:GetEntrySoundConfig(entry)
			inspector.cbSound.Text:SetText(soundLabel or (L["CooldownPanelSoundReady"] or "Sound when ready"))
		end

		inspector.cbCooldownText:SetChecked(entry.showCooldownText ~= false)
		if effectiveType == "STANCE" then
			inspector.cbAlwaysShow:SetChecked(entry.showWhenMissing == true)
		else
			local alwaysShowChecked = effectiveType == "ITEM" and entry.alwaysShow ~= false
			if effectiveType == "CDM_AURA" then
				alwaysShowChecked = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(panel and panel.layout or nil, entry)
					~= (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.HIDE or "HIDE")
			end
			inspector.cbAlwaysShow:SetChecked(alwaysShowChecked)
		end
		inspector.cbCharges:SetChecked(entry.showCharges and true or false)
		inspector.cbStacks:SetChecked(entry.showStacks and true or false)
		inspector.cbItemCount:SetChecked(effectiveType == "ITEM" and entry.showItemCount ~= false)
		inspector.cbItemUses:SetChecked(effectiveType == "ITEM" and entry.showItemUses == true)
		if inspector.cbUseHighestRank then inspector.cbUseHighestRank:SetChecked(effectiveType == "ITEM" and entry.type == "ITEM" and entry.useHighestRank == true) end
		inspector.cbShowWhenEmpty:SetChecked(effectiveType == "ITEM" and entry.showWhenEmpty == true)
		inspector.cbShowWhenNoCooldown:SetChecked(effectiveType == "SLOT" and entry.showWhenNoCooldown == true)
		inspector.cbGlow:SetChecked(entry.type ~= "MACRO" and entry.glowReady and true or false)
		if inspector.cbPandemicGlow then inspector.cbPandemicGlow:SetChecked(effectiveType == "CDM_AURA" and entry.pandemicGlow == true) end
		do
			local _, soundEnabledField, soundField = CooldownPanels:GetEntrySoundConfig(entry)
			inspector.cbSound:SetChecked(soundEnabledField and entry[soundEnabledField] == true or false)
			if inspector.soundButton then inspector.soundButton:SetText(getSoundButtonText(soundField and entry[soundField] or nil)) end
		end
		if inspector.staticTextBox then inspector.staticTextBox:SetText(entry.staticText or "") end
		if inspector.cbStaticTextDuringCD then inspector.cbStaticTextDuringCD:SetChecked(entry.staticTextShowOnCooldown == true) end

		if cdmAuras and cdmAuras.RefreshInspector then cdmAuras:RefreshInspector(editor, panel, entry) end
		inspector.removeEntry:Enable()
		layoutInspectorToggles(inspector, entry)
	else
		if inspector.entryHeader then inspector.entryHeader:Hide() end
		if inspector.entryEmptyHint then
			inspector.entryEmptyHint:SetText(L["CooldownPanelSelectEntryHint"] or "Click a spell/item/macro/slot/stance to modify")
			inspector.entryEmptyHint:Show()
		end
		if inspector.entryIcon then inspector.entryIcon:Hide() end
		if inspector.entryName then inspector.entryName:Hide() end
		if inspector.entryType then inspector.entryType:Hide() end
		if inspector.entryId then
			inspector.entryId:SetText("")
			if inspector.entryId.SetNumeric then inspector.entryId:SetNumeric(true) end
			inspector.entryId:Hide()
		end
		if inspector.cbAlwaysShow and inspector.cbAlwaysShow.Text then inspector.cbAlwaysShow.Text:SetText(L["CooldownPanelAlwaysShow"] or "Always show") end
		if inspector.cbGlow and inspector.cbGlow.Text then inspector.cbGlow.Text:SetText(L["CooldownPanelGlowReady"] or "Glow when ready") end
		if inspector.cbPandemicGlow and inspector.cbPandemicGlow.Text then inspector.cbPandemicGlow.Text:SetText(L["CooldownPanelGlowPandemic"] or "Pandemic glow") end
		if inspector.cbSound and inspector.cbSound.Text then inspector.cbSound.Text:SetText(L["CooldownPanelSoundReady"] or "Sound when ready") end

		if inspector.staticTextBox then inspector.staticTextBox:SetText("") end
		if inspector.cbStaticTextDuringCD then inspector.cbStaticTextDuringCD:SetChecked(false) end

		inspector.entryId:Disable()
		inspector.removeEntry:Disable()
		if inspector.removeEntry then inspector.removeEntry:Hide() end
		if inspector.soundButton then inspector.soundButton:SetText(getSoundButtonText(nil)) end
		local cdmAuras = CooldownPanels.CDMAuras
		if cdmAuras and cdmAuras.RefreshInspector then cdmAuras:RefreshInspector(editor, panel, nil) end
		layoutInspectorToggles(inspector, nil)
	end
end

function CooldownPanels:RefreshEditor()
	local editor = getEditor()
	if not editor or not editor.frame or not editor.frame:IsShown() then return end
	local root = ensureRoot()
	if not root then return end
	local previousLayoutPanelId = normalizeId(editor._eqolLayoutPanelId)

	Helper.SyncOrder(root.order, root.panels)
	root._orderDirty = nil

	local panelId = editor.selectedPanelId or root.selectedPanel or (root.order and root.order[1])
	if panelId and (not root.panels or not root.panels[panelId]) then panelId = root.order and root.order[1] or nil end

	local filterByClass = addon.db and addon.db.cooldownPanelsFilterClass == true
	local hideEmptyGroups = addon.db and addon.db.cooldownPanelsHideEmptyGroups == true
	local classSpecs = filterByClass and getPlayerClassSpecMap() or nil
	if filterByClass and panelId then
		local selectedPanel = root.panels and root.panels[panelId]
		if selectedPanel and not panelMatchesPlayerClass(selectedPanel, classSpecs) then panelId = findFirstPanelForClass(root, classSpecs) end
	end
	editor.selectedPanelId = panelId
	root.selectedPanel = panelId

	local panel = panelId and root.panels and root.panels[panelId] or nil
	if panel then Helper.NormalizePanel(panel, root.defaults) end

	if editor.filterButton and editor.filterButton.icon then
		if filterByClass or hideEmptyGroups then
			editor.filterButton.icon:SetVertexColor(1, 0.82, 0.2, 1)
		else
			editor.filterButton.icon:SetVertexColor(1, 1, 1, 0.9)
		end
	end
	refreshPanelList(editor, root, classSpecs)
	refreshEntryList(editor, panel)
	refreshPreview(editor, panel)

	local panelActive = panel ~= nil
	if not panelActive then editor.layoutEditActive = nil end
	local layoutEditAvailable = panelActive and CooldownPanels:IsPanelLayoutEditAvailable(panelId)
	if not layoutEditAvailable then editor.layoutEditActive = nil end
	if editor.deletePanel then
		if panelActive then
			editor.deletePanel:Enable()
		else
			editor.deletePanel:Disable()
		end
	end
	if editor.addSpellBox then
		if panelActive then
			editor.addSpellBox:Enable()
		else
			editor.addSpellBox:Disable()
		end
	end
	if editor.addItemBox then
		if panelActive then
			editor.addItemBox:Enable()
		else
			editor.addItemBox:Disable()
		end
	end
	if editor.slotButton then
		if panelActive then
			editor.slotButton:Enable()
		else
			editor.slotButton:Disable()
		end
	end
	if editor.importCDMButton then
		if panelActive then
			editor.importCDMButton:Enable()
		else
			editor.importCDMButton:Disable()
		end
	end
	if editor.layoutEditButton then
		if layoutEditAvailable then
			editor.layoutEditButton:Enable()
		else
			editor.layoutEditButton:Disable()
		end
		editor.layoutEditButton:SetText(editor.layoutEditActive == true and (L["CooldownPanelLayoutEditDone"] or "Done") or (L["CooldownPanelLayoutEdit"] or "Layout edit"))
	end

	local entryId = editor.selectedEntryId
	if panel and entryId and not (panel.entries and panel.entries[entryId]) then entryId = nil end
	editor.selectedEntryId = entryId
	local entry = panel and entryId and panel.entries and panel.entries[entryId] or nil
	refreshInspector(editor, panel, entry)

	local currentLayoutPanelId = editor.layoutEditActive == true and normalizeId(panelId) or nil
	editor._eqolLayoutPanelId = currentLayoutPanelId
	if previousLayoutPanelId ~= currentLayoutPanelId then
		if previousLayoutPanelId and self:GetPanel(previousLayoutPanelId) then self:RefreshPanel(previousLayoutPanelId) end
		if currentLayoutPanelId and self:GetPanel(currentLayoutPanelId) then self:RefreshPanel(currentLayoutPanelId) end
	elseif currentLayoutPanelId and self:GetPanel(currentLayoutPanelId) then
		self:UpdatePanelMouseState(currentLayoutPanelId)
	end
	self:RefreshLayoutEntryStandaloneMenu()
	self:RefreshLayoutPanelStandaloneMenu()
	self:RefreshLayoutFixedGroupStandaloneMenu()
end

function CooldownPanels:OpenEditor()
	local editor = ensureEditor()
	if not editor then return end
	self:NormalizeAll()
	editor.frame:Show()
end

function CooldownPanels:CloseEditor()
	local editor = getEditor()
	if not editor then return end
	local panelId = normalizeId(editor._eqolLayoutPanelId or editor.selectedPanelId)
	self:HideLayoutEntryStandaloneMenu(panelId)
	self:HideLayoutPanelStandaloneMenu(panelId)
	self:HideLayoutFixedGroupStandaloneMenu(panelId)
	editor.frame:Hide()
	editor.layoutEditActive = nil
	editor._eqolLayoutPanelId = nil
	if panelId and self:GetPanel(panelId) then self:RefreshPanel(panelId) end
end

function CooldownPanels:ToggleEditor()
	local editor = getEditor()
	if not editor then
		self:OpenEditor()
		return
	end
	if editor.frame:IsShown() then
		self:CloseEditor()
	else
		self:OpenEditor()
	end
end

function CooldownPanels:IsEditorOpen()
	local editor = getEditor()
	return editor and editor.frame and editor.frame:IsShown()
end

function CooldownPanels:EnsurePanelFrame(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return nil end
	local runtime = getRuntime(panelId)
	if runtime.frame then return runtime.frame end
	local frame = createPanelFrame(panelId, panel)
	runtime.frame = frame
	self:ApplyPanelPosition(panelId)
	self:ApplyLayout(panelId)
	self:UpdatePreviewIcons(panelId)
	return frame
end

function CooldownPanels:ApplyLayout(panelId, countOverride)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	CooldownPanels.ClearRuntimeResolvedLayoutCache(runtime)
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	local appliedLayout = layout
	local fixedLayoutCount
	if Helper.IsFixedLayout(layout) then
		local _, slotCount, gridColumns = Helper.BuildFixedSlotEntryIds(panel, nil, false)
		fixedLayoutCount = slotCount
		appliedLayout = Helper.CopyTableShallow(layout)
		appliedLayout.wrapCount = gridColumns or 0
		appliedLayout.direction = "RIGHT"
		appliedLayout.wrapDirection = "DOWN"
	end

	local count = countOverride or fixedLayoutCount or getPreviewCount(panel)
	applyIconLayout(frame, count, appliedLayout)

	frame:SetFrameStrata(Helper.NormalizeStrata(layout.strata, Helper.PANEL_LAYOUT_DEFAULTS.strata))
	syncEditModeSelectionStrata(frame)
	if frame.label then frame.label:SetText(panel.name or "Cooldown Panel") end
end

function CooldownPanels.LayoutSlotAnchorHandleOnEnter(self)
	local handle = self and self._eqolForwardHandle or nil
	local script = handle and handle.GetScript and handle:GetScript("OnEnter") or nil
	if script then script(handle) end
end

function CooldownPanels.LayoutSlotAnchorHandleOnLeave(self)
	local handle = self and self._eqolForwardHandle or nil
	local script = handle and handle.GetScript and handle:GetScript("OnLeave") or nil
	if script then script(handle) end
end

function CooldownPanels.LayoutSlotAnchorHandleOnDragStart(self)
	local handle = self and self._eqolForwardHandle or nil
	local script = handle and handle.GetScript and handle:GetScript("OnDragStart") or nil
	if script then script(handle) end
end

function CooldownPanels.LayoutSlotAnchorHandleOnDragStop(self)
	local handle = self and self._eqolForwardHandle or nil
	local script = handle and handle.GetScript and handle:GetScript("OnDragStop") or nil
	if script then script(handle) end
end

function CooldownPanels.LayoutSlotAnchorHandleOnReceiveDrag(self)
	local handle = self and self._eqolForwardHandle or nil
	local script = handle and handle.GetScript and handle:GetScript("OnReceiveDrag") or nil
	if script then script(handle) end
end

function CooldownPanels.LayoutSlotAnchorHandleOnMouseUp(self, btn)
	local handle = self and self._eqolForwardHandle or nil
	local script = handle and handle.GetScript and handle:GetScript("OnMouseUp") or nil
	if script then script(handle, btn) end
end

function CooldownPanels:ConfigureEditModePanelIcon(panelId, icon, entryId, slotColumn, slotRow)
	if not icon then return end
	local handle = icon.layoutHandle
	local slotAnchorHandle = icon.slotAnchorHandle
	entryId = normalizeId(entryId)
	slotColumn = Helper.NormalizeSlotCoordinate(slotColumn)
	slotRow = Helper.NormalizeSlotCoordinate(slotRow)
	icon._eqolLayoutEntryId = entryId
	icon._eqolLayoutSlotColumn = nil
	icon._eqolLayoutSlotRow = nil
	local active = self:IsPanelLayoutEditActive(panelId)
	CooldownPanels.SetIconTooltipMouseState(icon, icon._eqolTooltipEnabled == true and not active)
	icon:SetScript("OnDragStart", nil)
	icon:SetScript("OnDragStop", nil)
	icon:SetScript("OnReceiveDrag", nil)
	icon:SetScript("OnMouseUp", nil)
	if not handle then return end
	if not active then
		if handle._eqolLayoutConfigured ~= true then return end
		handle:Hide()
		handle:EnableMouse(false)
		if slotAnchorHandle then
			slotAnchorHandle:Hide()
			slotAnchorHandle:EnableMouse(false)
			slotAnchorHandle:SetScript("OnEnter", nil)
			slotAnchorHandle:SetScript("OnLeave", nil)
			slotAnchorHandle:SetScript("OnDragStart", nil)
			slotAnchorHandle:SetScript("OnDragStop", nil)
			slotAnchorHandle:SetScript("OnReceiveDrag", nil)
			slotAnchorHandle:SetScript("OnMouseUp", nil)
			slotAnchorHandle._eqolForwardHandle = nil
			slotAnchorHandle._eqolLayoutEntryId = nil
			slotAnchorHandle._eqolLayoutSlotColumn = nil
			slotAnchorHandle._eqolLayoutSlotRow = nil
		end
		handle:SetScript("OnEnter", nil)
		handle:SetScript("OnLeave", nil)
		handle:SetScript("OnDragStart", nil)
		handle:SetScript("OnDragStop", nil)
		handle:SetScript("OnReceiveDrag", nil)
		handle:SetScript("OnMouseUp", nil)
		handle._eqolLayoutEntryId = nil
		handle._eqolLayoutSlotColumn = nil
		handle._eqolLayoutSlotRow = nil
		handle._eqolLayoutConfigured = nil
		return
	end
	if handle._eqolLayoutConfigured == true then
		handle:Show()
		handle:EnableMouse(true)
		handle:RegisterForDrag("LeftButton")
		handle:ClearAllPoints()
		handle:SetAllPoints(icon)
		if slotAnchorHandle then
			slotAnchorHandle:Show()
			slotAnchorHandle:EnableMouse(true)
			slotAnchorHandle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			slotAnchorHandle:RegisterForDrag("LeftButton")
			slotAnchorHandle._eqolForwardHandle = handle
			slotAnchorHandle._eqolLayoutEntryId = entryId
			slotAnchorHandle._eqolLayoutSlotColumn = slotColumn
			slotAnchorHandle._eqolLayoutSlotRow = slotRow
		end
		handle._eqolLayoutEntryId = entryId
		handle._eqolLayoutSlotColumn = slotColumn
		handle._eqolLayoutSlotRow = slotRow
		return
	end
	handle:Show()
	handle:EnableMouse(true)
	handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	handle:RegisterForDrag("LeftButton")
	handle:ClearAllPoints()
	handle:SetAllPoints(icon)
	if slotAnchorHandle then
		slotAnchorHandle:Show()
		slotAnchorHandle:EnableMouse(true)
		slotAnchorHandle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		slotAnchorHandle:RegisterForDrag("LeftButton")
		slotAnchorHandle._eqolForwardHandle = handle
		slotAnchorHandle._eqolLayoutEntryId = entryId
		slotAnchorHandle._eqolLayoutSlotColumn = slotColumn
		slotAnchorHandle._eqolLayoutSlotRow = slotRow
	end
	handle._eqolLayoutEntryId = entryId
	handle._eqolLayoutSlotColumn = slotColumn
	handle._eqolLayoutSlotRow = slotRow
	handle._eqolLayoutConfigured = true
	handle:SetScript("OnEnter", function(self)
		local editor = getEditor()
		if editor and editor.draggingEntry then
			editor.dragPreviewSlot = {
				column = self._eqolLayoutSlotColumn,
				row = self._eqolLayoutSlotRow,
			}
			if icon.rangeOverlay then
				icon._eqolLayoutDragRangePreview = true
				icon.rangeOverlay:SetColorTexture(0.2, 0.7, 0.2, 0.28)
				icon.rangeOverlay:Show()
			end
			return
		end
		local runtimePanel = getRuntime(panelId)
		if runtimePanel and runtimePanel._eqolFixedGroupDrag then
			CooldownPanels:UpdateFixedGroupDragTarget(panelId, self._eqolLayoutSlotColumn, self._eqolLayoutSlotRow)
			return
		end
		CooldownPanels.ShowIconTooltip(icon)
	end)
	handle:SetScript("OnLeave", function(self)
		local editor = getEditor()
		local dragSlot = editor and editor.dragPreviewSlot or nil
		if type(dragSlot) == "table" and dragSlot.column == self._eqolLayoutSlotColumn and dragSlot.row == self._eqolLayoutSlotRow then editor.dragPreviewSlot = nil end
		if icon.rangeOverlay and icon._eqolLayoutDragRangePreview then
			icon._eqolLayoutDragRangePreview = nil
			icon.rangeOverlay:Hide()
		end
		icon:SetAlpha(1)
		CooldownPanels.HideIconTooltip(icon)
	end)
	handle:SetScript("OnDragStart", function(self)
		local currentEntryId = normalizeId(self._eqolLayoutEntryId)
		local currentColumn = Helper.NormalizeSlotCoordinate(self._eqolLayoutSlotColumn)
		local currentRow = Helper.NormalizeSlotCoordinate(self._eqolLayoutSlotRow)
		if IsShiftKeyDown and IsShiftKeyDown() then
			local currentPanel = CooldownPanels:GetPanel(panelId)
			local group = currentPanel and CooldownPanels.GetFixedGroupAtCell(currentPanel, currentColumn, currentRow) or nil
			if group then
				if CooldownPanels:StartFixedGroupMove(panelId, group.id, currentColumn, currentRow) then icon:SetAlpha(0.8) end
			else
				CooldownPanels:StartFixedGroupDraw(panelId, currentColumn, currentRow)
			end
			return
		end
		if not currentEntryId then return end
		local editor = getEditor()
		if not editor then return end
		if CooldownPanels:PreparePanelForFixedLayoutEdit(panelId) then
			CooldownPanels:RefreshPanel(panelId)
			CooldownPanels:RefreshEditor()
		end
		editor.dragEntryId = currentEntryId
		editor.dragTargetId = nil
		editor.dragPreviewSlot = nil
		editor.draggingEntry = true
		showEditorDragIcon(editor, icon.texture and icon.texture:GetTexture())
		icon:SetAlpha(0.6)
	end)
	handle:SetScript("OnDragStop", function()
		icon:SetAlpha(1)
		local runtimePanel = getRuntime(panelId)
		if runtimePanel and runtimePanel._eqolFixedGroupDrag then
			local targetSlot = CooldownPanels:GetLayoutEditCursorSlot(panelId)
			if targetSlot then CooldownPanels:UpdateFixedGroupDragTarget(panelId, targetSlot.column, targetSlot.row) end
			CooldownPanels:FinishFixedGroupDrag(panelId)
			return
		end
		local editor = getEditor()
		if not (editor and editor.draggingEntry) then return end
		editor.draggingEntry = nil
		hideEditorDragIcon(editor)
		local fromId = editor.dragEntryId
		local targetSlot = editor.dragPreviewSlot or CooldownPanels:GetLayoutEditCursorSlot(panelId)
		editor.dragEntryId = nil
		editor.dragTargetId = nil
		editor.dragPreviewSlot = nil
		if panelId and fromId and targetSlot and CooldownPanels:MoveEntryToFixedSlot(panelId, fromId, targetSlot) then CooldownPanels:RefreshPanel(panelId) end
		CooldownPanels:RefreshEditor()
	end)
	handle:SetScript("OnReceiveDrag", function(self)
		local currentColumn = Helper.NormalizeSlotCoordinate(self._eqolLayoutSlotColumn)
		local currentRow = Helper.NormalizeSlotCoordinate(self._eqolLayoutSlotRow)
		local editor = getEditor()
		if editor and editor.draggingEntry then return end
		if CooldownPanels:HandleCursorDrop(panelId, { column = currentColumn, row = currentRow }) then
			CooldownPanels:RefreshPanel(panelId)
			CooldownPanels:RefreshEditor()
		end
	end)
	handle:SetScript("OnMouseUp", function(self, btn)
		local currentEntryId = normalizeId(self._eqolLayoutEntryId)
		local currentColumn = Helper.NormalizeSlotCoordinate(self._eqolLayoutSlotColumn)
		local currentRow = Helper.NormalizeSlotCoordinate(self._eqolLayoutSlotRow)
		if btn == "RightButton" then
			local currentPanel = CooldownPanels:GetPanel(panelId)
			local group = currentPanel and CooldownPanels.GetFixedGroupAtCell(currentPanel, currentColumn, currentRow) or nil
			if group then
				if IsControlKeyDown and IsControlKeyDown() then
					CooldownPanels:ShowFixedGroupMenu(handle or icon, panelId, group.id)
				else
					CooldownPanels:OpenLayoutFixedGroupStandaloneMenu(panelId, group.id, handle or icon)
				end
				return
			end
			return
		end
		if btn ~= "LeftButton" then return end
		local editor = getEditor()
		if editor and editor.draggingEntry then return end
		local runtimePanel = getRuntime(panelId)
		if runtimePanel and runtimePanel._eqolFixedGroupDrag then return end
		if CooldownPanels:HandleCursorDrop(panelId, { column = currentColumn, row = currentRow }) then
			CooldownPanels:RefreshPanel(panelId)
			CooldownPanels:RefreshEditor()
			return
		end
		CooldownPanels:SelectPanel(panelId)
		local cursorCandidates = CooldownPanels:GetLayoutEntryCandidatesAtCursor(panelId)
		if cursorCandidates and #cursorCandidates > 1 and CooldownPanels:ShowLayoutEntryChooserMenu(handle or icon, panelId, cursorCandidates) then return end
		local selectedCandidate = cursorCandidates and cursorCandidates[1] or nil
		local targetEntryId = selectedCandidate and selectedCandidate.entryId or currentEntryId
		local targetAnchor = selectedCandidate and (selectedCandidate.anchorFrame or selectedCandidate.icon) or (handle or icon)
		if targetEntryId then
			CooldownPanels:SelectEntry(targetEntryId)
			CooldownPanels:OpenLayoutEntryStandaloneMenu(panelId, targetEntryId, targetAnchor)
		else
			CooldownPanels:HideLayoutEntryStandaloneMenu(panelId)
			CooldownPanels:RefreshEditor()
		end
	end)
	if slotAnchorHandle then
		slotAnchorHandle:SetScript("OnEnter", CooldownPanels.LayoutSlotAnchorHandleOnEnter)
		slotAnchorHandle:SetScript("OnLeave", CooldownPanels.LayoutSlotAnchorHandleOnLeave)
		slotAnchorHandle:SetScript("OnDragStart", CooldownPanels.LayoutSlotAnchorHandleOnDragStart)
		slotAnchorHandle:SetScript("OnDragStop", CooldownPanels.LayoutSlotAnchorHandleOnDragStop)
		slotAnchorHandle:SetScript("OnReceiveDrag", CooldownPanels.LayoutSlotAnchorHandleOnReceiveDrag)
		slotAnchorHandle:SetScript("OnMouseUp", CooldownPanels.LayoutSlotAnchorHandleOnMouseUp)
	end
end

function CooldownPanels:UpdatePreviewIcons(panelId, countOverride)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	local fixedLayout = Helper.IsFixedLayout(layout)
	local layoutEditActive = self:IsPanelLayoutEditActive(panelId)
	local showTooltips = layout.showTooltips == true
	local showKeybinds = layout.keybindsEnabled == true
	local showIconTexture = layout.showIconTexture ~= false
	local staticFontPath, staticFontSize, staticFontStyle = Helper.GetCountFontDefaults(frame)
	local defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle = staticFontPath, staticFontSize, staticFontStyle
	local defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle = Helper.GetChargesFontDefaults(frame)
	local previewEntryIds
	local count = countOverride
	local previewGridColumns
	if fixedLayout then
		previewEntryIds, count, previewGridColumns = Helper.BuildFixedSlotEntryIds(panel, nil, false)
	end
	if not count then
		previewEntryIds = previewEntryIds or (getPreviewEntryIds and getPreviewEntryIds(panel) or nil)
		count = getPreviewCount(panel)
	end
	local editGridColumns
	if layoutEditActive and not fixedLayout then
		editGridColumns = Helper.ClampInt(layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
		if editGridColumns <= 0 then editGridColumns = math.min(math.max(type(panel.order) == "table" and #panel.order or 0, 4), 12) end
	end
	ensureIconCount(frame, count)
	local effectiveLayoutCache = {}

	for i = 1, count do
		local entryId
		if fixedLayout then
			entryId = previewEntryIds and previewEntryIds[i] or nil
		else
			entryId = (previewEntryIds and previewEntryIds[i]) or (panel.order and panel.order[i])
		end
		local entry = entryId and panel.entries and panel.entries[entryId] or nil
		local entryLayout = entry and CooldownPanels:GetEntryEffectiveLayout(panelId, entry, effectiveLayoutCache, panel) or layout
		local macro = entry and entry.type == "MACRO" and CooldownPanels.ResolveMacroEntry(entry) or nil
		local resolvedType = entry and ((macro and macro.kind) or entry.type) or nil
		local previewBaseItemId = resolvedType == "ITEM" and ((macro and macro.itemID) or entry.itemID) or nil
		local previewItemId = resolvedType == "ITEM" and CooldownPanels.ResolveEntryItemID(entry, previewBaseItemId) or nil
		local icon = frame.icons[i]
		local showCooldown = entry and entry.showCooldown ~= false
		local staticCooldown = entry and entry.staticTextShowOnCooldown == true or false
		local showCooldownText = entry and entry.showCooldownText ~= false
		local showCharges = entry and resolvedType == "SPELL" and entry.showCharges == true
		local showStacks = entry and (resolvedType == "SPELL" or resolvedType == "CDM_AURA") and entry.showStacks == true
		local showItemCount = entry and resolvedType == "ITEM" and entry.showItemCount ~= false
		local showItemUses = entry and resolvedType == "ITEM" and entry.showItemUses == true
		local showEntryIconTexture = entry and CooldownPanels:ResolveEntryShowIconTexture(entryLayout, entry) or showIconTexture
		local showGhostIcon = entry and CooldownPanels:ShouldShowEditorGhostIcon(entryLayout, entry, showEntryIconTexture, true) or false
		local stateTextureType, stateTextureValue, stateTextureWidth, stateTextureHeight, stateTextureScale, stateTextureAngle, stateTextureDouble, stateTextureMirror, stateTextureMirrorSecond, stateTextureSpacingX, stateTextureSpacingY
		if entry then
			stateTextureType, stateTextureValue, stateTextureWidth, stateTextureHeight, stateTextureScale, stateTextureAngle, stateTextureDouble, stateTextureMirror, stateTextureMirrorSecond, stateTextureSpacingX, stateTextureSpacingY =
				CooldownPanels:ResolveEntryStateTexture(entry)
		end
		local slotColumn = previewGridColumns and (((i - 1) % previewGridColumns) + 1) or (editGridColumns and (((i - 1) % editGridColumns) + 1) or i)
		local slotRow = previewGridColumns and (math.floor((i - 1) / previewGridColumns) + 1) or (editGridColumns and (math.floor((i - 1) / editGridColumns) + 1) or 1)
		icon:Show()
		icon._eqolPreviewCellColumn = slotColumn
		icon._eqolPreviewCellRow = slotRow
		CooldownPanels:ApplyEntryIconVisualLayout(icon, entryLayout, entry)
		CooldownPanels:HideEditorGhostIcon(icon)
		icon.texture:SetTexture(entry and getEntryIcon(entry) or Helper.PREVIEW_ICON)
		icon.texture:SetVertexColor(1, 1, 1)
		icon.texture:SetShown(showEntryIconTexture or not entry)
		if icon.cooldown.SetReverse then icon.cooldown:SetReverse(resolvedType == "CDM_AURA") end
		if icon.cooldown.SetUseAuraDisplayTime then icon.cooldown:SetUseAuraDisplayTime(resolvedType == "CDM_AURA") end
		icon.cooldown:SetHideCountdownNumbers(not showCooldownText)
		CooldownPanels:ApplyEntryCooldownTextStyle(icon, entryLayout, entry)
		CooldownPanels:ApplyEntryStackTextStyle(icon, entryLayout, entry, defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
		CooldownPanels:ApplyEntryChargesTextStyle(icon, entryLayout, entry, defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
		icon.cooldown:Clear()
		if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
		icon.count:Hide()
		icon.charges:SetAlpha(1)
		icon.charges:Hide()
		if icon.rangeOverlay then icon.rangeOverlay:Hide() end
		if icon.keybind then icon.keybind:Hide() end
		if icon.stateTexture then
			applyStateTexture(icon, {
				stateTextureShown = entry ~= nil and stateTextureType ~= nil,
				stateTextureType = stateTextureType,
				stateTextureValue = stateTextureValue,
				stateTextureWidth = stateTextureWidth,
				stateTextureHeight = stateTextureHeight,
				stateTextureScale = stateTextureScale,
				stateTextureAngle = stateTextureAngle,
				stateTextureDouble = stateTextureDouble,
				stateTextureMirror = stateTextureMirror,
				stateTextureMirrorSecond = stateTextureMirrorSecond,
				stateTextureSpacingX = stateTextureSpacingX,
				stateTextureSpacingY = stateTextureSpacingY,
			})
		end
		CooldownPanels.HidePreviewGlowBorder(icon)
		if icon.previewBling then icon.previewBling:Hide() end
		CooldownPanels.StopAllIconGlows(icon)
		setAssistedHighlight(icon, false)
		if not entry then
			if icon.staticText then icon.staticText:Hide() end
			icon.texture:SetDesaturated(false)
			icon.texture:SetAlpha(0)
			icon.texture:SetShown(false)
			CooldownPanels:HideEditorGhostIcon(icon)
			CooldownPanels.ApplyIconTooltip(icon, nil, false)
		else
			applyStaticText(icon, entryLayout, entry, staticFontPath, staticFontSize, staticFontStyle, staticCooldown)
			icon.texture:SetShown(showEntryIconTexture)
			icon.texture:SetDesaturated(false)
			icon.texture:SetAlpha(1)
			if showGhostIcon then CooldownPanels:ApplyEditorGhostIcon(icon) end
			if showItemUses and previewItemId then
				local usesValue = Api.GetItemCount(previewItemId, false, true)
				if isSafeGreaterThan(usesValue, 0) then
					icon.charges:SetText(usesValue)
					icon.charges:SetAlpha(1)
					icon.charges:Show()
				end
			end
			if showItemCount and previewItemId then
				local countValue = Api.GetItemCount(previewItemId, false, false)
				if isSafeGreaterThan(countValue, 0) then
					icon.count:SetText(countValue)
					icon.count:Show()
				end
			end
			if entryLayout.keybindsEnabled == true and entry and icon.keybind then
				local keyText = Keybinds.GetEntryKeybindText(entry, entryLayout)
				if keyText then
					icon.keybind:SetText(keyText)
					icon.keybind:Show()
				else
					icon.keybind:Hide()
				end
			end
			CooldownPanels.ApplyIconTooltip(icon, entry, showTooltips)
		end
		self:ConfigureEditModePanelIcon(panelId, icon, entryId, slotColumn, slotRow)
	end
	for i = count + 1, #(frame.icons or {}) do
		local icon = frame.icons[i]
		if icon then
			icon:Hide()
			CooldownPanels:HideEditorGhostIcon(icon)
			if icon.stateTexture then icon.stateTexture:Hide() end
			if icon.stateTextureSecond then icon.stateTextureSecond:Hide() end
			setAssistedHighlight(icon, false)
		end
	end
	self:UpdateLayoutEditGrid(panelId, fixedLayout and count or 0)
end

local function isSpellFlagged(map, baseId, effectiveId)
	if not map then return false end
	return (effectiveId and map[effectiveId]) or (baseId and map[baseId]) or false
end

CooldownPanels.SetIconDesaturatedRuntime = function(texture, enabled, skipDesaturation)
	if skipDesaturation then
		texture:SetDesaturated(false)
	else
		texture:SetDesaturated(enabled == true)
	end
end

CooldownPanels.SetIconDesaturationRuntime = function(texture, value, skipDesaturation)
	if skipDesaturation then
		texture:SetDesaturation(0)
	else
		texture:SetDesaturation(value or 0)
	end
end

CooldownPanels.IsAssistedSuggestedSpell = function(assistedSuggestedSpellId, assistedSuggestedBaseId, assistedSuggestedEffectiveId, baseSpellId, effectiveSpellId)
	if not (assistedSuggestedSpellId and baseSpellId) then return false end
	if baseSpellId == assistedSuggestedSpellId or baseSpellId == assistedSuggestedBaseId or baseSpellId == assistedSuggestedEffectiveId then return true end
	if effectiveSpellId and (effectiveSpellId == assistedSuggestedSpellId or effectiveSpellId == assistedSuggestedBaseId or effectiveSpellId == assistedSuggestedEffectiveId) then return true end
	return false
end

local function updateItemCountCache(usesOnly)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.itemCountCache = runtime.itemCountCache or {}
	local cache = runtime.itemCountCache
	local trackedIds = usesOnly == true and runtime.itemUsesTrackedIds or runtime.itemTrackedIds
	local trackedUsesIds = runtime.itemUsesTrackedIds
	if not trackedIds or not next(trackedIds) then
		if usesOnly == true then return false end
		for id in pairs(cache) do
			cache[id] = nil
		end
		return false
	end
	for id in pairs(cache) do
		if not trackedIds[id] then cache[id] = nil end
	end
	for id in pairs(trackedIds) do
		local slot = cache[id] or {}
		if usesOnly ~= true then slot.count = Api.GetItemCount(id, false, false) or 0 end
		if trackedUsesIds and trackedUsesIds[id] then
			slot.uses = Api.GetItemCount(id, false, true) or 0
		elseif usesOnly ~= true then
			slot.uses = nil
		end
		cache[id] = slot
	end
	return true
end

updateItemCountCacheForItem = function(itemID, includeUses)
	if not itemID then return end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.itemCountCache = runtime.itemCountCache or {}
	local slot = runtime.itemCountCache[itemID] or {}
	slot.count = Api.GetItemCount(itemID, false, false) or 0
	if includeUses == nil then includeUses = runtime.itemUsesTrackedIds and runtime.itemUsesTrackedIds[itemID] end
	if includeUses then
		slot.uses = Api.GetItemCount(itemID, false, true) or 0
	else
		slot.uses = nil
	end
	runtime.itemCountCache[itemID] = slot
end

function CooldownPanels:HandleEntryBooleanMutation(panelId, entryId, entry, field)
	if not (panelId and entry and field) then return end
	if field == "glowReady" then CooldownPanels.ClearReadyGlowEntryState(panelId, entryId, true) end
	if field == "glowReady" or field == "checkPower" or field == "hideWhenNoResource" or field == "readyGlowCheckPower" then
		self:RebuildPowerIndex()
	end
	if field == "showCharges" then self:RebuildChargesIndex() end
	if field == "showItemUses" or field == "useHighestRank" then
		self:RebuildSpellIndex()
		updateItemCountCache()
		if entry.type == "ITEM" then
			local resolvedItemId = CooldownPanels.ResolveEntryItemID(entry, entry.itemID)
			if resolvedItemId then updateItemCountCacheForItem(resolvedItemId, entry.showItemUses == true) end
		elseif entry.type == "MACRO" then
			local macro = CooldownPanels.ResolveMacroEntry(entry)
			if macro and macro.kind == "ITEM" and macro.itemID then updateItemCountCacheForItem(macro.itemID, entry.showItemUses == true) end
		end
	end
end

function CooldownPanels:UpdateRuntimeIcons(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	local layoutEditActive = self:IsPanelLayoutEditActive(panelId)
	local shared = CooldownPanels.runtime
	local enabledPanels = shared and shared.enabledPanels
	local eligible = layoutEditActive or enabledPanels and enabledPanels[panelId] or (not enabledPanels and panel.enabled ~= false and panelAllowsSpec(panel))
	if not eligible then
		if runtime._eqolHiddenByEligibility then return end
		runtime._eqolHiddenByEligibility = true
		runtime.visibleCount = 0
		runtime.visiblePowerSpellCount = 0
		if runtime.visibleEntries then
			for i = 1, #runtime.visibleEntries do
				runtime.visibleEntries[i] = nil
			end
		end
		if runtime.visiblePowerSpells then
			for i = 1, #runtime.visiblePowerSpells do
				runtime.visiblePowerSpells[i] = nil
			end
		end
		if frame.icons then
			for i = 1, #frame.icons do
				CooldownPanels:HideEditorGhostIcon(frame.icons[i])
				if frame.icons[i].stateTexture then frame.icons[i].stateTexture:Hide() end
				if frame.icons[i].stateTextureSecond then frame.icons[i].stateTextureSecond:Hide() end
				setAssistedHighlight(frame.icons[i], false)
			end
		end
		ensureIconCount(frame, 0)
		return
	end
	runtime._eqolHiddenByEligibility = nil
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	local fixedLayout = Helper.IsFixedLayout(layout)
	local resolvedLayout = CooldownPanels.ResolveRuntimeLayout(runtime, frame, layout)
	local showTooltips = resolvedLayout and resolvedLayout.showTooltips
	local showKeybinds = resolvedLayout and resolvedLayout.showKeybinds
	local staticFontPath = resolvedLayout and resolvedLayout.staticFontPath
	local staticFontSize = resolvedLayout and resolvedLayout.staticFontSize
	local staticFontStyle = resolvedLayout and resolvedLayout.staticFontStyle
	local defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle = Helper.GetCountFontDefaults(frame)
	local defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle = Helper.GetChargesFontDefaults(frame)
	local powerTintR = resolvedLayout and resolvedLayout.powerTintR
	local powerTintG = resolvedLayout and resolvedLayout.powerTintG
	local powerTintB = resolvedLayout and resolvedLayout.powerTintB
	local unusableTintR = resolvedLayout and resolvedLayout.unusableTintR
	local unusableTintG = resolvedLayout and resolvedLayout.unusableTintG
	local unusableTintB = resolvedLayout and resolvedLayout.unusableTintB
	local rangeOverlayEnabled = resolvedLayout and resolvedLayout.rangeOverlayEnabled
	local rangeOverlayR = resolvedLayout and resolvedLayout.rangeOverlayR
	local rangeOverlayG = resolvedLayout and resolvedLayout.rangeOverlayG
	local rangeOverlayB = resolvedLayout and resolvedLayout.rangeOverlayB
	local rangeOverlayA = resolvedLayout and resolvedLayout.rangeOverlayA
	local drawEdge = resolvedLayout and resolvedLayout.drawEdge
	local drawBling = resolvedLayout and resolvedLayout.drawBling
	local drawSwipe = resolvedLayout and resolvedLayout.drawSwipe
	local gcdDrawEdge = resolvedLayout and resolvedLayout.gcdDrawEdge
	local gcdDrawBling = resolvedLayout and resolvedLayout.gcdDrawBling
	local gcdDrawSwipe = resolvedLayout and resolvedLayout.gcdDrawSwipe
	local assistedHighlightEnabled = shared and shared.assistedHighlightEnabled
	if assistedHighlightEnabled == nil then
		if CooldownPanels.refreshAssistedHighlightCVarState then CooldownPanels.refreshAssistedHighlightCVarState(nil, true) end
		assistedHighlightEnabled = shared and shared.assistedHighlightEnabled == true
	end
	local assistedSuggestedSpellId = assistedHighlightEnabled and Api.GetAssistedCombatNextSpell and tonumber(Api.GetAssistedCombatNextSpell()) or nil
	local assistedSuggestedBaseId = assistedSuggestedSpellId and getBaseSpellId(assistedSuggestedSpellId) or nil
	local assistedSuggestedEffectiveId = assistedSuggestedSpellId and getEffectiveSpellId(assistedSuggestedSpellId) or nil

	local visible = runtime.visibleEntries
	if not visible then
		visible = {}
		runtime.visibleEntries = visible
	end
	local lastLayoutEditActive = runtime._eqolLastLayoutEditActive == true
	self:EnsureSpellQueryPass()
	local visibleCount = 0
	local previousOccupiedSlots = fixedLayout and runtime._eqolOccupiedSlots or nil
	local previousOccupiedSlotIndices = fixedLayout and runtime._eqolOccupiedSlotIndices or nil
	local visibleSlotsUsed = fixedLayout and (runtime._eqolScratchOccupiedSlots or {}) or nil
	if visibleSlotsUsed then
		for slotIndex in pairs(visibleSlotsUsed) do
			visibleSlotsUsed[slotIndex] = nil
		end
	end
	local visibleSlotIndices = fixedLayout and (runtime._eqolScratchOccupiedSlotIndices or {}) or nil
	local visibleSlotCount = 0
	local order = panel.order or {}
	local fixedSlotCount = 0
	local fixedGridColumns = 0
	local fixedLayoutCache = fixedLayout and Helper.GetFixedLayoutCache and Helper.GetFixedLayoutCache(panel) or nil
	local fixedGroups = fixedLayout and (fixedLayoutCache and fixedLayoutCache.groups or CooldownPanels.GetFixedGroups(panel)) or nil
	local fixedGroupById = fixedLayout and (fixedLayoutCache and fixedLayoutCache.groupById or {}) or nil
	local fixedStaticTargetIndices = fixedLayout and fixedLayoutCache and fixedLayoutCache.staticTargetIndexByEntryId or nil
	local fixedGroupVisibleCounts = fixedLayout and {} or nil
	local effectiveLayoutCache = {}
	if fixedLayout then
		if fixedLayoutCache then
			fixedSlotCount = fixedLayoutCache.slotCount or 0
			fixedGridColumns = fixedLayoutCache.boundsColumns or 0
		else
			_, fixedSlotCount, fixedGridColumns = Helper.BuildFixedSlotEntryIds(panel, nil, false)
		end
		if fixedGroups and fixedGroupById and not fixedLayoutCache then
			for i = 1, #fixedGroups do
				local fixedGroup = fixedGroups[i]
				if fixedGroup then fixedGroupById[fixedGroup.id] = fixedGroup end
			end
		end
		if fixedGroups then
			for i = 1, #fixedGroups do
				local fixedGroup = fixedGroups[i]
				if fixedGroup then
					if fixedGroup.layoutOverrides then
						effectiveLayoutCache[fixedGroup.id] = self:GetFixedGroupEffectiveLayout(panelId, fixedGroup.id, effectiveLayoutCache) or layout
					else
						effectiveLayoutCache[fixedGroup.id] = layout
					end
				end
			end
		end
	end
	local editGridColumns
	if layoutEditActive and not fixedLayout then
		editGridColumns = Helper.ClampInt(layout.wrapCount, 0, 40, Helper.PANEL_LAYOUT_DEFAULTS.wrapCount or 0)
		if editGridColumns <= 0 then editGridColumns = math.min(math.max(type(panel.order) == "table" and #panel.order or 0, 4), 12) end
	end
	local layoutEditGridCount = layoutEditActive and fixedLayout and fixedSlotCount or 0
	if runtime._eqolLayoutEditGridDirty == true or runtime._eqolLayoutEditGridCount ~= layoutEditGridCount or runtime._eqolLayoutEditGridActive ~= (layoutEditActive == true) then
		self:UpdateLayoutEditGrid(panelId, layoutEditGridCount)
		runtime._eqolLayoutEditGridCount = layoutEditGridCount
		runtime._eqolLayoutEditGridActive = layoutEditActive == true
		runtime._eqolLayoutEditGridDirty = nil
	end
	runtime.readyAt = runtime.readyAt or {}
	runtime.glowTimers = runtime.glowTimers or {}
	local readyGlowPrimed = CooldownPanels.GetReadyGlowPrimedState(runtime)
	local overlayGlowSpells = shared and shared.overlayGlowSpells
	local powerInsufficientSpells = shared and shared.powerInsufficient
	local spellUnusableSpells = shared and shared.spellUnusable
	local rangeOverlaySpells = shared and shared.rangeOverlaySpells
	local powerCheckSpells = shared and shared.powerCheckSpells or nil
	local cdmAuras = CooldownPanels.CDMAuras
	local playerInCombat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
	for _, entryId in ipairs(order) do
		local entry = panel.entries and panel.entries[entryId]
		if entry then
			local entryLayout = layout
			if fixedLayout then
				local groupId = entry.fixedGroupId
				if groupId and fixedGroupById and fixedGroupById[groupId] then entryLayout = effectiveLayoutCache[groupId] or layout end
			else
				entryLayout = self:GetEntryEffectiveLayout(panelId, entry, effectiveLayoutCache, panel) or layout
			end
			local macro = entry.type == "MACRO" and CooldownPanels.ResolveMacroEntry(entry) or nil
			local resolvedType = (macro and macro.kind) or entry.type
			local resolvedBaseItemId = resolvedType == "ITEM" and ((macro and macro.itemID) or entry.itemID) or nil
			local resolvedItemId = resolvedType == "ITEM" and CooldownPanels.ResolveEntryItemID(entry, resolvedBaseItemId) or nil
			local resolvedSlotId = resolvedType == "SLOT" and entry.slotID or nil
			local showCooldown = entry.showCooldown ~= false
			local showCooldownText = entry.showCooldownText ~= false
			local staticTextShowOnCooldown = entry.staticTextShowOnCooldown == true
			local trackCooldown = showCooldown or staticTextShowOnCooldown
			local showCharges = entry.showCharges == true and resolvedType == "SPELL"
			local showStacks = entry.showStacks == true and (resolvedType == "SPELL" or resolvedType == "CDM_AURA")
			local showItemCount = resolvedType == "ITEM" and entry.showItemCount ~= false
			local showItemUses = resolvedType == "ITEM" and entry.showItemUses == true
			local showWhenEmpty = resolvedType == "ITEM" and entry.showWhenEmpty == true
			local showWhenNoCooldown = resolvedType == "SLOT" and entry.showWhenNoCooldown == true
			local showWhenMissing = resolvedType == "STANCE" and entry.showWhenMissing == true
			local alwaysShow = entry.alwaysShow ~= false
			local cdmAuraAlwaysShowMode = resolvedType == "CDM_AURA" and CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(entryLayout, entry) or nil
			local entryHideOnCooldown, entryShowOnCooldown = self:ResolveEntryCooldownVisibility(entryLayout, entry)
			if layoutEditActive or resolvedType == "CDM_AURA" then
				entryHideOnCooldown = false
				entryShowOnCooldown = false
			end
			local showEntryIconTexture = self:ResolveEntryShowIconTexture(entryLayout, entry)
			local showGhostIcon = self:ShouldShowEditorGhostIcon(entryLayout, entry, showEntryIconTexture, layoutEditActive)
			local entryNoDesaturation = self:ResolveEntryNoDesaturation(entryLayout, entry)
			local entryShowChargesCooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe, entryGcdDrawEdge, entryGcdDrawBling, entryGcdDrawSwipe = self:ResolveEntryCooldownVisuals(entryLayout, entry)
			local cdmAuraActiveGlow = entry.type == "CDM_AURA" and entry.glowReady == true
			local cdmAuraPandemicGlow = entry.type == "CDM_AURA" and entry.pandemicGlow == true
			local glowReady = entry.type ~= "MACRO" and entry.type ~= "CDM_AURA" and entry.glowReady ~= false
			local glowDuration, glowColor, glowStyle, glowInset = CooldownPanels:ResolveEntryGlowStyle(entryLayout, entry)
			local procGlowStyle, procGlowInset = CooldownPanels:ResolveEntryProcGlowVisual(entryLayout, entry)
			local stateTextureType, stateTextureValue, stateTextureWidth, stateTextureHeight, stateTextureScale, stateTextureAngle, stateTextureDouble, stateTextureMirror, stateTextureMirrorSecond, stateTextureSpacingX, stateTextureSpacingY =
				CooldownPanels:ResolveEntryStateTexture(entry)
			local pandemicGlowColor, pandemicGlowStyle, pandemicGlowInset = glowColor, glowStyle, glowInset
			if resolvedType == "CDM_AURA" then
				pandemicGlowColor, pandemicGlowStyle, pandemicGlowInset = CooldownPanels:ResolveEntryPandemicGlowVisual(entryLayout, entry)
			end
			local soundReady = false
			local soundName = normalizeSoundName(nil)
			local previewSound = false
			do
				local _, soundEnabledField, soundField = self:GetEntrySoundConfig(entry)
				if soundEnabledField and soundField then
					previewSound = entry[soundEnabledField] == true
					soundName = normalizeSoundName(entry[soundField])
					soundReady = resolvedType ~= "CDM_AURA" and previewSound
				end
			end
			local baseSpellId = resolvedType == "SPELL" and ((macro and macro.spellID) or entry.spellID) or nil
			local effectiveSpellId = baseSpellId and getEffectiveSpellId(baseSpellId) or nil
			local stanceRelevant = resolvedType == "STANCE" and CooldownPanels.IsStanceEntryRelevant and CooldownPanels:IsStanceEntryRelevant(entry) or false
			local stanceActive = stanceRelevant and CooldownPanels.IsStanceEntryActive and CooldownPanels:IsStanceEntryActive(entry) or false
			local spellPassive = baseSpellId and isSpellPassiveSafe(baseSpellId, effectiveSpellId) or false
			local cdmAuraData
			-- local function isSpellFlagged(map)
			-- 	if not map then return false end
			-- 	if effectiveSpellId and map[effectiveSpellId] == true then return true end
			-- 	if baseSpellId and map[baseSpellId] == true then return true end
			-- 	return false
			-- end

			local entryCheckPower = resolvedType == "SPELL" and self:ResolveEntryCheckPower(entryLayout, entry)
			local hideWhenNoResource = self:ResolveEntryHideWhenNoResource(entryLayout, entry)
			local readyGlowCheckPower = resolvedType == "SPELL" and glowReady and self:ResolveEntryReadyGlowCheckPower(entryLayout, entry)
			local procGlowEnabled = resolvedType == "SPELL" and CooldownPanels:ResolveEntryProcGlowEnabled(entryLayout, entry)
			local procActive = resolvedType == "SPELL" and isSpellFlagged(overlayGlowSpells, baseSpellId, effectiveSpellId)
			local overlayGlow = procActive and procGlowEnabled
			local resourceInsufficient = resolvedType == "SPELL" and isSpellFlagged(powerInsufficientSpells, baseSpellId, effectiveSpellId)
			local readyGlowResourceBlocked = resolvedType == "SPELL" and readyGlowCheckPower and resourceInsufficient
			local powerInsufficient = resolvedType == "SPELL" and entryCheckPower and resourceInsufficient
			local spellUnusable = resolvedType == "SPELL" and entryCheckPower and isSpellFlagged(spellUnusableSpells, baseSpellId, effectiveSpellId)
			local rangeOverlay = rangeOverlayEnabled and resolvedType == "SPELL" and isSpellFlagged(rangeOverlaySpells, baseSpellId, effectiveSpellId)
			local assistedSuggested = resolvedType == "SPELL"
				and CooldownPanels.IsAssistedSuggestedSpell(assistedSuggestedSpellId, assistedSuggestedBaseId, assistedSuggestedEffectiveId, baseSpellId, effectiveSpellId)
			if rangeOverlay and Api.IsSpellUsableFn then
				local checkId = effectiveSpellId or baseSpellId
				if checkId then
					local isUsable = Api.IsSpellUsableFn(checkId)
					if not isUsable then rangeOverlay = false end
				end
			end

			local iconTexture = getEntryIcon(entry)
			local stackCount
			local itemCount
			local itemUses
			local chargesInfo
			local chargesInfoActive = false
			local chargeDurationObject
			local cooldownDurationObject
			local cooldownStart, cooldownDuration, cooldownEnabled, cooldownRate, cooldownGCD, cooldownIsActive
			local show = false
			local cooldownEnabledOk = true
			local emptyItem = false
			local canTriggerReadyGlow = false
			local spellReadyCondition

			if resolvedType == "SPELL" and baseSpellId then
				local spellId = effectiveSpellId or baseSpellId
				local spellPassState = self:GetSpellPassState(spellId)
				if spellPassive then
					show = false
				elseif Api.IsSpellKnown and not Api.IsSpellKnown(spellId) then
					show = false
				else
					canTriggerReadyGlow = true
					if showCharges then
						if spellPassState and spellPassState.chargesLoaded == nil then
							spellPassState.chargesInfo = self:GetCachedSpellChargesInfo(spellId)
							spellPassState.chargesLoaded = true
						end
						chargesInfo = spellPassState and spellPassState.chargesInfo or self:GetCachedSpellChargesInfo(spellId)
						chargesInfoActive = CooldownPanels.IsChargeInfoActive(chargesInfo)
						if showCooldown and entryShowChargesCooldown and chargesInfoActive then
							if spellPassState and spellPassState.chargeDurationLoaded == nil then
								spellPassState.chargeDurationObject = self:GetCachedSpellChargeDurationObject(spellId)
								spellPassState.chargeDurationLoaded = true
							end
							chargeDurationObject = spellPassState and spellPassState.chargeDurationObject or self:GetCachedSpellChargeDurationObject(spellId)
						end
					end
					if trackCooldown or (showCooldown and chargesInfoActive) then
						if spellPassState and spellPassState.infoLoaded == nil then
							spellPassState.cooldownStart, spellPassState.cooldownDuration, spellPassState.cooldownEnabled, spellPassState.cooldownRate, spellPassState.cooldownGCD, spellPassState.cooldownIsActive =
								self:GetCachedSpellCooldownInfo(spellId)
							spellPassState.infoLoaded = true
						end
						if spellPassState then
							cooldownStart = spellPassState.cooldownStart
							cooldownDuration = spellPassState.cooldownDuration
							cooldownEnabled = spellPassState.cooldownEnabled
							cooldownRate = spellPassState.cooldownRate
							cooldownGCD = spellPassState.cooldownGCD
							cooldownIsActive = spellPassState.cooldownIsActive
						else
							cooldownStart, cooldownDuration, cooldownEnabled, cooldownRate, cooldownGCD, cooldownIsActive = self:GetCachedSpellCooldownInfo(spellId)
						end
					end
					cooldownIsActive = CooldownPanels.IsSpellCooldownInfoActive(cooldownIsActive, cooldownEnabled, cooldownStart, cooldownDuration)
					if trackCooldown and cooldownIsActive then
						if spellPassState and spellPassState.durationLoaded == nil then
							spellPassState.cooldownDurationObject = self:GetCachedSpellCooldownDurationObject(spellId)
							spellPassState.durationLoaded = true
						end
						cooldownDurationObject = spellPassState and spellPassState.cooldownDurationObject or self:GetCachedSpellCooldownDurationObject(spellId)
					end
					if glowReady and showCooldown then
						if cooldownGCD then
							spellReadyCondition = true
						elseif type(cooldownIsActive) == "boolean" then
							spellReadyCondition = not cooldownIsActive
						end
					end
					if showStacks then
						local entryKey = Helper.GetEntryKey(panelId, entryId)
						local displayCount = Helper.GetActionDisplayCountForSpell and Helper.GetActionDisplayCountForSpell(spellId) or nil
						if displayCount == nil and baseSpellId and baseSpellId ~= spellId and Helper.GetActionDisplayCountForSpell then
							displayCount = Helper.GetActionDisplayCountForSpell(baseSpellId)
						end
						stackCount = displayCount
						shared = shared or CooldownPanels.runtime
						if shared then
							shared.actionDisplayCounts = shared.actionDisplayCounts or {}
							shared.actionDisplayCounts[entryKey] = displayCount
						end
					end
					cooldownEnabledOk = isSafeNotFalse(cooldownEnabled)
						local durationActive = cooldownDurationObject ~= nil and cooldownIsActive
						show = alwaysShow
						if not show and showCooldown and (durationActive or cooldownIsActive) then show = true end
						if not show and showCharges and chargesInfoActive then show = true end
						if not show and showStacks and Helper.HasDisplayCount(stackCount) then show = true end
					end
			elseif resolvedType == "ITEM" and resolvedItemId then
				local itemCache = shared and shared.itemCountCache
				local cached = itemCache and itemCache[resolvedItemId]
				if not cached then
					updateItemCountCacheForItem(resolvedItemId, showItemUses)
					itemCache = shared and shared.itemCountCache
					cached = itemCache and itemCache[resolvedItemId]
				end
				local cachedCount = cached and cached.count
				local cachedUses = cached and cached.uses
				local ownsItem
				if cachedCount ~= nil then
					ownsItem = cachedCount > 0 or (Api.IsEquippedItem and Api.IsEquippedItem(resolvedItemId))
				else
					ownsItem = hasItem(resolvedItemId)
				end
				emptyItem = showWhenEmpty and not ownsItem
				if (ownsItem or showWhenEmpty) and itemHasUseSpell(resolvedItemId) then
					canTriggerReadyGlow = ownsItem == true
					if trackCooldown and ownsItem then
						cooldownStart, cooldownDuration, cooldownEnabled = getItemCooldownInfo(resolvedItemId)
						if CooldownPanels:IsItemCooldownOnGCD(resolvedItemId, cooldownStart, cooldownDuration) then
							cooldownStart, cooldownDuration, cooldownEnabled = 0, 0, true
							cooldownGCD = true
						end
					end
					if showItemCount then
						local count = cachedCount
						if count == nil then
							updateItemCountCacheForItem(resolvedItemId, showItemUses)
							itemCache = shared and shared.itemCountCache
							cached = itemCache and itemCache[resolvedItemId]
							count = cached and cached.count or 0
							cachedUses = cached and cached.uses
						end
						if isSafeGreaterThan(count, 0) then
							itemCount = count
						elseif showWhenEmpty then
							itemCount = 0
						end
					end
					if showItemUses then
						local uses = cachedUses
						if uses == nil then
							updateItemCountCacheForItem(resolvedItemId, true)
							itemCache = shared and shared.itemCountCache
							cached = itemCache and itemCache[resolvedItemId]
							uses = cached and cached.uses or 0
						end
						if isSafeGreaterThan(uses, 0) then
							itemUses = uses
						elseif showWhenEmpty then
							itemUses = 0
						end
					end
					cooldownEnabledOk = cooldownEnabled ~= false and cooldownEnabled ~= 0
					show = alwaysShow or showWhenEmpty
					if not show and showCooldown and cooldownEnabledOk and isCooldownActive(cooldownStart, cooldownDuration) then show = true end
				end
			elseif resolvedType == "SLOT" and resolvedSlotId then
				local itemId = Api.GetInventoryItemID and Api.GetInventoryItemID("player", resolvedSlotId) or nil
				if itemId then
					iconTexture = Api.GetItemIconByID and Api.GetItemIconByID(itemId) or iconTexture
					if itemHasUseSpell(itemId) then
						canTriggerReadyGlow = true
						if trackCooldown then
							cooldownStart, cooldownDuration, cooldownEnabled = getItemCooldownInfo(itemId, resolvedSlotId)
							if CooldownPanels:IsItemCooldownOnGCD(itemId, cooldownStart, cooldownDuration) then
								cooldownStart, cooldownDuration, cooldownEnabled = 0, 0, true
								cooldownGCD = true
							end
						end
						cooldownEnabledOk = cooldownEnabled ~= false and cooldownEnabled ~= 0
						show = alwaysShow or showWhenNoCooldown
						if not show and showCooldown and cooldownEnabledOk and isCooldownActive(cooldownStart, cooldownDuration) then show = true end
					elseif showWhenNoCooldown then
						show = true
					end
				end
			elseif resolvedType == "STANCE" then
				if not stanceRelevant then
					show = false
				elseif showWhenMissing then
					show = not stanceActive
				else
					show = stanceActive
				end
			elseif resolvedType == "CDM_AURA" and cdmAuras and cdmAuras.BuildRuntimeData then
				cdmAuraData = cdmAuras:BuildRuntimeData(panelId, entryId, entry, entryLayout, cdmAuraAlwaysShowMode)
				if cdmAuraData then
					iconTexture = cdmAuraData.iconTextureID or iconTexture
					stackCount = cdmAuraData.stackCount
					cooldownStart = cdmAuraData.cooldownStart
					cooldownDuration = cdmAuraData.cooldownDuration
					cooldownEnabled = cdmAuraData.cooldownEnabled
					cooldownRate = cdmAuraData.cooldownRate
					show = cdmAuraData.show == true
				end
			end
			if show and hideWhenNoResource and resourceInsufficient then show = false end
			if layoutEditActive then show = true end

			if show then
				visibleCount = visibleCount + 1
				local targetIndex = visibleCount
				local data = nil
				if fixedLayout then
					local fixedGroup = entry.fixedGroupId and fixedGroupById and fixedGroupById[entry.fixedGroupId] or nil
					if fixedGroup then
						if fixedGroup._eqolIsStatic == true then
							targetIndex = fixedStaticTargetIndices and fixedStaticTargetIndices[entryId] or nil
						else
							local groupVisibleCount = (fixedGroupVisibleCounts[fixedGroup.id] or 0) + 1
							fixedGroupVisibleCounts[fixedGroup.id] = groupVisibleCount
							targetIndex = fixedGroup._eqolDynamicTargetIndices and fixedGroup._eqolDynamicTargetIndices[groupVisibleCount] or nil
							if not (targetIndex and targetIndex <= fixedSlotCount) then targetIndex = nil end
						end
					else
						targetIndex = fixedStaticTargetIndices and fixedStaticTargetIndices[entryId] or nil
					end
					if targetIndex and targetIndex > fixedSlotCount then targetIndex = nil end
				end
				if fixedLayout and targetIndex and visibleSlotsUsed and not visibleSlotsUsed[targetIndex] then
					visibleSlotsUsed[targetIndex] = true
					visibleSlotCount = visibleSlotCount + 1
					visibleSlotIndices[visibleSlotCount] = targetIndex
				end
				if not data then data = targetIndex and visible[targetIndex] or nil end
				if not data then
					data = {}
					if targetIndex then visible[targetIndex] = data end
				end
				data.icon = iconTexture or Helper.PREVIEW_ICON
				data.showCooldown = showCooldown
				data.showCooldownText = showCooldownText
				data.showIconTexture = showEntryIconTexture
				data.showGhostIcon = showGhostIcon
				data.showCharges = showCharges
				data.showChargesCooldown = showCharges and entryShowChargesCooldown
				data.showStacks = showStacks
				data.showItemCount = showItemCount
				data.showItemUses = showItemUses
				data.chargesHideWhenZero = entryLayout.chargesHideWhenZero == true
				data.showKeybinds = entryLayout.keybindsEnabled == true
				data.keybindText = data.showKeybinds and Keybinds.GetEntryKeybindText(entry, entryLayout) or nil
				data.layout = entryLayout
				data.liveGlowAllowed = entryLayout.hideGlowOutOfCombat ~= true or playerInCombat == true
				data.entry = entry
				data.entryId = entryId
				data.hideOnCooldown = entryHideOnCooldown == true
				data.showOnCooldown = entryShowOnCooldown == true
				data.resolvedType = resolvedType
				data.overlayGlow = overlayGlow
				data.overlayGlowColor = nil
				data.overlayGlowStyle = procGlowStyle
				data.overlayGlowInset = procGlowInset
				data.stateTextureShown = false
				data.stateTextureType = stateTextureType
				data.stateTextureValue = stateTextureValue
				data.stateTextureWidth = stateTextureWidth
				data.stateTextureHeight = stateTextureHeight
				data.stateTextureScale = stateTextureScale
				data.stateTextureAngle = stateTextureAngle
				data.stateTextureDouble = stateTextureDouble
				data.stateTextureMirror = stateTextureMirror
				data.stateTextureMirrorSecond = stateTextureMirrorSecond
				data.stateTextureSpacingX = stateTextureSpacingX
				data.stateTextureSpacingY = stateTextureSpacingY
				if resolvedType == "STANCE" and glowReady then
					data.overlayGlow = true
					data.overlayGlowColor = glowColor
					data.overlayGlowStyle = glowStyle
					data.overlayGlowInset = glowInset
				end
				if resolvedType == "CDM_AURA" and cdmAuraPandemicGlow and cdmAuraData and cdmAuraData.pandemicActive == true then
					data.overlayGlow = true
					data.overlayGlowColor = pandemicGlowColor
					data.overlayGlowStyle = pandemicGlowStyle
					data.overlayGlowInset = pandemicGlowInset
				elseif resolvedType == "CDM_AURA" and cdmAuraActiveGlow and cdmAuraData and cdmAuraData.active == true then
					data.overlayGlow = true
					data.overlayGlowColor = glowColor
					data.overlayGlowStyle = glowStyle
					data.overlayGlowInset = glowInset
				end
				if stateTextureType then
					if layoutEditActive then
						data.stateTextureShown = true
					elseif resolvedType == "SPELL" then
						data.stateTextureShown = procActive == true
					elseif resolvedType == "CDM_AURA" then
						data.stateTextureShown = cdmAuraData and cdmAuraData.active == true or false
					end
				end
				data.powerInsufficient = powerInsufficient
				data.spellUnusable = spellUnusable
				data.rangeOverlay = rangeOverlay
				data.assistedSuggested = assistedSuggested == true
				data.noDesaturation = entryNoDesaturation
				data.cooldownDrawEdge = entryDrawEdge
				data.cooldownDrawBling = entryDrawBling
				data.cooldownDrawSwipe = entryDrawSwipe
				data.cooldownGcdDrawEdge = entryGcdDrawEdge
				data.cooldownGcdDrawBling = entryGcdDrawBling
				data.cooldownGcdDrawSwipe = entryGcdDrawSwipe
				data.glowReady = glowReady
				data.glowDuration = glowDuration
				data.readyGlowColor = glowColor
				data.readyGlowStyle = glowStyle
				data.readyGlowInset = glowInset
				data.readyGlowCheckPower = readyGlowCheckPower == true
				data.readyGlowResourceBlocked = readyGlowResourceBlocked == true
				data.spellReadyCondition = spellReadyCondition
				data.canTriggerReadyGlow = canTriggerReadyGlow
				data.soundReady = soundReady
				data.soundName = soundName
				data.previewSound = previewSound
				data.readyAt = runtime.readyAt[entryId]
				data.stanceActive = stanceActive == true
				data.stackCount = Helper.NormalizeDisplayCount(stackCount)
				data.itemCount = itemCount
				data.itemUses = itemUses
				data.emptyItem = emptyItem
				data.chargesInfo = chargesInfo
				data.chargeDurationObject = chargeDurationObject
				data.cooldownDurationObject = cooldownDurationObject
				data.cooldownStart = cooldownStart or 0
				data.cooldownDuration = cooldownDuration or 0
				data.cooldownEnabled = cooldownEnabled
				data.cooldownIsActive = cooldownIsActive
				data.cooldownRate = cooldownRate or 1
				data.cooldownGCD = cooldownGCD == true
				data.cdmAuraActive = cdmAuraData and cdmAuraData.active == true
				data.cdmAuraInactiveDesaturate = cdmAuraData and cdmAuraData.inactiveDesaturate == true
					or cdmAuraAlwaysShowMode == (CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE and CooldownPanels.CDM_AURA_ALWAYS_SHOW_MODE.DESATURATE or "DESATURATE")
				data.cdmAuraDurationObject = cdmAuraData and cdmAuraData.cooldownDurationObject or nil
			end
		end
	end

	if fixedLayout then
		for i = 1, fixedSlotCount do
			if not visibleSlotsUsed[i] then visible[i] = nil end
		end
		for i = fixedSlotCount + 1, #visible do
			visible[i] = nil
		end
	else
		for i = visibleCount + 1, #visible do
			visible[i] = nil
		end
	end
	local count = fixedLayout and fixedSlotCount or visibleCount
	local layoutCount = count > 0 and count or 1
	local layoutShapeChanged = didLayoutShapeChange(runtime, layout, layoutCount)
	if layoutShapeChanged then self:ApplyLayout(panelId, layoutCount) end
	ensureIconCount(frame, count)

	runtime.entryToIcon = runtime.entryToIcon or {}
	local entryToIcon = runtime.entryToIcon
	for key in pairs(entryToIcon) do
		entryToIcon[key] = nil
	end

	local sparseFixedRuntime = fixedLayout
		and not layoutEditActive
		and not lastLayoutEditActive
		and not layoutShapeChanged
		and runtime.initialized == true
		and previousOccupiedSlots ~= nil
		and previousOccupiedSlotIndices ~= nil
	local function updateRuntimeIconAtIndex(i)
		local data = visible[i]
		local icon = frame.icons[i]
		local slotColumn = fixedLayout and fixedGridColumns > 0 and (((i - 1) % fixedGridColumns) + 1) or (editGridColumns and (((i - 1) % editGridColumns) + 1) or nil)
		local slotRow = fixedLayout and fixedGridColumns > 0 and (math.floor((i - 1) / fixedGridColumns) + 1) or (editGridColumns and (math.floor((i - 1) / editGridColumns) + 1) or nil)
		if layoutEditActive or (icon and icon.layoutHandle and icon.layoutHandle._eqolLayoutConfigured == true) then
			self:ConfigureEditModePanelIcon(panelId, icon, data and data.entryId or nil, slotColumn, slotRow)
		end
		if not data then
			icon.entryId = nil
			if not layoutEditActive and icon._eqolRuntimeEmpty == true then
				icon:Hide()
			else
				CooldownPanels:ApplyEntryIconVisualLayout(icon, nil, nil)
				CooldownPanels:HideEditorGhostIcon(icon)
				clearPreviewCooldown(icon.cooldown)
				icon.cooldown:Clear()
				icon.cooldown._eqolPanelId = nil
				icon.cooldown._eqolEntryId = nil
				icon.cooldown._eqolCooldownIsGCD = nil
				icon.cooldown._eqolSoundReady = nil
				icon.cooldown._eqolSoundName = nil
				icon.cooldown._eqolGlowReady = nil
				icon.cooldown._eqolGlowDuration = nil
				if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
				if icon.cooldown.Resume then icon.cooldown:Resume() end
				icon.count:Hide()
				icon.charges:Hide()
				if icon.rangeOverlay then icon.rangeOverlay:Hide() end
				if icon.keybind then icon.keybind:Hide() end
				if icon.staticText then icon.staticText:Hide() end
				if icon.stateTexture then icon.stateTexture:Hide() end
				if icon.stateTextureSecond then icon.stateTextureSecond:Hide() end
				CooldownPanels.HidePreviewGlowBorder(icon)
				if icon.previewBling then icon.previewBling:Hide() end
				if icon.previewSoundBorder then icon.previewSoundBorder:Hide() end
				icon._eqolLayoutDragRangePreview = nil
				icon.texture:SetDesaturated(false)
				icon.texture:SetAlpha(1)
				CooldownPanels.ApplyIconTooltip(icon, nil, false)
				setAssistedHighlight(icon, false)
				CooldownPanels.StopAllIconGlows(icon)
				if layoutEditActive and fixedLayout then
					icon:Show()
					icon:SetAlpha(1)
					icon._eqolPreviewCellColumn = slotColumn
					icon._eqolPreviewCellRow = slotRow
					icon.texture:SetTexture(Helper.PREVIEW_ICON)
					icon.texture:SetShown(false)
					icon.texture:SetAlpha(0)
				else
					icon:Hide()
				end
			end
			icon._eqolRuntimeEmpty = not layoutEditActive
		else
			icon._eqolRuntimeEmpty = nil
			icon:Show()
			icon.entryId = data.entryId
			icon._eqolPreviewCellColumn = slotColumn
			icon._eqolPreviewCellRow = slotRow
			if layoutEditActive then
				CooldownPanels.HidePreviewGlowBorder(icon)
				CooldownPanels.StopAllIconGlows(icon)
			end
			local showGhostIcon = layoutEditActive and data.showGhostIcon == true
			local hideOnCooldown = data.hideOnCooldown == true
			local showOnCooldown = data.showOnCooldown == true
			CooldownPanels:ApplyEntryIconVisualLayout(icon, data.layout, data.entry)
			CooldownPanels:HideEditorGhostIcon(icon)
			if showOnCooldown then
				icon:SetAlpha(0)
			elseif not hideOnCooldown then
				icon:SetAlpha(1)
			end
			clearPreviewCooldown(icon.cooldown)
			entryToIcon[data.entryId] = icon
			icon.texture:SetTexture(data.icon or Helper.PREVIEW_ICON)
			icon.texture:SetAlpha(1)
			icon.texture:SetShown(data.showIconTexture ~= false)
			CooldownPanels.ApplyIconTooltip(icon, data.entry, showTooltips)
			icon.cooldown:SetHideCountdownNumbers(not data.showCooldownText)
			CooldownPanels:ApplyEntryStackTextStyle(icon, data.layout, data.entry, defaultCountFontPath, defaultCountFontSize, defaultCountFontStyle)
			CooldownPanels:ApplyEntryChargesTextStyle(icon, data.layout, data.entry, defaultChargesFontPath, defaultChargesFontSize, defaultChargesFontStyle)
			if icon.cooldown.SetReverse then icon.cooldown:SetReverse(data.resolvedType == "CDM_AURA") end
			if icon.cooldown.SetUseAuraDisplayTime then icon.cooldown:SetUseAuraDisplayTime(data.resolvedType == "CDM_AURA") end

			-- Context for OnCooldownDone (sound/glow) - keep this in sync every update.
			icon.cooldown._eqolPanelId = panelId
			icon.cooldown._eqolEntryId = data.entryId
			icon.cooldown._eqolCooldownIsGCD = data.cooldownGCD == true
			icon.cooldown._eqolSoundReady = data.soundReady and not data.cooldownGCD
			icon.cooldown._eqolSoundName = data.soundName
			icon.cooldown._eqolGlowReady = data.glowReady
			icon.cooldown._eqolGlowDuration = data.glowDuration
			if icon.cooldown.Resume then icon.cooldown:Resume() end
			CooldownPanels.HidePreviewGlowBorder(icon)
			if icon.previewBling then icon.previewBling:Hide() end
			if icon.previewSoundBorder then icon.previewSoundBorder:Hide() end
			icon._eqolLayoutDragRangePreview = nil

			local cooldownStart = data.cooldownStart or 0
			local cooldownDuration = data.cooldownDuration or 0
			local cooldownRate = data.cooldownRate or 1
			local chargeDurationObject = data.chargeDurationObject
			local cooldownDurationObject = data.cooldownDurationObject
			local cooldownEnabledOk = isSafeNotFalse(data.cooldownEnabled)
			if data.resolvedType == "ITEM" or data.resolvedType == "SLOT" then cooldownEnabledOk = data.cooldownEnabled ~= false and data.cooldownEnabled ~= 0 end
			local spellCooldownActive = CooldownPanels.IsSpellCooldownInfoActive(data.cooldownIsActive, data.cooldownEnabled, cooldownStart, cooldownDuration)
			local durationActive = cooldownDurationObject ~= nil
			if data.resolvedType == "SPELL" then durationActive = durationActive and spellCooldownActive end
			local cdmAuraActive = data.cdmAuraActive == true
			local cdmAuraDurationObject = data.cdmAuraDurationObject
			local cdmAuraDurationActive = cdmAuraDurationObject ~= nil
			local cooldownActive = data.showCooldown and (durationActive or spellCooldownActive)
			local usingCooldown = false
			local desaturate = false
			local hidden = false
			local chargeCooldownHasAvailableCharge = false
			local chargeInfoActive = false
			local entryNoDesaturation = data.noDesaturation == true and not (data.resolvedType == "ITEM" and data.emptyItem == true)
			local entryDrawEdge = data.cooldownDrawEdge ~= false
			local entryDrawBling = data.cooldownDrawBling ~= false
			local entryDrawSwipe = data.cooldownDrawSwipe ~= false
			local entryGcdDrawEdge = data.cooldownGcdDrawEdge == true
			local entryGcdDrawBling = data.cooldownGcdDrawBling == true
			local entryGcdDrawSwipe = data.cooldownGcdDrawSwipe == true

			local chargesAlpha = 1
			if data.showCharges and data.chargesInfo and data.chargesInfo.maxCharges ~= nil then
				if data.chargesInfo.currentCharges ~= nil then
					icon.charges:SetText(data.chargesInfo.currentCharges)
					if data.chargesHideWhenZero == true then chargesAlpha = data.chargesInfo.currentCharges end
					icon.charges:SetAlpha(chargesAlpha)
					icon.charges:Show()
				else
					icon.charges:SetAlpha(1)
					icon.charges:Hide()
				end
				if data.showCooldown then
						chargeInfoActive = CooldownPanels.IsChargeInfoActive(data.chargesInfo)
					if chargeInfoActive then
						cooldownStart = data.chargesInfo.cooldownStartTime or cooldownStart
						cooldownDuration = data.chargesInfo.cooldownDuration or cooldownDuration
						cooldownRate = data.chargesInfo.chargeModRate or cooldownRate
						cooldownActive = true
						usingCooldown = true
					end
				end
				if usingCooldown then
					if isSafeNumber(data.chargesInfo.currentCharges) then
						chargeCooldownHasAvailableCharge = data.chargesInfo.currentCharges > 0 and isSafeLessThan(data.chargesInfo.currentCharges, data.chargesInfo.maxCharges)
						desaturate = data.chargesInfo.currentCharges == 0
						if hideOnCooldown or showOnCooldown then hidden = desaturate end
					else
						-- local CCD = C_Spell.GetSpellChargeDuration(data.entry.spellID)
						-- local SCD = C_Spell.GetSpellCooldownDuration(data.entry.spellID)
						-- if CCD and SCD then
						-- 	-- desaturate = true
						-- 	-- icon.texture:SetDesaturation(SCD:GetRemainingDuration())
						-- else
						-- 	-- desaturate = false
						-- 	-- icon.texture:SetDesaturated(false)
						-- end
					end
				end
			else
				icon.charges:SetAlpha(1)
				icon.charges:Hide()
			end

			if data.showItemUses then
				if data.itemUses ~= nil then
					icon.charges:SetText(data.itemUses)
					icon.charges:SetAlpha(1)
					icon.charges:Show()
				else
					icon.charges:SetAlpha(1)
					icon.charges:Hide()
				end
			end
			if layoutEditActive and not (icon.charges and icon.charges.IsShown and icon.charges:IsShown()) then
				if data.resolvedType == "SPELL" and data.showCharges then
					icon.charges:SetText("2")
					icon.charges:SetAlpha(1)
					icon.charges:Show()
				elseif data.resolvedType == "ITEM" and data.showItemUses then
					icon.charges:SetText("2")
					icon.charges:SetAlpha(1)
					icon.charges:Show()
				end
			end

			if data.emptyItem then desaturate = true end
			if data.resolvedType == "CDM_AURA" and data.cdmAuraInactiveDesaturate == true and not cdmAuraActive and not cdmAuraDurationActive then desaturate = true end

			if not isSafeNumber(cooldownRate) then cooldownRate = 1 end
			CooldownPanels.SetIconDesaturatedRuntime(icon.texture, desaturate, entryNoDesaturation)
			if hideOnCooldown then
				icon:SetAlphaFromBoolean(hidden, 0, 1)
			elseif showOnCooldown then
				icon:SetAlphaFromBoolean(hidden, 1, 0)
			end
			if data.showCooldown then
				if usingCooldown then
					setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
					if chargeCooldownHasAvailableCharge then
						-- Match Blizzard action-button behavior: charge recharge takes precedence while at least one charge remains.
						if data.showChargesCooldown then
							if chargeDurationObject and icon.cooldown.SetCooldownFromDurationObject then
								icon.cooldown:Clear()
								icon.cooldown:SetCooldownFromDurationObject(chargeDurationObject)
							elseif isSafeNumber(cooldownStart) and isSafeNumber(cooldownDuration) then
								icon.cooldown:Clear()
								icon.cooldown:SetCooldown(cooldownStart, cooldownDuration, cooldownRate)
							else
								icon.cooldown:Clear()
							end
							if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", onCooldownDone) end
						else
							icon.cooldown:Clear()
							if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
						end
					else
						if data.showChargesCooldown then
							if chargeDurationObject and icon.cooldown.SetCooldownFromDurationObject then
								icon.cooldown:Clear()
								icon.cooldown:SetCooldownFromDurationObject(chargeDurationObject)
							elseif isSafeNumber(cooldownStart) and isSafeNumber(cooldownDuration) then
								icon.cooldown:Clear()
								icon.cooldown:SetCooldown(cooldownStart, cooldownDuration, cooldownRate)
							else
								icon.cooldown:Clear()
							end
							if not data.cooldownGCD then
								if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", onCooldownDone) end
							end
						else
							icon.cooldown:Clear()
							if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
						end

						-- local SCD = effectiveId and C_Spell.GetSpellCooldownDuration(effectiveId)
						-- only when you have zero charges SCD will be true CCD is always true when one charge is missing
						if cooldownDurationObject then
							if data.cooldownGCD then
							-- icon.texture:SetDesaturation(0)
							-- desaturate = false
							-- setCooldownDrawState(icon.cooldown, entryGcdDrawEdge, entryGcdDrawBling, entryGcdDrawSwipe)
							else
								if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", onCooldownDone) end
								setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
								CooldownPanels.SetIconDesaturationRuntime(icon.texture, cooldownDurationObject:EvaluateRemainingDuration(curveDesat), entryNoDesaturation)
								if hideOnCooldown then
									icon:SetAlpha(cooldownDurationObject:EvaluateRemainingDuration(curveAlpha))
								elseif showOnCooldown then
									icon:SetAlpha(cooldownDurationObject:EvaluateRemainingDuration(curveDesat))
								end
								if data.showChargesCooldown and chargeDurationObject then
									icon.cooldown:SetCooldownFromDurationObject(chargeDurationObject)
								else
									icon.cooldown:SetCooldownFromDurationObject(cooldownDurationObject)
								end
							end
						end
					end
				elseif durationActive then
					icon.cooldown:SetCooldownFromDurationObject(cooldownDurationObject)
					if data.cooldownGCD then
						CooldownPanels.SetIconDesaturationRuntime(icon.texture, 0, entryNoDesaturation)
						if hideOnCooldown then
							icon:SetAlpha(1)
						elseif showOnCooldown then
							icon:SetAlpha(0)
						end
						desaturate = false
						hidden = false
						setCooldownDrawState(icon.cooldown, entryGcdDrawEdge, entryGcdDrawBling, entryGcdDrawSwipe)
					else
						setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)

						local desat = cooldownDurationObject:EvaluateRemainingDuration(curveDesat)
						CooldownPanels.SetIconDesaturationRuntime(icon.texture, desat, entryNoDesaturation)
						if hideOnCooldown then
							icon:SetAlpha(cooldownDurationObject:EvaluateRemainingDuration(curveAlpha))
						elseif showOnCooldown then
							icon:SetAlpha(cooldownDurationObject:EvaluateRemainingDuration(curveDesat))
						end
					end
					if data.cooldownGCD then
					else
						if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", onCooldownDone) end
					end
				elseif cdmAuraActive then
					setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
					icon.cooldown:Clear()
					if cdmAuraDurationActive and icon.cooldown.SetCooldownFromDurationObject then
						icon.cooldown:SetCooldownFromDurationObject(cdmAuraDurationObject)
						if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", onCooldownDone) end
					else
						if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
					end
					CooldownPanels.SetIconDesaturationRuntime(icon.texture, 0, entryNoDesaturation)
					desaturate = false
					if hideOnCooldown then
						icon:SetAlpha(0)
						hidden = true
					elseif showOnCooldown then
						icon:SetAlpha(1)
					end
				elseif cooldownActive then
					icon.cooldown:SetCooldown(cooldownStart, cooldownDuration, cooldownRate)
					desaturate = true
					CooldownPanels.SetIconDesaturatedRuntime(icon.texture, desaturate, entryNoDesaturation)
					if hideOnCooldown then
						icon:SetAlpha(0)
					elseif showOnCooldown then
						icon:SetAlpha(1)
					end
					setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
					if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", onCooldownDone) end
				elseif data.resolvedType == "CDM_AURA" and cdmAuraActive then
					setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
					icon.cooldown:Clear()
					CooldownPanels.SetIconDesaturationRuntime(icon.texture, 0, entryNoDesaturation)
					desaturate = false
					if hideOnCooldown then
						icon:SetAlpha(0)
						hidden = true
					elseif showOnCooldown then
						icon:SetAlpha(1)
					end
					if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
				else
					setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
					icon.cooldown:Clear()
					if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
				end
			else
				setCooldownDrawState(icon.cooldown, entryDrawEdge, entryDrawBling, entryDrawSwipe)
				icon.cooldown:Clear()
				if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
			end
			if layoutEditActive and data.showCooldown and data.showCooldownText then
				hidden = false
				if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
				setExampleCooldown(icon.cooldown)
				icon:SetAlpha(1)
			end
			CooldownPanels:ApplyEntryCooldownTextStyle(icon, data.layout, data.entry)
			if data.spellUnusable then
				icon.texture:SetVertexColor(unusableTintR or 0.6, unusableTintG or 0.6, unusableTintB or 0.6)
			elseif data.powerInsufficient then
				icon.texture:SetVertexColor(powerTintR or 0.5, powerTintG or 0.5, powerTintB or 1)
			elseif ((data.resolvedType == "ITEM" or data.resolvedType == "SLOT") and not cooldownEnabledOk and isSafeGreaterThan(cooldownDuration, 0))
				or (data.resolvedType == "SPELL" and data.cooldownEnabled == false and data.cooldownIsActive == false and data.cooldownGCD ~= true) then
				icon.texture:SetVertexColor(0.4, 0.4, 0.4)
			else
				icon.texture:SetVertexColor(1, 1, 1)
			end

			if data.showItemCount and data.itemCount ~= nil then
				icon.count:SetText(data.itemCount)
				icon.count:Show()
			elseif data.showStacks and data.stackCount then
				icon.count:SetText(data.stackCount)
				icon.count:Show()
			else
				icon.count:Hide()
			end
			if layoutEditActive and not (icon.count and icon.count.IsShown and icon.count:IsShown()) then
				if data.resolvedType == "ITEM" and data.showItemCount then
					icon.count:SetText("20")
					icon.count:Show()
				elseif data.showStacks then
					icon.count:SetText(data.resolvedType == "CDM_AURA" and "2" or "3")
					icon.count:Show()
				end
			end
			if icon.keybind then
				if data.showKeybinds and data.keybindText then
					icon.keybind:SetText(data.keybindText)
					icon.keybind:Show()
				else
					icon.keybind:Hide()
				end
			end
			local staticTextCooldown = false
			if data.entry and data.entry.staticTextShowOnCooldown == true then
				staticTextCooldown = data.stanceActive == true or cdmAuraActive or durationActive or (cooldownEnabledOk and isCooldownActive(cooldownStart, cooldownDuration))
			end
			applyStaticText(icon, data.layout, data.entry, staticFontPath, staticFontSize, staticFontStyle, staticTextCooldown)
			if durationActive and showOnCooldown and data.entry.staticTextShowOnCooldown == true and staticTextCooldown then
				if data.entry.spellID then
					icon.staticText:SetAlpha(cooldownDurationObject:EvaluateRemainingDuration(Helper.FakeCurve))
					icon.cooldown:SetAlpha(cooldownDurationObject:EvaluateRemainingDuration(Helper.FakeCurve))
				end
			end

			applyStateTexture(icon, data)
			if layoutEditActive and icon.previewSoundBorder and data.previewSound then icon.previewSoundBorder:Show() end
			if icon.rangeOverlay then
				if data.rangeOverlay then
					icon.rangeOverlay:SetColorTexture(rangeOverlayR or 1, rangeOverlayG or 0.1, rangeOverlayB or 0.1, rangeOverlayA or 0.35)
					icon.rangeOverlay:Show()
				else
					icon.rangeOverlay:Hide()
				end
			end
			setAssistedHighlight(icon, data.assistedSuggested == true)

			local readyGlowCooldownRunning
			local useSecretReadyGlow = data.resolvedType == "SPELL" and data.spellReadyCondition ~= nil and data.glowReady and data.showCooldown and data.canTriggerReadyGlow
			local secretReadyGlowAllowed = useSecretReadyGlow and data.readyGlowResourceBlocked ~= true
			if useSecretReadyGlow then
				if data.readyAt or (readyGlowPrimed and readyGlowPrimed[data.entryId]) then
					CooldownPanels.ClearReadyGlowEntryState(panelId, data.entryId, true)
					data.readyAt = nil
				end
			elseif data.canTriggerReadyGlow then
				readyGlowCooldownRunning = durationActive or usingCooldown or (cooldownEnabledOk and isCooldownActive(cooldownStart, cooldownDuration))
				if readyGlowCooldownRunning then
					CooldownPanels.ClearReadyGlowEntryState(panelId, data.entryId, true)
					data.readyAt = nil
				end
			end
			if not useSecretReadyGlow and data.glowReady and data.showCooldown and data.canTriggerReadyGlow then
				if data.readyAt then
					if readyGlowPrimed then readyGlowPrimed[data.entryId] = true end
				elseif not readyGlowCooldownRunning and not data.cooldownGCD and readyGlowPrimed and not readyGlowPrimed[data.entryId] then
					triggerReadyGlow(panelId, data.entryId, data.glowDuration)
					readyGlowPrimed[data.entryId] = true
					data.readyAt = runtime.readyAt[data.entryId]
				end
			end

			local overlayGlow = data.overlayGlow == true
			local overlayGlowColor = overlayGlow and data.overlayGlowColor or nil
			local simpleGlowEnabled = overlayGlow
			local simpleGlowColor = overlayGlowColor
			local simpleGlowStyle = data.overlayGlowStyle or data.readyGlowStyle
			local simpleGlowInset = data.overlayGlowInset or data.readyGlowInset
			if data.glowReady and not useSecretReadyGlow then
				local ready = data.readyAt ~= nil
				if ready and data.readyGlowCheckPower == true and data.readyGlowResourceBlocked == true then ready = false end

				simpleGlowEnabled = overlayGlow or ready
				simpleGlowColor = ready and data.readyGlowColor or overlayGlowColor
				simpleGlowStyle = ready and data.readyGlowStyle or (data.overlayGlowStyle or data.readyGlowStyle)
				simpleGlowInset = ready and data.readyGlowInset or (data.overlayGlowInset or data.readyGlowInset)
			end
			if layoutEditActive and data.entry and data.entry.type ~= "MACRO" and (data.entry.glowReady == true or data.entry.pandemicGlow == true) then
				simpleGlowEnabled = true
				simpleGlowColor = (
					data.entry.type == "CDM_AURA"
					and data.entry.pandemicGlow == true
					and data.entry.glowReady ~= true
					and CooldownPanels:ResolveEntryPandemicGlowColor(data.layout, data.entry)
				)
					or data.readyGlowColor
					or overlayGlowColor
				simpleGlowStyle = (
					data.entry.type == "CDM_AURA"
					and data.entry.pandemicGlow == true
					and data.entry.glowReady ~= true
					and select(2, CooldownPanels:ResolveEntryPandemicGlowVisual(data.layout, data.entry))
				) or data.readyGlowStyle
				simpleGlowInset = (
					data.entry.type == "CDM_AURA"
					and data.entry.pandemicGlow == true
					and data.entry.glowReady ~= true
					and select(3, CooldownPanels:ResolveEntryPandemicGlowVisual(data.layout, data.entry))
				) or data.readyGlowInset
			end
			if layoutEditActive then
				CooldownPanels.StopAllIconGlows(icon)
				if simpleGlowEnabled then
					CooldownPanels.ShowPreviewGlowBorder(icon, simpleGlowColor)
				else
					CooldownPanels.HidePreviewGlowBorder(icon)
				end
			else
				CooldownPanels.HidePreviewGlowBorder(icon)
				if data.liveGlowAllowed == false then
					setGlow(icon, false, nil, "EQOL_SIMPLE")
					setGlow(icon, false, nil, "EQOL_OVERLAY")
					setGlow(icon, false, nil, "EQOL_READY")
				elseif useSecretReadyGlow then
					setGlow(icon, false, nil, "EQOL_SIMPLE")
					if secretReadyGlowAllowed then
						setGlow(
							icon,
							overlayGlow,
							overlayGlowColor,
							"EQOL_OVERLAY",
							data.spellReadyCondition,
							0,
							1,
							data.overlayGlowStyle or data.readyGlowStyle,
							data.overlayGlowInset or data.readyGlowInset
						)
						setGlow(icon, true, data.readyGlowColor, "EQOL_READY", data.spellReadyCondition, 1, 0, data.readyGlowStyle, data.readyGlowInset)
					else
						setGlow(icon, overlayGlow, overlayGlowColor, "EQOL_OVERLAY", nil, nil, nil, data.overlayGlowStyle or data.readyGlowStyle, data.overlayGlowInset or data.readyGlowInset)
						setGlow(icon, false, nil, "EQOL_READY")
					end
				else
					setGlow(icon, false, nil, "EQOL_OVERLAY")
					setGlow(icon, false, nil, "EQOL_READY")
					setGlow(icon, simpleGlowEnabled, simpleGlowColor, "EQOL_SIMPLE", nil, nil, nil, simpleGlowStyle, simpleGlowInset)
				end
			end
			if showGhostIcon then
				icon:SetAlpha(1)
				CooldownPanels:ApplyEditorGhostIcon(icon)
			end
		end
	end

	if sparseFixedRuntime and visibleSlotIndices then
		for listIndex = 1, visibleSlotCount do
			updateRuntimeIconAtIndex(visibleSlotIndices[listIndex])
		end
		if previousOccupiedSlotIndices and previousOccupiedSlots then
			for listIndex = 1, #previousOccupiedSlotIndices do
				local slotIndex = previousOccupiedSlotIndices[listIndex]
				if slotIndex and not visibleSlotsUsed[slotIndex] and previousOccupiedSlots[slotIndex] then updateRuntimeIconAtIndex(slotIndex) end
			end
		end
	else
		for i = 1, count do
			updateRuntimeIconAtIndex(i)
		end
	end

	for i = count + 1, #frame.icons do
		local icon = frame.icons[i]
		if icon then
			self:ConfigureEditModePanelIcon(panelId, icon, nil, nil, nil)
			icon.entryId = nil
			clearPreviewCooldown(icon.cooldown)
			icon.cooldown:Clear()
			icon.cooldown._eqolSoundReady = nil
			icon.cooldown._eqolSoundName = nil
			if icon.cooldown.SetScript then icon.cooldown:SetScript("OnCooldownDone", nil) end
			if icon.cooldown.Resume then icon.cooldown:Resume() end
			icon.count:Hide()
			icon.charges:Hide()
			if icon.rangeOverlay then icon.rangeOverlay:Hide() end
			if icon.keybind then icon.keybind:Hide() end
			if icon.staticText then icon.staticText:Hide() end
			if icon.stateTexture then icon.stateTexture:Hide() end
			if icon.stateTextureSecond then icon.stateTextureSecond:Hide() end
			CooldownPanels:HideEditorGhostIcon(icon)
			CooldownPanels.HidePreviewGlowBorder(icon)
			if icon.previewBling then icon.previewBling:Hide() end
			if icon.previewSoundBorder then icon.previewSoundBorder:Hide() end
			icon._eqolLayoutDragRangePreview = nil
			icon.texture:SetDesaturated(false)
			icon.texture:SetAlpha(1)
			setAssistedHighlight(icon, false)
			CooldownPanels.StopAllIconGlows(icon)
		end
	end

	if fixedLayout then
		local nextScratchOccupiedSlots = previousOccupiedSlots or {}
		local nextScratchOccupiedSlotIndices = previousOccupiedSlotIndices or {}
		for i = visibleSlotCount + 1, #(visibleSlotIndices or {}) do
			visibleSlotIndices[i] = nil
		end
		runtime._eqolScratchOccupiedSlots = nextScratchOccupiedSlots
		runtime._eqolScratchOccupiedSlotIndices = nextScratchOccupiedSlotIndices
		runtime._eqolOccupiedSlots = visibleSlotsUsed
		runtime._eqolOccupiedSlotIndices = visibleSlotIndices
	end
	runtime._eqolLastLayoutEditActive = layoutEditActive == true
	runtime.visibleCount = visibleCount
	runtime.initialized = true
end

function CooldownPanels:ApplyPanelPosition(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	local anchor = ensurePanelAnchor(panel)
	local point = Helper.NormalizeAnchor(anchor and anchor.point, panel.point or "CENTER")
	local relativePoint = Helper.NormalizeAnchor(anchor and anchor.relativePoint, point)
	local x = tonumber(anchor and anchor.x) or 0
	local y = tonumber(anchor and anchor.y) or 0
	local relativeFrame = resolveAnchorFrame(anchor)
	local layoutEditCursorPanelId = self:GetLayoutEditFakeCursorPanel()
	if layoutEditCursorPanelId ~= nil and normalizeId(layoutEditCursorPanelId) == normalizeId(panelId) and panelUsesFakeCursor(panel) then
		point = "CENTER"
		relativePoint = "CENTER"
		relativeFrame = UIParent
	end
	if
		runtime._eqolAnchorAppliedFrame == frame
		and runtime._eqolAnchorPoint == point
		and runtime._eqolAnchorRelativePoint == relativePoint
		and runtime._eqolAnchorRelativeFrame == relativeFrame
		and runtime._eqolAnchorX == x
		and runtime._eqolAnchorY == y
	then
		return
	end
	runtime._eqolAnchorAppliedFrame = frame
	runtime._eqolAnchorPoint = point
	runtime._eqolAnchorRelativePoint = relativePoint
	runtime._eqolAnchorRelativeFrame = relativeFrame
	runtime._eqolAnchorX = x
	runtime._eqolAnchorY = y
	frame:ClearAllPoints()
	frame:SetPoint(point, relativeFrame, relativePoint, x, y)
end

function CooldownPanels:HandlePositionChanged(panelId, data)
	local panel = self:GetPanel(panelId)
	if not panel or type(data) ~= "table" then return end
	local runtime = getRuntime(panelId)
	if runtime.suspendEditSync then return end
	local anchor = ensurePanelAnchor(panel)
	if not anchor or not anchorUsesUIParent(anchor) then return end
	anchor.point = data.point or anchor.point or "CENTER"
	anchor.relativePoint = data.relativePoint or anchor.relativePoint or anchor.point
	if data.x ~= nil then anchor.x = data.x end
	if data.y ~= nil then anchor.y = data.y end
	panel.point = anchor.point or panel.point or "CENTER"
	panel.x = anchor.x or panel.x or 0
	panel.y = anchor.y or panel.y or 0
end

function CooldownPanels:IsInEditMode() return EditMode and EditMode.IsInEditMode and EditMode:IsInEditMode() end

local function playerHasVehicleUI()
	if UnitHasVehicleUI then return UnitHasVehicleUI("player") == true end
	if UnitInVehicle then return UnitInVehicle("player") == true end
	return false
end

local function isPetBattleActive() return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() == true end
local function isClientSceneActive()
	local runtime = CooldownPanels.runtime
	return runtime and runtime.clientSceneActive == true
end

function CooldownPanels:ShouldShowPanel(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return false end
	if self:IsPanelLayoutEditActive(panelId) then return true end
	if panel.enabled == false then return false end
	if not panelAllowsSpec(panel) then return false end
	if self:IsInEditMode() == true then return true end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	if panel.layout.hideInPetBattle == true and isPetBattleActive() then return false end
	if panel.layout.hideInVehicle == true and playerHasVehicleUI() then return false end
	local hideInClientScene = panel.layout.hideInClientScene
	if hideInClientScene == nil then hideInClientScene = Helper.PANEL_LAYOUT_DEFAULTS.hideInClientScene == true end
	if hideInClientScene and isClientSceneActive() then return false end
	if not PanelVisibility.ShouldShow(panel.layout.visibility) then return false end
	local runtime = getRuntime(panelId)
	return runtime.visibleCount and runtime.visibleCount > 0
end

function CooldownPanels:UpdatePanelOpacity(panelId, forcedAlpha)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	local fallbackOut = Helper.PANEL_LAYOUT_DEFAULTS.opacityOutOfCombat
	local fallbackIn = Helper.PANEL_LAYOUT_DEFAULTS.opacityInCombat
	local outAlpha = Helper.NormalizeOpacity(layout.opacityOutOfCombat, fallbackOut)
	local inAlpha = Helper.NormalizeOpacity(layout.opacityInCombat, fallbackIn)
	local alpha
	if forcedAlpha ~= nil then
		alpha = forcedAlpha
	elseif self:IsInEditMode() == true or self:IsPanelLayoutEditActive(panelId) then
		alpha = 1
	else
		local inCombat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
		alpha = inCombat and inAlpha or outAlpha
	end
	if alpha == nil then alpha = 1 end
	if frame._eqolAlpha ~= alpha then
		frame._eqolAlpha = alpha
		frame:SetAlpha(alpha)
	end
end

function CooldownPanels:UpdateVisibility(panelId)
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	local shouldShow = self:ShouldShowPanel(panelId)
	local forceAlphaHidden = false
	if frame:IsShown() ~= shouldShow then
		local inCombat = (InCombatLockdown and InCombatLockdown()) or false
		local isProtected = frame.IsProtected and frame:IsProtected()
		if not (inCombat and isProtected) then
			frame:SetShown(shouldShow)
		elseif not shouldShow then
			-- Protected frames cannot be shown/hidden in combat; use alpha fallback.
			forceAlphaHidden = true
		end
	elseif not shouldShow then
		local inCombat = (InCombatLockdown and InCombatLockdown()) or false
		local isProtected = frame.IsProtected and frame:IsProtected()
		if inCombat and isProtected then forceAlphaHidden = true end
	end
	self:UpdatePanelOpacity(panelId, forceAlphaHidden and 0 or nil)
	self:UpdatePanelMouseState(panelId)
end

function CooldownPanels:UpdatePanelMouseState(panelId)
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	local inEditMode = self:IsInEditMode() == true
	local layoutEditActive = self:IsPanelLayoutEditActive(panelId)
	if frame._mouseEnabled ~= false then
		frame._mouseEnabled = false
		frame:EnableMouse(false)
	end
	if frame.Selection and frame.Selection.EnableMouse then
		local enableSelection = inEditMode and not layoutEditActive
		if frame._eqolSelectionMouseEnabled ~= enableSelection then
			frame._eqolSelectionMouseEnabled = enableSelection
			frame.Selection:EnableMouse(enableSelection)
		end
	end
	if frame.editDropZone then
		local showDropZone = layoutEditActive
		frame.editDropZone:SetShown(showDropZone)
		if frame._eqolDropZoneMouseEnabled ~= showDropZone then
			frame._eqolDropZoneMouseEnabled = showDropZone
			frame.editDropZone:EnableMouse(showDropZone)
		end
	end
	local showMoveHandle = false
	local showPanelHandle = layoutEditActive and self:IsLayoutPanelStandaloneMenuAvailable(panelId)
	local handleLayoutKey
	if showMoveHandle then
		handleLayoutKey = "MOVE"
	elseif showPanelHandle then
		handleLayoutKey = "PANEL"
	else
		handleLayoutKey = "NONE"
	end
	if frame._eqolPanelHandleLayout ~= handleLayoutKey then
		frame._eqolPanelHandleLayout = handleLayoutKey
		if frame.editMoveHandle then
			frame.editMoveHandle:ClearAllPoints()
			frame.editMoveHandle:SetPoint("BOTTOM", frame, "TOP", 0, 4)
		end
		if frame.editPanelHandle then
			frame.editPanelHandle:ClearAllPoints()
			frame.editPanelHandle:SetPoint("BOTTOM", frame, "TOP", 0, 4)
		end
	end
	if frame.editMoveHandle then
		frame.editMoveHandle:SetShown(showMoveHandle == true)
		if frame._eqolMoveHandleMouseEnabled ~= showMoveHandle then
			frame._eqolMoveHandleMouseEnabled = showMoveHandle
			frame.editMoveHandle:EnableMouse(showMoveHandle == true)
		end
	end
	if frame.editPanelHandle then
		frame.editPanelHandle:SetShown(showPanelHandle == true)
		if frame._eqolPanelHandleMouseEnabled ~= showPanelHandle then
			frame._eqolPanelHandleMouseEnabled = showPanelHandle
			frame.editPanelHandle:EnableMouse(showPanelHandle == true)
		end
	end
end

function CooldownPanels:ShowEditModeHint(panelId, show)
	local runtime = getRuntime(panelId)
	local frame = runtime.frame
	if not frame then return end
	if show then
		if frame.bg then frame.bg:Show() end
		if frame.label then frame.label:Show() end
	else
		if frame.bg then frame.bg:Hide() end
		if frame.label then frame.label:Hide() end
	end
end

function CooldownPanels:RefreshPanel(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local layoutEditActive = self:IsPanelLayoutEditActive(panelId)
	if panel.enabled == false and not self:IsInEditMode() and not layoutEditActive then
		local runtime = self.runtime and self.runtime[panelId]
		local frame = runtime and runtime.frame
		if frame then frame:Hide() end
		return
	end
	local startedRuntimeQueryBatch = false
	if not self:IsRuntimeQueryBatchActive() then
		self:BeginRuntimeQueryBatch()
		startedRuntimeQueryBatch = true
	end
	self:EnsurePanelFrame(panelId)
	self:ApplyPanelPosition(panelId)
	local runtime = getRuntime(panelId)
	if layoutEditActive then
		clearRuntimeLayoutShapeCache(runtime)
		self:ApplyLayout(panelId)
		self:UpdateRuntimeIcons(panelId)
	elseif self:IsInEditMode() then
		clearRuntimeLayoutShapeCache(runtime)
		self:ApplyLayout(panelId)
		self:UpdatePreviewIcons(panelId)
	else
		if ensureAssistedHighlightHook then ensureAssistedHighlightHook() end
		self:UpdateRuntimeIcons(panelId)
	end
	self:UpdateVisibility(panelId)
	self:ShowEditModeHint(panelId, self:IsInEditMode() == true or layoutEditActive)
	if startedRuntimeQueryBatch then self:EndRuntimeQueryBatch() end
end

function CooldownPanels:HideAllRuntimePanels()
	local root = ensureRoot()
	if not root or not root.panels then return end
	local allRuntime = self.runtime
	if not allRuntime then return end
	for panelId in pairs(root.panels) do
		local runtime = allRuntime[panelId]
		if runtime then
			runtime.visibleCount = 0
			runtime.visiblePowerSpellCount = 0
			runtime._eqolHiddenByEligibility = true
			if runtime.visibleEntries then
				for i = 1, #runtime.visibleEntries do
					runtime.visibleEntries[i] = nil
				end
			end
			if runtime.visiblePowerSpells then
				for i = 1, #runtime.visiblePowerSpells do
					runtime.visiblePowerSpells[i] = nil
				end
			end
			if runtime.frame then runtime.frame:Hide() end
		end
	end
end

function CooldownPanels:RefreshAllPanels(forceAll)
	local root = ensureRoot()
	if not root then return end
	local runtime = self.runtime
	local panelIds = nil
	if forceAll == true and runtime and runtime.disabledPanelIds then
		for i = 1, #runtime.disabledPanelIds do
			runtime.disabledPanelIds[i] = nil
		end
	end
	if forceAll ~= true and self:IsInEditMode() ~= true and not self:IsAnyPanelLayoutEditActive() then
		local enabledPanels = runtime and runtime.enabledPanels
		if not enabledPanels or not next(enabledPanels) then
			self:HideAllRuntimePanels()
			self:UpdateCursorAnchorState()
			return
		end
		panelIds = runtime and runtime.enabledPanelIds or nil
		if runtime and runtime.disabledPanelIds then
			for i = 1, #runtime.disabledPanelIds do
				local panelId = runtime.disabledPanelIds[i]
				if panelId and root.panels and root.panels[panelId] then self:RefreshPanel(panelId) end
			end
			for i = 1, #runtime.disabledPanelIds do
				runtime.disabledPanelIds[i] = nil
			end
		end
	end
	syncRootOrderIfDirty(root)
	panelIds = panelIds or CooldownPanels.GetCachedPanelIds(root)
	self:BeginRuntimeQueryBatch()
	for _, panelId in ipairs(panelIds) do
		self:EnsurePanelFrame(panelId)
	end
	for _, panelId in ipairs(panelIds) do
		self:ApplyPanelPosition(panelId)
	end
	for _, panelId in ipairs(panelIds) do
		self:RefreshPanel(panelId)
	end
	self:EndRuntimeQueryBatch()
	self:UpdateCursorAnchorState()
end

local function syncEditModeValue(panelId, field, value)
	local runtime = getRuntime(panelId)
	if not runtime or runtime.applyingFromEditMode then return end
	if runtime.editModeId and EditMode and EditMode.SetValue then EditMode:SetValue(runtime.editModeId, field, value, nil, true) end
end

function CooldownPanels:RefreshPanelForCurrentEditContext(panelId, refreshEditor)
	local runtime = getRuntime(panelId)
	if CooldownPanels:IsPanelLayoutEditActive(panelId) then
		if runtime then clearRuntimeLayoutShapeCache(runtime) end
		CooldownPanels:ApplyLayout(panelId)
		CooldownPanels:UpdateRuntimeIcons(panelId)
		CooldownPanels:UpdateVisibility(panelId)
	elseif CooldownPanels:IsInEditMode() then
		if runtime then clearRuntimeLayoutShapeCache(runtime) end
		CooldownPanels:ApplyLayout(panelId)
		CooldownPanels:UpdatePreviewIcons(panelId)
		CooldownPanels:UpdateVisibility(panelId)
	elseif CooldownPanels:IsEditorOpen() then
		if runtime then clearRuntimeLayoutShapeCache(runtime) end
		CooldownPanels:ApplyLayout(panelId)
		CooldownPanels:ApplyPanelPosition(panelId)
		CooldownPanels:UpdateVisibility(panelId)
	else
		CooldownPanels:RefreshPanel(panelId)
	end
	if refreshEditor and CooldownPanels:IsEditorOpen() then CooldownPanels:RefreshEditor() end
end

applyEditLayout = function(panelId, field, value, skipRefresh)
	local panel = CooldownPanels:GetPanel(panelId)
	if not panel then return end
	panel.layout = panel.layout or {}
	local layout = panel.layout
	local rowSizeIndex = field and field:match("^rowSize(%d+)$")

	if field == "iconSize" then
		layout.iconSize = Helper.ClampInt(value, 12, 128, layout.iconSize)
	elseif field == "spacing" then
		layout.spacing = Helper.ClampInt(value, 0, Helper.SPACING_RANGE or 200, layout.spacing)
	elseif field == "layoutMode" then
		layout.layoutMode = Helper.NormalizeLayoutMode(value, layout.layoutMode or Helper.PANEL_LAYOUT_DEFAULTS.layoutMode)
		Helper.InvalidateFixedLayoutCache(panel)
		if Helper.IsFixedLayout(layout) then
			local maxColumn, maxRow = Helper.EnsureFixedSlotAssignments(panel)
			if Helper.NormalizeFixedGridSize(layout.fixedGridColumns, 0) <= 0 then layout.fixedGridColumns = math.max(maxColumn or 0, 1) end
			if Helper.NormalizeFixedGridSize(layout.fixedGridRows, 0) <= 0 then layout.fixedGridRows = math.max(maxRow or 0, 1) end
		end
	elseif field == "fixedSlotCount" then
		local minimum = 0
		Helper.InvalidateFixedLayoutCache(panel)
		if Helper.IsFixedLayout(layout) then
			local maxColumn = Helper.EnsureFixedSlotAssignments(panel)
			minimum = maxColumn or 0
		end
		layout.fixedGridColumns = math.max(Helper.NormalizeFixedGridSize(value, layout.fixedGridColumns or Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0), minimum)
	elseif field == "fixedGridRows" then
		local minimum = 0
		Helper.InvalidateFixedLayoutCache(panel)
		if Helper.IsFixedLayout(layout) then
			local _, maxRow = Helper.EnsureFixedSlotAssignments(panel)
			minimum = maxRow or 0
		end
		layout.fixedGridRows = math.max(Helper.NormalizeFixedGridSize(value, layout.fixedGridRows or Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0), minimum)
	elseif field == "direction" then
		layout.direction = Helper.NormalizeDirection(value, layout.direction)
	elseif field == "wrapCount" then
		layout.wrapCount = Helper.ClampInt(value, 0, 40, layout.wrapCount)
		if Helper.IsFixedLayout(layout) then Helper.InvalidateFixedLayoutCache(panel) end
	elseif field == "wrapDirection" then
		layout.wrapDirection = Helper.NormalizeDirection(value, layout.wrapDirection)
	elseif field == "growthPoint" then
		layout.growthPoint = Helper.NormalizeGrowthPoint(value, layout.growthPoint or Helper.PANEL_LAYOUT_DEFAULTS.growthPoint)
	elseif field == "radialRadius" then
		layout.radialRadius = Helper.ClampInt(value, 0, Helper.RADIAL_RADIUS_RANGE or 600, layout.radialRadius or Helper.PANEL_LAYOUT_DEFAULTS.radialRadius)
	elseif field == "radialRotation" then
		layout.radialRotation =
			Helper.ClampNumber(value, -(Helper.RADIAL_ROTATION_RANGE or 360), Helper.RADIAL_ROTATION_RANGE or 360, layout.radialRotation or Helper.PANEL_LAYOUT_DEFAULTS.radialRotation)
	elseif field == "radialArcDegrees" then
		layout.radialArcDegrees =
			Helper.ClampInt(value, Helper.RADIAL_ARC_DEGREES_MIN or 15, Helper.RADIAL_ARC_DEGREES_MAX or 360, layout.radialArcDegrees or Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360)
	elseif field == "rangeOverlayEnabled" then
		layout.rangeOverlayEnabled = value == true
		if updateRangeCheckSpells then updateRangeCheckSpells() end
	elseif field == "rangeOverlayColor" then
		layout.rangeOverlayColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.rangeOverlayColor)
	elseif field == "procGlowEnabled" then
		layout.procGlowEnabled = value ~= false
	elseif field == "hideGlowOutOfCombat" then
		layout.hideGlowOutOfCombat = value == true
	elseif field == "procGlowStyle" then
		layout.procGlowStyle = Helper.NormalizeGlowStyle(value, layout.procGlowStyle or layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle)
	elseif field == "procGlowInset" then
		layout.procGlowInset = Helper.NormalizeGlowInset(value, layout.procGlowInset or layout.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0)
	elseif field == "readyGlowStyle" then
		layout.readyGlowStyle = Helper.NormalizeGlowStyle(value, layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle)
	elseif field == "pandemicGlowStyle" then
		layout.pandemicGlowStyle = Helper.NormalizeGlowStyle(value, layout.pandemicGlowStyle or layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle)
	elseif field == "readyGlowInset" then
		layout.readyGlowInset = Helper.NormalizeGlowInset(value, layout.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0)
	elseif field == "readyGlowColor" then
		layout.readyGlowColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
	elseif field == "pandemicGlowInset" then
		layout.pandemicGlowInset = Helper.NormalizeGlowInset(value, layout.pandemicGlowInset or layout.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0)
	elseif field == "pandemicGlowColor" then
		layout.pandemicGlowColor = Helper.NormalizeColor(value, layout.readyGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.pandemicGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
	elseif field == "readyGlowDuration" then
		layout.readyGlowDuration = 0
	elseif field == "readyGlowCheckPower" then
		layout.readyGlowCheckPower = value == true
		CooldownPanels:RebuildPowerIndex()
	elseif field == "noDesaturation" then
		layout.noDesaturation = value == true
	elseif field == "hideWhenNoResource" then
		layout.hideWhenNoResource = value == true
		CooldownPanels:RebuildPowerIndex()
	elseif field == "cdmAuraAlwaysShowMode" then
		layout.cdmAuraAlwaysShowMode = CooldownPanels:NormalizeCDMAuraAlwaysShowMode(value, layout.cdmAuraAlwaysShowMode or Helper.PANEL_LAYOUT_DEFAULTS.cdmAuraAlwaysShowMode)
	elseif field == "checkPower" then
		layout.checkPower = value == true
		CooldownPanels:RebuildPowerIndex()
	elseif field == "powerTintColor" then
		layout.powerTintColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.powerTintColor)
	elseif field == "strata" then
		layout.strata = Helper.NormalizeStrata(value, layout.strata)
	elseif field == "stackAnchor" then
		layout.stackAnchor = Helper.NormalizeAnchor(value, layout.stackAnchor or Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor)
	elseif field == "stackX" then
		layout.stackX = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.stackX or Helper.PANEL_LAYOUT_DEFAULTS.stackX)
	elseif field == "stackY" then
		layout.stackY = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.stackY or Helper.PANEL_LAYOUT_DEFAULTS.stackY)
	elseif field == "stackFont" then
		if type(value) == "string" and value ~= "" then layout.stackFont = value end
	elseif field == "stackFontSize" then
		layout.stackFontSize = Helper.ClampInt(value, 6, 64, layout.stackFontSize or Helper.PANEL_LAYOUT_DEFAULTS.stackFontSize)
	elseif field == "stackFontStyle" then
		layout.stackFontStyle = Helper.NormalizeFontStyleChoice(value, layout.stackFontStyle or Helper.PANEL_LAYOUT_DEFAULTS.stackFontStyle)
	elseif field == "stackColor" then
		layout.stackColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
	elseif field == "chargesAnchor" then
		layout.chargesAnchor = Helper.NormalizeAnchor(value, layout.chargesAnchor or Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor)
	elseif field == "chargesX" then
		layout.chargesX = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.chargesX or Helper.PANEL_LAYOUT_DEFAULTS.chargesX)
	elseif field == "chargesY" then
		layout.chargesY = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.chargesY or Helper.PANEL_LAYOUT_DEFAULTS.chargesY)
	elseif field == "chargesFont" then
		if type(value) == "string" and value ~= "" then layout.chargesFont = value end
	elseif field == "chargesFontSize" then
		layout.chargesFontSize = Helper.ClampInt(value, 6, 64, layout.chargesFontSize or Helper.PANEL_LAYOUT_DEFAULTS.chargesFontSize)
	elseif field == "chargesFontStyle" then
		layout.chargesFontStyle = Helper.NormalizeFontStyleChoice(value, layout.chargesFontStyle or Helper.PANEL_LAYOUT_DEFAULTS.chargesFontStyle)
	elseif field == "chargesColor" then
		layout.chargesColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
	elseif field == "chargesHideWhenZero" then
		layout.chargesHideWhenZero = value == true
	elseif field == "keybindsEnabled" then
		layout.keybindsEnabled = value == true
		Keybinds.MarkPanelsDirty()
	elseif field == "keybindsIgnoreItems" then
		layout.keybindsIgnoreItems = value == true
	elseif field == "keybindAnchor" then
		layout.keybindAnchor = Helper.NormalizeAnchor(value, layout.keybindAnchor or Helper.PANEL_LAYOUT_DEFAULTS.keybindAnchor)
	elseif field == "keybindX" then
		layout.keybindX = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.keybindX or Helper.PANEL_LAYOUT_DEFAULTS.keybindX)
	elseif field == "keybindY" then
		layout.keybindY = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.keybindY or Helper.PANEL_LAYOUT_DEFAULTS.keybindY)
	elseif field == "keybindFont" then
		if type(value) == "string" and value ~= "" then layout.keybindFont = value end
	elseif field == "keybindFontSize" then
		layout.keybindFontSize = Helper.ClampInt(value, 6, 64, layout.keybindFontSize or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize)
	elseif field == "keybindFontStyle" then
		layout.keybindFontStyle = Helper.NormalizeFontStyleChoice(value, layout.keybindFontStyle or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontStyle)
	elseif field == "cooldownDrawEdge" then
		layout.cooldownDrawEdge = value ~= false
	elseif field == "cooldownDrawBling" then
		layout.cooldownDrawBling = value ~= false
	elseif field == "cooldownDrawSwipe" then
		layout.cooldownDrawSwipe = value ~= false
	elseif field == "showChargesCooldown" then
		layout.showChargesCooldown = value == true
	elseif field == "cooldownGcdDrawEdge" then
		layout.cooldownGcdDrawEdge = value == true
	elseif field == "cooldownGcdDrawBling" then
		layout.cooldownGcdDrawBling = value == true
	elseif field == "cooldownGcdDrawSwipe" then
		layout.cooldownGcdDrawSwipe = value == true
	elseif field == "showTooltips" then
		layout.showTooltips = value == true
	elseif field == "showIconTexture" then
		layout.showIconTexture = value ~= false
	elseif field == "iconBorderEnabled" then
		layout.iconBorderEnabled = value == true
	elseif field == "iconBorderTexture" then
		layout.iconBorderTexture = normalizeIconBorderTexture(value, layout.iconBorderTexture or Helper.PANEL_LAYOUT_DEFAULTS.iconBorderTexture)
	elseif field == "iconBorderSize" then
		layout.iconBorderSize = Helper.ClampInt(value, 1, 64, layout.iconBorderSize or Helper.PANEL_LAYOUT_DEFAULTS.iconBorderSize)
	elseif field == "iconBorderOffset" then
		layout.iconBorderOffset = Helper.ClampInt(value, -64, 64, layout.iconBorderOffset or Helper.PANEL_LAYOUT_DEFAULTS.iconBorderOffset)
	elseif field == "iconBorderColor" then
		layout.iconBorderColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderColor)
	elseif field == "hideOnCooldown" then
		layout.hideOnCooldown = value == true
		if layout.hideOnCooldown then layout.showOnCooldown = false end
	elseif field == "showOnCooldown" then
		layout.showOnCooldown = value == true
		if layout.showOnCooldown then layout.hideOnCooldown = false end
	elseif field == "hideInVehicle" then
		layout.hideInVehicle = value == true
	elseif field == "hideInPetBattle" then
		layout.hideInPetBattle = value == true
	elseif field == "hideInClientScene" then
		layout.hideInClientScene = value == true
	elseif field == "visibility" then
		layout.visibility = PanelVisibility.NormalizeConfig(value)
	elseif field == "cooldownTextFont" then
		if type(value) == "string" and value ~= "" then layout.cooldownTextFont = value end
	elseif field == "cooldownTextSize" then
		layout.cooldownTextSize = Helper.ClampInt(value, 6, 64, layout.cooldownTextSize or 12)
	elseif field == "cooldownTextStyle" then
		layout.cooldownTextStyle = Helper.NormalizeFontStyleChoice(value, layout.cooldownTextStyle or Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextStyle)
	elseif field == "cooldownTextColor" then
		layout.cooldownTextColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)
	elseif field == "cooldownTextX" then
		layout.cooldownTextX = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.cooldownTextX or 0)
	elseif field == "cooldownTextY" then
		layout.cooldownTextY = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.cooldownTextY or 0)
	elseif field == "staticTextFont" then
		if type(value) == "string" then layout.staticTextFont = value end
	elseif field == "staticTextSize" then
		layout.staticTextSize = Helper.ClampInt(value, 6, 64, layout.staticTextSize or Helper.PANEL_LAYOUT_DEFAULTS.staticTextSize or 12)
	elseif field == "staticTextStyle" then
		layout.staticTextStyle = Helper.NormalizeFontStyleChoice(value, layout.staticTextStyle or Helper.PANEL_LAYOUT_DEFAULTS.staticTextStyle or "OUTLINE")
	elseif field == "staticTextColor" then
		layout.staticTextColor = Helper.NormalizeColor(value, Helper.PANEL_LAYOUT_DEFAULTS.staticTextColor or { 1, 1, 1, 1 })
	elseif field == "staticTextAnchor" then
		layout.staticTextAnchor = Helper.NormalizeAnchor(value, layout.staticTextAnchor or Helper.PANEL_LAYOUT_DEFAULTS.staticTextAnchor or "CENTER")
	elseif field == "staticTextX" then
		layout.staticTextX = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.staticTextX or Helper.PANEL_LAYOUT_DEFAULTS.staticTextX or 0)
	elseif field == "staticTextY" then
		layout.staticTextY = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, layout.staticTextY or Helper.PANEL_LAYOUT_DEFAULTS.staticTextY or 0)
	elseif field == "opacityOutOfCombat" then
		layout.opacityOutOfCombat = Helper.NormalizeOpacity(value, layout.opacityOutOfCombat or Helper.PANEL_LAYOUT_DEFAULTS.opacityOutOfCombat)
	elseif field == "opacityInCombat" then
		layout.opacityInCombat = Helper.NormalizeOpacity(value, layout.opacityInCombat or Helper.PANEL_LAYOUT_DEFAULTS.opacityInCombat)
	elseif rowSizeIndex then
		local index = tonumber(rowSizeIndex)
		local base = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
		local newSize = Helper.ClampInt(value, 12, 128, base)
		layout.rowSizes = layout.rowSizes or {}
		if newSize == base then
			layout.rowSizes[index] = nil
		else
			layout.rowSizes[index] = newSize
		end
		if not next(layout.rowSizes) then layout.rowSizes = nil end
	end

	if field == "iconSize" then CooldownPanels:ReskinMasque() end

	local syncValue = layout[field]
	if field == "visibility" then syncValue = PanelVisibility.CopySelectionMap(layout.visibility) end
	if rowSizeIndex then
		local base = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
		local idx = tonumber(rowSizeIndex)
		syncValue = (layout.rowSizes and layout.rowSizes[idx]) or base
	end
	if field == "fixedSlotCount" then syncValue = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0) end
	if field == "fixedGridRows" then syncValue = Helper.NormalizeFixedGridSize(layout.fixedGridRows, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0) end
	syncEditModeValue(panelId, field, syncValue)
	if field == "layoutMode" then
		syncEditModeValue(panelId, "fixedSlotCount", Helper.NormalizeFixedGridSize(layout.fixedGridColumns, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0))
		syncEditModeValue(panelId, "fixedGridRows", Helper.NormalizeFixedGridSize(layout.fixedGridRows, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0))
	end
	if field == "hideOnCooldown" and layout.hideOnCooldown then
		syncEditModeValue(panelId, "showOnCooldown", layout.showOnCooldown)
	elseif field == "showOnCooldown" and layout.showOnCooldown then
		syncEditModeValue(panelId, "hideOnCooldown", layout.hideOnCooldown)
	end
	if field == "iconSize" then
		local base = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
		for i = 1, 6 do
			if not layout.rowSizes or layout.rowSizes[i] == nil then syncEditModeValue(panelId, "rowSize" .. i, base) end
		end
	end
	if Helper.IsFixedLayout(layout) then CooldownPanels.BumpFixedGroupEffectiveLayoutVersion(panel) end

	if not skipRefresh then CooldownPanels:RefreshPanelForCurrentEditContext(panelId, false) end
	if field == "layoutMode" and not skipRefresh then refreshEditModeSettings() end
end

function CooldownPanels:ApplyEditMode(panelId, data)
	local panel = self:GetPanel(panelId)
	if not panel or type(data) ~= "table" then return end
	local runtime = getRuntime(panelId)
	runtime.applyingFromEditMode = true

	applyEditLayout(panelId, "iconSize", data.iconSize, true)
	applyEditLayout(panelId, "spacing", data.spacing, true)
	applyEditLayout(panelId, "layoutMode", data.layoutMode, true)
	applyEditLayout(panelId, "fixedSlotCount", data.fixedSlotCount, true)
	applyEditLayout(panelId, "fixedGridRows", data.fixedGridRows, true)
	applyEditLayout(panelId, "direction", data.direction, true)
	applyEditLayout(panelId, "wrapCount", data.wrapCount, true)
	applyEditLayout(panelId, "wrapDirection", data.wrapDirection, true)
	for i = 1, 6 do
		local key = "rowSize" .. i
		if data[key] ~= nil then applyEditLayout(panelId, key, data[key], true) end
	end
	applyEditLayout(panelId, "growthPoint", data.growthPoint, true)
	applyEditLayout(panelId, "radialRadius", data.radialRadius, true)
	applyEditLayout(panelId, "radialRotation", data.radialRotation, true)
	applyEditLayout(panelId, "radialArcDegrees", data.radialArcDegrees, true)
	applyEditLayout(panelId, "rangeOverlayEnabled", data.rangeOverlayEnabled, true)
	applyEditLayout(panelId, "rangeOverlayColor", data.rangeOverlayColor, true)
	applyEditLayout(panelId, "noDesaturation", data.noDesaturation, true)
	applyEditLayout(panelId, "cdmAuraAlwaysShowMode", data.cdmAuraAlwaysShowMode, true)
	applyEditLayout(panelId, "hideGlowOutOfCombat", data.hideGlowOutOfCombat, true)
	applyEditLayout(panelId, "readyGlowCheckPower", data.readyGlowCheckPower, true)
	applyEditLayout(panelId, "checkPower", data.checkPower, true)
	applyEditLayout(panelId, "hideWhenNoResource", data.hideWhenNoResource, true)
	applyEditLayout(panelId, "powerTintColor", data.powerTintColor, true)
	applyEditLayout(panelId, "strata", data.strata, true)
	applyEditLayout(panelId, "stackAnchor", data.stackAnchor, true)
	applyEditLayout(panelId, "stackX", data.stackX, true)
	applyEditLayout(panelId, "stackY", data.stackY, true)
	applyEditLayout(panelId, "stackFont", data.stackFont, true)
	applyEditLayout(panelId, "stackFontSize", data.stackFontSize, true)
	applyEditLayout(panelId, "stackFontStyle", data.stackFontStyle, true)
	applyEditLayout(panelId, "stackColor", data.stackColor, true)
	applyEditLayout(panelId, "chargesAnchor", data.chargesAnchor, true)
	applyEditLayout(panelId, "chargesX", data.chargesX, true)
	applyEditLayout(panelId, "chargesY", data.chargesY, true)
	applyEditLayout(panelId, "chargesFont", data.chargesFont, true)
	applyEditLayout(panelId, "chargesFontSize", data.chargesFontSize, true)
	applyEditLayout(panelId, "chargesFontStyle", data.chargesFontStyle, true)
	applyEditLayout(panelId, "chargesColor", data.chargesColor, true)
	applyEditLayout(panelId, "chargesHideWhenZero", data.chargesHideWhenZero, true)
	applyEditLayout(panelId, "keybindsEnabled", data.keybindsEnabled, true)
	applyEditLayout(panelId, "keybindsIgnoreItems", data.keybindsIgnoreItems, true)
	applyEditLayout(panelId, "keybindAnchor", data.keybindAnchor, true)
	applyEditLayout(panelId, "keybindX", data.keybindX, true)
	applyEditLayout(panelId, "keybindY", data.keybindY, true)
	applyEditLayout(panelId, "keybindFont", data.keybindFont, true)
	applyEditLayout(panelId, "keybindFontSize", data.keybindFontSize, true)
	applyEditLayout(panelId, "keybindFontStyle", data.keybindFontStyle, true)
	applyEditLayout(panelId, "cooldownDrawEdge", data.cooldownDrawEdge, true)
	applyEditLayout(panelId, "cooldownDrawBling", data.cooldownDrawBling, true)
	applyEditLayout(panelId, "cooldownDrawSwipe", data.cooldownDrawSwipe, true)
	applyEditLayout(panelId, "showChargesCooldown", data.showChargesCooldown, true)
	applyEditLayout(panelId, "cooldownGcdDrawEdge", data.cooldownGcdDrawEdge, true)
	applyEditLayout(panelId, "cooldownGcdDrawBling", data.cooldownGcdDrawBling, true)
	applyEditLayout(panelId, "cooldownGcdDrawSwipe", data.cooldownGcdDrawSwipe, true)
	applyEditLayout(panelId, "showTooltips", data.showTooltips, true)
	applyEditLayout(panelId, "showIconTexture", data.showIconTexture, true)
	applyEditLayout(panelId, "iconBorderEnabled", data.iconBorderEnabled, true)
	applyEditLayout(panelId, "iconBorderTexture", data.iconBorderTexture, true)
	applyEditLayout(panelId, "iconBorderSize", data.iconBorderSize, true)
	applyEditLayout(panelId, "iconBorderOffset", data.iconBorderOffset, true)
	applyEditLayout(panelId, "iconBorderColor", data.iconBorderColor, true)
	applyEditLayout(panelId, "hideOnCooldown", data.hideOnCooldown, true)
	applyEditLayout(panelId, "showOnCooldown", data.showOnCooldown, true)
	applyEditLayout(panelId, "hideInVehicle", data.hideInVehicle, true)
	applyEditLayout(panelId, "hideInPetBattle", data.hideInPetBattle, true)
	applyEditLayout(panelId, "hideInClientScene", data.hideInClientScene, true)
	applyEditLayout(panelId, "visibility", data.visibility, true)
	applyEditLayout(panelId, "cooldownTextFont", data.cooldownTextFont, true)
	applyEditLayout(panelId, "cooldownTextSize", data.cooldownTextSize, true)
	applyEditLayout(panelId, "cooldownTextStyle", data.cooldownTextStyle, true)
	applyEditLayout(panelId, "cooldownTextColor", data.cooldownTextColor, true)
	applyEditLayout(panelId, "cooldownTextX", data.cooldownTextX, true)
	applyEditLayout(panelId, "cooldownTextY", data.cooldownTextY, true)
	applyEditLayout(panelId, "opacityOutOfCombat", data.opacityOutOfCombat, true)
	applyEditLayout(panelId, "opacityInCombat", data.opacityInCombat, true)

	runtime.applyingFromEditMode = nil
	self:RefreshPanelForCurrentEditContext(panelId, true)
end

local function getCopySettingsEntries(panelKey)
	local root = CooldownPanels:GetRoot()
	if not root or not root.panels then return {} end
	local entries = {}
	local seen = {}
	if type(root.order) == "table" then
		for _, id in ipairs(root.order) do
			local otherId = normalizeId(id)
			if otherId ~= panelKey then
				local other = root.panels[otherId]
				if other then
					local label = string.format("Panel %s: %s", tostring(otherId), other.name or "Cooldown Panel")
					entries[#entries + 1] = { id = otherId, label = label }
					seen[otherId] = true
				end
			end
		end
	end
	for id, other in pairs(root.panels) do
		local otherId = normalizeId(id)
		if other and otherId ~= panelKey and not seen[otherId] then
			local label = string.format("Panel %s: %s", tostring(otherId), other.name or "Cooldown Panel")
			entries[#entries + 1] = { id = otherId, label = label }
		end
	end
	return entries
end

function CooldownPanels:RegisterEditModePanel(panelId)
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local runtime = getRuntime(panelId)
	if runtime.editModeRegistered then
		refreshEditModePanelFrame(panelId, runtime.editModeId)
		return
	end
	if not EditMode or not EditMode.RegisterFrame then return end

	local frame = self:EnsurePanelFrame(panelId)
	if not frame then return end

	local editModeId = "cooldownPanel:" .. tostring(panelId)
	runtime.editModeId = editModeId

	panel.layout = panel.layout or Helper.CopyTableShallow(Helper.PANEL_LAYOUT_DEFAULTS)
	local layout = panel.layout
	local baseIconSize = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
	local anchor = ensurePanelAnchor(panel)
	local panelKey = normalizeId(panelId)
	local countFontPath, countFontSize, countFontStyle = Helper.GetCountFontDefaults(frame)
	local chargesFontPath, chargesFontSize, chargesFontStyle = Helper.GetChargesFontDefaults(frame)
	local function fontOptions() return Helper.GetFontOptions(countFontPath) end
	local function chargesFontOptions() return Helper.GetFontOptions(chargesFontPath) end
	local function hasStaticTextEntries() return panel and panel.entries and next(panel.entries) ~= nil end
	local function hasCDMAuraEntries()
		if not (panel and panel.entries) then return false end
		for _, entry in pairs(panel.entries) do
			if entry and entry.type == "CDM_AURA" then return true end
		end
		return false
	end
	local function setStaticTextEntryId(entryId)
		local runtimePanel = getRuntime(panelId)
		if runtimePanel then runtimePanel.editModeEntryId = normalizeId(entryId) end
	end
	local function getStaticTextEntryId()
		if not hasStaticTextEntries() then return nil end
		local editor = getEditor()
		if editor and editor.selectedPanelId == panelId then
			local selected = normalizeId(editor.selectedEntryId)
			if selected and panel.entries and panel.entries[selected] then
				setStaticTextEntryId(selected)
				return selected
			end
		end
		local runtimePanel = getRuntime(panelId)
		local entryId = normalizeId(runtimePanel and runtimePanel.editModeEntryId)
		if entryId and panel.entries and panel.entries[entryId] then return entryId end
		local order = panel.order or {}
		for _, id in ipairs(order) do
			if panel.entries and panel.entries[id] then
				setStaticTextEntryId(id)
				return id
			end
		end
		for id in pairs(panel.entries) do
			if panel.entries[id] then
				setStaticTextEntryId(id)
				return id
			end
		end
		return nil
	end
	local function getStaticTextEntry()
		local entryId = getStaticTextEntryId()
		return entryId and panel.entries and panel.entries[entryId] or nil, entryId
	end
	local staticTextSharedFields = {
		staticTextFont = true,
		staticTextSize = true,
		staticTextStyle = true,
		staticTextColor = true,
		staticTextAnchor = true,
		staticTextX = true,
		staticTextY = true,
	}
	local function updateStaticTextEntry(entry, field, value)
		if not entry then return end
		local changed = false
		if staticTextSharedFields[field] then
			for _, other in pairs(panel.entries or {}) do
				if other then
					if other.staticTextUseGlobal ~= false then
						other.staticTextUseGlobal = false
						changed = true
					end
					if other[field] ~= value then
						other[field] = value
						changed = true
					end
				end
			end
		else
			if entry[field] == value then return end
			entry[field] = value
			changed = true
		end
		if not changed then return end
		CooldownPanels:RefreshPanel(panelId)
		CooldownPanels:RefreshEditor()
	end
	local function ensureAnchorTable() return ensurePanelAnchor(panel) end
	local function syncPanelPositionFromAnchor()
		local a = ensureAnchorTable()
		if not a then return end
		panel.point = a.point or panel.point or "CENTER"
		panel.x = a.x or panel.x or 0
		panel.y = a.y or panel.y or 0
	end
	local function syncEditModeLayoutFromAnchor() CooldownPanels:SyncEditModeDataFromPanel(panelId, editModeId) end
	local function applyAnchorPosition(skipFrameRefresh, skipSettingValuesRefresh)
		syncPanelPositionFromAnchor()
		syncEditModeLayoutFromAnchor()
		CooldownPanels:ApplyPanelPosition(panelId)
		CooldownPanels:UpdateVisibility(panelId)
		if skipFrameRefresh ~= true then refreshEditModePanelFrame(panelId, editModeId) end
		if skipSettingValuesRefresh ~= true then refreshEditModeSettingValues() end
	end
	local function applyAnchorDefaults(a, target)
		if not a then return end
		if target == "UIParent" then
			a.point = "CENTER"
			a.relativePoint = "CENTER"
			a.x = 0
			a.y = 0
		else
			a.point = "TOPLEFT"
			a.relativePoint = "BOTTOMLEFT"
			a.x = 0
			a.y = 0
		end
	end
	local function getRowSizeValue(index)
		local base = Helper.ClampInt(layout.iconSize, 12, 128, Helper.PANEL_LAYOUT_DEFAULTS.iconSize)
		local rowSizes = layout.rowSizes
		local value = rowSizes and tonumber(rowSizes[index]) or nil
		return Helper.ClampInt(value, 12, 128, base)
	end
	local function isRadialLayout() return Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) == "RADIAL" end
	local function isFixedLayout() return Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) == "FIXED" end
	local function shouldShowRowSize(index)
		if isRadialLayout() then return false end
		local rows, primaryHorizontal = getPanelRowCount(panel, layout)
		return primaryHorizontal and rows >= index
	end
	local visibilityRuleOptions = PanelVisibility.GetRuleOptions()
	local settings
	if SettingType then
		settings = {
			{
				name = L["CooldownPanelCopySettingsHeader"] or "Copy Settings",
				kind = SettingType.Collapsible,
				id = "cooldownPanelCopySettings",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelCopySettings"] or "Copy Settings",
				kind = SettingType.Dropdown,
				field = "copySettingsFrom",
				parentId = "cooldownPanelCopySettings",
				height = 140,
				get = function() return nil end,
				set = function() end,
				generator = function(_, root)
					local entries = getCopySettingsEntries(panelKey)
					if not entries or #entries == 0 then
						if root.CreateTitle then root:CreateTitle(L["CooldownPanelCopySettingsNone"] or "No other panels") end
						return
					end
					for _, entry in ipairs(entries) do
						root:CreateRadio(entry.label, function() return false end, function()
							ensureCopyPopup()
							StaticPopup_Show("EQOL_COOLDOWN_PANEL_COPY_SETTINGS", entry.label, nil, { targetPanelId = panelId, sourcePanelId = entry.id })
						end)
					end
				end,
			},
			{
				name = "Anchor",
				kind = SettingType.Collapsible,
				id = "cooldownPanelAnchor",
				defaultCollapsed = false,
			},
			{
				name = "Relative frame",
				kind = SettingType.Dropdown,
				field = "anchorRelativeFrame",
				parentId = "cooldownPanelAnchor",
				height = 200,
				get = function() return CooldownPanels.ValidateRelativeFrameChoice(panel, panelKey, runtime) end,
				set = function(_, value)
					local a = ensureAnchorTable()
					if not a then return end
					local target = Helper.NormalizeRelativeFrameName(value)
					local cache = CooldownPanels.GetRelativeFrameCache(runtime, panel, panelKey)
					if not (cache.valid and cache.valid[target]) then target = "UIParent" end
					if target == FAKE_CURSOR_FRAME_NAME then
						CooldownPanels:AttachFakeCursor(panelId)
						return
					end
					if a.relativeFrame ~= target then CooldownPanels.MarkRelativeFrameEntriesDirty() end
					a.relativeFrame = target
					applyAnchorDefaults(a, target)
					applyAnchorPosition()
					CooldownPanels:UpdateCursorAnchorState()
					local anchorHelper = CooldownPanels.AnchorHelper
					if anchorHelper and anchorHelper.MaybeScheduleRefresh then anchorHelper:MaybeScheduleRefresh(target) end
				end,
				generator = function(_, root)
					local entries = CooldownPanels.GetRelativeFrameCache(runtime, panel, panelKey).entries
					local current = CooldownPanels.ValidateRelativeFrameChoice(panel, panelKey, runtime)
					for _, entry in ipairs(entries) do
						root:CreateRadio(entry.label, function() return current == entry.key end, function()
							local a = ensureAnchorTable()
							if not a then return end
							local target = entry.key
							local cache = CooldownPanels.GetRelativeFrameCache(runtime, panel, panelKey)
							if not (cache.valid and cache.valid[target]) then target = "UIParent" end
							if target == FAKE_CURSOR_FRAME_NAME then
								CooldownPanels:AttachFakeCursor(panelId)
								return
							end
							if a.relativeFrame ~= target then CooldownPanels.MarkRelativeFrameEntriesDirty() end
							a.relativeFrame = target
							applyAnchorDefaults(a, target)
							applyAnchorPosition()
							CooldownPanels:UpdateCursorAnchorState()
							local anchorHelper = CooldownPanels.AnchorHelper
							if anchorHelper and anchorHelper.MaybeScheduleRefresh then anchorHelper:MaybeScheduleRefresh(target) end
						end)
					end
				end,
				default = "UIParent",
			},
			{
				name = "Anchor point",
				kind = SettingType.Dropdown,
				field = "anchorPoint",
				parentId = "cooldownPanelAnchor",
				height = 160,
				get = function()
					local a = ensureAnchorTable()
					return Helper.NormalizeAnchor(a and a.point, "CENTER")
				end,
				set = function(_, value)
					local a = ensureAnchorTable()
					if not a then return end
					a.point = Helper.NormalizeAnchor(value, a.point or "CENTER")
					if not a.relativePoint then a.relativePoint = a.point end
					applyAnchorPosition(true, true)
				end,
				generator = function(_, root)
					for _, option in ipairs(Helper.AnchorOptions) do
						root:CreateRadio(option.label, function()
							local a = ensureAnchorTable()
							return Helper.NormalizeAnchor(a and a.point, "CENTER") == option.value
						end, function()
							local a = ensureAnchorTable()
							if not a then return end
							a.point = option.value
							if not a.relativePoint then a.relativePoint = option.value end
							applyAnchorPosition(true, true)
						end)
					end
				end,
			},
			{
				name = "Relative point",
				kind = SettingType.Dropdown,
				field = "anchorRelativePoint",
				parentId = "cooldownPanelAnchor",
				height = 160,
				get = function()
					local a = ensureAnchorTable()
					return Helper.NormalizeAnchor(a and a.relativePoint, a and a.point or "CENTER")
				end,
				set = function(_, value)
					local a = ensureAnchorTable()
					if not a then return end
					a.relativePoint = Helper.NormalizeAnchor(value, a.relativePoint or "CENTER")
					applyAnchorPosition(true, true)
				end,
				generator = function(_, root)
					for _, option in ipairs(Helper.AnchorOptions) do
						root:CreateRadio(option.label, function()
							local a = ensureAnchorTable()
							return Helper.NormalizeAnchor(a and a.relativePoint, a and a.point or "CENTER") == option.value
						end, function()
							local a = ensureAnchorTable()
							if not a then return end
							a.relativePoint = option.value
							applyAnchorPosition(true, true)
						end)
					end
				end,
			},
			{
				name = "X Offset",
				kind = SettingType.Slider,
				allowInput = true,
				field = "anchorOffsetX",
				parentId = "cooldownPanelAnchor",
				minValue = -1000,
				maxValue = 1000,
				valueStep = 1,
				get = function()
					local a = ensureAnchorTable()
					return a and a.x or 0
				end,
				set = function(_, value)
					local a = ensureAnchorTable()
					if not a then return end
					local new = tonumber(value) or 0
					if a.x == new then return end
					a.x = new
					applyAnchorPosition(true, true)
				end,
				default = 0,
			},
			{
				name = "Y Offset",
				kind = SettingType.Slider,
				allowInput = true,
				field = "anchorOffsetY",
				parentId = "cooldownPanelAnchor",
				minValue = -1000,
				maxValue = 1000,
				valueStep = 1,
				get = function()
					local a = ensureAnchorTable()
					return a and a.y or 0
				end,
				set = function(_, value)
					local a = ensureAnchorTable()
					if not a then return end
					local new = tonumber(value) or 0
					if a.y == new then return end
					a.y = new
					applyAnchorPosition(true, true)
				end,
				default = 0,
			},
			{
				name = L["CooldownPanelLayoutHeader"] or "Layout",
				kind = SettingType.Collapsible,
				id = "cooldownPanelLayout",
				defaultCollapsed = false,
			},
			{
				name = L["CooldownPanelLayoutMode"] or "Layout mode",
				kind = SettingType.Dropdown,
				field = "layoutMode",
				parentId = "cooldownPanelLayout",
				height = 80,
				get = function() return Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) end,
				set = function(_, value) applyEditLayout(panelId, "layoutMode", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.LayoutModeOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode) == option.value end,
							function() applyEditLayout(panelId, "layoutMode", option.value) end
						)
					end
				end,
			},
			{
				name = "Icon size",
				kind = SettingType.Slider,
				field = "iconSize",
				parentId = "cooldownPanelLayout",
				default = layout.iconSize,
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				get = function() return layout.iconSize end,
				set = function(_, value) applyEditLayout(panelId, "iconSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = "Spacing",
				kind = SettingType.Slider,
				field = "spacing",
				parentId = "cooldownPanelLayout",
				default = layout.spacing,
				minValue = 0,
				maxValue = Helper.SPACING_RANGE or 200,
				valueStep = 1,
				allowInput = true,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return isRadialLayout() end,
				get = function() return Helper.ClampInt(layout.spacing, 0, Helper.SPACING_RANGE or 200, Helper.PANEL_LAYOUT_DEFAULTS.spacing) end,
				set = function(_, value) applyEditLayout(panelId, "spacing", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = "Direction",
				kind = SettingType.Dropdown,
				field = "direction",
				parentId = "cooldownPanelLayout",
				height = 120,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return isRadialLayout() end,
				get = function() return Helper.NormalizeDirection(layout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction) end,
				set = function(_, value) applyEditLayout(panelId, "direction", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.DirectionOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeDirection(layout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction) == option.value end,
							function() applyEditLayout(panelId, "direction", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelFixedSlotCount"] or "Fixed slots",
				kind = SettingType.Slider,
				field = "fixedSlotCount",
				parentId = "cooldownPanelLayout",
				default = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0),
				minValue = 0,
				maxValue = 40,
				valueStep = 1,
				allowInput = true,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return not isFixedLayout() end,
				get = function() return Helper.NormalizeFixedGridSize(layout.fixedGridColumns, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0) end,
				set = function(_, value) applyEditLayout(panelId, "fixedSlotCount", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelFixedGridRows"] or "Grid rows",
				kind = SettingType.Slider,
				field = "fixedGridRows",
				parentId = "cooldownPanelLayout",
				default = Helper.NormalizeFixedGridSize(layout.fixedGridRows, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0),
				minValue = 0,
				maxValue = 40,
				valueStep = 1,
				allowInput = true,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return not isFixedLayout() end,
				get = function() return Helper.NormalizeFixedGridSize(layout.fixedGridRows, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0) end,
				set = function(_, value) applyEditLayout(panelId, "fixedGridRows", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = "Wrap",
				kind = SettingType.Slider,
				field = "wrapCount",
				parentId = "cooldownPanelLayout",
				default = layout.wrapCount or 0,
				minValue = 0,
				maxValue = 40,
				valueStep = 1,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return isRadialLayout() end,
				get = function() return layout.wrapCount or 0 end,
				set = function(_, value) applyEditLayout(panelId, "wrapCount", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = "Wrap direction",
				kind = SettingType.Dropdown,
				field = "wrapDirection",
				parentId = "cooldownPanelLayout",
				height = 120,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return isRadialLayout() or (layout.wrapCount or 0) == 0 end,
				get = function() return Helper.NormalizeDirection(layout.wrapDirection, Helper.PANEL_LAYOUT_DEFAULTS.wrapDirection or "DOWN") end,
				set = function(_, value) applyEditLayout(panelId, "wrapDirection", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.DirectionOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeDirection(layout.wrapDirection, Helper.PANEL_LAYOUT_DEFAULTS.wrapDirection or "DOWN") == option.value end,
							function() applyEditLayout(panelId, "wrapDirection", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelGrowthPoint"] or "Growth point",
				kind = SettingType.Dropdown,
				field = "growthPoint",
				parentId = "cooldownPanelLayout",
				height = 90,
				isShown = function() return not isRadialLayout() end,
				disabled = function() return isRadialLayout() or (layout.wrapCount or 0) == 0 end,
				get = function() return Helper.NormalizeGrowthPoint(layout.growthPoint, Helper.PANEL_LAYOUT_DEFAULTS.growthPoint) end,
				set = function(_, value) applyEditLayout(panelId, "growthPoint", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.GrowthPointOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeGrowthPoint(layout.growthPoint, Helper.PANEL_LAYOUT_DEFAULTS.growthPoint) == option.value end,
							function() applyEditLayout(panelId, "growthPoint", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelRadialRadius"] or "Radius",
				kind = SettingType.Slider,
				field = "radialRadius",
				parentId = "cooldownPanelLayout",
				default = layout.radialRadius or Helper.PANEL_LAYOUT_DEFAULTS.radialRadius,
				minValue = 0,
				maxValue = Helper.RADIAL_RADIUS_RANGE or 600,
				valueStep = 1,
				allowInput = true,
				isShown = function() return isRadialLayout() end,
				disabled = function() return not isRadialLayout() end,
				get = function() return layout.radialRadius or Helper.PANEL_LAYOUT_DEFAULTS.radialRadius end,
				set = function(_, value) applyEditLayout(panelId, "radialRadius", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelRadialRotation"] or "Rotation",
				kind = SettingType.Slider,
				field = "radialRotation",
				parentId = "cooldownPanelLayout",
				default = layout.radialRotation or Helper.PANEL_LAYOUT_DEFAULTS.radialRotation,
				minValue = -(Helper.RADIAL_ROTATION_RANGE or 360),
				maxValue = Helper.RADIAL_ROTATION_RANGE or 360,
				valueStep = 1,
				allowInput = true,
				isShown = function() return isRadialLayout() end,
				disabled = function() return not isRadialLayout() end,
				get = function() return layout.radialRotation or Helper.PANEL_LAYOUT_DEFAULTS.radialRotation end,
				set = function(_, value) applyEditLayout(panelId, "radialRotation", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelRadialArcDegrees"] or "Arc degrees",
				kind = SettingType.Slider,
				field = "radialArcDegrees",
				parentId = "cooldownPanelLayout",
				default = layout.radialArcDegrees or Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360,
				minValue = Helper.RADIAL_ARC_DEGREES_MIN or 15,
				maxValue = Helper.RADIAL_ARC_DEGREES_MAX or 360,
				valueStep = 1,
				allowInput = true,
				isShown = function() return isRadialLayout() end,
				disabled = function() return not isRadialLayout() end,
				get = function() return layout.radialArcDegrees or Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360 end,
				set = function(_, value) applyEditLayout(panelId, "radialArcDegrees", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = "Strata",
				kind = SettingType.Dropdown,
				field = "strata",
				parentId = "cooldownPanelLayout",
				height = 200,
				get = function() return Helper.NormalizeStrata(layout.strata, Helper.PANEL_LAYOUT_DEFAULTS.strata) end,
				set = function(_, value) applyEditLayout(panelId, "strata", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.STRATA_ORDER) do
						root:CreateRadio(
							option,
							function() return Helper.NormalizeStrata(layout.strata, Helper.PANEL_LAYOUT_DEFAULTS.strata) == option end,
							function() applyEditLayout(panelId, "strata", option) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelRowSizesHeader"] or "Row sizes",
				kind = SettingType.Collapsible,
				id = "cooldownPanelRowSizes",
				parentId = "cooldownPanelLayout",
				defaultCollapsed = true,
				isShown = function() return not isRadialLayout() end,
			},
			{
				name = (L["CooldownPanelRowSize"] or "Row %d size"):format(1),
				kind = SettingType.Slider,
				field = "rowSize1",
				parentId = "cooldownPanelRowSizes",
				default = getRowSizeValue(1),
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return getRowSizeValue(1) end,
				set = function(_, value) applyEditLayout(panelId, "rowSize1", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isShown = function() return shouldShowRowSize(1) end,
			},
			{
				name = (L["CooldownPanelRowSize"] or "Row %d size"):format(2),
				kind = SettingType.Slider,
				field = "rowSize2",
				parentId = "cooldownPanelRowSizes",
				default = getRowSizeValue(2),
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return getRowSizeValue(2) end,
				set = function(_, value) applyEditLayout(panelId, "rowSize2", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isShown = function() return shouldShowRowSize(2) end,
			},
			{
				name = (L["CooldownPanelRowSize"] or "Row %d size"):format(3),
				kind = SettingType.Slider,
				field = "rowSize3",
				parentId = "cooldownPanelRowSizes",
				default = getRowSizeValue(3),
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return getRowSizeValue(3) end,
				set = function(_, value) applyEditLayout(panelId, "rowSize3", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isShown = function() return shouldShowRowSize(3) end,
			},
			{
				name = (L["CooldownPanelRowSize"] or "Row %d size"):format(4),
				kind = SettingType.Slider,
				field = "rowSize4",
				parentId = "cooldownPanelRowSizes",
				default = getRowSizeValue(4),
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return getRowSizeValue(4) end,
				set = function(_, value) applyEditLayout(panelId, "rowSize4", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isShown = function() return shouldShowRowSize(4) end,
			},
			{
				name = (L["CooldownPanelRowSize"] or "Row %d size"):format(5),
				kind = SettingType.Slider,
				field = "rowSize5",
				parentId = "cooldownPanelRowSizes",
				default = getRowSizeValue(5),
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return getRowSizeValue(5) end,
				set = function(_, value) applyEditLayout(panelId, "rowSize5", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isShown = function() return shouldShowRowSize(5) end,
			},
			{
				name = (L["CooldownPanelRowSize"] or "Row %d size"):format(6),
				kind = SettingType.Slider,
				field = "rowSize6",
				parentId = "cooldownPanelRowSizes",
				default = getRowSizeValue(6),
				minValue = 12,
				maxValue = 128,
				valueStep = 1,
				allowInput = true,
				get = function() return getRowSizeValue(6) end,
				set = function(_, value) applyEditLayout(panelId, "rowSize6", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
				isShown = function() return shouldShowRowSize(6) end,
			},
			{
				name = L["CooldownPanelDisplayHeader"] or "Display",
				kind = SettingType.Collapsible,
				id = "cooldownPanelDisplay",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelShowTooltips"] or "Show tooltips",
				kind = SettingType.Checkbox,
				field = "showTooltips",
				parentId = "cooldownPanelDisplay",
				default = layout.showTooltips == true,
				get = function() return layout.showTooltips == true end,
				set = function(_, value) applyEditLayout(panelId, "showTooltips", value) end,
			},
			{
				name = L["CooldownPanelShowIconTexture"] or "Show icon texture",
				kind = SettingType.Checkbox,
				field = "showIconTexture",
				parentId = "cooldownPanelDisplay",
				default = layout.showIconTexture ~= false,
				get = function() return layout.showIconTexture ~= false end,
				set = function(_, value) applyEditLayout(panelId, "showIconTexture", value) end,
			},
			{
				name = "Icon border",
				kind = SettingType.CheckboxColor,
				field = "iconBorderEnabled",
				parentId = "cooldownPanelDisplay",
				default = layout.iconBorderEnabled == true,
				get = function() return layout.iconBorderEnabled == true end,
				set = function(_, value) applyEditLayout(panelId, "iconBorderEnabled", value) end,
				colorDefault = Helper.NormalizeColor(layout.iconBorderColor, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderColor),
				colorGet = function() return layout.iconBorderColor or Helper.PANEL_LAYOUT_DEFAULTS.iconBorderColor end,
				colorSet = function(_, value) applyEditLayout(panelId, "iconBorderColor", value) end,
				hasOpacity = true,
			},
			{
				name = L["Border texture"] or "Border texture",
				kind = SettingType.Dropdown,
				field = "iconBorderTexture",
				parentId = "cooldownPanelDisplay",
				height = 180,
				disabled = function() return layout.iconBorderEnabled ~= true end,
				default = normalizeIconBorderTexture(layout.iconBorderTexture, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderTexture),
				get = function() return normalizeIconBorderTexture(layout.iconBorderTexture, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderTexture) end,
				set = function(_, value) applyEditLayout(panelId, "iconBorderTexture", value) end,
				generator = function(_, root)
					for _, option in ipairs(iconBorderOptions()) do
						root:CreateRadio(
							option.label,
							function() return normalizeIconBorderTexture(layout.iconBorderTexture, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderTexture) == option.value end,
							function() applyEditLayout(panelId, "iconBorderTexture", option.value) end
						)
					end
				end,
			},
			{
				name = L["Border size"] or "Border size",
				kind = SettingType.Slider,
				field = "iconBorderSize",
				parentId = "cooldownPanelDisplay",
				default = Helper.ClampInt(layout.iconBorderSize, 1, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderSize),
				minValue = 1,
				maxValue = 64,
				valueStep = 1,
				allowInput = true,
				disabled = function() return layout.iconBorderEnabled ~= true end,
				get = function() return Helper.ClampInt(layout.iconBorderSize, 1, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderSize) end,
				set = function(_, value) applyEditLayout(panelId, "iconBorderSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["Border offset"] or "Border offset",
				kind = SettingType.Slider,
				field = "iconBorderOffset",
				parentId = "cooldownPanelDisplay",
				default = Helper.ClampInt(layout.iconBorderOffset, -64, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderOffset),
				minValue = -64,
				maxValue = 64,
				valueStep = 1,
				allowInput = true,
				disabled = function() return layout.iconBorderEnabled ~= true end,
				get = function() return Helper.ClampInt(layout.iconBorderOffset, -64, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderOffset) end,
				set = function(_, value) applyEditLayout(panelId, "iconBorderOffset", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelHideOnCooldown"] or "Hide on cooldown",
				kind = SettingType.Checkbox,
				field = "hideOnCooldown",
				parentId = "cooldownPanelDisplay",
				default = layout.hideOnCooldown == true,
				get = function() return layout.hideOnCooldown == true end,
				set = function(_, value) applyEditLayout(panelId, "hideOnCooldown", value) end,
			},
			{
				name = L["CooldownPanelShowOnCooldown"] or "Show on cooldown",
				kind = SettingType.Checkbox,
				field = "showOnCooldown",
				parentId = "cooldownPanelDisplay",
				default = layout.showOnCooldown == true,
				get = function() return layout.showOnCooldown == true end,
				set = function(_, value) applyEditLayout(panelId, "showOnCooldown", value) end,
			},
			{
				name = L["CooldownPanelCDMAuraAlwaysShowMode"] or "Tracked aura display",
				kind = SettingType.Dropdown,
				field = "cdmAuraAlwaysShowMode",
				parentId = "cooldownPanelDisplay",
				height = 180,
				isShown = function() return hasCDMAuraEntries() end,
				default = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, nil),
				get = function() return CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, nil) end,
				set = function(_, value) applyEditLayout(panelId, "cdmAuraAlwaysShowMode", value) end,
				generator = function(_, root)
					for _, option in ipairs(CooldownPanels:GetCDMAuraAlwaysShowOptions()) do
						root:CreateRadio(
							option.label,
							function() return CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, nil) == option.value end,
							function() applyEditLayout(panelId, "cdmAuraAlwaysShowMode", option.value) end
						)
					end
				end,
			},
			{
				name = L["Show when"] or "Show when",
				kind = SettingType.MultiDropdown,
				field = "visibility",
				parentId = "cooldownPanelDisplay",
				height = 220,
				values = visibilityRuleOptions,
				hideSummary = true,
				default = PanelVisibility.CopySelectionMap(PanelVisibility.NormalizeConfig(layout.visibility)),
				isSelected = function(_, value)
					local cfg = PanelVisibility.NormalizeConfig(layout.visibility)
					return cfg and cfg[value] == true or false
				end,
				setSelected = function(_, value, state)
					local cfg = PanelVisibility.NormalizeConfig(layout.visibility) or {}
					if value == "ALWAYS_HIDDEN" and state then
						cfg = { ALWAYS_HIDDEN = true }
					elseif state then
						cfg[value] = true
						cfg.ALWAYS_HIDDEN = nil
					else
						cfg[value] = nil
					end
					if not next(cfg) then cfg = nil end
					applyEditLayout(panelId, "visibility", cfg)
				end,
				isShown = function() return visibilityRuleOptions and #visibilityRuleOptions > 0 end,
				isEnabled = function() return visibilityRuleOptions and #visibilityRuleOptions > 0 end,
			},
			{
				name = L["CooldownPanelHideInVehicle"] or "Hide in vehicles",
				kind = SettingType.Checkbox,
				field = "hideInVehicle",
				parentId = "cooldownPanelDisplay",
				default = layout.hideInVehicle == true,
				get = function() return layout.hideInVehicle == true end,
				set = function(_, value) applyEditLayout(panelId, "hideInVehicle", value) end,
			},
			{
				name = L["CooldownPanelHideInPetBattle"] or "Hide in pet battles",
				kind = SettingType.Checkbox,
				field = "hideInPetBattle",
				parentId = "cooldownPanelDisplay",
				default = layout.hideInPetBattle == true,
				get = function() return layout.hideInPetBattle == true end,
				set = function(_, value) applyEditLayout(panelId, "hideInPetBattle", value) end,
			},
			{
				name = L["CooldownPanelHideInClientScene"] or "Hide in client scenes",
				kind = SettingType.Checkbox,
				field = "hideInClientScene",
				parentId = "cooldownPanelDisplay",
				default = layout.hideInClientScene ~= false,
				get = function() return layout.hideInClientScene ~= false end,
				set = function(_, value) applyEditLayout(panelId, "hideInClientScene", value) end,
			},
			{
				name = L["CooldownPanelOpacityOutOfCombat"] or "Opacity (out of combat)",
				kind = SettingType.Slider,
				field = "opacityOutOfCombat",
				parentId = "cooldownPanelDisplay",
				default = Helper.NormalizeOpacity(layout.opacityOutOfCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityOutOfCombat),
				minValue = 0,
				maxValue = 1,
				valueStep = 0.05,
				allowInput = true,
				get = function() return Helper.NormalizeOpacity(layout.opacityOutOfCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityOutOfCombat) end,
				set = function(_, value) applyEditLayout(panelId, "opacityOutOfCombat", value) end,
				formatter = function(value)
					local num = tonumber(value) or 0
					return tostring(math.floor((num * 100) + 0.5)) .. "%"
				end,
			},
			{
				name = L["CooldownPanelOpacityInCombat"] or "Opacity (in combat)",
				kind = SettingType.Slider,
				field = "opacityInCombat",
				parentId = "cooldownPanelDisplay",
				default = Helper.NormalizeOpacity(layout.opacityInCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityInCombat),
				minValue = 0,
				maxValue = 1,
				valueStep = 0.05,
				allowInput = true,
				get = function() return Helper.NormalizeOpacity(layout.opacityInCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityInCombat) end,
				set = function(_, value) applyEditLayout(panelId, "opacityInCombat", value) end,
				formatter = function(value)
					local num = tonumber(value) or 0
					return tostring(math.floor((num * 100) + 0.5)) .. "%"
				end,
			},
			{
				name = L["CooldownPanelCooldownTextHeader"] or "Cooldown text",
				kind = SettingType.Collapsible,
				id = "cooldownPanelCooldownText",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelCooldownTextFont"] or "Cooldown text font",
				kind = SettingType.Dropdown,
				field = "cooldownTextFont",
				parentId = "cooldownPanelCooldownText",
				height = 160,
				default = layout.cooldownTextFont or countFontPath,
				get = function() return layout.cooldownTextFont or countFontPath end,
				set = function(_, value) applyEditLayout(panelId, "cooldownTextFont", value) end,
				generator = function(_, root)
					for _, option in ipairs(fontOptions()) do
						root:CreateRadio(
							option.label,
							function() return (layout.cooldownTextFont or countFontPath) == option.value end,
							function() applyEditLayout(panelId, "cooldownTextFont", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelCooldownTextSize"] or "Cooldown text size",
				kind = SettingType.Slider,
				field = "cooldownTextSize",
				parentId = "cooldownPanelCooldownText",
				default = layout.cooldownTextSize or countFontSize or 12,
				minValue = 6,
				maxValue = 64,
				valueStep = 1,
				allowInput = true,
				get = function() return layout.cooldownTextSize or countFontSize or 12 end,
				set = function(_, value) applyEditLayout(panelId, "cooldownTextSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelCooldownTextStyle"] or "Cooldown text outline",
				kind = SettingType.Dropdown,
				field = "cooldownTextStyle",
				parentId = "cooldownPanelCooldownText",
				height = 120,
				default = Helper.NormalizeFontStyleChoice(layout.cooldownTextStyle, "NONE"),
				get = function() return Helper.NormalizeFontStyleChoice(layout.cooldownTextStyle, "NONE") end,
				set = function(_, value) applyEditLayout(panelId, "cooldownTextStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.FontStyleOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeFontStyleChoice(layout.cooldownTextStyle, "NONE") == option.value end,
							function() applyEditLayout(panelId, "cooldownTextStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelCooldownTextColor"] or "Cooldown text color",
				kind = SettingType.Color,
				parentId = "cooldownPanelCooldownText",
				hasOpacity = true,
				default = Helper.NormalizeColor(layout.cooldownTextColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor),
				get = function()
					local color = Helper.NormalizeColor(layout.cooldownTextColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor)
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) applyEditLayout(panelId, "cooldownTextColor", value) end,
			},
			{
				name = L["CooldownPanelCooldownTextOffsetX"] or "Cooldown text offset X",
				kind = SettingType.Slider,
				field = "cooldownTextX",
				parentId = "cooldownPanelCooldownText",
				default = layout.cooldownTextX or 0,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				allowInput = true,
				get = function() return layout.cooldownTextX or 0 end,
				set = function(_, value) applyEditLayout(panelId, "cooldownTextX", value) end,
			},
			{
				name = L["CooldownPanelCooldownTextOffsetY"] or "Cooldown text offset Y",
				kind = SettingType.Slider,
				field = "cooldownTextY",
				parentId = "cooldownPanelCooldownText",
				default = layout.cooldownTextY or 0,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				allowInput = true,
				get = function() return layout.cooldownTextY or 0 end,
				set = function(_, value) applyEditLayout(panelId, "cooldownTextY", value) end,
			},
			{
				name = L["CooldownPanelStaticText"] or "Static text",
				kind = SettingType.Collapsible,
				id = "cooldownPanelStaticText",
				defaultCollapsed = true,
				isShown = function() return hasStaticTextEntries() end,
			},
			{
				name = L["Font"] or "Font",
				kind = SettingType.Dropdown,
				parentId = "cooldownPanelStaticText",
				height = 220,
				isShown = function() return hasStaticTextEntries() end,
				get = function()
					local entry = getStaticTextEntry()
					local configured = entry and entry.staticTextFont
					if type(configured) == "string" and configured ~= "" then return configured end
					return countFontPath
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					updateStaticTextEntry(entry, "staticTextFont", value)
				end,
				generator = function(_, root)
					for _, option in ipairs(fontOptions()) do
						root:CreateRadio(option.label, function()
							local entry = getStaticTextEntry()
							if not entry then return false end
							local configured = entry.staticTextFont
							if type(configured) == "string" and configured ~= "" then return configured == option.value end
							return countFontPath == option.value
						end, function()
							local entry = getStaticTextEntry()
							if not entry then return end
							updateStaticTextEntry(entry, "staticTextFont", option.value)
						end)
					end
				end,
			},
			{
				name = L["CooldownPanelFontStyle"] or "Font style",
				kind = SettingType.Dropdown,
				parentId = "cooldownPanelStaticText",
				height = 120,
				isShown = function() return hasStaticTextEntries() end,
				get = function()
					local entry = getStaticTextEntry()
					return Helper.NormalizeFontStyleChoice(entry and entry.staticTextStyle, Helper.ENTRY_DEFAULTS.staticTextStyle or "OUTLINE")
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					updateStaticTextEntry(entry, "staticTextStyle", Helper.NormalizeFontStyleChoice(value, Helper.ENTRY_DEFAULTS.staticTextStyle or "OUTLINE"))
				end,
				generator = function(_, root)
					for _, option in ipairs(Helper.FontStyleOptions) do
						root:CreateRadio(option.label, function()
							local entry = getStaticTextEntry()
							return Helper.NormalizeFontStyleChoice(entry and entry.staticTextStyle, Helper.ENTRY_DEFAULTS.staticTextStyle or "OUTLINE") == option.value
						end, function()
							local entry = getStaticTextEntry()
							if not entry then return end
							updateStaticTextEntry(entry, "staticTextStyle", option.value)
						end)
					end
				end,
			},
			{
				name = L["CooldownPanelStaticTextColor"] or _G.COLOR or "Color",
				kind = SettingType.Color,
				parentId = "cooldownPanelStaticText",
				hasOpacity = true,
				isShown = function() return hasStaticTextEntries() end,
				default = Helper.NormalizeColor(Helper.ENTRY_DEFAULTS.staticTextColor, { 1, 1, 1, 1 }),
				get = function()
					local entry = getStaticTextEntry()
					local color = Helper.NormalizeColor(entry and entry.staticTextColor, Helper.ENTRY_DEFAULTS.staticTextColor or { 1, 1, 1, 1 })
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					updateStaticTextEntry(entry, "staticTextColor", Helper.NormalizeColor(value, Helper.ENTRY_DEFAULTS.staticTextColor or { 1, 1, 1, 1 }))
				end,
			},
			{
				name = L["FontSize"] or "Font size",
				kind = SettingType.Slider,
				parentId = "cooldownPanelStaticText",
				minValue = 6,
				maxValue = 64,
				valueStep = 1,
				allowInput = true,
				isShown = function() return hasStaticTextEntries() end,
				get = function()
					local entry = getStaticTextEntry()
					return Helper.ClampInt(entry and entry.staticTextSize, 6, 64, Helper.ENTRY_DEFAULTS.staticTextSize or countFontSize or 12)
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					local size = Helper.ClampInt(value, 6, 64, Helper.ENTRY_DEFAULTS.staticTextSize or countFontSize or 12)
					updateStaticTextEntry(entry, "staticTextSize", size)
				end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["Anchor"] or "Anchor",
				kind = SettingType.Dropdown,
				parentId = "cooldownPanelStaticText",
				height = 160,
				isShown = function() return hasStaticTextEntries() end,
				get = function()
					local entry = getStaticTextEntry()
					return Helper.NormalizeAnchor(entry and entry.staticTextAnchor, Helper.ENTRY_DEFAULTS.staticTextAnchor or "CENTER")
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					updateStaticTextEntry(entry, "staticTextAnchor", Helper.NormalizeAnchor(value, Helper.ENTRY_DEFAULTS.staticTextAnchor or "CENTER"))
				end,
				generator = function(_, root)
					for _, option in ipairs(Helper.AnchorOptions) do
						root:CreateRadio(option.label, function()
							local entry = getStaticTextEntry()
							return Helper.NormalizeAnchor(entry and entry.staticTextAnchor, Helper.ENTRY_DEFAULTS.staticTextAnchor or "CENTER") == option.value
						end, function()
							local entry = getStaticTextEntry()
							if not entry then return end
							updateStaticTextEntry(entry, "staticTextAnchor", option.value)
						end)
					end
				end,
			},
			{
				name = L["Text X Offset"] or "Text X Offset",
				kind = SettingType.Slider,
				parentId = "cooldownPanelStaticText",
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				allowInput = true,
				isShown = function() return hasStaticTextEntries() end,
				get = function()
					local entry = getStaticTextEntry()
					return Helper.ClampInt(entry and entry.staticTextX, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					local offset = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
					updateStaticTextEntry(entry, "staticTextX", offset)
				end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["Text Y Offset"] or "Text Y Offset",
				kind = SettingType.Slider,
				parentId = "cooldownPanelStaticText",
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				allowInput = true,
				isShown = function() return hasStaticTextEntries() end,
				get = function()
					local entry = getStaticTextEntry()
					return Helper.ClampInt(entry and entry.staticTextY, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
				end,
				set = function(_, value)
					local entry = getStaticTextEntry()
					if not entry then return end
					local offset = Helper.ClampInt(value, -Helper.OFFSET_RANGE, Helper.OFFSET_RANGE, 0)
					updateStaticTextEntry(entry, "staticTextY", offset)
				end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelOverlaysHeader"] or "Overlays",
				kind = SettingType.Collapsible,
				id = "cooldownPanelOverlays",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelRangeOverlay"] or "Range overlay",
				kind = SettingType.CheckboxColor,
				parentId = "cooldownPanelOverlays",
				default = layout.rangeOverlayEnabled == true,
				get = function() return layout.rangeOverlayEnabled == true end,
				set = function(_, value) applyEditLayout(panelId, "rangeOverlayEnabled", value) end,
				colorDefault = Helper.NormalizeColor(layout.rangeOverlayColor, Helper.PANEL_LAYOUT_DEFAULTS.rangeOverlayColor),
				colorGet = function() return layout.rangeOverlayColor or Helper.PANEL_LAYOUT_DEFAULTS.rangeOverlayColor end,
				colorSet = function(_, value) applyEditLayout(panelId, "rangeOverlayColor", value) end,
				hasOpacity = true,
			},
			{
				name = L["CooldownPanelNoDesaturation"] or "No desaturation",
				kind = SettingType.Checkbox,
				parentId = "cooldownPanelOverlays",
				default = layout.noDesaturation == true,
				get = function() return layout.noDesaturation == true end,
				set = function(_, value) applyEditLayout(panelId, "noDesaturation", value) end,
			},
			{
				name = L["CooldownPanelPowerTint"] or "Check power",
				kind = SettingType.CheckboxColor,
				parentId = "cooldownPanelOverlays",
				default = layout.checkPower == true,
				get = function() return layout.checkPower == true end,
				set = function(_, value) applyEditLayout(panelId, "checkPower", value) end,
				colorDefault = Helper.NormalizeColor(layout.powerTintColor, Helper.PANEL_LAYOUT_DEFAULTS.powerTintColor),
				colorGet = function() return layout.powerTintColor or Helper.PANEL_LAYOUT_DEFAULTS.powerTintColor end,
				colorSet = function(_, value) applyEditLayout(panelId, "powerTintColor", value) end,
			},
			{
				name = L["CooldownPanelHideWhenNoResource"] or "Hide when no resource",
				kind = SettingType.Checkbox,
				parentId = "cooldownPanelOverlays",
				default = layout.hideWhenNoResource == true,
				get = function() return layout.hideWhenNoResource == true end,
				set = function(_, value) applyEditLayout(panelId, "hideWhenNoResource", value) end,
			},
			{
				name = _G.GLOW or "Glow",
				kind = SettingType.Collapsible,
				id = "cooldownPanelGlow",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelProcGlow"] or "Proc glow",
				kind = SettingType.Checkbox,
				parentId = "cooldownPanelGlow",
				default = layout.procGlowEnabled ~= false,
				get = function() return layout.procGlowEnabled ~= false end,
				set = function(_, value) applyEditLayout(panelId, "procGlowEnabled", value) end,
			},
			{
				name = L["CooldownPanelHideGlowOutOfCombat"] or "Hide glow out of combat",
				kind = SettingType.Checkbox,
				parentId = "cooldownPanelGlow",
				default = layout.hideGlowOutOfCombat == true,
				get = function() return layout.hideGlowOutOfCombat == true end,
				set = function(_, value) applyEditLayout(panelId, "hideGlowOutOfCombat", value) end,
			},
			{
				name = L["CooldownPanelProcGlowStyle"] or "Proc glow style",
				kind = SettingType.Dropdown,
				parentId = "cooldownPanelGlow",
				height = 180,
				default = select(1, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)),
				get = function() return select(1, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)) end,
				set = function(_, value) applyEditLayout(panelId, "procGlowStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
						local label = L[option.labelKey] or option.fallback
						root:CreateRadio(
							label,
							function() return select(1, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)) == option.value end,
							function() applyEditLayout(panelId, "procGlowStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelProcGlowInset"] or "Proc glow inset",
				kind = SettingType.Slider,
				parentId = "cooldownPanelGlow",
				minValue = -(Helper.GLOW_INSET_RANGE or 20),
				maxValue = Helper.GLOW_INSET_RANGE or 20,
				valueStep = 1,
				allowInput = true,
				default = select(2, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)),
				get = function() return select(2, CooldownPanels:ResolveEntryProcGlowVisual(layout, nil)) end,
				set = function(_, value) applyEditLayout(panelId, "procGlowInset", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelReadyGlowCheckPower"] or "Require resource for ready glow",
				kind = SettingType.Checkbox,
				parentId = "cooldownPanelGlow",
				default = layout.readyGlowCheckPower == true,
				get = function() return layout.readyGlowCheckPower == true end,
				set = function(_, value) applyEditLayout(panelId, "readyGlowCheckPower", value) end,
			},
			{
				name = L["CooldownPanelGlowStyle"] or "Glow style",
				kind = SettingType.Dropdown,
				parentId = "cooldownPanelGlow",
				height = 180,
				default = Helper.NormalizeGlowStyle(layout.readyGlowStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle),
				get = function() return Helper.NormalizeGlowStyle(layout.readyGlowStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) end,
				set = function(_, value) applyEditLayout(panelId, "readyGlowStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
						local label = L[option.labelKey] or option.fallback
						root:CreateRadio(
							label,
							function() return Helper.NormalizeGlowStyle(layout.readyGlowStyle, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) == option.value end,
							function() applyEditLayout(panelId, "readyGlowStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelGlowStylePandemic"] or "Pandemic glow style",
				kind = SettingType.Dropdown,
				parentId = "cooldownPanelGlow",
				height = 180,
				default = Helper.NormalizeGlowStyle(layout.pandemicGlowStyle, layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle),
				get = function() return Helper.NormalizeGlowStyle(layout.pandemicGlowStyle, layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) end,
				set = function(_, value) applyEditLayout(panelId, "pandemicGlowStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.GLOW_STYLE_OPTIONS or {}) do
						local label = L[option.labelKey] or option.fallback
						root:CreateRadio(
							label,
							function() return Helper.NormalizeGlowStyle(layout.pandemicGlowStyle, layout.readyGlowStyle or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowStyle) == option.value end,
							function() applyEditLayout(panelId, "pandemicGlowStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelGlowInset"] or "Glow inset",
				kind = SettingType.Slider,
				parentId = "cooldownPanelGlow",
				minValue = -(Helper.GLOW_INSET_RANGE or 20),
				maxValue = Helper.GLOW_INSET_RANGE or 20,
				valueStep = 1,
				allowInput = true,
				default = Helper.NormalizeGlowInset(layout.readyGlowInset, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0),
				get = function() return Helper.NormalizeGlowInset(layout.readyGlowInset, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0) end,
				set = function(_, value) applyEditLayout(panelId, "readyGlowInset", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelGlowColor"] or "Ready glow color",
				kind = SettingType.Color,
				parentId = "cooldownPanelGlow",
				hasOpacity = true,
				default = Helper.NormalizeColor(layout.readyGlowColor, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor),
				get = function()
					local color = Helper.NormalizeColor(layout.readyGlowColor, Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) applyEditLayout(panelId, "readyGlowColor", value) end,
			},
			{
				name = L["CooldownPanelGlowColorPandemic"] or "Pandemic glow color",
				kind = SettingType.Color,
				parentId = "cooldownPanelGlow",
				hasOpacity = true,
				default = Helper.NormalizeColor(layout.pandemicGlowColor, layout.readyGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.pandemicGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor),
				get = function()
					local color =
						Helper.NormalizeColor(layout.pandemicGlowColor, layout.readyGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.pandemicGlowColor or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowColor)
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) applyEditLayout(panelId, "pandemicGlowColor", value) end,
			},
			{
				name = L["CooldownPanelGlowInsetPandemic"] or "Pandemic glow inset",
				kind = SettingType.Slider,
				parentId = "cooldownPanelGlow",
				minValue = -(Helper.GLOW_INSET_RANGE or 20),
				maxValue = Helper.GLOW_INSET_RANGE or 20,
				valueStep = 1,
				allowInput = true,
				default = Helper.NormalizeGlowInset(layout.pandemicGlowInset, layout.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0),
				get = function() return Helper.NormalizeGlowInset(layout.pandemicGlowInset, layout.readyGlowInset or Helper.PANEL_LAYOUT_DEFAULTS.readyGlowInset or 0) end,
				set = function(_, value) applyEditLayout(panelId, "pandemicGlowInset", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelStacksHeader"] or "Stacks / Item Count",
				kind = SettingType.Collapsible,
				id = "cooldownPanelStacks",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelCountAnchor"] or "Count anchor",
				kind = SettingType.Dropdown,
				field = "stackAnchor",
				parentId = "cooldownPanelStacks",
				height = 160,
				get = function() return Helper.NormalizeAnchor(layout.stackAnchor, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor) end,
				set = function(_, value) applyEditLayout(panelId, "stackAnchor", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.AnchorOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeAnchor(layout.stackAnchor, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor) == option.value end,
							function() applyEditLayout(panelId, "stackAnchor", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelCountOffsetX"] or "Count X",
				kind = SettingType.Slider,
				field = "stackX",
				parentId = "cooldownPanelStacks",
				default = layout.stackX or Helper.PANEL_LAYOUT_DEFAULTS.stackX,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				get = function() return layout.stackX or Helper.PANEL_LAYOUT_DEFAULTS.stackX end,
				set = function(_, value) applyEditLayout(panelId, "stackX", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelCountOffsetY"] or "Count Y",
				kind = SettingType.Slider,
				field = "stackY",
				parentId = "cooldownPanelStacks",
				default = layout.stackY or Helper.PANEL_LAYOUT_DEFAULTS.stackY,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				get = function() return layout.stackY or Helper.PANEL_LAYOUT_DEFAULTS.stackY end,
				set = function(_, value) applyEditLayout(panelId, "stackY", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["Font"] or "Font",
				kind = SettingType.Dropdown,
				field = "stackFont",
				parentId = "cooldownPanelStacks",
				height = 220,
				get = function() return layout.stackFont or countFontPath end,
				set = function(_, value) applyEditLayout(panelId, "stackFont", value) end,
				generator = function(_, root)
					for _, option in ipairs(fontOptions()) do
						root:CreateRadio(option.label, function() return (layout.stackFont or countFontPath) == option.value end, function() applyEditLayout(panelId, "stackFont", option.value) end)
					end
				end,
			},
			{
				name = L["CooldownPanelFontStyle"] or "Font style",
				kind = SettingType.Dropdown,
				field = "stackFontStyle",
				parentId = "cooldownPanelStacks",
				height = 120,
				get = function() return Helper.NormalizeFontStyleChoice(layout.stackFontStyle, countFontStyle) end,
				set = function(_, value) applyEditLayout(panelId, "stackFontStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.FontStyleOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeFontStyleChoice(layout.stackFontStyle, countFontStyle) == option.value end,
							function() applyEditLayout(panelId, "stackFontStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["FontSize"] or "Font size",
				kind = SettingType.Slider,
				field = "stackFontSize",
				parentId = "cooldownPanelStacks",
				default = layout.stackFontSize or countFontSize or 12,
				minValue = 6,
				maxValue = 64,
				valueStep = 1,
				get = function() return layout.stackFontSize or countFontSize or 12 end,
				set = function(_, value) applyEditLayout(panelId, "stackFontSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = _G.COLOR or "Color",
				kind = SettingType.Color,
				field = "stackColor",
				parentId = "cooldownPanelStacks",
				hasOpacity = true,
				default = Helper.NormalizeColor(layout.stackColor, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 }),
				get = function()
					local color = Helper.NormalizeColor(layout.stackColor, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 })
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) applyEditLayout(panelId, "stackColor", value) end,
			},
			{
				name = L["CooldownPanelChargesHeader"] or "Charges",
				kind = SettingType.Collapsible,
				id = "cooldownPanelCharges",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelChargesAnchor"] or "Charges anchor",
				kind = SettingType.Dropdown,
				field = "chargesAnchor",
				parentId = "cooldownPanelCharges",
				height = 160,
				get = function() return Helper.NormalizeAnchor(layout.chargesAnchor, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor) end,
				set = function(_, value) applyEditLayout(panelId, "chargesAnchor", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.AnchorOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeAnchor(layout.chargesAnchor, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor) == option.value end,
							function() applyEditLayout(panelId, "chargesAnchor", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelChargesOffsetX"] or "Charges X",
				kind = SettingType.Slider,
				field = "chargesX",
				parentId = "cooldownPanelCharges",
				default = layout.chargesX or Helper.PANEL_LAYOUT_DEFAULTS.chargesX,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				get = function() return layout.chargesX or Helper.PANEL_LAYOUT_DEFAULTS.chargesX end,
				set = function(_, value) applyEditLayout(panelId, "chargesX", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelChargesOffsetY"] or "Charges Y",
				kind = SettingType.Slider,
				field = "chargesY",
				parentId = "cooldownPanelCharges",
				default = layout.chargesY or Helper.PANEL_LAYOUT_DEFAULTS.chargesY,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				get = function() return layout.chargesY or Helper.PANEL_LAYOUT_DEFAULTS.chargesY end,
				set = function(_, value) applyEditLayout(panelId, "chargesY", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["Font"] or "Font",
				kind = SettingType.Dropdown,
				field = "chargesFont",
				parentId = "cooldownPanelCharges",
				height = 220,
				get = function() return layout.chargesFont or chargesFontPath end,
				set = function(_, value) applyEditLayout(panelId, "chargesFont", value) end,
				generator = function(_, root)
					for _, option in ipairs(chargesFontOptions()) do
						root:CreateRadio(
							option.label,
							function() return (layout.chargesFont or chargesFontPath) == option.value end,
							function() applyEditLayout(panelId, "chargesFont", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelFontStyle"] or "Font style",
				kind = SettingType.Dropdown,
				field = "chargesFontStyle",
				parentId = "cooldownPanelCharges",
				height = 120,
				get = function() return Helper.NormalizeFontStyleChoice(layout.chargesFontStyle, chargesFontStyle) end,
				set = function(_, value) applyEditLayout(panelId, "chargesFontStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.FontStyleOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeFontStyleChoice(layout.chargesFontStyle, chargesFontStyle) == option.value end,
							function() applyEditLayout(panelId, "chargesFontStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["FontSize"] or "Font size",
				kind = SettingType.Slider,
				field = "chargesFontSize",
				parentId = "cooldownPanelCharges",
				default = layout.chargesFontSize or chargesFontSize or 12,
				minValue = 6,
				maxValue = 64,
				valueStep = 1,
				get = function() return layout.chargesFontSize or chargesFontSize or 12 end,
				set = function(_, value) applyEditLayout(panelId, "chargesFontSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = _G.COLOR or "Color",
				kind = SettingType.Color,
				field = "chargesColor",
				parentId = "cooldownPanelCharges",
				hasOpacity = true,
				default = Helper.NormalizeColor(layout.chargesColor, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 }),
				get = function()
					local color = Helper.NormalizeColor(layout.chargesColor, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 })
					return { r = color[1], g = color[2], b = color[3], a = color[4] }
				end,
				set = function(_, value) applyEditLayout(panelId, "chargesColor", value) end,
			},
			{
				name = L["CooldownPanelHideWhenZero"] or "Hide when 0",
				kind = SettingType.Checkbox,
				field = "chargesHideWhenZero",
				parentId = "cooldownPanelCharges",
				default = layout.chargesHideWhenZero == true,
				get = function() return layout.chargesHideWhenZero == true end,
				set = function(_, value) applyEditLayout(panelId, "chargesHideWhenZero", value) end,
			},
			{
				name = L["CooldownPanelKeybindsHeader"] or "Keybinds",
				kind = SettingType.Collapsible,
				id = "cooldownPanelKeybinds",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelShowKeybinds"] or "Show keybinds",
				kind = SettingType.Checkbox,
				field = "keybindsEnabled",
				parentId = "cooldownPanelKeybinds",
				default = layout.keybindsEnabled == true,
				get = function() return layout.keybindsEnabled == true end,
				set = function(_, value) applyEditLayout(panelId, "keybindsEnabled", value) end,
			},
			{
				name = L["CooldownPanelKeybindsIgnoreItems"] or "Ignore items",
				kind = SettingType.Checkbox,
				field = "keybindsIgnoreItems",
				parentId = "cooldownPanelKeybinds",
				default = layout.keybindsIgnoreItems == true,
				get = function() return layout.keybindsIgnoreItems == true end,
				set = function(_, value) applyEditLayout(panelId, "keybindsIgnoreItems", value) end,
			},
			{
				name = L["CooldownPanelKeybindsAnchor"] or "Keybind anchor",
				kind = SettingType.Dropdown,
				field = "keybindAnchor",
				parentId = "cooldownPanelKeybinds",
				height = 160,
				get = function() return Helper.NormalizeAnchor(layout.keybindAnchor, Helper.PANEL_LAYOUT_DEFAULTS.keybindAnchor) end,
				set = function(_, value) applyEditLayout(panelId, "keybindAnchor", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.AnchorOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeAnchor(layout.keybindAnchor, Helper.PANEL_LAYOUT_DEFAULTS.keybindAnchor) == option.value end,
							function() applyEditLayout(panelId, "keybindAnchor", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelKeybindsOffsetX"] or "Keybind X",
				kind = SettingType.Slider,
				field = "keybindX",
				parentId = "cooldownPanelKeybinds",
				default = layout.keybindX or Helper.PANEL_LAYOUT_DEFAULTS.keybindX,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				get = function() return layout.keybindX or Helper.PANEL_LAYOUT_DEFAULTS.keybindX end,
				set = function(_, value) applyEditLayout(panelId, "keybindX", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelKeybindsOffsetY"] or "Keybind Y",
				kind = SettingType.Slider,
				field = "keybindY",
				parentId = "cooldownPanelKeybinds",
				default = layout.keybindY or Helper.PANEL_LAYOUT_DEFAULTS.keybindY,
				minValue = -Helper.OFFSET_RANGE,
				maxValue = Helper.OFFSET_RANGE,
				valueStep = 1,
				get = function() return layout.keybindY or Helper.PANEL_LAYOUT_DEFAULTS.keybindY end,
				set = function(_, value) applyEditLayout(panelId, "keybindY", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["Font"] or "Font",
				kind = SettingType.Dropdown,
				field = "keybindFont",
				parentId = "cooldownPanelKeybinds",
				height = 220,
				get = function() return layout.keybindFont or countFontPath end,
				set = function(_, value) applyEditLayout(panelId, "keybindFont", value) end,
				generator = function(_, root)
					for _, option in ipairs(fontOptions()) do
						root:CreateRadio(
							option.label,
							function() return (layout.keybindFont or countFontPath) == option.value end,
							function() applyEditLayout(panelId, "keybindFont", option.value) end
						)
					end
				end,
			},
			{
				name = L["CooldownPanelFontStyle"] or "Font style",
				kind = SettingType.Dropdown,
				field = "keybindFontStyle",
				parentId = "cooldownPanelKeybinds",
				height = 120,
				get = function() return Helper.NormalizeFontStyleChoice(layout.keybindFontStyle, countFontStyle) end,
				set = function(_, value) applyEditLayout(panelId, "keybindFontStyle", value) end,
				generator = function(_, root)
					for _, option in ipairs(Helper.FontStyleOptions) do
						root:CreateRadio(
							option.label,
							function() return Helper.NormalizeFontStyleChoice(layout.keybindFontStyle, countFontStyle) == option.value end,
							function() applyEditLayout(panelId, "keybindFontStyle", option.value) end
						)
					end
				end,
			},
			{
				name = L["FontSize"] or "Font size",
				kind = SettingType.Slider,
				field = "keybindFontSize",
				parentId = "cooldownPanelKeybinds",
				default = layout.keybindFontSize or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize or 10,
				minValue = 6,
				maxValue = 64,
				valueStep = 1,
				get = function() return layout.keybindFontSize or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize or 10 end,
				set = function(_, value) applyEditLayout(panelId, "keybindFontSize", value) end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["CooldownPanelCooldownHeader"] or "Cooldown",
				kind = SettingType.Collapsible,
				id = "cooldownPanelCooldown",
				defaultCollapsed = true,
			},
			{
				name = L["CooldownPanelShowChargesCooldown"] or "Show charges cooldown",
				kind = SettingType.Checkbox,
				field = "showChargesCooldown",
				parentId = "cooldownPanelCooldown",
				default = layout.showChargesCooldown == true,
				get = function() return layout.showChargesCooldown == true end,
				set = function(_, value) applyEditLayout(panelId, "showChargesCooldown", value) end,
			},
			{
				name = L["CooldownPanelDrawEdge"] or "Draw edge",
				kind = SettingType.Checkbox,
				field = "cooldownDrawEdge",
				parentId = "cooldownPanelCooldown",
				default = layout.cooldownDrawEdge ~= false,
				get = function() return layout.cooldownDrawEdge ~= false end,
				set = function(_, value) applyEditLayout(panelId, "cooldownDrawEdge", value) end,
			},
			{
				name = L["CooldownPanelDrawBling"] or "Draw bling",
				kind = SettingType.Checkbox,
				field = "cooldownDrawBling",
				parentId = "cooldownPanelCooldown",
				default = layout.cooldownDrawBling ~= false,
				get = function() return layout.cooldownDrawBling ~= false end,
				set = function(_, value) applyEditLayout(panelId, "cooldownDrawBling", value) end,
			},
			{
				name = L["CooldownPanelDrawSwipe"] or "Draw swipe",
				kind = SettingType.Checkbox,
				field = "cooldownDrawSwipe",
				parentId = "cooldownPanelCooldown",
				default = layout.cooldownDrawSwipe ~= false,
				get = function() return layout.cooldownDrawSwipe ~= false end,
				set = function(_, value) applyEditLayout(panelId, "cooldownDrawSwipe", value) end,
			},
			{
				name = L["CooldownPanelDrawEdgeGcd"] or "Draw edge on GCD",
				kind = SettingType.Checkbox,
				field = "cooldownGcdDrawEdge",
				parentId = "cooldownPanelCooldown",
				default = layout.cooldownGcdDrawEdge == true,
				get = function() return layout.cooldownGcdDrawEdge == true end,
				set = function(_, value) applyEditLayout(panelId, "cooldownGcdDrawEdge", value) end,
			},
			{
				name = L["CooldownPanelDrawBlingGcd"] or "Draw bling on GCD",
				kind = SettingType.Checkbox,
				field = "cooldownGcdDrawBling",
				parentId = "cooldownPanelCooldown",
				default = layout.cooldownGcdDrawBling == true,
				get = function() return layout.cooldownGcdDrawBling == true end,
				set = function(_, value) applyEditLayout(panelId, "cooldownGcdDrawBling", value) end,
			},
			{
				name = L["CooldownPanelDrawSwipeGcd"] or "Draw swipe on GCD",
				kind = SettingType.Checkbox,
				field = "cooldownGcdDrawSwipe",
				parentId = "cooldownPanelCooldown",
				default = layout.cooldownGcdDrawSwipe == true,
				get = function() return layout.cooldownGcdDrawSwipe == true end,
				set = function(_, value) applyEditLayout(panelId, "cooldownGcdDrawSwipe", value) end,
			},
		}
	end
	runtime.editModeSettings = settings
	runtime.editModeSettingsMaxHeight = 620

	EditMode:RegisterFrame(editModeId, {
		frame = frame,
		title = panel.name or "Cooldown Panel",
		layoutDefaults = {
			point = (anchor and anchor.point) or panel.point or "CENTER",
			relativePoint = (anchor and anchor.relativePoint) or (anchor and anchor.point) or panel.point or "CENTER",
			x = (anchor and anchor.x) or panel.x or 0,
			y = (anchor and anchor.y) or panel.y or 0,
			iconSize = layout.iconSize,
			spacing = layout.spacing,
			layoutMode = Helper.NormalizeLayoutMode(layout.layoutMode, Helper.PANEL_LAYOUT_DEFAULTS.layoutMode),
			fixedSlotCount = Helper.NormalizeFixedGridSize(layout.fixedGridColumns, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridColumns or 0),
			fixedGridRows = Helper.NormalizeFixedGridSize(layout.fixedGridRows, Helper.PANEL_LAYOUT_DEFAULTS.fixedGridRows or 0),
			direction = Helper.NormalizeDirection(layout.direction, Helper.PANEL_LAYOUT_DEFAULTS.direction),
			wrapCount = layout.wrapCount or 0,
			wrapDirection = Helper.NormalizeDirection(layout.wrapDirection, Helper.PANEL_LAYOUT_DEFAULTS.wrapDirection or "DOWN"),
			rowSize1 = (layout.rowSizes and layout.rowSizes[1]) or baseIconSize,
			rowSize2 = (layout.rowSizes and layout.rowSizes[2]) or baseIconSize,
			rowSize3 = (layout.rowSizes and layout.rowSizes[3]) or baseIconSize,
			rowSize4 = (layout.rowSizes and layout.rowSizes[4]) or baseIconSize,
			rowSize5 = (layout.rowSizes and layout.rowSizes[5]) or baseIconSize,
			rowSize6 = (layout.rowSizes and layout.rowSizes[6]) or baseIconSize,
			growthPoint = Helper.NormalizeGrowthPoint(layout.growthPoint, Helper.PANEL_LAYOUT_DEFAULTS.growthPoint),
			radialRadius = layout.radialRadius or Helper.PANEL_LAYOUT_DEFAULTS.radialRadius,
			radialRotation = layout.radialRotation or Helper.PANEL_LAYOUT_DEFAULTS.radialRotation,
			radialArcDegrees = layout.radialArcDegrees or Helper.PANEL_LAYOUT_DEFAULTS.radialArcDegrees or 360,
			rangeOverlayEnabled = layout.rangeOverlayEnabled == true,
			rangeOverlayColor = layout.rangeOverlayColor or Helper.PANEL_LAYOUT_DEFAULTS.rangeOverlayColor,
			noDesaturation = layout.noDesaturation == true,
			cdmAuraAlwaysShowMode = CooldownPanels:ResolveEntryCDMAuraAlwaysShowMode(layout, nil),
			hideGlowOutOfCombat = layout.hideGlowOutOfCombat == true,
			readyGlowCheckPower = layout.readyGlowCheckPower == true,
			checkPower = layout.checkPower == true,
			hideWhenNoResource = layout.hideWhenNoResource == true,
			powerTintColor = layout.powerTintColor or Helper.PANEL_LAYOUT_DEFAULTS.powerTintColor,
			strata = Helper.NormalizeStrata(layout.strata, Helper.PANEL_LAYOUT_DEFAULTS.strata),
			stackAnchor = Helper.NormalizeAnchor(layout.stackAnchor, Helper.PANEL_LAYOUT_DEFAULTS.stackAnchor),
			stackX = layout.stackX or Helper.PANEL_LAYOUT_DEFAULTS.stackX,
			stackY = layout.stackY or Helper.PANEL_LAYOUT_DEFAULTS.stackY,
			stackFont = layout.stackFont or countFontPath,
			stackFontSize = layout.stackFontSize or countFontSize or 12,
			stackFontStyle = Helper.NormalizeFontStyleChoice(layout.stackFontStyle, countFontStyle),
			stackColor = Helper.NormalizeColor(layout.stackColor, Helper.PANEL_LAYOUT_DEFAULTS.stackColor or { 1, 1, 1, 1 }),
			chargesAnchor = Helper.NormalizeAnchor(layout.chargesAnchor, Helper.PANEL_LAYOUT_DEFAULTS.chargesAnchor),
			chargesX = layout.chargesX or Helper.PANEL_LAYOUT_DEFAULTS.chargesX,
			chargesY = layout.chargesY or Helper.PANEL_LAYOUT_DEFAULTS.chargesY,
			chargesFont = layout.chargesFont or chargesFontPath,
			chargesFontSize = layout.chargesFontSize or chargesFontSize or 12,
			chargesFontStyle = Helper.NormalizeFontStyleChoice(layout.chargesFontStyle, chargesFontStyle),
			chargesColor = Helper.NormalizeColor(layout.chargesColor, Helper.PANEL_LAYOUT_DEFAULTS.chargesColor or { 1, 1, 1, 1 }),
			chargesHideWhenZero = layout.chargesHideWhenZero == true,
			keybindsEnabled = layout.keybindsEnabled == true,
			keybindsIgnoreItems = layout.keybindsIgnoreItems == true,
			keybindAnchor = Helper.NormalizeAnchor(layout.keybindAnchor, Helper.PANEL_LAYOUT_DEFAULTS.keybindAnchor),
			keybindX = layout.keybindX or Helper.PANEL_LAYOUT_DEFAULTS.keybindX,
			keybindY = layout.keybindY or Helper.PANEL_LAYOUT_DEFAULTS.keybindY,
			keybindFont = layout.keybindFont or countFontPath,
			keybindFontSize = layout.keybindFontSize or Helper.PANEL_LAYOUT_DEFAULTS.keybindFontSize or 10,
			keybindFontStyle = Helper.NormalizeFontStyleChoice(layout.keybindFontStyle, countFontStyle),
			cooldownDrawEdge = layout.cooldownDrawEdge ~= false,
			cooldownDrawBling = layout.cooldownDrawBling ~= false,
			cooldownDrawSwipe = layout.cooldownDrawSwipe ~= false,
			showChargesCooldown = layout.showChargesCooldown == true,
			cooldownGcdDrawEdge = layout.cooldownGcdDrawEdge == true,
			cooldownGcdDrawBling = layout.cooldownGcdDrawBling == true,
			cooldownGcdDrawSwipe = layout.cooldownGcdDrawSwipe == true,
			opacityOutOfCombat = Helper.NormalizeOpacity(layout.opacityOutOfCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityOutOfCombat),
			opacityInCombat = Helper.NormalizeOpacity(layout.opacityInCombat, Helper.PANEL_LAYOUT_DEFAULTS.opacityInCombat),
			showTooltips = layout.showTooltips == true,
			showIconTexture = layout.showIconTexture ~= false,
			iconBorderEnabled = layout.iconBorderEnabled == true,
			iconBorderTexture = normalizeIconBorderTexture(layout.iconBorderTexture, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderTexture),
			iconBorderSize = Helper.ClampInt(layout.iconBorderSize, 1, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderSize),
			iconBorderOffset = Helper.ClampInt(layout.iconBorderOffset, -64, 64, Helper.PANEL_LAYOUT_DEFAULTS.iconBorderOffset),
			iconBorderColor = layout.iconBorderColor or Helper.PANEL_LAYOUT_DEFAULTS.iconBorderColor,
			hideOnCooldown = layout.hideOnCooldown == true,
			showOnCooldown = layout.showOnCooldown == true,
			hideInVehicle = layout.hideInVehicle == true,
			hideInPetBattle = layout.hideInPetBattle == true,
			hideInClientScene = layout.hideInClientScene ~= false,
			visibility = PanelVisibility.CopySelectionMap(PanelVisibility.NormalizeConfig(layout.visibility)),
			cooldownTextFont = layout.cooldownTextFont,
			cooldownTextSize = layout.cooldownTextSize or 12,
			cooldownTextStyle = Helper.NormalizeFontStyleChoice(layout.cooldownTextStyle, "NONE"),
			cooldownTextColor = Helper.NormalizeColor(layout.cooldownTextColor, Helper.PANEL_LAYOUT_DEFAULTS.cooldownTextColor),
			cooldownTextX = layout.cooldownTextX or 0,
			cooldownTextY = layout.cooldownTextY or 0,
		},
		onApply = function()
			-- Addon profile is authoritative. Keep EditMode data mirrored from it.
			syncEditModeLayoutFromAnchor()
			CooldownPanels.ClearAppliedAnchorCache(getRuntime(panelId))
			self:ApplyPanelPosition(panelId)
			self:UpdateVisibility(panelId)
			refreshEditModeSettingValues()
		end,
		onPositionChanged = function(_, _, data) self:HandlePositionChanged(panelId, data) end,
		onEnter = function(activeFrame)
			syncEditModeSelectionStrata(activeFrame or frame)
			self:ShowEditModeHint(panelId, true)
			if self:IsPanelLayoutEditActive(panelId) then
				self:RequestPanelRefresh(panelId)
			else
				self:UpdatePanelMouseState(panelId)
			end
		end,
		onExit = function()
			self:ShowEditModeHint(panelId, false)
			self:RequestPanelRefresh(panelId)
		end,
		isEnabled = function()
			if self:IsInEditMode() == true then return panel.enabled ~= false end
			return panel.enabled ~= false and panelAllowsSpec(panel)
		end,
		relativeTo = function() return resolveAnchorFrame(ensureAnchorTable()) end,
		allowDrag = function() return anchorUsesUIParent(ensureAnchorTable()) end,
		settings = settings,
		showOutsideEditMode = true,
		settingsMaxHeight = 620,
	})

	runtime.editModeRegistered = true
	self:UpdateVisibility(panelId)
end

function CooldownPanels:EnsureEditMode()
	local root = ensureRoot()
	if not root then return end
	Helper.SyncOrder(root.order, root.panels)
	root._orderDirty = nil
	for _, panelId in ipairs(root.order) do
		self:RegisterEditModePanel(panelId)
	end
	for panelId in pairs(root.panels) do
		if not containsId(root.order, panelId) then self:RegisterEditModePanel(panelId) end
	end
end

function CooldownPanels:AttachFakeCursor(panelId)
	if not panelId then return end
	local panel = self:GetPanel(panelId)
	if not panel then return end
	local anchor = ensurePanelAnchor(panel)
	if not anchor then return end

	local runtime = getRuntime(panelId)

	anchor.point = "CENTER"
	anchor.relativePoint = "CENTER"
	CooldownPanels.MarkRelativeFrameEntriesDirty()
	anchor.relativeFrame = FAKE_CURSOR_FRAME_NAME
	anchor.x = 0
	anchor.y = 0
	panel.point = anchor.point or panel.point or "CENTER"
	panel.x = anchor.x or panel.x or 0
	panel.y = anchor.y or panel.y or 0
	self:ApplyPanelPosition(panelId)
	refreshEditModePanelFrame(panelId, runtime.editModeId)
	refreshEditModeSettingValues()
	resetFakeCursorFrame()
	self:UpdateCursorAnchorState()
end

local editModeCallbacksRegistered = false
local function registerEditModeCallbacks()
	if editModeCallbacksRegistered then return end
	if addon.EditModeLib and addon.EditModeLib.RegisterCallback then
		addon.EditModeLib:RegisterCallback("enter", function()
			CooldownPanels:RefreshAllPanels()
			resetFakeCursorFrame()
			CooldownPanels:UpdateCursorAnchorState()
			if CooldownPanels.UpdateEventRegistration then CooldownPanels:UpdateEventRegistration() end
		end)
		addon.EditModeLib:RegisterCallback("exit", function()
			CooldownPanels.runtime = CooldownPanels.runtime or {}
			local runtime = CooldownPanels.runtime
			if runtime.editModeExitRefreshPending then return end
			runtime.editModeExitRefreshPending = true

			local function finishExitRefresh(attempt)
				local retryCount = tonumber(attempt) or 1
				if CooldownPanels:IsInEditMode() == true and retryCount < 10 and C_Timer and C_Timer.After then
					C_Timer.After(0, function() finishExitRefresh(retryCount + 1) end)
					return
				end
				runtime.editModeExitRefreshPending = nil
				CooldownPanels:RebuildSpellIndex()
				CooldownPanels:UpdateCursorAnchorState()
				CooldownPanels:RefreshAllPanels()
				refreshPanelsForCharges()
				if CooldownPanels.UpdateEventRegistration then CooldownPanels:UpdateEventRegistration() end
			end

			if C_Timer and C_Timer.After then
				C_Timer.After(0, function() finishExitRefresh(1) end)
			else
				finishExitRefresh(10)
			end
		end)
	end
	editModeCallbacksRegistered = true
end

local function isSlashCommandRegistered(command)
	if not command then return false end
	command = command:lower()
	for key, value in pairs(_G) do
		if type(key) == "string" and key:match("^SLASH_") and type(value) == "string" then
			if value:lower() == command then return true end
		end
	end
	return false
end

local function registerCooldownPanelsSlashCommand()
	if not SlashCmdList then return end
	local commands = { "/ecd", "/cpe" }
	local assigned = false
	local slot = 1
	for _, command in ipairs(commands) do
		local lower = command:lower()
		if isSlashCommandRegistered(lower) then
			local owned = false
			if SlashCmdList["EQOLCP"] then
				for i = 1, 5 do
					local key = _G["SLASH_EQOLCP" .. i]
					if type(key) == "string" and key:lower() == lower then
						owned = true
						break
					end
				end
			end
			if not owned then command = nil end
		end
		if command then
			_G["SLASH_EQOLCP" .. slot] = lower
			slot = slot + 1
			assigned = true
		end
	end
	if not assigned then return end
	SlashCmdList["EQOLCP"] = function()
		local panels = addon.Aura and addon.Aura.CooldownPanels
		if not panels then return end
		if panels.ToggleEditor then
			panels:ToggleEditor()
		elseif panels.OpenEditor then
			panels:OpenEditor()
		end
	end
end

refreshPanelsForSpell = function(spellId)
	local id = tonumber(spellId)
	if not id then return false end
	local runtime = CooldownPanels.runtime
	local index = runtime and runtime.spellIndex
	if not runtime or not index then return false end
	runtime._eqolSpellRefreshScratch = runtime._eqolSpellRefreshScratch or {}
	local panelsToRefresh = runtime._eqolSpellRefreshScratch
	for panelId in pairs(panelsToRefresh) do
		panelsToRefresh[panelId] = nil
	end
	local refreshed = false
	local function collectPanels(lookupId)
		if not lookupId then return end
		local panels = index[lookupId]
		if not panels then return end
		for panelId in pairs(panels) do
			panelsToRefresh[panelId] = true
			refreshed = true
		end
	end
	collectPanels(id)
	local baseId = getBaseSpellId(id)
	if baseId and baseId ~= id then collectPanels(baseId) end
	local effectiveId = getEffectiveSpellId(id)
	if effectiveId and effectiveId ~= id and effectiveId ~= baseId then collectPanels(effectiveId) end
	if not refreshed then return false end
	for panelId in pairs(panelsToRefresh) do
		panelsToRefresh[panelId] = nil
		if CooldownPanels.RequestPanelRefresh then
			CooldownPanels:RequestPanelRefresh(panelId)
		elseif CooldownPanels:GetPanel(panelId) then
			CooldownPanels:RefreshPanel(panelId)
		end
	end
	return refreshed
end

CooldownPanels.TraceChargeSpellSnapshot = function(stage, spellId, extra)
	local numericId = tonumber(spellId)
	if not numericId then return end
	local baseId = getBaseSpellId(numericId)
	local effectiveId = getEffectiveSpellId(numericId)
	local bars = CooldownPanels.Bars
	if not (bars and bars.TraceChargeDebug and bars.ShouldTraceChargeSpell and bars.ShouldTraceChargeSpell(numericId, baseId, effectiveId)) then return end
	local info = Api.GetSpellChargesInfo and Api.GetSpellChargesInfo(numericId) or nil
	local chargeDurationObject = C_Spell and C_Spell.GetSpellChargeDuration and C_Spell.GetSpellChargeDuration(numericId) or nil
	local cooldownDurationObject = getSpellCooldownDurationObject and getSpellCooldownDurationObject(numericId) or nil
	local startTime, duration, enabled, modRate, isOnGCD, isActive = getSpellCooldownInfo(numericId)
	local payload = {
		spellId = numericId,
		baseSpellId = baseId,
		effectiveSpellId = effectiveId,
		chargesIsActive = info and info.isActive,
		currentCharges = info and info.currentCharges,
		maxCharges = info and info.maxCharges,
		chargeStartTime = info and info.cooldownStartTime,
		chargeCooldownDuration = info and info.cooldownDuration,
		chargeModRate = info and info.chargeModRate,
		chargeDurationObject = chargeDurationObject ~= nil,
		chargeDurationRemaining = chargeDurationObject and chargeDurationObject.GetRemainingDuration and chargeDurationObject.GetRemainingDuration(chargeDurationObject, Api.DurationModifierRealTime) or nil,
		cooldownStartTime = startTime,
		cooldownDuration = duration,
		cooldownEnabled = enabled,
		cooldownModRate = modRate,
		cooldownIsOnGCD = isOnGCD,
		cooldownIsActive = isActive,
		cooldownDurationObject = cooldownDurationObject ~= nil,
		cooldownDurationRemaining = cooldownDurationObject and cooldownDurationObject.GetRemainingDuration and cooldownDurationObject.GetRemainingDuration(cooldownDurationObject, Api.DurationModifierRealTime) or nil,
	}
	if type(extra) == "table" then
		for key, value in pairs(extra) do
			payload[key] = value
		end
	end
	bars.TraceChargeDebug(stage, payload)
end

CooldownPanels.InvalidateChargeCachesForSpell = function(spellId)
	local numericSpellId = tonumber(spellId)
	local baseId = numericSpellId and getBaseSpellId(numericSpellId) or nil
	local effectiveId = numericSpellId and getEffectiveSpellId(numericSpellId) or nil
	local function invalidateForId(id)
		if not id then return end
		CooldownPanels:InvalidateSpellQueryCaches("charges", id)
		CooldownPanels:InvalidateSpellQueryCaches("chargeDuration", id)
		CooldownPanels:InvalidateSpellQueryCaches("duration", id)
		CooldownPanels:InvalidateSpellQueryCaches("info", id)
	end
	invalidateForId(numericSpellId)
	if baseId and baseId ~= numericSpellId then invalidateForId(baseId) end
	if effectiveId and effectiveId ~= numericSpellId and effectiveId ~= baseId then invalidateForId(effectiveId) end
end

refreshPanelsForCharges = function()
	local runtime = CooldownPanels.runtime
	local chargesIndex = runtime and runtime.chargesIndex
	if not chargesIndex or not Api.GetSpellChargesInfo then return false end
	runtime.chargesState = runtime.chargesState or {}
	local chargesState = runtime.chargesState
	local panelsToRefresh

	for spellId, panels in pairs(chargesIndex) do
		local info = Api.GetSpellChargesInfo(spellId)
		local function safeNumber(value)
			if Api.issecretvalue and Api.issecretvalue(value) then return nil, true end
			return type(value) == "number" and value or nil, false
		end
		local function safeBoolean(value)
			if Api.issecretvalue and Api.issecretvalue(value) then return nil, true end
			return type(value) == "boolean" and value or nil, false
		end
		local cur, curSecret = safeNumber(info and info.currentCharges)
		local max, maxSecret = safeNumber(info and info.maxCharges)
		local start, startSecret = safeNumber(info and info.cooldownStartTime)
		local duration, durationSecret = safeNumber(info and info.cooldownDuration)
		local rate, rateSecret = safeNumber(info and info.chargeModRate)
		local active, activeSecret = safeBoolean(info and info.isActive)

		local state = chargesState[spellId]
		local changed = false
		if not state then
			state = {}
			chargesState[spellId] = state
			changed = true
		end

		local function updateStateField(field, value, isSecret)
			local secretField = field .. "Secret"
			local normalizedSecret = isSecret or nil
			if state[field] ~= value or state[secretField] ~= normalizedSecret then changed = true end
			state[field] = value
			state[secretField] = normalizedSecret
		end
		updateStateField("cur", cur, curSecret)
		updateStateField("max", max, maxSecret)
		updateStateField("start", start, startSecret)
		updateStateField("duration", duration, durationSecret)
		updateStateField("rate", rate, rateSecret)
		updateStateField("active", active, activeSecret)
		CooldownPanels.TraceChargeSpellSnapshot("trace51505_coreRefreshPanelsForCharges", spellId, {
			changed = changed == true,
			hasPanels = panels ~= nil,
		})

		if changed and panels then
			panelsToRefresh = panelsToRefresh or {}
			for panelId in pairs(panels) do
				panelsToRefresh[panelId] = true
			end
		end
	end

	if panelsToRefresh then
		for panelId in pairs(panelsToRefresh) do
			if CooldownPanels:GetPanel(panelId) then CooldownPanels:RefreshPanel(panelId) end
		end
		return true
	end
	return false
end

local function updatePowerStatesVisible(powerTokens)
	if not Api.IsSpellUsableFn then return false end
	local runtime = CooldownPanels.runtime
	local powerIndex = runtime and runtime.powerIndex
	local powerCheckSpells = runtime and runtime.powerCheckSpells
	local powerPanelsBySpell = runtime and runtime.powerPanelsBySpell
	if not powerCheckSpells or not runtime.powerCheckActive then return false end
	runtime.powerInsufficient = runtime.powerInsufficient or {}
	runtime.spellUnusable = runtime.spellUnusable or {}
	runtime._eqolPowerCheckSpellsScratch = runtime._eqolPowerCheckSpellsScratch or {}
	runtime._eqolPowerChangedScratch = runtime._eqolPowerChangedScratch or {}
	local spellsToCheck = runtime._eqolPowerCheckSpellsScratch
	local changedBySpell = runtime._eqolPowerChangedScratch
	for spellId in pairs(spellsToCheck) do
		spellsToCheck[spellId] = nil
	end
	for spellId in pairs(changedBySpell) do
		changedBySpell[spellId] = nil
	end
	local checkAll = true
	if powerTokens and next(powerTokens) and powerIndex and next(powerIndex) then
		checkAll = false
		for token in pairs(powerTokens) do
			local bucket = token and powerIndex[token] or nil
			if bucket then
				for spellId in pairs(bucket) do
					spellsToCheck[spellId] = true
				end
			else
				checkAll = true
				break
			end
		end
		if not checkAll and not next(spellsToCheck) then checkAll = true end
	end
	local panelsToRefresh
	local spellMap = checkAll and powerCheckSpells or spellsToCheck
	for effectiveId in pairs(spellMap) do
		if powerCheckSpells[effectiveId] then
			local isUsable, insufficientPower = Api.IsSpellUsableFn(effectiveId)
			changedBySpell[effectiveId] = setPowerInsufficient(runtime, effectiveId, isUsable, insufficientPower) == true
			if changedBySpell[effectiveId] then
				local panels = powerPanelsBySpell and powerPanelsBySpell[effectiveId] or nil
				if panels then
					panelsToRefresh = panelsToRefresh or {}
					for panelId in pairs(panels) do
						panelsToRefresh[panelId] = true
					end
				end
			end
		end
	end
	if panelsToRefresh then
		for panelId in pairs(panelsToRefresh) do
			if CooldownPanels.RequestPanelRefresh then
				CooldownPanels:RequestPanelRefresh(panelId)
			elseif CooldownPanels:GetPanel(panelId) then
				CooldownPanels:RefreshPanel(panelId)
			end
		end
	end
	return true
end

local function schedulePowerUsableRefresh(powerToken)
	local runtime = CooldownPanels.runtime
	if not runtime or not runtime.powerCheckActive then return end
	runtime._eqolPendingPowerTokens = runtime._eqolPendingPowerTokens or {}
	local pendingTokens = runtime._eqolPendingPowerTokens
	if type(powerToken) == "string" and powerToken ~= "" then
		pendingTokens[string.upper(powerToken)] = true
	else
		runtime._eqolPendingPowerFull = true
	end
	if runtime.powerRefreshPending then return end
	runtime.powerRefreshPending = true
	C_Timer.After(CooldownPanels.POWER_USABLE_REFRESH_DELAY, function()
		local rt = CooldownPanels.runtime
		if not rt then return end
		local pending = rt._eqolPendingPowerTokens
		local pendingFull = rt._eqolPendingPowerFull == true
		rt.powerRefreshPending = nil
		rt._eqolPendingPowerFull = nil
		updatePowerStatesVisible(pendingFull and nil or pending)
		rt._eqolPendingPowerTokens = rt._eqolPendingPowerTokens or {}
		if pending and next(pending) then
			for token in pairs(pending) do
				rt._eqolPendingPowerTokens[token] = nil
			end
		end
	end)
end

updatePowerEventRegistration = function()
	local runtime = CooldownPanels.runtime
	local frame = runtime and runtime.updateFrame
	if not frame or not frame.RegisterUnitEvent then return end
	local enable = runtime and runtime.powerCheckActive
	if enable and not runtime.powerEventRegistered then
		frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
		frame:RegisterEvent("SPELL_UPDATE_USABLE")
		runtime.powerEventRegistered = true
	elseif not enable and runtime.powerEventRegistered then
		frame:UnregisterEvent("UNIT_POWER_UPDATE")
		frame:UnregisterEvent("SPELL_UPDATE_USABLE")
		runtime.powerEventRegistered = nil
	end
end

updateRangeCheckSpells = function(rangeCheckSpells)
	if not Api.EnableSpellRangeCheck then return end
	local wanted = rangeCheckSpells
	if not wanted then
		wanted = {}
		local root = ensureRoot()
		if root and root.panels then
			for _, panel in pairs(root.panels) do
				if panel and panel.enabled ~= false and panelAllowsSpec(panel) then
					local layout = panel.layout
					if layout and layout.rangeOverlayEnabled == true then
						for _, entry in pairs(panel.entries or {}) do
							local spellId
							if entry and entry.type == "SPELL" and entry.spellID then
								spellId = tonumber(entry.spellID)
							elseif entry and entry.type == "MACRO" then
								local macro = CooldownPanels.ResolveMacroEntry(entry)
								if macro and macro.kind == "SPELL" and macro.spellID then spellId = tonumber(macro.spellID) end
							end
							if spellId then
								local effectiveId = getEffectiveSpellId(spellId) or spellId
								if not isSpellPassiveSafe(spellId, effectiveId) then wanted[spellId] = true end
							end
						end
					end
				end
			end
		end
	end

	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.rangeCheckSpells = runtime.rangeCheckSpells or {}
	local active = runtime.rangeCheckSpells

	for spellId in pairs(active) do
		if not wanted[spellId] then
			Api.EnableSpellRangeCheck(spellId, false)
			active[spellId] = nil
			if runtime.rangeOverlaySpells then runtime.rangeOverlaySpells[spellId] = nil end
		end
	end
	for spellId in pairs(wanted) do
		if not active[spellId] then
			Api.EnableSpellRangeCheck(spellId, true)
			active[spellId] = true
		end
	end
end
local function clearReadyGlowForSpell(spellId)
	local id = tonumber(spellId)
	if not id then return false end
	local index = CooldownPanels.runtime and CooldownPanels.runtime.spellIndex
	local panels = index and index[id]
	if not panels then return false end
	for panelId in pairs(panels) do
		local runtime = getRuntime(panelId)
		local panel = CooldownPanels:GetPanel(panelId)
		if runtime and panel and panel.entries then
			runtime.readyAt = runtime.readyAt or {}
			runtime.glowTimers = runtime.glowTimers or {}
			for entryId, entry in pairs(panel.entries) do
				if entry then
					local entrySpellId
					if entry.type == "SPELL" and entry.spellID then
						entrySpellId = tonumber(entry.spellID)
					elseif entry.type == "MACRO" then
						local macro = CooldownPanels.ResolveMacroEntry(entry)
						if macro and macro.kind == "SPELL" and macro.spellID then entrySpellId = tonumber(macro.spellID) end
					end
					local effectiveId = entrySpellId and getEffectiveSpellId(entrySpellId) or nil
					if entrySpellId == id or effectiveId == id then
						runtime.readyAt[entryId] = nil
						local t = runtime.glowTimers[entryId]
						if t and t.Cancel then t:Cancel() end
						runtime.glowTimers[entryId] = nil
					end
				end
			end
		end
	end
	return true
end

local function triggerProcSoundForSpell(spellId)
	local id = tonumber(spellId)
	if not id then return end

	local index = CooldownPanels.runtime and CooldownPanels.runtime.spellIndex
	if not index then return end

	local panels
	local function mergePanels(map)
		if not map then return end
		panels = panels or {}
		for panelId in pairs(map) do
			panels[panelId] = true
		end
	end

	mergePanels(index[id])
	local baseId = getBaseSpellId(id)
	if baseId and baseId ~= id then mergePanels(index[baseId]) end
	local effectiveId = getEffectiveSpellId(id)
	if effectiveId and effectiveId ~= id then mergePanels(index[effectiveId]) end
	if not panels then return end

	-- EINMAL spielen, auch wenn der Spell in mehreren Panels vorkommt.
	local root = ensureRoot()
	local panelOrder = root and root.order

	local function scanPanel(panelId)
		local panel = CooldownPanels:GetPanel(panelId)
		if not (panel and panel.order and panel.entries) then return false end

		for _, entryId in ipairs(panel.order) do
			local entry = panel.entries[entryId]
			if entry then
				local entryBaseId
				if entry.type == "SPELL" and entry.spellID then
					entryBaseId = tonumber(entry.spellID)
				elseif entry.type == "MACRO" then
					local macro = CooldownPanels.ResolveMacroEntry(entry)
					if macro and macro.kind == "SPELL" and macro.spellID then entryBaseId = tonumber(macro.spellID) end
				end
				if entryBaseId then
					local entryEffId = getEffectiveSpellId(entryBaseId) or entryBaseId
					if entryBaseId == id or entryEffId == id then
						if entry.type ~= "MACRO" and entry.soundReady == true then
							local soundName = normalizeSoundName(entry.soundReadyFile)
							if soundName and soundName ~= "None" then
								playSoundName(soundName)
								return true
							end
						end
					end
				end
			end
		end

		return false
	end

	-- deterministisch: erst Root-Panel-Reihenfolge
	if panelOrder then
		for _, panelId in ipairs(panelOrder) do
			if panels[panelId] and scanPanel(panelId) then return end
		end
	end

	-- fallback: irgend eins
	for panelId in pairs(panels) do
		if scanPanel(panelId) then return end
	end
end

local function setOverlayGlowForSpell(spellId, enabled)
	local id = tonumber(spellId)
	if not id then return false end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.overlayGlowSpells = runtime.overlayGlowSpells or {}
	local baseId = getBaseSpellId(id)
	local effectiveId = getEffectiveSpellId(id)
	local wasEnabled = runtime.overlayGlowSpells[id] == true
	if not wasEnabled and baseId then wasEnabled = runtime.overlayGlowSpells[baseId] == true end
	if not wasEnabled and effectiveId then wasEnabled = runtime.overlayGlowSpells[effectiveId] == true end
	local function setFlag(spellIdentifier, value)
		if spellIdentifier then runtime.overlayGlowSpells[spellIdentifier] = value end
	end
	if enabled then
		setFlag(id, true)
		if baseId and baseId ~= id then setFlag(baseId, true) end
		if effectiveId and effectiveId ~= id then setFlag(effectiveId, true) end
	else
		setFlag(id, nil)
		if baseId and baseId ~= id then setFlag(baseId, nil) end
		if effectiveId and effectiveId ~= id then setFlag(effectiveId, nil) end
	end
	-- Sound nur wenn es frisch "an" ging.
	if enabled and not wasEnabled then triggerProcSoundForSpell(id) end
	if refreshPanelsForSpell and refreshPanelsForSpell(id) then return true end
	if CooldownPanels and CooldownPanels.RequestUpdate then CooldownPanels:RequestUpdate("OverlayGlow") end
	return true
end

local function setRangeOverlayForSpell(spellIdentifier, isInRange, checksRange)
	local id = tonumber(spellIdentifier)
	if not id and type(spellIdentifier) == "string" then id = C_Spell.GetSpellIDForSpellIdentifier(spellIdentifier) end
	if not id then return false end
	local index = CooldownPanels.runtime and CooldownPanels.runtime.spellIndex
	local panels = index and index[id]
	if not panels then return false end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.rangeOverlaySpells = runtime.rangeOverlaySpells or {}
	local shouldShow = checksRange and isInRange == false
	local wasShown = runtime.rangeOverlaySpells[id] == true
	if shouldShow == wasShown then return false end
	if shouldShow then
		runtime.rangeOverlaySpells[id] = true
	else
		runtime.rangeOverlaySpells[id] = nil
	end
	if refreshPanelsForSpell and refreshPanelsForSpell(id) then return true end
	if CooldownPanels and CooldownPanels.RequestUpdate then CooldownPanels:RequestUpdate("RangeOverlay") end
	return true
end

local function performSpecAwareRebuild(cause)
	CooldownPanels:RebuildSpellIndex()
	Keybinds.InvalidateCache()
	CooldownPanels:RequestUpdate({
		cause = cause,
		fullRefresh = true,
	})
end

local function runDelayedSpecAwareRebuild()
	local rt = CooldownPanels.runtime
	if not rt then return end
	rt.specRebuildPending = nil
	rt.specRebuildImmediateDone = nil
	local cause = rt.specRebuildCause
	rt.specRebuildCause = nil
	performSpecAwareRebuild(cause)
end

local function scheduleSpecAwareRebuild(event, immediate)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	runtime.specRebuildCause = "Event:" .. tostring(event or "Unknown")

	if immediate == true and runtime.specRebuildImmediateDone ~= true then
		runtime.specRebuildImmediateDone = true
		performSpecAwareRebuild(runtime.specRebuildCause .. ":Immediate")
	end

	if runtime.specRebuildPending then return end
	runtime.specRebuildPending = true
	C_Timer.After(1, runDelayedSpecAwareRebuild)
end

CooldownPanels.UPDATE_FRAME_EVENTS = {
	"PLAYER_ENTERING_WORLD",
	"PLAYER_LOGIN",
	"ADDON_LOADED",
	"CVAR_UPDATE",
	"SPELL_UPDATE_COOLDOWN",
	"SPELL_UPDATE_ICON",
	"SPELL_UPDATE_CHARGES",
	"SPELL_UPDATE_USES",
	"SPELLS_CHANGED",
	"ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
	"ACTIVE_TALENT_GROUP_CHANGED",
	"PLAYER_TALENT_UPDATE",
	"PLAYER_EQUIPMENT_CHANGED",
	"PLAYER_MOUNT_DISPLAY_CHANGED",
	"UPDATE_SHAPESHIFT_FORM",
	"PLAYER_CAN_GLIDE_CHANGED",
	"PLAYER_IS_GLIDING_CHANGED",
	"GROUP_ROSTER_UPDATE",
	"PLAYER_TARGET_CHANGED",
	"BAG_UPDATE_DELAYED",
	"BAG_UPDATE_COOLDOWN",
	"UPDATE_BINDINGS",
	"UPDATE_MACROS",
	"ACTIONBAR_SLOT_CHANGED",
	"ACTIONBAR_PAGE_CHANGED",
	"ACTIONBAR_HIDEGRID",
	"SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
	"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
	"SPELL_RANGE_CHECK_UPDATE",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"PET_BATTLE_OPENING_START",
	"PET_BATTLE_CLOSE",
	"CLIENT_SCENE_OPENED",
	"CLIENT_SCENE_CLOSED",
}

local function hasEnabledPanels()
	local runtime = CooldownPanels and CooldownPanels.runtime
	local enabledPanels = runtime and runtime.enabledPanels
	return enabledPanels and next(enabledPanels) ~= nil
end

local function hasConfiguredEnabledPanels()
	local root = ensureRoot()
	if not root or not root.panels then return false end
	for _, panel in pairs(root.panels) do
		if panel and panel.enabled ~= false then return true end
	end
	return false
end

local function shouldEnableUpdateFrame()
	if CooldownPanels and CooldownPanels.IsInEditMode and CooldownPanels:IsInEditMode() then return true end
	return hasEnabledPanels() or hasConfiguredEnabledPanels()
end

CooldownPanels.RequestEnabledPanelRefreshes = function()
	local root = ensureRoot()
	local runtime = CooldownPanels and CooldownPanels.runtime
	local enabledPanels = runtime and runtime.enabledPanels
	local enabledPanelIds = runtime and runtime.enabledPanelIds
	if not (root and root.panels and enabledPanels and next(enabledPanels)) then return false end
	local queued = false
	local queueRefresh = type(CooldownPanels.RequestPanelRefresh) == "function"
	if enabledPanelIds and #enabledPanelIds > 0 then
		if queueRefresh then
			for i = 1, #enabledPanelIds do
				local panelId = enabledPanelIds[i]
				if enabledPanels[panelId] then
					CooldownPanels:RequestPanelRefresh(panelId)
					queued = true
				end
			end
			return queued
		end
		CooldownPanels:BeginRuntimeQueryBatch()
		for i = 1, #enabledPanelIds do
			CooldownPanels:RefreshPanel(enabledPanelIds[i])
			queued = true
		end
		CooldownPanels:EndRuntimeQueryBatch()
		return queued
	end
	if queueRefresh then
		for _, panelId in ipairs(CooldownPanels.GetCachedPanelIds(root)) do
			if enabledPanels[panelId] then
				CooldownPanels:RequestPanelRefresh(panelId)
				queued = true
			end
		end
		return queued
	end
	CooldownPanels:BeginRuntimeQueryBatch()
	for _, panelId in ipairs(CooldownPanels.GetCachedPanelIds(root)) do
		if enabledPanels[panelId] then
			CooldownPanels:RefreshPanel(panelId)
			queued = true
		end
	end
	CooldownPanels:EndRuntimeQueryBatch()
	return queued
end

local assistedHighlightHooked = false

CooldownPanels.refreshAssistedHighlightCVarState = function(cause, suppressRefresh)
	local enabled = false
	if GetCVarBool then
		enabled = GetCVarBool("assistedCombatHighlight") == true
	elseif C_CVar and C_CVar.GetCVar then
		enabled = C_CVar.GetCVar("assistedCombatHighlight") == "1"
	end
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	if runtime.assistedHighlightEnabled == enabled then return false end
	runtime.assistedHighlightEnabled = enabled
	if not suppressRefresh and CooldownPanels and CooldownPanels.RequestUpdate then CooldownPanels:RequestUpdate(cause or "CVar:assistedCombatHighlight") end
	return true
end

CooldownPanels.ensureAssistedHighlightCVarListener = function()
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	local runtime = CooldownPanels.runtime
	if runtime.assistedHighlightCVarListenerRegistered then return true end
	CooldownPanels.refreshAssistedHighlightCVarState(nil, true)
	if CVarCallbackRegistry and CVarCallbackRegistry.RegisterCallback then
		CVarCallbackRegistry:RegisterCallback("assistedCombatHighlight", function() CooldownPanels.refreshAssistedHighlightCVarState("CVar:assistedCombatHighlight") end, CooldownPanels)
		runtime.assistedHighlightCVarListenerRegistered = true
		return true
	end
	return false
end

ensureAssistedHighlightHook = function()
	if assistedHighlightHooked then return true end
	if not (hooksecurefunc and Api.GetAssistedCombatNextSpell) then return false end
	local manager = _G.AssistedCombatManager
	if not manager then return false end
	if type(manager.UpdateAllAssistedHighlightFramesForSpell) ~= "function" then return false end

	hooksecurefunc(manager, "UpdateAllAssistedHighlightFramesForSpell", function(_, spellId)
		local refreshed = false
		if spellId and refreshPanelsForSpell then
			refreshed = refreshPanelsForSpell(spellId) == true
			local baseId = getBaseSpellId(spellId)
			if baseId and baseId ~= spellId then refreshed = refreshPanelsForSpell(baseId) == true or refreshed end
			local effectiveId = getEffectiveSpellId(spellId)
			if effectiveId and effectiveId ~= spellId and effectiveId ~= baseId then refreshed = refreshPanelsForSpell(effectiveId) == true or refreshed end
		end
		if not refreshed and CooldownPanels and CooldownPanels.RequestUpdate then CooldownPanels:RequestUpdate("AssistedCombatHighlight") end
	end)
	assistedHighlightHooked = true
	return true
end

local function setUpdateFrameEnabled(frame, enabled)
	if not frame then return end
	if enabled then
		if frame._eqolEventsRegistered then return end
		for _, event in ipairs(CooldownPanels.UPDATE_FRAME_EVENTS or {}) do
			frame:RegisterEvent(event)
		end
		frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
		frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
		frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
		frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
		frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
		frame._eqolEventsRegistered = true
		if updatePowerEventRegistration then updatePowerEventRegistration() end
	else
		if not frame._eqolEventsRegistered then return end
		frame:UnregisterAllEvents()
		frame._eqolEventsRegistered = false
	end
end

local function isAssistedCombatActionSlot(slot)
	local actionSlot = tonumber(slot)
	if not actionSlot or actionSlot <= 0 then return false end
	if not Api.IsAssistedCombatAction then return false end
	return Api.IsAssistedCombatAction(actionSlot) == true
end

function CooldownPanels:UpdateEventRegistration()
	local frame = self.runtime and self.runtime.updateFrame
	if not frame then return end
	setUpdateFrameEnabled(frame, shouldEnableUpdateFrame())
end

local function ensureUpdateFrame()
	if CooldownPanels.runtime and CooldownPanels.runtime.updateFrame then return end
	if ensureAssistedHighlightHook then ensureAssistedHighlightHook() end
	if CooldownPanels.ensureAssistedHighlightCVarListener then CooldownPanels.ensureAssistedHighlightCVarListener() end
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, ...)
		if not assistedHighlightHooked and ensureAssistedHighlightHook then ensureAssistedHighlightHook() end
		if CooldownPanels.ensureAssistedHighlightCVarListener then CooldownPanels.ensureAssistedHighlightCVarListener() end
		if event == "ADDON_LOADED" then
			local name = ...
			local anchorHelper = CooldownPanels.AnchorHelper
			if anchorHelper and anchorHelper.HandleAddonLoaded then anchorHelper:HandleAddonLoaded(name) end
			if type(name) == "string" and (name == "Dominos" or name == "Bartender4" or name == "ElvUI" or name:match("^Dominos_") or name:match("^Bartender4_")) then
				if Keybinds.InvalidateButtonList then Keybinds.InvalidateButtonList() end
				Keybinds.RequestRefresh("Event:ADDON_LOADED:" .. name)
			end
			if name == "Masque" then
				CooldownPanels:RegisterMasqueButtons()
				CooldownPanels:ReskinMasque()
			end
			return
		end
		if event == "PLAYER_LOGIN" then
			local anchorHelper = CooldownPanels.AnchorHelper
			if anchorHelper and anchorHelper.HandlePlayerLogin then anchorHelper:HandlePlayerLogin() end
			if Keybinds.InvalidateButtonList then Keybinds.InvalidateButtonList() end
			Keybinds.InvalidateCache()
			Keybinds.RequestRefresh("Event:PLAYER_LOGIN")
			if CooldownPanels.refreshAssistedHighlightCVarState then CooldownPanels.refreshAssistedHighlightCVarState("Event:PLAYER_LOGIN", true) end
			refreshPanelsForCharges()
			return
		end
		if event == "CVAR_UPDATE" then
			local cvarName = ...
			if type(cvarName) == "string" and string.lower(cvarName) == "assistedcombathighlight" then
				if CooldownPanels.refreshAssistedHighlightCVarState then CooldownPanels.refreshAssistedHighlightCVarState("Event:CVAR_UPDATE") end
			end
			return
		end
		if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
			local spellId = ...
			setOverlayGlowForSpell(spellId, true)
			return
		end
		if event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
			local spellId = ...
			setOverlayGlowForSpell(spellId, false)
			return
		end
		if event == "SPELL_RANGE_CHECK_UPDATE" then
			local spellId, inRange, checksRange = ...
			setRangeOverlayForSpell(spellId, inRange, checksRange)
			return
		end
		if event == "SPELL_UPDATE_USABLE" then
			schedulePowerUsableRefresh()
			return
		end
		if event == "UNIT_POWER_UPDATE" then
			local unit, powerType = ...
			if unit ~= "player" then return end
			schedulePowerUsableRefresh(powerType)
			return
		end
		if event == "SPELL_UPDATE_ICON" then
			if CooldownPanels.runtime then CooldownPanels.runtime.iconCache = nil end
		end
		if event == "BAG_UPDATE_COOLDOWN" then
			local runtime = CooldownPanels.runtime
			local itemPanels = runtime and runtime.itemPanels
			if not itemPanels or not next(itemPanels) then return end
			local itemUsesPanels = runtime and runtime.itemUsesPanels
			if itemUsesPanels and next(itemUsesPanels) then updateItemCountCache(true) end
			for panelId in pairs(itemPanels) do
				if CooldownPanels:GetPanel(panelId) then CooldownPanels:RefreshPanel(panelId) end
			end
			return
		end
		if event == "ACTIONBAR_SLOT_CHANGED" then
			local slot = tonumber((...))
			-- The Single Button Assistant rotates the assisted-combat slot without changing its binding.
			if isAssistedCombatActionSlot(slot) then return end
			local root = ensureRoot()
			if not (root and root.panels) then
				Keybinds.RequestRefresh("Event:" .. event)
				return
			end

			local trackedMacroIDs = {}
			local trackedMacroNames = {}
			for _, panel in pairs(root.panels) do
				if panel and panel.enabled ~= false and panelAllowsSpec(panel) and panel.entries then
					for _, entry in pairs(panel.entries) do
						if entry and entry.type == "MACRO" then
							local macroID = tonumber(entry.macroID)
							if macroID and macroID > 0 then trackedMacroIDs[macroID] = true end

							local macroName = CooldownPanels.NormalizeMacroName(entry.macroName)
							if not macroName and macroID and Api.GetMacroInfo then
								local infoName = Api.GetMacroInfo(macroID)
								macroName = CooldownPanels.NormalizeMacroName(infoName)
							end
							if macroName then trackedMacroNames[macroName] = true end
						end
					end
				end
			end

			if not next(trackedMacroIDs) and not next(trackedMacroNames) then
				Keybinds.RequestRefresh("Event:" .. event)
				return
			end

			CooldownPanels.runtime = CooldownPanels.runtime or {}
			local runtime = CooldownPanels.runtime
			runtime.actionSlotMacroCache = runtime.actionSlotMacroCache or {}
			local slotCache = runtime.actionSlotMacroCache
			local firstSlot, lastSlot = slot, slot
			if not firstSlot or firstSlot <= 0 then
				firstSlot = 1
				lastSlot = _G.NUM_ACTIONBAR_SLOTS or 180
			end

			local shouldRefresh = false
			for actionSlot = firstSlot, lastSlot do
				local previous = slotCache[actionSlot]
				local previousID = previous and previous.id or nil
				local previousName = previous and previous.name or nil
				local previousSig = previous and previous.sig or nil
				local wasTracked = previous and ((previousID and trackedMacroIDs[previousID]) or (previousName and trackedMacroNames[previousName]))

				local currentID, currentName, currentSig
				if Api.GetActionInfo then
					local actionType, actionID = Api.GetActionInfo(actionSlot)
					if actionType == "macro" then
						currentID = tonumber(actionID)
						if Api.GetActionText then currentName = CooldownPanels.NormalizeMacroName(Api.GetActionText(actionSlot)) end
						if not currentName and currentID and Api.GetMacroInfo then currentName = CooldownPanels.NormalizeMacroName(Api.GetMacroInfo(currentID)) end
						if currentName and Api.GetMacroIndexByName then
							local byName = Api.GetMacroIndexByName(currentName)
							if type(byName) == "number" and byName > 0 then currentID = byName end
						end

						local resolved = CooldownPanels.ResolveMacroEntry({
							type = "MACRO",
							macroID = currentID,
							macroName = currentName,
						})
						if resolved then
							if resolved.kind == "SPELL" and resolved.spellID then
								currentSig = "S:" .. tostring(resolved.spellID)
							elseif resolved.kind == "ITEM" and resolved.itemID then
								currentSig = "I:" .. tostring(resolved.itemID)
							else
								currentSig = "M"
							end
						end
					end
				end

				if currentID or currentName then
					slotCache[actionSlot] = { id = currentID, name = currentName, sig = currentSig }
				else
					slotCache[actionSlot] = nil
				end

				local isTracked = (currentID and trackedMacroIDs[currentID]) or (currentName and trackedMacroNames[currentName]) or false
				if wasTracked or isTracked then
					local slotChanged = (previousID ~= currentID) or (previousName ~= currentName) or (wasTracked ~= isTracked)
					local signatureChanged = previousSig ~= currentSig
					if slotChanged or signatureChanged then
						shouldRefresh = true
						if firstSlot == lastSlot then break end
					end
				end
			end

			if shouldRefresh then
				Keybinds.InvalidateCache()
				runtime.iconCache = nil
				updateItemCountCache()
				CooldownPanels:RebuildSpellIndex()
				CooldownPanels:RequestUpdate("Event:" .. event)
			else
				Keybinds.RequestRefresh("Event:" .. event)
			end
			return
		end
		if event == "ACTIONBAR_HIDEGRID" then
			Keybinds.RequestRefresh("Event:ACTIONBAR_HIDEGRID")
			return
		end
		if event == "UPDATE_BINDINGS" or event == "ACTIONBAR_PAGE_CHANGED" then
			Keybinds.RequestRefresh("Event:" .. event)
			return
		end
		if event == "UPDATE_MACROS" then
			Keybinds.InvalidateCache()
			if CooldownPanels.runtime then CooldownPanels.runtime.iconCache = nil end
			CooldownPanels:InvalidateSpellQueryCaches()
			updateItemCountCache()
			CooldownPanels:RebuildSpellIndex()
			CooldownPanels:RequestUpdate("Event:" .. event)
			return
		end
		if event == "SPELLS_CHANGED" then
			CooldownPanels:InvalidateSpellQueryCaches()
			scheduleSpecAwareRebuild(event, false)
			return
		end
		if event == "PLAYER_SPECIALIZATION_CHANGED" then
			local unit = ...
			if unit and unit ~= "player" then return end
			CooldownPanels:InvalidateSpellQueryCaches()
			scheduleSpecAwareRebuild(event, true)
			return
		end
		if event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
			CooldownPanels:InvalidateSpellQueryCaches()
			scheduleSpecAwareRebuild(event, true)
			return
		end
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local unit, _, spellId = ...
			if unit ~= "player" then return end
			if not spellId then return end
			CooldownPanels.TraceChargeSpellSnapshot("trace51505_event_UNIT_SPELLCAST_SUCCEEDED", spellId, { event = event })
			local runtime = CooldownPanels.runtime
			local enabledPanels = runtime and runtime.enabledPanels
			if enabledPanels and not next(enabledPanels) then return end
			local spellIndex = runtime and runtime.spellIndex
			if not (spellIndex and spellIndex[spellId]) then return end
			clearReadyGlowForSpell(spellId)
			refreshPanelsForSpell(spellId)
			return
		end
		if event == "SPELL_UPDATE_COOLDOWN" then
			local spellId = ...
			if spellId ~= nil then
				CooldownPanels.TraceChargeSpellSnapshot("trace51505_event_SPELL_UPDATE_COOLDOWN_before", spellId, { event = event })
				CooldownPanels:InvalidateSpellQueryCaches("duration", spellId)
				CooldownPanels:InvalidateSpellQueryCaches("info", spellId)
				CooldownPanels.TraceChargeSpellSnapshot("trace51505_event_SPELL_UPDATE_COOLDOWN_after", spellId, { event = event })
				refreshPanelsForSpell(spellId)
				return
			end
			CooldownPanels:InvalidateSpellQueryCaches("duration")
			CooldownPanels:InvalidateSpellQueryCaches("info")
		end
		if event == "SPELL_UPDATE_USES" then
			local spellId, baseSpellId = ...
			if Helper and Helper.UpdateActionDisplayCountsForSpell then Helper.UpdateActionDisplayCountsForSpell(spellId, baseSpellId) end
			return
		end
		if event == "SPELL_UPDATE_CHARGES" then
			local spellId = ...
			if spellId ~= nil then
				CooldownPanels.TraceChargeSpellSnapshot("trace51505_event_SPELL_UPDATE_CHARGES_before", spellId, { event = event })
				CooldownPanels.InvalidateChargeCachesForSpell(spellId)
				CooldownPanels.TraceChargeSpellSnapshot("trace51505_event_SPELL_UPDATE_CHARGES_after", spellId, { event = event })
			else
				CooldownPanels:InvalidateSpellQueryCaches("charges")
				CooldownPanels:InvalidateSpellQueryCaches("chargeDuration")
				CooldownPanels:InvalidateSpellQueryCaches("duration")
				CooldownPanels:InvalidateSpellQueryCaches("info")
			end
			refreshPanelsForCharges()
			return
		end
		if event == "PLAYER_ENTERING_WORLD" then
			CooldownPanels:InvalidateSpellQueryCaches()
			updateItemCountCache()
			scheduleSpecAwareRebuild(event)
			return
		end
		if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
			local unit = ...
			if unit and unit ~= "player" then return end
		end
		if event == "CLIENT_SCENE_OPENED" then
			local sceneType = ...
			CooldownPanels.runtime = CooldownPanels.runtime or {}
			CooldownPanels.runtime.clientSceneActive = (sceneType == 1)
		elseif event == "CLIENT_SCENE_CLOSED" then
			CooldownPanels.runtime = CooldownPanels.runtime or {}
			CooldownPanels.runtime.clientSceneActive = false
		end
		if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
			if event == "PLAYER_EQUIPMENT_CHANGED" then CooldownPanels:InvalidateSpellQueryCaches() end
			updateItemCountCache()
		end
		CooldownPanels:RequestUpdate("Event:" .. event)
	end)
	CooldownPanels.runtime = CooldownPanels.runtime or {}
	CooldownPanels.runtime.updateFrame = frame
	if CooldownPanels.UpdateEventRegistration then CooldownPanels:UpdateEventRegistration() end
end

function CooldownPanels:RequestUpdate(cause)
	self.runtime = self.runtime or {}
	local runtime = self.runtime
	local fullRefresh = false
	if type(cause) == "table" then
		fullRefresh = cause.fullRefresh == true
		cause = cause.cause
	end
	if self:IsInEditMode() ~= true then
		local enabledPanels = self.runtime.enabledPanels
		if not enabledPanels or not next(enabledPanels) then
			self:RefreshAllPanels()
			return
		end
	else
		fullRefresh = true
	end
	if runtime.updateDispatching then
		if cause then runtime.updateCause = cause end
		if fullRefresh then runtime.updateFullRefresh = true end
		runtime.updateReschedule = true
		return
	end
	if runtime.updatePending then
		if cause then runtime.updateCause = cause end
		if fullRefresh then runtime.updateFullRefresh = true end
		return
	end
	runtime.updatePending = true
	runtime.updateCause = cause
	runtime.updateFullRefresh = fullRefresh
	C_Timer.After(0, function()
		local currentRuntime = self.runtime
		if not currentRuntime then return end
		local shouldFullRefresh = currentRuntime.updateFullRefresh == true or self:IsInEditMode() == true
		currentRuntime.updateDispatching = true
		currentRuntime.updateCause = nil
		currentRuntime.updateFullRefresh = nil
		currentRuntime.updateReschedule = nil
		if shouldFullRefresh then
			CooldownPanels:RefreshAllPanels(true)
		else
			if not CooldownPanels.RequestEnabledPanelRefreshes() then CooldownPanels:RefreshAllPanels() end
		end

		currentRuntime = self.runtime
		if not currentRuntime then return end
		currentRuntime.updateDispatching = nil
		currentRuntime.updatePending = nil

		if currentRuntime.updateReschedule == true then
			local nextCause = currentRuntime.updateCause
			local nextFullRefresh = currentRuntime.updateFullRefresh == true
			currentRuntime.updateCause = nil
			currentRuntime.updateFullRefresh = nil
			currentRuntime.updateReschedule = nil
			self:RequestUpdate(nextFullRefresh and {
				cause = nextCause,
				fullRefresh = true,
			} or nextCause)
			return
		end

		currentRuntime.updateCause = nil
		currentRuntime.updateFullRefresh = nil
		currentRuntime.updateReschedule = nil
	end)
end

function CooldownPanels:Init()
	if self.InitStanceTracker then self:InitStanceTracker() end
	self:NormalizeAll()
	self:EnsureEditMode()
	self:RebuildSpellIndex()
	updateItemCountCache()
	if CooldownPanels.refreshAssistedHighlightCVarState then CooldownPanels.refreshAssistedHighlightCVarState(nil, true) end
	Keybinds.RebuildPanels()
	self:RefreshAllPanels()
	self:UpdateCursorAnchorState()
	ensureUpdateFrame()
	registerEditModeCallbacks()
	registerCooldownPanelsSlashCommand()
end

function addon.Aura.functions.InitCooldownPanels()
	if CooldownPanels and CooldownPanels.Init then CooldownPanels:Init() end
end
