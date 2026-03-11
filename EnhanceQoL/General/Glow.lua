local parentAddonName = "EnhanceQoL"
local addon = select(2, ...)

if _G[parentAddonName] then
	addon = _G[parentAddonName]
else
	error(parentAddonName .. " is not loaded")
end

addon.Glow = addon.Glow or {}
local Glow = addon.Glow

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
local ceil = math.ceil
local floor = math.floor
local max = math.max
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local type = type

Glow.STYLE = Glow.STYLE or {}
Glow.STYLE.BLIZZARD = "BLIZZARD"
Glow.STYLE.MARCHING_ANTS = "MARCHING_ANTS"
Glow.STYLE.FLASH = "FLASH"
Glow.STYLE.BUTTON = "BUTTON"
Glow.STYLE.PIXEL = "PIXEL"
Glow.STYLE.SHINE = "SHINE"
Glow.STYLE.PROC = "PROC"
Glow.STYLE.AUTOCAST = Glow.STYLE.SHINE

local BLIZZARD_GLOW_TEXTURE = [[Interface\SpellActivationOverlay\IconAlert]]
local MARCHING_ANTS_ATLAS = "VisualAlert_Ants_Flipbook"
local FLASH_GLOW_ATLAS = "UI-CooldownManager-VisualAlert-Glow"

local VALID_STRATA = {
	BACKGROUND = true,
	LOW = true,
	MEDIUM = true,
	HIGH = true,
	DIALOG = true,
	FULLSCREEN = true,
	FULLSCREEN_DIALOG = true,
	TOOLTIP = true,
}

local function normalizeColor(color, fallback)
	fallback = fallback or { 1, 1, 1, 1 }
	if type(color) ~= "table" then return fallback end
	return {
		tonumber(color.r or color[1]) or fallback[1],
		tonumber(color.g or color[2]) or fallback[2],
		tonumber(color.b or color[3]) or fallback[3],
		tonumber(color.a or color[4]) or fallback[4],
	}
end

local function normalizeKey(key)
	if key == nil then return "" end
	return tostring(key)
end

local function normalizeStyle(style)
	local normalized = tostring(style or Glow.STYLE.BLIZZARD):upper()
	if normalized == "BLIZZARD" then return Glow.STYLE.BLIZZARD end
	if normalized == "MARCHING_ANTS" or normalized == "MARCHINGANTS" or normalized == "ANTS" then return Glow.STYLE.MARCHING_ANTS end
	if normalized == "FLASH" then return Glow.STYLE.FLASH end
	if normalized == "BUTTON" then return Glow.STYLE.BUTTON end
	if normalized == "PIXEL" then return Glow.STYLE.PIXEL end
	if normalized == "SHINE" or normalized == "AUTOCAST" or normalized == "AUTOCAST_SHINE" then return Glow.STYLE.SHINE end
	if normalized == "PROC" or normalized == "PROC_GLOW" then return Glow.STYLE.PROC end
	return Glow.STYLE.BLIZZARD
end

local function roundOffset(value)
	value = tonumber(value) or 0
	if value < 0 then return ceil(value - 0.5) end
	return floor(value + 0.5)
end

local function normalizeInset(opts)
	if type(opts) ~= "table" then return 0 end
	return roundOffset(opts.inset)
end

local function getState(target, key, create)
	if not target then return nil end
	local states = target._eqolGlowStates
	if not states then
		if not create then return nil end
		states = {}
		target._eqolGlowStates = states
	end
	local state = states[key]
	if state or not create then return state end
	local host = CreateFrame("Frame", nil, target)
	host:EnableMouse(false)
	host:SetAllPoints(target)
	host:Hide()
	state = { host = host }
	states[key] = state
	return state
end

local function configureHost(target, state, opts)
	local host = state and state.host
	if not host then return end
	host:SetParent(target)
	host:EnableMouse(false)
	host:ClearAllPoints()
	host:SetAllPoints(target)

	local strata = target:GetFrameStrata()
	local requestedStrata = type(opts) == "table" and opts.strata or nil
	if type(requestedStrata) == "string" then
		local upper = tostring(requestedStrata):upper()
		if VALID_STRATA[upper] then strata = upper end
	end
	host:SetFrameStrata(strata)

	local baseLevel = target:GetFrameLevel() or 0
	local offset = type(opts) == "table" and roundOffset(opts.hostFrameLevelOffset) or 0
	host:SetFrameLevel(max(0, baseLevel + offset))
	host.cooldown = (type(opts) == "table" and opts.cooldown) or target.cooldown
	host:Show()
end

local function applyStateAlpha(state)
	local host = state and state.host
	if not host then return end
	if state.alphaMode == "boolean" then
		local onAlpha = tonumber(state.alphaOn)
		local offAlpha = tonumber(state.alphaOff)
		if onAlpha == nil then onAlpha = 1 end
		if offAlpha == nil then offAlpha = 0 end
		if host.SetAlphaFromBoolean and state.alphaCondition ~= nil then
			host:SetAlphaFromBoolean(state.alphaCondition, onAlpha, offAlpha)
		elseif type(state.alphaCondition) == "boolean" then
			host:SetAlpha(state.alphaCondition and onAlpha or offAlpha)
		else
			host:SetAlpha(offAlpha)
		end
		return
	end
	host:SetAlpha(tonumber(state.alphaValue) or 1)
end

local function anchorCooldownViewerAlert(frame, host, inset)
	if not (frame and host) then return end
	inset = roundOffset(inset)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", host, "TOPLEFT", -8 - inset, 8 + inset)
	frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 9 + inset, -9 - inset)
end

local function ensureMarchingAntsOverlay(host)
	local overlay = host and host._eqolMarchingAntsOverlay
	if overlay then return overlay end

	overlay = CreateFrame("Frame", nil, host)
	overlay:EnableMouse(false)
	overlay.Texture = overlay:CreateTexture(nil, "ARTWORK")
	overlay.Texture:SetAllPoints()
	if not (overlay.Texture.SetAtlas and overlay.Texture:SetAtlas(MARCHING_ANTS_ATLAS)) then
		overlay.Texture:SetTexture(BLIZZARD_GLOW_TEXTURE)
		overlay.Texture:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
	end

	local anim = overlay:CreateAnimationGroup()
	anim:SetLooping("REPEAT")
	anim:SetToFinalAlpha(true)
	overlay.Anim = anim

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
		flipAnim:SetDuration(1)
		flipAnim:SetOrder(1)
		flipAnim:SetFlipBookRows(6)
		flipAnim:SetFlipBookColumns(5)
		flipAnim:SetFlipBookFrames(30)
		flipAnim:SetFlipBookFrameWidth(0)
		flipAnim:SetFlipBookFrameHeight(0)
		overlay.FlipAnim = flipAnim
	end

	overlay:SetScript("OnHide", function(self)
		if self.Anim and self.Anim.IsPlaying and self.Anim:IsPlaying() then self.Anim:Stop() end
	end)

	host._eqolMarchingAntsOverlay = overlay
	return overlay
end

local function updateMarchingAntsOverlay(host, opts)
	local overlay = ensureMarchingAntsOverlay(host)
	local color = normalizeColor(type(opts) == "table" and opts.color or nil, { 1, 0.82, 0.2, 1 })
	overlay:SetParent(host)
	overlay:SetFrameStrata(host:GetFrameStrata())
	overlay:SetFrameLevel(max(0, (host:GetFrameLevel() or 0) + 3))
	anchorCooldownViewerAlert(overlay, host, normalizeInset(opts))
	overlay.Texture:SetVertexColor(color[1], color[2], color[3], color[4])
	return overlay
end

local function startMarchingAnts(host, opts)
	local overlay = updateMarchingAntsOverlay(host, opts)
	if not overlay then return end
	overlay:Show()
	if overlay.Anim and overlay.Anim.IsPlaying and not overlay.Anim:IsPlaying() then overlay.Anim:Play() end
end

local function stopMarchingAnts(host)
	local overlay = host and host._eqolMarchingAntsOverlay
	if not overlay then return end
	if overlay.Anim and overlay.Anim.IsPlaying and overlay.Anim:IsPlaying() then overlay.Anim:Stop() end
	overlay:Hide()
end

local function ensureFlashOverlay(host)
	local overlay = host and host._eqolFlashOverlay
	if overlay then return overlay end

	overlay = CreateFrame("Frame", nil, host)
	overlay:EnableMouse(false)
	overlay.Texture = overlay:CreateTexture(nil, "ARTWORK")
	overlay.Texture:SetAllPoints()
	if not (overlay.Texture.SetAtlas and overlay.Texture:SetAtlas(FLASH_GLOW_ATLAS)) then
		overlay.Texture:SetTexture(BLIZZARD_GLOW_TEXTURE)
		overlay.Texture:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
	end

	local anim = overlay:CreateAnimationGroup()
	anim:SetLooping("BOUNCE")
	anim:SetToFinalAlpha(true)
	overlay.Anim = anim

	local alphaAnim = anim:CreateAnimation("Alpha")
	alphaAnim:SetChildKey("Texture")
	alphaAnim:SetDuration(0.5)
	alphaAnim:SetOrder(1)
	alphaAnim:SetSmoothing("IN_OUT")
	alphaAnim:SetFromAlpha(0.25)
	alphaAnim:SetToAlpha(1)
	overlay.AlphaAnim = alphaAnim

	overlay:SetScript("OnHide", function(self)
		if self.Anim and self.Anim.IsPlaying and self.Anim:IsPlaying() then self.Anim:Stop() end
	end)

	host._eqolFlashOverlay = overlay
	return overlay
end

local function updateFlashOverlay(host, opts)
	local overlay = ensureFlashOverlay(host)
	local color = normalizeColor(type(opts) == "table" and opts.color or nil, { 1, 0.82, 0.2, 1 })
	overlay:SetParent(host)
	overlay:SetFrameStrata(host:GetFrameStrata())
	overlay:SetFrameLevel(max(0, (host:GetFrameLevel() or 0) + 3))
	anchorCooldownViewerAlert(overlay, host, normalizeInset(opts))
	overlay.Texture:SetVertexColor(color[1], color[2], color[3], color[4])
	if overlay.AlphaAnim then
		overlay.AlphaAnim:SetFromAlpha(color[4] * 0.25)
		overlay.AlphaAnim:SetToAlpha(color[4])
	end
	return overlay
end

local function startFlash(host, opts)
	local overlay = updateFlashOverlay(host, opts)
	if not overlay then return end
	overlay:Show()
	if overlay.Anim and overlay.Anim.IsPlaying and not overlay.Anim:IsPlaying() then overlay.Anim:Play() end
end

local function stopFlash(host)
	local overlay = host and host._eqolFlashOverlay
	if not overlay then return end
	if overlay.Anim and overlay.Anim.IsPlaying and overlay.Anim:IsPlaying() then overlay.Anim:Stop() end
	overlay:Hide()
end

local function createTargetScaleAnim(group, target, order, duration, scaleX, scaleY, delay)
	local anim = group:CreateAnimation("Scale")
	anim:SetTarget(target)
	anim:SetOrder(order)
	anim:SetDuration(duration)
	anim:SetScale(scaleX, scaleY)
	if delay then anim:SetStartDelay(delay) end
	return anim
end

local function createTargetAlphaAnim(group, target, order, duration, fromAlpha, toAlpha, delay)
	local anim = group:CreateAnimation("Alpha")
	anim:SetTarget(target)
	anim:SetOrder(order)
	anim:SetDuration(duration)
	anim:SetFromAlpha(fromAlpha)
	anim:SetToAlpha(toAlpha)
	if delay then anim:SetStartDelay(delay) end
	return anim
end

local function resetBlizzardOverlayVisuals(overlay)
	if not overlay then return end
	overlay.spark:SetAlpha(0)
	overlay.innerGlow:SetAlpha(0)
	overlay.innerGlowOver:SetAlpha(0)
	overlay.outerGlow:SetAlpha(0)
	overlay.outerGlowOver:SetAlpha(0)
	overlay.ants:SetAlpha(0)
end

local function applyBlizzardOverlayRestState(overlay)
	if not overlay then return end
	local width, height = overlay:GetSize()
	width = max(1, width or 0)
	height = max(1, height or 0)
	overlay.spark:SetSize(width, height)
	overlay.spark:SetAlpha(0)
	overlay.innerGlow:SetSize(width, height)
	overlay.innerGlow:SetAlpha(0)
	overlay.innerGlowOver:SetPoint("TOPLEFT", overlay.innerGlow, "TOPLEFT")
	overlay.innerGlowOver:SetPoint("BOTTOMRIGHT", overlay.innerGlow, "BOTTOMRIGHT")
	overlay.innerGlowOver:SetAlpha(0)
	overlay.outerGlow:SetSize(width, height)
	overlay.outerGlow:SetAlpha(1)
	overlay.outerGlowOver:SetPoint("TOPLEFT", overlay.outerGlow, "TOPLEFT")
	overlay.outerGlowOver:SetPoint("BOTTOMRIGHT", overlay.outerGlow, "BOTTOMRIGHT")
	overlay.outerGlowOver:SetSize(width, height)
	overlay.outerGlowOver:SetAlpha(0)
	overlay.ants:SetSize(width * 0.85, height * 0.85)
	overlay.ants:SetAlpha(1)
end

local function blizzardAnimOutFinished(animGroup)
	local overlay = animGroup and animGroup:GetParent() or nil
	if not overlay then return end
	resetBlizzardOverlayVisuals(overlay)
	overlay:Hide()
end

local function blizzardOverlayOnHide(self)
	if self.animOut and self.animOut:IsPlaying() then self.animOut:Stop() end
	if self.animIn and self.animIn:IsPlaying() then self.animIn:Stop() end
	resetBlizzardOverlayVisuals(self)
end

local function blizzardOverlayOnUpdate(self, elapsed)
	if not (self and self.ants and self.ants:IsShown() and self.ants:GetAlpha() > 0) then return end
	if AnimateTexCoords then AnimateTexCoords(self.ants, 256, 256, 48, 48, 22, elapsed, 0.01) end
end

local function blizzardAnimInOnPlay(group)
	local overlay = group and group:GetParent() or nil
	if not overlay then return end
	local width, height = overlay:GetSize()
	overlay.spark:SetSize(width, height)
	overlay.spark:SetAlpha(0.3)
	overlay.innerGlow:SetSize(width / 2, height / 2)
	overlay.innerGlow:SetAlpha(1)
	overlay.innerGlowOver:SetAlpha(1)
	overlay.outerGlow:SetSize(width * 2, height * 2)
	overlay.outerGlow:SetAlpha(1)
	overlay.outerGlowOver:SetAlpha(1)
	overlay.ants:SetSize(width * 0.85, height * 0.85)
	overlay.ants:SetAlpha(0)
	overlay:Show()
end

local function blizzardAnimInOnFinished(group)
	local overlay = group and group:GetParent() or nil
	if not overlay then return end
	applyBlizzardOverlayRestState(overlay)
end

local function ensureBlizzardOverlay(host)
	local overlay = host and host._eqolBlizzardOverlay
	if overlay then return overlay end

	overlay = CreateFrame("Frame", nil, host)
	overlay:EnableMouse(false)
	overlay:Hide()

	overlay.spark = overlay:CreateTexture(nil, "BACKGROUND")
	overlay.spark:SetPoint("CENTER")
	overlay.spark:SetTexture(BLIZZARD_GLOW_TEXTURE)
	overlay.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)

	overlay.innerGlow = overlay:CreateTexture(nil, "ARTWORK")
	overlay.innerGlow:SetPoint("CENTER")
	overlay.innerGlow:SetTexture(BLIZZARD_GLOW_TEXTURE)
	overlay.innerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

	overlay.innerGlowOver = overlay:CreateTexture(nil, "ARTWORK")
	overlay.innerGlowOver:SetPoint("TOPLEFT", overlay.innerGlow, "TOPLEFT")
	overlay.innerGlowOver:SetPoint("BOTTOMRIGHT", overlay.innerGlow, "BOTTOMRIGHT")
	overlay.innerGlowOver:SetTexture(BLIZZARD_GLOW_TEXTURE)
	overlay.innerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

	overlay.outerGlow = overlay:CreateTexture(nil, "ARTWORK")
	overlay.outerGlow:SetPoint("CENTER")
	overlay.outerGlow:SetTexture(BLIZZARD_GLOW_TEXTURE)
	overlay.outerGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)

	overlay.outerGlowOver = overlay:CreateTexture(nil, "ARTWORK")
	overlay.outerGlowOver:SetPoint("TOPLEFT", overlay.outerGlow, "TOPLEFT")
	overlay.outerGlowOver:SetPoint("BOTTOMRIGHT", overlay.outerGlow, "BOTTOMRIGHT")
	overlay.outerGlowOver:SetTexture(BLIZZARD_GLOW_TEXTURE)
	overlay.outerGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)

	overlay.ants = overlay:CreateTexture(nil, "OVERLAY")
	overlay.ants:SetPoint("CENTER")
	overlay.ants:SetTexture([[Interface\SpellActivationOverlay\IconAlertAnts]])

	overlay.animIn = overlay:CreateAnimationGroup()
	createTargetScaleAnim(overlay.animIn, overlay.spark, 1, 0.2, 1.5, 1.5)
	createTargetAlphaAnim(overlay.animIn, overlay.spark, 1, 0.2, 0, 1)
	createTargetScaleAnim(overlay.animIn, overlay.innerGlow, 1, 0.3, 2, 2)
	createTargetScaleAnim(overlay.animIn, overlay.innerGlowOver, 1, 0.3, 2, 2)
	createTargetAlphaAnim(overlay.animIn, overlay.innerGlowOver, 1, 0.3, 1, 0)
	createTargetScaleAnim(overlay.animIn, overlay.outerGlow, 1, 0.3, 0.5, 0.5)
	createTargetScaleAnim(overlay.animIn, overlay.outerGlowOver, 1, 0.3, 0.5, 0.5)
	createTargetAlphaAnim(overlay.animIn, overlay.outerGlowOver, 1, 0.3, 1, 0)
	createTargetScaleAnim(overlay.animIn, overlay.spark, 1, 0.2, 2 / 3, 2 / 3, 0.2)
	createTargetAlphaAnim(overlay.animIn, overlay.spark, 1, 0.2, 1, 0, 0.2)
	createTargetAlphaAnim(overlay.animIn, overlay.innerGlow, 1, 0.2, 1, 0, 0.3)
	createTargetAlphaAnim(overlay.animIn, overlay.ants, 1, 0.2, 0, 1, 0.3)
	overlay.animIn:SetScript("OnPlay", blizzardAnimInOnPlay)
	overlay.animIn:SetScript("OnFinished", blizzardAnimInOnFinished)

	overlay.animOut = overlay:CreateAnimationGroup()
	createTargetAlphaAnim(overlay.animOut, overlay.outerGlowOver, 1, 0.2, 0, 1)
	createTargetAlphaAnim(overlay.animOut, overlay.ants, 1, 0.2, 1, 0)
	createTargetAlphaAnim(overlay.animOut, overlay.outerGlowOver, 2, 0.2, 1, 0)
	createTargetAlphaAnim(overlay.animOut, overlay.outerGlow, 2, 0.2, 1, 0)
	overlay.animOut:SetScript("OnFinished", blizzardAnimOutFinished)

	overlay:SetScript("OnHide", blizzardOverlayOnHide)
	overlay:SetScript("OnUpdate", blizzardOverlayOnUpdate)

	host._eqolBlizzardOverlay = overlay
	return overlay
end

local function updateBlizzardOverlay(host, opts)
	local overlay = ensureBlizzardOverlay(host)
	local width = max(1, host:GetWidth() or 0)
	local height = max(1, host:GetHeight() or 0)
	local inset = normalizeInset(opts)
	local extraX = max(0, (width * 0.2) + inset)
	local extraY = max(0, (height * 0.2) + inset)
	local overlayWidth = max(1, width + (extraX * 2))
	local overlayHeight = max(1, height + (extraY * 2))
	local color = normalizeColor(type(opts) == "table" and opts.color or nil, { 1, 0.82, 0.2, 1 })
	local r, g, b, a = color[1], color[2], color[3], color[4]

	overlay:SetParent(host)
	overlay:SetFrameStrata(host:GetFrameStrata())
	overlay:SetFrameLevel(max(0, (host:GetFrameLevel() or 0) + 3))
	overlay:ClearAllPoints()
	overlay:SetSize(overlayWidth, overlayHeight)
	overlay:SetPoint("CENTER", host, "CENTER", 0, 0)

	overlay.spark:SetVertexColor(r, g, b, a)
	overlay.innerGlow:SetVertexColor(r, g, b, a)
	overlay.innerGlowOver:SetVertexColor(r, g, b, a)
	overlay.outerGlow:SetVertexColor(r, g, b, a)
	overlay.outerGlowOver:SetVertexColor(r, g, b, a)
	overlay.ants:SetVertexColor(r, g, b, a)
	if overlay:IsShown()
		and not (overlay.animIn and overlay.animIn:IsPlaying())
		and not (overlay.animOut and overlay.animOut:IsPlaying()) then
		applyBlizzardOverlayRestState(overlay)
	end
	return overlay
end

local function startBlizzard(host, opts)
	local overlay = updateBlizzardOverlay(host, opts)
	if not overlay then return end
	if overlay.animOut and overlay.animOut:IsPlaying() then
		overlay.animOut:Stop()
		overlay.animIn:Play()
		return
	end
	if not overlay:IsShown() then
		overlay.animIn:Play()
		return
	end
	if overlay.animIn and overlay.animIn:IsPlaying() then return end
	overlay.ants:SetAlpha(1)
end

local function stopBlizzard(host)
	local overlay = host and host._eqolBlizzardOverlay
	if not overlay then return end
	if overlay.animIn and overlay.animIn:IsPlaying() then overlay.animIn:Stop() end
	if not overlay:IsShown() then
		resetBlizzardOverlayVisuals(overlay)
		return
	end
	if host:IsVisible() and overlay.animOut then
		overlay.animOut:Play()
	else
		resetBlizzardOverlayVisuals(overlay)
		overlay:Hide()
	end
end

local BACKENDS = {
	[Glow.STYLE.BLIZZARD] = {
		start = function(host, opts) startBlizzard(host, opts) end,
		stop = function(host) stopBlizzard(host) end,
	},
	[Glow.STYLE.MARCHING_ANTS] = {
		start = function(host, opts) startMarchingAnts(host, opts) end,
		stop = function(host) stopMarchingAnts(host) end,
	},
	[Glow.STYLE.FLASH] = {
		start = function(host, opts) startFlash(host, opts) end,
		stop = function(host) stopFlash(host) end,
	},
	[Glow.STYLE.BUTTON] = {
		start = function(host, opts)
			if LCG and LCG.ButtonGlow_Start then
				LCG.ButtonGlow_Start(host, type(opts) == "table" and opts.color or nil, type(opts) == "table" and opts.frequency or nil, type(opts) == "table" and opts.frameLevel or nil)
			else
				startBlizzard(host, opts)
			end
		end,
		stop = function(host)
			if LCG and LCG.ButtonGlow_Stop then
				LCG.ButtonGlow_Stop(host)
			else
				stopBlizzard(host)
			end
		end,
	},
	[Glow.STYLE.PIXEL] = {
		start = function(host, opts)
			if LCG and LCG.PixelGlow_Start then
				LCG.PixelGlow_Start(
					host,
					type(opts) == "table" and opts.color or nil,
					type(opts) == "table" and (opts.count or opts.N) or nil,
					type(opts) == "table" and opts.frequency or nil,
					type(opts) == "table" and opts.length or nil,
					type(opts) == "table" and (opts.thickness or opts.th) or nil,
					type(opts) == "table" and opts.xOffset or nil,
					type(opts) == "table" and opts.yOffset or nil,
					type(opts) == "table" and opts.border or nil,
					"",
					type(opts) == "table" and opts.frameLevel or nil
				)
			else
				startBlizzard(host, opts)
			end
		end,
		stop = function(host)
			if LCG and LCG.PixelGlow_Stop then
				LCG.PixelGlow_Stop(host, "")
			else
				stopBlizzard(host)
			end
		end,
	},
	[Glow.STYLE.SHINE] = {
		start = function(host, opts)
			if LCG and LCG.AutoCastGlow_Start then
				LCG.AutoCastGlow_Start(
					host,
					type(opts) == "table" and opts.color or nil,
					type(opts) == "table" and (opts.count or opts.N) or nil,
					type(opts) == "table" and opts.frequency or nil,
					type(opts) == "table" and opts.scale or nil,
					type(opts) == "table" and opts.xOffset or nil,
					type(opts) == "table" and opts.yOffset or nil,
					"",
					type(opts) == "table" and opts.frameLevel or nil
				)
			else
				startBlizzard(host, opts)
			end
		end,
		stop = function(host)
			if LCG and LCG.AutoCastGlow_Stop then
				LCG.AutoCastGlow_Stop(host, "")
			else
				stopBlizzard(host)
			end
		end,
	},
	[Glow.STYLE.PROC] = {
		start = function(host, opts)
			if LCG and LCG.ProcGlow_Start then
				local procOptions = {}
				if type(opts) == "table" then
					for optionKey, optionValue in pairs(opts) do
						procOptions[optionKey] = optionValue
					end
				end
				procOptions.key = ""
				LCG.ProcGlow_Start(host, procOptions)
			else
				startBlizzard(host, opts)
			end
		end,
		stop = function(host)
			if LCG and LCG.ProcGlow_Stop then
				LCG.ProcGlow_Stop(host, "")
			else
				stopBlizzard(host)
			end
		end,
	},
}

local function stopBackend(state)
	if not (state and state.active and state.style) then return end
	local backend = BACKENDS[state.style] or BACKENDS[Glow.STYLE.BLIZZARD]
	if backend and backend.stop and state.host then backend.stop(state.host) end
end

function Glow.GetHost(target, key)
	local state = getState(target, normalizeKey(key), false)
	return state and state.host or nil
end

function Glow.IsActive(target, key)
	local state = getState(target, normalizeKey(key), false)
	return state and state.active == true or false
end

function Glow.Start(target, key, style, opts)
	if not target then return nil end
	key = normalizeKey(key)
	style = normalizeStyle(style)
	local state = getState(target, key, true)
	if state.style and state.style ~= style then stopBackend(state) end
	state.style = style
	state.active = true
	configureHost(target, state, opts)
	local backend = BACKENDS[style] or BACKENDS[Glow.STYLE.BLIZZARD]
	if backend and backend.start and state.host then backend.start(state.host, opts) end
	applyStateAlpha(state)
	return state.host
end

function Glow.Refresh(target, key, style, opts) return Glow.Start(target, key, style, opts) end

function Glow.Stop(target, key)
	local state = getState(target, normalizeKey(key), false)
	if not state then return end
	stopBackend(state)
	state.active = false
	state.style = nil
	state.alphaMode = nil
	state.alphaCondition = nil
	if state.host then
		state.host:SetAlpha(1)
		state.host:Hide()
	end
end

function Glow.StopAll(target)
	if not (target and target._eqolGlowStates) then return end
	for key in pairs(target._eqolGlowStates) do
		Glow.Stop(target, key)
	end
end

function Glow.SetAlpha(target, key, alpha)
	local state = getState(target, normalizeKey(key), true)
	if not state then return end
	state.alphaMode = "value"
	state.alphaValue = tonumber(alpha) or 1
	applyStateAlpha(state)
end

function Glow.SetAlphaFromBoolean(target, key, condition, onAlpha, offAlpha)
	local state = getState(target, normalizeKey(key), true)
	if not state then return end
	state.alphaMode = "boolean"
	state.alphaCondition = condition
	state.alphaOn = onAlpha
	state.alphaOff = offAlpha
	applyStateAlpha(state)
end
