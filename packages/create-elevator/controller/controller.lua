-- REACT INDUSTRIES | Elevator Controller
local clutchSide = "top"
local gearshiftSide = "back"
local doorControlSide = "bottom"

local carLinkSide = "right"
local callInputSide = "left"

local doorOpenTime = 5
local doorMovementTime = 1
local movementTimeout = 30

local driveInverted = false
local doorInverted = false

local limitSwitchSide = "front"
local limitSwitches = {
    [15] = "top",
    [14] = "bottom",
}
local bottomLimitSwitchFloor = 1
local topLimitSwitchFloor = 3

local floors = {
    [1] = 0,
    [2] = 6,
    [3] = 12,
}
local floorIndex = {
    1,
    2,
    3,
}

local position = 0
local floor = 0
local direction = 0
local state = "init"
local calls = {}

-- Pre-Initialization
local lowestFloor = 0
local highestFloor = 0
for i,v in pairs(floors) do
    if i < lowestFloor then
        lowestFloor = i
    end
    if i > highestFloor then
        highestFloor = i
    end
    calls[i] = false
end

-- Mechanical Functions
local function shaftDirection(state)
    rs.setOutput(clutchSide,state == 0)
    rs.setOutput(gearshiftSide,state == -1)
end
local function doorControl(state)
    rs.setOutput(doorControlSide,state)
end
local function checkLimitSwitch()
    return limitSwitches[rs.getAnalogInput(limitSwitchSide)] or false
end

-- Logic Functions
local function invert(val,bInvert)
    if bInvert then
        return 0-val
    else
        return val
    end
end

local function up()
    doorControl(false)
    shaftDirection(invert(1,driveInverted))
end
local function down()
    doorControl(false)
    shaftDirection(invert(-1,driveInverted))
end
local function stop()
    shaftDirection(0)
end

local function openDoor()
    doorControl(true)
    shaftDirection(invert(1,doorInverted))
    sleep(doorMovementTime)
    shaftDirection(0)
end
local function closeDoor()
    doorControl(true)
    shaftDirection(invert(-1,doorInverted))
    sleep(doorMovementTime)
    shaftDirection(0)
end

-- Abstract Functions
local secondsPerMeter = 0
local metersPerSecond = 0
local function homingSequence()
    local switch = checkLimitSwitch()
    local topLimitSwitchLevel = floors[topLimitSwitchFloor]
    local bottomLimitSwitchLevel = floors[bottomLimitSwitchFloor]
    print("[Homing] Limit switch: "..tostring(switch))
    -- close doors
    print("[Homing] Closing doors")
    closeDoor()
    -- go to bottom
    if switch ~= "bottom" then
        print("[Homing] Going to bottom")
        local timeoutTimer = os.startTimer(movementTimeout)
        while checkLimitSwitch() ~= "bottom" do
            down()
            local e,t = os.pullEvent()
            if e == "timer" and t == timeoutTimer then
                print("[Homing] Movement timeout reached")
                up()
                repeat
                    os.pullEvent("redstone")
                    if checkLimitSwitch() == "top" then
                        print("[Fatal Error] Limit switch fault B01")
                        stop()
                        state = "error"
                        return
                    end
                until checkLimitSwitch() == "bottom"
                print("[Homing] Realignment success")
                break
            end
        end
        stop()
        sleep(1)
    end
    local startTime = os.epoch("utc")
    -- go to top
    print("[Homing] Going to top")
    while checkLimitSwitch() ~= "top" do
        up()
        os.pullEvent("redstone")
    end
    stop()
    -- done
    local deltaTime = (os.epoch("utc")-startTime)/1000
    metersPerSecond = ( topLimitSwitchLevel - bottomLimitSwitchLevel) / deltaTime
    secondsPerMeter = 1 / metersPerSecond
    print("[Homing] Measured speed: "..tostring(metersPerSecond).." m/s")
    floor = topLimitSwitchFloor
    position = topLimitSwitchLevel
end
local function operateDoor()
    print("[Doors] Opening")
    openDoor()
    sleep(doorOpenTime)
    print("[Doors] Closing")
    closeDoor()
    os.queueEvent("doorClosed")
end
local function gotoFloor(selectedFloor)
    print("[Drive] Going to "..tostring(selectedFloor))
    local floorLevel = floors[selectedFloor]
    local delta = floorLevel-position
    local direction = 1

    if delta == 0 then
        return
    elseif delta < 0 then
        direction = -1
    end
    delta = math.abs(delta)

    print("[Drive] Travel time: "..tostring(delta*secondsPerMeter))
    if direction == 1 then
        up()
    else
        down()
    end
    sleep(delta*secondsPerMeter)
    print("[Drive] Arrived")
    position = floorLevel
    floor = selectedFloor
    stop()
    if selectedFloor == topLimitSwitchFloor then
        if checkLimitSwitch() ~= "top" then
            print("[Drive] Misaligned with top limit switch, starting homing.")
            homingSequence()
            operateDoor()
        end
    elseif selectedFloor == bottomLimitSwitchFloor then
        if checkLimitSwitch() ~= "bottom" then
            print("[Drive] Misaligned with bottom limit switch, starting homing.")
            homingSequence()
            operateDoor()
        end
    end
end

-- UI Functions
local function updateDisplayStatus()
    term.setTextColor(colors.lightGray)
    write("Status: "..string.upper(state).." | Floor: "..tostring(floor).." | Pos: "..tostring(position).." | ")
    if direction == 1 then
        print("UP")
    elseif direction == 0 then
        print("UP/DN")
    elseif direction == -1 then
        print("DOWN")
    end
    term.setTextColor(colors.white)
end

-- Core Routine
local function coreRoutine()
    local w,h = term.getSize()
    term.clear()
    term.setCursorPos(1,1)
    print("REACT INDUSTRIES | Elevator Controller")
    state = "homing"
    
    while true do
        -- display status
        updateDisplayStatus()

        -- outside call input
        if rs.getInput(callInputSide) then
            local inputFloor = 16 - rs.getAnalogInput(callInputSide)
            calls[floorIndex[inputFloor]] = true
            print("External call entered: "..tostring(floorIndex[inputFloor]))
        end

        -- state logic
        if state == "homing" then
            -- auto home
            homingSequence()
            state = "idle"
        elseif state == "idle" then
            -- call range
            local lowRange, highRange = lowestFloor, highestFloor
            if direction == 1 then
                lowRange = floor
            elseif direction == -1 then
                highRange = floor
            end
            -- check calls
            for i=lowRange, highRange do
                if calls[i] then
                    -- serve call
                    calls[i] = false
                    if i == floor then
                        -- open doors
                        operateDoor()
                    else
                        -- move lift
                        print("[Dispatch] Serving call "..tostring(i))
                        state = "travelling"
                        updateDisplayStatus()
                        gotoFloor(i)
                        state = "idle"
                        updateDisplayStatus()
                        operateDoor()
                    end
                    break
                elseif i == highRange then
                    -- no calls
                    direction = 0
                end
            end
            -- direction logic
            if floor == highestFloor then
                direction = -1
            elseif floor == lowestFloor then
                direction = 1
            end
        end

        -- event logic
        local routineTimer = os.startTimer(1)
        local e,c,x,y = os.pullEvent()
        if c ~= routineTimer then
            os.cancelTimer(routineTimer)
        end

    end
end

-- Car Call Routine
local function carCallRoutine()
    while true do
        os.pullEvent('redstone')
        if rs.getInput(carLinkSide) then
            local startTime = os.epoch("utc")
            while true do
                os.pullEvent("redstone")
                if rs.getInput(carLinkSide) == false then
                    break
                end
            end
            local timer = ( os.epoch("utc") - startTime ) / 100
            print(timer)
            
            local inputFloor = math.floor(timer+0.4) - 1
            print("detected as "..tostring(inputFloor))
            if inputFloor == 0 then
                calls[floor] = true
            elseif floorIndex[inputFloor] then
                print("floor input "..tostring(floorIndex[inputFloor]))
                calls[floorIndex[inputFloor]] = true
            end
            os.queueEvent("callInput")
        end
    end
end

-- Start
parallel.waitForAll(coreRoutine,carCallRoutine)
