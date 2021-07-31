-- Reactified's CCash API
local bank = "https://twix.aosync.me/" -- set your bank url here

--[[

	REACT CCASH API | DOCUMENTATION

	SIMPLE FUNCTIONS:
		api.simple.register( USERNAME, PASSWORD )	   Register a new user account
		api.simple.balance( USERNAME )				  Check account balance
		api.simple.verify( USERNAME, PASSWORD )		 Verify if credentials are valid
		api.simple.send( USERNAME, PASSWORD, TO, AMT )  Send AMT of money to TO

	IN ADDITION TO THE SIMPLIFIED API, ALL STANDARD CCASH FUNCTIONS ARE AVAILABLE
	YOU CAN ALSO ACCESS THE SPACECAT CCASH API WITH api.ccash

]]

-- Automatic Updates
if fs.exists("rpm.lua") then
	os.loadAPI("rpm.lua")
	rpm.api.update("ccash-api")
end

-- Load Spacecat-Chan's API
ccash = dofile("/apis/ccash/api.lua")
ccash.meta.set_server_address(bank)

-- Full API
admin = {} -- holds the admin only functions

function ping()
    local result = {ccash.properties()}
    return type(result[1]) ~= nil
end

function user(username, password) -- register
	local result = {ccash.register(username,password)} 
	return ping(), result[1] or false, result[3]
end

function sendfunds(username, target, amount, password) -- transfer money
	local result = {ccash.send_funds(username, password, target, amount)} 
	return ping(), result[1] or false, result[3]
end

function changepass(username, password, new_password) -- change password
	local result = {ccash.change_password(username, password, new_password)} 
	return ping(), result[1] or false, result[3]
end

function vpass(username, password) -- verify user and password combo
	local result = {ccash.verify_password(username, password)} 
	return ping(), result[1] or false, result[3]
end

function log(username, password) -- get transaction logs for us
	local result = {ccash.get_log(username, password)} 
    local logs = result[3]
    if type(logs) == "table" then
        for i,v in pairs(logs) do
            logs[i].time = v.time*1000
        end
    end
	return ping(), result[1] or false, logs
end

function contains(username) -- check if user exists
	local result = {ccash.user_exists(username)} 
	return ping(), result[1] or false, result[3]
end

function bal(username) -- check user balance
	local result = {ccash.get_bal(username)} 
	return ping(), result[1] or false, result[3]
end

function delete(username, password) -- delete user account
	local result = {ccash.delete_self(username, password)} 
	return ping(), result[1] or false, result[3]
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
