local Logic = {}
LooseButtonsLogic = Logic

Logic.ACTION_SLOTS = 48
Logic.LAUNCHER_SLOTS = 24

Logic.ANCHORS = {
	CENTER = true,
	TOP = true,
	BOTTOM = true,
	LEFT = true,
	RIGHT = true,
	TOPLEFT = true,
	TOPRIGHT = true,
	BOTTOMLEFT = true,
	BOTTOMRIGHT = true,
}

Logic.SECTION_ORDER = {
	"Character & info",
}

Logic.SECTION_STACK = {
	labelGap = 2,
	controlGap = 8,
	check = 26,
	sliderW = 180,
	sliderH = 36,
	dropW = 150,
	dropH = 25,
	stackGap = 2,
	sliderNudge = 4,
	sliderCap = 9,
	titleLine = 22,
	band = 14,
	divider = 11,
	plain = 51,
}

Logic.MACRO_SECTIONS = {
	{ scope = "general", title = "General Macros" },
	{ scope = "character", title = "Character Macros" },
}

Logic.ITEM_CLASS_CONSUMABLE = 0

Logic.LAUNCHERS = {
	{ command = "TOGGLECHARACTER0", name = "Character", section = "Character & info", chrome = "micro", portrait = true, click = "character" },
	{ command = "TOGGLESPELLBOOK", name = "Spellbook", section = "Character & info", chrome = "micro", atlas = "SpellbookAbilities", click = "spellbook" },
	{ command = "TOGGLETALENTS", name = "Talents", section = "Character & info", chrome = "micro", atlas = "SpecTalents", click = "talents" },
	{ command = "TOGGLEPROFESSIONBOOK", name = "Professions", section = "Character & info", chrome = "micro", atlas = "Professions", click = "professions" },
	{ command = "TOGGLELEGACYSYSTEM", name = "Legacy", section = "Character & info", chrome = "micro", atlas = "Legacy", click = "legacy" },
	{ command = "TOGGLEQUESTLOG", name = "Quest log", section = "Character & info", chrome = "micro", atlas = "Questlog", click = "quest" },
	{ command = "TOGGLEBACKPACK", name = "Backpack", section = "Items", chrome = "bag", click = "backpack" },
	{ command = "TOGGLEGUILDTAB", name = "Guild", section = "Character & info", chrome = "micro", atlas = "GuildCommunities", click = "guild" },
	{ command = "TOGGLECOLLECTIONS", name = "Collections", section = "Character & info", chrome = "micro", atlas = "Collections", click = "collections" },
	{ command = "TOGGLEGAMEMENU", name = "Game menu", section = "Character & info", chrome = "micro", atlas = "GameMenu", click = "gamemenu" },
}

Logic.EXTRA_LAUNCHERS = {
	{ command = "TOGGLEACHIEVEMENT", name = "Achievements", section = "Character & info", chrome = "micro", atlas = "Achievements", click = "achievements" },
	{ command = "TOGGLEENCOUNTERJOURNAL", name = "Adventure guide", section = "Character & info", chrome = "micro", atlas = "AdventureGuide", click = "journal" },
	{ command = "TOGGLEHOUSINGDASHBOARD", name = "Housing", section = "Character & info", chrome = "micro", atlas = "Housing", click = "housing" },
	{ command = "TOGGLEGROUPFINDER", name = "Group finder", section = "Character & info", chrome = "micro", atlas = "Groupfinder", click = "finder" },
}

function Logic.Pool(kind)
	if kind == "launcher" then
		return "launcher"
	end
	return "action"
end

function Logic.SlotLimit(kind)
	if Logic.Pool(kind) == "launcher" then
		return Logic.LAUNCHER_SLOTS
	end
	return Logic.ACTION_SLOTS
end

function Logic.FrameName(kind, slot)
	if Logic.Pool(kind) == "launcher" then
		return "LooseButtonsLauncher" .. slot
	end
	return "LooseButtonsAction" .. slot
end

function Logic.ClickBinding(frameName)
	if type(frameName) ~= "string" or frameName == "" then
		return nil
	end
	return "CLICK " .. frameName .. ":LeftButton"
end

function Logic.BindingLabel(kind, slot)
	if Logic.Pool(kind) == "launcher" then
		return "Launcher " .. slot
	end
	return "Button " .. slot
end

function Logic.BindingToken(input, alt, ctrl, shift)
	if type(input) ~= "string" or input == "" or input == "UNKNOWN" then
		return nil
	end
	if input == "LSHIFT" or input == "RSHIFT" or input == "SHIFT" or input == "LCTRL" or input == "RCTRL" or input == "CTRL" or input == "LALT" or input == "RALT" or input == "ALT" then
		return nil
	end
	if input == "ESCAPE" then
		return "CLEAR"
	end
	if input == "LeftButton" or input == "RightButton" or input == "Button1" or input == "Button2" then
		return nil
	end
	local key = input
	if input == "MiddleButton" then
		key = "BUTTON3"
	else
		local number = tonumber(string.match(input, "^Button(%d+)$"))
		if number then
			if number < 4 or number > 31 then
				return nil
			end
			key = "BUTTON" .. number
		else
			number = tonumber(string.match(input, "^BUTTON(%d+)$"))
			if number and (number < 3 or number > 31) then
				return nil
			end
		end
	end
	local parts = {}
	if alt then
		table.insert(parts, "ALT")
	end
	if ctrl then
		table.insert(parts, "CTRL")
	end
	if shift then
		table.insert(parts, "SHIFT")
	end
	table.insert(parts, key)
	return table.concat(parts, "-")
end

function Logic.RecordId(kind, slot)
	return Logic.Pool(kind) .. ":" .. slot
end

function Logic.CatalogTextLeft()
	return 8
end

function Logic.ItemUseAttribute(payload)
	if type(payload) == "number" and payload >= 1 and payload == math.floor(payload) then
		return "item:" .. payload
	end
	if type(payload) ~= "string" or payload == "" then
		return nil
	end
	if string.match(payload, "^%d+$") then
		return "item:" .. payload
	end
	return payload
end

function Logic.UsableTexture(icon)
	if type(issecretvalue) == "function" and issecretvalue(icon) then
		return nil
	end
	if type(icon) == "number" and icon >= 1 then
		return icon
	end
	if type(icon) == "string" and icon ~= "" then
		return icon
	end
	return nil
end

function Logic.PlacedTexture(record, textureFor)
	if type(record) ~= "table" then
		return nil
	end
	local stored = Logic.UsableTexture(record.icon)
	if stored then
		return stored
	end
	if type(textureFor) ~= "function" then
		return nil
	end
	return Logic.UsableTexture(textureFor(record))
end

function Logic.ClassToken(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if type(value) ~= "string" or not string.match(value, "^%u+$") then
		return nil
	end
	return value
end

-- A spell row paints when the placing class matches, or when this
-- character's spellbook holds the spell. `inBook` returns nil when it cannot
-- tell, and an unknown answer paints rather than hiding a real button.
function Logic.ShowsFor(record, class, inBook)
	if type(record) ~= "table" or record.kind ~= "spell" then
		return true
	end
	if record.class ~= nil and record.class == class then
		return true
	end
	local found = nil
	if type(inBook) == "function" then
		found = inBook(record.payload)
	end
	return found ~= false
end

local function wholeNumber(value, minimum)
	return type(value) == "number" and value >= minimum and value == math.floor(value)
end

function Logic.Normalize(list)
	local out = {}
	local indexByPoolSlot = {}
	if type(list) ~= "table" then
		return out
	end
	local i
	for i = 1, #list do
		local raw = list[i]
		if type(raw) == "table" then
			local kind = raw.kind
			local known = kind == "spell" or kind == "item" or kind == "macro" or kind == "launcher"
			local slot = raw.slot
			if known and wholeNumber(slot, 1) and slot <= Logic.SlotLimit(kind) then
				local payload = raw.payload
				local payloadOk = false
				if kind == "launcher" then
					payloadOk = type(payload) == "string" and Logic.LauncherByCommand(payload) ~= nil
				elseif kind == "macro" then
					payloadOk = wholeNumber(payload, 1) or (type(payload) == "string" and payload ~= "")
				else
					payloadOk = wholeNumber(payload, 1)
				end
				if payloadOk then
					local point = raw.point
					local relPoint = raw.relPoint
					if not Logic.ANCHORS[point] then
						point = "CENTER"
					end
					if not Logic.ANCHORS[relPoint] then
						relPoint = "CENTER"
					end
					local x = raw.x
					local y = raw.y
					if type(x) ~= "number" then
						x = 0
					end
					if type(y) ~= "number" then
						y = 0
					end
					local icon = raw.icon
					if type(issecretvalue) == "function" and issecretvalue(icon) then
						icon = nil
					end
					local key = raw.key
					if type(issecretvalue) == "function" and issecretvalue(key) then
						key = nil
					end
					if type(key) ~= "string" or key == "" then
						key = nil
					end
					local chrome, atlas, portrait
					if kind == "launcher" then
						chrome, atlas, portrait = Logic.FaceFields(raw, payload)
					end
					local class
					if kind == "spell" then
						class = Logic.ClassToken(raw.class)
					end
					local record = {
						id = Logic.RecordId(kind, slot),
						kind = kind,
						payload = payload,
						class = class,
						icon = Logic.UsableTexture(icon),
						chrome = chrome,
						atlas = atlas,
						portrait = portrait,
						key = key,
						point = point,
						relPoint = relPoint,
						x = x,
						y = y,
						slot = slot,
						north = Logic.LinkId(raw.north),
						south = Logic.LinkId(raw.south),
						east = Logic.LinkId(raw.east),
						west = Logic.LinkId(raw.west),
					}
					local dedupe = Logic.Pool(kind) .. ":" .. slot
					local existing = indexByPoolSlot[dedupe]
					if existing then
						out[existing] = record
					else
						table.insert(out, record)
						indexByPoolSlot[dedupe] = #out
					end
				end
			end
		end
	end
	return Logic.SettleLinks(out)
end
