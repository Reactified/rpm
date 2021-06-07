-- REACT INDUSTRIES Sorting System
local configFile = "config/sorter.cfg"

-- Load Configuration
local f = fs.open(configFile,"r")
local config = {}
if f then
    config = textutils.unserialise(f.readAll())
    f.close()
else
    printError("Config file missing")
    return
end

-- Core Functions
local function genID(metadata)
    if not metadata then
        return false
    end
    return metadata.name
end

-- Timing Functions
local timers = {}
local function startTimer(str)
    timers[str] = os.epoch("utc")
end
local function stopTimer(str)
    print(str..": "..tostring(os.epoch("utc")-timers[str]).."ms")
end

-- Storage Functions
local chests = {}
local unmanagedChests = {}

local function moveItem(fromChestID,fromSlot,toChestID,toSlot,quantity)
    if chests[fromChestID] and chests[toChestID] then
        local oldItem
        if chests[fromChestID] and chests[fromChestID].contents and chests[fromChestID].contents[fromSlot] then
            oldItem = chests[fromChestID].contents[fromSlot]
            chests[fromChestID].contents[fromSlot] = nil
        end
        if (chests[toChestID] and chests[toChestID].contents and chests[toChestID].contents[toSlot] == nil) and not (toSlot == nil) then
            chests[toChestID].contents[toSlot] = oldItem
        end
        return chests[fromChestID].pushItems(peripheral.getName(chests[toChestID]),fromSlot,quantity,toSlot)
    else
        return 0
    end
end

local function readChestItem(chestID,slotID)
    if not chests[chestID] or type(chests[chestID].contents) ~= "table" then
        return false
    end
    return chests[chestID].contents[slotID]
end

local function updateContents(networkID)
    chests[networkID].contents = chests[networkID].list()
end

local function indexAllChests(recheckCapacity)
    local peripheralList = peripheral.getNames()
    for peripheralListIndex, peripheralName in pairs(peripheralList) do
        local networkID = -1
        local shortName = peripheralName
        
        while true do
            local underscorePosition = string.find(shortName,"_")
            if underscorePosition then
                networkID = tonumber(string.sub(shortName,underscorePosition+1,#peripheralName))
                shortName = string.sub(peripheralName,1,underscorePosition-1)
            else
                break
            end
        end
        if config.core.storageTypes[shortName] then
            local oldCapacity
            if chests[networkID] then
                oldCapacity = chests[networkID].capacity
            end
            chests[networkID] = peripheral.wrap(peripheralName)
            if oldCapacity then
                chests[networkID].capacity = oldCapacity
            end
            if not chests[networkID].capacity or recheckCapacity then
                chests[networkID].capacity = chests[networkID].size()
            end
            updateContents(networkID)
        end
        write(".")
    end
    print()
end

local function getChestType(id)
    local markerItem = readChestItem(id, chests[id].capacity)
    if unmanagedChests[id] then
        return "unmanaged"
    elseif markerItem then
        return config.markers[genID(markerItem)] or genID(markerItem)
    else
        return "empty"
    end
end

local fullChests = {}
local function placeInChest(fromChestID,fromSlot,chestID,count)
    if fullChests[chestID] then
        return 0
    end
    local movedItems = moveItem(fromChestID,fromSlot,chestID,nil,count)
    if movedItems <= 0 then
        fullChests[chestID] = true
    end
    return movedItems
end

local function depositItem(chestID,slotID)
    local itemData = readChestItem(chestID,slotID)
    if itemData then
        local itemId = genID(itemData)
        local count = itemData.count

        -- Deposit in item-specific chest first
        for targetChestID,v in pairs(chests) do
            if v.type == itemId then
                count = count - placeInChest(chestID,slotID,targetChestID,count)
                if count <= 0 then
                    return true
                end
            end
        end

        -- Deposit in misc chest as a fallback
        for targetChestID,v in pairs(chests) do
            if v.type == "misc" then
                count = count - placeInChest(chestID,slotID,targetChestID,count)
                if count <= 0 then
                    return true
                end
            end
        end

        print("MISC CHESTS FULL")
    end
end

local function locateItem(id, exclude)
    for i,v in pairs(chests) do
        if i ~= exclude then
            if v.contents then
                for k,z in pairs(v.contents) do
                    if type(z) == "table" and z.name then
                        if genID(z) == id then
                            return i, k
                        end
                    end
                end
            end
        end
    end
end

local function fillChest(chest, item, count)
    for i=1,1000 do
        local chestId,slotId = locateItem(item, chest)
        if not chestId or not slotId then
            return
        end
        local slotCount = chests[chestId].contents[slotId].count
        if slotCount > count then
            slotCount = count
        end
        count = count - placeInChest(chestId,slotId,chest,slotCount)
        if count <= 0 then
            return true
        end
    end
end

-- Display Name Cache
local displayNames = {}
local function getDisplayName(id)
    if displayNames[id] then
        return displayNames[id]
    end
    local chestId, chestSlot = locateItem(id)
    if chestId then
        local detail = chests[chestId].getItemDetail(chestSlot)
        if detail then
            local displayName = detail.displayName
            displayNames[id] = displayName
            return displayName
        end
    else
        printError("Could not get ",id)
        return false
    end
end

local function translateFromDisplayName(name)
    for i,v in pairs(displayNames) do
        if v == name then
            return i
        end
    end
    return name
end

-- Storage Routine
local function storageRoutine()
    local maxCountCache = {}
    local resourceChests = {}
    local cycle = 0
    while true do
        -- Loop code
        startTimer("FULL LOOP")

        -- Index all chests
        startTimer("INDEXING CHESTS")
        indexAllChests(cycle % config.performance.cyclesPerCapacityCheck == 0)
        stopTimer("INDEXING CHESTS")

        -- Get display names
        startTimer("GET DISPLAY NAMES")
        for i,v in pairs(chests) do
            if v.contents then
                for k,z in pairs(v.contents) do
                    if type(z) == "table" and z.name then
                        getDisplayName(genID(z))
                    end
                end
            end
        end
        stopTimer("GET DISPLAY NAMES")

        -- Chest classification
        startTimer("CHEST CLASSIFICATION")
        resourceChests = {}
        for i,v in pairs(chests) do
            local chestType = getChestType(i)
            chests[i].type = chestType
            resourceChests[chestType] = true
        end
        stopTimer("CHEST CLASSIFICATION")

        -- Empty chest clearing
        startTimer("DROP CHEST CLEARING")
        for i,v in pairs(chests) do
            if v.type == "empty" then
                if type(v.contents) == "table" then
                    for k,z in pairs(v.contents) do
                        if k ~= v.capacity then
                            depositItem(i,k)
                        end
                    end
                end
            end
        end
        stopTimer("DROP CHEST CLEARING")

        -- Resource chest cleanup
        startTimer("RESOURCE CHEST REALLOCATION")
        for i,v in pairs(chests) do
            if string.find(v.type,":") then
                if type(v.contents) == "table" then
                    for k,z in pairs(v.contents) do
                        if k ~= v.capacity then
                            if z and genID(z) ~= v.type then
                                depositItem(i,k)
                            end
                        end
                    end
                end
            end
        end
        stopTimer("RESOURCE CHEST REALLOCATION")

        -- Misc chest reallocation
        startTimer("MISC CHEST REALLOCATION")
        for i,v in pairs(chests) do
            if v.type == "misc" then
                if type(v.contents) == "table" then
                    for k,z in pairs(v.contents) do
                        if k ~= v.capacity then
                            if resourceChests[genID(z)] then
                                depositItem(i,k)
                            end
                        end
                    end
                end
            end
        end
        stopTimer("MISC CHEST REALLOCATION")

        -- Resource balancing
        startTimer("RESOURCE BALANCING")

        local resourceCount = {}
        local resourceChestCount = {}
        local resourceChests = {}
        for i,v in pairs(chests) do -- count resources
            if string.find(v.type,":") then
                if type(v.contents) == "table" then
                    if not resourceChests[v.type] then
                        resourceChests[v.type] = {}
                    end
                    table.insert(resourceChests[v.type],i)
                    for k,z in pairs(v.contents) do
                        if k ~= v.capacity then
                            if z and genID(z) == v.type then
                                if not resourceCount[v.type] then
                                    resourceCount[v.type] = 0
                                end
                                if not resourceChestCount[i] then
                                    resourceChestCount[i] = 0
                                end
                                resourceCount[v.type] = resourceCount[v.type] + z.count
                                resourceChestCount[i] = resourceChestCount[i] + z.count
                            end
                        end
                    end
                end
            end
        end

        local redistributionValues = {}
        for resource, chestList in pairs(resourceChests) do
            for chestIndex, chestId in pairs(chestList) do
                if chests[chestId] and resourceCount[resource] then
                    local targetAmount = resourceCount[resource]/#resourceChests[resource]
                    if not maxCountCache[resource] then
                        maxCountCache[resource] = chests[chestId].getItemDetail(chests[chestId].capacity).maxCount
                    end
                    if targetAmount > ((chests[chestId].capacity-1)*maxCountCache[resource]) then
                        targetAmount = ((chests[chestId].capacity-1)*maxCountCache[resource])
                    end
                    redistributionValues[chestId] = math.floor(targetAmount - (resourceChestCount[chestId] or 0))
                end
            end
        end

        for toChestId,toChestAmount in pairs(redistributionValues) do
            if toChestAmount > 0 then
                local amountToFill = toChestAmount
                for fromChestId,fromChestAmount in pairs(redistributionValues) do
                    if fromChestAmount < 0 then
                        for i=1,chests[fromChestId].capacity-1 do
                            if readChestItem(fromChestId,i) then
                                amountToFill = amountToFill - chests[fromChestId].pushItems(peripheral.getName(chests[toChestId]),i,amountToFill)
                                if amountToFill <= 0.5 then
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        
        stopTimer("RESOURCE BALANCING")

        -- Wait
        cycle = cycle + 1
        stopTimer("FULL LOOP")
    end
end

-- Network Routine
local networkModem = peripheral.find("modem")
local networkChannel = 18245
local networkID = 0

local function networkSend(id,str)
    networkModem.transmit(networkChannel, networkID, {
        sorter = true,
        target = id,
        message = str,
    })
end
local function networkReceive(filter)
    networkModem.open(networkChannel)
    while true do
        local e,s,c,r,m = os.pullEvent("modem_message")
        if type(m) == "table" and m.sorter then
            -- protocol valid
            local messageTarget, messageContent = m.target, m.message
            if not ((filter and r ~= filter) or (messageTarget ~= networkID)) then
                return r, messageContent
            end
        end
    end
    networkModem.close(networkChannel)
end

local function networkRoutine()
    while true do
        local id, message = networkReceive()
        if type(message) == "table" then
            local cmd = message.command
            if cmd == "storage-inventory" then
                -- package storage data
                local storageInventory = {}
                for i,v in pairs(chests) do
                    storageInventory[i] = v.contents
                end
                networkSend(id, storageInventory)
            elseif cmd == "storage-totals" then
                -- calculate totals
                local storageTotals = {}
                for i,v in pairs(chests) do
                    if v.contents then
                        for k,z in pairs(v.contents) do
                            if k ~= v.capacity then
                                local name = getDisplayName(genID(z))
                                if type(z) == "table" and name then
                                    if not storageTotals[name] then
                                        storageTotals[name] = 0
                                    end
                                    storageTotals[name] = storageTotals[name] + z.count
                                end
                            end
                        end
                    end
                end
                networkSend(id, storageTotals)
            elseif cmd == "unmanage-chest" then
                unmanagedChests[message.chest] = true
            elseif cmd == "manage-chest" then
                unmanagedChests[message.chest] = false
            elseif cmd == "clear-chest" then
                for k,z in pairs(chests[message.chest].list()) do
                    if k ~= chests[message.chest].capacity then
                        repeat 
                            sleep()
                        until depositItem(message.chest,k)
                    end
                end
            elseif cmd == "fill-chest" then
                local itemName = translateFromDisplayName(message.item)
                fillChest(message.chest, itemName, message.count)
            end
        end
    end
end

-- Run
parallel.waitForAll(networkRoutine,storageRoutine)
