-- Aurora Stargate Control by Reactified

-- Persistent Data
local data = {
    panelName = "= AURORA =",
    theme = {
        background = "black",
        text = "lightGray",
        bright = "white",
        dark = "gray",
        accent = "cyan",
        warn = "red",
    },
    gates = {}
}
local datafile = "/aurora.data"
local function saveData()
    f = fs.open(datafile,"w")
    f.writeLine(textutils.serialise(data))
    f.close()
end
if fs.exists(datafile) then
    f = fs.open(datafile,"r")
    data = textutils.unserialise(f.readAll())
    f.close()
else
    saveData()
end

-- Logic Functions
local function switch(bool,on,off)
    if bool then 
        return on 
    else 
        return off 
    end
end
local function inTable(str,tbl)
    for i,v in pairs(tbl) do
        if v == str then
            return true
        end
    end
    return false
end

-- Drawing Functions
local function scbg(name) -- set color background
    term.setBackgroundColor(colors[data.theme[name]])
end
local function scfg(name) -- set color foreground
    term.setTextColor(colors[data.theme[name]])
end
local function center(str,ln,skip)
    str = str or "<- Placeholder ->"
    local w,h = term.getSize()
    term.setCursorPos((w/2)-(#str/2)+1,ln)
    if skip then return end
    term.write(str)
end

-- Intialize Peripherals
local stargate = peripheral.find("stargate")
local monitors = {}
for i,v in pairs(peripheral.getNames()) do
    local peripheralType = peripheral.getType(v)
    if peripheralType == "monitor" then
        table.insert(monitors,peripheral.wrap(v))
    end
end
if not stargate then
    printError("No stargate connected")
    return
end

-- Initialize Stargate
local function formatAdr(str)
    if #str == 9 then
        return string.sub(str,1,4).."-"..string.sub(str,5,7).."-"..string.sub(str,8,9)
    end
end
local localAdr = formatAdr(stargate.localAddress())
local sgState = stargate.stargateState()
local irisState = stargate.irisState()
local remoteAdr = formatAdr(stargate.remoteAddress())
local connectionName = false
local direction = false
local chevrons = 0

-- Gate Functions
local function gateName(adr)
    if data.gates[adr] then
        return data.gates[adr].name
    end
end

-- Update Monitors
local sgAlphabet = {"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","0","1","2","3","4","5","6","7","8","9"}
local function updateMonitors()
    for monitorId,m in pairs(monitors) do
        term.redirect(m)
        
        local w,h = term.getSize()
        if w >= 35 and h > 5 then
            m.setTextScale(2)
            w,h = term.getSize()
        end
        scbg("background")
        term.clear()

        if sgState == "Idle" then
            scfg("accent")
            center(data.panelName,2)
            if h > 5 then
                scfg("text")
                center(localAdr,3)
            end
            scfg("dark")
            center("STARGATE IDLE",h-1)
        elseif sgState == "Dialling" then
            local chevronText = ""
            local charVal = 0
            for i=1,chevrons do
                charVal = i
                if i > 4 then charVal = charVal + 1 end
                if i > 7 then charVal = charVal + 1 end
                chevronText = chevronText .. string.sub(remoteAdr,charVal,charVal)
                if i == 4 or i == 7 then
                    chevronText = chevronText .. "-"
                end
            end
            for i=chevrons+1,9 do
                chevronText = chevronText .. string.upper(sgAlphabet[math.random(1,#sgAlphabet)])
                if i == 4 or i == 7 then
                    chevronText = chevronText .. "-"
                end
            end
            scfg("dark")
            center(chevronText,2)
            scfg("accent")
            center(chevronText,2,true)
            write(string.sub(chevronText,1,charVal))
            scfg("bright")
            center(connectionName or "Unknown",3)
            scfg("text")
            if direction == "in" then
                center(switch(w>25,">> INBOUND CONNECTION <<",">> INBOUND <<"),h-1)
            else
                center(switch(w>25,"<< OUTBOUND CONNECTION >>","<< OUTBOUND >>"),h-1)
            end
        elseif sgState == "Opening" then
            scfg("accent")
            center(remoteAdr,2)
            scfg("bright")
            center(connectionName or "Unknown",3)
            scfg("warn")
            center("!! STAND CLEAR !!",h-1)
        elseif sgState == "Connected" then
            scfg("accent")
            center(remoteAdr,2)
            scfg("bright")
            center(switch(direction=="in","< ","> ")..(connectionName or "Unknown")..switch(direction=="in"," >"," <"),3)
            scfg("dark")
            center("STARGATE ACTIVE",h-1)
        elseif sgState == "Closing" then
            scfg("text")
            center(remoteAdr,2)
            scfg("bright")
            center(connectionName or "Unknown",3)
            scfg("warn")
            center(switch(w>25,"[ TERMINATING CONNECTION ]","[ TERMINATING ]"),h-1)
        end
    end
    term.redirect(term.native())
end

-- Update Screen
local mainMenu = {
    "Dial Stargate",
    "Address Book ",
    "Manage Gates ",
    "Settings     ",
}
local menuOptions = mainMenu
local menuOption = ""
local menuType = "main"

local controls = {}
local menuSelect = 1
local dialAdr = ""
local dialSelected = true
local function updateScreen()
    controls = {}
    local w,h = term.getSize()
    scbg("background")
    term.clear()

    if sgState == "Idle" then
        -- Main Menu
        scfg("accent")
        center(data.panelName,2)
        scfg("dark")
        center(localAdr,3)

        menuOption = menuOptions[menuSelect]
        scfg("text")
        center(menuOption,h/2)
        local aboveOption = menuOptions[menuSelect-1] or menuOptions[#menuOptions]
        local belowOption = menuOptions[menuSelect+1] or menuOptions[1]
        scfg("dark")
        center(aboveOption,h/2-2)
        center(belowOption,h/2+3)

        -- Special Menu Options
        scfg("bright")
        dialSelected = (menuOption == "Dial Stargate")
        if dialSelected then
            table.insert(controls,"-> Dial Gate")
            local dialStr = ""
            if dialSelected then
                dialStr = dialStr .. "["
            end
            local lastChar = true
            for i=1,9 do
                local char = string.sub(dialAdr,i,i)
                if char == "" then
                    char = " "
                end
                if lastChar and char == " " then
                    lastChar = false
                    dialStr = dialStr .. "_"
                else
                    if char ~= " " then
                        lastChar = true
                    end
                    dialStr = dialStr .. char
                end
                if i == 4 or i == 7 then
                    dialStr = dialStr .. "-"
                end
            end
            if dialSelected then
                dialStr = dialStr .. "]"
            end
            center(dialStr,h/2+1)
        elseif menuType == "main" then
            center(">>>          ",h/2+1)
        elseif menuType == "addressbook" then
            local gateAdr = "Main Menu"
            for i,v in pairs(data.gates) do
                if v.name == menuOption then
                    gateAdr = i
                end
            end
            center(gateAdr,h/2+1)
            table.insert(controls,switch((gateAdr=="Main Menu"),"-> Return","-> Dial Gate"))
        end
    elseif sgState ~= "Idle" then
        scfg("dark")
        center(data.panelName,2)
        scfg("text")
        center(localAdr..switch(direction=="in"," <<< "," >>> ")..(remoteAdr or "???"),4)
        scfg("accent")
        center(connectionName or "[ Unknown Gate ]",5)

        table.insert(controls,"<- Terminate")
        if direction == "in" then
            table.insert(controls,"\\ Reverse")
        end
        if not connectionName then
            table.insert(controls,"/ Chart Gate")
        end
    end

    -- Draw Controls
    local ctrlLen = 0
    for i,v in pairs(controls) do
        ctrlLen = ctrlLen + #v + 3
    end
    term.setCursorPos((w/2)-(ctrlLen/2)+1.5,h-1)
    for i,v in pairs(controls) do
        scbg("dark")
        scfg("background")
        write(" "..v.." ")
        scbg("background")
        write(" ")
    end
end

-- High Level
local function dialStargate(adr)
    success,error = stargate.dial(adr)
    if success then
        connectionName = gateName(remoteAdr)
        sgState = "Dialling"
        heartbeat = fastHb
        remoteAdr = adr
        direction = "out"
        dialAdr = ""
        return true
    else
        scfg("warn")
        local w,h = term.getSize()
        center(error,h-3)
        sleep(0.7)
        return false,error
    end
end

-- Core
local idleHb = 0.1
local fastHb = 5
local heartbeat = 0.1 -- rate of program execution in hz
while true do
    -- Update Screen
    updateScreen()

    -- Update Monitors
    updateMonitors()

    -- Event Handler
    local timer = os.startTimer(1/heartbeat)
    while true do
        local e = {os.pullEvent()}
        -- heartbeat refresh
        if e[1] == "timer" and e[2] == timer then
            break
        end
        -- stargate events
        if e[1] == "sgChevronEngaged" then
            chevrons = e[3]
        elseif e[1] == "sgIrisStateChange" then
            irisState = e[3]
        elseif e[1] == "sgStargateStateChange" then
            sgState = e[3]
            if sgState == "Idle" then
                chevrons = 0
                direction = false
                connectionName = false
                heartbeat = idleHb
            end
        elseif e[1] == "sgDialIn" then
            heartbeat = fastHb
            direction = "in"
            remoteAdr = formatAdr(stargate.remoteAddress())
            connectionName = gateName(remoteAdr)
        elseif e[1] == "sgDialOut" then
            heartbeat = fastHb
            direction = "out"
            remoteAdr = formatAdr(stargate.remoteAddress())
            connectionName = gateName(remoteAdr)
        end

        -- control events
        if e[1] == "key" then
            local key = e[2]
            if dialSelected and sgState == "Idle" then
                -- Dialing
                if key == keys.backspace then
                    dialAdr = string.sub(dialAdr,1,#dialAdr-1)
                elseif key == keys.enter then
                    local adr = formatAdr(dialAdr)
                    if adr then
                        dialStargate(adr)
                    end
                end
            elseif sgState ~= "Idle" then
                if key == keys.backspace then
                    stargate.disconnect()
                    if irisState ~= "Open" then
                        sleep(2)
                        stargate.openIris()
                    end
                elseif key == keys.backslash and direction == "in" then
                    local adr = remoteAdr
                    stargate.disconnect()
                    sleep(2.5)
                    stargate.dial(remoteAdr)
                elseif key == keys.slash then
                    local w,h = term.getSize()
                    scfg("accent")
                    center("Chart Stargate",h/2-1)
                    scfg("dark")
                    center("Enter Name:   ",h/2)
                    scfg("bright")
                    sleep()
                    center("              ",h/2+1,true)
                    write("> ")
                    local name = read()
                    connectionName = name
                    data.gates[remoteAdr] = {
                        name = name,
                    }
                    saveData()
                elseif key == keys.minus then
                    stargate.closeIris()
                elseif key == keys.equals then
                    stargate.openIris()
                end
            end

            if sgState == "Idle" then
                -- Menu Controls
                if key == keys.down then
                    menuSelect = menuSelect + 1
                    if menuSelect > #menuOptions then
                        menuSelect = 1
                    end
                elseif key == keys.up then
                    menuSelect = menuSelect - 1
                    if menuSelect < 1 then
                        menuSelect = #menuOptions
                    end
                end
                -- Menu Items
                if key == keys.enter then
                    if menuType == "main" then
                        if menuOption == "Address Book " then
                            local addresses = {"<- Back"}
                            for i,v in pairs(data.gates) do
                                table.insert(addresses,v.name)
                            end
                            menuOptions = addresses
                            menuType = "addressbook"
                        end
                    elseif menuType == "addressbook" then
                        local gateAdr = false
                        for i,v in pairs(data.gates) do
                            if v.name == menuOption then
                                gateAdr = i
                            end
                        end
                        if gateAdr then
                            dialStargate(gateAdr)
                        else
                            menuOptions = mainMenu
                            menuType = "main"
                        end
                    end
                end
            end
        elseif e[1] == "char" then
            if dialSelected then
                -- Dialing
                local char = e[2]
                if inTable(char,sgAlphabet) then
                    if #dialAdr < 9 then
                        dialAdr = dialAdr..string.upper(char)
                    end
                end
            end
        end

        -- cancel timer    
        if e[1] ~= "timer" then
            os.cancelTimer(timer)
            break
        end
    end
end
