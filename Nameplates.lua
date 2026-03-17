local PvPTogether = _G.PvPTogether

if not PvPTogether then
	return
end

local NAMEPLATE_CVAR_STYLE = "nameplateStyle"
local NAMEPLATE_CVAR_SIZE = "nameplateSize"
local NAMEPLATE_CVAR_AURA_SCALE = "nameplateAuraScale"
local NAMEPLATE_CVAR_DEBUFF_PADDING = "nameplateDebuffPadding"
local MAX_NAMEPLATE_UNIT_TOKENS = 80

local SIZE_SMALL = Enum and Enum.NamePlateSize and Enum.NamePlateSize.Small or 1
local SIZE_MEDIUM = Enum and Enum.NamePlateSize and Enum.NamePlateSize.Medium or 2
local SIZE_LARGE = Enum and Enum.NamePlateSize and Enum.NamePlateSize.Large or 3
local SIZE_EXTRA_LARGE = Enum and Enum.NamePlateSize and Enum.NamePlateSize.ExtraLarge or 4
local SIZE_HUGE = Enum and Enum.NamePlateSize and Enum.NamePlateSize.Huge or 5

local STYLE_MODERN = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Modern or 0
local STYLE_BLOCK = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Block or 2
local STYLE_HEALTH_FOCUS = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.HealthFocus or 3
local STYLE_CAST_FOCUS = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.CastFocus or 4
local STYLE_LEGACY = Enum and Enum.NamePlateStyle and Enum.NamePlateStyle.Legacy or 5

local FALLBACK_NAME_PLATE_SCALES = {
	[SIZE_SMALL] = { horizontal = 0.75, vertical = 0.8, classification = 0.8, aura = 0.75 },
	[SIZE_MEDIUM] = { horizontal = 1.0, vertical = 1.0, classification = 1.0, aura = 1.0 },
	[SIZE_LARGE] = { horizontal = 1.25, vertical = 1.25, classification = 1.25, aura = 1.25 },
	[SIZE_EXTRA_LARGE] = { horizontal = 1.4, vertical = 1.4, classification = 1.4, aura = 1.4 },
	[SIZE_HUGE] = { horizontal = 1.6, vertical = 1.6, classification = 1.6, aura = 1.6 },
}
local BORDER_TINT_TEXTURE_ATLAS = "UI-HUD-Nameplates-Selected"
local BORDER_TINT_TEXTURE_ALPHA = 1.0
local BORDER_GLOW_TEXTURE_ALPHA = 0.35
local BORDER_GLOW_OUTSET = 4

local function IsFrameForbidden(frame)
	if not frame or not frame.IsForbidden then
		return false
	end

	local ok, isForbidden = pcall(frame.IsForbidden, frame)
	return ok and isForbidden and true or false
end

local function CanMutateFrame(frame)
	return frame ~= nil and not IsFrameForbidden(frame)
end

local function GetNumericCVar(cvarName, fallbackValue)
	if not (C_CVar and type(C_CVar.GetCVar) == "function" and type(cvarName) == "string") then
		return fallbackValue
	end

	local ok, rawValue = pcall(C_CVar.GetCVar, cvarName)
	if not ok then
		return fallbackValue
	end
	if PvPTogether:IsSecretValue(rawValue) then
		return fallbackValue
	end

	local numericValue = PvPTogether:SafeToNumber(rawValue)
	if numericValue == nil then
		return fallbackValue
	end
	return numericValue
end

local function GetNamePlateScaleData()
	local cvarKey = NAMEPLATE_CVAR_SIZE
	if type(NamePlateConstants) == "table" and type(NamePlateConstants.SIZE_CVAR) == "string" then
		cvarKey = NamePlateConstants.SIZE_CVAR
	end

	local sizeValue = math.floor((GetNumericCVar(cvarKey, SIZE_MEDIUM) or SIZE_MEDIUM) + 0.5)
	local scaleTable = type(NamePlateConstants) == "table" and NamePlateConstants.NAME_PLATE_SCALES or nil
	local scaleData = scaleTable and scaleTable[sizeValue] or nil
	if scaleData then
		return scaleData
	end

	return FALLBACK_NAME_PLATE_SCALES[sizeValue] or FALLBACK_NAME_PLATE_SCALES[SIZE_MEDIUM]
end

local function IsLargeHealthBarStyle(namePlateStyle)
	return namePlateStyle == STYLE_MODERN or namePlateStyle == STYLE_BLOCK or namePlateStyle == STYLE_HEALTH_FOCUS
end

local function IsLargeCastBarStyle(namePlateStyle)
	return namePlateStyle == STYLE_BLOCK or namePlateStyle == STYLE_CAST_FOCUS
end

local function IsUnitNameInsideHealthBar(namePlateStyle)
	return namePlateStyle == STYLE_MODERN or namePlateStyle == STYLE_BLOCK
end

local function IsSpellNameInsideCastBar(namePlateStyle)
	return namePlateStyle == STYLE_BLOCK or namePlateStyle == STYLE_CAST_FOCUS
end

local function IsUnitNameColored(namePlateStyle)
	return namePlateStyle == STYLE_LEGACY
end

local function SetPixelPoint(frame, point, relativeTo, relativePoint, offsetX, offsetY)
	if PixelUtil and PixelUtil.SetPoint then
		PixelUtil.SetPoint(frame, point, relativeTo, relativePoint, offsetX, offsetY)
		return
	end
	frame:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
end

local function SetPixelSize(frame, width, height)
	if PixelUtil and PixelUtil.SetSize then
		PixelUtil.SetSize(frame, width, height)
		return
	end
	frame:SetSize(width, height)
end

local function SetPixelHeight(frame, height)
	if PixelUtil and PixelUtil.SetHeight then
		PixelUtil.SetHeight(frame, height)
		return
	end
	frame:SetHeight(height)
end

local function GetHealthBarHeight(namePlateStyle, scaleData)
	local largeHeight = type(NamePlateConstants) == "table" and NamePlateConstants.LARGE_HEALTH_BAR_HEIGHT or 20
	local smallHeight = type(NamePlateConstants) == "table" and NamePlateConstants.SMALL_HEALTH_BAR_HEIGHT or 10
	local baseHeight = IsLargeHealthBarStyle(namePlateStyle) and largeHeight or smallHeight
	return baseHeight * (scaleData.vertical or 1.0)
end

local function GetCastBarHeight(namePlateStyle, scaleData)
	local largeHeight = type(NamePlateConstants) == "table" and NamePlateConstants.LARGE_CAST_BAR_HEIGHT or 16
	local smallHeight = type(NamePlateConstants) == "table" and NamePlateConstants.SMALL_CAST_BAR_HEIGHT or 10
	local baseHeight = IsLargeCastBarStyle(namePlateStyle) and largeHeight or smallHeight
	return baseHeight * (scaleData.vertical or 1.0)
end

local function BuildSetupOptionsForStyle(namePlateStyle)
	if type(NamePlateSetupOptions) ~= "table" then
		return nil, nil
	end

	local scaleData = GetNamePlateScaleData()
	local setupOptions = {}
	for key, value in pairs(NamePlateSetupOptions) do
		setupOptions[key] = value
	end

	setupOptions.healthBarHeight = GetHealthBarHeight(namePlateStyle, scaleData)
	setupOptions.castBarHeight = GetCastBarHeight(namePlateStyle, scaleData)
	setupOptions.unitNameInsideHealthBar = IsUnitNameInsideHealthBar(namePlateStyle)
	setupOptions.spellNameInsideCastBar = IsSpellNameInsideCastBar(namePlateStyle)

	return setupOptions, scaleData
end

local function CalculateNamePlateHeight(namePlateStyle, scaleData, setupOptions)
	local auraItemHeight = type(NamePlateConstants) == "table" and NamePlateConstants.AURA_ITEM_HEIGHT or 25
	local auraScaleCVar = type(NamePlateConstants) == "table" and NamePlateConstants.AURA_SCALE_CVAR or NAMEPLATE_CVAR_AURA_SCALE
	local debuffPaddingCVar = type(NamePlateConstants) == "table" and NamePlateConstants.DEBUFF_PADDING_CVAR
		or NAMEPLATE_CVAR_DEBUFF_PADDING

	local auraScale = GetNumericCVar(auraScaleCVar, 1)
	local debuffPadding = GetNumericCVar(debuffPaddingCVar, 0)
	local healthBarFontHeight = setupOptions.healthBarFontHeight or 12
	local castBarFontHeight = setupOptions.castBarFontHeight or 10

	local height = auraItemHeight * auraScale * (scaleData.aura or 1.0)
	height = height + debuffPadding

	if not IsUnitNameInsideHealthBar(namePlateStyle) then
		height = height + healthBarFontHeight
	end

	height = height + setupOptions.healthBarHeight
	height = height + setupOptions.castBarHeight

	if not IsSpellNameInsideCastBar(namePlateStyle) then
		height = height + castBarFontHeight
	end

	return height
end

local function CopyFrameOptions(baseFrameOptions, namePlateStyle)
	if type(baseFrameOptions) ~= "table" then
		return nil
	end

	local copiedOptions = {}
	for key, value in pairs(baseFrameOptions) do
		copiedOptions[key] = value
	end

	copiedOptions.colorNameBySelection = IsUnitNameColored(namePlateStyle)
	return copiedOptions
end

local function IsPlayerInGroup(unitToken)
	if type(unitToken) ~= "string" or unitToken == "" then
		return false
	end

	local okParty, inParty = pcall(UnitInParty, unitToken)
	if okParty and inParty then
		return true
	end

	local okRaid, inRaid = pcall(UnitInRaid, unitToken)
	if okRaid and inRaid then
		return true
	end

	return false
end

local function ResolveUnitKind(namePlateFrameBase)
	if not namePlateFrameBase or type(namePlateFrameBase.GetUnit) ~= "function" then
		return nil
	end

	local okUnit, unitToken = pcall(namePlateFrameBase.GetUnit, namePlateFrameBase)
	if not okUnit or type(unitToken) ~= "string" or unitToken == "" then
		return nil
	end
	if PvPTogether:IsSecretValue(unitToken) then
		return nil
	end

	local okPlayer, isPlayer = pcall(UnitIsPlayer, unitToken)
	if not okPlayer or not isPlayer then
		return "npc"
	end

	if IsPlayerInGroup(unitToken) then
		return "partyMember"
	end

	local okFriend, isFriend = pcall(UnitIsFriend, "player", unitToken)
	if okFriend and isFriend then
		return "friendlyPlayer"
	end

	return "enemyPlayer"
end

local function ResolveUnitKindFromUnitFrame(unitFrame)
	if not unitFrame then
		return nil
	end

	local unitToken = unitFrame.unit
	if type(unitToken) == "string" and unitToken ~= "" and not PvPTogether:IsSecretValue(unitToken) then
		local okPlayer, isPlayer = pcall(UnitIsPlayer, unitToken)
		if okPlayer then
			if not isPlayer then
				return "npc"
			end

			if IsPlayerInGroup(unitToken) then
				return "partyMember"
			end

			local okFriend, isFriend = pcall(UnitIsFriend, "player", unitToken)
			if okFriend and isFriend then
				return "friendlyPlayer"
			end

			return "enemyPlayer"
		end
	end

	local parentFrame = unitFrame.GetParent and unitFrame:GetParent() or nil
	if parentFrame then
		return ResolveUnitKind(parentFrame)
	end

	return nil
end

local function ForEachVisibleNameplate(callbackFn)
	if not (C_NamePlate and type(C_NamePlate.GetNamePlates) == "function") then
		return
	end

	local okFrames, frames = pcall(C_NamePlate.GetNamePlates, false)
	if not okFrames or type(frames) ~= "table" then
		return
	end

	for _, frame in pairs(frames) do
		callbackFn(frame)
	end
end

local function ForEachVisibleNameplateToken(callbackFn)
	if type(callbackFn) ~= "function" then
		return
	end

	for index = 1, MAX_NAMEPLATE_UNIT_TOKENS do
		local unitToken = "nameplate" .. tostring(index)
		local okExists, exists = pcall(UnitExists, unitToken)
		if okExists and exists then
			callbackFn(unitToken)
		end
	end
end

function PvPTogether:TrackNameplateFrame(namePlateFrameBase)
	if not CanMutateFrame(namePlateFrameBase) then
		return false
	end

	if type(self.trackedNamePlateFrames) ~= "table" then
		self.trackedNamePlateFrames = setmetatable({}, { __mode = "k" })
	end

	self.trackedNamePlateFrames[namePlateFrameBase] = true
	return true
end

function PvPTogether:ForEachTrackedNameplateFrame(callbackFn)
	if type(callbackFn) ~= "function" then
		return
	end
	if type(self.trackedNamePlateFrames) ~= "table" then
		return
	end

	for frame in pairs(self.trackedNamePlateFrames) do
		callbackFn(frame)
	end
end

PvPTogether.nameplateBorderTintByUnitFrame = PvPTogether.nameplateBorderTintByUnitFrame
	or setmetatable({}, { __mode = "k" })

local function GetBorderTintHealthBar(unitFrame)
	if not CanMutateFrame(unitFrame) then
		return nil
	end

	local healthBarsContainer = unitFrame.HealthBarsContainer
	local healthBar = healthBarsContainer and healthBarsContainer.healthBar or nil
	if not CanMutateFrame(healthBar) then
		return nil
	end

	return healthBar
end

local function AnchorBorderTintTexture(healthBar, texture, extraOutset)
	if not CanMutateFrame(healthBar) or not CanMutateFrame(texture) then
		return
	end

	local anchorTarget = healthBar.bgTexture
	if not CanMutateFrame(anchorTarget) then
		anchorTarget = healthBar
	end

	local outset = PvPTogether:SafeToNumber(extraOutset) or 0
	if outset < 0 then
		outset = 0
	end

	texture:ClearAllPoints()
	SetPixelPoint(texture, "TOPLEFT", anchorTarget, "TOPLEFT", -1 - outset, 1 + outset)
	SetPixelPoint(texture, "BOTTOMRIGHT", anchorTarget, "BOTTOMRIGHT", -3 + outset, 3 + outset)
end

local function AnchorBorderGlowTextures(healthBar, overlay)
	if not CanMutateFrame(healthBar) or type(overlay) ~= "table" then
		return
	end

	local glowTop = overlay.GlowTop
	local glowBottom = overlay.GlowBottom
	local glowLeft = overlay.GlowLeft
	local glowRight = overlay.GlowRight
	if
		not CanMutateFrame(glowTop)
		or not CanMutateFrame(glowBottom)
		or not CanMutateFrame(glowLeft)
		or not CanMutateFrame(glowRight)
	then
		return
	end

	local anchorTarget = healthBar.bgTexture
	if not CanMutateFrame(anchorTarget) then
		anchorTarget = healthBar
	end

	local outset = PvPTogether:SafeToNumber(BORDER_GLOW_OUTSET) or 0
	if outset < 0 then
		outset = 0
	end

	-- Top glow: strongest at border edge, fades outward/up.
	glowTop:ClearAllPoints()
	SetPixelPoint(glowTop, "TOPLEFT", anchorTarget, "TOPLEFT", -1, 1 + outset)
	SetPixelPoint(glowTop, "BOTTOMRIGHT", anchorTarget, "TOPRIGHT", -3, 1)

	-- Bottom glow: strongest at border edge, fades outward/down.
	glowBottom:ClearAllPoints()
	SetPixelPoint(glowBottom, "TOPLEFT", anchorTarget, "BOTTOMLEFT", -1, 3)
	SetPixelPoint(glowBottom, "BOTTOMRIGHT", anchorTarget, "BOTTOMRIGHT", -3, 3 - outset)

	-- Left glow: strongest at border edge, fades outward/left.
	glowLeft:ClearAllPoints()
	SetPixelPoint(glowLeft, "TOPLEFT", anchorTarget, "TOPLEFT", -1 - outset, 1)
	SetPixelPoint(glowLeft, "BOTTOMRIGHT", anchorTarget, "BOTTOMLEFT", -1, 3)

	-- Right glow: strongest at border edge, fades outward/right.
	glowRight:ClearAllPoints()
	SetPixelPoint(glowRight, "TOPLEFT", anchorTarget, "TOPRIGHT", -3, 1)
	SetPixelPoint(glowRight, "BOTTOMRIGHT", anchorTarget, "BOTTOMRIGHT", -3 + outset, 3)
end

local function ApplyBorderGlowGradient(texture, orientation, red, green, blue, alpha, invert)
	if not CanMutateFrame(texture) then
		return
	end

	local colorAlpha = PvPTogether:SafeToNumber(alpha) or 0
	if colorAlpha < 0 then
		colorAlpha = 0
	elseif colorAlpha > 1 then
		colorAlpha = 1
	end

	local useGradient = texture.SetGradient and type(CreateColor) == "function"
	if useGradient then
		local strongColor = CreateColor(red, green, blue, colorAlpha)
		local clearColor = CreateColor(red, green, blue, 0)
		if invert then
			texture:SetGradient(orientation, clearColor, strongColor)
		else
			texture:SetGradient(orientation, strongColor, clearColor)
		end
		return
	end

	if texture.SetColorTexture then
		texture:SetColorTexture(red, green, blue, colorAlpha)
	end
end

local function EnsureBorderTintTexture(unitFrame)
	local healthBar = GetBorderTintHealthBar(unitFrame)
	if not healthBar then
		return nil
	end

	local existingOverlay = PvPTogether.nameplateBorderTintByUnitFrame[unitFrame]
	if existingOverlay and CanMutateFrame(existingOverlay.Texture) then
		existingOverlay.HealthBar = healthBar
		return existingOverlay
	end

	local texture = healthBar:CreateTexture(nil, "OVERLAY", nil, 2)
	local glowTop = healthBar:CreateTexture(nil, "OVERLAY", nil, 1)
	local glowBottom = healthBar:CreateTexture(nil, "OVERLAY", nil, 1)
	local glowLeft = healthBar:CreateTexture(nil, "OVERLAY", nil, 1)
	local glowRight = healthBar:CreateTexture(nil, "OVERLAY", nil, 1)
	if
		not CanMutateFrame(texture)
		or not CanMutateFrame(glowTop)
		or not CanMutateFrame(glowBottom)
		or not CanMutateFrame(glowLeft)
		or not CanMutateFrame(glowRight)
	then
		return nil
	end

	if texture.SetAtlas then
		texture:SetAtlas(BORDER_TINT_TEXTURE_ATLAS, true)
	end
	if glowTop.SetBlendMode then
		glowTop:SetBlendMode("ADD")
	end
	if glowBottom.SetBlendMode then
		glowBottom:SetBlendMode("ADD")
	end
	if glowLeft.SetBlendMode then
		glowLeft:SetBlendMode("ADD")
	end
	if glowRight.SetBlendMode then
		glowRight:SetBlendMode("ADD")
	end
	texture:Hide()
	glowTop:Hide()
	glowBottom:Hide()
	glowLeft:Hide()
	glowRight:Hide()

	local overlay = {
		Texture = texture,
		GlowTop = glowTop,
		GlowBottom = glowBottom,
		GlowLeft = glowLeft,
		GlowRight = glowRight,
		HealthBar = healthBar,
	}
	PvPTogether.nameplateBorderTintByUnitFrame[unitFrame] = overlay
	return overlay
end

function PvPTogether:HideBorderTintForUnitFrame(unitFrame)
	if not unitFrame then
		return
	end

	local overlay = self.nameplateBorderTintByUnitFrame and self.nameplateBorderTintByUnitFrame[unitFrame] or nil
	if not overlay then
		return
	end

	if overlay.Texture and overlay.Texture.Hide and not IsFrameForbidden(overlay.Texture) then
		overlay.Texture:Hide()
	end
	if overlay.GlowTop and overlay.GlowTop.Hide and not IsFrameForbidden(overlay.GlowTop) then
		overlay.GlowTop:Hide()
	end
	if overlay.GlowBottom and overlay.GlowBottom.Hide and not IsFrameForbidden(overlay.GlowBottom) then
		overlay.GlowBottom:Hide()
	end
	if overlay.GlowLeft and overlay.GlowLeft.Hide and not IsFrameForbidden(overlay.GlowLeft) then
		overlay.GlowLeft:Hide()
	end
	if overlay.GlowRight and overlay.GlowRight.Hide and not IsFrameForbidden(overlay.GlowRight) then
		overlay.GlowRight:Hide()
	end
end

function PvPTogether:ApplyBorderTintForUnitFrame(unitFrame, unitKind)
	if not self.isEnabled or type(unitKind) ~= "string" then
		self:HideBorderTintForUnitFrame(unitFrame)
		return
	end

	if not self:IsBorderColorOverrideEnabledForUnitKind(unitKind) then
		self:HideBorderTintForUnitFrame(unitFrame)
		return
	end

	local overlay = EnsureBorderTintTexture(unitFrame)
	if not overlay or not CanMutateFrame(overlay.Texture) then
		return
	end

	local healthBar = overlay.HealthBar
	if not CanMutateFrame(healthBar) then
		self:HideBorderTintForUnitFrame(unitFrame)
		return
	end

	if healthBar.IsShown and not healthBar:IsShown() then
		self:HideBorderTintForUnitFrame(unitFrame)
		return
	end

	AnchorBorderTintTexture(healthBar, overlay.Texture, 0)
	AnchorBorderGlowTextures(healthBar, overlay)

	local color = self:GetConfiguredBorderColorForUnitKind(unitKind)
	local tintAlpha = BORDER_TINT_TEXTURE_ALPHA
	local glowAlpha = BORDER_GLOW_TEXTURE_ALPHA
	if healthBar.GetAlpha then
		local healthBarAlpha = healthBar:GetAlpha()
		if type(healthBarAlpha) == "number" then
			if healthBarAlpha < 0 then
				healthBarAlpha = 0
			elseif healthBarAlpha > 1 then
				healthBarAlpha = 1
			end
			tintAlpha = healthBarAlpha * BORDER_TINT_TEXTURE_ALPHA
			glowAlpha = healthBarAlpha * BORDER_GLOW_TEXTURE_ALPHA
		end
	end

	if overlay.Texture.SetVertexColor then
		overlay.Texture:SetVertexColor(color.r, color.g, color.b, tintAlpha)
	elseif overlay.Texture.SetColorTexture then
		overlay.Texture:SetColorTexture(color.r, color.g, color.b, tintAlpha)
	end

	overlay.Texture:Show()
	if overlay.GlowTop and overlay.GlowBottom and overlay.GlowLeft and overlay.GlowRight then
		ApplyBorderGlowGradient(overlay.GlowTop, "VERTICAL", color.r, color.g, color.b, glowAlpha, true)
		ApplyBorderGlowGradient(overlay.GlowBottom, "VERTICAL", color.r, color.g, color.b, glowAlpha, false)
		ApplyBorderGlowGradient(overlay.GlowLeft, "HORIZONTAL", color.r, color.g, color.b, glowAlpha, true)
		ApplyBorderGlowGradient(overlay.GlowRight, "HORIZONTAL", color.r, color.g, color.b, glowAlpha, false)

		overlay.GlowTop:Show()
		overlay.GlowBottom:Show()
		overlay.GlowLeft:Show()
		overlay.GlowRight:Show()
	end
end

function PvPTogether:HideAllBorderTintOverrides()
	if type(self.nameplateBorderTintByUnitFrame) ~= "table" then
		return
	end

	for unitFrame in pairs(self.nameplateBorderTintByUnitFrame) do
		self:HideBorderTintForUnitFrame(unitFrame)
	end
end

local function ApplyCustomAnchors(unitFrame, setupOptions)
	if type(unitFrame) ~= "table" then
		return
	end
	if not CanMutateFrame(unitFrame) then
		return
	end

	local castBar = unitFrame.castBar
	local healthBarsContainer = unitFrame.HealthBarsContainer
	local aurasFrame = unitFrame.AurasFrame
	local raidTargetFrame = unitFrame.RaidTargetFrame
	local name = unitFrame.name
	if
		not castBar
		or not healthBarsContainer
		or not aurasFrame
		or not raidTargetFrame
		or not name
		or not castBar.Icon
		or not castBar.BorderShield
		or not healthBarsContainer.healthBar
	then
		return
	end

	local healthBar = healthBarsContainer.healthBar
	local healthBarText = healthBar.Text
	local healthBarLeftText = healthBar.LeftText
	local healthBarRightText = healthBar.RightText
	if not healthBarText or not healthBarLeftText or not healthBarRightText then
		return
	end

	castBar:ClearAllPoints()
	castBar.Icon:ClearAllPoints()
	castBar.BorderShield:ClearAllPoints()

	if setupOptions.spellNameInsideCastBar == true then
		SetPixelPoint(castBar, "BOTTOMLEFT", unitFrame, "BOTTOMLEFT", 12, 0)
		SetPixelPoint(castBar, "BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -12, 0)
		SetPixelPoint(castBar.Icon, "LEFT", castBar, "LEFT", 0, 0)
	else
		SetPixelPoint(castBar.Icon, "BOTTOMLEFT", unitFrame, "BOTTOMLEFT", 12, 0)
		SetPixelPoint(castBar, "BOTTOM", castBar.Icon, "TOP", 0, 0)
		SetPixelPoint(castBar, "LEFT", unitFrame, "BOTTOMLEFT", 12, 0)
		SetPixelPoint(castBar, "RIGHT", unitFrame, "BOTTOMRIGHT", -12, 0)
	end

	SetPixelSize(castBar.Icon, setupOptions.castIconWidth, setupOptions.castIconHeight)
	SetPixelSize(castBar.BorderShield, setupOptions.castBarShieldWidth, setupOptions.castBarShieldHeight)
	SetPixelPoint(castBar.BorderShield, "RIGHT", castBar.Icon, "RIGHT", 0, 0)

	if castBar.ImportantCastIndicator then
		local namePlateSize = math.floor((GetNumericCVar(NAMEPLATE_CVAR_SIZE, SIZE_MEDIUM) or SIZE_MEDIUM) + 0.5)
		if namePlateSize < SIZE_MEDIUM then
			SetPixelPoint(castBar.ImportantCastIndicator, "TOPLEFT", castBar, "TOPLEFT", -20, 3)
			SetPixelPoint(castBar.ImportantCastIndicator, "BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 20, -3)
		else
			SetPixelPoint(castBar.ImportantCastIndicator, "TOPLEFT", castBar, "TOPLEFT", -26, 3)
			SetPixelPoint(castBar.ImportantCastIndicator, "BOTTOMRIGHT", castBar, "BOTTOMRIGHT", 25, -3)
		end
	end

	healthBarsContainer:ClearAllPoints()
	SetPixelPoint(healthBarsContainer, "BOTTOMLEFT", castBar, "TOPLEFT", 0, 2)
	SetPixelPoint(healthBarsContainer, "BOTTOMRIGHT", castBar, "TOPRIGHT", 0, 2)
	SetPixelHeight(healthBarsContainer, setupOptions.healthBarHeight)

	name:ClearAllPoints()
	healthBarText:ClearAllPoints()
	healthBarLeftText:ClearAllPoints()
	healthBarRightText:ClearAllPoints()

	local showOnlyName = unitFrame.IsShowOnlyName and unitFrame:IsShowOnlyName()
	if showOnlyName then
		name:SetJustifyH("CENTER")
		if setupOptions.unitNameInsideHealthBar == true then
			SetPixelPoint(name, "LEFT", healthBarsContainer, "LEFT", 4, 0)
			SetPixelPoint(name, "RIGHT", healthBarsContainer, "RIGHT", -4, 0)
		else
			SetPixelPoint(name, "BOTTOMLEFT", healthBarsContainer, "TOPLEFT", 4, 2)
			SetPixelPoint(name, "BOTTOMRIGHT", healthBarsContainer, "TOPRIGHT", -4, 2)
		end
	else
		name:SetJustifyH("LEFT")
		if setupOptions.unitNameInsideHealthBar == true then
			SetPixelPoint(healthBarLeftText, "RIGHT", healthBar, "RIGHT", -4, 0)
			SetPixelPoint(healthBarRightText, "RIGHT", healthBarLeftText, "LEFT", -2, 0)
			SetPixelPoint(healthBarText, "RIGHT", healthBarRightText, "LEFT", 2, 0)
			SetPixelPoint(name, "LEFT", healthBarsContainer, "LEFT", 4, 0)
			SetPixelPoint(name, "RIGHT", healthBarText, "LEFT", -2, 0)
		else
			SetPixelPoint(healthBarLeftText, "BOTTOMRIGHT", healthBar, "TOPRIGHT", -4, 2)
			SetPixelPoint(healthBarRightText, "BOTTOMRIGHT", healthBarLeftText, "BOTTOMLEFT", -2, 0)
			SetPixelPoint(healthBarText, "BOTTOMRIGHT", healthBarRightText, "BOTTOMLEFT", 2, 0)
			SetPixelPoint(name, "BOTTOMLEFT", healthBarsContainer, "TOPLEFT", 4, 2)
			SetPixelPoint(name, "BOTTOMRIGHT", healthBarText, "BOTTOMLEFT", -2, 0)
		end
	end

	if name.GetLineHeight then
		local lineHeight = name:GetLineHeight()
		if type(lineHeight) == "number" and lineHeight > 0 then
			SetPixelHeight(name, lineHeight)
		end
	end

	if unitFrame.overAbsorbGlow then
		unitFrame.overAbsorbGlow:ClearAllPoints()
		SetPixelPoint(unitFrame.overAbsorbGlow, "BOTTOMLEFT", healthBar, "BOTTOMRIGHT", -4, -1)
		SetPixelPoint(unitFrame.overAbsorbGlow, "TOPLEFT", healthBar, "TOPRIGHT", -4, 1)
		SetPixelHeight(unitFrame.overAbsorbGlow, 8)
	end

	if unitFrame.overHealAbsorbGlow then
		unitFrame.overHealAbsorbGlow:ClearAllPoints()
		SetPixelPoint(unitFrame.overHealAbsorbGlow, "BOTTOMRIGHT", healthBar, "BOTTOMLEFT", 2, -1)
		SetPixelPoint(unitFrame.overHealAbsorbGlow, "TOPRIGHT", healthBar, "TOPLEFT", 2, 1)
		if PixelUtil and PixelUtil.SetWidth then
			PixelUtil.SetWidth(unitFrame.overHealAbsorbGlow, 8)
		else
			unitFrame.overHealAbsorbGlow:SetWidth(8)
		end
	end

	if healthBar.bgTexture then
		SetPixelPoint(healthBar.bgTexture, "TOPLEFT", healthBar, "TOPLEFT", -2, 3)
		SetPixelPoint(healthBar.bgTexture, "BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 6, -6)
	end

	if healthBar.selectedBorder and healthBar.bgTexture then
		SetPixelPoint(healthBar.selectedBorder, "TOPLEFT", healthBar.bgTexture, "TOPLEFT", -1, 1)
		SetPixelPoint(healthBar.selectedBorder, "BOTTOMRIGHT", healthBar.bgTexture, "BOTTOMRIGHT", -3, 3)
	end

	local debuffPaddingCVar = type(NamePlateConstants) == "table" and NamePlateConstants.DEBUFF_PADDING_CVAR
		or NAMEPLATE_CVAR_DEBUFF_PADDING
	local debuffPadding = GetNumericCVar(debuffPaddingCVar, 0)
	if aurasFrame.DebuffListFrame then
		if setupOptions.unitNameInsideHealthBar == true then
			SetPixelPoint(aurasFrame.DebuffListFrame, "BOTTOM", healthBar, "TOP", 0, debuffPadding)
		else
			SetPixelPoint(aurasFrame.DebuffListFrame, "BOTTOM", name, "TOP", 0, debuffPadding)
		end
	end

	raidTargetFrame:ClearAllPoints()
	if showOnlyName then
		SetPixelPoint(raidTargetFrame, "BOTTOM", name, "TOP", 0, 10)
	else
		SetPixelPoint(raidTargetFrame, "RIGHT", healthBarsContainer, "LEFT", 0, 0)
	end
end

local function ApplySetupOptionsVisuals(unitFrame, setupOptions)
	if not unitFrame or not setupOptions then
		return
	end

	local castBar = unitFrame.castBar
	if castBar then
		if castBar.SetHeight then
			castBar:SetHeight(setupOptions.castBarHeight)
		end
		if castBar.Spark and castBar.Spark.SetHeight then
			castBar.Spark:SetHeight(setupOptions.castBarHeight + 8)
		end
		if castBar.Text and castBar.Text.SetTextHeight then
			castBar.Text:SetTextHeight(setupOptions.castBarFontHeight)
		end
		if castBar.CastTargetNameText and castBar.CastTargetNameText.SetTextHeight then
			castBar.CastTargetNameText:SetTextHeight(setupOptions.castBarFontHeight)
		end
	end

	local healthBar = unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar or nil
	if healthBar then
		if setupOptions.unitNameInsideHealthBar then
			if unitFrame.name and unitFrame.name.SetFontObject then
				unitFrame.name:SetFontObject("SystemFont_NamePlate_Outlined")
			end
			if healthBar.Text and healthBar.Text.SetFontObject then
				healthBar.Text:SetFontObject("SystemFont_NamePlate_Outlined")
			end
			if healthBar.LeftText and healthBar.LeftText.SetFontObject then
				healthBar.LeftText:SetFontObject("SystemFont_NamePlate_Outlined")
			end
			if healthBar.RightText and healthBar.RightText.SetFontObject then
				healthBar.RightText:SetFontObject("SystemFont_NamePlate_Outlined")
			end
		else
			if unitFrame.name and unitFrame.name.SetFontObject then
				unitFrame.name:SetFontObject("SystemFont_NamePlate")
			end
			if healthBar.Text and healthBar.Text.SetFontObject then
				healthBar.Text:SetFontObject("SystemFont_NamePlate")
			end
			if healthBar.LeftText and healthBar.LeftText.SetFontObject then
				healthBar.LeftText:SetFontObject("SystemFont_NamePlate")
			end
			if healthBar.RightText and healthBar.RightText.SetFontObject then
				healthBar.RightText:SetFontObject("SystemFont_NamePlate")
			end
		end

		if unitFrame.name and unitFrame.name.SetTextHeight then
			unitFrame.name:SetTextHeight(setupOptions.healthBarFontHeight)
		end
		if healthBar.Text and healthBar.Text.SetTextHeight then
			healthBar.Text:SetTextHeight(setupOptions.healthBarFontHeight)
		end
		if healthBar.LeftText and healthBar.LeftText.SetTextHeight then
			healthBar.LeftText:SetTextHeight(setupOptions.healthBarFontHeight)
		end
		if healthBar.RightText and healthBar.RightText.SetTextHeight then
			healthBar.RightText:SetTextHeight(setupOptions.healthBarFontHeight)
		end
	end

	if unitFrame.ClassificationFrame and unitFrame.ClassificationFrame.SetScale then
		unitFrame.ClassificationFrame:SetScale(setupOptions.classificationScale or 1.0)
	end
	if unitFrame.PlayerLevelDiffFrame and unitFrame.PlayerLevelDiffFrame.SetScale then
		unitFrame.PlayerLevelDiffFrame:SetScale(setupOptions.classificationScale or 1.0)
	end
end

local function ApplyCalculatedFrameSize(namePlateFrameBase, styleValue, scaleData, setupOptions)
	if
		not namePlateFrameBase
		or type(namePlateFrameBase.SetSize) ~= "function"
		or type(namePlateFrameBase.GetWidth) ~= "function"
	then
		return
	end

	local frameHeight = CalculateNamePlateHeight(styleValue, scaleData, setupOptions)
	if type(frameHeight) ~= "number" or frameHeight <= 0 then
		return
	end

	local okWidth, currentWidth = pcall(namePlateFrameBase.GetWidth, namePlateFrameBase)
	local widthValue = okWidth and PvPTogether:SafeToNumber(currentWidth) or nil
	if widthValue and widthValue > 0 then
		pcall(namePlateFrameBase.SetSize, namePlateFrameBase, widthValue, frameHeight)
	end
end

function PvPTogether:ReapplyStyleForNameplateFrame(namePlateFrameBase)
	if not CanMutateFrame(namePlateFrameBase) then
		return false
	end
	self:TrackNameplateFrame(namePlateFrameBase)

	-- Always apply our per-type override directly for already-created frames.
	self:ApplyPerTypeStyleToNameplateFrame(namePlateFrameBase)
	return true
end

function PvPTogether:ReapplyStyleForUnitToken(unitToken)
	if type(unitToken) ~= "string" or unitToken == "" then
		return false
	end
	if not (C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function") then
		return false
	end

	local okFrame, namePlateFrameBase = pcall(C_NamePlate.GetNamePlateForUnit, unitToken, false)
	if not okFrame or not namePlateFrameBase then
		return false
	end

	return self:ReapplyStyleForNameplateFrame(namePlateFrameBase)
end

function PvPTogether:ApplyPerTypeStyleToNameplateFrame(namePlateFrameBase)
	if not self.isEnabled then
		return
	end
	if self:IsInCombatLockdown() then
		self.pendingNameplateRefreshAfterCombat = true
		return
	end
	if not CanMutateFrame(namePlateFrameBase) then
		return
	end
	self:TrackNameplateFrame(namePlateFrameBase)

	local unitFrame = namePlateFrameBase.UnitFrame
	if not CanMutateFrame(unitFrame) then
		return
	end

	local unitKind = ResolveUnitKind(namePlateFrameBase)
	self:ApplyBorderTintForUnitFrame(unitFrame, unitKind)
	if not unitKind then
		return
	end

	local styleValue = self:GetConfiguredStyleForUnitKind(unitKind)
	if not self:IsNameplateStyle(styleValue) then
		return
	end

	local setupOptions, scaleData = BuildSetupOptionsForStyle(styleValue)
	if not setupOptions or not scaleData then
		return
	end

	ApplySetupOptionsVisuals(unitFrame, setupOptions)
	ApplyCustomAnchors(unitFrame, setupOptions)
	ApplyCalculatedFrameSize(namePlateFrameBase, styleValue, scaleData, setupOptions)
end

function PvPTogether:ApplyPerTypeStyleGeometryToUnitFrame(unitFrame)
	if not self.isEnabled then
		return
	end
	if self:IsInCombatLockdown() then
		self.pendingNameplateRefreshAfterCombat = true
		return
	end
	if not CanMutateFrame(unitFrame) then
		return
	end

	local namePlateFrameBase = unitFrame.GetParent and unitFrame:GetParent() or nil
	if not CanMutateFrame(namePlateFrameBase) then
		return
	end

	local unitKind = ResolveUnitKindFromUnitFrame(unitFrame)
	self:ApplyBorderTintForUnitFrame(unitFrame, unitKind)
	if not unitKind then
		return
	end

	local styleValue = self:GetConfiguredStyleForUnitKind(unitKind)
	if not self:IsNameplateStyle(styleValue) then
		return
	end

	local setupOptions, scaleData = BuildSetupOptionsForStyle(styleValue)
	if not setupOptions or not scaleData then
		return
	end

	ApplySetupOptionsVisuals(unitFrame, setupOptions)
	ApplyCustomAnchors(unitFrame, setupOptions)
	ApplyCalculatedFrameSize(namePlateFrameBase, styleValue, scaleData, setupOptions)
end

function PvPTogether:ReapplyAllNameplateStyles()
	if not self.isEnabled then
		return {
			inCombat = false,
			tracked = 0,
			tokens = 0,
			fallback = 0,
		}
	end

	local inCombat = self:IsInCombatLockdown()
	if inCombat then
		self.pendingNameplateRefreshAfterCombat = true
		return {
			inCombat = true,
			tracked = 0,
			tokens = 0,
			fallback = 0,
		}
	end
	self.pendingNameplateRefreshAfterCombat = false

	local refreshedByFrame = {}
	local stats = {
		inCombat = inCombat and true or false,
		tracked = 0,
		tokens = 0,
		fallback = 0,
	}

	self:ForEachTrackedNameplateFrame(function(namePlateFrameBase)
		if CanMutateFrame(namePlateFrameBase) then
			local unitToken = namePlateFrameBase.GetUnit and namePlateFrameBase:GetUnit() or nil
			if type(unitToken) == "string" and unitToken ~= "" then
				self:ReapplyStyleForNameplateFrame(namePlateFrameBase)
				if not refreshedByFrame[namePlateFrameBase] then
					refreshedByFrame[namePlateFrameBase] = true
					stats.tracked = stats.tracked + 1
				end
			end
		end
	end)

	ForEachVisibleNameplateToken(function(unitToken)
		local okFrame, namePlateFrameBase = pcall(C_NamePlate.GetNamePlateForUnit, unitToken, false)
		if okFrame and namePlateFrameBase then
			self:TrackNameplateFrame(namePlateFrameBase)
			self:ReapplyStyleForNameplateFrame(namePlateFrameBase)
			if not refreshedByFrame[namePlateFrameBase] then
				refreshedByFrame[namePlateFrameBase] = true
				stats.tokens = stats.tokens + 1
			end
		end
	end)

	ForEachVisibleNameplate(function(namePlateFrameBase)
		if not refreshedByFrame[namePlateFrameBase] then
			self:ReapplyStyleForNameplateFrame(namePlateFrameBase)
			stats.fallback = stats.fallback + 1
		end
	end)

	-- Apply one lightweight deferred pass to win races against Blizzard's immediate follow-up anchor updates.
	if C_Timer and type(C_Timer.After) == "function" then
		local refreshGeneration = (self.nameplateReapplyGeneration or 0) + 1
		self.nameplateReapplyGeneration = refreshGeneration
		C_Timer.After(0.05, function()
			if self.nameplateReapplyGeneration ~= refreshGeneration then
				return
			end
			if not self.isEnabled or self:IsInCombatLockdown() then
				if self:IsInCombatLockdown() then
					self.pendingNameplateRefreshAfterCombat = true
				end
				if not self.isEnabled then
					return
				end
			end

			ForEachVisibleNameplateToken(function(unitToken)
				self:ReapplyStyleForUnitToken(unitToken)
			end)
		end)
	end

	return stats
end

function PvPTogether:ScheduleReapplyAllNameplateStyles(delaySeconds)
	if not self.isEnabled then
		return
	end

	local delay = self:SafeToNumber(delaySeconds) or 0
	if delay < 0 then
		delay = 0
	end

	if not (C_Timer and type(C_Timer.After) == "function") then
		self:ReapplyAllNameplateStyles()
		return
	end

	local generation = (self.nameplateScheduledReapplyGeneration or 0) + 1
	self.nameplateScheduledReapplyGeneration = generation
	C_Timer.After(delay, function()
		if self.nameplateScheduledReapplyGeneration ~= generation then
			return
		end
		if not self.isEnabled then
			return
		end
		self:ReapplyAllNameplateStyles()
	end)
end

function PvPTogether:ResetAllNameplateStylesToBlizzard()
	if self:IsInCombatLockdown() then
		self.pendingNameplateResetAfterCombat = true
		return
	end

	self.pendingNameplateResetAfterCombat = false
	self:HideAllBorderTintOverrides()

	if type(NamePlateDriverFrame) == "table" and type(NamePlateDriverFrame.UpdateNamePlateOptions) == "function" then
		pcall(NamePlateDriverFrame.UpdateNamePlateOptions, NamePlateDriverFrame)
	end
end

function PvPTogether:TryInstallNameplateHooks()
	if self.nameplateHooksInstalled then
		return true
	end

	if not NamePlateBaseMixin and type(UIParentLoadAddOn) == "function" then
		pcall(UIParentLoadAddOn, "Blizzard_NamePlates")
	end

	if type(hooksecurefunc) ~= "function" or type(NamePlateBaseMixin) ~= "table" then
		return false
	end

	hooksecurefunc(NamePlateBaseMixin, "ApplyFrameOptions", function(namePlateFrameBase)
		PvPTogether:TrackNameplateFrame(namePlateFrameBase)
		PvPTogether:ApplyPerTypeStyleToNameplateFrame(namePlateFrameBase)
	end)
	if type(NamePlateUnitFrameMixin) == "table" then
		hooksecurefunc(NamePlateUnitFrameMixin, "OnUnitSet", function(unitFrame)
			local parentFrame = unitFrame and unitFrame.GetParent and unitFrame:GetParent() or nil
			if parentFrame then
				PvPTogether:TrackNameplateFrame(parentFrame)
				PvPTogether:ApplyPerTypeStyleToNameplateFrame(parentFrame)
			end
		end)
		hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", function(unitFrame)
			PvPTogether:ApplyPerTypeStyleGeometryToUnitFrame(unitFrame)
		end)
	end

	self.nameplateHooksInstalled = true
	return true
end

function PvPTogether:EnsureNameplateEventFrame()
	if self.nameplateEventFrame then
		return self.nameplateEventFrame
	end

	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, eventName, ...)
		if eventName == "ADDON_LOADED" then
			local loadedAddon = ...
			if loadedAddon == "Blizzard_NamePlates" then
				PvPTogether:TryInstallNameplateHooks()
				if PvPTogether.isEnabled then
					PvPTogether:ReapplyAllNameplateStyles()
				end
			end
		elseif eventName == "NAME_PLATE_UNIT_ADDED" then
			if not PvPTogether.isEnabled then
				return
			end

			if PvPTogether:IsInCombatLockdown() then
				PvPTogether.pendingNameplateRefreshAfterCombat = true
				return
			end

			local unitToken = ...
			if type(unitToken) ~= "string" or unitToken == "" then
				return
			end

			if C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function" then
				local okFrame, frameBase = pcall(C_NamePlate.GetNamePlateForUnit, unitToken, false)
				if okFrame and frameBase then
					PvPTogether:ApplyPerTypeStyleToNameplateFrame(frameBase)
				end
			end
		elseif eventName == "PLAYER_ENTERING_WORLD" then
			if PvPTogether.isEnabled then
				PvPTogether:ReapplyAllNameplateStyles()
			end
		elseif eventName == "CVAR_UPDATE" then
			if not PvPTogether.isEnabled then
				return
			end

			local cvarName = ...
			local cvarText = PvPTogether:SafeToString(cvarName, ""):lower()
			if cvarText:find("nameplate", 1, true) then
				PvPTogether:ReapplyAllNameplateStyles()
			end
		elseif eventName == "PLAYER_REGEN_ENABLED" then
			if PvPTogether.pendingNameplateResetAfterCombat then
				PvPTogether:ResetAllNameplateStylesToBlizzard()
			end

			if PvPTogether.pendingNameplateRefreshAfterCombat and PvPTogether.isEnabled then
				PvPTogether:ReapplyAllNameplateStyles()
			end
		end
	end)

	self.nameplateEventFrame = frame
	return frame
end

function PvPTogether:EnableNameplateModule()
	local frame = self:EnsureNameplateEventFrame()

	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("CVAR_UPDATE")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")

	self:TryInstallNameplateHooks()
	self:ReapplyAllNameplateStyles()
end

function PvPTogether:DisableNameplateModule()
	if self.nameplateEventFrame then
		self.nameplateEventFrame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
		self.nameplateEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self.nameplateEventFrame:UnregisterEvent("CVAR_UPDATE")
		-- Keep PLAYER_REGEN_ENABLED in case a deferred reset is pending.
	end

	self.pendingNameplateRefreshAfterCombat = false
	self:ResetAllNameplateStylesToBlizzard()
end
