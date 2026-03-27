local parentAddonName = "EnhanceQoL"
local addonName, addon = ...
if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Aura = addon.Aura or {}
addon.Aura.functions = addon.Aura.functions or {}
addon.Aura.variables = addon.Aura.variables or {}

function addon.Aura.functions.InitDB()
	if not addon.db or not addon.functions or not addon.functions.InitDBValue then return end
	local init = addon.functions.InitDBValue

	-- resource bar defaults
	init("enableResourceFrame", false)
	init("resourceBarsHideOutOfCombat", false)
	init("resourceBarsHideMounted", false)
	init("resourceBarsHideVehicle", false)
	init("resourceBarsHidePetBattle", false)
	init("resourceBarsHideClientScene", true)
	if addon.db.resourceBarsHidePetBattle == nil and addon.db.auraHideInPetBattle ~= nil then addon.db.resourceBarsHidePetBattle = addon.db.auraHideInPetBattle and true or false end

	-- spec specific settings for personal resource bars
	init("personalResourceBarSettings", {})
	init("personalResourceBarAnchors", {})

	init("cooldownPanels", {
		version = 1,
		panels = {},
		order = {},
		selectedPanel = nil,
		defaults = {
			layout = {
				iconSize = 36,
				spacing = 2,
				direction = "RIGHT",
				wrapCount = 0,
				wrapDirection = "DOWN",
				strata = "MEDIUM",
			},
			entry = {
				alwaysShow = true,
				showCooldown = true,
				showCooldownText = true,
				showCharges = false,
				showStacks = false,
				glowReady = false,
				glowDuration = 0,
			},
		},
	})
	init("cooldownPanelsEditorPoint", "CENTER")
	init("cooldownPanelsEditorX", 0)
	init("cooldownPanelsEditorY", 0)
	addon.db["_cooldownPanelsDebugLog"] = nil
	addon.db["debugCooldownPanelsSession"] = nil

	init("standalonePrivateAuras", {
		version = 1,
		enabled = false,
		anchor = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = -140,
		},
		icon = {
			amount = 3,
			size = 64,
			minSize = 10,
			maxSize = 256,
			point = "RIGHT",
			offset = 4,
		},
		layout = {
			enabled = true,
			direction = "RIGHT",
			wrapCount = 0,
			wrapDirection = "DOWN",
		},
		countdownFrame = true,
		countdownNumbers = false,
		showDispelType = false,
		duration = {
			enable = false,
			point = "BOTTOM",
			offsetX = 0,
			offsetY = -1,
		},
	})

	init("focusInterruptTracker", {
		version = 1,
		enabled = false,
		displayMode = "TEXT",
		text = "INTERRUPT",
		textFont = addon.functions and addon.functions.GetGlobalFontConfigKey and addon.functions.GetGlobalFontConfigKey() or "__EQOL_GLOBAL_FONT__",
		textSize = 24,
		textOutline = "THICKOUTLINE",
		textColor = { 1, 0.15, 0.15, 1 },
		iconSize = 28,
		customIcon = nil,
		background = {
			enabled = false,
			color = { 0, 0, 0, 0.35 },
		},
		border = {
			enabled = false,
			texture = "DEFAULT",
			size = 1,
			offset = 0,
			color = { 0, 0, 0, 0.9 },
		},
		anchor = {
			point = "TOP",
			relativePoint = "BOTTOM",
			relativeFrame = "AUTO",
			x = 0,
			y = -10,
		},
		strata = "HIGH",
	})

	if addon.Aura and addon.Aura.CooldownPanels and addon.Aura.CooldownPanels.NormalizeAll then addon.Aura.CooldownPanels:NormalizeAll() end
end
