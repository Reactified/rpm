--/ Krypt Node / Reactified /--
local modem = peripheral.find("modem")
local sanitizeData = {
    ["password"] = true,
}

--/ Data Persistence /--
local data = {
    status = true,
    io = {},
}
local init = false
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
        limeoutTmr = os.startTimer(timeout)
    end
    while true do
        local e,s,c,r,m = os.pullEvent()
        if e == "modem_message" and c == data.chan/76 and type(m) == "table" and m.krypt then
            if (r == filter or not filter) and (m.target == os.getComputerID() or m.target == true) and m.integrity == data.chan*#textutils.serialise(m.data) then
                return m.data
            end
        elseif e == "timer" then
            if s == timeoutTmr then
                return false
            end
        end
    end
end

--/ Special Functions /--
local function updateAttribute(aName,aValue)
    send({command="[UPDATE-ATTRIBUTE]",attribute=aName,value=aValue})
end

--/ First Time Setup /--
if init then
    term.setBackgroundColor(colors.gray)
    term.clear()
    term.setCursorPos(1,1)
    if term.isColor() then
        term.setBackgroundColor(colors.green)
    else
        term.setBackgroundColor(colors.lightGray)
    end
    term.clearLine()
    term.setCursorPos(2,1)
    term.setTextColor(colors.black)
    write("KRYPT NODE ")
    term.setTextColor(colors.gray)
    write("- ")
    term.setTextColor(colors.gray)
    write("FIRST TIME SETUP")
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.lightGray)
    term.setCursorPos(2,3)
    write(">> Welcome")
    term.setCursorPos(2,4)
    write("To initialize this KRYPT node")
    term.setCursorPos(2,5)
    if not modem then
        write("Please attach a modem")
        sleep(5)
        os.reboot()
    end
    write("input the Mainframe ID.")
    term.setCursorPos(2,7)
    term.setTextColor(colors.white)
    write("> #")
    local input = read()
    term.setCursorPos(2,9)
    term.setTextColor(colors.lightGray)
    if not tonumber(input) then
        write("Invalid entry.")
        sleep(2)
        os.reboot()
    else
        data.chan = tonumber(input)
        modem.open(data.chan/76)
        print("Connecting...")
        sleep(1)
        send("[PAIRING-REQUEST]")
        local msg = recv(2)
        if msg == "[PAIRING-ACCEPTED]" then
            print(" Success!")
            print()
            print(" Name this node")
            print()
            term.setTextColor(colors.white)
            write(" > ")
            data.name = read()
            os.setComputerLabel(data.name)
            updateAttribute("name",data.name)
            print()
            term.setTextColor(colors.lightGray)
            sleep(1)
            print(" This node is now initialized.")
            sleep(2)
            saveData()
        else
            print(" Failed.")
            print()
            sleep(1)
            print(" Verify server status and")
            print(" attempting pairing again")
            sleep(5)
            os.reboot()
        end
    end
end

--/ Initialization /--
modem.open(data.chan/76)

--/ UI Functions /--
function listSelect(options,title)
    local cursor = 1
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        if term.isColor() then
            term.setTextColor(colors.green)
        else
            term.setTextColor(colors.gray)
        end
        term.setCursorPos(2,2)
        write("KRYPT ")
        term.setTextColor(colors.lightGray)
        write(data.name)
        term.setTextColor(colors.gray)
        write(" | "..title)
        local dPos = 2
        for i,v in pairs(options) do
            term.setCursorPos(2,2+dPos)
            term.setBackgroundColor(colors.black)
            if cursor == dPos-1 then
                term.setTextColor(colors.white)
                term.write("> "..v)
            else
                term.setTextColor(colors.lightGray)
                term.write(" "..v)
            end
            dPos = dPos + 1
        end
        local e,k = os.pullEvent("key")
        if e == "key" then
            if k == keys.down then
                if cursor < #options then
                    cursor = cursor+1
                end
            elseif k == keys.up then
                if cursor > 1 then
                    cursor = cursor-1
                end
            elseif k == keys.enter then
                return options[cursor]
            end
        end
    end
end

--/ UI Routine /--
local function uiRoutine()
    while true do
        if data.password then
            os.pullEvent = os.pullEventRaw
            while true do
                term.setBackgroundColor(colors.black)
                term.clear()
                if term.isColor() then
                    term.setTextColor(colors.green)
                else
                    term.setTextColor(colors.gray)
                end
                term.setCursorPos(2,2)
                write("KRYPT ")
                term.setTextColor(colors.lightGray)
                write(data.name)
                term.setTextColor(colors.gray)
                write(" | Console Locked")
                term.setCursorPos(2,4)
                term.setTextColor(colors.lightGray)
                term.write("Enter password")
                term.setCursorPos(2,5)
                term.setTextColor(colors.white)
                term.write("> ")
                local pass = read("*")
                term.setCursorPos(2,7)
                term.setTextColor(colors.green)
                if pass == data.password then
                    data.password = nil
                    saveData()
                    write("Welcome!")
                    sleep(0.5)
                    break
                else
                    write("Incorrect password.")
                    sleep(2)
                end
            end
        end
        local sel = listSelect({"Interfaces","Settings","Lockout"},"Maintainence Menu")
        if sel == "Settings" then
            local sel = listSelect({"- Return","Terminate"},"Settings Menu")
            if sel == "Terminate" then
                term.setTextColor(colors.red)
                print(" >> NODE TERMINATED <<")
                term.setCursorPos(1,15)
                shell.run('shell')
            end
        elseif sel == "Lockout" then
            term.setBackgroundColor(colors.black)
            term.clear()
            if term.isColor() then
                term.setTextColor(colors.green)
            else
                term.setTextColor(colors.gray)
            end
            term.setCursorPos(2,2)
            write("KRYPT ")
            term.setTextColor(colors.lightGray)
            write(data.name)
            term.setTextColor(colors.gray)
            write(" | Lock Console")
            term.setCursorPos(2,4)
            term.setTextColor(colors.lightGray)
            term.write("Set password")
            term.setCursorPos(2,5)
            term.setTextColor(colors.white)
            term.write("> ")
            local pass1 = read("*")
            term.setCursorPos(2,7)
            term.setTextColor(colors.lightGray)
            term.write("Confirm password")
            term.setCursorPos(2,8)
            term.setTextColor(colors.white)
            write("> ")
            local pass2 = read("*")
            term.setCursorPos(2,10)
            term.setTextColor(colors.green)
            if pass1 == pass2 then
                write("Password set!")
                data.password = pass1
                saveData()
            else
                write("Passwords do not match.")
            end
            sleep(1)
        elseif sel == "Interfaces" then
            while true do
                local selList = {"- Return"}
                for i,v in pairs(data.io) do
                    selList[#selList+1] = i
                end
                selList[#selList+1] = "+ Create New"
                local sel = listSelect(selList,"Node Interfaces")
                if sel == "+ Create New" then
                    local sel = listSelect({
                        "Toggle Control",
                        "Push Control",
                        "Basic Sensor",
                        "Percentage Bar",
                        "- Cancel",
                    },"Create Interface")
                    if sel ~= "- Cancel" then
                        -- Name Interface
                        local intf = {
                            type = sel,
                        }
                        term.setBackgroundColor(colors.black)
                        term.clear()
                        if term.isColor() then
                            term.setTextColor(colors.green)
                        else
                            term.setTextColor(colors.gray)
                        end
                        term.setCursorPos(2,2)
                        write("KRYPT ")
                        term.setTextColor(colors.lightGray)
                        write(data.name)
                        term.setTextColor(colors.gray)
                        write(" | Create Interface")
                        term.setCursorPos(2,4)
                        term.setTextColor(colors.lightGray)
                        term.write("Name Interface")
                        term.setCursorPos(2,5)
                        term.setTextColor(colors.white)
                        term.write("> ")
                        local intfname = read()
                        -- Text Editor
                        local intf = {}
                        intf.type = sel
                        term.setBackgroundColor(colors.black)
                        term.clear()
                        if term.isColor() then
                            term.setTextColor(colors.green)
                        else
                            term.setTextColor(colors.gray)
                        end
                        term.setCursorPos(2,2)
                        write("KRYPT ")
                        term.setTextColor(colors.lightGray)
                        write(data.name)
                        term.setTextColor(colors.gray)
                        write(" | Create Interface")
                        term.setCursorPos(2,4)
                        term.setTextColor(colors.lightGray)
                        term.write(sel.." ")
                        term.setCursorPos(2,5)
                        term.setTextColor(colors.gray)
                        write("To program this interface write a script that:")
                        term.setCursorPos(2,6)
                        if sel == "Toggle Control" then
                            write("Sets the ")
                            term.setTextColor(colors.green)
                            write("interface")
                            term.setTextColor(colors.gray)
                            write(" to the ")
                            term.setTextColor(colors.green)
                            write("state")
                            term.setTextColor(colors.gray)
                            write(" variable")
                            intf.state = false
                        elseif sel == "Push Control" then
                            write("Runs when the ")
                            term.setTextColor(colors.green)
                            write("button ")
                            term.setTextColor(colors.gray)
                            write("is ")
                            term.setTextColor(colors.green)
                            write("clicked")
                        elseif sel == "Basic Sensor" then
                            write("Return the ")
                            term.setTextColor(colors.green)
                            write("data ")
                            term.setTextColor(colors.gray)
                            write("to display on the ")
                            term.setTextColor(colors.green)
                            write("sensor ")
                        elseif sel == "Percentage Bar" then
                            write("Return the ")
                            term.setTextColor(colors.green)
                            write("percentage ")
                            term.setTextColor(colors.gray)
                            write("as a ")
                            term.setTextColor(colors.green)
                            write("0 - 1")
                        end
                        term.setTextColor(colors.white)
                        term.setCursorPos(2,8)
                        term.setTextColor(colors.lightGray)
                        write("Script:")
                        term.setCursorPos(2,9)
                        term.setBackgroundColor(colors.gray)
                        term.setTextColor(colors.white)
                        term.write(string.rep(" ",term.getSize()-2))
                        term.setCursorPos(3,9)
                        intf.script = read()
                        term.setCursorPos(2,11)
                        term.setBackgroundColor(colors.black)
                        term.setTextColor(colors.green)
                        if #intf.script > 4 then
                            write("Interface Created!")
                            data.io[intfname] = intf
                            saveData()
                        else
                            write("Interface Creation Cancelled.")
                        end
                        sleep(2)
                    end
                elseif data.io[sel] then
                    local selx = listSelect({"- Return","Delete"},data.io[sel].type)
                    if selx == "Delete" then
                        data.io[sel] = nil
                        saveData()
                    end
                elseif sel == "- Return" then
                    break
                end
            end
        end
    end
end

--/ NODE Routine /--
local function updateIoOutput(interf,val)
    data.io[interf].output = val
end
local function execute(interf)
    local func = loadstring(data.io[interf].script)
    local env = getfenv(function() end)
    env["state"] = data.io[interf].state
    setfenv(func,env)
    local ok,err = pcall(func)
    if ok then
        updateIoOutput(interf,err or "N/A")
    else
        updateIoOutput(interf,"ERROR")
    end
    saveData()
end
local function nodeRoutine()
    while true do
        local msg = recv()
        if msg == "[STATUS-UPDATE]" then
            cleandata = {}
            for i,v in pairs(data) do
                if not sanitizeData[i] then
                    cleandata[i] = v
                end
            end
            send(cleandata)
        elseif msg == "[NODE-UPDATE]" then
            shell.run("rpm update")
        elseif msg == "[NODE-REBOOT]" then
            sleep(8)
            os.reboot()
        elseif type(msg) == "table" then
            if msg.command == "[IO-UPDATE]" and data.io[msg.interface] then
                local interf = data.io[msg.interface]
                if interf.type == "Toggle Control" then
                    data.io[msg.interface].state = msg.value
                elseif interf.type == "Push Control" then
                    -- push code but none needed right now
                end
                execute(msg.interface)
            end
        end
    end
end

--/ Threading /--
parallel.waitForAll(nodeRoutine,uiRoutine)
