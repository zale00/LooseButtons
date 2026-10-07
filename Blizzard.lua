local Logic = LooseButtonsLogic
local LB = Logic.LB

function LB.OverBook()
	local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
	if book and book.IsMouseOver and book:IsShown() and book:IsMouseOver() then
		return true
	end
	return false
end

local CLICK = {
	legacy = function()
		if ToggleLegacySystemUI then
			ToggleLegacySystemUI()
		end
	end,
}

function LB.RunLauncher(record)
	local spec = Logic.LauncherByCommand(record.payload)
	local fn = spec and CLICK[spec.click]
	if not fn then
		return
	end
	if type(securecall) == "function" then
		securecall(fn)
		return
	end
	fn()
end

function LB.PaintPortrait(icon)
	if not icon or type(SetPortraitTexture) ~= "function" then
		return
	end
	if type(securecall) == "function" then
		securecall(SetPortraitTexture, icon, "player")
		return
	end
	SetPortraitTexture(icon, "player")
end

function LB.BookFrame()
	if C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_PlayerSpells")
	end
	return PlayerSpellsFrame
end

local function HideForOtherTab(book, tabID)
	if book and book.isUpdatingAllSpellData then
		return
	end
	if LB.tabID == nil or tabID == LB.tabID or not LB.CatalogUp() then
		return
	end
	LB.HideLooseChrome()
end

local function WatchTabButton(book, button, tabID, watchedButtons)
	if type(button) ~= "table" or watchedButtons[button] then
		return
	end
	watchedButtons[button] = true
	local function liveID(self)
		if type(self) == "table" and type(self.GetTabID) == "function" then
			local id = self:GetTabID()
			if id ~= nil then
				return id
			end
		end
		return tabID
	end
	if type(button.SetTabSelected) == "function" then
		hooksecurefunc(button, "SetTabSelected", function(self, isSelected)
			local id = liveID(self)
			if isSelected and id ~= LB.tabID then
				HideForOtherTab(book, id)
			elseif not isSelected and id == LB.tabID then
				HideForOtherTab(book, nil)
			end
		end)
	end
	if type(button.HookScript) ~= "function" then
		return
	end
	button:HookScript("OnClick", function(self)
		local id = liveID(self)
		if id ~= LB.tabID then
			HideForOtherTab(book, id)
		end
	end)
end

local function WatchTabButtons(book, tabs, watchedButtons)
	if not tabs or type(tabs.GetTabButton) ~= "function" then
		return
	end
	local id = 1
	while true do
		local button = tabs:GetTabButton(id)
		if not button then
			break
		end
		WatchTabButton(book, button, id, watchedButtons)
		id = id + 1
	end
end

local function WatchTabSelection(book)
	local tabs = book.CategoryTabSystem
	if not tabs or LB.tabWatched or type(hooksecurefunc) ~= "function" then
		return
	end
	LB.tabWatched = true
	local watchedButtons = {}
	LB.SyncCatalog = function(owner, tabID)
		if tabID == LB.tabID then
			if owner.isUpdatingAllSpellData then
				if LB.wantCatalog then
					LB.ShowCatalog(owner)
				end
				return
			end
			LB.wantCatalog = true
			LB.ShowCatalog(owner)
			return
		end
		if owner.isUpdatingAllSpellData then
			return
		end
		LB.wantCatalog = false
		LB.HideCatalog(owner)
	end
	local function follow(_, tabID)
		LB.SyncCatalog(book, tabID)
	end
	if type(tabs.SetTab) == "function" then
		hooksecurefunc(tabs, "SetTab", follow)
	end
	if type(tabs.SetTabVisuallySelected) == "function" then
		hooksecurefunc(tabs, "SetTabVisuallySelected", follow)
	end
	if type(tabs.AddTab) == "function" then
		hooksecurefunc(tabs, "AddTab", function(self)
			WatchTabButtons(book, self, watchedButtons)
		end)
	end
	WatchTabButtons(book, tabs, watchedButtons)
end

local function BindCatalogTab(_, tabID)
	LB.tabID = tabID
end

local function HideUnavailableTabs(book)
	local mixins = book.categoryMixins
	local tabSystem = book.CategoryTabSystem
	if type(mixins) ~= "table" or not tabSystem or not tabSystem.SetTabShown then
		return
	end
	local i
	for i = 1, #mixins do
		local row = mixins[i]
		if row.GetTabID and row.IsAvailable then
			tabSystem:SetTabShown(row:GetTabID(), row:IsAvailable())
		end
	end
end

local function AddCatalogTab(book)
	local tabID = book:AddIconTab("Interface\\Icons\\INV_Misc_Book_09")
	BindCatalogTab(book, tabID)
	local tabButton = book.CategoryTabSystem and book.CategoryTabSystem.GetTabButton and book.CategoryTabSystem:GetTabButton(tabID)
	if tabButton then
		if tabButton.SetTooltipText then
			tabButton:SetTooltipText("Loose Buttons")
		end
		if tabButton.SetSquareMode then
			tabButton:SetSquareMode(true)
		end
		if tabButton.Icon and tabButton.Icon.SetAtlas then
			tabButton.Icon:SetAtlas("UI-HUD-MicroMenu-SpellbookAbilities-Up")
			if tabButton.Icon.Show then
				tabButton.Icon:Show()
			end
		end
		if type(tabButton.IconMask) == "table" and tabButton.IconMask.Show then
			tabButton.IconMask:Show()
		end
	end
	HideUnavailableTabs(book)
end

local function HookBook()
	if LB.bookHooked then
		return
	end
	local book = PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
	if not book or type(book.CreateCategoryMixins) ~= "function" or type(hooksecurefunc) ~= "function" then
		return
	end
	LB.bookHooked = true
	hooksecurefunc(book, "CreateCategoryMixins", function(self)
		AddCatalogTab(self)
	end)
	if type(book.UpdateDisplayedSpells) == "function" then
		hooksecurefunc(book, "UpdateDisplayedSpells", function(self)
			if LB.wantCatalog and self.GetTab and self:GetTab() == LB.tabID then
				LB.ClearBlizzardPage(self)
			end
		end)
	end
	if type(book.UpdateAllSpellData) == "function" then
		hooksecurefunc(book, "UpdateAllSpellData", function(self)
			if LB.wantCatalog and LB.tabID and self.GetTab and self:GetTab() == LB.tabID then
				LB.ShowCatalog(self)
			elseif LB.CatalogUp() and self.GetTab and LB.tabID and self:GetTab() ~= LB.tabID then
				LB.HideLooseChrome()
			end
		end)
	end
	WatchTabSelection(book)
	if type(book.SetTab) == "function" and not LB.bookTabHooked then
		LB.bookTabHooked = true
		hooksecurefunc(book, "SetTab", function(self, tabID)
			if LB.SyncCatalog then
				LB.SyncCatalog(self, tabID)
			end
		end)
	end
	book:CreateCategoryMixins()
end

local function WatchBook()
	HookBook()
	if EventUtil and EventUtil.ContinueOnAddOnLoaded then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", HookBook)
	end
end

LB.HookBook = HookBook
LB.WatchBook = WatchBook
