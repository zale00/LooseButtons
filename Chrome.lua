local Logic = LooseButtonsLogic
local LB = Logic.LB

local function HideRegion(region)
	if region then
		region:Hide()
	end
end

local function MicroPlate(button)
	if not button.plate then
		button.plate = button:CreateTexture(nil, "BACKGROUND")
		button.plate:SetPoint("CENTER")
	end
	return button.plate
end

local function ClearStateTextures(button)
	if button.ClearNormalTexture then
		button:ClearNormalTexture()
	else
		HideRegion(button:GetNormalTexture())
	end
	if button.ClearPushedTexture then
		button:ClearPushedTexture()
	else
		HideRegion(button:GetPushedTexture())
	end
	if button.ClearHighlightTexture then
		button:ClearHighlightTexture()
	else
		HideRegion(button:GetHighlightTexture())
	end
end

local function Edge(button, layer)
	local tex = button:CreateTexture(nil, layer)
	tex:SetColorTexture(1, 1, 1, 1)
	return tex
end

local function EnsureChrome(button)
	if button.lbChrome then
		return button.lbChrome
	end
	local chrome = {
		shadow = Edge(button, "BACKGROUND"),
		well = Edge(button, "BORDER"),
		top = Edge(button, "OVERLAY"),
		bottom = Edge(button, "OVERLAY"),
		left = Edge(button, "OVERLAY"),
		right = Edge(button, "OVERLAY"),
		hoverTop = Edge(button, "HIGHLIGHT"),
		hoverBottom = Edge(button, "HIGHLIGHT"),
		hoverLeft = Edge(button, "HIGHLIGHT"),
		hoverRight = Edge(button, "HIGHLIGHT"),
	}
	button.lbChrome = chrome
	return chrome
end

local function HideChrome(button)
	local chrome = button.lbChrome
	if not chrome then
		return
	end
	chrome.shadow:Hide()
	chrome.well:Hide()
	chrome.top:Hide()
	chrome.bottom:Hide()
	chrome.left:Hide()
	chrome.right:Hide()
	chrome.hoverTop:Hide()
	chrome.hoverBottom:Hide()
	chrome.hoverLeft:Hide()
	chrome.hoverRight:Hide()
end

local function PlaceRim(button, top, bottom, left, right, rim, r, g, b, a)
	local function place(tex, p1, rel1, x1, y1, p2, rel2, x2, y2)
		tex:ClearAllPoints()
		tex:SetPoint(p1, button, rel1, x1, y1)
		tex:SetPoint(p2, button, rel2, x2, y2)
		tex:SetColorTexture(r, g, b, a)
		tex:Show()
	end
	place(top, "TOPLEFT", "TOPLEFT", 0, 0, "BOTTOMRIGHT", "TOPRIGHT", 0, -rim)
	place(bottom, "TOPLEFT", "BOTTOMLEFT", 0, rim, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0)
	place(left, "TOPLEFT", "TOPLEFT", 0, -rim, "BOTTOMRIGHT", "BOTTOMLEFT", rim, rim)
	place(right, "TOPLEFT", "TOPRIGHT", -rim, -rim, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, rim)
end

local function ApplyChrome(button, spec)
	local chrome = EnsureChrome(button)
	if spec.shadowA > 0 then
		local shift = spec.shadow
		chrome.shadow:ClearAllPoints()
		chrome.shadow:SetPoint("TOPLEFT", button, "TOPLEFT", shift, -shift)
		chrome.shadow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", shift, -shift)
		chrome.shadow:SetColorTexture(0, 0, 0, spec.shadowA)
		chrome.shadow:Show()
	else
		chrome.shadow:Hide()
	end
	if spec.wellA > 0 then
		chrome.well:ClearAllPoints()
		chrome.well:SetPoint("TOPLEFT", button, "TOPLEFT", spec.rim, -spec.rim)
		chrome.well:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -spec.rim, spec.rim)
		chrome.well:SetColorTexture(spec.wellR, spec.wellG, spec.wellB, spec.wellA)
		chrome.well:Show()
	else
		chrome.well:Hide()
	end
	if spec.rim > 0 then
		PlaceRim(button, chrome.top, chrome.bottom, chrome.left, chrome.right, spec.rim, spec.rimR, spec.rimG, spec.rimB, spec.rimA)
	else
		chrome.top:Hide()
		chrome.bottom:Hide()
		chrome.left:Hide()
		chrome.right:Hide()
	end
	if spec.hoverA > 0 then
		PlaceRim(button, chrome.hoverTop, chrome.hoverBottom, chrome.hoverLeft, chrome.hoverRight, spec.rim, spec.hoverR, spec.hoverG, spec.hoverB, spec.hoverA)
	else
		chrome.hoverTop:Hide()
		chrome.hoverBottom:Hide()
		chrome.hoverLeft:Hide()
		chrome.hoverRight:Hide()
	end
	if button.border then
		button.border:Hide()
	end
	button.icon:ClearAllPoints()
	button.icon:SetPoint("TOPLEFT", spec.inset, -spec.inset)
	button.icon:SetPoint("BOTTOMRIGHT", -spec.inset, spec.inset)
end

local function FitStockFrame(texture, frameW, frameH, role)
	if not texture or not texture.ClearAllPoints then
		return
	end
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", 0, 0)
	texture:SetSize(frameW, frameH)
	if role == "highlight" then
		if texture.SetDrawLayer then
			texture:SetDrawLayer("HIGHLIGHT")
		end
		return
	end
	if texture.SetDrawLayer then
		texture:SetDrawLayer("OVERLAY")
	end
	if Logic.StockIdleShown(role) then
		texture:Show()
	else
		texture:Hide()
	end
end

local function SetIconMask(button, shown, width, height)
	local icon = button.icon
	if not icon then
		return
	end
	if shown and not button.lbIconMask and icon.AddMaskTexture and button.CreateMaskTexture then
		local mask = button:CreateMaskTexture()
		if mask and mask.SetAtlas then
			mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
			button.lbIconMask = mask
		end
	end
	if not button.lbIconMask then
		return
	end
	if shown then
		if icon.RemoveMaskTexture then
			icon:RemoveMaskTexture(button.lbIconMask)
		end
		if icon.AddMaskTexture then
			icon:AddMaskTexture(button.lbIconMask)
		end
		button.lbIconMask:Show()
		button.lbIconMask:ClearAllPoints()
		button.lbIconMask:SetPoint("CENTER", icon, "CENTER", 0, 0)
		button.lbIconMask:SetSize(width, height)
		return
	end
	if icon.RemoveMaskTexture then
		icon:RemoveMaskTexture(button.lbIconMask)
	end
	button.lbIconMask:Hide()
end

local function AnchorCooldown(button)
	local cooldown = button.cooldown
	local icon = button.icon
	if not cooldown or not icon or not cooldown.ClearAllPoints then
		return
	end
	local record = button.lbKind and LB.Find(button.lbKind, button.lbSlot)
	local theme = record and LB.ThemeOf(record) or LB.CurrentTheme()
	local pad = Logic.ThemeSpec(theme).cooldownInset
	cooldown:ClearAllPoints()
	cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", pad, -pad)
	cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -pad, pad)
end

local function RaiseCooldown(button)
	local cooldown = button.cooldown
	if not cooldown then
		return
	end
	if cooldown.SetDrawSwipe then
		cooldown:SetDrawSwipe(true)
	end
	if cooldown.SetSwipeColor then
		cooldown:SetSwipeColor(0, 0, 0, 0.64)
	end
	if cooldown.SetFrameLevel and button.GetFrameLevel then
		cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
	end
	if button.hotkey and button.hotkey.SetFrameLevel and button.GetFrameLevel then
		button.hotkey:SetFrameLevel(button:GetFrameLevel() + 2)
	end
	AnchorCooldown(button)
end

local function PlaceCount(button)
	if not button.lbCount then
		local frame = CreateFrame("Frame", nil, button)
		if frame.EnableMouse then
			frame:EnableMouse(false)
		end
		local text = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		text:SetJustifyH("RIGHT")
		button.lbCount = frame
		button.lbCountText = text
	end
	local icon = button.icon or button
	local frame = button.lbCount
	frame:ClearAllPoints()
	frame:SetAllPoints(icon)
	if frame.SetFrameLevel and button.GetFrameLevel then
		frame:SetFrameLevel(button:GetFrameLevel() + 2)
	end
	local text = button.lbCountText
	text:ClearAllPoints()
	text:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
end

local function ItemCount(payload)
	if C_Item and C_Item.GetItemCount then
		return C_Item.GetItemCount(payload)
	end
	if type(GetItemCount) == "function" then
		return GetItemCount(payload)
	end
	return nil
end

function LB.PaintHotkeyRange(text, outOfRange)
	if not text or type(text.GetText) ~= "function" or type(text.SetVertexColor) ~= "function" then
		return
	end
	local shown = text:GetText()
	if type(shown) ~= "string" or shown == "" then
		return
	end
	local color = ACTIONBAR_HOTKEY_FONT_COLOR
	if outOfRange then
		color = RED_FONT_COLOR
	end
	if type(color) ~= "table" or type(color.GetRGB) ~= "function" then
		return
	end
	local r, g, b = color:GetRGB()
	if type(issecretvalue) == "function" and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then
		return
	end
	text:SetVertexColor(r, g, b)
end

local function RestoreIcon(icon)
	if icon and icon.SetDesaturated then
		icon:SetDesaturated(false)
	end
	if icon and icon.SetVertexColor then
		icon:SetVertexColor(1, 1, 1)
	end
end

local function PaintItemCount(button, record)
	PlaceCount(button)
	local text = button.lbCountText
	local icon = button.icon
	if not record or record.kind ~= "item" then
		text:SetText("")
		RestoreIcon(icon)
		return
	end
	local count = ItemCount(record.payload)
	local secret = type(issecretvalue) == "function" and issecretvalue(count)
	if secret then
		text:SetText(count)
		text:SetTextColor(1, 1, 1)
		return
	end
	local look = Logic.ItemCountLook(count)
	if not look then
		text:SetText("")
		RestoreIcon(icon)
		return
	end
	text:SetText(look.text)
	text:SetTextColor(look.r, look.g, look.b)
	if icon and icon.SetDesaturated then
		icon:SetDesaturated(look.desaturate)
	end
	if icon and icon.SetVertexColor then
		icon:SetVertexColor(look.vertexR, look.vertexG, look.vertexB)
	end
end

local function ApplyRecordCooldown(button, record)
	local cooldown = button and button.cooldown
	if not cooldown or not record then
		return
	end
	if (record.kind == "spell" or (record.kind == "pet" and record.petCast == "spell")) and C_Spell and C_Spell.GetSpellCooldownDuration and cooldown.SetCooldownFromDurationObject then
		local duration = C_Spell.GetSpellCooldownDuration(record.payload)
		local secret = type(issecretvalue) == "function" and issecretvalue(duration)
		if secret or duration then
			cooldown:SetCooldownFromDurationObject(duration)
		end
		return
	end
	if record.kind == "item" and C_Item and C_Item.GetItemCooldown and cooldown.SetCooldown then
		local start, duration, enable = C_Item.GetItemCooldown(record.payload)
		local secret = type(issecretvalue) == "function" and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enable))
		if secret or enable then
			cooldown:SetCooldown(start, duration)
		elseif cooldown.Clear then
			cooldown:Clear()
		end
	end
end

local function ApplyActionOverlay(button)
	if not button then
		return
	end
	RaiseCooldown(button)
	local record = LB.Find(button.lbKind or "spell", button.lbSlot)
	if record then
		ApplyRecordCooldown(button, record)
	end
	PaintItemCount(button, record)
end

local function ButtonLayout(button)
	local width
	local height
	if type(button.GetWidth) == "function" then
		width = button:GetWidth()
	end
	if type(button.GetHeight) == "function" then
		height = button:GetHeight()
	end
	return Logic.StockIconLayout(width, height)
end

local function WirePressFeedback(button, frameW, frameH, theme)
	local function hideGlow()
		if button.lbIconGlow then
			button.lbIconGlow:Hide()
		end
		if button.lbIconPress then
			button.lbIconPress:Hide()
		end
		if button.lbPressFill then
			button.lbPressFill:Hide()
		end
	end
	local feedback = Logic.PressFeedback(theme)
	if feedback == "frame" then
		hideGlow()
		if button.SetPushedAtlas then
			button:SetPushedAtlas(Logic.STOCK_PUSHED_ATLAS)
			FitStockFrame(button:GetPushedTexture(), frameW, frameH, "pushed")
		end
		if button.SetHighlightAtlas then
			button:SetHighlightAtlas(Logic.STOCK_HIGHLIGHT_ATLAS)
			FitStockFrame(button:GetHighlightTexture(), frameW, frameH, "highlight")
		end
		return
	end
	if feedback == "fill" then
		local spec = Logic.ThemeSpec(theme)
		hideGlow()
		if not button.lbPressFill then
			button.lbPressFill = button:CreateTexture(nil, "OVERLAY")
		end
		local fill = button.lbPressFill
		fill:SetColorTexture(spec.pressR, spec.pressG, spec.pressB, spec.pressA)
		if button.SetPushedTexture then
			button:SetPushedTexture(fill)
		end
		fill:SetDrawLayer("OVERLAY")
		fill:ClearAllPoints()
		fill:SetPoint("TOPLEFT", button, "TOPLEFT", spec.rim, -spec.rim)
		fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -spec.rim, spec.rim)
		return
	end
	local icon = button.icon
	if not icon then
		hideGlow()
		return
	end
	local function copyFace(from, to)
		local atlas
		if type(from.GetAtlas) == "function" then
			atlas = from:GetAtlas()
		end
		if type(atlas) == "string" and atlas ~= "" and type(to.SetAtlas) == "function" then
			to:SetAtlas(atlas)
			return true
		end
		if type(from.GetTexture) == "function" and type(to.SetTexture) == "function" then
			local texture = from:GetTexture()
			if texture then
				to:SetTexture(texture)
				return true
			end
		end
		return false
	end
	local function placeGlow(tex, alpha)
		local inset = Logic.ICON_GLOW_INSET
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", icon, "TOPLEFT", inset, -inset)
		tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset)
		if tex.SetBlendMode then
			tex:SetBlendMode("ADD")
		end
		tex:SetAlpha(alpha)
		tex:Show()
	end
	if not button.lbIconGlow then
		button.lbIconGlow = button:CreateTexture(nil, "HIGHLIGHT")
	end
	if not copyFace(icon, button.lbIconGlow) and button.lbIconGlow.SetColorTexture then
		button.lbIconGlow:SetColorTexture(1, 0.95, 0.8, 1)
	end
	placeGlow(button.lbIconGlow, Logic.ICON_GLOW_ALPHA)
	if not button.lbIconPress then
		button.lbIconPress = button:CreateTexture(nil, "OVERLAY")
	end
	if not copyFace(icon, button.lbIconPress) and button.lbIconPress.SetColorTexture then
		button.lbIconPress:SetColorTexture(1, 0.95, 0.8, 1)
	end
	placeGlow(button.lbIconPress, Logic.ICON_PRESS_ALPHA)
	if button.SetPushedTexture then
		button:SetPushedTexture(button.lbIconPress)
		placeGlow(button.lbIconPress, Logic.ICON_PRESS_ALPHA)
	end
end

local function ShowStockSlot(button, shown)
	if shown and not button.lbSlotArt then
		button.lbSlotArt = button:CreateTexture(nil, "BACKGROUND", nil, -1)
		button.lbSlotArt:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
		button.lbSlotArt:SetAllPoints(button)
	end
	if button.lbSlotArt then
		button.lbSlotArt:SetShown(shown)
	end
end

local function PaintStockAction(button, icon)
	HideChrome(button)
	local iconW, iconH, frameW, frameH, maskW, maskH = ButtonLayout(button)
	ShowStockSlot(button, true)
	button.icon:Show()
	button.icon:SetDrawLayer("BACKGROUND", 1)
	button.icon:ClearAllPoints()
	button.icon:SetPoint("CENTER", 0, 0)
	button.icon:SetSize(iconW, iconH)
	local texture = Logic.UsableTexture(icon)
	if texture then
		button.icon:SetTexture(texture)
	end
	if button.border then
		button.border:Hide()
	end
	if button.SetNormalAtlas then
		button:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
		FitStockFrame(button:GetNormalTexture(), frameW, frameH, "normal")
	end
	WirePressFeedback(button, frameW, frameH)
	SetIconMask(button, true, maskW, maskH)
end

local function PaintThemedFace(button, paint, icon, theme)
	if paint.chrome == "micro" and paint.portrait and type(SetPortraitTexture) == "function" then
		LB.PaintPortrait(button.icon)
	elseif paint.chrome == "micro" and paint.normal and button.icon.SetAtlas then
		button.icon:SetAtlas(paint.normal)
	elseif paint.chrome == "bag" then
		button.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
	else
		local texture = Logic.UsableTexture(icon)
		if texture then
			button.icon:SetTexture(texture)
		end
	end
	ApplyChrome(button, Logic.ThemeSpec(theme))
	local crop = Logic.ThemeSpec(theme).crop
	if crop > 0 and paint.chrome ~= "micro" and button.icon.SetTexCoord then
		button.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	local _, _, frameW, frameH = ButtonLayout(button)
	WirePressFeedback(button, frameW, frameH, theme)
end

local function PaintFace(button, paint, icon, theme)
	theme = Logic.NormalizeTheme(theme or LB.CurrentTheme())
	local chrome = paint.chrome
	local stock = Logic.StockTheme(theme)
	button.icon:ClearAllPoints()
	if button.icon.SetTexCoord then
		button.icon:SetTexCoord(0, 1, 0, 1)
	end
	SetIconMask(button, false)
	ShowStockSlot(button, false)
	ClearStateTextures(button)
	if button.lbIconGlow then
		button.lbIconGlow:Hide()
	end
	if button.lbIconPress then
		button.lbIconPress:Hide()
	end
	if button.lbPressFill then
		button.lbPressFill:Hide()
	end
	if stock and chrome == "micro" then
		HideChrome(button)
		local plate = MicroPlate(button)
		plate:Show()
		plate:SetAtlas(paint.plate, true)
		if paint.portrait and type(SetPortraitTexture) == "function" then
			button:SetPushedAtlas("UI-HUD-MicroMenu-ButtonBG-Down")
			button.icon:Show()
			button.icon:SetDrawLayer("OVERLAY", 1)
			button.icon:SetPoint("TOPLEFT", 7, -7)
			button.icon:SetPoint("BOTTOMRIGHT", -7, 7)
			SetPortraitTexture(button.icon, "player")
		else
			button.icon:Hide()
			button:SetNormalAtlas(paint.normal)
			button:SetPushedAtlas(paint.pushed)
			button:SetHighlightAtlas(paint.highlight)
			local normal = button:GetNormalTexture()
			if normal then
				normal:Show()
			end
		end
		if button.border then
			button.border:Hide()
		end
		AnchorCooldown(button)
		return
	end
	if button.plate then
		button.plate:Hide()
	end
	button.icon:Show()
	button.icon:SetDrawLayer("ARTWORK", 1)
	if stock and chrome == "bag" then
		HideChrome(button)
		button.icon:SetPoint("TOPLEFT", 4, -4)
		button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
		button.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
		if button.border then
			button.border:Show()
			button.border:SetAtlas("bag-border")
		end
		local _, _, frameW, frameH = ButtonLayout(button)
		WirePressFeedback(button, frameW, frameH)
		AnchorCooldown(button)
		return
	end
	if stock and chrome == "action" then
		PaintStockAction(button, icon)
		ApplyActionOverlay(button)
		return
	end
	PaintThemedFace(button, paint, icon, theme)
	if chrome == "action" then
		ApplyActionOverlay(button)
	else
		AnchorCooldown(button)
	end
end

local function RepaintPlaced()
	local buttons = LB.DB().buttons
	local i
	for i = 1, #buttons do
		local record = buttons[i]
		local button = LB.ButtonFor(record)
		if button and button.IsShown and button:IsShown() then
			if record.kind == "launcher" then
				PaintFace(button, Logic.LauncherPaint(record), nil, LB.ThemeOf(record))
			else
				PaintFace(button, { chrome = "action" }, record.icon, LB.CurrentTheme())
			end
		end
	end
end

local function ApplyTheme(id)
	local live = LB.DB()
	live.theme = Logic.NormalizeTheme(id)
	local theme = live.theme
	if LB.themeDropdown and LB.themeDropdown.SetDefaultText then
		LB.themeDropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	RepaintPlaced()
end

local function ApplyLauncherTheme(id)
	local theme = Logic.NormalizeTheme(id)
	LB.DB().launcherTheme = theme
	if LB.launcherThemeDropdown and LB.launcherThemeDropdown.SetDefaultText then
		LB.launcherThemeDropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	RepaintPlaced()
end

LB.ApplyActionOverlay = ApplyActionOverlay
LB.ApplyLauncherTheme = ApplyLauncherTheme
LB.ApplyTheme = ApplyTheme
LB.ButtonLayout = ButtonLayout
LB.ClearStateTextures = ClearStateTextures
LB.PaintFace = PaintFace
LB.PaintStockAction = PaintStockAction
LB.RaiseCooldown = RaiseCooldown
LB.RepaintPlaced = RepaintPlaced
