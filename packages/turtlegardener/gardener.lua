-- Auto Turtle Gardener (by Reactified)

local logFile = false
local sizeX = 9
local sizeY = 9
local waitTime = 600

-- Logging Function

local w,h = term.getSize()
local function log(str)
    if logFile then
        f = fs.open("/log","a")
        f.writeLine(str)
        f.close()
    end
    print(str)
    local curX,curY = term.getCursorPos()
    term.setCursorPos(1,1)
    write(string.rep(" ",w))
    term.setCursorPos(1,1)
    local percent = (turtle.getFuelLevel()/turtle.getFuelLimit())*100
    write("Gardener Turtle OS | Fuel: "..tostring(math.floor(percent)).."%")
    term.setCursorPos(1,2)
    write(string.rep("-",w))
    term.setCursorPos(curX,curY)
end
term.setCursorPos(1,3)

-- Saving Data

local function saveData()
    if data then
        f = fs.open("/.data","w")
        f.writeLine(textutils.serialise(data))
        f.close()
        return true
    else
        return false
    end
end

-- Recalling Data

if fs.exists("/.data") then
    f = fs.open("/.data","r")
    data = textutils.unserialise(f.readAll())
    f.close()
    log("Data loaded")
else
    data = {}
    data.x = 0
    data.y = 0
    data.f = 2
    data.z = 0
    saveData()
end

-- Sorting Inventory

local openSlot = 16
local invSlots = {
    [15] = "minecraft:wheat_seeds",
    [14] = "minecraft:sapling",
    [13] = "minecraft:bonemeal",
    [12] = "minecraft:pumpkin",
    [11] = "minecraft:melon",
    [10] = "minecraft:carrot",
    [9] = "minecraft:potato",
    [8] = "minecraft:wheat",
    [7] = "minecraft:log",
    [6] = "minecraft:reeds",
    [5] = "minecraft:coal",
}
function sortInv()
    for i=1,16 do
        local itemData = turtle.getItemDetail(i)
        if itemData then
            local destSlot = nil
            for i,v in pairs(invSlots) do
                if v == itemData.name then
                    destSlot = i
                end
            end
            if destSlot then
                if destSlot ~= i then
                    turtle.select(i)
                    turtle.transferTo(destSlot)
                end
            else
                turtle.select(i)
                turtle.drop()
            end
        end
    end
    turtle.select(1)
end
function selectItem(name)
    for i,v in pairs(invSlots) do
        if v == name then
            turtle.select(i)
        end
    end
end

-- Facing Directions

local hdg = {
    [1] = {0,-1},
    [2] = {1,0},
    [3] = {0,1},
    [4] = {-1,0},
}

-- Turtle Functions

local t = {}
for i,v in pairs(turtle) do
    t[i] = v
end
function fuelCheck()
    if turtle.getFuelLevel() <= 0 then
        log("Oh no! I'm out of fuel!")
        log("Searching for a fuel source..")
        while turtle.getFuelLevel() <= 0 do
            for i=1,16 do
                turtle.select(i)
                if turtle.refuel(4) then
                    break
                end
            end
            sleep(5)
        end
        log("Back in business!")
        turtle.select(1)
    end
end
function t.forward()
    fuelCheck()
    while true do
        if turtle.forward() then
            break
        else
            turtle.attack()
            turtle.dig()
        end
        sleep(0)
    end
    data.x = data.x + hdg[data.f][1]
    data.y = data.y + hdg[data.f][2]
    saveData()
end
function t.back()
    fuelCheck()
    while true do
        if turtle.back() then
            break
        else
            data.f = data.f + 1
            turtle.turnRight()
            data.f = data.f + 1
            turtle.turnRight()
            turtle.attack()
            while not turtle.dig() do
                sleep(30)
            end
            data.f = data.f + 1
            turtle.turnRight()
            data.f = data.f + 1
            turtle.turnRight()
        end
        sleep(0)
    end
    data.x = data.x - hdg[data.f][1]
    data.y = data.y - hdg[data.f][1]
    saveData()
end
function t.turnLeft()
    data.f = data.f - 1
    if data.f < 1 then
        data.f = 4
    end
    saveData()
    turtle.turnLeft()
end
function t.turnRight()
    data.f = data.f + 1
    if data.f > 4 then
        data.f = 1
    end
    saveData()
    turtle.turnRight()
end
function t.up()
    fuelCheck()
    data.z = data.z + 1
    saveData()
    turtle.up()
end
function t.down()
    fuelCheck()
    data.z = data.z - 1
    saveData()
    turtle.down()
end
local function face(heading)
    while heading ~= data.f do
        t.turnRight()
    end
end
local function goTo(tX,tY)
    if data.x < tX then
        face(2)
    end
    while data.x < tX do
        t.forward()
    end
    if data.y < tY then
        face(3)
    end
    while data.y < tY do
        t.forward()
    end
    if data.x > tX then
        face(4)
    end
    while data.x > tX do
        t.forward()
    end
    if data.y > tY then
        face(1)
    end
    while data.y > tY do
        t.forward()
    end
end

-- Cleanup Screen

term.clear()
term.setCursorPos(1,2)
if shell.getRunningProgram() ~= "startup" and shell.getRunningProgram() ~= "startup.lua" then
    log("Warning! Not running as startup.")
end
while data.z > 0 do
    t.down()
end

-- Dump Function

local holdItems = {
    ["minecraft:log"] = 24,
    ["minecraft:wheat_seeds"] = 16,
    ["minecraft:sapling"] = 8,
}
local dumpItems = {
    ["minecraft:carrot"] = true,
    ["minecraft:log"] = true,
    ["minecraft:wheat"] = true,
    ["minecraft:wheat_seeds"] = true,
    ["minecraft:potato"] = true,
    ["minecraft:reeds"] = true,
    ["minecraft:pumpkin"] = true,
    ["minecraft:melon"] = true,
    ["minecraft:sapling"] = true,
}
function dump(resume)
    log("Returning to dump point")
    if resume then
        local callback = {
            ["x"] = data.x,
            ["y"] = data.y,
            ["f"] = data.f,
        }
    end
    goTo(0,0)
    face(2)
    log("Dumping items...")
    local _,meta = turtle.inspectDown()
    if meta then
        if meta.name == "minecraft:chest" then
            -- All good
        else
            log("Error! Chest not found")
            return false
        end
    end
    for i=1,16 do
        turtle.select(i)
        local itemData = turtle.getItemDetail(i)
        if itemData then
            if dumpItems[itemData.name] then
                turtle.select(i)
                local dropAmount = nil
                if holdItems[itemData.name] then
                    dropAmount = itemData.count - holdItems[itemData.name]
                end
                if dropAmount then
                    if dropAmount > 0 then
                        turtle.dropDown(dropAmount)
                    end
                else
                    turtle.dropDown()
                end
            end
        end
    end
    log("Done!")
    turtle.select(1)
    if resume then
        log("Returning to traverse")
        goTo(callback.x,callback.y)
        face(callback.f)
    end
end

-- Return Home

while data.z > 0 do
    t.down()
end
sortInv()
dump(false)
local _,meta = turtle.inspectDown()
if meta then
    if meta.name == "minecraft:chest" then
        log("In position, ready to go!")
    else
        log("Cannot find home point!")
        return    
    end
end

-- Traverse Garden

log("All systems operational")
while true do
    log("Begin traverse")
    local dir = true
    for x=1,sizeY do
        if dir then
            face(2)
        else
            face(4)
        end
        for y=1,sizeX do
            local ok,meta = t.inspectDown()
            if ok then
                if meta.name == "minecraft:log" then
                    log("Tree! Harvesting..")
                    t.digDown()
                    while t.detectUp() do
                        t.digUp()
                        t.up()
                        t.dig()
                        t.turnRight()
                        t.dig()
                        t.turnRight()
                        t.dig()
                        t.turnRight()
                        t.dig()
                        t.turnRight()
                    end
                    while data.z > 0 do
                        t.down()
                    end
                    sortInv()
                    selectItem("minecraft:sapling")
                    t.placeDown()
                    t.select(1)
                elseif meta.name == "minecraft:wheat" then
                    if meta.metadata >= 7 then
                        t.digDown()
                        sortInv()
                        selectItem("minecraft:wheat_seeds")
                        t.placeDown()
                        t.select(1)
                    end
                elseif meta.name == "minecraft:potatoes" then
                    if meta.metadata >= 7 then
                        t.digDown()
                        sortInv()
                        selectItem("minecraft:potato")
                        t.placeDown()
                        t.select(1)
                    end
                elseif meta.name == "minecraft:carrots" then
                    if meta.metadata >= 7 then
                        t.digDown()
                        sortInv()
                        selectItem("minecraft:carrot")
                        t.placeDown()
                        t.select(1)
                    end    
                elseif meta.name == "minecraft:melon_block" then
                    t.digDown()
                    sortInv()
                elseif meta.name == "minecraft:pumpkin" then
                    t.digDown()
                    sortInv()
                end
            end
            t.forward()
        end
        if x ~= sizeX then
            if dir then
                t.turnRight()
                t.forward()
                t.turnRight()
            else
                t.turnLeft()
                t.forward()
                t.turnLeft()
            end
        end
        dir = not dir
    end
    dump(false)
    log("Traverse complete")
    log("Waiting for "..tostring(waitTime).." seconds")
    sleep(waitTime)
end
