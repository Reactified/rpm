-- Forceload Non-Command Server
os.loadAPI("apis/ccash.lua")
os.loadAPI("apis/sha256.lua")
rednet.open("right") -- THIS SHOULD ONLY BE A WIRED MODEM
local networkModem = peripheral.wrap("left") -- THIS SHOULD BE A WIRELESS MODEM
local networkChannel = 36721 -- CHANNEL FOR WIRELESS NETWORKING

-- Persistent Data
local datafile = "data/chunkload.dat"
local data = {
    users = {},
    shopAccountName = "Chunkload",
    shopAccountPass = "Test",
    dailyChunkCost = 8,
}

local function saveData()
    if type(data) ~= "table" then
        error("Twix check failed.")
    end
    local f = fs.open(datafile,"w")
    f.writeLine(textutils.serialise(data))
    f.close()
end

if fs.exists(datafile) then
    local f = fs.open(datafile,"r")
    data = textutils.unserialise(f.readAll())
    f.close()
else
    -- First time setup
    print("first time setup")
    print("-----------------------")
    print("enter shop account name")
    data.shopAccountName = read()
    print("enter shop account password")
    data.shopAccountPass = read("*")
    print("enter target fund name")
    data.shopVaultName = read()
    print("enter daily chunk cost")
    data.dailyChunkCost = tonumber(read())
    ccash.user(data.shopAccountName,data.shopAccountPass)
    saveData()
end

-- Command Interface Functions
local function loadChunk(chunkX,chunkY)
    rednet.broadcast({
        chunkloader = true,
        command = "load",
        chunkX = chunkX,
        chunkY = chunkY,
    })
    local id,cmd = rednet.receive(1)
    return cmd
end
local function unloadChunk(chunkX,chunkY)
    rednet.broadcast({
        chunkloader = true,
        command = "unload",
        chunkX = chunkX,
        chunkY = chunkY,
    })
    local id,cmd = rednet.receive(1)
    return cmd
end
local function listLoadedChunks()
    rednet.broadcast({
        chunkloader = true,
        command = "list",
    })
    local id,cmd = rednet.receive(1)
    return cmd
end

-- Chunk Management System
local function recalculateChunks()
    for i,v in pairs(data.users) do
        
    end
end

-- Chunk ID Function
local function getID(chunkX,chunkY)
    return tostring(chunkX)..","..tostring(chunkY)
end

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
                return r,m
            end
        end
    end
end

-- Network Security Functions
local activeTokens = {}
local function getToken()
    local token = math.random(1,99999999)
    activeTokens[token] = true
    return token
end
local function verifyToken(token)
    if activeTokens[token] then
        activeTokens[token] = nil
        return true
    else
        return false
    end
end
local function getSignature(hash, token)
    return sha256.sha256(hash .. tostring(token))
end
local function authenticate(user, signature, token)
    if not data.users[user] then
        return false, "Invalid user"
    end

    if not verifyToken(token) then
        return false, "Invalid token"
    end

    if getSignature(data.users[user].hash, token) == signature then
        return true, "Accepted"
    else
        return false,"Denied"
    end
end

-- Credit Functions
local function takeCredits(user, amount)
    if data.users[user].credits >= amount then
        data.users[user].credits = data.users[user].credits - amount
        return true
    else
        return false
    end
end
local function addCredits(user, amount)
    data.users[user].credits = data.users[user].credits + amount
end

-- Routine
local serverFunctions = {
    ["GET_TOKEN"] = function()
        return getToken()
    end,
    ["REGISTER"] = function(params)
        if type(params) == "table" then
            local user, hash = params[1], params[2]
            
            if type(user) ~= "string" or #user > 20 or #user < 1 then
                return false,"Bad username"
            end

            if data.users[user] then
                return false,"User taken"
            end

            data.users[user] = {
                hash = hash,
                chunks = {},
                credits = 0,
            }
            saveData()
            return true
        end
    end,
    ["VERIFY"] = function(params)
        if type(params) == "table" then
            local user, signature, token = params[1], params[2], params[3]

            local ok, err = authenticate(user, signature, token)
            return ok
        end
    end,
    ["USER_DATA"] = function(params)
        if type(data) == "table" then
            local user, signature, token = params[1], params[2], params[3]

            local ok, err = authenticate(user, signature, token)
            if not ok then
                return err
            end

            -- security checks passed
            local userdata = {}
            for i,v in pairs(data.users[user]) do
                if i ~= "hash" then
                    userdata[i] = v
                end
            end

            return userdata
        end
    end,
    ["CHUNK"] = function(params)
        if type(data) == "table" then
            local user, signature, token, chunkX, chunkY, command = params[1], params[2], params[3], params[4], params[5], params[6]

            local ok, err = authenticate(user, signature, token)
            if not ok then
                return err
            end

            -- security checks passed
            if command == "load" then
                if not data.users[user].chunks[getID(chunkX,chunkY)] then
                    if takeCredits(user, data.dailyChunkCost) then
                        data.users[user].chunks[getID(chunkX,chunkY)] = true
                        loadChunk(chunkX,chunkY)
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            elseif command == "unload" then
                if data.users[user].chunks[getID(chunkX,chunkY)] then
                    data.users[user].chunks[getID(chunkX,chunkY)] = nil
                    unloadChunk(chunkX,chunkY)
                    return true
                else
                    return false
                end
            else
                print(command)
                return "no protocol"
            end
        end
    end,
    ["DEPOSIT"] = function()
        local bal = ccash.simple.balance(data.shopAccountName)
        if bal > 0 then
            local _,log = ccash.log(data.shopAccountName,data.shopAccountPass)
            ccash.simple.send(data.shopAccountName,data.shopAccountPass,data.shopVaultName,bal)
            local target = log[1].from
            addCredits(target,bal)
            return true
        else
            return false
        end
    end,
}

local function networkRoutine()
    while true do
        local id,cmd = networkRecv()
        if type(cmd) == "table" and cmd.chunkloader then
            if serverFunctions[cmd.request] then
                print(cmd.request)
                local result = serverFunctions[cmd.request](cmd.data)
                networkSend(id, "RESPONSE", result)
            end
        end
    end
end

local function timingRoutine()
    while true do
        local day = os.epoch("utc")/86400000
        local dayPercent = 1-(day-math.floor(day))
        sleep(dayPercent*86400)
        print("-- PAYMENT TIMER --")
        -- this code will run once a day at UTC midnight
        for username,userdata in pairs(data.users) do
            for chunk_id,chunkdata in pairs(userdata.chunks) do
                local bal = data.users[username].credits
                if bal >= data.dailyChunkCost then
                    print("CHARGED "..username.." FOR "..chunk_id)
                    data.users[username].credits = bal - data.dailyChunkCost
                else
                    print("UNLOADED; INSUFFICIENT FUNDS "..username.." FOR "..chunk_id)
                    data.users[username].chunks[chunk_id] = nil
                    local chunkX = tonumber(string.sub(chunk_id,1,string.find(chunk_id,",")-1))
                    local chunkY = tonumber(string.sub(chunk_id,string.find(chunk_id,",")+1,#chunk_id))
                    print(chunkX,chunkY)
                    unloadChunk(chunkX,chunkY)
                end
            end
        end
    end
end

parallel.waitForAny(networkRoutine,timingRoutine)
