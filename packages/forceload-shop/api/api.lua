-- Forceload API
os.loadAPI("apis/sha256.lua")
local networkModem = peripheral.find("modem") -- THIS SHOULD BE A WIRELESS MODEM
local networkChannel = 36721 -- CHANNEL FOR WIRELESS NETWORKING
local server = 4 -- ID OF THE SERVER

-- Networking Functions
local id = os.getComputerID()
local function networkSend(idTarget,request,data)
    networkModem.transmit(networkChannel,id,{
        chunkloader = true,
        request = request,
        target = idTarget,
        data = data,
    })
end
local function networkRecv(idFilter,timeout)
    networkModem.open(networkChannel)
    local timeoutTimer
    if timeout then
        timeoutTimer = os.startTimer(timeout)
    end
    while true do
        local e,s,c,r,m = os.pullEvent()
        if e == "timer" and s == timeoutTimer then
            networkModem.close(networkChannel)
            return
        elseif e == "modem_message" and c == networkChannel then
            if not idFilter or r == idFilter and type(m) == "table" and m.target == id then
                networkModem.close(networkChannel)
                if r == server and m.chunkloader then
                    return m.data
                end
            end
        end
    end
end

-- Security Signature
local function getSignature(hash, token)
    return sha256.sha256(hash .. tostring(token))
end

-- Internal API Functions
local function get_token()
    networkSend(server,"GET_TOKEN")
    return networkRecv(server,1)
end

local function chunk(user, pass, chunkX, chunkY, command)
    local hash = sha256.sha256(pass)
    local token = get_token()
    local signature = getSignature(hash,token)
    networkSend(server,"CHUNK",{user,signature,token,chunkX,chunkY,command})
    return networkRecv(server,1)
end

-- Exposed API Functions
function register(user, pass)
    local hash = sha256.sha256(pass)
    networkSend(server,"REGISTER",{user,hash})
    return networkRecv(server,1)
end

function verify(user, pass)
    local hash = sha256.sha256(pass)
    local token = get_token()
    local signature = getSignature(hash,token)
    networkSend(server,"VERIFY",{user,signature,token})
    return networkRecv(server,1)
end

function user_data(user, pass)
    local hash = sha256.sha256(pass)
    local token = get_token()
    local signature = getSignature(hash,token)
    networkSend(server,"USER_DATA",{user,signature,token})
    return networkRecv(server,1)
end

function load_chunk(user, pass, chunkX, chunkY)
    return chunk(user, pass, chunkX, chunkY, "load")
end

function unload_chunk(user, pass, chunkX, chunkY)
    return chunk(user, pass, chunkX, chunkY, "unload")
end

function deposit()
    networkSend(server,"DEPOSIT")
end
