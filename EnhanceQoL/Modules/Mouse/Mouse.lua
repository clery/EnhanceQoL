local parentAddonName = "EnhanceQoL"
local addonName, addon = ...

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceQoL_Mouse")
local EditMode = addon.EditMode
local SettingType = EditMode and EditMode.lib and EditMode.lib.SettingType
local GetVisibilityRuleMetadata = addon.functions and addon.functions.GetVisibilityRuleMetadata

-- Hotpath locals & constants
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local IsInInstance = IsInInstance
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local IsMounted = IsMounted
local UIParent = UIParent
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local GetClassColor = GetClassColor
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitExists = UnitExists
local GetTime = GetTime
local GetSpellCooldownInfo = (C_Spell and C_Spell.GetSpellCooldown) or GetSpellCooldown
local issecretvalue = _G.issecretvalue
local RING_FRAME_NAME = addonName .. "_MouseRingFrame"
local CROSSHAIR_FRAME_NAME = addonName .. "_MouseCrosshairFrame"
local CROSSHAIR_EDITMODE_ID = "mouseCrosshair"
local TEX_MOUSE = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Mouse\\Mouse.tga"
local TEX_DOT = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Mouse\\Dot.tga"
addon.Mouse.variables.TEXT_DOT = TEX_DOT
local TEX_TRAIL = "Interface\\AddOns\\" .. addonName .. "\\Assets\\Mouse\\MouseTrail.tga"
local PLAYER_UNIT = "player"
local GCD_SPELL_ID = 61304
local TWO_PI = math.pi * 2
local HALF_PI = math.pi * 0.5
local PROGRESS_STYLE_DOT = "DOT"
local PROGRESS_STYLE_RING = "RING"
local CROSSHAIR_RULE_ALWAYS_IN_COMBAT = "ALWAYS_IN_COMBAT"
local CROSSHAIR_RULE_ALWAYS_OUT_OF_COMBAT = "ALWAYS_OUT_OF_COMBAT"
local CROSSHAIR_RULE_PLAYER_CASTING = "PLAYER_CASTING"
local CROSSHAIR_RULE_PLAYER_MOUNTED = "PLAYER_MOUNTED"
local CROSSHAIR_RULE_PLAYER_NOT_MOUNTED = "PLAYER_NOT_MOUNTED"
local CROSSHAIR_RULE_PLAYER_HAS_TARGET = "PLAYER_HAS_TARGET"
local CROSSHAIR_RULE_PLAYER_IN_GROUP = "PLAYER_IN_GROUP"
local CROSSHAIR_RULE_PLAYER_IN_PARTY = "PLAYER_IN_PARTY"
local CROSSHAIR_RULE_PLAYER_IN_RAID = "PLAYER_IN_RAID"
local CROSSHAIR_RULE_PLAYER_IN_INSTANCE = "PLAYER_IN_INSTANCE"
local CROSSHAIR_RULE_PLAYER_IN_PARTY_INSTANCE = "PLAYER_IN_PARTY_INSTANCE"
local CROSSHAIR_RULE_PLAYER_IN_RAID_INSTANCE = "PLAYER_IN_RAID_INSTANCE"
local CROSSHAIR_ANCHOR_OPTIONS = {
	{ value = "TOPLEFT", label = "TOPLEFT", text = "TOPLEFT" },
	{ value = "TOP", label = "TOP", text = "TOP" },
	{ value = "TOPRIGHT", label = "TOPRIGHT", text = "TOPRIGHT" },
	{ value = "LEFT", label = "LEFT", text = "LEFT" },
	{ value = "CENTER", label = "CENTER", text = "CENTER" },
	{ value = "RIGHT", label = "RIGHT", text = "RIGHT" },
	{ value = "BOTTOMLEFT", label = "BOTTOMLEFT", text = "BOTTOMLEFT" },
	{ value = "BOTTOM", label = "BOTTOM", text = "BOTTOM" },
	{ value = "BOTTOMRIGHT", label = "BOTTOMRIGHT", text = "BOTTOMRIGHT" },
}

local MaxActuationPoint = 1 -- Minimaler Bewegungsabstand für Trail-Elemente
local MaxActuationPointSq = MaxActuationPoint * MaxActuationPoint
local duration = 0.3 -- Lebensdauer der Trail-Elemente in Sekunden
local Density = 0.02 -- Zeitdichte für neue Elemente
local ElementCap = 28 -- Maximale Anzahl von Trail-Elementen
local PastCursorX, PastCursorY, PresentCursorX, PresentCursorY = nil, nil, nil, nil

local trailPool = {}
local activeCount = 0
local playerClass = UnitClass and select(2, UnitClass("player")) or nil
local classR, classG, classB
if playerClass and GetClassColor then
	classR, classG, classB = GetClassColor(playerClass)
end
local currentPreset = nil
local lastTrailWanted = false
local lastRingCombat = nil
local ringStyleDirty = true
local castInfo = nil
local gcdActive = nil
local gcdStart = nil
local gcdDuration = nil
local gcdRate = nil
local crosshairEditModeRegistered = false

local trailPresets = {
	[1] = { -- LOW
		MaxActuationPoint = 1.0,
		duration = 0.4,
		Density = 0.025,
		ElementCap = 20,
	},
	[2] = { -- MEDIUM
		MaxActuationPoint = 0.7,
		duration = 0.5,
		Density = 0.02,
		ElementCap = 40,
	},
	[3] = { -- HIGH (Sweet Spot)
		MaxActuationPoint = 0.5,
		duration = 0.7,
		Density = 0.012,
		ElementCap = 80,
	},
	[4] = { -- ULTRA
		MaxActuationPoint = 0.3,
		duration = 0.7,
		Density = 0.007,
		ElementCap = 120,
	},
	[5] = { -- ULTRA HIGH
		MaxActuationPoint = 0.2,
		duration = 0.8,
		Density = 0.005,
		ElementCap = 150,
	},
}

local function createTrailElement()
	local tex = UIParent:CreateTexture(nil)
	tex:SetTexture(TEX_TRAIL)
	tex:SetBlendMode("ADD")
	tex:SetSize(35, 35)

	local ag = tex:CreateAnimationGroup()
	ag:SetScript("OnFinished", function(self)
		local t = self:GetParent()
		t:Hide()
		trailPool[#trailPool + 1] = t
		activeCount = activeCount - 1
	end)
	local fade = ag:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)

	tex.anim = ag
	tex.fade = fade

	return tex
end

local function ensureTrailPool()
	local total = activeCount + #trailPool
	if total >= ElementCap then return end
	for _ = 1, (ElementCap - total) do
		local tex = createTrailElement()
		tex:Hide()
		trailPool[#trailPool + 1] = tex
	end
end

local function applyPreset(presetName)
	local preset = trailPresets[presetName]
	if not preset then return end
	MaxActuationPoint = preset.MaxActuationPoint
	MaxActuationPointSq = MaxActuationPoint * MaxActuationPoint
	duration = preset.duration
	Density = preset.Density
	ElementCap = preset.ElementCap
	currentPreset = presetName

	if addon.db and addon.db["mouseTrailEnabled"] then ensureTrailPool() end
end
addon.Mouse.functions.applyPreset = applyPreset

local timeAccumulator = 0

local function isRingWanted(db, inCombat, rightClickActive)
	if not db or not db["mouseRingEnabled"] then return false end
	if db["mouseRingOnlyInCombat"] and not inCombat then return false end
	if db["mouseRingOnlyOnRightClick"] and not rightClickActive then return false end
	return true
end

local crosshairVisibilityAllowedRules = {
	[CROSSHAIR_RULE_ALWAYS_IN_COMBAT] = true,
	[CROSSHAIR_RULE_ALWAYS_OUT_OF_COMBAT] = true,
	[CROSSHAIR_RULE_PLAYER_CASTING] = true,
	[CROSSHAIR_RULE_PLAYER_MOUNTED] = true,
	[CROSSHAIR_RULE_PLAYER_NOT_MOUNTED] = true,
	[CROSSHAIR_RULE_PLAYER_HAS_TARGET] = true,
	[CROSSHAIR_RULE_PLAYER_IN_GROUP] = true,
	[CROSSHAIR_RULE_PLAYER_IN_PARTY] = true,
	[CROSSHAIR_RULE_PLAYER_IN_RAID] = true,
	[CROSSHAIR_RULE_PLAYER_IN_INSTANCE] = true,
	[CROSSHAIR_RULE_PLAYER_IN_PARTY_INSTANCE] = true,
	[CROSSHAIR_RULE_PLAYER_IN_RAID_INSTANCE] = true,
}

local crosshairVisibilityFallbackOptions = {
	{ value = CROSSHAIR_RULE_ALWAYS_IN_COMBAT, label = L["visibilityRule_inCombat"] or "Always in combat", order = 20 },
	{ value = CROSSHAIR_RULE_ALWAYS_OUT_OF_COMBAT, label = L["visibilityRule_outCombat"] or "Always out of combat", order = 30 },
	{ value = CROSSHAIR_RULE_PLAYER_CASTING, label = L["visibilityRule_playerCasting"] or "Player is casting", order = 35 },
	{ value = CROSSHAIR_RULE_PLAYER_MOUNTED, label = L["visibilityRule_playerMounted"] or "Mounted", order = 36 },
	{ value = CROSSHAIR_RULE_PLAYER_NOT_MOUNTED, label = L["visibilityRule_playerNotMounted"] or "Not mounted", order = 37 },
	{ value = CROSSHAIR_RULE_PLAYER_HAS_TARGET, label = L["visibilityRule_playerHasTarget"] or "When I have a target", order = 45 },
	{ value = CROSSHAIR_RULE_PLAYER_IN_GROUP, label = L["visibilityRule_inGroup"] or "In party/raid", order = 46 },
}

local crosshairVisibilityCustomOptions = {
	{ value = CROSSHAIR_RULE_PLAYER_IN_PARTY, label = L["mouseCrosshairRuleInParty"] or "In party", order = 47 },
	{ value = CROSSHAIR_RULE_PLAYER_IN_RAID, label = L["mouseCrosshairRuleInRaid"] or "In raid", order = 48 },
	{ value = CROSSHAIR_RULE_PLAYER_IN_INSTANCE, label = L["mouseCrosshairRuleInAnyInstance"] or "In any instance", order = 49 },
	{ value = CROSSHAIR_RULE_PLAYER_IN_PARTY_INSTANCE, label = L["mouseCrosshairRuleInPartyInstance"] or "In party instances (5-man)", order = 50 },
	{ value = CROSSHAIR_RULE_PLAYER_IN_RAID_INSTANCE, label = L["mouseCrosshairRuleInRaidInstance"] or "In raid instances", order = 51 },
}

local crosshairVisibilityOptionsCache

local function copyVisibilitySelection(selection)
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

local function appendCrosshairVisibilityOption(options, seen, value, label, order)
	if not value or seen[value] or not crosshairVisibilityAllowedRules[value] then return end
	options[#options + 1] = {
		value = value,
		label = label or value,
		text = label or value,
		order = order or 999,
	}
	seen[value] = true
end

local function mapLegacyCrosshairVisibility(value)
	if type(value) ~= "string" then return nil end
	if value == "ALWAYS" then return nil end
	if value == "COMBAT" then return { [CROSSHAIR_RULE_ALWAYS_IN_COMBAT] = true } end
	if value == "INSTANCE" then return { [CROSSHAIR_RULE_PLAYER_IN_PARTY_INSTANCE] = true } end
	if value == "RAID" then return { [CROSSHAIR_RULE_PLAYER_IN_RAID_INSTANCE] = true } end
	if value == "COMBAT_AND_INSTANCE" or value == "COMBAT_OR_INSTANCE" then return {
		[CROSSHAIR_RULE_ALWAYS_IN_COMBAT] = true,
		[CROSSHAIR_RULE_PLAYER_IN_PARTY_INSTANCE] = true,
	} end
	return nil
end

local function normalizeCrosshairVisibilityConfig(config, legacyValue)
	local out
	if type(config) == "table" then
		for key in pairs(crosshairVisibilityAllowedRules) do
			if config[key] == true then
				out = out or {}
				out[key] = true
			end
		end
	end

	if not out and legacyValue ~= nil then
		local legacy = mapLegacyCrosshairVisibility(legacyValue)
		if type(legacy) == "table" then
			for key in pairs(crosshairVisibilityAllowedRules) do
				if legacy[key] == true then
					out = out or {}
					out[key] = true
				end
			end
		end
	end

	if out and not next(out) then out = nil end
	return out
end

local function migrateLegacyCrosshairVisibility()
	local db = addon.db
	if not db then return end
	local normalized = normalizeCrosshairVisibilityConfig(db["mouseCrosshairShowWhen"], db["mouseCrosshairVisibility"])
	db["mouseCrosshairShowWhen"] = copyVisibilitySelection(normalized)
	if db["mouseCrosshairVisibility"] ~= nil then db["mouseCrosshairVisibility"] = nil end
end

local function getCrosshairVisibilitySelection()
	if not addon.db then return nil end
	migrateLegacyCrosshairVisibility()
	return normalizeCrosshairVisibilityConfig(addon.db["mouseCrosshairShowWhen"])
end

local function setCrosshairVisibilityRule(rule, state)
	if not addon.db or not crosshairVisibilityAllowedRules[rule] then return end
	local working = getCrosshairVisibilitySelection() or {}
	if state then
		working[rule] = true
	else
		working[rule] = nil
	end
	if not next(working) then
		addon.db["mouseCrosshairShowWhen"] = nil
	else
		addon.db["mouseCrosshairShowWhen"] = copyVisibilitySelection(working)
	end
end

local function getCrosshairVisibilityRuleOptions()
	if crosshairVisibilityOptionsCache then return crosshairVisibilityOptionsCache end
	local options = {}
	local seen = {}
	local metadata = GetVisibilityRuleMetadata and GetVisibilityRuleMetadata() or nil
	if type(metadata) == "table" then
		for key, data in pairs(metadata) do
			if crosshairVisibilityAllowedRules[key] then appendCrosshairVisibilityOption(options, seen, key, data.label or key, data.order) end
		end
	end
	for _, option in ipairs(crosshairVisibilityFallbackOptions) do
		appendCrosshairVisibilityOption(options, seen, option.value, option.label, option.order)
	end
	for _, option in ipairs(crosshairVisibilityCustomOptions) do
		appendCrosshairVisibilityOption(options, seen, option.value, option.label, option.order)
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
	crosshairVisibilityOptionsCache = options
	return options
end

local function isCrosshairRuleMatched(rule, context)
	if not context then return false end
	if rule == CROSSHAIR_RULE_ALWAYS_IN_COMBAT then return context.inCombat end
	if rule == CROSSHAIR_RULE_ALWAYS_OUT_OF_COMBAT then return not context.inCombat end
	if rule == CROSSHAIR_RULE_PLAYER_CASTING then return context.isCasting end
	if rule == CROSSHAIR_RULE_PLAYER_MOUNTED then return context.isMounted end
	if rule == CROSSHAIR_RULE_PLAYER_NOT_MOUNTED then return not context.isMounted end
	if rule == CROSSHAIR_RULE_PLAYER_HAS_TARGET then return context.hasTarget end
	if rule == CROSSHAIR_RULE_PLAYER_IN_GROUP then return context.inGroup end
	if rule == CROSSHAIR_RULE_PLAYER_IN_PARTY then return context.inParty end
	if rule == CROSSHAIR_RULE_PLAYER_IN_RAID then return context.inRaid end
	if rule == CROSSHAIR_RULE_PLAYER_IN_INSTANCE then return context.inInstance end
	if rule == CROSSHAIR_RULE_PLAYER_IN_PARTY_INSTANCE then return context.inPartyInstance end
	if rule == CROSSHAIR_RULE_PLAYER_IN_RAID_INSTANCE then return context.inRaidInstance end
	return false
end

local function buildCrosshairVisibilityContext()
	local inCombat = UnitAffectingCombat and UnitAffectingCombat(PLAYER_UNIT) and true or false
	local inGroup = IsInGroup and IsInGroup() and true or false
	local inRaid = IsInRaid and IsInRaid() and true or false
	local inParty = inGroup and not inRaid
	local inInstance, instanceType = false, nil
	if IsInInstance then
		inInstance, instanceType = IsInInstance()
	end
	local inPartyInstance = inInstance and instanceType == "party"
	local inRaidInstance = inInstance and instanceType == "raid"
	local hasTarget = UnitExists and UnitExists("target") and true or false
	local isCasting = (UnitCastingInfo and UnitCastingInfo(PLAYER_UNIT) ~= nil) or (UnitChannelInfo and UnitChannelInfo(PLAYER_UNIT) ~= nil)
	local isMounted = IsMounted and IsMounted() and true or false
	return {
		inCombat = inCombat,
		inGroup = inGroup,
		inRaid = inRaid,
		inParty = inParty,
		inInstance = inInstance and true or false,
		inPartyInstance = inPartyInstance and true or false,
		inRaidInstance = inRaidInstance and true or false,
		hasTarget = hasTarget,
		isCasting = isCasting and true or false,
		isMounted = isMounted,
	}
end

local function isCrosshairVisibilityMatch(context)
	local selection = getCrosshairVisibilitySelection()
	if not selection then return true end
	for rule in pairs(selection) do
		if selection[rule] == true and isCrosshairRuleMatched(rule, context) then return true end
	end
	return false
end

local function getTrailColor()
	if addon.db["mouseTrailUseClassColor"] then
		if not classR then
			local class = playerClass or (UnitClass and select(2, UnitClass("player")))
			if class then playerClass = class end
			if class and GetClassColor then
				classR, classG, classB = GetClassColor(class)
			end
		end
		if classR then return classR, classG, classB, 1 end
		return 1, 1, 1, 1
	end
	local c = addon.db["mouseTrailColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 1, 1, 1
end

local function getRingColor()
	if addon.db["mouseRingUseClassColor"] then
		if not classR then
			local class = playerClass or (UnitClass and select(2, UnitClass("player")))
			if class then playerClass = class end
			if class and GetClassColor then
				classR, classG, classB = GetClassColor(class)
			end
		end
		if classR then return classR, classG, classB, 1 end
		return 1, 1, 1, 1
	end
	local c = addon.db["mouseRingColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 1, 1, 1
end

local function getCrosshairColor()
	if addon.db["mouseCrosshairUseClassColor"] then
		if not classR then
			local class = playerClass or (UnitClass and select(2, UnitClass("player")))
			if class then playerClass = class end
			if class and GetClassColor then
				classR, classG, classB = GetClassColor(class)
			end
		end
		if classR then return classR, classG, classB end
		return 1, 1, 1
	end
	local c = addon.db["mouseCrosshairColor"]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function clampNumber(value, minValue, maxValue, fallback)
	local num = tonumber(value)
	if not num then num = fallback end
	if num < minValue then return minValue end
	if num > maxValue then return maxValue end
	return num
end

local function getCombatOverrideColor()
	local c = addon.db["mouseRingCombatOverrideColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 0.2, 0.2, 1
end

local function getCombatOverlayColor()
	local c = addon.db["mouseRingCombatOverlayColor"]
	if c then return c.r, c.g, c.b, c.a or 1 end
	return 1, 0.2, 0.2, 0.6
end

local function ensureCombatOverlay(frame)
	local overlay = frame.combatOverlay
	if overlay then return overlay end
	overlay = frame:CreateTexture(nil, "BACKGROUND")
	overlay:SetTexture(TEX_MOUSE)
	overlay:SetBlendMode("ADD")
	overlay:SetPoint("CENTER", frame, "CENTER", 0, 0)
	overlay:SetDrawLayer("BACKGROUND", -1)
	frame.combatOverlay = overlay
	return overlay
end

local function shouldShowCastProgress(db) return db and db["mouseRingCastProgress"] == true end

local function shouldShowCastProgressOutsideCombat(db) return db and db["mouseRingCastProgressShowOutsideCombat"] == true end

local function shouldShowGCDProgress(db) return db and db["mouseRingGCDProgress"] == true end

local function normalizeProgressStyle(value)
	if value == PROGRESS_STYLE_RING then return PROGRESS_STYLE_RING end
	return PROGRESS_STYLE_DOT
end

local function isRingProgressStyle(db) return normalizeProgressStyle(db and db["mouseRingProgressStyle"]) == PROGRESS_STYLE_RING end

local function isSwipeEdgeEnabled(db) return not (db and db["mouseRingProgressShowEdge"] == false) end

local function getProgressHideMultiplier(db)
	local pct = tonumber(db and db["mouseRingProgressHideDuringSwipe"])
	if pct == nil then pct = 35 end
	if pct < 0 then pct = 0 end
	if pct > 100 then pct = 100 end
	return pct / 100
end

local function normalizeGCDProgressMode(value)
	if value == "ELAPSED" then return "ELAPSED" end
	return "REMAINING"
end

local function colorFromTable(color, fallbackR, fallbackG, fallbackB, fallbackA)
	if type(color) == "table" then return color.r or color[1] or fallbackR, color.g or color[2] or fallbackG, color.b or color[3] or fallbackB, color.a or color[4] or fallbackA end
	return fallbackR, fallbackG, fallbackB, fallbackA
end

local function ensureProgressIndicators(frame)
	local castTick = frame.castTick
	if not castTick then
		castTick = frame:CreateTexture(nil, "OVERLAY", nil, 3)
		castTick:SetTexture(TEX_DOT)
		castTick:SetBlendMode("ADD")
		castTick:Hide()
		frame.castTick = castTick
	end

	local gcdTick = frame.gcdTick
	if not gcdTick then
		gcdTick = frame:CreateTexture(nil, "OVERLAY", nil, 2)
		gcdTick:SetTexture(TEX_DOT)
		gcdTick:SetBlendMode("ADD")
		gcdTick:Hide()
		frame.gcdTick = gcdTick
	end

	return castTick, gcdTick
end

local function createSwipeIndicator(parent, levelOffset)
	local swipe = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
	swipe:ClearAllPoints()
	swipe:SetPoint("CENTER", parent, "CENTER", 0, 0)
	swipe:SetDrawSwipe(true)
	swipe:SetDrawEdge(true)
	if swipe.SetUseCircularEdge then swipe:SetUseCircularEdge(true) end
	swipe:SetHideCountdownNumbers(true)
	if swipe.SetDrawBling then swipe:SetDrawBling(false) end
	if swipe.SetSwipeTexture then pcall(swipe.SetSwipeTexture, swipe, TEX_MOUSE) end
	swipe:SetFrameStrata("TOOLTIP")
	if swipe.SetFrameLevel and parent.GetFrameLevel then swipe:SetFrameLevel((parent:GetFrameLevel() or 0) + (levelOffset or 1)) end
	swipe:Hide()
	return swipe
end

local function ensureSwipeIndicators(frame)
	if not frame.castSwipe then frame.castSwipe = createSwipeIndicator(frame, 6) end
	if not frame.gcdSwipe then frame.gcdSwipe = createSwipeIndicator(frame, 5) end
	return frame.castSwipe, frame.gcdSwipe
end

local function applySwipeEdgeSetting(frame, enabled)
	if not frame then return end
	local castSwipe, gcdSwipe = ensureSwipeIndicators(frame)
	if castSwipe and castSwipe.SetDrawEdge and castSwipe._eqolDrawEdge ~= enabled then
		castSwipe:SetDrawEdge(enabled)
		castSwipe._eqolDrawEdge = enabled
	end
	if gcdSwipe and gcdSwipe.SetDrawEdge and gcdSwipe._eqolDrawEdge ~= enabled then
		gcdSwipe:SetDrawEdge(enabled)
		gcdSwipe._eqolDrawEdge = enabled
	end
end

local function hideSwipeIndicators(frame)
	if not frame then return end
	if frame.castSwipe then
		frame.castSwipe:Hide()
		frame.castSwipe._eqolActive = nil
	end
	if frame.gcdSwipe then
		frame.gcdSwipe:Hide()
		frame.gcdSwipe._eqolActive = nil
	end
end

local function applyRingAlphaMultiplier(frame, multiplier)
	if not frame or not frame.texture1 then return end
	if frame._eqolAppliedRingAlphaMultiplier == multiplier then return end
	local base = frame._eqolRingBaseColor
	if not base then return end
	frame.texture1:SetVertexColor(base[1], base[2], base[3], base[4] * multiplier)
	frame._eqolAppliedRingAlphaMultiplier = multiplier
end

local function hideProgressIndicators(frame)
	if not frame then return end
	if frame.castTick then frame.castTick:Hide() end
	if frame.gcdTick then frame.gcdTick:Hide() end
	hideSwipeIndicators(frame)
	applyRingAlphaMultiplier(frame, 1)
end

local function updateProgressIndicatorLayout(frame, ringSize)
	if not frame then return end
	local castTick, gcdTick = ensureProgressIndicators(frame)
	local castSwipe, gcdSwipe = ensureSwipeIndicators(frame)
	local size = tonumber(ringSize) or 70
	if size < 20 then size = 20 end
	local castTickSize = math.max(5, math.floor((size * 0.14) + 0.5))
	local gcdTickSize = math.max(4, math.floor((castTickSize * 0.8) + 0.5))
	local outerRadius = math.max(4, (size * 0.5) - (castTickSize * 0.5) - 1)
	local innerRadius = outerRadius
	if shouldShowCastProgress(addon.db) and shouldShowGCDProgress(addon.db) then innerRadius = math.max(2, outerRadius - math.max(gcdTickSize + 1, math.floor((size * 0.12) + 0.5))) end
	castTick:SetSize(castTickSize, castTickSize)
	gcdTick:SetSize(gcdTickSize, gcdTickSize)
	frame.castTickRadius = outerRadius
	frame.gcdTickRadius = innerRadius

	local castSwipeSize = size
	local gcdSwipeSize = size
	if shouldShowCastProgress(addon.db) and shouldShowGCDProgress(addon.db) then gcdSwipeSize = math.max(18, math.floor((size * 0.86) + 0.5)) end
	castSwipe:SetSize(castSwipeSize, castSwipeSize)
	gcdSwipe:SetSize(gcdSwipeSize, gcdSwipeSize)
	castSwipe:ClearAllPoints()
	castSwipe:SetPoint("CENTER", frame, "CENTER", 0, 0)
	gcdSwipe:ClearAllPoints()
	gcdSwipe:SetPoint("CENTER", frame, "CENTER", 0, 0)
	applySwipeEdgeSetting(frame, isSwipeEdgeEnabled(addon.db))
end

local function setIndicatorProgress(frame, texture, progress, radius)
	if not frame or not texture then return end
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	local angle = HALF_PI - (progress * TWO_PI)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", frame, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function getCastProgressColor()
	local db = addon.db or {}
	local c = db["mouseRingCastProgressColor"]
	if c then return colorFromTable(c, 1, 1, 1, 1) end
	return getRingColor()
end

local function getGCDProgressColor()
	local db = addon.db or {}
	return colorFromTable(db["mouseRingGCDProgressColor"], 1, 0.82, 0.2, 1)
end

local function stopCastProgress() castInfo = nil end

local function stopGCDProgress()
	gcdActive = nil
	gcdStart = nil
	gcdDuration = nil
	gcdRate = nil
end

local function shouldIgnoreCastFail(castGUID, spellId)
	if UnitChannelInfo then
		local channelName = UnitChannelInfo(PLAYER_UNIT)
		if channelName then return true end
	end
	local info = castInfo
	if not info then return false end
	if info.castGUID and castGUID then
		if not (issecretvalue and (issecretvalue(info.castGUID) or issecretvalue(castGUID))) and info.castGUID ~= castGUID then return true end
	end
	if info.spellId and spellId and info.castGUID then
		if not (issecretvalue and (issecretvalue(info.spellId) or issecretvalue(spellId))) and info.spellId ~= spellId then return true end
	end
	return false
end

local function setCastInfoFromUnit()
	local name, text, texture, startTimeMS, endTimeMS, _, _, spellId, isEmpowered, numEmpowerStages = UnitChannelInfo(PLAYER_UNIT)
	local isChannel = true
	local castGUID
	if not name then
		name, text, texture, startTimeMS, endTimeMS, _, castGUID, _, spellId = UnitCastingInfo(PLAYER_UNIT)
		isChannel = false
		isEmpowered = nil
		numEmpowerStages = nil
	end
	if not name then
		stopCastProgress()
		return
	end

	local isEmpoweredCast = isChannel and (issecretvalue and not issecretvalue(isEmpowered)) and isEmpowered and numEmpowerStages and numEmpowerStages > 0
	if isEmpoweredCast and startTimeMS and endTimeMS and (not issecretvalue or (not issecretvalue(startTimeMS) and not issecretvalue(endTimeMS))) then
		local UFHelper = addon.Aura and addon.Aura.UFHelper
		local totalMs = UFHelper and UFHelper.getEmpoweredChannelDurationMilliseconds and UFHelper.getEmpoweredChannelDurationMilliseconds(PLAYER_UNIT)
		if totalMs and totalMs > 0 and (not issecretvalue or not issecretvalue(totalMs)) then
			endTimeMS = startTimeMS + totalMs
		else
			local hold = UFHelper and UFHelper.getEmpowerHoldMilliseconds and UFHelper.getEmpowerHoldMilliseconds(PLAYER_UNIT)
			if hold and (not issecretvalue or not issecretvalue(hold)) then endTimeMS = endTimeMS + hold end
		end
	end

	if issecretvalue and ((startTimeMS and issecretvalue(startTimeMS)) or (endTimeMS and issecretvalue(endTimeMS))) then
		stopCastProgress()
		return
	end
	local castDuration = (endTimeMS or 0) - (startTimeMS or 0)
	if not castDuration or castDuration <= 0 then
		stopCastProgress()
		return
	end

	castInfo = {
		name = text or name,
		texture = texture,
		startTime = startTimeMS,
		endTime = endTimeMS,
		isChannel = isChannel,
		isEmpowered = isEmpowered,
		numEmpowerStages = numEmpowerStages,
		castGUID = castGUID,
		spellId = spellId,
	}
end

local function updateGCDProgressState()
	if not GetSpellCooldownInfo then
		stopGCDProgress()
		return
	end

	local start, durationValue, enabled, modRate
	local info, info2, info3, info4 = GetSpellCooldownInfo(GCD_SPELL_ID)
	if type(info) == "table" then
		start = info.startTime
		durationValue = info.duration
		enabled = info.isEnabled
		modRate = info.modRate or 1
	else
		start, durationValue, enabled, modRate = info, info2, info3, info4
	end
	if not enabled or not durationValue or durationValue <= 0 or not start or start <= 0 then
		stopGCDProgress()
		return
	end

	gcdActive = true
	gcdStart = start
	gcdDuration = durationValue
	gcdRate = modRate or 1
end

local function syncRingProgressState()
	local db = addon.db
	if not db or db["mouseRingEnabled"] ~= true then
		stopCastProgress()
		stopGCDProgress()
		hideProgressIndicators(addon.mousePointer)
		return
	end
	if shouldShowCastProgress(db) then
		setCastInfoFromUnit()
	else
		stopCastProgress()
	end
	if shouldShowGCDProgress(db) then
		updateGCDProgressState()
	else
		stopGCDProgress()
	end
end
addon.Mouse.functions.syncRingProgressState = syncRingProgressState

local function getCastProgressValue(nowMs)
	local info = castInfo
	if not info then return nil end
	if not info.startTime or not info.endTime then
		stopCastProgress()
		return nil
	end
	if issecretvalue and (issecretvalue(info.startTime) or issecretvalue(info.endTime)) then
		stopCastProgress()
		return nil
	end

	local startMs = info.startTime or 0
	local endMs = info.endTime or 0
	local durationMs = endMs - startMs
	if not durationMs or durationMs <= 0 then
		stopCastProgress()
		return nil
	end
	if nowMs >= endMs then
		stopCastProgress()
		return nil
	end

	local elapsedMs
	if info.isEmpowered then
		elapsedMs = nowMs - startMs
	else
		elapsedMs = info.isChannel and (endMs - nowMs) or (nowMs - startMs)
	end
	if elapsedMs < 0 then elapsedMs = 0 end
	local progress = elapsedMs / durationMs
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	return progress, info
end

local function getGCDProgressValue(now)
	if not gcdActive then return nil end
	local start = gcdStart
	local durationValue = gcdDuration
	if not start or not durationValue or durationValue <= 0 then
		stopGCDProgress()
		return nil
	end
	local rate = gcdRate or 1
	local elapsed = (now - start) * rate
	if elapsed >= durationValue then
		stopGCDProgress()
		return nil
	end
	local progress = elapsed / durationValue
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	if normalizeGCDProgressMode(addon.db and addon.db["mouseRingGCDProgressMode"]) ~= "ELAPSED" then progress = 1 - progress end
	return progress
end

local function isCastProgressOutsideCombatWanted(db, inCombat, rightClickActive)
	if not db or db["mouseRingEnabled"] ~= true then return false end
	if inCombat or db["mouseRingOnlyInCombat"] ~= true then return false end
	if not shouldShowCastProgress(db) or not shouldShowCastProgressOutsideCombat(db) then return false end
	if db["mouseRingOnlyOnRightClick"] and not rightClickActive then return false end
	local nowMs = (GetTime and GetTime() or 0) * 1000
	local progress = getCastProgressValue(nowMs)
	return progress ~= nil
end

local function isRingDisplayWanted(db, inCombat, rightClickActive)
	if isRingWanted(db, inCombat, rightClickActive) then return true end
	return isCastProgressOutsideCombatWanted(db, inCombat, rightClickActive)
end

local function setSwipeIndicatorState(indicator, active, startTime, durationValue, modRate, reverse, r, g, b, a)
	if not indicator then return false end
	if not active then
		if indicator:IsShown() then indicator:Hide() end
		indicator._eqolActive = nil
		return false
	end

	reverse = reverse and true or false
	if indicator.SetReverse and indicator._eqolReverse ~= reverse then
		indicator:SetReverse(reverse)
		indicator._eqolReverse = reverse
	end

	if indicator.SetSwipeColor then
		local lastR, lastG, lastB, lastA = indicator._eqolColorR, indicator._eqolColorG, indicator._eqolColorB, indicator._eqolColorA
		if lastR ~= r or lastG ~= g or lastB ~= b or lastA ~= a then
			indicator:SetSwipeColor(r, g, b, a)
			indicator._eqolColorR, indicator._eqolColorG, indicator._eqolColorB, indicator._eqolColorA = r, g, b, a
		end
	end

	local normalizedRate = tonumber(modRate) or 1
	local needsCooldown = indicator._eqolActive ~= true or indicator._eqolStart ~= startTime or indicator._eqolDuration ~= durationValue or indicator._eqolRate ~= normalizedRate

	if needsCooldown and indicator.SetCooldown then
		if normalizedRate ~= 1 then
			indicator:SetCooldown(startTime, durationValue, normalizedRate)
		else
			indicator:SetCooldown(startTime, durationValue)
		end
		indicator._eqolStart = startTime
		indicator._eqolDuration = durationValue
		indicator._eqolRate = normalizedRate
	end

	indicator._eqolActive = true
	if not indicator:IsShown() then indicator:Show() end
	return true
end

local function updateRingProgressIndicators()
	local db = addon.db
	local frame = addon.mousePointer
	if not db or not frame or not db["mouseRingEnabled"] then
		hideProgressIndicators(frame)
		return
	end
	local castEnabled = shouldShowCastProgress(db)
	local gcdEnabled = shouldShowGCDProgress(db)
	if not castEnabled and not gcdEnabled then
		hideProgressIndicators(frame)
		return
	end

	local now = GetTime and GetTime() or 0
	local nowMs = now * 1000
	local ringStyle = isRingProgressStyle(db)
	local swipeVisible = false

	if ringStyle then
		local castSwipe, gcdSwipe = ensureSwipeIndicators(frame)
		applySwipeEdgeSetting(frame, isSwipeEdgeEnabled(db))
		if frame.castTick then frame.castTick:Hide() end
		if frame.gcdTick then frame.gcdTick:Hide() end

		if castEnabled then
			local progress, info = getCastProgressValue(nowMs)
			if progress ~= nil and info and info.startTime and info.endTime then
				local castDuration = (info.endTime - info.startTime) / 1000
				local castStart = info.startTime / 1000
				if castDuration and castDuration > 0 then
					local r, g, b, a = getCastProgressColor()
					local castReverse = (info.isEmpowered == true) or (info.isChannel ~= true)
					local castActive = setSwipeIndicatorState(castSwipe, true, castStart, castDuration, 1, castReverse, r, g, b, a)
					if castActive then swipeVisible = true end
				else
					setSwipeIndicatorState(castSwipe, false)
				end
			else
				setSwipeIndicatorState(castSwipe, false)
			end
		else
			setSwipeIndicatorState(castSwipe, false)
		end

		if gcdEnabled then
			local progress = getGCDProgressValue(now)
			if progress ~= nil and gcdStart and gcdDuration and gcdDuration > 0 then
				local r, g, b, a = getGCDProgressColor()
				local reverse = normalizeGCDProgressMode(db["mouseRingGCDProgressMode"]) == "ELAPSED"
				local gcdShown = setSwipeIndicatorState(gcdSwipe, true, gcdStart, gcdDuration, gcdRate, reverse, r, g, b, a)
				if gcdShown then swipeVisible = true end
			else
				setSwipeIndicatorState(gcdSwipe, false)
			end
		else
			setSwipeIndicatorState(gcdSwipe, false)
		end
	else
		ensureProgressIndicators(frame)
		hideSwipeIndicators(frame)

		if castEnabled then
			local progress = getCastProgressValue(nowMs)
			if progress ~= nil then
				local r, g, b, a = getCastProgressColor()
				frame.castTick:SetVertexColor(r, g, b, a)
				setIndicatorProgress(frame, frame.castTick, progress, frame.castTickRadius or 0)
				frame.castTick:Show()
			else
				frame.castTick:Hide()
			end
		elseif frame.castTick then
			frame.castTick:Hide()
		end

		if gcdEnabled then
			local progress = getGCDProgressValue(now)
			if progress ~= nil then
				local r, g, b, a = getGCDProgressColor()
				frame.gcdTick:SetVertexColor(r, g, b, a)
				setIndicatorProgress(frame, frame.gcdTick, progress, frame.gcdTickRadius or 0)
				frame.gcdTick:Show()
			else
				frame.gcdTick:Hide()
			end
		elseif frame.gcdTick then
			frame.gcdTick:Hide()
		end
	end

	if ringStyle and swipeVisible then
		applyRingAlphaMultiplier(frame, 1 - getProgressHideMultiplier(db))
	else
		applyRingAlphaMultiplier(frame, 1)
	end
end
addon.Mouse.functions.updateRingProgressIndicators = updateRingProgressIndicators

local function markRingStyleDirty() ringStyleDirty = true end
addon.Mouse.functions.markRingStyleDirty = markRingStyleDirty

local function applyRingStyle(inCombat)
	if not addon.db or not addon.mousePointer or not addon.mousePointer.texture1 then return end
	local db = addon.db
	local ringFrame = addon.mousePointer
	local combatActive = inCombat and true or false

	local size = db["mouseRingSize"] or 70
	local r, g, b, a = getRingColor()

	if combatActive and db["mouseRingCombatOverride"] then
		size = db["mouseRingCombatOverrideSize"] or size
		r, g, b, a = getCombatOverrideColor()
	end

	ringFrame._eqolRingBaseColor = ringFrame._eqolRingBaseColor or {}
	ringFrame._eqolRingBaseColor[1] = r
	ringFrame._eqolRingBaseColor[2] = g
	ringFrame._eqolRingBaseColor[3] = b
	ringFrame._eqolRingBaseColor[4] = a
	ringFrame._eqolAppliedRingAlphaMultiplier = nil
	ringFrame.texture1:SetSize(size, size)
	ringFrame.texture1:SetVertexColor(r, g, b, a)
	updateProgressIndicatorLayout(ringFrame, size)

	if combatActive and db["mouseRingCombatOverlay"] then
		local overlay = ensureCombatOverlay(ringFrame)
		local overlaySize = db["mouseRingCombatOverlaySize"] or size
		local orr, org, orb, ora = getCombatOverlayColor()
		overlay:SetSize(overlaySize, overlaySize)
		overlay:SetVertexColor(orr, org, orb, ora)
		overlay:Show()
	elseif ringFrame.combatOverlay then
		ringFrame.combatOverlay:Hide()
	end
end
addon.Mouse.functions.applyRingStyle = applyRingStyle

local function refreshRingStyle(inCombat)
	ringStyleDirty = true
	if not addon.mousePointer then return end
	if inCombat == nil and UnitAffectingCombat then inCombat = UnitAffectingCombat("player") and true or false end
	applyRingStyle(inCombat)
	updateRingProgressIndicators()
	ringStyleDirty = false
	lastRingCombat = inCombat and true or false
end
addon.Mouse.functions.refreshRingStyle = refreshRingStyle

local function isCrosshairWanted(db, context)
	if not db then return false end
	if db["mouseCrosshairEnabled"] ~= true then return false end
	if addon.EditMode and addon.EditMode.IsInEditMode and addon.EditMode:IsInEditMode() then return true end
	return isCrosshairVisibilityMatch(context)
end

local function refreshCrosshairEditModeSettingsUI()
	local lib = addon.EditModeLib
	if lib and lib.internal and lib.internal.RefreshSettings then lib.internal:RefreshSettings() end
	if lib and lib.internal and lib.internal.RefreshSettingValues then lib.internal:RefreshSettingValues() end
end

local function ensureCrosshairFrame()
	local frame = addon.mouseCrosshair or _G[CROSSHAIR_FRAME_NAME]
	if not frame then
		frame = CreateFrame("Frame", CROSSHAIR_FRAME_NAME, UIParent)
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		frame:SetFrameStrata("MEDIUM")
		frame:EnableMouse(false)
		if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
	end

	if not frame.outerVertical then
		local outerVertical = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
		outerVertical:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame.outerVertical = outerVertical

		local outerHorizontal = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
		outerHorizontal:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame.outerHorizontal = outerHorizontal

		local innerVertical = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
		innerVertical:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame.innerVertical = innerVertical

		local innerHorizontal = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
		innerHorizontal:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame.innerHorizontal = innerHorizontal
	end

	addon.mouseCrosshair = frame
	return frame
end

local function applyCrosshairStyle(frame)
	if not frame or not addon.db then return end
	local db = addon.db
	local thickness = clampNumber(db["mouseCrosshairThickness"], 1, 32, 4)
	local length = clampNumber(db["mouseCrosshairLength"], 4, 256, 24)
	local border = clampNumber(db["mouseCrosshairBorderSize"], 0, 64, 4)
	local alpha = clampNumber(db["mouseCrosshairAlpha"], 0, 1, 1)

	frame:SetSize(length + thickness + border, length + thickness + border)
	frame.innerVertical:SetSize(thickness, length)
	frame.innerHorizontal:SetSize(length, thickness)
	frame.outerVertical:SetSize(thickness + border, length + border)
	frame.outerHorizontal:SetSize(length + border, thickness + border)

	local r, g, b = getCrosshairColor()
	frame.innerVertical:SetColorTexture(r, g, b, alpha)
	frame.innerHorizontal:SetColorTexture(r, g, b, alpha)
	frame.outerVertical:SetColorTexture(0, 0, 0, alpha)
	frame.outerHorizontal:SetColorTexture(0, 0, 0, alpha)
end

local refreshCrosshairStyle
local refreshCrosshairVisibility

local function registerCrosshairWithEditMode(frame)
	if crosshairEditModeRegistered then return end
	if not EditMode or not EditMode.RegisterFrame then return end
	local settingsList
	if SettingType then
		local visibilityRuleOptions = getCrosshairVisibilityRuleOptions()
		settingsList = {
			{
				name = L["Frame"] or "Frame",
				kind = SettingType.Collapsible,
				id = "crosshairFrame",
				defaultCollapsed = false,
			},
			{
				name = L["mouseCrosshairShowWhen"] or "Show when",
				kind = SettingType.MultiDropdown,
				field = "showWhen",
				parentId = "crosshairFrame",
				height = 220,
				values = visibilityRuleOptions,
				hideSummary = true,
				default = getCrosshairVisibilitySelection(),
				isSelected = function(_, value)
					local selection = getCrosshairVisibilitySelection()
					return selection and selection[value] == true or false
				end,
				setSelected = function(_, value, state)
					setCrosshairVisibilityRule(value, state and true or false)
					refreshCrosshairVisibility()
				end,
				isShown = function() return visibilityRuleOptions and #visibilityRuleOptions > 0 end,
				isEnabled = function() return visibilityRuleOptions and #visibilityRuleOptions > 0 end,
			},
			{
				name = L["mouseCrosshairAnchorPoint"] or "Anchor point",
				kind = SettingType.Dropdown,
				field = "point",
				parentId = "crosshairFrame",
				values = CROSSHAIR_ANCHOR_OPTIONS,
				height = 180,
				default = "CENTER",
			},
			{
				name = L["mouseCrosshairRelativePoint"] or "Relative point",
				kind = SettingType.Dropdown,
				field = "relativePoint",
				parentId = "crosshairFrame",
				values = CROSSHAIR_ANCHOR_OPTIONS,
				height = 180,
				default = "CENTER",
			},
			{
				name = L["mouseCrosshairOffsetX"] or "Offset X",
				kind = SettingType.Slider,
				field = "x",
				parentId = "crosshairFrame",
				allowInput = true,
				minValue = -4000,
				maxValue = 4000,
				valueStep = 1,
				default = 0,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["mouseCrosshairOffsetY"] or "Offset Y",
				kind = SettingType.Slider,
				field = "y",
				parentId = "crosshairFrame",
				allowInput = true,
				minValue = -4000,
				maxValue = 4000,
				valueStep = 1,
				default = 0,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["mouseCrosshairThickness"] or "Crosshair thickness",
				kind = SettingType.Slider,
				parentId = "crosshairFrame",
				allowInput = true,
				minValue = 1,
				maxValue = 32,
				valueStep = 1,
				default = 4,
				get = function() return addon.db and addon.db["mouseCrosshairThickness"] or 4 end,
				set = function(_, value)
					if not addon.db then return end
					addon.db["mouseCrosshairThickness"] = value
					refreshCrosshairStyle()
				end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["mouseCrosshairLength"] or "Crosshair inner length",
				kind = SettingType.Slider,
				parentId = "crosshairFrame",
				allowInput = true,
				minValue = 4,
				maxValue = 256,
				valueStep = 1,
				default = 24,
				get = function() return addon.db and addon.db["mouseCrosshairLength"] or 24 end,
				set = function(_, value)
					if not addon.db then return end
					addon.db["mouseCrosshairLength"] = value
					refreshCrosshairStyle()
				end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["mouseCrosshairBorderSize"] or "Crosshair border size",
				kind = SettingType.Slider,
				parentId = "crosshairFrame",
				allowInput = true,
				minValue = 0,
				maxValue = 64,
				valueStep = 1,
				default = 4,
				get = function() return addon.db and addon.db["mouseCrosshairBorderSize"] or 4 end,
				set = function(_, value)
					if not addon.db then return end
					addon.db["mouseCrosshairBorderSize"] = value
					refreshCrosshairStyle()
				end,
				formatter = function(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end,
			},
			{
				name = L["mouseCrosshairAlpha"] or "Crosshair opacity",
				kind = SettingType.Slider,
				parentId = "crosshairFrame",
				allowInput = true,
				minValue = 0,
				maxValue = 1,
				valueStep = 0.05,
				default = 1,
				get = function() return addon.db and addon.db["mouseCrosshairAlpha"] or 1 end,
				set = function(_, value)
					if not addon.db then return end
					addon.db["mouseCrosshairAlpha"] = value
					refreshCrosshairStyle()
				end,
				formatter = function(value) return string.format("%.2f", tonumber(value) or 0) end,
			},
			{
				name = L["mouseCrosshairUseClassColor"] or "Use class color for crosshair",
				kind = SettingType.Checkbox,
				parentId = "crosshairFrame",
				default = true,
				get = function() return addon.db and addon.db["mouseCrosshairUseClassColor"] ~= false end,
				set = function(_, value)
					if not addon.db then return end
					addon.db["mouseCrosshairUseClassColor"] = value and true or false
					refreshCrosshairStyle()
					refreshCrosshairEditModeSettingsUI()
				end,
			},
			{
				name = L["mouseCrosshairColor"] or "Crosshair color",
				kind = SettingType.Color,
				parentId = "crosshairFrame",
				hasOpacity = false,
				get = function()
					local color = (addon.db and addon.db["mouseCrosshairColor"]) or { r = 1, g = 1, b = 1, a = 1 }
					return { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = 1 }
				end,
				set = function(_, value)
					if not addon.db then return end
					addon.db["mouseCrosshairColor"] = {
						r = value and value.r or 1,
						g = value and value.g or 1,
						b = value and value.b or 1,
						a = 1,
					}
					refreshCrosshairStyle()
				end,
				isEnabled = function() return addon.db and addon.db["mouseCrosshairUseClassColor"] ~= true end,
			},
		}
	end
	EditMode:RegisterFrame(CROSSHAIR_EDITMODE_ID, {
		frame = frame,
		title = L["mouseCrosshairTitle"] or "Crosshair",
		layoutDefaults = {
			point = "CENTER",
			relativePoint = "CENTER",
			x = 0,
			y = 0,
		},
		isEnabled = function()
			local db = addon.db
			if addon.EditMode and addon.EditMode.IsInEditMode and addon.EditMode:IsInEditMode() then return true end
			if not db then return false end
			return isCrosshairWanted(db, buildCrosshairVisibilityContext())
		end,
		showOutsideEditMode = true,
		onApply = function(targetFrame) applyCrosshairStyle(targetFrame) end,
		settings = settingsList,
	})
	crosshairEditModeRegistered = true
end

refreshCrosshairStyle = function()
	local frame = addon.mouseCrosshair
	if not frame then return end
	applyCrosshairStyle(frame)
	if crosshairEditModeRegistered and addon.EditMode and addon.EditMode.RefreshFrame then addon.EditMode:RefreshFrame(CROSSHAIR_EDITMODE_ID) end
end
addon.Mouse.functions.refreshCrosshairStyle = refreshCrosshairStyle

refreshCrosshairVisibility = function()
	local db = addon.db
	if not db then return false end
	migrateLegacyCrosshairVisibility()
	local enabled = db["mouseCrosshairEnabled"] == true
	local frame = addon.mouseCrosshair or _G[CROSSHAIR_FRAME_NAME]
	if not enabled then
		if crosshairEditModeRegistered and addon.EditMode and addon.EditMode.UnregisterFrame then
			addon.EditMode:UnregisterFrame(CROSSHAIR_EDITMODE_ID, false)
			crosshairEditModeRegistered = false
		end
		if frame then frame:Hide() end
		return false
	end

	frame = ensureCrosshairFrame()
	registerCrosshairWithEditMode(frame)
	applyCrosshairStyle(frame)

	if crosshairEditModeRegistered and addon.EditMode and addon.EditMode.RefreshFrame then
		addon.EditMode:RefreshFrame(CROSSHAIR_EDITMODE_ID)
		return frame:IsShown()
	end

	local shouldShow = isCrosshairWanted(db, buildCrosshairVisibilityContext())
	if shouldShow then
		frame:Show()
	else
		frame:Hide()
	end
	return shouldShow
end
addon.Mouse.functions.refreshCrosshairVisibility = refreshCrosshairVisibility

local function UpdateMouseTrail(delta, cursorX, cursorY, effectiveScale)
	-- Delta = Zeit seit letztem Frame

	-- Ersten Maus-Frame sauber initialisieren
	if PresentCursorX == nil then
		PresentCursorX, PresentCursorY = cursorX, cursorY
		return -- Startposition gesetzt
	end

	-- Zeit hochzählen
	timeAccumulator = timeAccumulator + delta

	-- Aktuelle Mausposition holen, Distanz ermitteln
	PastCursorX, PastCursorY = PresentCursorX, PresentCursorY
	PresentCursorX, PresentCursorY = cursorX, cursorY

	local dx = PresentCursorX - PastCursorX
	local dy = PresentCursorY - PastCursorY
	local distanceSq = dx * dx + dy * dy

	-- Neues Trail-Element anlegen?
	if timeAccumulator >= Density and distanceSq >= MaxActuationPointSq then
		timeAccumulator = timeAccumulator - Density

		if activeCount < ElementCap and #trailPool > 0 then
			local element = trailPool[#trailPool]
			trailPool[#trailPool] = nil
			activeCount = activeCount + 1

			element:SetPoint("CENTER", UIParent, "BOTTOMLEFT", PresentCursorX / effectiveScale, PresentCursorY / effectiveScale)

			local r, g, b, a = getTrailColor()
			element:SetVertexColor(r, g, b, a)

			element.fade:SetDuration(duration)
			element.anim:Stop()
			element.anim:Play()
			element:Show()
		end
	end
end

local function createMouseRing(inCombat)
	if addon.mousePointer then
		addon.mousePointer:Show()
		if addon.Mouse.functions.refreshRingStyle then addon.Mouse.functions.refreshRingStyle(inCombat) end
		updateRingProgressIndicators()
		return
	end

	local imageFrame = _G[RING_FRAME_NAME]
	if not imageFrame then
		imageFrame = CreateFrame("Frame", RING_FRAME_NAME, UIParent, "BackdropTemplate")
		imageFrame:SetSize(120, 120)
		imageFrame:SetBackdropColor(0, 0, 0, 0)
		imageFrame:SetFrameStrata("TOOLTIP")
	end

	local texture1 = imageFrame.texture1
	if not texture1 then
		texture1 = imageFrame:CreateTexture(nil, "BACKGROUND")
		texture1:SetTexture(TEX_MOUSE)
		texture1:SetPoint("CENTER", imageFrame, "CENTER", 0, 0)
		imageFrame.texture1 = texture1
	end
	ensureProgressIndicators(imageFrame)

	if addon.db["mouseRingHideDot"] then
		if imageFrame.dot then imageFrame.dot:Hide() end
	else
		local dot = imageFrame.dot
		if not dot then
			dot = imageFrame:CreateTexture(nil, "BACKGROUND")
			dot:SetTexture(TEX_DOT)
			dot:SetSize(10, 10)
			dot:SetPoint("CENTER", imageFrame, "CENTER", 0, 0)
			imageFrame.dot = dot
		end
		dot:Show()
	end

	addon.mousePointer = imageFrame
	if addon.Mouse.functions.refreshRingStyle then addon.Mouse.functions.refreshRingStyle(inCombat) end
	updateRingProgressIndicators()
	imageFrame:Show()
end
addon.Mouse.functions.createMouseRing = createMouseRing

local function removeMouseRing()
	if addon.mousePointer then
		hideProgressIndicators(addon.mousePointer)
		addon.mousePointer:Hide()
	end
end
addon.Mouse.functions.removeMouseRing = removeMouseRing

local function updateRunnerState()
	if not addon.mouseTrailRunner then return end
	local db = addon.db
	local shouldRun = db and (db["mouseRingEnabled"] or db["mouseTrailEnabled"])
	if shouldRun then
		if addon.mouseTrailRunner:GetScript("OnUpdate") == nil then addon.mouseTrailRunner:SetScript("OnUpdate", addon.Mouse.functions.runMouseRunner) end
	elseif addon.mouseTrailRunner:GetScript("OnUpdate") ~= nil then
		addon.mouseTrailRunner:SetScript("OnUpdate", nil)
	end
end
addon.Mouse.functions.updateRunnerState = updateRunnerState

local function refreshRingVisibility()
	local db = addon.db
	if not db then return false end
	local ringOnly = db["mouseRingOnlyInCombat"]
	local combatOverride = db["mouseRingCombatOverride"]
	local combatOverlay = db["mouseRingCombatOverlay"]
	local inCombat = false
	if ringOnly or combatOverride or combatOverlay then inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false end
	local rightClickActive = db["mouseRingOnlyOnRightClick"] and IsMouseButtonDown and IsMouseButtonDown("RightButton")
	local ringWanted = isRingDisplayWanted(db, inCombat, rightClickActive)

	if ringWanted then
		if not addon.mousePointer then createMouseRing(inCombat) end
		if addon.mousePointer and not addon.mousePointer:IsShown() then addon.mousePointer:Show() end
		if ringStyleDirty or lastRingCombat ~= inCombat then
			applyRingStyle(inCombat)
			ringStyleDirty = false
			lastRingCombat = inCombat
		end
		updateRingProgressIndicators()
	elseif addon.mousePointer and addon.mousePointer:IsShown() then
		hideProgressIndicators(addon.mousePointer)
		addon.mousePointer:Hide()
	end

	return ringWanted
end
addon.Mouse.functions.refreshRingVisibility = refreshRingVisibility

function addon.Mouse.functions.InitState()
	local db = addon.db
	if not db then return end
	syncRingProgressState()
	refreshRingVisibility()
	refreshCrosshairVisibility()
	if db["mouseTrailEnabled"] then applyPreset(db["mouseTrailDensity"]) end
	updateRunnerState()
end

local function handleProgressEvent(event, unit, ...)
	if event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
		if addon.db and addon.db["mouseRingEnabled"] and shouldShowGCDProgress(addon.db) then
			updateGCDProgressState()
		else
			stopGCDProgress()
		end
		return
	end

	if not addon.db or addon.db["mouseRingEnabled"] ~= true or not shouldShowCastProgress(addon.db) then
		stopCastProgress()
		return
	end
	if unit ~= PLAYER_UNIT then return end

	if
		event == "UNIT_SPELLCAST_START"
		or event == "UNIT_SPELLCAST_CHANNEL_START"
		or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
		or event == "UNIT_SPELLCAST_EMPOWER_START"
		or event == "UNIT_SPELLCAST_EMPOWER_UPDATE"
		or event == "UNIT_SPELLCAST_DELAYED"
	then
		setCastInfoFromUnit()
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
		local castGUID, spellId = ...
		if not shouldIgnoreCastFail(castGUID, spellId) then stopCastProgress() end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
		stopCastProgress()
	end
end

-- Manage visibility of the ring based on combat state
local eventFrame = CreateFrame("Frame")
local crosshairContextRefreshEvents = {
	PLAYER_TARGET_CHANGED = true,
	GROUP_ROSTER_UPDATE = true,
	PLAYER_MOUNT_DISPLAY_CHANGED = true,
	UPDATE_SHAPESHIFT_FORM = true,
	UNIT_SPELLCAST_START = true,
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_CHANNEL_START = true,
	UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_EMPOWER_START = true,
	UNIT_SPELLCAST_EMPOWER_STOP = true,
}
local ringProgressEvents = {
	SPELL_UPDATE_COOLDOWN = true,
	ACTIONBAR_UPDATE_COOLDOWN = true,
	UNIT_SPELLCAST_SENT = true,
	UNIT_SPELLCAST_START = true,
	UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true,
	UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_CHANNEL_START = true,
	UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_CHANNEL_UPDATE = true,
	UNIT_SPELLCAST_EMPOWER_START = true,
	UNIT_SPELLCAST_EMPOWER_UPDATE = true,
	UNIT_SPELLCAST_DELAYED = true,
	UNIT_SPELLCAST_EMPOWER_STOP = true,
}
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- enter combat
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED") -- leave combat
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_START", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_UPDATE", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", PLAYER_UNIT)
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_EMPOWER_STOP", PLAYER_UNIT)
eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
	if not addon.db then return end
	if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
		syncRingProgressState()
		refreshRingVisibility()
		refreshCrosshairVisibility()
		return
	end
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "ZONE_CHANGED_NEW_AREA" then
		refreshRingVisibility()
		refreshCrosshairVisibility()
		return
	end
	if crosshairContextRefreshEvents[event] then refreshCrosshairVisibility() end
	if ringProgressEvents[event] then handleProgressEvent(event, unit, ...) end
end)

-- Shared runner for ring + trail updates
if not addon.mouseTrailRunner then
	local runner = CreateFrame("Frame")
	addon.Mouse.functions.runMouseRunner = function(self, delta)
		local db = addon.db
		if not db then
			self:SetScript("OnUpdate", nil)
			return
		end
		if not db["mouseRingEnabled"] and not db["mouseTrailEnabled"] then
			self:SetScript("OnUpdate", nil)
			return
		end
		local ringOnly = db["mouseRingOnlyInCombat"]
		local trailOnly = db["mouseTrailOnlyInCombat"]
		local rightClickOnly = db["mouseRingOnlyOnRightClick"]
		local combatOverride = db["mouseRingCombatOverride"]
		local combatOverlay = db["mouseRingCombatOverlay"]
		local inCombat = false
		if ringOnly or trailOnly or combatOverride or combatOverlay then inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false end
		local rightClickActive = rightClickOnly and IsMouseButtonDown and IsMouseButtonDown("RightButton")
		local ringWanted = isRingDisplayWanted(db, inCombat, rightClickActive)
		local trailWanted = db["mouseTrailEnabled"] and (not trailOnly or inCombat)
		if trailWanted and currentPreset ~= db["mouseTrailDensity"] then applyPreset(db["mouseTrailDensity"]) end
		if trailWanted and not lastTrailWanted then
			ensureTrailPool()
			PresentCursorX, PresentCursorY = nil, nil
			timeAccumulator = 0
		end
		lastTrailWanted = trailWanted

		if ringWanted then
			if not addon.mousePointer then createMouseRing(inCombat) end
			if addon.mousePointer and not addon.mousePointer:IsShown() then addon.mousePointer:Show() end
			if ringStyleDirty or lastRingCombat ~= inCombat then
				applyRingStyle(inCombat)
				ringStyleDirty = false
				lastRingCombat = inCombat
			end
		elseif addon.mousePointer and addon.mousePointer:IsShown() then
			hideProgressIndicators(addon.mousePointer)
			addon.mousePointer:Hide()
		end

		if not ringWanted and not trailWanted then return end
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		if ringWanted and addon.mousePointer and addon.mousePointer:IsShown() then
			addon.mousePointer:ClearAllPoints()
			addon.mousePointer:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
			updateRingProgressIndicators()
		end
		if trailWanted then UpdateMouseTrail(delta, x, y, scale) end
	end
	addon.mouseTrailRunner = runner
	updateRunnerState()
end
