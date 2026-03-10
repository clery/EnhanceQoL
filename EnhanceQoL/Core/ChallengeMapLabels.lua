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
	deDE = {
		[161] = "Himmelsnadel",
		[239] = "Der Sitz des Triumvirats",
		[402] = "Akademie von Algeth'ar",
		[556] = "Die Grube von Saron",
		[557] = "Windläuferturm",
		[558] = "Terrasse der Magister",
		[559] = "Nexuspunkt Xenas",
		[560] = "Maisarakavernen",
	},
	esES = {
		[402] = "Academia Algeth'ar - AA",
	},
	esMX = {
		[402] = "Academia Algeth'ar - AA",
	},
	frFR = {
		[402] = "AA",
	},
	itIT = {
		[402] = "ADA",
	},
	koKR = {
		[161] = "하늘탑",
		[239] = "삼두정",
		[402] = "대학",
		[556] = "사론",
		[557] = "첨탑",
		[558] = "정원",
		[559] = "제나스",
		[560] = "마이사라",
	},
	ptBR = {
		[402] = "Academia Algeth'ar",
	},
	ruRU = {
		[161] = "Небесный Путь",
		[239] = "Престол Триумвирата",
		[402] = "Академия Алгет'ар",
		[556] = "Яма Сарона",
		[557] = "Шпили Ветрокрылых",
		[558] = "Терраса Магистров",
		[559] = "Узел Нексуса Зенас",
		[560] = "Пещеры Маисара",
	},
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
	zhTW = {
		[161] = "擎天峰",
		[239] = "三傑",
		[402] = "學院",
		[556] = "薩倫",
		[557] = "風行者",
		[558] = "博學者",
		[559] = "奧核點",
		[560] = "梅薩拉",
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
