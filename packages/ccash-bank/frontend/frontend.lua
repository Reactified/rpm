-- CCash Exchange Frontend
local cname = "CCash"
local ticker = "CSH"
local commodity = "Coal"
local showReserve = true

-- Frontend Routine
os.pullEvent = os.pullEventRaw
local version = 0.15
local function frontend()

    -- Networking
    local modem = peripheral.wrap("back") -- WIRED MODEM THAT SHOULD ONLY CONNECT TO BACKEND
    local port = 8192 -- COMMUNCATION PORT, THIS DOESN'T MATTER MUCH BUT MUST MATCH BACKEND

    modem.open(port)

    local function fixedTostring(number) -- simple tostring function that rounds off floating point errors
        local str = tostring(number)
        if string.find(str,".") then
            for i=1,#str do
                if string.sub(str,#str,#str) == "0" then
                    str = string.sub(str,1,#str-1)
                end
            end
        end
        return str
    end

    local function recv(timeout)
        local timeoutTimer = false
        if timeout then
            timeoutTimer = os.startTimer(timeout)
        end
        while true do
            local e,s,c,r,m = os.pullEvent()
            if e == "timer" and s == timeoutTimer then
                return false
            elseif e == "modem_message" and c == port then
                return m
            end
        end
    end

    local function send(packet)
        modem.transmit(port, port, packet)
    end

    -- Internal Functions
    local internal = {}

    function internal.ping()
        send("[PING]")
        local cmd = recv(1)
        return (cmd == "[PONG]") or false
    end
    function internal.versionCheck()
        send("[VERSION-CHECK]")
        local cmd = recv(1)
        return cmd
    end
    function internal.online()
        send("[ONLINE-CHECK]")
        local cmd = recv(3)
        return (cmd == "[ONLINE]")
    end
    function internal.reserveBalance()
        send("[RESERVE-BALANCE-CHECK]")
        local cmd = recv(4)
        return cmd
    end
    function internal.reserveMaximum()
        send("[RESERVE-MAXIMUM-CHECK]")
        local cmd = recv(1)
        return cmd
    end
    function internal.exchangeRate()
        send("[EXCHANGE-RATE-CHECK]")
        local cmd = recv(2)
        return cmd
    end
    function internal.depositCheck()
        send("[DEPOSIT-CHECK]")
        local cmd = recv(10)
        return cmd
    end
    function internal.depositAmount()
        send("[DEPOSIT-AMOUNT]")
        local cmd = recv(1)
        return cmd
    end
    function internal.depositConfirm(username)
        send("[DEPOSIT-CONFIRM]")
        sleep(0.1)
        send(username)
        local cmd = recv(8)
        return cmd
    end

    -- UI Functions
    local w,h = term.getSize()
    term.setPaletteColor(colors.brown,1,0.8,0.2)    

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
        write("Exchange")
        term.setBackgroundColor(colors.black)
    end
    local function rightAlign(str,ln)
        term.setCursorPos(w-#str,ln)
        write(str)
    end
    local function center(str,ln)
        local w,h = term.getSize()
        term.setCursorPos((w/2)-(#str/2)+1,ln)
        write(str)
    end

    -- Meta Functions
    local function connectionCheck(quick)
        local exponentialTimeout = 1
        while true do
            drawHeader()
            term.setTextColor(colors.brown)
            center("<< Connecting >>",h/2+2)
            if not internal.ping() then
                center("! Connection Error !",h/2+2)
                term.setTextColor(colors.gray)
                center("Turtle Offline",h/2+3)
            elseif not quick and not internal.online() then
                center("! Connection Error !",h/2+2)
                term.setTextColor(colors.gray)
                center("Server Offline",h/2+3)
            else
                return true
            end
            sleep(exponentialTimeout)
            exponentialTimeout = exponentialTimeout * 2
        end
    end
    local function forceGet(func)
        while true do
            sleep()
            local val = func()
            if type(val) == "number" then
                return val
            end
        end
    end

    -- Interface
    connectionCheck()
    local serverVersion = internal.versionCheck()
    while true do
        -- Update
        local exchangeRate = forceGet(internal.exchangeRate)
        local reserveBalance = forceGet(internal.reserveBalance)
        local reserveMaximum = forceGet(internal.reserveMaximum)

        -- Base Draw
        drawHeader()
        term.setTextColor(colors.gray)
        term.setCursorPos(2,h-1)
        write("v"..fixedTostring(version).."."..fixedTostring(serverVersion))

        -- Draw
        term.setBackgroundColor(colors.brown)
        term.setTextColor(colors.gray)
        center("  Deposit  ",h-1)

        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        center("Exchange Rate",7)
        term.setTextColor(colors.brown)
        center("1 "..commodity.." = "..tostring(exchangeRate).." "..ticker,8)

        if showReserve then
            term.setTextColor(colors.gray)
            center("Reserve",10)
            term.setTextColor(colors.brown)
            center(fixedTostring(math.floor(reserveBalance/1000)).."K "..fixedTostring(math.floor((reserveBalance/reserveMaximum)*1000)/10).."%",11)
        end

        -- Events
        local e,c,x,y = os.pullEvent("mouse_click")
        if y == h-1 and x > w/2-5 and x < w/2+5 then
            -- Deposit
            drawHeader()
            term.setTextColor(colors.lightGray)
            center(" [ Deposit ] ",8)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.brown)
            center("Enter Username",11)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(w/2-w/8,12)
            write("> ")
            local username = read()
            term.setTextColor(colors.gray)
            center("Enter Username",11)
            term.setTextColor(colors.brown)
            center("Place your deposit below",h-2)
            for i=1,10 do
                local ok = internal.depositCheck()
                if ok then
                    -- Success
                    sleep(1)
                    internal.depositCheck()
                    local deposited = internal.depositAmount()
                    local depositValue = math.floor(deposited * internal.exchangeRate())

                    while true do
                        drawHeader()
                        term.setTextColor(colors.lightGray)
                        center(" [ Deposit ] ",8)

                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.gray)
                        center(tostring(deposited).." "..commodity,11)
                        term.setTextColor(colors.brown)
                        center(tostring(depositValue).." "..ticker,12)

                        if depositValue > reserveBalance then
                            term.setTextColor(colors.red)
                            center("Insufficient reserve to complete deposit.", h-3)
                        end

                        term.setBackgroundColor(colors.gray)
                        term.setTextColor(colors.white)
                        term.setCursorPos(w/2-w/6,h-1)
                        write(" Return ")
                        term.setBackgroundColor(colors.black)
                        write(" ")
                        term.setBackgroundColor(colors.brown)
                        term.setTextColor(colors.gray)
                        write(" Deposit ")

                        local e,c,x,y = os.pullEvent("mouse_click")
                        if y == h-1 then
                            if x < w/2 then
                                send("[DEPOSIT-RETURN]")
                                drawHeader()
                                term.setTextColor(colors.brown)
                                center("Retrieve your deposit",h/2+2)
                                break
                            elseif x > w/2 then
                                drawHeader()
                                local success = internal.depositConfirm(username)
                                term.setTextColor(colors.brown)
                                if success then
                                    center("Deposit confirmed.",h/2+2)
                                    center("+ "..tostring(depositValue),h/2+3)
                                    sleep(3)
                                    break
                                else
                                    center("Deposit failed.",h/2+2)
                                    sleep(3)
                                end
                            end
                        end
                    end

                    break
                end
                sleep(1)
            end
        end
    end

end

-- Error Handler
while true do
    ok,err = pcall(frontend)
    term.setCursorPos(1,1)
    printError(err)
    sleep(5)
end
