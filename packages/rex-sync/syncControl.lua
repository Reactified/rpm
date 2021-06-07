os.loadAPI("/RSync/**syncApi.lua")

w, h = term.getSize()
term.clear()

local api = syncApi


function drawHeader(header)
    bg = colors.blue
    paintutils.drawFilledBox(1, 1, w, 3, bg)
    term.setBackgroundColor(bg)
    term.setTextColor(colors.white)
    term.setCursorPos(4, 2)
    term.write(header)
    term.setCursorPos(2,2)
    term.write("<")
    term.setCursorPos(w - 1,2)
    term.write(">")
end
function syncControlsMenu()
    paintutils.drawFilledBox(1, 4, w, h, colors.black)

    --Menu items
    term.setBackgroundColor(colors.black)

    term.setTextColor(colors.red)
    term.setCursorPos(2,5)
    term.write(" ^ Upload All Files ")

    term.setTextColor(colors.green)
    term.setCursorPos(2,7)
    term.write(" v Download All Files ")

    term.setTextColor(colors.lightGray)
    term.setCursorPos(2,9)
    term.write(" Clear Message Queue ")

    term.setTextColor(colors.gray)
    term.setCursorPos(2, h - 1)
    term.write(" Sync Client - " .. syncApi.t["ip"] .. ":" .. syncApi.t["port"])

    menuIndex = currentMenu
    while menuIndex == currentMenu do
        os.startTimer(0.25)
        local e, c, x, y = os.pullEvent()
        if e == "mouse_click" then
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
            if y == 5 then
                term.setCursorPos(2,5)
                term.write(" Uploading all files ")
                api.clearMessages()
                api.sendAllFiles()
                sleep(0.5)
                api.clearMessages()
                break
            end
            if y == 7 then
                term.setCursorPos(2,7)
                term.write(" Downloading all files ")
                api.clearMessages()
                api.getAllFiles()
                sleep(0.5)
                api.clearMessages()
                break
            end
            if y == 9 then
                term.setCursorPos(2,9)
                term.write(" Clearing Message Queue ")
                api.clearMessages()
                sleep(0.5)
                break
            end
        end
    end
    if menuIndex == currentMenu then
        syncControlsMenu()
    end
end
search = ""
typing = false
listOffset = 1
currentList = {}
function getValue(index)
    i = index + listOffset
    if i < 1 or i > #currentList then
        return ""
    end
    return currentList[i]
end
function drawMenuList()
    paintutils.drawFilledBox(2, 7, w-1, h-1, colors.black)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    for i = 0, ((h-1) - 7) do
        term.setCursorPos(2,7 + i)
        term.write(getValue(i))
    end
end
function searchFunction(list)
    if search == "" then
        return list
    else
        local returnList = {}
        for i,v in pairs(list) do
            if string.find(v,search) then
                table.insert(returnList,v)
            end
        end
        return returnList
    end
end
function localSyncMenu()
    allList = api.getLocalFiles()
    currentList = searchFunction(allList)
    
    paintutils.drawFilledBox(1, 4, w, h, colors.black)

    --Menu items
    paintutils.drawFilledBox(2, 5, w-1, 5, colors.gray)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2,5)
    term.write(search)

    drawMenuList()

    menuIndex = currentMenu
    while menuIndex == currentMenu do
        os.startTimer(0.25)
        local e, c, x, y = os.pullEvent()
        if e == "mouse_click" then
            if y == 5 then
                typing = true
                while typing do
                    currentList = searchFunction(allList)
                    drawMenuList()
                    
                    paintutils.drawFilledBox(2, 5, w-1, 5, colors.lightGray)
                    term.setBackgroundColor(colors.lightGray)
                    term.setTextColor(colors.white)
                    term.setCursorPos(2,5)
                    term.write(search)

                    local e, key, isHeld = os.pullEvent()
                    if e == "key" then
                        if key == keys.backspace then
                            search = string.sub(search, 0, math.max(#search-1, 0))
                        elseif key == keys.enter then
                            typing = false
                        end
                    elseif e == "char" then
                        search = search .. key
                    end
                end
                break
            elseif y >= 7 and y <= h-1 then
                index = y - 7
                item = getValue(index)
            
                paintutils.drawFilledBox(2, y, w-1, y, colors.grey)
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.setCursorPos(2,y)
                term.write(item)

                api.clearMessages()
                api.sendFile(item)

                sleep(0.5)
                break
            end
        elseif e == "mouse_scroll" then
            listOffset = listOffset + c;
            if listOffset < 1 then
                listOffset = 1
            end
            if listOffset > #currentList then
                listOffset = #currentList
            end
            break
        end
    end
    if menuIndex == currentMenu then
        localSyncMenu()
    end
end
function serverSyncMenu()
    allList = api.getFilesList()
    currentList = searchFunction(allList)
    paintutils.drawFilledBox(1, 4, w, h, colors.black)

    --Menu items
    paintutils.drawFilledBox(2, 5, w-1, 5, colors.gray)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(2,5)
    term.write(search)

    drawMenuList()

    menuIndex = currentMenu
    while menuIndex == currentMenu do
        os.startTimer(0.25)
        local e, c, x, y = os.pullEvent()
        if e == "mouse_click" then
            if y == 5 then
                typing = true
                while typing do
                    currentList = searchFunction(allList)
                    drawMenuList()
                    
                    paintutils.drawFilledBox(2, 5, w-1, 5, colors.lightGray)
                    term.setBackgroundColor(colors.lightGray)
                    term.setTextColor(colors.white)
                    term.setCursorPos(2,5)
                    term.write(search)

                    local e, key, isHeld = os.pullEvent()
                    if e == "key" then
                        if key == keys.backspace then
                            search = string.sub(search, 0, math.max(#search-1, 0))
                        elseif key == keys.enter then
                            typing = false
                        end
                    elseif e == "char" then
                        search = search .. key
                    end
                end
                break
            elseif y >= 7 and y <= h-1 then
                index = y - 7
                item = getValue(index)
            
                paintutils.drawFilledBox(2, y, w-1, y, colors.grey)
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.white)
                term.setCursorPos(2,y)
                term.write(item)

                api.clearMessages()
                api.getFile(item)

                sleep(0.5)
                break
            end
        elseif e == "mouse_scroll" then
            listOffset = listOffset + c;
            if listOffset < 1 then
                listOffset = 1
            end
            if listOffset > #currentList then
                listOffset = #currentList
            end
            break
        end
    end
    if menuIndex == currentMenu then
        serverSyncMenu()
    end

end
menuCount = 3
currentMenu = 1
menus = {
    ["Sync Controls"] = syncControlsMenu,
    ["Upload to Server"] = localSyncMenu,
    ["Download from Server"] = serverSyncMenu
}
menuIndexs = {
    "Sync Controls",
    "Upload to Server",
    "Download from Server"
}
function drawUI()
    menuName = menuIndexs[currentMenu]
    menus[menuName]()
end

function frontend()
    while true do
        drawUI()
    end
end

function backend()
    while true do
        menuName = menuIndexs[currentMenu]
        drawHeader(menuName)
    
        local e, c, x, y = os.pullEvent("mouse_click")
        if typing == false then
            if y < 4 then
                if x < 4 then
                    currentMenu = currentMenu - 1
                    if currentMenu < 1 then
                        currentMenu = menuCount
                    end
                else
                    currentMenu = currentMenu + 1
                    if currentMenu > menuCount then
                        currentMenu = 1
                    end
                end
            end
        end
    end
end

parallel.waitForAll(frontend,backend)


paintutils.drawFilledBox(2, 5, w-1, h - 1, colors.gray)
