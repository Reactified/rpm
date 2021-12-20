-- React Tracker
local speaker = peripheral.find("speaker")

-- Core Functions
local function tableInverse(tbl)
    local invTable = {}
    for i,v in pairs(tbl) do
        invTable[v] = i
    end
    return invTable
end

local function d2str(num,len)
    local len = len or 2
    local str = tostring(math.floor(num))
    if #str > len then
        str = string.sub(str,#str-len+1,#str)
    end
    str = string.rep("0",len-#str) .. str
    return str
end

local function tno(switch,on,off)
    if switch then
        return on
    else
        return off
    end
end

local function n2sort(n1,n2)
    if n1 > n2 then
        return n2,n1
    else
        return n1,n2
    end
end

local function cloneTable(tbl)
    local newTbl = {}
    for i,v in pairs(tbl) do
        newTbl[i] = v
    end
    return newTbl
end

-- Song Variables
local instruments = {
    {"BIT", "bit"},
    {"PIANO", "harp"},
    {"GUITAR", "guitar"},
    {"FLUTE", "flute"},
    {"BASS", "bass"},
    {"SNARE", "snare"},
    {"HIHAT", "hat"},
    {"PLING", "pling"},
}
local tracks = {{},{},{},{}}
local bpm = 240


-- File Management
local filename = "song.rt"
local function saveFile()
    f = fs.open(filename,"w")
    f.writeLine(textutils.serialise({
        reactTracker = true,
        tracks = tracks,
        bpm = bpm,
    }))
    f.close()
end
local function loadFile()
    f = fs.open(filename,"r")
    local filedata = textutils.unserialise(f.readAll())
    f.close()
    if filedata.reactTracker then
        tracks = filedata.tracks
        bpm = filedata.bpm
    end
end


-- Audio Functions
function playNote(note)
    local insData = instruments[note[2]]
    
    if insData then
        insData = insData[2]
        if type(insData) == "string" then
            speaker.playNote(insData,note[3],note[1])
        end
    end
end

local noteTable = {
    [0] = "F#0", "G-0", "G#0", "A-1", "A#1", "B-1", "C-1", "C#1", "D-1", "D#1", "E-1", "F-1", "F#1", "G-1", "G#1", "A-2", "A#2", "B-2", "C-2", "C#2", "D-2", "D#2", "E-2", "F-2", "F#2"
}
local invNoteTable = tableInverse(noteTable)

function num2note(num)
    return noteTable[num]
end
function note2num(note)
    return invNoteTable[note]
end

-- Example
playNote({
    2, -- pitch
    1, -- instrument
    0.5, -- volume
})


-- Theme
local ui = {
    colors.black,
    colors.gray,
    colors.lightGray,
    colors.white,
    colors.lightGray,
    colors.blue,
    colors.cyan,
    colors.purple,
}


-- Variables
local playing = false
local row = 1
local trk = 1
local instr = 1
local trcpos = 5
local volume = 1
local select = false


-- Interface
local t = {
    clr = term.clear,
    cur = term.setCursorPos,
    bg = term.setBackgroundColor,
    txt = term.setTextColor,
    w = term.write,
}

local function renderTrack(nTrack,xPos,yPos,vSize)
    local dTrack = tracks[nTrack]
    for y=yPos,yPos+(vSize-1) do
        local nRow = (y-yPos+row)-2
        local note
        if dTrack then
            note = dTrack[nRow]
        end
        local so = 0
        if row == nRow then
            so = 3
        end
        if select then
            local r1,r2 = n2sort(select,row)
            if nRow >= r1 and nRow <= r2 then
                so = 3
            end
        end
        -- clear
        t.cur(xPos,y)
        t.bg(ui[1])
        t.txt(ui[2+so])
        t.w(string.rep(tno(dTrack,"."," "),7))
        -- write
        if note then
            t.cur(xPos,y)
            t.txt(ui[4+so])
            t.w(num2note(note[1]))

            t.cur(xPos+4,y)
            t.txt(ui[3+so])
            t.w(d2str(note[2]))

            t.cur(xPos+6,y)
            t.txt(ui[2+so])
            t.w(d2str((note[3]*10)-1,1))
        end
        -- end
        t.cur(xPos+7,y)
        t.txt(ui[2])
        t.w("|")
    end
end

local function terminalEntry(prompt)
    local w,h = term.getSize()
    t.cur(1,h)
    t.bg(ui[1])
    t.txt(ui[3])
    t.w(string.rep(" ",w))

    t.cur(1,h)
    t.w(prompt..": ")
    t.txt(ui[4])
    return read()
end

local function fullRender()
    -- setup
    local w,h = term.getSize()
    t.bg(ui[2])
    t.clr()
    -- row indicator
    for i=trcpos+1,h do
        local dRow = i-(trcpos+3)+row
        t.cur(1,i)
        t.bg(ui[1])
        local so = tno(dRow == row,3,0)
        if select then
            local r1,r2 = n2sort(select,row)
            if dRow >= r1 and dRow <= r2 then
                so = 3
            end
        end
        t.txt(ui[3+so])
        if dRow > 0 then
            t.w(d2str(dRow,3))
        else
            t.w(string.rep(" ",3))
        end
        t.txt(ui[2])
        t.w("|")
    end
    -- trackers
    for i=1,math.floor(w/8)+1 do
        renderTrack(i,-3+(i*8),trcpos+1,h-trcpos)
        t.cur(-3+(i*8),trcpos)
        t.bg(ui[2+tno(i==trk,2,0)])
        t.txt(ui[1])
        if #tracks >= i then
            t.w("TRK "..d2str(i).." ")
        end
    end
    -- instruments panel
    for i=1,3 do
        t.cur(w-14,i+1)
        t.bg(ui[1])
        t.w(string.rep(" ",14))

        local dIns = (i+instr)-2
        t.cur(w-13,i+1)
        if instruments[dIns] then
            local so = tno(dIns==instr,3,0)
            t.txt(ui[3+so])
            t.w(d2str(dIns).." ")
            t.txt(ui[2+so])
            t.w(instruments[dIns][1])
        elseif dIns == 0 then
            t.txt(ui[2])
            t.w("INSTRUMENTS")
        end
    end
    -- react tracker logo
    t.cur(2,2)
    t.bg(ui[2])
    t.txt(ui[tno(playing,3,1)])
    t.w("REACT")
    t.cur(2,3)
    t.w("TRACKER")
end

local menus = {
    ["REACT"] = {
        width = 10,
        {"FILE","FILE"},
        {"SETTINGS","SETTINGS"},
    },
    ["FILE"] = {
        width = 6,
        {"SAVE",function()
            filename = terminalEntry("SAVE FILENAME")
            saveFile();
        end,},
        {"LOAD",function()
            filename = terminalEntry("LOAD FILENAME")
            loadFile();
        end,},
    },
    ["SETTINGS"] = {
        width = 10,
        {"TEMPO",function()
            local tempoInput = terminalEntry("SET TEMPO")
            if tonumber(tempoInput) then
                bpm = tonumber(tempoInput)
            end
        end,},
        {"+ TRACK",function()
            table.insert(tracks,{})
        end,},
        {"- TRACK",function()
            table.remove(tracks,#tracks)
        end,},
    },
}
local function openMenu(menuName,xPos,yPos)
    local menu = menus[menuName]
    local sel = 1
    local width = menu.width or 10
    while true do
        -- draw menu name
        t.cur(xPos,yPos)
        t.bg(ui[3])
        t.w(string.rep(" ",width))
        
        t.cur(xPos+1,yPos)
        t.txt(ui[2])
        t.w(menuName)

        -- draw menu options
        for i,v in pairs(menu) do
            if type(i) == "number" then
                local so = tno(sel==i,3,0)

                t.cur(xPos,yPos+i)
                t.bg(ui[3+so])
                t.w(string.rep(" ",width))

                t.cur(xPos+1,yPos+i)
                t.txt(ui[1+so])
                t.w(v[1])
            end
        end

        local _,k = os.pullEvent("key")
        if k == keys.down then
            if sel < #menu then
                sel = sel + 1
            end
        elseif k == keys.up then
            if sel > 1 then
                sel = sel - 1
            end
        elseif k == keys.grave then
            break
        elseif k == keys.enter then
            t.cur(xPos,yPos+sel)
            t.bg(ui[2])
            t.w(string.rep(" ",width))

            t.cur(xPos+1,yPos+sel)
            t.txt(ui[3])
            t.w(menu[sel][1])

            local cmd = menu[sel][2]
            if type(cmd) == "string" then
                openMenu(cmd,xPos+width,yPos+sel)
                break
            elseif type(cmd) == "function" then
                cmd()
                break
            end
        end
    end
end


-- Control Functions
function noteTune(offset)
    if row < 1 then return end
    if tracks[trk] then
        local data = tracks[trk][row]
        if data then
            data[1] = data[1] + offset
            if data[1] > 24 then data[1] = 24 end
            if data[1] < 0 then data[1] = 0 end
            tracks[trk][row] = data
        else
            local prevPitch = 12
            for i=1,4 do
                if tracks[trk][row-i] then
                    prevPitch = tracks[trk][row-i][1]
                    break
                end
            end
            if prevPitch <= 0 then
                prevPitch = 1
            elseif prevPitch >= 24 then
                prevPitch = 23
            end
            tracks[trk][row] = {prevPitch+offset,instr,volume}
        end
        playNote(tracks[trk][row])
    end
end


-- Controls
local controls = {
    [keys.left] = {
        function()
            trk = trk - 1
            if trk < 1 then
                trk = #tracks
            end
        end,
        "<-",
        "Previous track",
    },
    [keys.right] = {
        function()
            trk = trk + 1
            if trk > #tracks then
                trk = 1
            end
        end,
        "->",
        "Next track",
    },
    [keys.up] = {
        function()
            row = row - 1
        end,
        "UP",
        "Previous row",
    },
    [keys.down] = {
        function()
            row = row + 1
        end,
        "DOWN",
        "Next row",
    },
    [keys.space] = {
        function()
            playing = not playing
            if playing then
                os.queueEvent("start-playback")
            end
        end,
        "SPACE",
        "Play/pause",
    },
    [keys.leftBracket] = {
        function()
            instr = instr - 1
            if instr < 1 then
                instr = #instruments
            end
        end,
        "[",
        "Previous instrument",
    },
    [keys.rightBracket] = {
        function()
            instr = instr + 1
            if instr > #instruments then
                instr = 1
            end
        end,
        "]",
        "Next instrument",
    },
    [keys.pageUp] = {
        function()
            row = row - 8
            if row < 1 then
                row = 1
            end
        end,
        "PGUP",
        "Previous page",
    },
    [keys.pageDown] = {
        function()
            row = row + 8
        end,
        "PGDN",
        "Next page",
    },
    [keys.enter] = {
        function()
            if row < 1 then return end

            t.cur(-3+(trk*8),trcpos+3)
            t.bg(ui[1])
            t.txt(ui[8])
            t.w("   ")

            t.cur(-3+(trk*8),trcpos+3)
            local input = string.upper(read())

            if #input == 2 then
                input = string.sub(input,1,1) .. "-" .. string.sub(input,2,2)
            end

            if note2num(input) then
                tracks[trk][row] = {note2num(input), instr, volume}
                row = row + 1
            end
        end,
        "ENTER",
        "Input note",
    },
    [keys.grave] = {
        function()
            openMenu("REACT",1,1)
        end,
        "GRAVE",
        "Open menu",
    },
    [keys.q] = {
        function()
            noteTune(-1)
        end,
        "Q",
        "Note -",
    },
    [keys.e] = {
        function()
            noteTune(1)
        end,
        "E",
        "Note +",
    },
    [keys.c] = {
        function()
            if select then
                local r1,r2 = n2sort(row,select)
                for i=r1,r2 do
                    if tracks[trk][i] then
                        tracks[trk][i+(r2-r1)+1] = cloneTable(tracks[trk][i])
                    else
                        tracks[trk][i+(r2-r1)+1] = nil
                    end
                end
            else
                noteTune(0)
            end
        end,
        "C",
        "Copy note",
    },
    [keys.x] = {
        function()
            if select then
                local r1,r2 = n2sort(row,select)
                for i=r1,r2 do
                    tracks[trk][i] = nil
                end
            else
                tracks[trk][row] = nil
            end
        end,
        "X",
        "Delete note",
    },  
    [keys.leftShift] = {
        function()
            if select then
                select = false
            else
                select = row
            end
        end,
        "SHIFT",
        "Row selection",
    },
}
function showControls()
    local w,h = term.getSize()
    t.bg(ui[1])
    t.clr()
    t.cur(2,2)
    t.txt(ui[2])
    t.w("CONTROLS")
    local x,y = 2,4
    for i,v in pairs(controls) do
        t.cur(x,y)
        t.txt(ui[7])
        t.w(v[2])

        t.cur(x+7,y)
        t.txt(ui[3])
        t.w(v[3])

        y = y + 1
        if y >= h-1 then
            y = 4
            x =x + 30
        end
    end
    os.pullEvent("key")
    os.queueEvent("render-update")
end

aliases = {
    [keys.w] = keys.up,
    [keys.a] = keys.left,
    [keys.s] = keys.down,
    [keys.d] = keys.right,
}


-- Routines
routines = {
    interface = function()
        while true do
            fullRender()
    
            -- Event Core
            while true do
                local e = {os.pullEvent()}
                -- render update request
                if e[1] == "render-update" then
                    break
                end
                -- control input
                if e[1] == "key" then
                    local aliasKey = aliases[e[2]] or e[2]
                    if controls[aliasKey] then
                        controls[aliasKey][1]()
                        break
                    elseif aliasKey == keys.h then
                        showControls()
                    end
                end
            end
        end
    end,

    playback = function()
        while true do
            os.pullEvent("start-playback")
            while playing do
                row = row + 1
                for trackNum,trackData in pairs(tracks) do
                    local rowData = trackData[row]
                    if rowData then
                        playNote(rowData)
                    end
                end
                os.queueEvent("render-update")
                sleep(60/bpm)
            end
        end
    end,
}

-- Execute
parallel.waitForAny(routines.interface, routines.playback)
