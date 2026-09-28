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

Logic.MICRO_CLICK = {
	character = "CharacterMicroButton",
	professions = "ProfessionMicroButton",
	quest = "QuestLogMicroButton",
	guild = "GuildMicroButton",
	collections = "CollectionsMicroButton",
	achievements = "AchievementMicroButton",
	journal = "EJMicroButton",
	housing = "HousingMicroButton",
	finder = "LFDMicroButton",
	backpack = "MainMenuBarBackpackButton",
}

-- These panels have no safe micro click. MainMenuMicroButton bails out
-- unless the cursor is over it, and PlayerSpellsMicroButton cannot choose
-- the spellbook tab without a tainted field write.
Logic.PANEL_PROXY = {
	gamemenu = "LooseButtonsGameMenuProxy",
	spellbook = "LooseButtonsSpellbookProxy",
	talents = "LooseButtonsTalentsProxy",
}

Logic.PanelToggleSnippet = [=[
if button ~= "LeftButton" or down then
  return
end
local panel = self:GetFrameRef("panel")
if not panel then
  return
end
local page = self:GetFrameRef("page")
local open = panel:IsShown()
local switch = open and page and not page:IsShown()
if open and not switch then
  panel:Hide()
  self:ClearBindings()
  return
end
if not open and PlayerInCombat() then
  return
end
if not open then
  panel:Show()
end
if page then
  local book = self:GetFrameRef("book")
  local talents = self:GetFrameRef("talents")
  local spec = self:GetFrameRef("spec")
  if book and book ~= page then
    book:Hide()
  end
  if talents and talents ~= page then
    talents:Hide()
  end
  if spec and spec ~= page then
    spec:Hide()
  end
  page:Show()
end
if self:GetAttribute("escape") then
  self:SetBindingClick(true, "ESCAPE", self, "LeftButton")
end
]=]

Logic.PanelHidePre = "return true, true"
Logic.PanelHideSnippet = "control:ClearBindings()"

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

Logic.SNAP_REACH = 0.75
Logic.SNAP_EPS = 1
Logic.SCALE_MIN = 0.5
Logic.SCALE_MAX = 2
Logic.SCALE_STEP = 0.1
Logic.DEFAULT_SCALE = 1
Logic.SCALE_MIN_PERCENT = 50
Logic.SCALE_MAX_PERCENT = 200
Logic.SCALE_STEPS = 15

Logic.SIDES = { "north", "south", "east", "west" }

Logic.OPPOSITE = {
	north = "south",
	south = "north",
	east = "west",
	west = "east",
}

Logic.SIDE_STEP = {
	north = { 0, 1 },
	south = { 0, -1 },
	east = { 1, 0 },
	west = { -1, 0 },
}

function Logic.LinkId(value)
	if type(value) ~= "string" then
		return nil
	end
	if not string.match(value, "^[a-z]+:%d+$") then
		return nil
	end
	return value
end

local function indexById(list)
	local byId = {}
	local i
	for i = 1, #list do
		local record = list[i]
		if type(record) == "table" and type(record.id) == "string" then
			byId[record.id] = record
		end
	end
	return byId
end

function Logic.SettleLinks(list)
	local byId = indexById(list)
	local i
	for i = 1, #list do
		local record = list[i]
		local s
		for s = 1, #Logic.SIDES do
			local side = Logic.SIDES[s]
			local other = byId[record[side]]
			local back = other and other[Logic.OPPOSITE[side]]
			if back ~= record.id then
				record[side] = nil
			end
		end
	end
	return list
end

function Logic.RecordById(list, id)
	local i
	for i = 1, #list do
		if list[i].id == id then
			return list[i], i
		end
	end
	return nil
end

function Logic.ClearSide(list, record, side)
	if not record or not Logic.OPPOSITE[side] then
		return
	end
	local otherId = record[side]
	record[side] = nil
	local other = otherId and Logic.RecordById(list, otherId)
	if other and other[Logic.OPPOSITE[side]] == record.id then
		other[Logic.OPPOSITE[side]] = nil
	end
end

function Logic.Detach(list, id)
	local record = Logic.RecordById(list, id)
	if not record then
		return
	end
	local s
	for s = 1, #Logic.SIDES do
		Logic.ClearSide(list, record, Logic.SIDES[s])
	end
end

function Logic.Attach(list, moverId, targetId, targetSide)
	local mover = Logic.RecordById(list, moverId)
	local target = Logic.RecordById(list, targetId)
	local moverSide = Logic.OPPOSITE[targetSide]
	if not mover or not target or moverId == targetId or not moverSide then
		return false
	end
	Logic.ClearSide(list, target, targetSide)
	Logic.ClearSide(list, mover, moverSide)
	target[targetSide] = moverId
	mover[moverSide] = targetId
	return true
end

function Logic.Component(list, id)
	local byId = indexById(list)
	local out = {}
	if not byId[id] then
		return out
	end
	local seen = {}
	local queue = { id }
	seen[id] = true
	local head = 1
	while queue[head] do
		local current = queue[head]
		head = head + 1
		table.insert(out, current)
		local record = byId[current]
		local s
		for s = 1, #Logic.SIDES do
			local nextId = record[Logic.SIDES[s]]
			if nextId and not seen[nextId] and byId[nextId] then
				seen[nextId] = true
				table.insert(queue, nextId)
			end
		end
	end
	return out
end

function Logic.BoxAt(id, x, y, w, h)
	return {
		id = id,
		x = x,
		y = y,
		w = w,
		h = h,
		left = x - w / 2,
		right = x + w / 2,
		bottom = y - h / 2,
		top = y + h / 2,
	}
end

local function beside(target, side, w, h)
	local step = Logic.SIDE_STEP[side]
	return target.x + step[1] * (target.w + w) / 2, target.y + step[2] * (target.h + h) / 2
end

local function flushOn(target, side, box)
	local x, y = beside(target, side, box.w, box.h)
	return math.abs(box.x - x) <= Logic.SNAP_EPS and math.abs(box.y - y) <= Logic.SNAP_EPS
end

local function overlapping(a, b)
	return math.min(a.right, b.right) - math.max(a.left, b.left) > Logic.SNAP_EPS
		and math.min(a.top, b.top) - math.max(a.bottom, b.bottom) > Logic.SNAP_EPS
end

local function moved(box, dx, dy)
	return Logic.BoxAt(box.id, box.x + dx, box.y + dy, box.w, box.h)
end

-- Holes are read looking east or south. `along` grows toward that side,
-- `across` is the other axis, and `span` returns a box's length then width.
local function along(side, x, y)
	local step = Logic.SIDE_STEP[side]
	return step[1] * x + step[2] * y
end

local function across(side, x, y)
	if Logic.SIDE_STEP[side][1] ~= 0 then
		return y
	end
	return x
end

local function span(side, box)
	if Logic.SIDE_STEP[side][1] ~= 0 then
		return box.w, box.h
	end
	return box.h, box.w
end

-- Ties resolve by where the mover lands, never by save order.
local function earlier(a, b)
	if a.score ~= b.score then
		return a.score < b.score
	end
	if a.x ~= b.x then
		return a.x < b.x
	end
	if a.y ~= b.y then
		return a.y > b.y
	end
	if a.rank ~= b.rank then
		return a.rank < b.rank
	end
	if a.partner.x ~= b.partner.x then
		return a.partner.x < b.partner.x
	end
	if a.partner.y ~= b.partner.y then
		return a.partner.y > b.partner.y
	end
	return a.partner.id < b.partner.id
end

local HOLE_SIDES = { "east", "south" }

-- movers[1] leads, and each mover's record still holds where the drag began.
-- Returns where the leader lands, every edge it links, and the neighbors a
-- filled or opened hole pushes, or nil when nothing is in reach.
function Logic.SnapPlan(list, movers, x, y, scale)
	local leader = type(movers) == "table" and movers[1]
	if type(list) ~= "table" or type(leader) ~= "table" or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	local moving = {}
	local raw = {}
	local i
	for i = 1, #movers do
		local mover = movers[i]
		local mx, my = x, y
		if i > 1 then
			mx = x + mover.x - leader.x
			my = y + mover.y - leader.y
		end
		local w, h = Logic.ButtonExtent(mover, Logic.ExtentScale(mover, scale))
		moving[mover.id] = true
		raw[i] = Logic.BoxAt(mover.id, mx, my, w, h)
	end
	local byId = {}
	local still = {}
	for i = 1, #list do
		local record = list[i]
		if type(record) == "table" and record.id and not moving[record.id] and type(record.x) == "number" and type(record.y) == "number" then
			local w, h = Logic.ButtonExtent(record, Logic.ExtentScale(record, scale))
			byId[record.id] = record
			table.insert(still, Logic.BoxAt(record.id, record.x, record.y, w, h))
		end
	end

	local function settle(dx, dy, shift)
		local pushed = {}
		local k, j
		if shift then
			for k = 1, #shift.ids do
				pushed[shift.ids[k]] = true
			end
		end
		local finals = {}
		for k = 1, #still do
			finals[k] = pushed[still[k].id] and moved(still[k], shift.dx, shift.dy) or still[k]
		end
		local boxes = {}
		for k = 1, #raw do
			boxes[k] = moved(raw[k], dx, dy)
			for j = 1, #finals do
				if overlapping(boxes[k], finals[j]) then
					return nil
				end
			end
		end
		for k = 1, #finals do
			if pushed[finals[k].id] then
				for j = 1, #finals do
					if not pushed[finals[j].id] and overlapping(finals[k], finals[j]) then
						return nil
					end
				end
			end
		end
		local links = {}
		for k = 1, #boxes do
			for j = 1, #finals do
				local s
				for s = 1, #Logic.SIDES do
					if flushOn(finals[j], Logic.SIDES[s], boxes[k]) then
						table.insert(links, { id = finals[j].id, side = Logic.SIDES[s], other = boxes[k].id, box = finals[j] })
					end
				end
			end
		end
		return { x = boxes[1].x, y = boxes[1].y, links = links, shift = shift }
	end

	local best
	local function consider(plan, score, rank, partner)
		if not plan or #plan.links == 0 then
			return
		end
		plan.score = score
		plan.rank = rank
		plan.partner = partner
		if not best or earlier(plan, best) then
			best = plan
		end
	end

	-- Everything linked to `far` once its link to `near` is cut, or nil when
	-- that group still reaches `near` another way and cannot slide alone.
	local function sideOf(far, near)
		local ids = { far }
		local reached = { [far] = true }
		local head = 1
		while ids[head] do
			local id = ids[head]
			head = head + 1
			local s
			for s = 1, #Logic.SIDES do
				local nextId = byId[id][Logic.SIDES[s]]
				if nextId == near and id ~= far then
					return nil
				end
				if nextId and nextId ~= near and byId[nextId] and not reached[nextId] then
					reached[nextId] = true
					table.insert(ids, nextId)
				end
			end
		end
		return ids
	end

	local function fill(near, far, side)
		local mover = raw[1]
		local cx, cy = beside(near, side, mover.w, mover.h)
		local fx, fy = beside(Logic.BoxAt(mover.id, cx, cy, mover.w, mover.h), side, far.w, far.h)
		local shift
		if math.abs(fx - far.x) > Logic.SNAP_EPS or math.abs(fy - far.y) > Logic.SNAP_EPS then
			local ids = sideOf(far.id, near.id)
			if not ids then
				return nil
			end
			shift = { dx = fx - far.x, dy = fy - far.y, ids = ids }
		end
		return settle(cx - mover.x, cy - mover.y, shift)
	end

	local claimed = {}
	if #raw == 1 then
		local mover = raw[1]
		local reach = Logic.SNAP_REACH * math.max(mover.w, mover.h)
		local t, h, u
		for t = 1, #still do
			local near = still[t]
			for h = 1, #HOLE_SIDES do
				local side = HOLE_SIDES[h]
				local length, width = span(side, mover)
				local nearEdge = along(side, near.x, near.y) + span(side, near) / 2
				for u = 1, #still do
					local far = still[u]
					local gap = along(side, far.x, far.y) - span(side, far) / 2 - nearEdge
					local off = math.abs(across(side, far.x, far.y) - across(side, near.x, near.y))
					if far ~= near and gap >= -Logic.SNAP_EPS and gap <= length + reach / 2 and off <= width / 2 then
						local lo = nearEdge + length / 2
						local hi = nearEdge + gap - length / 2
						if lo > hi then
							lo = nearEdge + gap / 2
							hi = lo
						end
						local a = along(side, mover.x, mover.y)
						local da = math.max(lo - a, a - hi, 0)
						local dc = across(side, mover.x, mover.y) - (across(side, near.x, near.y) + across(side, far.x, far.y)) / 2
						local score = math.sqrt(da * da + dc * dc)
						local plan = score <= reach and (fill(near, far, side) or fill(far, near, Logic.OPPOSITE[side]))
						if plan then
							claimed[near.id .. side] = true
							claimed[far.id .. Logic.OPPOSITE[side]] = true
							consider(plan, score, 0, far)
						end
					end
				end
			end
		end
	end

	local k, t, s
	for k = 1, #raw do
		local mover = raw[k]
		local reach = Logic.SNAP_REACH * math.max(mover.w, mover.h)
		for t = 1, #still do
			local target = still[t]
			for s = 1, #Logic.SIDES do
				local side = Logic.SIDES[s]
				if not claimed[target.id .. side] then
					local cx, cy = beside(target, side, mover.w, mover.h)
					local dx, dy = cx - mover.x, cy - mover.y
					local score = math.sqrt(dx * dx + dy * dy)
					if score <= reach then
						consider(settle(dx, dy, nil), score, s, target)
					end
				end
			end
		end
	end
	return best
end

function Logic.Drop(list, leaderId, memberIds, x, y, scale)
	local leader = Logic.RecordById(list, leaderId)
	if not leader or type(leader.x) ~= "number" or type(leader.y) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	local movers = { leader }
	local i
	for i = 1, #(memberIds or {}) do
		local member = Logic.RecordById(list, memberIds[i])
		if member and member ~= leader and type(member.x) == "number" and type(member.y) == "number" then
			table.insert(movers, member)
		end
	end
	local plan = Logic.SnapPlan(list, movers, x, y, scale)
	local dx = (plan and plan.x or x) - leader.x
	local dy = (plan and plan.y or y) - leader.y
	for i = 1, #movers do
		local mover = movers[i]
		mover.x = mover.x + dx
		mover.y = mover.y + dy
		mover.point = "CENTER"
		mover.relPoint = "CENTER"
	end
	if not plan then
		return nil
	end
	if plan.shift then
		for i = 1, #plan.shift.ids do
			local record = Logic.RecordById(list, plan.shift.ids[i])
			record.x = record.x + plan.shift.dx
			record.y = record.y + plan.shift.dy
			record.point = "CENTER"
			record.relPoint = "CENTER"
		end
	end
	for i = 1, #plan.links do
		local link = plan.links[i]
		Logic.Attach(list, link.other, link.id, link.side)
	end
	return plan
end

function Logic.DragMode(shiftDown, altDown)
	if altDown then
		return "one"
	end
	if shiftDown then
		return "group"
	end
	return "one"
end

function Logic.ModifierPrefix(shiftDown, ctrlDown, altDown)
	local prefix = ""
	if shiftDown then
		prefix = "shift-" .. prefix
	end
	if ctrlDown then
		prefix = "ctrl-" .. prefix
	end
	if altDown then
		prefix = "alt-" .. prefix
	end
	return prefix
end

function Logic.ButtonSuffix(button)
	if button == "RightButton" then
		return "2"
	end
	if button == "MiddleButton" then
		return "3"
	end
	return "1"
end

function Logic.CastHoldPrefixes()
	return {
		"shift-",
		"alt-",
		"alt-shift-",
		"ctrl-shift-",
		"alt-ctrl-",
		"alt-ctrl-shift-",
	}
end

function Logic.ResolveAttribute(attrs, name, shiftDown, ctrlDown, altDown, button)
	if type(attrs) ~= "table" or type(name) ~= "string" then
		return nil
	end
	local prefix = Logic.ModifierPrefix(shiftDown, ctrlDown, altDown)
	local suffix = Logic.ButtonSuffix(button)
	local keys = {
		prefix .. name .. suffix,
		"*" .. name .. suffix,
		prefix .. name .. "*",
		"*" .. name .. "*",
		name,
	}
	local seen = {}
	local i
	for i = 1, #keys do
		local key = keys[i]
		if not seen[key] then
			seen[key] = true
			local value = attrs[key]
			if value ~= nil then
				if value == "" then
					return nil
				end
				return value
			end
		end
	end
	return nil
end

function Logic.NormalizeScale(value)
	if type(value) ~= "number" then
		return Logic.DEFAULT_SCALE
	end
	local steps = math.floor((value - Logic.SCALE_MIN) / Logic.SCALE_STEP + 0.5)
	local snapped = Logic.SCALE_MIN + steps * Logic.SCALE_STEP
	if snapped < Logic.SCALE_MIN then
		snapped = Logic.SCALE_MIN
	end
	if snapped > Logic.SCALE_MAX then
		snapped = Logic.SCALE_MAX
	end
	return math.floor(snapped * 100 + 0.5) / 100
end

function Logic.ScalePercent(scale)
	return math.floor(Logic.NormalizeScale(scale) * 100 + 0.5)
end

function Logic.ScaleFromSlider(first, second)
	if type(second) == "number" then
		return second
	end
	if type(first) == "number" then
		return first
	end
	if type(first) == "table" then
		local inner = first.Slider
		if type(inner) == "table" and type(inner.GetValue) == "function" then
			local value = inner:GetValue()
			if type(value) == "number" then
				return value
			end
		end
		if type(first.GetValue) == "function" then
			local value = first:GetValue()
			if type(value) == "number" then
				return value
			end
		end
	end
	return nil
end

function Logic.DeleteScope(shiftDown, altDown)
	if shiftDown then
		return "group"
	end
	if altDown then
		return "one"
	end
	return nil
end

function Logic.ExtentScale(record, scale)
	if type(scale) == "function" then
		return scale(record)
	end
	return scale
end

function Logic.LockArt(locked)
	if locked then
		return "Interface\\Buttons\\LockButton-Locked-Up"
	end
	return "Interface\\Buttons\\LockButton-Unlocked-Up"
end

function Logic.UsesSectionScale(record)
	if type(record) ~= "table" or record.kind ~= "launcher" then
		return false
	end
	local spec = Logic.LauncherByCommand(record.payload)
	return spec ~= nil and spec.section == Logic.SECTION_ORDER[1]
end

function Logic.RecordScale(record, globalScale, separate, launcherScale)
	if separate and Logic.UsesSectionScale(record) then
		return Logic.NormalizeScale(launcherScale)
	end
	return Logic.NormalizeScale(globalScale)
end

function Logic.RecordTheme(record, globalTheme, separate, launcherTheme)
	if separate and Logic.UsesSectionScale(record) then
		return Logic.NormalizeTheme(launcherTheme)
	end
	return Logic.NormalizeTheme(globalTheme)
end

function Logic.ButtonExtent(record, scale)
	local w, h = 45, 45
	if type(record) == "table" and record.kind == "launcher" and record.chrome == "micro" then
		w, h = 32, 40
	end
	scale = Logic.NormalizeScale(scale)
	return w * scale, h * scale
end

function Logic.Reflow(list, sizeOf)
	local byId = indexById(list)
	local seen = {}
	local i
	for i = 1, #list do
		local root = list[i]
		if root and root.id and not seen[root.id] then
			local queue = { root.id }
			seen[root.id] = true
			local head = 1
			while queue[head] do
				local id = queue[head]
				head = head + 1
				local record = byId[id]
				local rw, rh = sizeOf(record)
				local s
				for s = 1, #Logic.SIDES do
					local side = Logic.SIDES[s]
					local nextId = record[side]
					local other = nextId and byId[nextId]
					if other and not seen[nextId] then
						seen[nextId] = true
						local ow, oh = sizeOf(other)
						if side == "east" then
							other.x = record.x + rw / 2 + ow / 2
							other.y = record.y
						elseif side == "west" then
							other.x = record.x - rw / 2 - ow / 2
							other.y = record.y
						elseif side == "north" then
							other.x = record.x
							other.y = record.y + rh / 2 + oh / 2
						elseif side == "south" then
							other.x = record.x
							other.y = record.y - rh / 2 - oh / 2
						end
						table.insert(queue, nextId)
					end
				end
			end
		end
	end
end

function Logic.DropIntent(source, overActionSlot, kind)
	if source ~= "catalog" and source ~= "loose" then
		return "ignore"
	end
	if overActionSlot then
		if kind == "launcher" then
			return "cancel"
		end
		return "action"
	end
	return "float"
end

function Logic.NextSlot(list, kind)
	local pool = Logic.Pool(kind)
	local used = {}
	local i
	for i = 1, #list do
		local record = list[i]
		if type(record) == "table" and Logic.Pool(record.kind) == pool then
			used[record.slot] = true
		end
	end
	local limit = Logic.SlotLimit(kind)
	local slot
	for slot = 1, limit do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

function Logic.FaceFields(raw, payload)
	local spec = Logic.LauncherByCommand(payload)
	if spec then
		if spec.portrait then
			return spec.chrome or "micro", nil, true
		end
		local atlas = spec.atlas
		if type(atlas) ~= "string" or atlas == "" then
			atlas = nil
		end
		return spec.chrome or "micro", atlas, nil
	end
	local chrome = raw.chrome
	if chrome ~= "micro" and chrome ~= "bag" then
		chrome = "micro"
	end
	if raw.portrait then
		return chrome, nil, true
	end
	local atlas = raw.atlas
	if type(atlas) ~= "string" or atlas == "" then
		atlas = nil
	end
	return chrome, atlas, nil
end

function Logic.LauncherPaint(record)
	local chrome, atlas, portrait = Logic.FaceFields(record, record.payload)
	local normal, pushed, highlight
	if chrome == "micro" and atlas then
		local prefix = "UI-HUD-MicroMenu-" .. atlas
		normal = prefix .. "-Up"
		pushed = prefix .. "-Down"
		highlight = prefix .. "-Mouseover"
	end
	local plate = nil
	if chrome == "micro" then
		plate = "UI-HUD-MicroMenu-ButtonBG-Up"
	end
	return {
		chrome = chrome,
		atlas = atlas,
		portrait = portrait and true or false,
		plate = plate,
		normal = normal,
		pushed = pushed,
		highlight = highlight,
	}
end

function Logic.LauncherByCommand(command)
	local i
	for i = 1, #Logic.LAUNCHERS do
		if Logic.LAUNCHERS[i].command == command then
			return Logic.LAUNCHERS[i]
		end
	end
	for i = 1, #Logic.EXTRA_LAUNCHERS do
		if Logic.EXTRA_LAUNCHERS[i].command == command then
			return Logic.EXTRA_LAUNCHERS[i]
		end
	end
	return nil
end

local gameMenu = Logic.LauncherByCommand("TOGGLEGAMEMENU")

Logic.PAGE_COMMANDS = {
	{ id = "clear", title = "Clear all", text = "Remove every loose button.", icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
	{ id = "edit", title = "Edit", text = "Bind keys to loose buttons.", icon = "Interface\\Icons\\INV_Misc_Key_06" },
	{ id = "lock", title = "Lock", text = "Stop moving and snapping loose buttons.", icon = Logic.LockArt(false) },
	{
		id = "help",
		title = "Help",
		text = "How to place, move, and remove buttons.",
		atlas = gameMenu and gameMenu.atlas or nil,
	},
}

Logic.HELP = {
	{ gesture = "Drag from the catalog", detail = "Place it on open ground. Release over the spellbook to cancel." },
	{ gesture = "Drop on an action button", detail = "Put that spell or item on the action slot." },
	{ gesture = "Left-drag", detail = "Move one button. It snaps. A gap or a seam makes room." },
	{ gesture = "Shift-drag", detail = "Move a snapped group together." },
	{ gesture = "Alt-drag", detail = "Pull one button free, even if Shift is held." },
	{ gesture = "Left-click", detail = "Use the spell, item, or launcher." },
	{ gesture = "Right-click", detail = "Leaves the button where it is." },
	{ gesture = "Shift-right-click", detail = "Remove the snapped group, even if Alt is held." },
	{ gesture = "Alt-right-click", detail = "Remove one button." },
	{ gesture = "Right-click a catalog drag", detail = "Cancel a spell or item still on the cursor." },
	{ gesture = "Clear", detail = "Asks, then removes every button. /loose reset skips the ask." },
	{ gesture = "Edit", detail = "Hover a button, then press a key, a mouse button past Right, the wheel, or a controller button the game already reports. Escape clears it. Edit or Escape ends. /loose does the same." },
	{ gesture = "Lock", detail = "Stops moves, snaps, and deletes until you click again." },
}

Logic.DEFAULT_THEME = "elevated_classic"

Logic.THEMES = {
	default = {
		id = "default",
		title = "Default",
		stock = true,
		inset = 3,
		rim = 0,
		wellA = 0,
		shadow = 0,
		shadowA = 0,
		hoverA = 0,
		press = "frame",
		crop = 0,
		cooldownInset = 3,
	},
	no_plate = {
		id = "no_plate",
		title = "No plate",
		inset = 0,
		rim = 0,
		wellA = 0,
		shadow = 0,
		shadowA = 0,
		hoverA = 0,
		press = "icon",
		crop = 0,
		cooldownInset = 3,
	},
	elevated_classic = {
		id = "elevated_classic",
		title = "Elevated",
		inset = 2,
		rim = 1,
		rimR = 0.62, rimG = 0.48, rimB = 0.22, rimA = 0.85,
		wellR = 0.42, wellG = 0.30, wellB = 0.14, wellA = 0.4,
		shadow = 2,
		shadowA = 0.35,
		hoverA = 0,
		press = "frame",
		crop = 0,
		cooldownInset = 3,
	},
	glass_lip = {
		id = "glass_lip",
		title = "Glass lip",
		inset = 0,
		rim = 2,
		rimR = 1, rimG = 0.94, rimB = 0.78, rimA = 0.28,
		wellA = 0,
		shadow = 2,
		shadowA = 0.35,
		hoverA = 0,
		press = "frame",
		crop = 0,
		cooldownInset = 3,
	},
	edge = {
		id = "edge",
		title = "Edge",
		inset = 2,
		rim = 1,
		rimR = 0.392, rimG = 0.435, rimB = 0.529, rimA = 1,
		wellR = 0.094, wellG = 0.106, wellB = 0.125, wellA = 1,
		shadow = 0,
		shadowA = 0,
		hoverR = 1, hoverG = 0.161, hoverB = 0.161, hoverA = 1,
		press = "fill",
		pressR = 0.839, pressG = 0, pressB = 0, pressA = 0.35,
		crop = 0.08,
		cooldownInset = 0,
	},
}

Logic.THEME_ORDER = { "default", "no_plate", "elevated_classic", "glass_lip", "edge" }

function Logic.NormalizeTheme(theme)
	if type(theme) == "string" and Logic.THEMES[theme] then
		return theme
	end
	return Logic.DEFAULT_THEME
end

function Logic.ThemeSpec(theme)
	return Logic.THEMES[Logic.NormalizeTheme(theme)]
end

function Logic.StockTheme(theme)
	local spec = Logic.ThemeSpec(theme)
	return spec and spec.stock and true or false
end

function Logic.PressFeedback(theme)
	return Logic.ThemeSpec(theme).press
end

function Logic.SectionRow(scaleLabelW, themeLabelW)
	if type(scaleLabelW) ~= "number" or scaleLabelW < 0 then
		scaleLabelW = 0
	end
	if type(themeLabelW) ~= "number" or themeLabelW < 0 then
		themeLabelW = 0
	end
	local stack = Logic.SECTION_STACK
	local scaleColumnW = stack.check + stack.labelGap + scaleLabelW + stack.controlGap + stack.sliderW
	local themeColumnW = stack.check + stack.labelGap + themeLabelW + stack.controlGap + stack.dropW
	local themeColumnX = scaleColumnW + stack.controlGap
	return {
		height = stack.band + stack.titleLine + stack.sliderH + stack.band + stack.divider,
		scaleColumnW = scaleColumnW,
		themeColumnX = themeColumnX,
		themeColumnW = themeColumnW,
		anchors = {
			scaleCheck = { point = "TOPLEFT", rel = "title", relPoint = "BOTTOMLEFT", x = 0, y = -stack.sliderCap },
			scaleLabel = { point = "LEFT", rel = "scaleCheck", relPoint = "RIGHT", x = stack.labelGap, y = 0 },
			slider = { point = "LEFT", rel = "scaleLabel", relPoint = "RIGHT", x = stack.controlGap, y = stack.sliderNudge },
			themeCheck = { point = "TOPLEFT", rel = "title", relPoint = "BOTTOMLEFT", x = themeColumnX, y = -stack.sliderCap },
			themeLabel = { point = "LEFT", rel = "themeCheck", relPoint = "RIGHT", x = stack.labelGap, y = 0 },
			dropdown = { point = "LEFT", rel = "themeLabel", relPoint = "RIGHT", x = stack.controlGap, y = 0 },
		},
	}
end

function Logic.CatalogHeaderHeight(title)
	if title ~= Logic.SECTION_ORDER[1] then
		return Logic.SECTION_STACK.plain
	end
	return Logic.SectionRow().height
end

function Logic.SectionHeaderInset()
	return -Logic.SECTION_STACK.band
end

function Logic.ItemCountLook(count)
	if type(count) ~= "number" then
		return nil
	end
	if count < 0 then
		count = 0
	end
	count = math.floor(count)
	if count == 0 then
		return {
			text = "0",
			r = 1,
			g = 0.1,
			b = 0.1,
			desaturate = true,
			vertexR = 0.4,
			vertexG = 0.4,
			vertexB = 0.4,
		}
	end
	local text = tostring(count)
	if count > 9999 then
		text = "*"
	end
	return {
		text = text,
		r = 1,
		g = 1,
		b = 1,
		desaturate = false,
		vertexR = 1,
		vertexG = 1,
		vertexB = 1,
	}
end

function Logic.StockIdleShown(role)
	return role == "normal"
end

Logic.STOCK_PUSHED_ATLAS = "UI-HUD-ActionBar-IconFrame-Down"
Logic.STOCK_HIGHLIGHT_ATLAS = "UI-HUD-ActionBar-IconFrame-Mouseover"
Logic.ICON_GLOW_INSET = 4
Logic.ICON_GLOW_ALPHA = 0.35
Logic.ICON_PRESS_ALPHA = 0.25

function Logic.StockIconLayout(width, height)
	if type(width) ~= "number" or width <= 0 then
		width = 45
	end
	if type(height) ~= "number" or height <= 0 then
		height = width
	end
	return width, height, width * 46 / 45, height, width * 64 / 45, height * 64 / 45
end

function Logic.NormalizeLocked(locked)
	return locked == true
end

function Logic.ClickRegistration(kind)
	if kind == "launcher" then
		return "AnyUp"
	end
	return "AnyUp", "AnyDown"
end

function Logic.VisibleLaunchers(bindingExists)
	local out = {}
	local i
	for i = 1, #Logic.LAUNCHERS do
		table.insert(out, Logic.LAUNCHERS[i])
	end
	for i = 1, #Logic.EXTRA_LAUNCHERS do
		local row = Logic.EXTRA_LAUNCHERS[i]
		if bindingExists and bindingExists(row.command) then
			table.insert(out, row)
		end
	end
	return out
end

local function copyEntry(row)
	return {
		kind = row.kind,
		payload = row.payload,
		name = row.name,
		icon = row.icon,
		chrome = row.chrome,
		atlas = row.atlas,
		portrait = row.portrait,
		click = row.click,
	}
end

local function spellIdentity(spell)
	if type(spell) ~= "table" then
		return nil
	end
	if spell.baseSpellID and wholeNumber(spell.baseSpellID, 1) then
		return spell.baseSpellID
	end
	if wholeNumber(spell.spellID, 1) then
		return spell.spellID
	end
	return nil
end

function Logic.ConsumableEntries(candidates)
	local out = {}
	local seen = {}
	if type(candidates) ~= "table" then
		return out
	end
	local i
	for i = 1, #candidates do
		local row = candidates[i]
		local id = type(row) == "table" and row.itemID or nil
		local usable = type(id) == "number" and id >= 1 and id == math.floor(id) and not seen[id]
		if usable and row.classID == Logic.ITEM_CLASS_CONSUMABLE and row.spellID ~= nil then
			seen[id] = true
			local name = row.name
			if type(name) ~= "string" or name == "" then
				name = "Item " .. id
			end
			table.insert(out, {
				kind = "item",
				payload = id,
				name = name,
				icon = Logic.UsableTexture(row.icon),
				chrome = "action",
			})
		end
	end
	return out
end

local function macroEntries(macroInfo, first, count)
	local entries = {}
	if type(issecretvalue) == "function" and issecretvalue(count) or type(count) ~= "number" then
		return entries
	end
	local index
	for index = first, first + count - 1 do
		local name, icon = macroInfo(index)
		local secret = type(issecretvalue) == "function" and issecretvalue(name)
		if not secret and type(name) == "string" and name ~= "" then
			table.insert(entries, {
				kind = "macro",
				payload = name,
				name = name,
				icon = Logic.UsableTexture(icon),
				chrome = "action",
			})
		end
	end
	return entries
end

-- Character macro indices start past every account slot, used or not.
function Logic.Macros(api)
	if type(api.GetNumMacros) ~= "function" or type(api.GetMacroInfo) ~= "function" then
		return nil
	end
	local general, character = api.GetNumMacros()
	local consts = type(api.Constants) == "table" and api.Constants.MacroConsts
	local characterBase = type(consts) == "table" and consts.MAX_ACCOUNT_MACROS or api.MAX_ACCOUNT_MACROS or 120
	return {
		general = macroEntries(api.GetMacroInfo, 1, general),
		character = macroEntries(api.GetMacroInfo, characterBase + 1, character),
	}
end

function Logic.BuildSections(skillLines, spellAt, launchers, items, macros)
	local sections = {}
	if type(skillLines) == "table" and type(spellAt) == "function" then
		local seenID = {}
		local seenName = {}
		local lineIndex
		for lineIndex = 1, #skillLines do
			local line = skillLines[lineIndex]
			local hidden = type(line) ~= "table" or line.shouldHide or line.offSpecID
			if not hidden then
				local offset = line.itemIndexOffset or 0
				local count = line.numSpellBookItems or 0
				local entries = {}
				local nameAt = {}
				local slot
				for slot = offset + 1, offset + count do
					local spell = spellAt(slot)
					local id = spellIdentity(spell)
					if id and spell.isSpell and not spell.isPassive and not spell.isOffSpec then
						local name = spell.name
						if type(name) ~= "string" or name == "" then
							name = "Spell " .. id
						end
						if seenID[id] then
							id = nil
						elseif seenName[name] then
							local at = nameAt[name]
							if at then
								entries[at].payload = id
								entries[at].icon = Logic.UsableTexture(spell.iconID) or entries[at].icon
								seenID[id] = true
							end
							id = nil
						end
						if id then
							table.insert(entries, {
								kind = "spell",
								payload = id,
								name = name,
								icon = Logic.UsableTexture(spell.iconID),
								chrome = "action",
							})
							seenID[id] = true
							seenName[name] = true
							nameAt[name] = #entries
						end
					end
				end
				if #entries > 0 then
					table.insert(sections, { title = line.name or "Spells", entries = entries })
				end
			end
		end
	end

	local launcherRows = launchers or {}
	local itemEntries = {}
	local i
	for i = 1, #launcherRows do
		local row = launcherRows[i]
		if row.section == "Items" then
			table.insert(itemEntries, copyEntry({
				kind = "launcher",
				payload = row.command,
				name = row.name,
				chrome = row.chrome,
				atlas = row.atlas,
				portrait = row.portrait,
				click = row.click,
			}))
		end
	end
	if type(items) == "table" then
		for i = 1, #items do
			table.insert(itemEntries, items[i])
		end
	end
	if #itemEntries > 0 then
		table.insert(sections, { title = "Items", entries = itemEntries })
	end
	if type(macros) == "table" then
		for i = 1, #Logic.MACRO_SECTIONS do
			local spec = Logic.MACRO_SECTIONS[i]
			local entries = macros[spec.scope]
			if type(entries) == "table" and #entries > 0 then
				table.insert(sections, { title = spec.title, entries = entries })
			end
		end
	end
	local sectionIndex
	for sectionIndex = 1, #Logic.SECTION_ORDER do
		local title = Logic.SECTION_ORDER[sectionIndex]
		local entries = {}
		local i
		for i = 1, #launcherRows do
			local row = launcherRows[i]
			if row.section == title then
				table.insert(entries, copyEntry({
					kind = "launcher",
					payload = row.command,
					name = row.name,
					chrome = row.chrome,
					atlas = row.atlas,
					portrait = row.portrait,
					click = row.click,
				}))
			end
		end
		if #entries > 0 then
			table.insert(sections, { title = title, entries = entries })
		end
	end
	return sections
end

function Logic.RankRow(spell)
	if type(spell) ~= "table" then
		return nil
	end
	local actionID = spell.spellID
	local overrideID = spell.baseSpellID
	local row = {
		name = spell.name,
		subName = spell.subName,
		rank = spell.rank,
		iconID = spell.iconID,
		isSpell = spell.isSpell,
		isPassive = spell.isPassive,
		isOffSpec = spell.isOffSpec,
	}
	if wholeNumber(actionID, 1) and wholeNumber(overrideID, 1) and overrideID ~= actionID then
		row.spellID = overrideID
		row.baseSpellID = actionID
		return row
	end
	row.spellID = actionID
	return row
end

function Logic.SpellRank(value)
	if type(issecretvalue) == "function" and issecretvalue(value) then
		return nil
	end
	if wholeNumber(value, 1) then
		return value
	end
	if type(value) == "table" then
		if wholeNumber(value.rank, 1) then
			return value.rank
		end
		value = value.subName
		if type(issecretvalue) == "function" and issecretvalue(value) then
			return nil
		end
	end
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = string.match(value, "^%s*(.-)%s*$")
	local digits = trimmed and string.match(trimmed, "^%D*(%d+)$")
	local n = digits and tonumber(digits)
	if wholeNumber(n, 1) then
		return n
	end
	return nil
end

function Logic.UpgradeSpellRanks(records, skillLines, spellAt, baseOf, nameOf, rankOf)
	if type(records) ~= "table" or type(skillLines) ~= "table" or type(spellAt) ~= "function" then
		return false
	end
	local groups = {}
	local owners = {}
	local lineIndex
	for lineIndex = 1, #skillLines do
		local line = skillLines[lineIndex]
		if type(line) == "table" and not line.shouldHide and not line.offSpecID then
			local offset = line.itemIndexOffset or 0
			local count = line.numSpellBookItems or 0
			local slot
			for slot = offset + 1, offset + count do
				local spell = spellAt(slot)
				if type(spell) == "table" and spell.isSpell and not spell.isPassive and not spell.isOffSpec then
					local rawId = spell.spellID
					local rawBase = spell.baseSpellID
					local rawName = spell.name
					local rawIcon = spell.iconID
					local secret = type(issecretvalue) == "function" and (issecretvalue(rawId) or issecretvalue(rawBase) or issecretvalue(rawName) or issecretvalue(rawIcon))
					if not secret and wholeNumber(rawId, 1) and wholeNumber(rawBase, 1) and type(rawName) == "string" and rawName ~= "" then
						local group = groups[rawBase]
						if not group then
							group = { byName = {}, list = {} }
							groups[rawBase] = group
						end
						local family = group.byName[rawName]
						if not family then
							family = { members = {}, seen = {} }
							group.byName[rawName] = family
							group.list[#group.list + 1] = family
						end
						if not family.seen[rawId] then
							family.seen[rawId] = true
							family.members[#family.members + 1] = {
								id = rawId,
								icon = Logic.UsableTexture(rawIcon),
								rank = Logic.SpellRank(spell),
							}
							local owned = owners[rawId]
							if not owned then
								owned = {}
								owners[rawId] = owned
							end
							owned[#owned + 1] = family
						end
					end
				end
			end
		end
	end
	local function pickHigher(family, currentRank)
		if not wholeNumber(currentRank, 1) then
			return nil
		end
		local best
		local tie = false
		local memberIndex
		for memberIndex = 1, #family.members do
			local member = family.members[memberIndex]
			if member.rank then
				if not best or member.rank > best.rank then
					best = member
					tie = false
				elseif member.rank == best.rank and member.id ~= best.id then
					tie = true
				end
			end
		end
		if tie or not best or best.rank <= currentRank then
			return nil
		end
		return best
	end
	local changed = false
	local index
	for index = 1, #records do
		local record = records[index]
		if type(record) == "table" and record.kind == "spell" and wholeNumber(record.payload, 1) then
			local payload = record.payload
			local owned = owners[payload]
			local picked
			if owned and #owned == 1 then
				local members = owned[1].members
				local currentRank
				local memberIndex
				for memberIndex = 1, #members do
					if members[memberIndex].id == payload then
						currentRank = members[memberIndex].rank
						break
					end
				end
				picked = pickHigher(owned[1], currentRank)
			elseif not owned then
				local base = payload
				if not groups[base] and type(baseOf) == "function" then
					local found = baseOf(payload)
					local secret = type(issecretvalue) == "function" and issecretvalue(found)
					if not secret and wholeNumber(found, 1) then
						base = found
					else
						base = nil
					end
				end
				local group = base and groups[base]
				local name
				if group and type(nameOf) == "function" then
					name = nameOf(payload)
					local secret = type(issecretvalue) == "function" and issecretvalue(name)
					if secret or type(name) ~= "string" or name == "" then
						name = nil
					end
				end
				local family = group and name and group.byName[name]
				local currentRank
				if family and type(rankOf) == "function" then
					currentRank = Logic.SpellRank(rankOf(payload))
				end
				if family then
					picked = pickHigher(family, currentRank)
				end
			end
			if picked and picked.id ~= payload then
				record.payload = picked.id
				if picked.icon then
					record.icon = picked.icon
				else
					record.icon = nil
				end
				changed = true
			end
		end
	end
	return changed
end

local PROFILE_FIELDS = {
	"buttons",
	"theme",
	"scale",
	"locked",
	"launcherScaleSeparate",
	"launcherScale",
	"launcherThemeSeparate",
	"launcherTheme",
}

local function profileName(name)
	if type(name) ~= "string" then
		return nil, "Enter a name."
	end
	local trimmed = string.match(name, "^[ \t]*(.-)[ \t]*$")
	if not trimmed or trimmed == "" then
		return nil, "Enter a name."
	end
	if #trimmed > 32 then
		return nil, "That name is too long."
	end
	if string.find(trimmed, "|", 1, true) or string.find(trimmed, "%c") then
		return nil, "That name cannot be used."
	end
	return trimmed
end

function Logic.Profile(raw)
	if type(raw) ~= "table" then
		raw = {}
	end
	local scale = Logic.NormalizeScale(raw.scale)
	local theme = Logic.NormalizeTheme(raw.theme)
	local launcherScale = scale
	if raw.launcherScale ~= nil then
		launcherScale = Logic.NormalizeScale(raw.launcherScale)
	end
	local launcherTheme = theme
	if raw.launcherTheme ~= nil then
		launcherTheme = Logic.NormalizeTheme(raw.launcherTheme)
	end
	return {
		buttons = Logic.Normalize(raw.buttons),
		theme = theme,
		scale = scale,
		locked = Logic.NormalizeLocked(raw.locked),
		launcherScaleSeparate = raw.launcherScaleSeparate == true,
		launcherScale = launcherScale,
		launcherThemeSeparate = raw.launcherThemeSeparate == true,
		launcherTheme = launcherTheme,
	}
end

function Logic.ApplyProfile(db, source)
	if type(db) ~= "table" then
		return db
	end
	local profile = Logic.Profile(source)
	local i
	for i = 1, #PROFILE_FIELDS do
		local key = PROFILE_FIELDS[i]
		db[key] = profile[key]
	end
	return db
end

local function rootLayoutPresent(account)
	local i
	for i = 1, #PROFILE_FIELDS do
		if account[PROFILE_FIELDS[i]] ~= nil then
			return true
		end
	end
	return false
end

local function clearRootLayout(account)
	local i
	for i = 1, #PROFILE_FIELDS do
		account[PROFILE_FIELDS[i]] = nil
	end
end

local function freeLayoutName(account)
	local n = 1
	while account.profiles["Layout " .. n] ~= nil do
		n = n + 1
	end
	return "Layout " .. n
end

Logic.BLANK_LAYOUT = "Blank"

local function reservedName(name)
	return string.lower(name) == string.lower(Logic.BLANK_LAYOUT)
end

local function freeName(account, suggested)
	local base = profileName(suggested) or "Layout"
	local candidate = base
	local n = 1
	while account.profiles[candidate] ~= nil or reservedName(candidate) do
		n = n + 1
		local suffix = " " .. n
		candidate = string.sub(base, 1, 32 - #suffix) .. suffix
	end
	return candidate
end

function Logic.CharKey(name, realm)
	if type(issecretvalue) == "function" and (issecretvalue(name) or issecretvalue(realm)) then
		return nil
	end
	if type(name) ~= "string" or name == "" or type(realm) ~= "string" or realm == "" then
		return nil
	end
	return name .. "-" .. realm
end

-- A save from before per-character layouts has no `chars` map. The one
-- `active` layout (or the pre-layout root fields) goes to whoever logs in
-- first; every later character is missing from the map and starts Blank.
local function migrate(account, key)
	if type(account.profiles) ~= "table" then
		account.profiles = {}
	end
	if type(account.chars) ~= "table" then
		local claimed = account.active
		if type(claimed) ~= "string" or type(account.profiles[claimed]) ~= "table" then
			claimed = nil
			if rootLayoutPresent(account) then
				claimed = freeLayoutName(account)
				account.profiles[claimed] = Logic.Profile(account)
			end
		end
		account.chars = {}
		if claimed then
			account.chars[key] = { layout = claimed }
		end
	end
	account.active = nil
	clearRootLayout(account)
end

-- Each character row holds `layout` (a name in `profiles`) or `blank` (a
-- profile only this character sees), never both.
local function charRow(account, key)
	migrate(account, key)
	local row = account.chars[key]
	if type(row) ~= "table" then
		row = {}
		account.chars[key] = row
	end
	if type(row.layout) == "string" and type(account.profiles[row.layout]) == "table" then
		row.blank = nil
		return row
	end
	row.layout = nil
	if type(row.blank) ~= "table" then
		row.blank = Logic.Profile({})
	end
	return row
end

local function validKey(account, key)
	return type(account) == "table" and type(key) == "string" and key ~= ""
end

local function unbindAll(account, name)
	local _, row
	for _, row in pairs(account.chars) do
		if type(row) == "table" and row.layout == name then
			row.layout = nil
		end
	end
end

Logic.Layouts = {}

function Logic.Layouts.Live(account, key)
	if not validKey(account, key) then
		return nil
	end
	local row = charRow(account, key)
	if row.layout then
		return account.profiles[row.layout]
	end
	return row.blank
end

function Logic.Layouts.Normalize(account, key)
	local live = Logic.Layouts.Live(account, key)
	if not live then
		return nil
	end
	return Logic.ApplyProfile(live, live)
end

function Logic.Layouts.ActiveName(account, key)
	if not validKey(account, key) then
		return nil
	end
	return charRow(account, key).layout
end

function Logic.Layouts.Names(account)
	local names = {}
	if type(account) ~= "table" or type(account.profiles) ~= "table" then
		return names
	end
	local name, value
	for name, value in pairs(account.profiles) do
		if type(name) == "string" and type(value) == "table" then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

function Logic.Layouts.UsedBy(account, name)
	local keys = {}
	if type(account) ~= "table" or type(account.chars) ~= "table" then
		return keys
	end
	local key, row
	for key, row in pairs(account.chars) do
		if type(row) == "table" and row.layout == name then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function Logic.Layouts.DeleteText(account, key, name)
	if name == Logic.Layouts.ActiveName(account, key) then
		return "Delete this layout and clear it off the screen?"
	end
	local others = {}
	local users = Logic.Layouts.UsedBy(account, name)
	local i
	for i = 1, #users do
		if users[i] ~= key then
			table.insert(others, string.match(users[i], "^([^-]+)") or users[i])
		end
	end
	if #others == 0 then
		return "Delete this saved layout?"
	end
	if #others == 1 then
		return "Delete this saved layout? " .. others[1] .. " uses it and will go blank."
	end
	local rest = #others - 1
	local noun = rest == 1 and "character" or "characters"
	return "Delete this saved layout? " .. others[1] .. " and " .. rest .. " other " .. noun .. " use it and will go blank."
end

-- `name == nil` picks Blank for this character only.
function Logic.Layouts.Switch(account, key, name, lockdown)
	if not validKey(account, key) then
		return nil, "No saved profile with that name."
	end
	local clean
	if name ~= nil then
		clean = profileName(name)
		if not clean then
			return nil, "No saved profile with that name."
		end
	end
	local row = charRow(account, key)
	if clean == row.layout then
		return Logic.Layouts.Live(account, key), false
	end
	if lockdown then
		return nil, "Leave combat to load a layout."
	end
	if clean == nil then
		row.layout = nil
		row.blank = Logic.Profile({})
		return row.blank, true
	end
	local stored = account.profiles[clean]
	if type(stored) ~= "table" then
		return nil, "No saved profile with that name."
	end
	local nextProfile = Logic.Profile(stored)
	account.profiles[clean] = nextProfile
	row.layout = clean
	row.blank = nil
	return nextProfile, true
end

function Logic.Layouts.Claim(account, key, suggested)
	if not validKey(account, key) then
		return nil, false
	end
	local row = charRow(account, key)
	if row.layout then
		return row.layout, false
	end
	local name = freeName(account, suggested)
	account.profiles[name] = row.blank
	row.layout = name
	row.blank = nil
	return name, true
end

function Logic.Layouts.Create(account, key, name, source, lockdown)
	local clean, reason = profileName(name)
	if not clean then
		return nil, reason
	end
	if not validKey(account, key) then
		return nil, "That name cannot be used."
	end
	local row = charRow(account, key)
	if account.profiles[clean] ~= nil or reservedName(clean) then
		return nil, "That name is already used."
	end
	if source ~= nil then
		if lockdown then
			return nil, "Leave combat to load a layout."
		end
		local imported = Logic.Profile(source)
		account.profiles[clean] = imported
		row.layout = clean
		row.blank = nil
		return clean, imported
	end
	if not row.layout then
		local live = row.blank
		account.profiles[clean] = live
		row.layout = clean
		row.blank = nil
		return clean, live
	end
	local previous = row.layout
	local live = account.profiles[previous]
	account.profiles[clean] = live
	account.profiles[previous] = Logic.Profile(live)
	row.layout = clean
	return clean, live
end

function Logic.Layouts.Delete(account, key, name, lockdown)
	local clean = profileName(name)
	if not clean or not validKey(account, key) then
		return nil, "No saved profile with that name."
	end
	local row = charRow(account, key)
	if type(account.profiles[clean]) ~= "table" then
		return nil, "No saved profile with that name."
	end
	if clean ~= row.layout then
		account.profiles[clean] = nil
		unbindAll(account, clean)
		return "kept", row.layout
	end
	if lockdown then
		return nil, "Leave combat to load a layout."
	end
	account.profiles[clean] = nil
	unbindAll(account, clean)
	row.blank = Logic.Profile({})
	return "cleared", nil
end

local ownedCommand = {}
local ownedCommandList = {}

local function ownCommand(kind, slot)
	local command = Logic.ClickBinding(Logic.FrameName(kind, slot))
	ownedCommand[command] = true
	ownedCommandList[#ownedCommandList + 1] = command
end

do
	local slot
	for slot = 1, Logic.ACTION_SLOTS do
		ownCommand("spell", slot)
	end
	for slot = 1, Logic.LAUNCHER_SLOTS do
		ownCommand("launcher", slot)
	end
end

local function bindToken(token)
	if type(token) ~= "string" or token == "" or token == "CLEAR" then
		return nil
	end
	if string.find(token, "%c") or string.find(token, " ", 1, true) then
		return nil
	end
	return token
end

local function storedTokens(value)
	local list = {}
	local seen = {}
	local function add(token)
		token = bindToken(token)
		if token and not seen[token] then
			seen[token] = true
			list[#list + 1] = token
		end
	end
	if type(value) == "string" then
		add(value)
	elseif type(value) == "table" then
		local i
		for i = 1, #value do
			add(value[i])
		end
	end
	return list
end

Logic.Binds = {}

function Logic.Binds.Commands()
	return ownedCommandList
end

function Logic.Binds.All(account, key)
	local out = {}
	if not validKey(account, key) or type(account.chars) ~= "table" then
		return out
	end
	local row = account.chars[key]
	if type(row) ~= "table" or type(row.binds) ~= "table" then
		return out
	end
	local i
	for i = 1, #ownedCommandList do
		local command = ownedCommandList[i]
		local tokens = storedTokens(row.binds[command])
		if #tokens == 1 then
			out[command] = tokens[1]
		elseif #tokens > 1 then
			out[command] = tokens
		end
	end
	return out
end

function Logic.Binds.Read(account, key)
	local out = {}
	local all = Logic.Binds.All(account, key)
	local i
	for i = 1, #ownedCommandList do
		local command = ownedCommandList[i]
		local value = all[command]
		if type(value) == "string" then
			out[command] = value
		elseif type(value) == "table" then
			out[command] = value[1]
		end
	end
	return out
end

function Logic.Binds.Put(account, key, command, token)
	if not validKey(account, key) or not ownedCommand[command] then
		return false
	end
	local clean = bindToken(token)
	if token ~= nil and token ~= "CLEAR" and not clean then
		return false
	end
	local row = charRow(account, key)
	if type(row.binds) ~= "table" then
		row.binds = {}
	end
	local other, bound
	for other, bound in pairs(row.binds) do
		if other == command or (clean and bound == clean) then
			row.binds[other] = nil
		elseif clean and type(bound) == "table" then
			local kept = {}
			local i
			local hit = false
			for i = 1, #bound do
				if bound[i] == clean then
					hit = true
				else
					kept[#kept + 1] = bound[i]
				end
			end
			if hit then
				if #kept <= 1 then
					row.binds[other] = kept[1]
				else
					row.binds[other] = kept
				end
			end
		end
	end
	if clean then
		row.binds[command] = clean
	end
	return true
end

function Logic.Binds.Reconcile(saved, live)
	local desired = {}
	local i
	for i = 1, #ownedCommandList do
		local command = ownedCommandList[i]
		local tokens = storedTokens(type(saved) == "table" and saved[command] or nil)
		local t
		for t = 1, #tokens do
			local token = tokens[t]
			if not desired[token] then
				desired[token] = command
			end
		end
	end
	local current = {}
	if type(live) == "table" then
		for i = 1, #live do
			local row = live[i]
			if type(row) == "table" and ownedCommand[row.command] and bindToken(row.key) then
				current[row.key] = row.command
			end
		end
	end
	local unbind = {}
	local bind = {}
	local key, command
	for key, command in pairs(current) do
		if desired[key] ~= command then
			unbind[#unbind + 1] = key
		end
	end
	for key, command in pairs(desired) do
		if current[key] ~= command then
			bind[#bind + 1] = { key = key, command = command }
		end
	end
	table.sort(unbind)
	table.sort(bind, function(a, b)
		return a.key < b.key
	end)
	local ops = {}
	for i = 1, #unbind do
		ops[#ops + 1] = { key = unbind[i] }
	end
	for i = 1, #bind do
		ops[#ops + 1] = bind[i]
	end
	return ops
end

function Logic.Binds.Capture(account, key, live)
	if not validKey(account, key) then
		return false
	end
	local grouped = {}
	local seen = {}
	if type(live) == "table" then
		local i
		for i = 1, #live do
			local row = live[i]
			if type(row) == "table" and ownedCommand[row.command] then
				local token = bindToken(row.key)
				if token and not seen[token] then
					seen[token] = true
					local list = grouped[row.command]
					if not list then
						list = {}
						grouped[row.command] = list
					end
					list[#list + 1] = token
				end
			end
		end
	end
	local command, list
	for command, list in pairs(grouped) do
		table.sort(list)
	end
	local row = type(account.chars) == "table" and account.chars[key] or nil
	local any = false
	for command in pairs(grouped) do
		any = true
		break
	end
	if type(row) ~= "table" then
		if not any then
			return false
		end
		row = charRow(account, key)
	end
	local current = type(row.binds) == "table" and row.binds or {}
	local changed = false
	local i
	for i = 1, #ownedCommandList do
		command = ownedCommandList[i]
		list = grouped[command]
		local have = storedTokens(current[command])
		if not list then
			if have[1] then
				changed = true
			end
		elseif #have ~= #list then
			changed = true
		else
			local t
			for t = 1, #list do
				if have[t] ~= list[t] then
					changed = true
				end
			end
		end
	end
	if not changed then
		return false
	end
	local nextBinds = {}
	for i = 1, #ownedCommandList do
		command = ownedCommandList[i]
		list = grouped[command]
		if list and #list == 1 then
			nextBinds[command] = list[1]
		elseif list and #list > 1 then
			nextBinds[command] = list
		end
	end
	row.binds = nextBinds
	return true
end

Logic.ShareCodec = {}

local SHARE_PREFIX = "LB1!"
local SHARE_MAX = 16384

local function callString(fn, arg)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, arg)
	if not ok or type(value) ~= "string" then
		return nil
	end
	return value
end

local function callAny(fn, arg)
	if type(fn) ~= "function" then
		return nil, false
	end
	local ok, value = pcall(fn, arg)
	if not ok then
		return nil, false
	end
	return value, true
end

local function shareSettingsOk(profile)
	if type(profile) ~= "table" or type(profile.buttons) ~= "table" then
		return false
	end
	if type(profile.theme) ~= "string" or not Logic.THEMES[profile.theme] then
		return false
	end
	if type(profile.launcherTheme) ~= "string" or not Logic.THEMES[profile.launcherTheme] then
		return false
	end
	if type(profile.scale) ~= "number" or type(profile.launcherScale) ~= "number" then
		return false
	end
	if type(profile.locked) ~= "boolean" or type(profile.launcherScaleSeparate) ~= "boolean" or type(profile.launcherThemeSeparate) ~= "boolean" then
		return false
	end
	return true
end

function Logic.ShareCodec.Encode(profile, name)
	if type(C_EncodingUtil) ~= "table" then
		return nil, "Encoding is not available."
	end
	local envelope = {
		addon = "LooseButtons",
		version = 1,
		kind = "profile",
		profile = profile,
	}
	local clean = profileName(name)
	if clean then
		envelope.name = clean
	end
	local serialized = callString(C_EncodingUtil.SerializeCBOR, envelope)
	if not serialized then
		return nil, "This share string could not be read."
	end
	local compressed = callString(C_EncodingUtil.CompressString, serialized)
	if not compressed then
		return nil, "This share string could not be read."
	end
	local encoded = callString(C_EncodingUtil.EncodeBase64, compressed)
	if not encoded then
		return nil, "This share string could not be read."
	end
	return SHARE_PREFIX .. encoded
end

function Logic.ShareCodec.Decode(text)
	if type(text) ~= "string" then
		return nil, "Not a Loose Buttons string."
	end
	local stripped = string.gsub(text, "%s", "")
	if #stripped > SHARE_MAX or string.sub(stripped, 1, #SHARE_PREFIX) ~= SHARE_PREFIX then
		return nil, "Not a Loose Buttons string."
	end
	local payload = string.sub(stripped, #SHARE_PREFIX + 1)
	if type(C_EncodingUtil) ~= "table" then
		return nil, "This share string could not be read."
	end
	local decoded = callString(C_EncodingUtil.DecodeBase64, payload)
	if not decoded then
		return nil, "This share string could not be read."
	end
	local decompressed = callString(C_EncodingUtil.DecompressString, decoded)
	if not decompressed then
		return nil, "This share string could not be read."
	end
	local envelope, ok = callAny(C_EncodingUtil.DeserializeCBOR, decompressed)
	if not ok then
		return nil, "This share string could not be read."
	end
	if type(envelope) ~= "table" then
		return nil, "This share string is not a Loose Buttons layout."
	end
	if envelope.version ~= 1 then
		return nil, "This share string is a different version."
	end
	if envelope.addon ~= "LooseButtons" or envelope.kind ~= "profile" or not shareSettingsOk(envelope.profile) then
		return nil, "This share string is not a Loose Buttons layout."
	end
	local sharedName = profileName(envelope.name)
	return Logic.Profile(envelope.profile), sharedName
end
