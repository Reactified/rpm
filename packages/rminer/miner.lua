-- automatic miner by reactified
local item_blacklist = {"minecraft:stone","minecraft:cobblestone","minecraft:dirt","minecraft:diorite","minecraft:granite","minecraft:andesite","minecraft:gravel","minecraft:flint","create:limestone","create:weathered_limestone","minecraft:flint"}
local keyword_blacklist = {"fossil"}

local args = {...}
local target = tonumber(args[1])
local length = 0

-- logging
local function log(str)
    print(str)
end

-- turtle functions
local t = {}

for i,v in pairs(turtle) do
    t[i] = v
end

local movefuncs = {fwd=turtle.forward,up=turtle.up,down=turtle.down,back=turtle.back,left=turtle.turnLeft,right=turtle.turnRight}
for i,v in pairs(movefuncs) do
    t[i] = function(count)
        for z=1,count or 1 do
            while true do
                local result = v()
                if result then 
                    break 
                else
                    if v == turtle.forward then
                        turtle.dig()
                    elseif v == turtle.up then
                        turtle.digUp()
                    elseif v == turtle.down then
                        turtle.digDown()
                    end
                    turtle.attack()
                    turtle.attackUp()
                    turtle.attackDown()
                end
            end
        end
    end
end

-- filter functions
local function isGoodOre(name)
    if string.find(name,"ore") then
        return true
    end
end
local function isGoodItem(name)
    for i,v in pairs(item_blacklist) do
        if name == v then
            return false
        end
    end
    for i,v in pairs(key_blacklist) do
        if string.find(name,v) then
            return false
        end
    end
    return true
end

-- miner functions
local function veinCheck(side)
    -- scan appropriate side
    local idata
    if side == "front" then
        _,idata = turtle.inspect()
    elseif side == "top" then
        _,idata = turtle.inspectUp()
    elseif side == "bottom" then
        _,idata = turtle.inspectDown()
    else
        error("invalid veincheck call: "..side)
    end
    
    -- is good ore?
    if idata and idata.name then
        if isGoodOre(idata.name) then
            log(idata.name.." mined")
            -- do appropriate mining action
            if side == "front" then
                turtle.dig()
                t.fwd()
                veinCheck("front")
                veinCheck("bottom")
                veinCheck("top")
                turtle.turnLeft()
                veinCheck("front")
                turtle.turnRight()
                turtle.turnRight()
                veinCheck("front")
                turtle.turnLeft()
                t.back()
            elseif side == "bottom" then
                turtle.digDown()
                t.down()
                veinCheck("bottom")
                for i=1,4 do
                    veinCheck("front")
                    t.left()
                end
                t.up()
            elseif side == "top" then
                turtle.digUp()
                t.up()
                veinCheck("top")
                for i=1,4 do
                    veinCheck("front")
                    t.left()
                end
                t.down()
            end
        end
    end
end

local function mineStep()
    turtle.select(1)
    t.dig()
    t.fwd()
    length = length + 1
    t.digUp()
    veinCheck("bottom")
    t.left()
    veinCheck("front")
    t.up()
    veinCheck("front")
    veinCheck("top")
    t.right()
    t.right()
    veinCheck("front")
    t.down()
    veinCheck("front")
    t.left()
end

local function cleanInv()
    local success = false
    for i=1,16 do
        turtle.select(i)
        local idata = turtle.getItemDetail()
        if idata then
            if not isGoodItem(idata.name) then
                success = true
                turtle.drop()
            end
        end
    end
    turtle.select(1)
    return success
end

-- mine
while true do
    mineStep()
    if target and length >= target then
        log("reached target length, returning")
        break
    end
    if turtle.getItemCount(16) > 0 then
        local success = cleanInv()
        if not success then
            log("inventory full, returning")
            break
        else
            log("inventory cleaned")
        end
    end
    if turtle.getFuelLevel() < length*2 then
        log("low fuel, returning")
        break
    end
end

-- return
cleanInv()
t.left(2)
t.fwd(length)
