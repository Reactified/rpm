-- Forceload Command Server
rednet.open("left") -- THIS SHOULD ONLY BE A WIRED MODEM

-- Persistently Store Loaded Chunks
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

-- Command Functions
local function loadChunk(chunkX,chunkY)
    local chunkID = getID(chunkX,chunkY)
    forceloaded[chunkID] = true
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

-- Routine
term.clear()
term.setCursorPos(1,1)
print("CHUNKLOADER MAINFRAME")
while true do
    local id,cmd = rednet.receive()
    if type(cmd) == "table" and cmd.chunkloader then
        if cmd.command == "load" then
            if type(cmd.chunkX) == "number" and type(cmd.chunkY) == "number" then
                print("LOAD: ",cmd.chunkX,cmd.chunkY)
                loadChunk(cmd.chunkX,cmd.chunkY)
                rednet.send(id,true)
            end
        elseif cmd.command == "unload" then
            if type(cmd.chunkX) == "number" and type(cmd.chunkY) == "number" then
                print("UNLOAD: ",cmd.chunkX,cmd.chunkY)
                unloadChunk(cmd.chunkX,cmd.chunkY)
                rednet.send(id,true)
            end
        elseif cmd.command == "list" then
            rednet.send(id,forceloaded)
        end
    end
end
