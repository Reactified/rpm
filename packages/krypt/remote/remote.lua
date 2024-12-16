--/ Krypt Remote / Reactified /--
local m = peripheral.find("monitor")
local modem = peripheral.find("modem")
local cliLog = false

--/ Data Persistence /--
local data = {
    chan = 0,
    nodes = {},
    map = {},
    drawMap = {},
}
local init = false
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
    init = true
end

--/ Networking /--
function send(msg)
    modem.transmit(data.chan/76,os.getComputerID(),{
        integrity = data.chan*#textutils.serialise(msg),
        krypt = true,
        data = msg,
        target = 65535,
    })
end
function recv(timeout)
    local filter = 65535
    local timeoutTmr
    if timeout then
        timeoutTmr = os.startTimer(timeout)
    end
    while true do
        local e,s,c,r,m = os.pullEvent()
        if e == "modem_message" and c == data.chan/76 and type(m) == "table" and m.krypt then
            if r == filter or not filter and (m.target == os.getComputerID() or m.target == true) and m.integrity == data.chan*#textutils.serialise(m.data) then
                return m.data
            end
        elseif e == "timer" then
            if s == timeoutTmr then
                return false
            end
        end
    end
end

-- First Time Setup
if init then
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(2,2)
    term.setTextColor(colors.orange)
    write("KRYPT ")
    term.setTextColor(colors.lightGray)
    write("REMOTE")
    term.setCursorPos(2,4)
    term.setTextColor(colors.white)
    write("Enter KRYPT ID:")
    term.setCursorPos(2,5)
    input = tonumber(read())
    if not input then
        term.setCursorPos(2,6)
        printError("Invalid Entry")
        return
    end
    data.chan = input
    modem.open(data.chan/76)
    term.setCursorPos(2,7)
    write("Ready server for pairing")
    term.setCursorPos(2,8)
    write("by pressing the KRYPT ID")
    term.setCursorPos(2,9)
    term.setTextColor(colors.gray)
    write("Press any key when ready")
    os.pullEvent("key")
    term.setTextColor(colors.orange)
    term.setCursorPos(2,11)
    write("Pairing... ")
    send("[REMOTE-PAIRING]")
    local msg = recv(1)
    if msg == "[REMOTE-PAIRED]" then
        write("Success!")
    else
        print("Failed.")
        return
    end
    sleep(2)
    saveData()
end
modem.open(data.chan/76)

--/ Update Routine /--
local function updateRoutine()
    while true do
        send("[REMOTE-DATA-REQUEST]")
        msg = recv(1)
        if type(msg) == "table" then
            data = msg[1]
            nodes = msg[2]
        end

        sleep(3)
    end
end

--/ Update IO Function /--
local function updateIO(node,attrib,value)
    send({command = "[REMOTE-IO-CHANGE]",params={node,attrib,value}})
end

--/ Interface Subroutine /--
local function userRoutine()
    local m = term
    local nodeListScroll = 0
    local tab = "Nodes"
    local selected = false
    local selectedID = false
    local w,h = m.getSize()
    local mapX = 0
    local mapY = 0
    local mapZ = 0
    local nldps = {} -- Node List Display Positions
    local opcd = {} -- Object Panel Control Data

    --/ Routine /--
    local darkColor = colors.black
    if m.setPaletteColor then
        m.setPaletteColor(colors.brown,0.2,0.2,0.2)
        darkColor = colors.brown
    end
    while true do
        local panelX = w+1
        if selected then
            panelX = w-15
        end
        -- Basic Draw
        m.setBackgroundColor(colors.black)
        m.clear()
        -- Main Field Draw
        if tab == "Map" then
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
                            m.setBackgroundColor(colors.orange)
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
            m.setTextColor(colors.orange)
            m.write("KRYPT ")
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
                        m.setTextColor(colors.orange)
                    elseif v.status then
                        m.setTextColor(colors.white)
                    else
                        m.setTextColor(colors.gray)
                    end
                    m.write(v.name or "Unknown")
                end
            end
        else
            m.setTextColor(colors.orange)
            m.setCursorPos(2,2)
            m.write("Error")
            m.setCursorPos(2,3)
            m.setTextColor(colors.lightGray)
            m.write("Unsupported tab mode")
        end
        -- Draw Bottom Controls
        m.setBackgroundColor(colors.brown)
        m.setCursorPos(1,h)
        m.write(string.rep(" ",panelX-1))
        m.setCursorPos(2,h)
        if tab == "Map" then
            m.setTextColor(colors.orange)
            m.setBackgroundColor(colors.gray)
        else
            m.setTextColor(colors.lightGray)
            m.setBackgroundColor(darkColor)
        end
        m.write(" Map ")
        if tab == "Nodes" then
            m.setTextColor(colors.orange)
            m.setBackgroundColor(colors.gray)
        else
            m.setTextColor(colors.lightGray)
            m.setBackgroundColor(darkColor)
        end
        m.write(" Nodes ")
        if tab == "Map" then
            m.setCursorPos(panelX-(5+#tostring(mapZ)),h)
            m.setBackgroundColor(darkColor)
            m.setTextColor(colors.gray)
            m.write("- ")
            m.setTextColor(colors.lightGray)
            m.write(tostring(mapZ))
            m.setTextColor(colors.gray)
            m.write(" +")
        end
        -- Draw Panel
        m.setBackgroundColor(colors.gray)
        for y=1,h do
            m.setCursorPos(panelX,y)
            m.write(string.rep(" ",1+(w-panelX)))
        end
        -- Draw Panel Header
        m.setBackgroundColor(colors.orange)
        m.setCursorPos(panelX,1)
        m.write(string.rep(" ",1+(w-panelX)))
        m.setTextColor(colors.black)
        m.setCursorPos(panelX+1,1)
        m.write("KRYPT")
        local str = "#"..tostring(data.chan)
        if selected then
            m.setCursorPos(w-#str,1)
            m.setTextColor(darkColor)
            m.write(str)
        end
        -- Draw Panel Information
        m.setCursorPos(panelX+1,3)
        m.setBackgroundColor(colors.gray)
        if selected then
            local dpos = 3
            if data.map[selectedID] then
                m.setTextColor(colors.white)
            else
                m.setTextColor(colors.orange)
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
                            m.setTextColor(colors.orange)
                            m.write(sensorText)
                        else
                            m.setCursorPos(panelX+1,dpos)
                            m.setTextColor(colors.lightGray)
                            m.write(i)
                            m.setCursorPos(w-#sensorText,dpos)
                            m.setTextColor(colors.orange)
                            m.write(sensorText)
                        end
                    elseif v.type == "Percentage Bar" then
                        local pPos = string.find(i,"<")
                        local pName = i
                        local pColor = colors.orange
                        if pPos then
                            pColor = colors[string.lower(string.sub(i,pPos+1,#i-1))] or colors.orange
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
        end
        -- Event Handling
        local uiTimer = os.startTimer(0.25)
        while true do
            local e,c,x,y = os.pullEvent()
            if selected then
                selected = nodes[selectedID]
            end
            if e == "timer" and c == uiTimer then
                break
            elseif e == "mouse_click" or (c == 2 and e == "mouse_drag") then
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
                            local centerX = panelX/2
                            local centerY = (h-1)/2
                            mapX = mapX - math.floor((x-centerX)/2)
                            mapY = mapY - math.floor((y-centerY)/2)
                            selected = false
                            selectedID = false
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
                    elseif x == panelX-(5+#tostring(mapZ)) or x == panelX-(4+#tostring(mapZ)) then
                        mapZ = mapZ - 1
                    elseif x == panelX-2 then
                        mapZ = mapZ + 1
                    end
                end
                break
            end
        end
    end
end

--/ Kernel /--
parallel.waitForAny(userRoutine,updateRoutine)
