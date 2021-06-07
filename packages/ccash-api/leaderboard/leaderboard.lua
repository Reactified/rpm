local channel = 1984
local modem = peripheral.find("modem")

local function send(id, str)
    modem.transmit(channel, os.getComputerID(), {
        target = id,
        message = str,
    })
end
local function recv(timeout, idFilter)
    modem.open(channel)
    local tmr
    if timeout then
        tmr = os.startTimer(timeout)
    end
    while true do
        local e,s,c,r,m = os.pullEvent()
        if e == "timer" and s == tmr then
            return false
        elseif e == "modem_message" then
            if c == channel and type(m) == "table" then
                if m.target == os.getComputerID() then
                    if not idFilter then
                        return r,m.message
                    elseif idFilter and r == idFilter then
                        return r,m.message
                    end
                end
            end
        end
    end
    modem.close(channel)
end

local server = 239
function leaderboard()
    if peripheral.find("modem") then
        send(server,"[LEADERBOARD-REQUEST]")
        local id,cmd = recv(1,server)
        return cmd or {}
    else
        return {}
    end
end

function submit(username)
    if peripheral.find("modem") then
        send(server,{
            command = "LEADERBOARD-SUBMISSION",
            user = username,
        })
    end
end
