--/ Krypt Mainframe / Reactified /--
local m = peripheral.find("monitor")
local modem = peripheral.find("modem")
local cliLog = false

--/ Data Persistence /--
local data = {
    chan = math.random(1,65535)*76,
    nodes = {},
    map = {},
    drawMap = {},
}
local nodes = {}
function saveData()
    f = fs.open("/.krypt","w")
    f.writeLine(textutils.serialise(data))
    f.close()
end
if fs.exists("/.krypt") then
    f = fs.open("/.krypt","r")
    data = textutils.unserialise(f.readAll())
    f.close()
else
    saveData()
end
function log(x,init)
    term.scroll(1)
    if init then
        term.setBackgroundColor(colors.gray)
        term.clear()
    end
    if term.isColor() then
        term.setBackgroundColor(colors.green)
    else
        term.setBackgroundColor(colors.lightGray)
    end
    term.setCursorPos(1,1)
    term.clearLine()
    term.setCursorPos(2,1)
    term.setTextColor(colors.black)
    term.write("KRYPT")
    term.setTextColor(colors.gray)
    term.write(" | ")
    term.setTextColor(colors.black)
    term.write("MAINFRAME LOG")
    term.setBackgroundColor(colors.gray)
    if term.isColor() then
        term.setTextColor(colors.green)
    else
        term.setTextColor(colors.lightGray)
    end
    term.setCursorPos(1,19)
    term.write(x)
end
local refreshAllNodes = false
local updateAttribute = false

--/ Primary Routine /--
function primaryRoutine()
    --/ Networking /--
    if modem then
        modem.open(data.chan/76)
    else
        os.pullEvent("INFINITE_YIELD")
    end
    function send(node,msg) -- IF target node TRUE means broadcast
        modem.transmit(data.chan/76,65535,{
            integrity = data.chan*#textutils.serialise(msg),
            krypt = true,
            data = msg,
            target = node,
        })
    end
    function recv(filter,timeout)
        local timeoutTimer
        if timeout then
            timeoutTmr = os.startTimer(timeout)
        end
        while true do
            local e,s,c,r,msg = os.pullEvent()
            if e == "modem_message" and c == data.chan/76 and type(msg) == "table" and msg.krypt and msg.integrity == data.chan*#textutils.serialise(msg.data) then
                if (r == filter or not filter) and msg.target == 65535 then
                    return r,msg.data
                end
            elseif e == "timer" then
                if s == timeoutTmr then
                    return false
                end
            end
        end
    end

    --/ Node Updating /--
    updateIO = function(node,attrib,value)
        send(node,{
            command = "[IO-UPDATE]",
            interface = attrib,
            value = value,
        })
    end
    refreshAllNodes = function()
        for i,v in pairs(data.nodes) do
            send(i,"[STATUS-UPDATE]")
            local _,msg = recv(i,0.2)
            if msg then
                nodes[i] = msg
                for k,z in pairs(nodes[i].io) do
                    if z.type == "Basic Sensor" or z.type == "Percentage Bar" then
                        updateIO(i,k,true)
                    end
                end
            else
                nodes[i] = {
                    status = false,
                    name = v.name,
                }
            end
        end
    end

    --/ Routine /--
    while true do
        local node,msg = recv()
        if msg == "[PAIRING-REQUEST]" then
            send(node,"[PAIRING-ACCEPTED]")
            data.nodes[node] = {}
        elseif type(msg) == "table" then
            if msg.command == "[UPDATE-ATTRIBUTE]" and data.nodes[node] then
                log("#"..tostring(node)..": UPDATED "..string.upper(msg.attribute))
                data.nodes[node][msg.attribute] = msg.value
                saveData()
            end
        end
    end
end

--/ Node Update Subroutine /--
function updateRoutine()
    while true do
        sleep(0.25)
        refreshAllNodes()
    end
end

--/ Interface Subroutine /--
function userRoutine()
    m.setTextScale(1)
    local nodeListScroll = 0
    local tab = "Nodes"
    local selected = false
    local selectedID = false
    local wid = m.getSize()
    if wid < 30 then
        m.setTextScale(0.5)
    elseif wid > 60 then
        m.setTextScale(2)
    end
    local w,h = m.getSize()
    local mapX = 0
    local mapY = 0
    local mapZ = 0
    local mapObjPlace = false
    local mapDrawColor = false
    local nldps = {} -- Node List Display Positions
    local opcd = {} -- Object Panel Control Data

    --/ Routine /--
    local darkColor = colors.black
    if m.setPaletteColor then
        m.setPaletteColor(colors.brown,0.2,0.2,0.2)
        darkColor = colors.brown
        m.setPaletteColor(colors.magenta,0,0.1,0)
    end
    while true do
        local panelX = w-15
        -- Basic Draw
        m.setBackgroundColor(colors.black)
        m.clear()
        -- Main Field Draw
        if tab == "Map" then
            if mapObjPlace then
                m.setBackgroundColor(colors.magenta)
                m.clear()
            end
            if not data.drawMap[mapZ] then
                data.drawMap[mapZ] = {}
            end
            for x,i in pairs(data.drawMap[mapZ]) do
                for y,v in pairs(i) do
                    local renderX = x+mapX
                    local renderY = y+mapY
                    if renderX >= 1 and renderX <= w and renderY >= 1 and renderY <= h then
                        m.setCursorPos(renderX,renderY)
                        m.setBackgroundColor(v)
                        m.write(" ")
                    end
                end
            end
            for i,v in pairs(data.map) do
                if v[3] == mapZ then
                    local renderX = v[1]+mapX
                    local renderY = v[2]+mapY
                    if renderX >= 1-#nodes[i].name and renderY >= 1 and renderX <= w and renderY <= h then
                        if selectedID == i then
                            m.setBackgroundColor(colors.green)
                            m.setTextColor(darkColor)
                        else
                            m.setBackgroundColor(colors.gray)
                            m.setTextColor(colors.lightGray)
                        end
                        m.setCursorPos(renderX,renderY)
                        m.write(" "..nodes[i].name.." ")
                    end
                end
            end
        elseif tab == "Nodes" then
            local dpos = 1
            local drawid = 1
            m.setCursorPos(1,1)
            m.setTextColor(colors.gray)
            m.write("Network")
            m.setCursorPos(panelX-3,1)
            if #nodes > h-2 then
                m.write("<>")
            end
            for i,v in pairs(nodes) do
                drawid = drawid + 1
                if drawid > nodeListScroll then
                    nldps[dpos] = i
                    dpos = dpos + 1
                    if dpos == h then
                        break
                    end
                    m.setCursorPos(1,dpos)
                    m.setTextColor(colors.lightGray)
                    m.write("#"..string.rep("0",3-#tostring(i))..tostring(i).." ")
                    if selected and selected.name == v.name then
                        m.setTextColor(colors.green)
                    elseif v.status then
                        m.setTextColor(colors.white)
                    else
                        m.setTextColor(colors.gray)
                    end
                    m.write(v.name or "Unknown")
                end
            end
        else
            m.setTextColor(colors.green)
            m.setCursorPos(2,2)
            m.write("Error")
            m.setCursorPos(2,3)
            m.setTextColor(colors.lightGray)
            m.write("Unsupported tab mode")
        end
        -- Draw Panel
        m.setBackgroundColor(colors.gray)
        for y=1,h do
            m.setCursorPos(panelX,y)
            m.write(string.rep(" ",1+(w-panelX)))
        end
        -- Draw Panel Header
        m.setBackgroundColor(colors.green)
        m.setCursorPos(panelX,1)
        m.write(string.rep(" ",1+(w-panelX)))
        m.setTextColor(colors.black)
        m.setCursorPos(panelX+1,1)
        m.write("KRYPT")
        local str = "#"..tostring(data.chan)
        m.setCursorPos(w-#str,1)
        m.setTextColor(darkColor)
        m.write(str)
        -- Draw Panel Information
        m.setCursorPos(panelX+1,3)
        m.setBackgroundColor(colors.gray)
        if selected then
            local dpos = 3
            if data.map[selectedID] then
                m.setTextColor(colors.white)
            else
                m.setTextColor(colors.green)
            end
            m.write("> ")
            m.setTextColor(colors.white)
            m.write(selected.name)
            dpos = dpos + 1
            if not selected.status then
                m.setCursorPos(panelX+1,dpos)
                m.setTextColor(colors.red)
                m.write("Offline")
                dpos = dpos + 1
            end
            m.setCursorPos(panelX+1,dpos)
            m.setTextColor(colors.lightGray)
            m.setCursorPos(panelX+1,dpos)
            m.write(string.rep("-",14))
            -- Draw IO
            opcd = {}
            if selected.io then
                local formattedIO = {}
                for i,v in pairs(selected.io) do
                    if v.type == "Basic Sensor" then
                        v.listid = i
                        formattedIO[#formattedIO+1] = v
                    end
                end
                for i,v in pairs(selected.io) do
                    if v.type ~= "Basic Sensor" then
                        v.listid = i
                        formattedIO[#formattedIO+1] = v
                    end
                end
                for _,v in pairs(formattedIO) do
                    local i = v.listid
                    m.setBackgroundColor(colors.gray)
                    if v.type ~= "Basic Sensor" and dpos ~= 4 then
                        dpos = dpos + 1
                        m.setCursorPos(panelX+1,dpos)
                        m.setTextColor(colors.lightGray)
                        m.write(string.rep("-",14))
                    end
                    dpos = dpos + 1
                    m.setCursorPos(panelX+1,dpos)
                    m.setTextColor(colors.lightGray)
                    if v.type == "Toggle Control" then
                        m.write(string.sub(i,1,9))
                        opcd[dpos] = {i,v,selectedID}
                        m.setCursorPos(w-4,dpos)
                        if v.state then
                            m.setBackgroundColor(darkColor)
                        else
                            m.setBackgroundColor(colors.red)
                        end
                        m.write("  ")
                        if v.state then
                            m.setBackgroundColor(colors.green)
                        else
                            m.setBackgroundColor(darkColor)
                        end
                        m.write("  ")
                    elseif v.type == "Push Control" then
                        opcd[dpos] = {i,v,selectedID}
                        m.setCursorPos(panelX+1,dpos)
                        m.setBackgroundColor(colors.lightGray)
                        m.write(string.rep(" ",14))
                        m.setCursorPos((panelX+8)-(#i/2),dpos)
                        m.setTextColor(darkColor)
                        m.write(i)
                    elseif v.type == "Basic Sensor" then
                        local sensorText = tostring(v.output or "N/A")
                        if #sensorText + #i > 13 then
                            m.setCursorPos(panelX+1,dpos)
                            m.setTextColor(colors.lightGray)
                            m.write(i..":")
                            dpos = dpos + 1
                            m.setCursorPos(panelX+1,dpos)
                            m.setTextColor(colors.green)
                            m.write(sensorText)
                        else
                            m.setCursorPos(panelX+1,dpos)
                            m.setTextColor(colors.lightGray)
                            m.write(i)
                            m.setCursorPos(w-#sensorText,dpos)
                            m.setTextColor(colors.green)
                            m.write(sensorText)
                        end
                    elseif v.type == "Percentage Bar" then
                        local pPos = string.find(i,"<")
                        local pName = i
                        local pColor = colors.green
                        if pPos then
                            pColor = colors[string.lower(string.sub(i,pPos+1,#i-1))] or colors.green
                            pName = string.sub(i,1,pPos-2)
                        end
                        m.setCursorPos(panelX+1,dpos)
                        m.setTextColor(colors.lightGray)
                        m.write(pName..":")
                        dpos = dpos + 1
                        local pOutput = tonumber(v.output)
                        if pOutput then
                            local pValue = ( pOutput * 100 ) + 0.01
                            if pValue > 100 then pValue = 100 end
                            if pValue < 0 then pValue = 0 end
                            local pString = " "..tostring(math.floor(pValue)).."%"
                            m.setCursorPos(panelX+1,dpos)
                            for i=1,14 do
                                m.setTextColor(colors.black)
                                if i > pValue * .14 then
                                    m.setBackgroundColor(colors.brown)
                                else
                                    m.setBackgroundColor(pColor)
                                end
                                local subString = string.sub(pString,i,i)
                                if type(subString) ~= "string" or #subString < 1 then
                                    subString = " "
                                end
                                m.write(subString)
                            end
                        else
                            m.setCursorPos(panelX+1,dpos)
                            m.write("<ERROR>")
                        end
                    end
                end
            end
        else
            m.setTextColor(colors.white)
            m.setCursorPos(panelX+1,3)
            m.write("  Node Panel")
            m.setTextColor(colors.lightGray)
            m.setCursorPos(panelX+2,5)
            m.write("Select a Node")
            m.setCursorPos(panelX+2,6)
            m.write(" for details")
            if tab == "Map" then
                m.setCursorPos(panelX+3,8)
                m.setTextColor(colors.white)
                m.write("Map Drawing")
                m.setCursorPos(panelX+4,9)
                m.setTextColor(colors.black)
                if mapDrawColor == false then
                    m.write("> ")
                end
                m.write("Disabled")
                m.setCursorPos(panelX+4,10)
                m.setTextColor(colors.black)
                if mapDrawColor == colors.black then
                    m.write("> ")
                end
                m.write("Black")
                m.setCursorPos(panelX+4,11)
                m.setTextColor(darkColor)
                if mapDrawColor == darkColor then
                    m.write("> ")
                end
                m.write("Gray")
                m.setCursorPos(panelX+4,12)
                m.setTextColor(colors.lightGray)
                if mapDrawColor == colors.lightGray then
                    m.write("> ")
                end
                m.write("Light")
                m.setCursorPos(panelX+4,13)
                m.setTextColor(colors.cyan)
                if mapDrawColor == colors.cyan then
                    m.write("> ")
                end
                m.write("Cyan")
                m.setCursorPos(panelX+4,14)
                m.setTextColor(colors.red)
                if mapDrawColor == colors.red then
                    m.write("> ")
                end
                m.write("Red")
            end
        end
        -- Draw Bottom Controls
        m.setBackgroundColor(colors.brown)
        m.setCursorPos(1,h)
        m.write(string.rep(" ",panelX-1))
        m.setCursorPos(2,h)
        if tab == "Map" then
            m.setTextColor(colors.green)
            m.setBackgroundColor(colors.gray)
        else
            m.setTextColor(colors.lightGray)
            m.setBackgroundColor(darkColor)
        end
        m.write(" Map ")
        if tab == "Nodes" then
            m.setTextColor(colors.green)
            m.setBackgroundColor(colors.gray)
        else
            m.setTextColor(colors.lightGray)
            m.setBackgroundColor(darkColor)
        end
        m.write(" Nodes ")
        -- Event Handling
        local uiTimer = os.startTimer(0.25)
        while true do
            local e,c,x,y = os.pullEvent()
            if selected then
                selected = nodes[selectedID]
            end
            if e == "timer" and c == uiTimer then
                break
            elseif e == "monitor_touch" then
                -- Right Panel Controls
                if selected and x >= panelX then
                    local cd = opcd[y]
                    if cd then
                        if cd[2].type == "Toggle Control" then
                            updateIO(cd[3],cd[1],not cd[2].state)
                            selected.io[cd[1]].state = not cd[2].state
                        elseif cd[2].type == "Push Control" then
                            updateIO(cd[3],cd[1],true)
                        end
                    end
                    if x == panelX + 1 and y == 3 then
                        if not mapObjPlace then
                            if data.map[selectedID] then
                                data.map[selectedID] = nil
                                saveData()
                            else
                                tab = "Map"
                                mapObjPlace = selectedID
                            end
                        else
                            mapObjPlace = false
                        end
                    end
                elseif tab == "Map" and not selected and x >= panelX then
                    if y == 9 then
                        mapDrawColor = false
                    elseif y == 10 then
                        mapDrawColor = colors.black
                    elseif y == 11 then
                        mapDrawColor = darkColor
                    elseif y == 12 then
                        mapDrawColor = colors.lightGray
                    elseif y == 13 then
                        mapDrawColor = colors.cyan
                    elseif y == 14 then
                        mapDrawColor = colors.red
                    end
                end
                -- Main Field Controls
                if x < panelX and y < h then
                    local hit = false
                    if tab == "Map" then
                        local hit = false
                        for i,v in pairs(data.map) do
                            if v[3] == mapZ then
                                local renderX = v[1]+mapX
                                local renderY = v[2]+mapY
                                if x >= renderX and x <= renderX+#nodes[i].name+1 and y == renderY then
                                    hit = i
                                    selectedID = i
                                    selected = nodes[i]
                                end
                                saveData()
                            end
                        end
                        if not hit then
                            if mapObjPlace then
                                data.map[mapObjPlace] = {x-mapX,y-mapY,mapZ}
                                mapObjPlace = false
                                saveData()
                            elseif mapDrawColor then
                                if not data.drawMap[mapZ][x-mapX] then
                                    data.drawMap[mapZ][x-mapX] = {}
                                end
                                data.drawMap[mapZ][x-mapX][y-mapY] = mapDrawColor
                            else
                                local centerX = panelX/2
                                local centerY = (h-1)/2
                                mapX = mapX - math.floor((x-centerX)/2)
                                mapY = mapY - math.floor((y-centerY)/2)
                                selected = false
                                selectedID = false
                            end
                        end
                    elseif tab == "Nodes" then
                        if nldps[y-1] then
                            hit = true
                            selected = nodes[nldps[y-1]]
                            selectedID = nldps[y-1]
                        end
                        if not hit then
                            selected = false
                            selectedID = false
                        end
                        if x == panelX-3 and y == 1 then
                            if nodeListScroll > 0 then
                                nodeListScroll = nodeListScroll - h-2
                            end
                        elseif x == panelX-2 and y == 1 then
                            nodeListScroll = nodeListScroll + h-2
                        end
                    end
                end
                -- Bottom Controls
                if y == h then
                    if x >= 2 and x <= 6 then
                        tab = "Map"
                    elseif x >= 7 and x <= 12 then
                        tab = "Nodes"
                    end
                end
                break
            end
        end
    end
end

--/ Kernel /--
log("KRYPT MAINFRAME INITIALIZING",true)
while true do
    local drawTargets = {}
    if m then
        drawTargets[#drawTargets+1] = m
        parallel.waitForAny(userRoutine,primaryRoutine,updateRoutine) -- Normal routine start
    else
        log("RUNNING IN COMPATIBILITY OVERRIDE MODE!")
        sleep(2)
        m = term
        log = function() end
    end
    log("! ERROR ! SYSTEM FAILURE")
    for k=30,0,-0.2 do
        for i,v in pairs(drawTargets) do
            v.setBackgroundColor(colors.green)
            v.clear()
            v.setTextColor(colors.black)
            v.setCursorPos(2,2)
            v.write(">> KRYPT - CRITICAL ERROR")
            local txw,txy = v.getSize()
            for dpos = 4,txy do
                v.setBackgroundColor(colors.black)
                v.setCursorPos(1,dpos)
                v.clearLine()
                v.setCursorPos(math.random(1,txw),dpos)
                v.setTextColor(colors.green)
                v.write(string.char(math.random(1,255)))
            end
            v.setTextColor(colors.white)
            v.setCursorPos(2,5)
            v.write("MAINFRAME HAS ENCOUNTERED AN ERROR")
            v.setCursorPos(2,6)
            v.write("SYSTEM WILL REBOOT IN ")
            v.setBackgroundColor(colors.white)
            v.setTextColor(colors.gray)
            v.write(" "..tostring(math.floor(k)).." ")
            v.setBackgroundColor(colors.black)
            v.setTextColor(colors.white)
            v.write(" SECONDS")
        end
        sleep(0.2)
    end
    log("ATTEMPTING CRASH RECOVERY")
end
