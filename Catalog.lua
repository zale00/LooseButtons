local Logic = LooseButtonsLogic
local LB = Logic.LB

local receive = CreateFrame("Frame", "LooseButtonsReceive", UIParent)
receive:SetAllPoints(UIParent)
receive:SetFrameStrata("FULLSCREEN")
receive:EnableMouse(true)
receive:Hide()

local function CatalogMover()
	if LB.dragLauncher then
		return { id = "catalog", kind = "launcher", chrome = LB.dragLauncher.chrome }
	end
	if LB.dragSpell then
		return { id = "catalog", kind = LB.dragSpell.kind }
	end
	return nil
end

local function PreviewCatalogDrop()
	local mover = CatalogMover()
	local x, y = LB.CursorCenter()
	if not mover or not x or LB.OverBook() or LB.ActionButtonUnderCursor() then
		LB.ClearSnapPlan()
		return
	end
	LB.ShowSnapPlan(Logic.SnapPlan(LB.DB().buttons, { mover }, x, y, LB.ScaleOf))
end

receive:SetScript("OnHide", LB.ClearSnapPlan)
receive:SetScript("OnUpdate", function(self)
	if not self:IsShown() then
		return
	end
	PreviewCatalogDrop()
	self:EnableMouse(true)
end)

local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(32, 40)
ghost:SetFrameStrata("TOOLTIP")
ghost:Hide()
ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
ghost.icon:SetAllPoints()
ghost:SetScript("OnUpdate", function(self)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	if not scale or scale == 0 then
		scale = 1
	end
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

local function HideGhost()
	ghost:Hide()
	LB.dragLauncher = nil
end

local function ShowSpellGhost(icon)
	local texture = Logic.UsableTexture(icon)
	if texture and ghost.icon.SetTexture then
		ghost.icon:SetTexture(texture)
	end
	ghost:Show()
end

local function ShowReceive(aboveUi)
	receive:SetFrameStrata(aboveUi and "FULLSCREEN" or "LOW")
	receive:EnableMouse(true)
	receive:Show()
end

local function HideReceive()
	receive:Hide()
	HideGhost()
end

local dropBusy = false
local function FinishDrop()
	if dropBusy then
		return
	end
	dropBusy = true
	local kind, payload, icon
	if LB.dragLauncher then
		kind = "launcher"
		payload = LB.dragLauncher.payload
		icon = LB.dragLauncher.icon
	elseif LB.dragSpell then
		kind = LB.dragSpell.kind
		payload = LB.dragSpell.payload
		icon = LB.dragSpell.icon
		LB.dragSpell = nil
	else
		HideReceive()
		dropBusy = false
		return
	end
	local over = LB.ActionButtonUnderCursor()
	local intent = Logic.DropIntent("catalog", over ~= nil, kind)
	if intent == "action" then
		LB.PlaceIntoAction(over, kind, payload)
		if ClearCursor then
			ClearCursor()
		end
		HideReceive()
		dropBusy = false
		return
	end
	if intent == "cancel" then
		HideReceive()
		dropBusy = false
		return
	end
	local onBook = LB.OverBook()
	local x, y = LB.CursorCenter()
	if ClearCursor then
		ClearCursor()
	end
	HideReceive()
	if not onBook and x then
		LB.Place(kind, payload, x, y, icon)
	end
	dropBusy = false
end

receive:SetScript("OnReceiveDrag", FinishDrop)
receive:SetScript("OnMouseUp", function(_, mouseButton)
	if mouseButton == "RightButton" and not LB.dragLauncher then
		LB.dragSpell = nil
		if ClearCursor then
			ClearCursor()
		end
		HideReceive()
		return
	end
	FinishDrop()
end)

local function BeginLauncherDrag(entry)
	LB.dragLauncher = entry
	if entry.portrait and type(SetPortraitTexture) == "function" then
		SetPortraitTexture(ghost.icon, "player")
	elseif entry.atlas and ghost.icon.SetAtlas then
		ghost.icon:SetAtlas("UI-HUD-MicroMenu-" .. entry.atlas .. "-Up")
	elseif entry.chrome == "bag" then
		ghost.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
	end
	ghost:Show()
	ShowReceive(true)
end

local function UpdateCooldowns()
	if not LB.poolReady then
		return
	end
	local i
	for i = 1, Logic.ACTION_SLOTS do
		local button = LB.actions[i]
		local record = LB.Find("spell", i)
		if button and button:IsShown() and record and (record.kind == "spell" or record.kind == "item") then
			LB.ApplyActionOverlay(button)
		end
	end
end

local function SpellAt(index)
	if not C_SpellBook or not C_SpellBook.GetSpellBookItemInfo or not Enum or not Enum.SpellBookSpellBank then
		return nil
	end
	local info = C_SpellBook.GetSpellBookItemInfo(index, Enum.SpellBookSpellBank.Player)
	if not info then
		return nil
	end
	local isSpell = Enum.SpellBookItemType and info.itemType == Enum.SpellBookItemType.Spell
	local actionID = info.actionID
	local spellID = info.spellID
	if type(spellID) ~= "number" then
		spellID = actionID
	end
	if type(actionID) ~= "number" then
		actionID = spellID
	end
	return {
		spellID = actionID,
		baseSpellID = type(info.spellID) == "number" and info.spellID or nil,
		name = info.name,
		subName = info.subName,
		iconID = info.iconID,
		isSpell = isSpell and true or false,
		isPassive = info.isPassive and true or false,
		isOffSpec = info.isOffSpec and true or false,
	}
end

local function SkillLines()
	local lines = {}
	if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then
		return lines
	end
	local count = C_SpellBook.GetNumSpellBookSkillLines()
	local i
	for i = 1, count do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
		if info then
			table.insert(lines, {
				name = info.name,
				shouldHide = info.shouldHide and true or false,
				offSpecID = info.offSpecID,
				itemIndexOffset = info.itemIndexOffset,
				numSpellBookItems = info.numSpellBookItems,
			})
		end
	end
	return lines
end

function LB.SpellBase(spellID)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return nil
	end
	if type(spellID) ~= "number" or spellID < 1 or spellID ~= math.floor(spellID) then
		return nil
	end
	if type(C_SpellBook) ~= "table" or type(C_SpellBook.FindBaseSpellByID) ~= "function" then
		return nil
	end
	local base = C_SpellBook.FindBaseSpellByID(spellID)
	if type(issecretvalue) == "function" and issecretvalue(base) then
		return nil
	end
	if type(base) ~= "number" or base < 1 or base ~= math.floor(base) then
		return nil
	end
	return base
end

function LB.SpellName(spellID)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return nil
	end
	if type(C_Spell) ~= "table" or type(C_Spell.GetSpellName) ~= "function" then
		return nil
	end
	local name = C_Spell.GetSpellName(spellID)
	if type(issecretvalue) == "function" and issecretvalue(name) then
		return nil
	end
	if type(name) ~= "string" or name == "" then
		return nil
	end
	return name
end

function LB.SpellRank(spellID)
	if type(issecretvalue) == "function" and issecretvalue(spellID) then
		return nil
	end
	if type(C_Spell) ~= "table" or type(C_Spell.GetSpellSubtext) ~= "function" then
		return nil
	end
	return Logic.SpellRank(C_Spell.GetSpellSubtext(spellID))
end

function LB.FollowRanks()
	if Logic.UpgradeSpellRanks(LB.DB().buttons, SkillLines(), function(index)
		return Logic.RankRow(SpellAt(index))
	end, LB.SpellBase, LB.SpellName, LB.SpellRank) then
		LB.bookStale = true
	end
end

local function BindingExists(command)
	if type(GetBindingIndex) ~= "function" then
		return false
	end
	local index = GetBindingIndex(command)
	return type(index) == "number" and index > 0
end

local function ApplySpellbookColor(fontString)
	local color = SPELLBOOK_FONT_COLOR
	if not fontString or not fontString.SetTextColor or type(color) ~= "table" then
		return
	end
	local r, g, b = color.r, color.g, color.b
	if not r and color.GetRGB then
		r, g, b = color:GetRGB()
	end
	if r and g and b then
		fontString:SetTextColor(r, g, b)
	end
end

local function PaintCatalogIcon(icon, entry)
	if entry.portrait and type(SetPortraitTexture) == "function" then
		SetPortraitTexture(icon, "player")
		return
	end
	if entry.atlas and icon.SetAtlas then
		icon:SetAtlas("UI-HUD-MicroMenu-" .. entry.atlas .. "-Up")
		return
	end
	if entry.chrome == "bag" then
		icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag")
		return
	end
	local texture = Logic.UsableTexture(entry.icon)
	if texture then
		icon:SetTexture(texture)
	end
end

local function plainNumber(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if type(value) == "number" and value == math.floor(value) then
		return value
	end
	return nil
end

local function plainString(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local function ConsumableRow(info)
	local itemID = type(info) == "table" and plainNumber(info.itemID) or nil
	if not itemID or type(C_Item) ~= "table" or type(C_Item.GetItemInfoInstant) ~= "function" or type(C_Item.GetItemSpell) ~= "function" then
		return nil
	end
	local _, _, _, _, instantIcon, classID = C_Item.GetItemInfoInstant(itemID)
	classID = plainNumber(classID)
	local spellName, spellID = C_Item.GetItemSpell(itemID)
	local hasUse = false
	if type(issecretvalue) == "function" and (issecretvalue(spellName) or issecretvalue(spellID)) then
		hasUse = true
	elseif plainNumber(spellID) or plainString(spellName) then
		hasUse = true
	end
	if not hasUse or classID ~= Logic.ITEM_CLASS_CONSUMABLE then
		return nil
	end
	local icon = plainNumber(info.iconFileID)
	if not icon then
		icon = plainNumber(instantIcon)
	end
	return {
		itemID = itemID,
		name = plainString(info.itemName),
		icon = icon,
		classID = classID,
		spellID = true,
	}
end

local function BagConsumables()
	if type(C_Container) ~= "table" or type(C_Container.GetContainerNumSlots) ~= "function" or type(C_Container.GetContainerItemInfo) ~= "function" then
		return {}
	end
	local rows = {}
	local bag
	for bag = 0, 5 do
		local slots = plainNumber(C_Container.GetContainerNumSlots(bag))
		if slots and slots > 0 then
			local slot
			for slot = 1, slots do
				local ok, row = pcall(function()
					return ConsumableRow(C_Container.GetContainerItemInfo(bag, slot))
				end)
				if ok and type(row) == "table" then
					table.insert(rows, row)
				end
			end
		end
	end
	return Logic.ConsumableEntries(rows)
end

local function HideSectionScale(header)
	if header.check then
		header.check:Hide()
	end
	if header.checkLabel then
		header.checkLabel:Hide()
	end
	if header.sectionSlider then
		header.sectionSlider:Hide()
	end
	if header.themeCheck then
		header.themeCheck:Hide()
	end
	if header.themeCheckLabel then
		header.themeCheckLabel:Hide()
	end
	if header.sectionTheme then
		header.sectionTheme:Hide()
	end
end

local function EnsureCheckLabel(header, key, text)
	local label = header[key]
	if label then
		return label
	end
	label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetText(text)
	ApplySpellbookColor(label)
	header[key] = label
	return label
end

local function ShowSectionScale(header)
	if not header.check then
		local check = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
		check:SetSize(26, 26)
		check:SetScript("OnClick", function(self)
			LB.DB().launcherScaleSeparate = self:GetChecked() and true or false
			if header.sectionSlider then
				header.sectionSlider:SetShown(LB.DB().launcherScaleSeparate)
			end
			LB.ApplyScale(LB.CurrentScale())
		end)
		header.check = check
		EnsureCheckLabel(header, "checkLabel", "Scale")
		local slider = CreateFrame("Frame", nil, header, "MinimalSliderWithSteppersTemplate")
		slider:SetSize(Logic.SECTION_STACK.sliderW, Logic.SECTION_STACK.sliderH)
		local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
		if slider.Init and label then
			local formatters = {}
			formatters[label.Top] = function(value)
				if type(value) ~= "number" then
					return ""
				end
				return math.floor(value + 0.5) .. "%"
			end
			slider:Init(Logic.ScalePercent(LB.DB().launcherScale), Logic.SCALE_MIN_PERCENT, Logic.SCALE_MAX_PERCENT, Logic.SCALE_STEPS, formatters)
		end
		local function OnChanged(_, value)
			if LB.launcherScaleWriting then
				return
			end
			local percent = Logic.ScaleFromSlider(slider, value)
			if type(percent) ~= "number" then
				return
			end
			LB.ApplyLauncherScale(percent / 100)
		end
		local inner = slider.Slider
		if type(inner) == "table" and type(inner.HookScript) == "function" then
			inner:HookScript("OnValueChanged", OnChanged)
		elseif type(slider.HookScript) == "function" then
			slider:HookScript("OnValueChanged", OnChanged)
		end
		header.sectionSlider = slider
	end
	if not header.themeCheck then
		local themeCheck = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
		themeCheck:SetSize(26, 26)
		themeCheck:SetScript("OnClick", function(self)
			LB.DB().launcherThemeSeparate = self:GetChecked() and true or false
			if header.sectionTheme then
				header.sectionTheme:SetShown(LB.DB().launcherThemeSeparate)
			end
			LB.RepaintPlaced()
		end)
		header.themeCheck = themeCheck
		EnsureCheckLabel(header, "themeCheckLabel", "Theme")
		local dropdown = CreateFrame("DropdownButton", nil, header, "WowStyle1DropdownTemplate")
		dropdown:SetSize(Logic.SECTION_STACK.dropW, Logic.SECTION_STACK.dropH)
		local theme = Logic.NormalizeTheme(LB.DB().launcherTheme)
		if dropdown.SetDefaultText then
			dropdown:SetDefaultText(Logic.THEMES[theme].title)
		end
		if MenuUtil and MenuUtil.CreateRadioMenu then
			local rows = {}
			local i
			for i = 1, #Logic.THEME_ORDER do
				local id = Logic.THEME_ORDER[i]
				rows[i] = { Logic.THEMES[id].title, id }
			end
			MenuUtil.CreateRadioMenu(dropdown, function(id)
				return Logic.NormalizeTheme(LB.DB().launcherTheme) == id
			end, function(id)
				LB.ApplyLauncherTheme(id)
			end, unpack(rows))
		end
		header.sectionTheme = dropdown
	end
	local scaleLabel = EnsureCheckLabel(header, "checkLabel", "Scale")
	local themeLabel = EnsureCheckLabel(header, "themeCheckLabel", "Theme")
	local row = Logic.SectionRow(scaleLabel:GetStringWidth(), themeLabel:GetStringWidth())
	local frames = {
		title = header.text,
		scaleCheck = header.check,
		scaleLabel = header.checkLabel,
		slider = header.sectionSlider,
		themeCheck = header.themeCheck,
		themeLabel = header.themeCheckLabel,
		dropdown = header.sectionTheme,
	}
	local order = { "scaleCheck", "scaleLabel", "slider", "themeCheck", "themeLabel", "dropdown" }
	local i
	for i = 1, #order do
		local anchor = row.anchors[order[i]]
		local frame = frames[order[i]]
		local relFrame = anchor and frames[anchor.rel]
		if frame and relFrame then
			frame:ClearAllPoints()
			frame:SetPoint(anchor.point, relFrame, anchor.relPoint, anchor.x, anchor.y)
		end
	end
	header.check:Show()
	if header.check.SetChecked then
		header.check:SetChecked(LB.DB().launcherScaleSeparate)
	end
	scaleLabel:Show()
	ApplySpellbookColor(scaleLabel)
	local slider = header.sectionSlider
	if slider.SetValue and not LB.launcherScaleWriting then
		LB.launcherScaleWriting = true
		slider:SetValue(Logic.ScalePercent(LB.DB().launcherScale))
		LB.launcherScaleWriting = nil
	end
	slider:SetShown(LB.DB().launcherScaleSeparate)
	LB.launcherSlider = slider
	local themeCheck = header.themeCheck
	themeCheck:Show()
	if themeCheck.SetChecked then
		themeCheck:SetChecked(LB.DB().launcherThemeSeparate)
	end
	themeLabel:Show()
	ApplySpellbookColor(themeLabel)
	local dropdown = header.sectionTheme
	local theme = Logic.NormalizeTheme(LB.DB().launcherTheme)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(Logic.THEMES[theme].title)
	end
	dropdown:SetShown(LB.DB().launcherThemeSeparate)
	LB.launcherThemeDropdown = dropdown
end

local function LayoutCatalog(items, scheduleItems)
	local page = LB.page
	if not page then
		return
	end
	local content = page.content
	local width = page.scroll:GetWidth()
	if not width or width < 40 then
		width = page:GetWidth()
	end
	if not width or width < 40 then
		width = 680
	end
	local columns = 3
	if width > 1000 then
		columns = 6
	end
	local rowH = 60
	local yGap = 10
	local xPad = 15
	local headerH = Logic.SECTION_STACK.plain
	local pad = Logic.CatalogTextLeft()
	local inner = width - pad * 2
	if inner < 40 then
		inner = width
		pad = 0
	end
	local colWidth = math.floor((inner - xPad * (columns - 1)) / columns)
	if colWidth < 40 then
		colWidth = 40
	end
	local sections = Logic.BuildSections(SkillLines(), SpellAt, Logic.VisibleLaunchers(BindingExists), items, Logic.Macros(_G))
	local y = 0
	local col = 0
	local buttonIndex = 0
	local headerIndex = 0
	local s
	for s = 1, #sections do
		local section = sections[s]
		if col ~= 0 then
			y = y + rowH + yGap
			col = 0
		end
		headerIndex = headerIndex + 1
		local header = LB.catalogHeaders[headerIndex]
		if not header then
			header = CreateFrame("Frame", nil, content)
			header.backplate = header:CreateTexture(nil, "BACKGROUND")
			header.backplate:SetAtlas("spellbook-list-backplate", true)
			header.backplate:SetAlpha(0.65)
			header.backplate:SetAllPoints(header)
			header.text = header:CreateFontString(nil, "OVERLAY", "SystemFont_Huge2")
			header.text:SetJustifyH("LEFT")
			header.divider = header:CreateTexture(nil, "ARTWORK")
			header.divider:SetAtlas("spellbook-divider", true)
			header.divider:SetHeight(Logic.SECTION_STACK.divider)
			header.divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
			header.divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
			LB.catalogHeaders[headerIndex] = header
		end
		headerH = Logic.CatalogHeaderHeight(section.title)
		header:ClearAllPoints()
		header:SetSize(inner, headerH)
		header:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -y)
		header.text:ClearAllPoints()
		local textY = -4
		if section.title == Logic.SECTION_ORDER[1] then
			textY = Logic.SectionHeaderInset()
		end
		header.text:SetPoint("TOPLEFT", header, "TOPLEFT", pad, textY)
		header.text:SetText(section.title)
		ApplySpellbookColor(header.text)
		if section.title == Logic.SECTION_ORDER[1] then
			ShowSectionScale(header)
		else
			header.text:SetPoint("TOPRIGHT", header, "TOPRIGHT", -pad, textY)
			HideSectionScale(header)
		end
		header:Show()
		y = y + headerH + yGap
		local e
		for e = 1, #section.entries do
			local entry = section.entries[e]
			if col >= columns then
				col = 0
				y = y + rowH + yGap
			end
			buttonIndex = buttonIndex + 1
			local row = LB.catalogButtons[buttonIndex]
			if not row then
				row = CreateFrame("Button", nil, content)
				row.lbCatalog = true
				row.backplate = row:CreateTexture(nil, "BACKGROUND")
				row.backplate:SetAtlas("spellbook-item-backplate", true)
				row.backplate:SetAlpha(0.33)
				row.backplate:SetPoint("CENTER", row, "CENTER", 5, -5)
				row.icon = row:CreateTexture(nil, "ARTWORK")
				row.icon:SetSize(40, 40)
				row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
				row.nameText = row:CreateFontString(nil, "OVERLAY", "SystemFont_Large")
				row.nameText:SetJustifyH("LEFT")
				row.nameText:SetPoint("LEFT", row, "LEFT", 50, 0)
				row.nameText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
				row:RegisterForDrag("LeftButton")
				row:SetScript("OnDragStart", function(self)
					local dragged = self.entry
					if not dragged then
						return
					end
					if dragged.kind == "item" or dragged.kind == "macro" then
						LB.dragSpell = { kind = dragged.kind, payload = dragged.payload, icon = dragged.icon }
						ShowSpellGhost(dragged.icon)
						ShowReceive(true)
						return
					end
					if dragged.kind == "spell" then
						if InCombatLockdown() then
							LB.Say("Cannot pick up a spell in combat.")
							return
						end
						LB.dragSpell = { kind = "spell", payload = dragged.payload, icon = dragged.icon }
						ShowSpellGhost(dragged.icon)
						ShowReceive(true)
						return
					end
					BeginLauncherDrag(dragged)
				end)
				row:SetScript("OnEnter", function(self)
					LB.ShowTip(self, self.entry)
				end)
				row:SetScript("OnLeave", function()
					if type(GameTooltip) == "table" and type(GameTooltip.Hide) == "function" then
						GameTooltip:Hide()
					end
				end)
				LB.catalogButtons[buttonIndex] = row
			end
			row.entry = entry
			row:SetSize(colWidth, rowH)
			row.icon:SetSize(40, 40)
			PaintCatalogIcon(row.icon, entry)
			row.nameText:SetText(entry.name or "")
			ApplySpellbookColor(row.nameText)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", content, "TOPLEFT", pad + col * (colWidth + xPad), -y)
			row:Show()
			col = col + 1
		end
	end
	if col ~= 0 then
		y = y + rowH
	end
	local i
	for i = headerIndex + 1, #LB.catalogHeaders do
		LB.catalogHeaders[i]:Hide()
	end
	for i = buttonIndex + 1, #LB.catalogButtons do
		LB.catalogButtons[i]:Hide()
	end
	content:SetSize(width, math.max(y + 12, 40))
	page.scroll:SetVerticalScroll(0)
	if not scheduleItems or LB.itemScanQueued then
		return
	end
	LB.itemScanQueued = true
	local function finishItems()
		LB.itemScanQueued = false
		if not LB.page or not LB.page:IsShown() then
			return
		end
		local ok, scanned = pcall(BagConsumables)
		if ok and type(scanned) == "table" then
			LayoutCatalog(scanned, false)
		end
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, finishItems)
	else
		finishItems()
	end
end

local function ClearBlizzardPage(book)
	local paged = book and book.PagedSpellsFrame
	if not paged then
		return
	end
	if paged.RemoveDataProvider then
		paged:RemoveDataProvider()
	end
	if paged.ViewFrames then
		local i
		for i = 1, #paged.ViewFrames do
			paged.ViewFrames[i]:Hide()
		end
	end
	if paged.PagingControls then
		paged.PagingControls:Hide()
	end
	paged:Hide()
end

local function RestoreBlizzardPage(book)
	local paged = book and book.PagedSpellsFrame
	if not paged then
		return
	end
	paged:Show()
	local views = paged.viewsPerPage or 1
	if paged.ViewFrames then
		local i
		for i = 1, #paged.ViewFrames do
			if i <= views then
				paged.ViewFrames[i]:Show()
			else
				paged.ViewFrames[i]:Hide()
			end
		end
	end
	if paged.PagingControls then
		paged.PagingControls:Show()
	end
end

local function AttachCatalogScroll(page)
	local scroll = CreateFrame("ScrollFrame", "LooseButtonsCatalogScroll", page)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(20, 20)
	scroll:SetScrollChild(content)
	scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 0)
	local bar = CreateFrame("EventFrame", "LooseButtonsCatalogBar", page, "WowTrimScrollBar")
	bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 28, 0)
	bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 28, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
	page.scroll = scroll
	page.content = content
end

local function PaintStripButton(button, texture)
	if not button.icon then
		if type(button.Icon) == "table" then
			button.icon = button.Icon
		else
			button.icon = button:CreateTexture(nil, "ARTWORK")
		end
	end
	LB.ClearStateTextures(button)
	LB.PaintStockAction(button, texture)
end

local function CenterLockIcon(button)
	local icon = button.Icon
	if type(icon) ~= "table" or not icon.ClearAllPoints then
		return
	end
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
end

local function CenterStripIcon(button)
	local icon = button.Icon
	if type(icon) ~= "table" or not icon.ClearAllPoints then
		return
	end
	local iconW, iconH = LB.ButtonLayout(button)
	icon:ClearAllPoints()
	icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	if icon.SetSize then
		icon:SetSize(iconW, iconH)
	end
	if icon.SetTexCoord then
		icon:SetTexCoord(0, 1, 0, 1)
	end
end

local function RefreshLockButton()
	local button = LB.lockButton
	if not button then
		return
	end
	local locked = LB.IsLocked()
	local art = Logic.LockArt(locked)
	if button.SetIcon then
		button:SetIcon(art)
	end
	PaintStripButton(button, art)
	CenterLockIcon(button)
	if button.SetButtonState then
		if locked then
			button:SetButtonState("PUSHED", true)
		else
			button:SetButtonState("NORMAL", false)
		end
	end
	if button.SetTooltipInfo then
		if locked then
			button:SetTooltipInfo("Unlock", "Buttons are locked. Click to move and snap them again.")
		else
			button:SetTooltipInfo("Lock", "Stop moving and snapping loose buttons.")
		end
	end
end

local function ToggleLock()
	local live = LB.DB()
	live.locked = Logic.NormalizeLocked(not LB.IsLocked())
	RefreshLockButton()
end

local function LayoutLabel()
	return Logic.Layouts.ActiveName(LB.Account(), LB.CharKey()) or Logic.BLANK_LAYOUT
end

local function RefreshLayoutChrome()
	RefreshLockButton()
	if LB.themeDropdown and LB.themeDropdown.SetDefaultText then
		LB.themeDropdown:SetDefaultText(Logic.THEMES[LB.CurrentTheme()].title)
	end
	if LB.scaleSlider and LB.scaleSlider.SetValue then
		LB.scaleWriting = true
		LB.scaleSlider:SetValue(Logic.ScalePercent(LB.CurrentScale()))
		LB.scaleWriting = nil
	end
	if LB.layoutDropdown and LB.layoutDropdown.SetDefaultText then
		LB.layoutDropdown:SetDefaultText(LayoutLabel())
	end
	if LB.layoutDropdown and LB.layoutDropdown.GenerateMenu then
		LB.layoutDropdown:GenerateMenu()
	end
	if LB.page and LB.page.IsShown and LB.page:IsShown() then
		LayoutCatalog(nil, true)
	end
end

local function PresentLayout()
	if LB.poolReady then
		LB.ApplyAll()
	else
		LB.EnsurePool()
	end
	RefreshLayoutChrome()
end

local function layoutLoadedText()
	local text = "Loaded. Quick Keybind keys stay on their slots."
	local buttons = LB.DB().buttons
	local i
	for i = 1, #buttons do
		local row = buttons[i]
		if type(row) == "table" and row.kind == "macro" then
			return text .. " Macro buttons run this character's macro with the same name."
		end
	end
	return text
end

local function PopupEditText(dialog)
	if type(dialog) ~= "table" then
		return ""
	end
	if type(dialog.GetEditBox) == "function" then
		local box = dialog:GetEditBox()
		if type(box) == "table" and type(box.GetText) == "function" then
			local text = box:GetText()
			if type(text) == "string" then
				return text
			end
		end
	end
	if type(dialog.editBox) == "table" and type(dialog.editBox.GetText) == "function" then
		local text = dialog.editBox:GetText()
		if type(text) == "string" then
			return text
		end
	end
	return ""
end

local function NameIsBlank(text)
	return type(text) ~= "string" or string.match(text, "^[ \t]*$") ~= nil
end

local function CommitNew(typed)
	local created, detail = Logic.Layouts.Create(LB.Account(), LB.CharKey(), typed, nil, InCombatLockdown())
	if not created then
		LB.Say(detail)
		return
	end
	RefreshLayoutChrome()
end

local function CommitImport(pasted, typed)
	local profile, sharedName = Logic.ShareCodec.Decode(pasted)
	if not profile then
		LB.Say(sharedName)
		return
	end
	local name = typed
	if NameIsBlank(name) then
		name = sharedName
	end
	local created, detail = Logic.Layouts.Create(LB.Account(), LB.CharKey(), name, profile, InCombatLockdown())
	if not created then
		LB.Say(detail)
		return
	end
	PresentLayout()
	LB.Say(layoutLoadedText())
end

local function CommitDelete(name)
	local effect, detail = Logic.Layouts.Delete(LB.Account(), LB.CharKey(), name, InCombatLockdown())
	if not effect then
		LB.Say(detail)
		return
	end
	if effect == "cleared" then
		PresentLayout()
		LB.Say("Removed that layout.")
		return
	end
	RefreshLayoutChrome()
end

local function ConfirmDelete(name)
	if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
		CommitDelete(name)
		return
	end
	local dialog = StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_DELETE"]
	dialog.text = Logic.Layouts.DeleteText(LB.Account(), LB.CharKey(), name)
	StaticPopup_Show("LOOSEBUTTONS_LAYOUT_DELETE", nil, nil, { name = name })
end

local function OpenNewLayout()
	if type(StaticPopup_Show) == "function" then
		StaticPopup_Show("LOOSEBUTTONS_LAYOUT_NAME")
		return
	end
	LB.Say("Enter a name.")
end

local function BindEscape(box, frame)
	box:SetScript("OnEscapePressed", function(self)
		self:SetPropagateKeyboardInput(false)
		frame:Hide()
	end)
end

local function AttachDialogChrome(frame)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableKeyboard(true)
	frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			self:Hide()
			return
		end
		self:SetPropagateKeyboardInput(true)
	end)
	local drag = CreateFrame("Button", nil, frame)
	drag:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	drag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, 0)
	drag:SetHeight(28)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	drag:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
	end)
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)
	local catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("DIALOG")
	catcher:EnableMouse(true)
	catcher:SetScript("OnClick", function()
		frame:Hide()
	end)
	catcher:Hide()
	frame:HookScript("OnShow", function()
		catcher:SetFrameLevel(1)
		frame:SetFrameLevel(20)
		catcher:Show()
	end)
	frame:HookScript("OnHide", function()
		catcher:Hide()
	end)
end

function LB.FitDialog(frame, bottom, pad, watched)
	local function fit()
		local top = frame:GetTop()
		local low = bottom:GetBottom()
		if type(top) ~= "number" or type(low) ~= "number" then
			return
		end
		-- Centered frame: a new height moves the top, and children move with it.
		local height = (top - low) + pad
		if height > frame:GetHeight() + 0.5 then
			frame:SetHeight(height)
		end
	end
	local function watch(widget)
		if type(widget) == "table" and type(widget.HookScript) == "function" then
			widget:HookScript("OnSizeChanged", fit)
		end
	end
	watch(bottom)
	if type(watched) == "table" then
		local i
		for i = 1, #watched do
			watch(watched[i])
		end
	end
	frame:HookScript("OnShow", fit)
	fit()
end

local function EnsureShareFrame()
	if LB.shareFrame then
		return LB.shareFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsShare", UIParent)
	frame:SetSize(420, 180)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Share")
	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
	hint:SetText("Press Ctrl+C to copy.")
	local box = CreateFrame("EditBox", nil, frame)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetSize(388, 90)
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -56)
	box:SetTextInsets(6, 6, 6, 6)
	box:SetMaxLetters(20000)
	local shareBg = box:CreateTexture(nil, "BACKGROUND")
	shareBg:SetAllPoints(box)
	shareBg:SetColorTexture(0, 0, 0, 0.45)
	frame.box = box
	BindEscape(box, frame)
	AttachDialogChrome(frame)
	LB.FitDialog(frame, box, 16)
	frame:Hide()
	LB.shareFrame = frame
	return frame
end

local function OpenShare()
	local name = Logic.Layouts.ActiveName(LB.Account(), LB.CharKey())
	if not name then
		LB.Say("Nothing to share yet.")
		return
	end
	local text, reason = Logic.ShareCodec.Encode(Logic.Profile(LB.DB()), name)
	if not text then
		LB.Say(reason)
		return
	end
	local frame = EnsureShareFrame()
	frame.box:SetText(text)
	frame:Show()
	frame.box:SetFocus()
	frame.box:HighlightText()
end

local function EnsureImportFrame()
	if LB.importFrame then
		return LB.importFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsImport", UIParent)
	frame:SetSize(420, 236)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Import")
	local paste = CreateFrame("EditBox", nil, frame)
	paste:SetMultiLine(true)
	paste:SetAutoFocus(false)
	paste:SetFontObject("ChatFontNormal")
	paste:SetSize(388, 90)
	paste:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
	paste:SetTextInsets(6, 6, 6, 6)
	paste:SetMaxLetters(20000)
	local pasteBg = paste:CreateTexture(nil, "BACKGROUND")
	pasteBg:SetAllPoints(paste)
	pasteBg:SetColorTexture(0, 0, 0, 0.45)
	local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameLabel:SetPoint("TOPLEFT", paste, "BOTTOMLEFT", 0, -8)
	nameLabel:SetText("Rename Layout")
	local nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	nameBox:SetAutoFocus(false)
	nameBox:SetSize(240, 22)
	nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
	nameBox:SetFontObject("ChatFontNormal")
	nameBox:SetMaxLetters(32)
	local accept = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	accept:SetSize(88, 22)
	accept:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -12)
	accept:SetText("Import")
	accept:SetScript("OnClick", function()
		local pasted = paste:GetText()
		local typed = nameBox:GetText()
		CommitImport(pasted, typed)
		frame:Hide()
	end)
	BindEscape(paste, frame)
	BindEscape(nameBox, frame)
	frame:SetScript("OnShow", function()
		paste:SetText("")
		nameBox:SetText("")
	end)
	AttachDialogChrome(frame)
	LB.FitDialog(frame, accept, 16, { paste, nameBox })
	frame:Hide()
	LB.importFrame = frame
	return frame
end

local function SelectLayout(name)
	local profile, changed = Logic.Layouts.Switch(LB.Account(), LB.CharKey(), name, InCombatLockdown())
	if not profile then
		LB.Say(changed)
		return
	end
	if changed then
		PresentLayout()
		LB.Say(layoutLoadedText())
	end
end

local function LayoutMenu(_, root)
	if type(root) ~= "table" or type(root.CreateRadio) ~= "function" then
		return
	end
	local names = Logic.Layouts.Names(LB.Account())
	local i
	for i = 1, #names do
		local name = names[i]
		root:CreateRadio(name, function(picked)
			return Logic.Layouts.ActiveName(LB.Account(), LB.CharKey()) == picked
		end, function(picked)
			SelectLayout(picked)
		end, name)
	end
	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end
	root:CreateRadio(Logic.BLANK_LAYOUT, function()
		return Logic.Layouts.ActiveName(LB.Account(), LB.CharKey()) == nil
	end, function()
		SelectLayout(nil)
	end)
	if type(root.CreateDivider) == "function" then
		root:CreateDivider()
	end
	local function addAction(text, fn)
		local row = root:CreateButton(text, fn)
		if type(row) == "table" and type(row.SetSelectionIgnored) == "function" then
			row:SetSelectionIgnored()
		end
	end
	addAction("New Layout", OpenNewLayout)
	addAction("Import", function()
		EnsureImportFrame():Show()
	end)
	addAction("Share", OpenShare)
	local deleteRow = root:CreateButton("Delete")
	if type(deleteRow) == "table" and type(deleteRow.SetSelectionIgnored) == "function" then
		deleteRow:SetSelectionIgnored()
	end
	if type(deleteRow) == "table" and type(deleteRow.CreateButton) == "function" then
		for i = 1, #names do
			local name = names[i]
			local child = deleteRow:CreateButton(name, function()
				ConfirmDelete(name)
			end)
			if type(child) == "table" and type(child.SetSelectionIgnored) == "function" then
				child:SetSelectionIgnored()
			end
		end
	end
end

local DROP_W = 170
local DROP_H = 22
local STACK_GAP = 2
local STACK_LIFT = (DROP_H + STACK_GAP) / 2
local SLIDER_W = 176
local SLIDER_H = 40
local SLIDER_NUDGE = 4
local STRIP_H = DROP_H * 2 + STACK_GAP + 8
local SUBBAR_NUDGE = 6
local PARCHMENT_CAP = "GarrMission_ParchmentHeader-End"
local PARCHMENT_MID = "_GarrMission_ParchmentHeader-Mid"
local PARCHMENT_OVERLAP = 35

local function EnsureLayoutControl(strip, theme)
	local dropdown = CreateFrame("DropdownButton", "LooseButtonsLayout", strip, "WowStyle1DropdownTemplate")
	dropdown:SetSize(DROP_W, DROP_H)
	dropdown:SetPoint("TOPLEFT", theme, "BOTTOMLEFT", 0, -STACK_GAP)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(LayoutLabel())
	end
	if dropdown.SetupMenu then
		dropdown:SetupMenu(LayoutMenu)
	end
	LB.layoutDropdown = dropdown
end

if type(StaticPopupDialogs) == "table" then
	StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_NAME"] = {
		text = "New layout name",
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = true,
		maxLetters = 32,
		OnAccept = function(dialog)
			CommitNew(PopupEditText(dialog))
		end,
		EditBoxOnEnterPressed = function(editBox)
			local dialog = editBox:GetParent()
			CommitNew(PopupEditText(dialog))
			if type(StaticPopup_Hide) == "function" then
				StaticPopup_Hide("LOOSEBUTTONS_LAYOUT_NAME")
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs["LOOSEBUTTONS_LAYOUT_DELETE"] = {
		text = "Delete this saved layout?",
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			if type(data) == "table" then
				CommitDelete(data.name)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
end


local function HideNamed(name)
	local frame = _G[name]
	if frame and frame.IsShown and frame:IsShown() then
		frame:Hide()
	end
end

local function EnsureHelpFrame()
	if LB.helpFrame then
		return LB.helpFrame
	end
	local frame = CreateFrame("Frame", "LooseButtonsHelp", UIParent)
	local rows = Logic.HELP
	local rowH = 20
	frame:SetSize(640, 48 + #rows * rowH)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0.06, 0.05, 0.04, 0.94)
	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
	title:SetText("Help")
	local i
	for i = 1, #rows do
		local row = rows[i]
		local y = -40 - (i - 1) * rowH
		local gesture = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		gesture:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, y)
		gesture:SetJustifyH("LEFT")
		gesture:SetText(row.gesture)
		local detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, y)
		detail:SetJustifyH("LEFT")
		if detail.SetWidth then
			detail:SetWidth(410)
		end
		detail:SetText(row.detail)
	end
	AttachDialogChrome(frame)
	frame:Hide()
	LB.helpFrame = frame
	return frame
end

local function OpenHelp()
	HideNamed("LooseButtonsShare")
	HideNamed("LooseButtonsImport")
	EnsureHelpFrame():Show()
end

local function ToggleHelp()
	local frame = EnsureHelpFrame()
	if frame:IsShown() then
		frame:Hide()
		return
	end
	OpenHelp()
end

local PAGE_CLICK = {
	clear = LB.ConfirmClear,
	edit = LB.ToggleBind,
	lock = ToggleLock,
	help = ToggleHelp,
}

local function AttachParchmentRibbon(strip)
	local left = strip:CreateTexture(nil, "BACKGROUND", nil, 1)
	left:SetAtlas(PARCHMENT_CAP, true)
	left:SetHeight(STRIP_H)
	left:SetPoint("LEFT", strip, "LEFT", 0, 0)
	local right = strip:CreateTexture(nil, "BACKGROUND", nil, 1)
	right:SetAtlas(PARCHMENT_CAP, true)
	right:SetHeight(STRIP_H)
	right:SetTexCoord(1, 0, 0, 1)
	right:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
	local mid = strip:CreateTexture(nil, "BACKGROUND", nil, 0)
	mid:SetAtlas(PARCHMENT_MID, true)
	mid:SetHorizTile(true)
	mid:SetHeight(STRIP_H)
	mid:SetPoint("LEFT", left, "RIGHT", -PARCHMENT_OVERLAP, 0)
	mid:SetPoint("RIGHT", right, "LEFT", PARCHMENT_OVERLAP, 0)
end

local function EnsureSubBar(book)
	local strip = CreateFrame("Frame", nil, book)
	strip:SetHeight(STRIP_H)
	strip:Hide()
	AttachParchmentRibbon(strip)
	local previous
	local i
	for i = 1, #Logic.PAGE_COMMANDS do
		local spec = Logic.PAGE_COMMANDS[i]
		local buttonName = nil
		if spec.id == "help" then
			buttonName = "LooseButtonsHelpButton"
		end
		local button = CreateFrame("Button", buttonName, strip, "SquareIconButtonTemplate")
		button:SetSize(32, 32)
		if previous then
			button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
		else
			button:SetPoint("LEFT", strip, "LEFT", 8, 0)
		end
		if spec.icon and button.SetIcon then
			button:SetIcon(spec.icon)
		end
		PaintStripButton(button, spec.icon)
		if spec.id == "clear" then
			CenterStripIcon(button)
		end
		if spec.atlas and button.icon and button.icon.SetAtlas then
			button.icon:SetAtlas("UI-HUD-MicroMenu-" .. spec.atlas .. "-Up")
			button.icon:Show()
		end
		local run = PAGE_CLICK[spec.id]
		button:SetOnClickHandler(function()
			if run then
				run()
			end
		end)
		button:SetTooltipInfo(spec.title, spec.text)
		if spec.id == "lock" then
			LB.lockButton = button
			RefreshLockButton()
		end
		previous = button
	end
	local dropdown = CreateFrame("DropdownButton", "LooseButtonsTheme", strip, "WowStyle1DropdownTemplate")
	dropdown:SetSize(DROP_W, DROP_H)
	if previous then
		dropdown:SetPoint("LEFT", previous, "RIGHT", 8, STACK_LIFT)
	else
		dropdown:SetPoint("LEFT", strip, "LEFT", 8, STACK_LIFT)
	end
	local theme = Logic.THEMES[LB.CurrentTheme()]
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(theme.title)
	end
	if MenuUtil and MenuUtil.CreateRadioMenu then
		local rows = {}
		local i
		for i = 1, #Logic.THEME_ORDER do
			local id = Logic.THEME_ORDER[i]
			rows[i] = { Logic.THEMES[id].title, id }
		end
		MenuUtil.CreateRadioMenu(dropdown, function(id)
			return LB.CurrentTheme() == id
		end, function(id)
			LB.ApplyTheme(id)
		end, unpack(rows))
	end
	LB.themeDropdown = dropdown
	local slider = CreateFrame("Frame", "LooseButtonsScale", strip, "MinimalSliderWithSteppersTemplate")
	slider:SetSize(SLIDER_W, SLIDER_H)
	slider:SetPoint("LEFT", dropdown, "RIGHT", 12, -STACK_LIFT - SLIDER_NUDGE)
	local label = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
	if slider.Init and label then
		local formatters = {}
		formatters[label.Top] = function(value)
			if type(value) ~= "number" then
				return ""
			end
			return math.floor(value + 0.5) .. "%"
		end
		slider:Init(Logic.ScalePercent(LB.CurrentScale()), Logic.SCALE_MIN_PERCENT, Logic.SCALE_MAX_PERCENT, Logic.SCALE_STEPS, formatters)
	end
	local function OnScaleChanged(_, value)
		if LB.scaleWriting then
			return
		end
		local percent = Logic.ScaleFromSlider(slider, value)
		if type(percent) ~= "number" then
			return
		end
		LB.ApplyScale(percent / 100)
	end
	local inner = slider.Slider
	if type(inner) == "table" and type(inner.HookScript) == "function" then
		inner:HookScript("OnValueChanged", OnScaleChanged)
	elseif type(slider.HookScript) == "function" then
		slider:HookScript("OnValueChanged", OnScaleChanged)
	end
	LB.scaleSlider = slider
	EnsureLayoutControl(strip, dropdown)
	LB.subbar = strip
end

local function AnchorSubBar(book)
	local strip = LB.subbar
	if not strip or not book then
		return
	end
	strip:ClearAllPoints()
	local ribbonRight = -(80 + 4 + Logic.CatalogTextLeft())
	local tabs = book.CategoryTabSystem
	if tabs then
		strip:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 16, -4 - SUBBAR_NUDGE)
		strip:SetPoint("TOPRIGHT", book, "TOPRIGHT", ribbonRight, -55 - SUBBAR_NUDGE)
	else
		strip:SetPoint("TOPLEFT", book, "TOPLEFT", 86, -55 - SUBBAR_NUDGE)
		strip:SetPoint("TOPRIGHT", book, "TOPRIGHT", ribbonRight, -55 - SUBBAR_NUDGE)
	end
	local level = 0
	if book.GetFrameLevel then
		level = book:GetFrameLevel() or 0
	end
	strip:SetFrameLevel(level + 40)
end

local function EnsurePage(book)
	if LB.page then
		return
	end
	local page = CreateFrame("Frame", nil, book)
	page:Hide()
	EnsureSubBar(book)
	AttachCatalogScroll(page)
	LB.page = page
end

local function AnchorPage(book)
	local page = LB.page
	if not page then
		return
	end
	page:ClearAllPoints()
	page:SetPoint("TOPLEFT", book, "TOPLEFT", 100, -120)
	page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -80, 48)
	local level = 0
	if book and book.GetFrameLevel then
		level = book:GetFrameLevel() or 0
	end
	page:SetFrameLevel(level + 30)
	AnchorSubBar(book)
end

local function ShowCatalog(book)
	EnsurePage(book)
	ClearBlizzardPage(book)
	AnchorPage(book)
	LB.page:Show()
	if LB.subbar then
		LB.subbar:Show()
	end
	LayoutCatalog(nil, true)
end

local function HideLooseChrome()
	if LB.page then
		LB.page:Hide()
	end
	if LB.subbar then
		LB.subbar:Hide()
	end
end

local function HideCatalog(book)
	HideLooseChrome()
	RestoreBlizzardPage(book)
end

local function CatalogUp()
	if LB.page and LB.page.IsShown and LB.page:IsShown() then
		return true
	end
	if LB.subbar and LB.subbar.IsShown and LB.subbar:IsShown() then
		return true
	end
	return false
end
LB.CatalogUp, LB.ClearBlizzardPage, LB.FinishDrop, LB.HideCatalog = CatalogUp, ClearBlizzardPage, FinishDrop, HideCatalog
LB.HideLooseChrome, LB.HideReceive, LB.LayoutCatalog, LB.OpenHelp = HideLooseChrome, HideReceive, LayoutCatalog, OpenHelp
LB.RefreshLayoutChrome, LB.ShowCatalog, LB.UpdateCooldowns, LB.receive = RefreshLayoutChrome, ShowCatalog, UpdateCooldowns, receive
