local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.functions = addon.functions or {}
addon.variables = addon.variables or {}

-- Locale-specific overrides for short dungeon labels shown in M+ tooltips and frames.
local challengeMapLabelOverrides = {
	zhCN = {
		[161] = "通天峰",
		[239] = "执政团",
		[402] = "艾杰斯亚",
		[556] = "萨隆",
		[557] = "风行者",
		[558] = "魔导师",
		[559] = "希纳斯",
		[560] = "迈萨拉",
	},
}

addon.variables.challengeMapLabelOverrides = challengeMapLabelOverrides

function addon.functions.BuildChallengeMapLabelTable(defaults)
	local labels = {}
	if type(defaults) == "table" then
		for mapID, label in pairs(defaults) do
			labels[mapID] = label
		end
	end

	local locale = GetLocale and GetLocale() or "enUS"
	local overrides = challengeMapLabelOverrides[locale]
	if type(overrides) == "table" then
		for mapID, label in pairs(overrides) do
			labels[mapID] = label
		end
	end

	return labels
end

function addon.functions.GetChallengeMapLabel(mapID, defaults)
	if mapID == nil then return nil end

	local locale = GetLocale and GetLocale() or "enUS"
	local overrides = challengeMapLabelOverrides[locale]
	if type(overrides) == "table" then
		local label = overrides[mapID]
		if type(label) == "string" and label ~= "" then return label end
	end

	if type(defaults) == "table" then
		local label = defaults[mapID]
		if type(label) == "string" and label ~= "" then return label end
	end

	return nil
end
