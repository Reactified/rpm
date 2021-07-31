-- CCash Exchange Backend
local reserveAccount = "Reserve"
local reservePassword = "RESERVE_PASSWORD_HERE"
local reserveMaximum = 100000
local commodity = "minecraft:coal"

-- Backend Routine
os.pullEvent = os.pullEventRaw
local version = 2
local function backend()

    -- Load API
    os.loadAPI("apis/ccash.lua")
    local api = _G["ccash"]

    -- Networking
    local modem = peripheral.wrap("top") -- WIRED MODEM THAT SHOULD ONLY CONNECT TO FRONTEND
    local port = 8192 -- COMMUNCATION PORT, THIS DOESN'T MATTER MUCH BUT MUST MATCH FRONTEND

    modem.open(port)

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
                print("<< "..tostring(m))
                return m
            end
        end
    end

    local function send(packet)
        modem.transmit(port, port, packet)
        print(">> "..tostring(packet))
    end

    -- Economy
    function exchangeRate()
        return 10
    end

    -- Routine
    local depositAmount = 0
    while true do

        local cmd = recv()

        if cmd == "[PING]" then
            send("[PONG]")
        elseif cmd == "[VERSION-CHECK]" then
            send(version)
        elseif cmd == "[ONLINE-CHECK]" then
            if api.simple.online() then
                send("[ONLINE]")
            else
                send("[OFFLINE]")
            end
        elseif cmd == "[RESERVE-BALANCE-CHECK]" then
            send(api.simple.balance(reserveAccount))
        elseif cmd == "[RESERVE-MAXIMUM-CHECK]" then
            send(reserveMaximum)
        elseif cmd == "[EXCHANGE-RATE-CHECK]" then
            send(exchangeRate())
        elseif cmd == "[DEPOSIT-CHECK]" then
            local slot = 1
            local success = false
            while true do
                turtle.select(slot)
                if turtle.getItemCount() > 0 then
                    slot = slot + 1
                    if slot > 16 then
                        break
                    end
                else
                    turtle.suck()
                    local detail = turtle.getItemDetail()
                    local count = turtle.getItemCount()
                    if not detail then
                        send(success)
                        break
                    end
                    if detail.name == commodity then
                        success = true
                        depositAmount = depositAmount + count
                    else
                        turtle.drop()
                    end
                end
            end
        elseif cmd == "[DEPOSIT-AMOUNT]" then
            send(depositAmount)
        elseif cmd == "[DEPOSIT-RETURN]" then
            depositAmount = 0
            for i=1,16 do
                turtle.select(i)
                turtle.drop()
            end
        elseif cmd == "[DEPOSIT-CONFIRM]" then
            local exRate = exchangeRate()

            local username = recv()
            local depositValue = math.floor(depositAmount*exRate)
            local reserveBalance
            repeat
                reserveBalance = api.simple.balance(reserveAccount)
            until reserveBalance

            -- incinerate
            local incinerationCount = 0
            for i=1,16 do
                if turtle.getItemCount(i) > 0 then
                    turtle.select(i)
                    local detail = turtle.getItemDetail()
                    local count = turtle.getItemCount()
                    if detail.name == commodity then
                        incinerationCount = incinerationCount + (count * exRate)
                    end
                    if not turtle.dropDown() then
                        -- if item was somehow stolen in this tiny window of time
                        incinerationCount = incinerationCount - (count * exRate)
                    end
                end
            end

            if (depositValue ~= incinerationCount) then
                print("!! INCINERATION ERROR !!")
                print(incinerationCount)
                print(depositValue)
            end

            if reserveBalance >= depositValue and (depositValue == incinerationCount) then
                write("Attempting deposit... ")
                local success = api.simple.send(reserveAccount, reservePassword, username, depositValue)
                print(success)
                if success then
                    send(true)
                    depositAmount = 0
                else
                    send(false)
                end
            else
                send(false)
            end
        end

    end

end

-- Error Handler
while true do
    ok,err = pcall(backend)
    term.setCursorPos(1,1)
    printError(err)
    sleep(5)
end
