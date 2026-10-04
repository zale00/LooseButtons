local function readFile(path)
	local handle = io.open(path, "rb")
	if not handle then
		return nil
	end
	local text = handle:read("*a")
	handle:close()
	return text
end

local root
if readFile("LooseButtons/LooseButtons.toc") then
	root = "LooseButtons"
elseif readFile("LooseButtons.toc") then
	root = ""
end

local function addonPath(name)
	if not root or root == "" then
		return name
	end
	return root .. "/" .. name
end

local function shellQuote(text)
	return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function luacAccepts(path)
	local command = "luac5.1 -p " .. shellQuote(path) .. " >/dev/null 2>&1"
	return os.execute(command) == 0
end

local function sourceAccepts(source)
	local tmp = os.tmpname()
	local handle = io.open(tmp, "wb")
	if not handle then
		os.remove(tmp)
		return false
	end
	handle:write(source)
	handle:close()
	local ok = luacAccepts(tmp)
	os.remove(tmp)
	return ok
end

local function extraLocals(count)
	local lines = {}
	for index = 1, count do
		lines[index] = "local function lbBudgetExtra" .. index .. "() end\n"
	end
	return table.concat(lines)
end

local function spareCount(source)
	local body = source
	if not body:match("\n$") then
		body = body .. "\n"
	end
	local low = 0
	local high = 200
	local best = -1
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if sourceAccepts(body .. extraLocals(mid)) then
			best = mid
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return best
end

local function baseName(path)
	return path:match("([^/]+)$") or path
end

local function interfaceProblem(text)
	local found = false
	for line in text:gmatch("[^\r\n]+") do
		local body = line:match("^%s*(.*)$")
		local comment = body:sub(1, 1) == "#" and body:sub(2, 2) ~= "#"
		if not comment then
			local values = body:match("^##%s*Interface:%s*(.*)$")
			if values then
				found = true
				for number in values:gmatch("%d+") do
					if number:sub(1, 2) == "12" then
						return number
					end
				end
			end
		end
	end
	if not found then
		return "missing"
	end
	return nil
end

local badInterface = {
	"## Interface: 120100",
	"## Interface: 16001, 120100",
	"# note ## Interface: 16001\n## Interface: 120100",
}
local goodInterface = {
	"## Interface: 16001",
	"## Interface: 16002",
}
for _, sample in ipairs(badInterface) do
	if not interfaceProblem(sample) then
		io.stderr:write("interface sample accepted\n")
		os.exit(1)
	end
end
for _, sample in ipairs(goodInterface) do
	if interfaceProblem(sample) then
		io.stderr:write("interface sample rejected\n")
		os.exit(1)
	end
end

local toc = readFile(addonPath("LooseButtons.toc"))
if not toc then
	io.stderr:write("missing TOC\n")
	os.exit(1)
end

local listed = {}
for line in toc:gmatch("[^\r\n]+") do
	local name = line:match("^%s*([^#%s][^%s]*%.lua)%s*$")
	if name then
		listed[#listed + 1] = name
	end
end

local spareByName = {}
for _, name in ipairs(listed) do
	local source = readFile(addonPath(name))
	local spare = -1
	if source then
		spare = spareCount(source)
	end
	local fileName = baseName(name)
	spareByName[fileName] = spare
	print(fileName .. " spare " .. spare)
end

local denied = false
local function deny(message)
	denied = true
	io.stderr:write(message .. "\n")
end

if spareByName["LooseButtons.lua"] ~= 0 then
	deny("LooseButtons.lua spare is " .. tostring(spareByName["LooseButtons.lua"]))
end
local logicSpare = spareByName["Logic.lua"]
if not logicSpare or logicSpare < 40 then
	deny("Logic.lua spare is " .. tostring(logicSpare))
end
local interface = interfaceProblem(toc)
if interface then
	deny("interface " .. interface)
end
if toc:find("Interface-Forever", 1, true) then
	deny("TOC contains Interface-Forever")
end
local camelot = io.open(addonPath("_Camelot.toc"), "rb")
if camelot then
	camelot:close()
	deny("Camelot TOC exists")
end
local fixturePath = addonPath("devcheck/fixture_201_locals.lua")
if not readFile(fixturePath) then
	deny("fixture missing")
elseif luacAccepts(fixturePath) then
	deny("fixture compiled")
end

if denied then
	os.exit(1)
end
os.exit(0)
