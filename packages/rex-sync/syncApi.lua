os.loadAPI("RSync/commApi.lua")

path = "RSync/.sync-settings"
t = {}
function saveData()
    f = fs.open(path, "w")
    f.write(textutils.serialise(t))
    f.close()
end
function loadData()
    f = nil
    if fs.exists(path) then
        f = fs.open(path, "r")
    else
        t["address"] = "http://0.0.0.0:8000"
        saveData()
        f = fs.open(path, "r")
    end
    t = textutils.unserialize(f.readAll())
end
loadData()

api = commApi
api.setAddress(t["address"])

function getFile(filename)
    api.sendString("[Download]" .. filename)
    data = api.receiveString()
    f = fs.open(filename, "w")
    f.writeLine(data)
    f.close()
end

function mysplit (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function getFilesList()
    api.sendString("[List]")
    data = api.receiveString(true)
    if data ~= false then
        return mysplit(data, ",")
    end
    return {}
end

function getAllFiles()
    getFiles = getFilesList()
    for i, v in pairs(getFiles) do
        --print("Getting: " .. v)
    end
    for i, v in pairs(getFiles) do
        getFile(v)
        sleep()
    end
end

function sendFile(filename)
    api.sendString("[Upload]" .. filename)
    f = fs.open(filename, "r")
    api.sendString(f.readAll())
end

local allFiles = {}
function explorePath(path)
    local fileList = fs.list(path)
    for i,v in pairs(fileList) do
        local file = path..v
        if fs.isDir(file) then
            if not fs.isReadOnly(file) then
                explorePath(file.."/")
            end
        else
            table.insert(allFiles, string.sub(file,2,#file))
        end
    end
end
function getLocalFiles()
    allFiles = {}
    explorePath("/")
    return allFiles
end

function sendAllFiles()
    sendFiles = getLocalFiles()
    for i, v in pairs(sendFiles) do
        --print("Sending: " .. v)
    end
    for i, v in pairs(sendFiles) do
        sendFile(v)
        sleep()
    end
end

function registerComputer()
        api.sendString("[Register]" .. os.getComputerLabel())
end

function clearMessages()
    continue = true
    while continue do
        --print("Clearing Messages")
        if api.receiveString(true) == false then
            continue = false
        end
    end
    --print("Messages Cleared")
end
 


registerComputer()



clearMessages()
