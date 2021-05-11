--[[

    KRYPT API | REACTIFIED

    authenticate (channel)            Pair with a krypt mainframe (bool success)
    control (node, interface, value)  Set the interface of the given node to value
    fetch ()                          Get data from the network (bool success, table nodes, table data)

]]

-- Data Persistence
local dataFile = "/data/krypt"
local data = {
    chan = 0,
    nodes = {},
    map = {},
    drawMap = {},
}
local initRun = true

local function saveData()
    f = fs.open(dataFile,"w")
    f.writeLine(textutils.serialise(data))
    f.close()
end
if fs.exists(dataFile) then
    initRun = false
    f = fs.open(dataFile,"r")
    data = textutils.unserialise(f.readAll())
    f.close()
end

--/ Networking /--
local modem = peripheral.find("modem")
function send(msg)
    modem.transmit(data.chan/76,os.getComputerID(),{
        integrity = data.chan*#textutils.serialise(msg),
        krypt = true,
        data = msg,
        target = 65535,
    })
end
function recv(timeout)
    local filter = 65535
    local timeoutTmr
    if timeout then
        timeoutTmr = os.startTimer(timeout)
    end
    while true do
        local e,s,c,r,m = os.pullEvent()
        if e == "modem_message" and c == data.chan/76 and type(m) == "table" and m.krypt then
            if r == filter or not filter and (m.target == os.getComputerID() or m.target == true) and m.integrity == data.chan*#textutils.serialise(m.data) then
                return m.data
            end
        elseif e == "timer" then
            if s == timeoutTmr then
                return false
            end
        end
    end
end

-- Functions
function authenticate(channel)
    data.chan = channel
    modem.open(data.chan/76)

    send("[REMOTE-PAIRING]")
    local msg = recv(1)
    if msg == "[REMOTE-PAIRED]" then
        saveData()
        return true
    else
        return false
    end
end

function fetch()
    send("[REMOTE-DATA-REQUEST]")
    msg = recv(1)
    if type(msg) == "table" then
        return true,msg[2],msg[1]
    else
        return false
    end
end

function control(node,attrib,value)
    send({command = "[REMOTE-IO-CHANGE]",params={node,attrib,value}})
end
