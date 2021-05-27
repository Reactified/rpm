-- REACT INDUSTRIES Sorting API
local networkModem = peripheral.find("modem")
local networkChannel = 18245
local networkID = os.getComputerID()

local function networkSend(id,str)
    networkModem.transmit(networkChannel, networkID, {
        sorter = true,
        target = id,
        message = str,
    })
end
local function networkReceive(filter)
    networkModem.open(networkChannel)
    local timeoutTimer = os.startTimer(3)
    while true do
        local e,s,c,r,m = os.pullEvent()
        if e == "modem_message" then
            if type(m) == "table" and m.sorter then
                -- protocol valid
                local messageTarget, messageContent = m.target, m.message
                if not ((filter and r ~= filter) or (messageTarget ~= networkID)) then
                    return r, messageContent
                end
            end
        elseif e == "timer" and s == timeoutTimer then
            return false,false
        end
    end
    networkModem.close(networkChannel)
end

-- API Functions
function inventory() -- Get content data from all chests
    networkSend(0,{command="storage-inventory"})
    local id,data = networkReceive(0)
    return data
end

function totals() -- Get the total amount of each item
    networkSend(0,{command="storage-totals"})
    local id,data = networkReceive(0)
    return data
end

function unmanageChest(id) -- Stop sorting this chest
    networkSend(0,{command="unmanage-chest",chest=id})
end

function manageChest(id) -- Start sorting this chest
    networkSend(0,{command="manage-chest",chest=id})
end

function clearChest(id) -- Empty all of the chests items
    networkSend(0,{command="clear-chest",chest=id})
end

function fillChest(id, item, count) -- Fill the given chest with some amount of an item
    networkSend(0,{command="fill-chest",chest=id,item=item,count=count})
end
