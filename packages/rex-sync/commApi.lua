ip = "0.0.0.0"
port = "0000"

function setAddress(_ip, _port)
    ip = _ip
    port = _port
end

local fetchInterval = 5

local function httpRequest(rawQuery)
    local query = ""
    for i=1,#rawQuery do
        local char = string.sub(rawQuery,i,i)
        query = query .. string.byte(char)
        if i ~= #rawQuery then
            query = query .. "-"
        end
    end

    local stream = http.get("http://"..ip..":"..port.."/"..query,headers)
    if stream then
        local data = stream.readAll()
        stream.close()
        if data then
            return data
        end
    end
    return ""
end

function sendString(rawQuery)
    query = rawQuery .. "</" .. "end>"
    idTag = "<" .. os.getComputerID() .. ">"
    maxLength = 50 - #idTag 
    n = string.len(query)
    pn = math.ceil(n / maxLength)
    returnData = ""
    for i = 1, pn do
        part = string.sub(query, maxLength*(i-1) + 1, maxLength*i)
        returnData = httpRequest(idTag .. part)
    end
    return returnData
end

function receiveString(async)
    while true do
        local receivedData = sendString("[receive" .. "Data]")
        if #receivedData > 0 then
            return receivedData
        elseif async then
            return false
        end
        sleep(fetchInterval)
    end
end
