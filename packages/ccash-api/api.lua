-- Reactified's CCash API
local bank = "https://twix.aosync.me/BankF/" -- set your bank url here

--[[

	REACT CCASH API | DOCUMENTATION

	SIMPLE FUNCTIONS:
		api.simple.register( USERNAME, PASSWORD )	   Register a new user account
		api.simple.balance( USERNAME )				  Check account balance
		api.simple.verify( USERNAME, PASSWORD )		 Verify if credentials are valid
		api.simple.send( USERNAME, PASSWORD, TO, AMT )  Send AMT of money to TO

	IN ADDITION TO THE SIMPLIFIED API, ALL STANDARD CCASH FUNCTIONS ARE AVAILABLE
	SEE STANDARD CCASH DOCUMENTATION HERE: https://ccash.ryzerth.com/BankF/help

]]

-- Automatic Updates
if fs.exists("rpm.lua") then
	os.loadAPI("rpm.lua")
	rpm.api.update("ccash-api")
end

-- Integrated JSON API
local controls = {["\n"]="\\n", ["\r"]="\\r", ["\t"]="\\t", ["\b"]="\\b", ["\f"]="\\f", ["\""]="\\\"", ["\\"]="\\\\"}
local json = {}

local function isArray(t)
	local max = 0
	for k,v in pairs(t) do
		if type(k) ~= "number" then
			return false
		elseif k > max then
			max = k
		end
	end
	return max == #t
end

local whites = {['\n']=true; ['\r']=true; ['\t']=true; [' ']=true; [',']=true; [':']=true}
local function removeWhite(str)
	while whites[str:sub(1, 1)] do
		str = str:sub(2)
	end
	return str
end

local function encodeCommon(val, pretty, tabLevel, tTracking)
	local str = ""

	-- Tabbing util
	local function tab(s)
		str = str .. ("\t"):rep(tabLevel) .. s
	end

	local function arrEncoding(val, bracket, closeBracket, iterator, loopFunc)
		str = str .. bracket
		if pretty then
			str = str .. "\n"
			tabLevel = tabLevel + 1
		end
		for k,v in iterator(val) do
			tab("")
			loopFunc(k,v)
			str = str .. ","
			if pretty then str = str .. "\n" end
		end
		if pretty then
			tabLevel = tabLevel - 1
		end
		if str:sub(-2) == ",\n" then
			str = str:sub(1, -3) .. "\n"
		elseif str:sub(-1) == "," then
			str = str:sub(1, -2)
		end
		tab(closeBracket)
	end

	-- Table encoding
	if type(val) == "table" then
		assert(not tTracking[val], "Cannot encode a table holding itself recursively")
		tTracking[val] = true
		if isArray(val) then
			arrEncoding(val, "[", "]", ipairs, function(k,v)
				str = str .. encodeCommon(v, pretty, tabLevel, tTracking)
			end)
		else
			arrEncoding(val, "{", "}", pairs, function(k,v)
				assert(type(k) == "string", "JSON object keys must be strings", 2)
				str = str .. encodeCommon(k, pretty, tabLevel, tTracking)
				str = str .. (pretty and ": " or ":") .. encodeCommon(v, pretty, tabLevel, tTracking)
			end)
		end
	-- String encoding
	elseif type(val) == "string" then
		str = '"' .. val:gsub("[%c\"\\]", controls) .. '"'
	-- Number encoding
	elseif type(val) == "number" or type(val) == "boolean" then
		str = tostring(val)
	else
		error("JSON only supports arrays, objects, numbers, booleans, and strings", 2)
	end
	return str
end

function json.encode(val)
	return encodeCommon(val, false, 0, {})
end

local function encodePretty(val)
	return encodeCommon(val, true, 0, {})
end

local decodeControls = {}
for k,v in pairs(controls) do
	decodeControls[v] = k
end

local function parseBoolean(str)
	if str:sub(1, 4) == "true" then
		return true, removeWhite(str:sub(5))
	else
		return false, removeWhite(str:sub(6))
	end
end

local function parseNull(str)
	return nil, removeWhite(str:sub(5))
end

local numChars = {['e']=true; ['E']=true; ['+']=true; ['-']=true; ['.']=true}
local function parseNumber(str)
	local i = 1
	while numChars[str:sub(i, i)] or tonumber(str:sub(i, i)) do
		i = i + 1
	end
	local val = tonumber(str:sub(1, i - 1))
	str = removeWhite(str:sub(i))
	return val, str
end

local function parseString(str)
	str = str:sub(2)
	local s = ""
	while str:sub(1,1) ~= "\"" do
		local next = str:sub(1,1)
		str = str:sub(2)
		assert(next ~= "\n", "Unclosed string")

		if next == "\\" then
			local escape = str:sub(1,1)
			str = str:sub(2)

			next = assert(decodeControls[next..escape], "Invalid escape character")
		end

		s = s .. next
	end
	return s, removeWhite(str:sub(2))
end

local function parseArray(str)
	str = removeWhite(str:sub(2))

	local val = {}
	local i = 1
	while str:sub(1, 1) ~= "]" do
		local v = nil
		v, str = json.parseValue(str)
		val[i] = v
		i = i + 1
		str = removeWhite(str)
	end
	str = removeWhite(str:sub(2))
	return val, str
end

function json.parseObject(str)
	str = removeWhite(str:sub(2))

	local val = {}
	while str:sub(1, 1) ~= "}" do
		local k, v = nil, nil
		k, v, str = json.parseMember(str)
		val[k] = v
		str = removeWhite(str)
	end
	str = removeWhite(str:sub(2))
	return val, str
end

function json.parseMember(str)
	local k = nil
	k, str = json.parseValue(str)
	local val = nil
	val, str = json.parseValue(str)
	return k, val, str
end

function json.parseValue(str)
	local fchar = str:sub(1, 1)
	if fchar == "{" then
		return json.parseObject(str)
	elseif fchar == "[" then
		return parseArray(str)
	elseif tonumber(fchar) ~= nil or numChars[fchar] then
		return parseNumber(str)
	elseif str:sub(1, 4) == "true" or str:sub(1, 5) == "false" then
		return parseBoolean(str)
	elseif fchar == "\"" then
		return parseString(str)
	elseif str:sub(1, 4) == "null" then
		return parseNull(str)
	end
	return nil
end

function json.decode(str)
	str = removeWhite(str)
	local t = json.parseValue(str)
	return t
end

local function decodeFromFile(path)
	local file = assert(fs.open(path, "r"))
	local decoded = decode(file.readAll())
	file.close()
	return decoded
end
-- END JSON API

-- HTTP Functions
local function http_request(method, option, args, password)
	local res, body
	
	http.request({
		url = bank .. option, 
		method = method, 
		body = body,
		headers = {
			["Content-Type"] = "application/json",
			["Password"] = password,
		}
	})

	local tmr = os.startTimer(timeout or 5)
	while true do

		local event, url, sourceText = os.pullEvent()

		-- timeout
		if event == "timer" and url == tmr then
			return false, "HTTP Timeout"
		end

		-- success
		if event == "http_success" then
			local respondedText = sourceText.readAll()

			sourceText.close()
			
			if tonumber(respondedText) then
				return true, tonumber(respondedText)
			else
				return true, respondedText
			end
		end

		-- fail
		if event == "http_failure" then
			return false, "HTTP Failure"
		end
	end
end

-- Full API
local enum = {
	[1] = "Success",
	[0] = "Unknown Error",
	[-1] = "User Not Found",
	[-2] = "Wrong Password",
	[-3] = "Invalid Request",
	[-4] = "Name Too Long",
	[-5] = "User Already Exists",
	[-6] = "Insufficient Funds",
}

admin = {} -- holds the admin only functions

function admin.close(admin_password) -- shutdown server
	local ok,err = http_request("POST","admin/close",nil,admin_password)
	return ok,err,enum[err]
end

function user(username, password) -- register
	local ok,err = http_request("POST","user/"..username,nil,password) 
	return ok,err,enum[err]
end

function admin.user(username, admin_password, balance, password) -- add user with balance
	local ok,err = http_request("POST","admin/user/"..username.."?init_bal={"..tostring(balance).."}",password,admin_password) 
	return ok,err,enum[err]
end

function sendfunds(username, target, amount, password) -- transfer money
	local ok,err = http_request("POST",username.."/send/"..target.."?amount="..tostring(amount),nil,password) 
	return ok,err,enum[err]
end

function changepass(username, password, new_password) -- change password
	local ok,err = http_request("PATCH",username.."/pass/change",new_password,password) 
	return ok,(err==1),enum[err]
end

function admin.bal(username, admin_password, balance) -- admin set balance
	local ok,err = http_request("PATCH","admin/"..username.."/bal?amount="..tostring(balance),nil,admin_password) 
	return ok,err,enum[err]
end

function vpass(username, password) -- verify user and password combo
	local ok,err = http_request("GET",username.."/pass/verify",nil,password)
	return ok,(err==1),enum[err]
end

function log(username, password) -- get transaction logs for us
	local ok,err = http_request("GET",username.."/log",nil,password)
	return ok,json.decode(err)
end

function contains(username) -- check if user exists
	local ok,err = http_request("GET","contains/"..username)
	return ok,err,enum[err]
end

function bal(username) -- check user balance
	local ok,err = http_request("GET",username.."/bal")
	return ok,tonumber(err)
end

function admin.vpass(admin_password) -- verify admin password
	local ok,err = http_request("GET","admin/verify",nil,admin_password)
	return ok,err,enum[err]
end

function delete(username, password) -- delete user account
	local ok,err = http_request("DELETE","user/"..username,nil,password)
	return ok,err,enum[err]
end

function admin.delete(username, admin_password) -- admin delete user account
	local ok,err = http_request("DELETE","admin/user/"..username,nil,admin_password)
	return ok,err,enum[err]
end

function ping()
	local ok,err = http_request("GET","ping")
	return ok
end

-- Simple API
simple = {
	online = ping,
	register = function(username, password)
		local ok,err,output = user(username, password)
		return err,output
	end,
	balance = function(username)
		local ok,err,output = bal(username)
		return err,output
	end,
	verify = function(username, password)
		local ok,err,output = vpass(username, password)
		return err,output
	end,
	send = function(fromUsername, fromPassword, toUsername, amount)
		local ok,err,output = sendfunds(fromUsername, toUsername, amount, fromPassword)
		return err,output
	end,
	transactions = function(username, password)
		local ok,err,output = log(username, password)
		return err,output
	end,
}
