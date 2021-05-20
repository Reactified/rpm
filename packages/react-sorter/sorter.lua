-- REACT INDUSTRIES Sorting System
local configFile = "config"

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

local function moveItem(fromChestID,fromSlot,toChestID,toSlot,quantity)
    if chests[fromChestID] and chests[toChestID] then
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

local function indexAllChests(recheckCapacity)
    local peripheralList = peripheral.getNames()
    for peripheralListIndex, peripheralName in pairs(peripheralList) do
        local underscorePosition = string.find(peripheralName,"_")

        local networkID = -1
        local shortName = peripheralName
        if underscorePosition then
            networkID = tonumber(string.sub(peripheralName,underscorePosition+1,#peripheralName))
            shortName = string.sub(peripheralName,1,underscorePosition-1)
        end
        if config.core.storageTypes[shortName] then
            chests[networkID] = peripheral.wrap(peripheralName)
            if not chests[networkID].capacity or recheckCapacity then
                chests[networkID].capacity = chests[networkID].size()
            end
            chests[networkID].contents = chests[networkID].list()
        end
    end
end

local function getChestType(id)
    local markerItem = readChestItem(id, chests[id].capacity)
    if markerItem then
        return config.markers[genID(markerItem)] or genID(markerItem)
    else
        return "empty"
    end
end

local function placeInChest(fromChestID,fromSlot,chestID,count)
    local v = chests[chestID]
    local initCount = count
    for i=1,v.capacity-1 do
        local tItem = readChestItem(chestID,i)
        if not tItem or (genID(tItem) == itemId and tItem.count < 64) then
            local moved = moveItem(fromChestID,fromSlot,chestID,i,count)
            count = count - moved
            if count <= 0 then
                return moved
            end
        end
    end
    return initCount - count
end

local function depositItem(chestID,slotID)
    local itemData = readChestItem(chestID,slotID)
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
end

-- Storage Routine
local maxCountCache = {}
local resourceChests = {}
local cycle = 0
while true do
    -- Loop code
    print("Loop #"..tostring(cycle))
    startTimer("FULL LOOP")

    -- Index all chests
    startTimer("INDEXING CHESTS")
    indexAllChests(cycle % config.performance.cyclesPerCapacityCheck == 0)
    stopTimer("INDEXING CHESTS")

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
    print("---------------")
end
