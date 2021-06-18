-- Reactified's CCash API
local bank = "https://twix.aosync.me/BankF/" -- set your bank url here

--[[

    REACT CCASH API | DOCUMENTATION

    SIMPLE FUNCTIONS:
        api.simple.register( USERNAME, PASSWORD )       Register a new user account
        api.simple.balance( USERNAME )                  Check account balance
        api.simple.verify( USERNAME, PASSWORD )         Verify if credentials are valid
        api.simple.send( USERNAME, PASSWORD, TO, AMT )  Send AMT of money to TO

    IN ADDITION TO THE SIMPLIFIED API, ALL STANDARD CCASH FUNCTIONS ARE AVAILABLE
    SEE STANDARD CCASH DOCUMENTATION HERE: https://ccash.ryzerth.com/BankF/help

]]

-- HTTP Functions
local function http_request(method, option, args, password)
    local res, body

    if method ~= "GET" and args then
        body = json.encode(args)
    end

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
    return ok,err
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
