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

-- Command Block
local function execute(command)
    if string.sub(command,1,10) == "forceload " then -- limit the use of this function, just to be safe.
        local command_block = peripheral.find("command")
        command_block.setCommand(command)
        command_block.runCommand()
    end
end

-- Epoch Time
local function epochTime()
    return os.epoch("utc")/1000
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
    forceloaded[chunkID] = epochTime()
    execute("forceload add "..tostring(chunkX*16).." "..tostring(chunkY*16))
    saveData()
    return true
end
local function unloadChunk(chunkX,chunkY)
    local chunkID = getID(chunkX,chunkY)
    forceloaded[chunkID] = nil
    execute("forceload remove "..tostring(chunkX*16).." "..tostring(chunkY*16))
    saveData()
    return true
end

-- Chunk Days
local function addChunkDays(chunkX,chunkY,days)
    local chunkID = getID(chunkX,chunkY)
    if forceloaded[chunkID] then
        forceloaded[chunkID] = forceloaded[chunkID] + (days*86400)
        saveData()
    else
        loadChunk(chunkX,chunkY)
        forceloaded[chunkID] = epochTime() + (days*86400)
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
        sleep(300)
        
        local chunkUnloaded = false
        for chunkID,daysLeft in pairs(forceloaded) do
            if forceloaded[chunkID] <= epochTime() then
                local chunkX,chunkY = splitID(chunkID)
                print("EXPIRED: ",chunkX,chunkY)
                unloadChunk(chunkX,chunkY)
                chunkUnloaded = true
            end
        end

        if chunkUnloaded then -- only save if we actually unloaded a chunk
            saveData()
        end
    end
end

parallel.waitForAny(chunkTimer, rednetRoutine) -- start both functions
