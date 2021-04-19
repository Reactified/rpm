--/ CCash Wallet /--
local ccashAPI = "/apis/ccash.lua"
local walletDataStore = "/.walletData"

if not fs.exists(ccashAPI) then
    printError("CCASH API is not installed")
    print("You can change the API path in the wallet script")
    print("If you have RPM, run 'rpm install ccash-api'")
    print()
    write("Automatically install CCASH API (y/n): ")
    local choice = read()
    if string.lower(choice) == "y" then
        local h = http.get("https://raw.githubusercontent.com/Reactified/rpm/main/packages/ccash-api/api.lua")
        if h then
            f = fs.open(ccashAPI,"w")
            f.writeLine(h.readAll())
            f.close()
            h.close()
            print("CCASH API Installed")
            sleep(2)
        else
            printError("An error occured.")
            return
        end
    end
end
os.loadAPI(ccashAPI)
local shortName = ccashAPI
while true do
    local findPos = string.find(shortName,"/")
    if findPos then
        shortName = string.sub(shortName,findPos+1,#shortName)
    else
        break
    end
end
shortName = string.gsub(shortName,".lua","")

local fullApi = _G[shortName]
local api = _G[shortName].simple
if not api then
    printError("Could not extract simple API")
    return
end

--/ Settings /--
local cname = "CCash"
local csn = "CSH"

--/ Wallet Data /--
local walletData = {}
if fs.exists(walletDataStore) then
    f = fs.open(walletDataStore,"r")
    walletData = textutils.unserialise(f.readAll())
    f.close()
end
local function saveWalletData()
    f = fs.open(walletDataStore,"w")
    f.writeLine(textutils.serialise(walletData))
    f.close()
end

--/ Initialization /--
local w,h = term.getSize()
term.setPaletteColor(colors.brown,1,0.8,0.2)

--/ Functions /--
local function drawLogo(x,y)
    term.setCursorPos(x,y)
    term.setBackgroundColor(colors.orange)
    term.setTextColor(colors.white)
    term.write("/")
    term.setBackgroundColor(colors.brown)
    term.write("\\")
    term.setCursorPos(x,y+1)
    term.write("\\")
    term.setBackgroundColor(colors.yellow)
    term.write("/")
end
local function drawHeader()
    term.setBackgroundColor(colors.black)
    term.clear()
    paintutils.drawFilledBox(1,1,w,4,colors.gray)
    drawLogo(2,2)
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(5,2)
    term.setTextColor(colors.brown)
    write(cname)
    term.setCursorPos(5,3)
    term.setTextColor(colors.lightGray)
    write("Wallet")
    term.setBackgroundColor(colors.black)
end
local function rightAlign(str,ln)
    term.setCursorPos(w-#str,ln)
    write(str)
end
local function center(str,ln)
    local w,h = term.getSize()
    term.setCursorPos((w/2)-(#str/2)+1,2)
    write(str)
end

--/ Routine /--
local autologin = walletData.username
while true do
    drawHeader()
    term.setCursorPos(2,6)
    term.setTextColor(colors.brown)
    write("Welcome!")
    term.setCursorPos(2,7)
    term.setTextColor(colors.lightGray)
    write("To get started, log in")
    term.setCursorPos(2,8)
    write("or create an account.")
    term.setCursorPos(2,10)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.gray)
    write(" Log In ")
    term.setCursorPos(11,10)
    term.setTextColor(colors.gray)
    term.setBackgroundColor(colors.brown)
    write(" Sign Up ")
    term.setCursorPos(2,h-1)
    term.setTextColor(colors.lightGray)
    term.setBackgroundColor(colors.black)
    write("Quit")
    term.setCursorPos(2,12)
    term.setTextColor(colors.gray)
    write("Connnecting")
    term.setCursorPos(2,12)
    if not autologin then
        if api.online() then
            term.setTextColor(colors.brown)
            write("Connected      ")
        else
            term.setTextColor(colors.red)
            write("Connection Failed")
        end
    end
    local e,c,x,y = "autologin", 0, 0, 0
    if not autologin then
        e,c,x,y = os.pullEvent("mouse_click")
    end
    if y == h-1 then
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        return
    elseif y == 10 or autologin then
        if x < 11 or autologin then
            -- Log In
            drawHeader()
            term.setCursorPos(2,6)
            term.setTextColor(colors.brown)
            write("Log In")
            term.setCursorPos(2,8)
            term.setTextColor(colors.lightGray)
            write("Username")
            term.setCursorPos(2,10)
            write("Password")
            term.setCursorPos(11,8)
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
            write(string.rep(" ",w-11))
            term.setCursorPos(11,10)
            write(string.rep(" ",w-11))
            term.setCursorPos(12,8)
            term.setTextColor(colors.white)
            local username, password
            if autologin then
                write(walletData.username)
                username = walletData.username
            else
                username = read()
            end
            term.setCursorPos(12,10)
            term.setTextColor(colors.white)
            if autologin and walletData.password then
                write(string.rep("*",#walletData.password))
                password = walletData.password
            else
                password = read("*")
            end
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(2,12)
            write("Loading...")
            if api.verify(username,password) then
                term.setCursorPos(2,12)
                term.setTextColor(colors.brown)
                term.clearLine()
                term.setCursorPos(2,12)
                write("Accepted!")
                if not autologin then
                    sleep(1)
                end
                -- Interface
                local transferTO = ""
                local transferAMT = "0"
                local tabs = {
                    "Dashboard",
                    "Transfer",
                    "Settings",
                    --"Transactions",
                    --"Leaderboard",
                }
                local tab = 1
                local scroll = 1
                while true do
                    -- Refresh
                    local balance = api.balance(username)
                    -- UI Draw
                    term.setBackgroundColor(colors.black)
                    term.clear()
                    paintutils.drawFilledBox(1,1,w,3,colors.gray)
                    term.setCursorPos(2,2)
                    term.setTextColor(colors.lightGray)
                    write("<- ")
                    term.setTextColor(colors.brown)
                    center(tabs[tab],2)
                    term.setTextColor(colors.lightGray)
                    term.setCursorPos(w-2,2)
                    write("->")
                    -- Tab Draw
                    if tab == 1 then
                        drawLogo(2,5)
                        term.setCursorPos(5,5)
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.lightGray)
                        write(username)
                        term.setTextColor(colors.brown)
                        term.setCursorPos(5,6)
                        write(tostring(balance).." "..csn)
                        term.setTextColor(colors.gray)
                        for i=2,w-1 do
                            term.setCursorPos(i,8)
                            write(string.char(math.random(129,140)))
                        end
                        term.setCursorPos(2,h-1)
                        term.setTextColor(colors.lightGray)
                        write("> Logout")
                    elseif tab == 2 then
                        drawLogo(2,h-2)
                        term.setCursorPos(5,h-2)
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.lightGray)
                        write(username)
                        term.setTextColor(colors.brown)
                        term.setCursorPos(5,h-1)
                        write(tostring(balance).." "..csn)
                        term.setTextColor(colors.gray)
                        for i=2,w-1 do
                            term.setCursorPos(i,h-4)
                            write(string.char(math.random(129,140)))
                        end
                        term.setCursorPos(2,5)
                        term.setTextColor(colors.brown)
                        write("Transfer Funds")
                        term.setCursorPos(2,7)
                        term.setTextColor(colors.lightGray)
                        write("Target")
                        term.setCursorPos(2,9)
                        write("Amount")
                        term.setCursorPos(9,7)
                        term.setBackgroundColor(colors.gray)
                        term.setTextColor(colors.lightGray)
                        write(string.rep(" ",w-9))
                        term.setCursorPos(9,9)
                        write(string.rep(" ",w-9))
                        term.setCursorPos(10,7)
                        write(string.sub(transferTO,1,w-11))
                        term.setCursorPos(10,9)
                        write(string.sub(transferAMT,1,w-15).." "..csn)
                        term.setCursorPos(2,11)
                        term.setBackgroundColor(colors.brown)
                        term.setTextColor(colors.gray)
                        write(" Send ")
                    elseif tab == 3 then
                        term.setCursorPos(2,5)
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.lightGray)
                        write("Wallet Settings")
                        term.setTextColor(colors.brown)
                        term.setCursorPos(2,7)
                        write("Autologin: ")
                        if walletData.username and walletData.password then
                            term.setTextColor(colors.brown)
                            write("Full")
                        elseif walletData.username then
                            term.setTextColor(colors.brown)
                            write("User")
                        else
                            term.setTextColor(colors.gray)
                            write("Off")
                        end
                        term.setTextColor(colors.gray)
                        for i=2,w-1 do
                            term.setCursorPos(i,9)
                            write(string.char(math.random(129,140)))
                        end
                        term.setCursorPos(2,11)
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.lightGray)
                        write("Account Settings")
                        term.setTextColor(colors.brown)
                        term.setCursorPos(2,13)
                        write("Change Password")
                        term.setTextColor(colors.red)
                        term.setCursorPos(2,14)
                        write("Delete Account")
                    elseif tab == 4 then
                        drawLogo(2,5)
                        term.setCursorPos(5,5)
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.lightGray)
                        write(username)
                        term.setCursorPos(5,6)
                        term.setTextColor(colors.brown)
                        write("Transactions")
                        term.setTextColor(colors.gray)
                        for i=2,w-1 do
                            term.setCursorPos(i,8)
                            write(string.char(math.random(129,140)))
                        end
                        local rawTransactions = api.transactions(username)
                        local Xtrans = {}
                        local vx = 0
                        if vx < 1 then
                            vx = 1 
                        end
                        for i=vx,#rawTransactions do
                            local val = rawTransactions[i]
                            val.id = i
                            Xtrans[#Xtrans+1] = val
                        end
                        local trans = {}
                        for i,v in pairs(Xtrans) do
                            trans[#Xtrans-i+1] = v
                        end
                        local yp = 10
                        for i=scroll,h+scroll-11 do
                            local v = trans[i]
                            if v then
                                term.setCursorPos(2,yp)
                                term.setTextColor(colors.lightGray)
                                write(tostring(v.id)..": "..v.address)
                                local str = tostring(v.amount)
                                if v.amount > 0 then
                                    str = "+"..str.." <<"
                                    term.setTextColor(colors.lime)
                                else
                                    str = str .. " >>"
                                    term.setTextColor(colors.red)
                                end
                                rightAlign(str,yp)
                                yp = yp + 1
                            end
                        end
                    elseif tab == 5 then
                        local leaderboard = api.leaderboard()
                        local yp = 5
                        for i=1,math.floor((h-4)/3) do
                            if leaderboard[i] then
                                drawLogo(2,yp)
                                term.setCursorPos(5,yp)
                                term.setBackgroundColor(colors.black)
                                term.setTextColor(colors.white)
                                if i == 1 then
                                    term.setTextColor(colors.brown)
                                elseif i == 2 then
                                    term.setTextColor(colors.lightGray)
                                elseif i == 3 then
                                    term.setTextColor(colors.orange)
                                end
                                write("#"..tostring(i)..": "..leaderboard[i][1])
                                term.setCursorPos(5,yp+1)
                                term.setBackgroundColor(colors.black)
                                term.setTextColor(colors.gray)
                                write(tostring(leaderboard[i][2]).." "..csn)
                                yp = yp + 3
                            end
                        end
                    end
                    -- Event Handling
                    local e,c,x,y
                    while true do
                        e,c,x,y = os.pullEvent()
                        if e == "mouse_click" or e == "mouse_scroll" then
                            break
                        end
                    end
                    if e == "mouse_scroll" then
                        scroll = scroll + (c*2)
                        if scroll < 1 then
                            scroll = 1
                        end
                    elseif e == "mouse_click" then
                        if y == 1 or y == 2 or y == 3 then
                            if x < w/2 then
                                tab = tab - 1
                                if tab == 0 then
                                    tab = #tabs
                                end
                            elseif x > w/2 then
                                tab = tab + 1
                                if tab > #tabs then
                                    tab = 1
                                end
                            end
                        elseif tab == 1 then
                            if y == h-1 then
                                break
                            end
                        elseif tab == 2 then
                            if y == 7 then
                                term.setBackgroundColor(colors.gray)
                                term.setTextColor(colors.white)
                                term.setCursorPos(10,7)
                                transferTO = read()
                            elseif y == 9 then
                                term.setBackgroundColor(colors.gray)
                                term.setTextColor(colors.white)
                                term.setCursorPos(10,9)
                                transferAMT = read()
                            elseif y == 11 then
                                term.setBackgroundColor(colors.black)
                                term.setTextColor(colors.brown)
                                term.setCursorPos(10,11)
                                write("...")
                                term.setCursorPos(10,11)
                                if tonumber(transferAMT) then
                                    if tonumber(transferAMT) > 0 then
                                        local ok,err = api.send(username,password,transferTO,tonumber(transferAMT))
                                        if ok and balance ~= api.balance(username) then
                                            write("Success!")
                                        else
                                            write("Failed.")
                                        end
                                    else
                                        write("Invalid amount.")
                                    end
                                else
                                    write("Invalid amount.")
                                end
                                os.pullEvent("mouse_click")
                            end
                        elseif tab == 3 then
                            if y == 7 then
                                -- autologin
                                term.setBackgroundColor(colors.black)
                                for i=4,h do
                                    term.setCursorPos(1,i)
                                    term.clearLine()
                                end
                                term.setCursorPos(2,5)
                                term.setTextColor(colors.lightGray)
                                write("Autologin Setup")
                                term.setCursorPos(2,7)
                                term.setTextColor(colors.brown)
                                write("Full")
                                term.setCursorPos(2,8)
                                term.setTextColor(colors.gray)
                                write("UNENCRYPTED PASSWORD")
                                term.setCursorPos(2,10)
                                term.setTextColor(colors.brown)
                                write("User")
                                term.setCursorPos(2,11)
                                term.setTextColor(colors.gray)
                                write("AUTOFILL USERNAME")
                                term.setCursorPos(2,13)
                                term.setTextColor(colors.brown)
                                write("None")
                                term.setCursorPos(2,14)
                                term.setTextColor(colors.gray)
                                write("NO AUTOLOGIN")
                                local e,c,x,y = os.pullEvent("mouse_click")
                                if y == 7 or y == 8 then
                                    term.setCursorPos(2,16)
                                    term.setTextColor(colors.brown)
                                    write("Enter Password")
                                    term.setCursorPos(2,17)
                                    term.setTextColor(colors.lightGray)
                                    write("> ")
                                    -- full
                                    walletData.username = username
                                    walletData.password = read("*")
                                elseif y == 10 or y == 11 then
                                    -- user
                                    walletData.username = username
                                    walletData.password = nil
                                elseif y == 13 or y == 14 then
                                    -- none
                                    walletData.username = nil
                                    walletData.password = nil
                                end
                                saveWalletData()
                            elseif y == 13 then
                                -- change password
                                term.setBackgroundColor(colors.black)
                                for i=4,h do
                                    term.setCursorPos(1,i)
                                    term.clearLine()
                                end
                                term.setCursorPos(2,5)
                                term.setTextColor(colors.brown)
                                write("Change Password")
                                term.setTextColor(colors.gray)
                                for i=2,w-1 do
                                    term.setCursorPos(i,7)
                                    write(string.char(math.random(129,140)))
                                end
                                term.setCursorPos(2,9)
                                term.setTextColor(colors.brown)
                                write("Old Password")
                                term.setCursorPos(2,10)
                                term.setTextColor(colors.lightGray)
                                write("> ")
                                local old_password = read("*")
                                term.setCursorPos(2,12)
                                term.setTextColor(colors.brown)
                                if old_password ~= password then
                                    write("Invalid Password")
                                    sleep(2)
                                else
                                    write("New Password")
                                    term.setCursorPos(2,13)
                                    term.setTextColor(colors.lightGray)
                                    write("> ")
                                    local new_password = read("*")
                                    term.setCursorPos(2,14)
                                    term.setTextColor(colors.lightGray)
                                    write("> ")
                                    local new_password_confirm = read("*")
                                    term.setCursorPos(2,16)
                                    term.setTextColor(colors.brown)
                                    if new_password == new_password_confirm then
                                        local ok,res = fullApi.changepass(username, old_password, new_password)
                                        if ok and res then
                                            write("Password changed")
                                        else
                                            write("Error occured")
                                        end
                                        sleep(2)
                                    else
                                        write("Passwords must match")
                                        sleep(2)
                                    end
                                end
                            elseif y == 14 then
                                -- delete account
                                term.setBackgroundColor(colors.black)
                                for i=4,h do
                                    term.setCursorPos(1,i)
                                    term.clearLine()
                                end
                                term.setCursorPos(2,5)
                                term.setTextColor(colors.red)
                                write("Delete Account")
                                term.setTextColor(colors.gray)
                                for i=2,w-1 do
                                    term.setCursorPos(i,7)
                                    write(string.char(math.random(129,140)))
                                end
                                term.setCursorPos(2,9)
                                term.setTextColor(colors.brown)
                                write("Enter Password")
                                term.setCursorPos(2,10)
                                term.setTextColor(colors.lightGray)
                                write("> ")
                                local delete_password = read("*")
                                term.setCursorPos(2,12)
                                term.setTextColor(colors.brown)
                                if password ~= delete_password then
                                    write("Invalid Password")
                                    sleep(2)
                                else
                                    write("Confirm Username")
                                    term.setCursorPos(2,13)
                                    term.setTextColor(colors.lightGray)
                                    write("> ")
                                    local delete_user = read()
                                    if delete_user == username then
                                        for i=8,h do
                                            term.setCursorPos(1,i)
                                            term.clearLine()
                                        end
                                        term.setBackgroundColor(colors.red)
                                        term.setTextColor(colors.black)
                                        term.setCursorPos(1,9)
                                        term.clearLine()
                                        term.setCursorPos(2,9)
                                        write("!!! ACCOUNT DELETION !!!")
                                        term.setBackgroundColor(colors.black)
                                        term.setCursorPos(2,15)
                                        term.setTextColor(colors.gray)
                                        write("Press any key to abort")
                                        term.setCursorPos(2,11)
                                        term.setTextColor(colors.red)
                                        write("All funds will be lost!")
                                        term.setCursorPos(2,12)
                                        write("This cannot be undone!")
                                        local abort = false
                                        for i=20,0,-1 do
                                            if abort then
                                                break
                                            end
                                            term.setCursorPos(1,14)
                                            term.clearLine()
                                            term.setCursorPos(2,14)
                                            write("T-"..tostring(i).." DELETION")
                                            local abort_tmr = os.startTimer(1)
                                            while true do
                                                local e,k = os.pullEvent()
                                                if e == "timer" and k == abort_tmr then
                                                    break
                                                elseif e == "key" then
                                                    abort = true
                                                    break
                                                end
                                            end
                                            if i == 0 and not abort then
                                                term.setBackgroundColor(colors.black)
                                                term.clear()
                                                term.setCursorPos(1,1)
                                                term.setTextColor(colors.red)
                                                print("Account Deleted.")
                                                fullApi.delete(username,password)
                                                return
                                            end
                                        end
                                        term.setCursorPos(2,17)
                                        term.setTextColor(colors.lime)
                                        write("Aborted.")
                                        sleep(2)
                                    else
                                        term.setCursorPos(2,15)
                                        term.setTextColor(colors.brown)
                                        write("Aborted.")
                                    end
                                end
                            end
                        end
                    end
                end
            else
                term.setCursorPos(2,12)
                term.setTextColor(colors.brown)
                term.clearLine()
                term.setCursorPos(2,12)
                write("Invalid credentials.")
                sleep(2)
            end
        else
            -- Sign Up
            drawHeader()
            term.setCursorPos(2,6)
            term.setTextColor(colors.brown)
            write("Sign Up")
            term.setCursorPos(2,8)
            term.setTextColor(colors.lightGray)
            write("Username")
            term.setCursorPos(2,10)
            write("Password")
            term.setCursorPos(2,12)
            write("Confirm")
            term.setCursorPos(11,8)
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
            write(string.rep(" ",w-11))
            term.setCursorPos(11,10)
            write(string.rep(" ",w-11))
            term.setCursorPos(11,12)
            write(string.rep(" ",w-11))
            term.setCursorPos(12,8)
            term.setTextColor(colors.white)
            local username = read()
            term.setCursorPos(12,10)
            term.setTextColor(colors.white)
            local password = read("*")
            term.setCursorPos(12,12)
            local confirm = read("*")
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(2,14)
            write("Loading...")
            if #username > 32 then
                term.setCursorPos(2,14)
                term.setTextColor(colors.brown)
                term.clearLine()
                term.setCursorPos(2,14)
                write("Name too long!")
                sleep(2)
            elseif string.find(username," ") then
                term.setCursorPos(2,14)
                term.setTextColor(colors.brown)
                term.clearLine()
                term.setCursorPos(2,14)
                write("Name cannot have spaces")
                sleep(2)
            elseif password == confirm then
                if api.register(username,password) then
                    term.setCursorPos(2,14)
                    term.setTextColor(colors.brown)
                    term.clearLine()
                    term.setCursorPos(2,14)
                    write("Account created!")
                    sleep(2)
                else
                    term.setCursorPos(2,14)
                    term.setTextColor(colors.brown)
                    term.clearLine()
                    term.setCursorPos(2,14)
                    write("Username in use.")
                    sleep(2)
                end
            else
                term.setCursorPos(2,14)
                term.setTextColor(colors.brown)
                term.clearLine()
                term.setCursorPos(2,14)
                write("Passwords must match.")
                sleep(2)
            end
        end
    end
    autologin = false
end
