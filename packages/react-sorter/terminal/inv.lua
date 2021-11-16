-- Sorting Terminal
local chestID = 104

-- APIS
os.loadAPI("/apis/sorter.lua")

-- Palette
local palette = {
    colors.black,
    colors.gray,
    colors.lightGray,
    colors.white,
    colors.cyan,
}

-- UI Functions
local function center(str,ln)
    local w,h = term.getSize()
    term.setCursorPos(w/2-(#str/2),ln)
    write(str)
end
local function setColor(fgCol,bgCol)
    fgCol = fgCol + 1
    bgCol = bgCol + 1
    term.setTextColor(palette[fgCol])
    if bgCol then
        term.setBackgroundColor(palette[bgCol])
    end
end

-- Inventory Routine
local totals = {}
local orderedTotals = {}
local function invRoutine()
    while true do
        totals = sorter.totals()
        orderedTotals = {}
        if totals then
            for i,v in pairs(totals) do
                orderedTotals[#orderedTotals+1] = {i,v}
            end
            table.sort(orderedTotals, function(aValue,bValue) 
                if aValue and bValue then
                    return aValue[2] > bValue[2]
                else
                    print(aValue,bValue)
                    end
            end)
        end
        sleep(5)
    end
end

-- UI Routine
local function uiRoutine()
    local searchTerm = ""
    local scrollDist = 0
    local selectedItem = false
    
    local timersToCancel = {}
    
    while true do
        -- init
        for i,v in pairs(timersToCancel) do
            os.cancelTimer(v)
        end
        timersToCancel = {}
        local w,h = term.getSize()
        
        -- list
        local list = {}
        for _,v in pairs(orderedTotals) do
            local i,v = v[1],v[2]
            local meetsCriteria = true
            if searchTerm ~= "" then
                if not string.find(string.lower(i),string.lower(searchTerm)) then
                    meetsCriteria = false
                end
            end
            if meetsCriteria then
                list[#list+1] = i
            end
        end
        
        
        -- selected item
        if #list > 0 and not selectedItem then
            selectedItem = 1
        elseif #list == 0 then
            selectedItem = false
        elseif selectedItem > #list then
            selectedItem = #list
        end
        if selectedItem then
            if selectedItem > scrollDist+(h-2) then
                selectedItem = scrollDist+(h-2)
            elseif selectedItem < scrollDist+1 then
                selectedItem = scrollDist+1
            end
        end
        local selected = list[selectedItem]
        
        -- draw
        setColor(0,0)
        term.clear()
        term.setCursorPos(1,1)
        setColor(2,1)
        term.clearLine()
        term.setCursorPos(2,1)
        if searchTerm == "" then
            write("Inventory")
        else
            setColor(3,1)
            write(searchTerm)
        end
        term.setCursorPos(2,h)
        setColor(2,0)
        write("ENTER = Pull   DELETE = Push")
    
        if totals then
            for listHeight = 1,h-2 do
                local drawHeight = listHeight+1
                local listIndex = listHeight+scrollDist
                local listItem = list[listIndex]
                if listItem then
                    term.setCursorPos(1, drawHeight)
                    if selectedItem and selectedItem == listIndex then
                        setColor(0,4)
                    else
                        setColor(3,0)
                    end
                    term.clearLine()
                    term.setCursorPos(2, drawHeight)
                    write(listItem.." x"..tostring(totals[listItem]))
                end
            end
        else
            term.setTextColor(colors.red)
            term.setBackgroundColor(colors.black)
            center("Storage array offline",h/2)
            table.insert(timersToCancel,os.startTimer(0.5))
        end
        
        local e = {os.pullEvent()}
        if e[1] == "mouse_scroll" then
            scrollDist = scrollDist + e[2]
            if scrollDist < 0 then
                scrollDist = 0
            elseif scrollDist > #list then
                scrollDist = #list
            end
        elseif e[1] == "mouse_click" then
            if e[4] > 1 then
                selectedItem = (e[4]-1)+scrollDist
            end
        elseif e[1] == "char" then
            searchTerm = searchTerm .. e[2]
        elseif e[1] == "key" then
            if e[2] == keys.delete then
                sorter.clearChest(chestID)
            elseif e[2] == keys.backspace then
                searchTerm = string.sub(searchTerm,1,#searchTerm-1)
            elseif e[2] == keys.pageDown then
                scrollDist = scrollDist + h
                if scrollDist > #list then
                    scrollDist = #list
                end
            elseif e[2] == keys.pageUp then
                scrollDist = scrollDist - h
                if scrollDist < 0 then
                    scrollDist = 0
                end
            end
            if selectedItem then
                if e[2] == keys.down then
                    selectedItem = selectedItem + 1
                    if selectedItem > #list then
                        selectedItem = #list
                    end
                    if selectedItem > scrollDist+(h-2) then
                        scrollDist = scrollDist + 1
                    end
                elseif e[2] == keys.up then
                    selectedItem = selectedItem - 1
                    if selectedItem < 1 then
                        selectedItem = 1
                    end
                    if selectedItem < scrollDist + 1 then
                        scrollDist = scrollDist - 1
                    end
                elseif e[2] == keys.enter then
                    term.setCursorPos(1,h)
                    setColor(2,0)
                    term.clearLine()
                    write(" Quantity > ")
                    local quantity = tonumber(read()) or 1
                    sorter.unmanageChest(chestID)
                    sorter.fillChest(chestID,selected,quantity)
                end
            end
        end
    end
end

-- Start
parallel.waitForAny(uiRoutine,invRoutine)
