-- Forceload Command Server
rednet.open("back") -- THIS SHOULD ONLY BE A WIRED MODEM

-- Persistent Data
local forceloaded = {}
local function saveData()
    local f = fs.open("/forceloaded","w")
    f.writeLine(textutils.serialise(forceloaded))
    f.close()
end
if fs.exists("/forceloaded") then
    local f = fs.open("/forceloaded","r")
    forceloaded = textutils.unserialise(f.readAll())
    f.close()
else
    saveData()
end

-- Chunk ID Function
local function getID(chunkX,chunkY)
    return tostring(chunkX)..","..tostring(chunkY)
end
local function splitID(chunkID)
    local chunkX = tonumber(string.sub(chunkID,1,string.find(chunkID,",")-1))
    local chunkY = tonumber(string.sub(chunkID,string.find(chunkID,",")+1,#chunkID))
    return chunkX, chunkY
end

-- Command Functions
local function loadChunk(chunkX,chunkY)
    local chunkID = getID(chunkX,chunkY)
    forceloaded[chunkID] = 0
    exec("forceload add "..tostring(chunkX*16).." "..tostring(chunkY*16))
    saveData()
    return true
end
local function unloadChunk(chunkX,chunkY)
    local chunkID = getID(chunkX,chunkY)
    forceloaded[chunkID] = nil
    exec("forceload remove "..tostring(chunkX*16).." "..tostring(chunkY*16))
    saveData()
    return true
end

-- Chunk Days
local function addChunkDays(chunkX,chunkY,days)
    local chunkID = getID(chunkX,chunkY)
    if forceloaded[chunkID] then
        forceloaded[chunkID] = forceloaded[chunkID] + days
        saveData()
    else
        loadChunk(chunkX,chunkY)
        forceloaded[chunkID] = days
        saveData()
    end
end

-- Routine
term.clear()
term.setCursorPos(1,1)
print("CHUNKLOADER COMMAND SERVER")

local function rednetRoutine()
    while true do
        local id,cmd = rednet.receive()
        if type(cmd) == "table" and cmd.chunkloader then
            if cmd.command == "add" then
                if type(cmd.chunkX) == "number" and type(cmd.chunkY) == "number" and type(cmd.days) == "number" then
                    print("ADD: ",cmd.chunkX,cmd.chunkY,cmd.days)
                    addChunkDays(cmd.chunkX,cmd.chunkY,cmd.days)
                    rednet.send(id,true)
                end
            elseif cmd.command == "list" then
                rednet.send(id,forceloaded)
            end
        end
    end
end

local function chunkTimer()
    while true do
        local day = os.epoch("utc")/86400000
        local dayPercent = 1-(day-math.floor(day))
        sleep(dayPercent*86400)

        -- this code will run once a day at UTC midnight
        print("CHUNK TIMER")
        for chunkID,daysLeft in pairs(forceloaded) do
            forceloaded[chunkID] = daysLeft - 1
            if forceloaded[chunkID] <= 0 then
                local chunkX,chunkY = splitID(chunkID)
                print("EXPIRED: ",chunkX,chunkY)
                unloadChunk(chunkX,chunkY)
            end
        end
        saveData()
    end
end

parallel.waitForAny(chunkTimer, rednetRoutine) -- start both functions
