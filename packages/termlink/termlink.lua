--[[               TERMLINK CC                 ]]--

-- A recreation of the terminals found
-- throughout the world of fallout.

os.pullEvent = os.pullEventRaw
bootOptions = true
forceWhite = false

--[[ Setup Terminal GPU ]]--

if forceWhite then
  function term.isColor()
    return false
  end
end
if fs.exists("/os") then
  firstRun = false
else
  firstRun = true
end
rendering = true
frame = {}
cursorX = 0
cursorY = 0
cursorTrail = false
local width,height = term.getSize()
for x=1,width do
  frame[x] = {}
  for y=1,height do
    frame[x][y] = {
      fill = false,
      char = " ",
    }
  end
end
function redraw()
  term.setCursorBlink(false)
  if rendering then
    pixCol = colors.white
    for x=1,width do
      for y=1,height do
        if term.isColor() then
          pixCol = colors.lime
        else
          pixCol = colors.white
        end
        if frame[x] then
          if frame[x][y] then
            term.setCursorPos(x,y)
            if frame[x][y]["fill"] then
              term.setBackgroundColor(pixCol)
              term.setTextColor(colors.black)
            else
              term.setBackgroundColor(colors.black)
              term.setTextColor(pixCol)
            end
            write(frame[x][y]["char"])
          end
        end
      end
    end
  end
  if cursorX ~= 0 and cursorY ~= 0 and cursorX and cursorY then
    term.setCursorPos(cursorX,cursorY)
    term.setCursorBlink(true)
  else
    term.setCursorBlink(false)
  end
end
function writeText(str,xPos,yPos,fill)
  if not fill then
    fill = false
  end
  for i=1,#str do
    if xPos >= 1 and xPos <= width and yPos >= 1 and yPos <= height then
      frame[xPos][yPos] = {
        fill = fill,
        char = string.sub(str,i,i),
      }
    end
    xPos = xPos + 1
  end
  redraw()
end
function slowWrite(str,xPos,yPos,fill)
  if not fill then
    fill = false
  end
  for i=1,#str do
    if xPos >= 1 and xPos <= width and yPos >= 1 and yPos <= height then
      frame[xPos][yPos] = {
        fill = fill,
        char = string.sub(str,i,i),
      }
    end
    xPos = xPos + 1
    if cursorTrail then
      cursorX = xPos
      cursorY = yPos
    end
    redraw()
    sleep(0) 
  end
end
function fillLine(yPos)
  for xPos=1,width do
    frame[xPos][yPos] = {
      fill = true,
      char = " ",
    }
  end
  redraw()
end
function clearScreen()
  for xPos=1,width do
    for yPos=1,height do
      frame[xPos][yPos] = {
        fill = false,
        char = " ",
      }
    end
  end
  redraw()
end
function setCursor(xPos,yPos)
  if cursorX == false then
    cursorX = 0
    cursorY = 0
  else
    cursorX = xPos
    cursorY = yPos
  end
  redraw()
end
function readInput(xPos,yPos,char)
  inputStr = ""
  while true do
    if char then
      writeText(string.rep(char,#inputStr),xPos,yPos)
    else
      writeText(inputStr,xPos,yPos)
    end
    cursorX = xPos+#inputStr
    cursorY = yPos
    redraw()
    evt,key = os.pullEvent()
    if evt == "char" then
      inputStr = inputStr..key
    elseif evt == "key" then
      if key == keys.backspace then
        inputStr = string.sub(inputStr,1,#inputStr-1)
        frame[xPos+(#inputStr)][yPos] = {
          fill = false,
          char = " ",
        }
      elseif key == keys.enter then
        setCursor(false)
        return inputStr
      end
    end
  end
end
function centerText(str,yPos,slow,fill)
  max = width / 2
  max = max - ( #str / 2 )
  if slow then
    slowWrite(str,max,yPos,fill)
  else
    writeText(str,max,yPos,fill)
  end
end
function scrollMenu(yPos,entries)
  select = 1
  yPos = yPos - 1
  while true do
    for i,v in pairs(entries) do
      if i == select then
        fill = true
      else
        fill = false
      end
      writeText(" "..v.." ",2,yPos+i,fill)
    end
    redraw()
    evt,key = os.pullEvent("key")
    if key == keys.up and select > 1 then
      select = select - 1
    end
    if key == keys.down and select < #entries then
      select = select + 1
    end
    if key == keys.enter then
      return select
    end
  end
end
function log(str)
  f = fs.open("/os/log","a")
  f.writeLine(str)
  f.close()
end

--[[ Main OS ]]--

function mainRoutine()
  if firstRun then
    clearScreen()
    fillLine(1)
    writeText("Initial Setup",2,1,true)
    slowWrite("Hello!",2,3)
    slowWrite("Welcome to Termlink,",2,5)
    slowWrite("this interface will guide",2,6)
    slowWrite("you through installing your",2,7)
    slowWrite("new operating system!",2,8)
    writeText("Press enter to advance",29,18)
    scrollMenu(18,{"Next"})
    clearScreen()
    fillLine(1)
    writeText("Initial Setup",2,1,true)
    slowWrite("Downloading files...",2,3)
    fs.makeDir("/os")
    h = http.get("https://raw.github.com/jakemroman/JakeHub/master/sha256")
    if not h then
      fs.delete("/os")
      error("No connection!")
    end
    f = fs.open("/os/sha256","w")
    f.writeLine(h.readAll())
    h.close()
    f.close()
    f = fs.open("/os/attempts","w")
    f.writeLine("3")
    f.close()
    f = fs.open("/os/commands","w")
    f.writeLine("return {}")
    f.close()
    writeText("sha256 API ["..string.rep(" ",32).."]",2,5)
    sleep(1)
    slowWrite(string.rep("-",32),14,5)
    os.loadAPI("/os/sha256")
    clearScreen()
    fillLine(1)
    writeText("Initial Setup",2,1,true)
    slowWrite("Set a master password",2,3)
    slowWrite("A master password allows you to",2,5)
    slowWrite("unlock the terminal and open BIOS",2,6)
    slowWrite("(Type nothing if you don't want a password)",2,8)
    repeat
      --slowWrite("Password: ",2,17)
      writeText("Password:                                       ",2,17)
      masterPass = sha256.sha256(readInput(12,17,"*"))
      --slowWrite(" Confirm: ",2,18)
      writeText(" Confirm:                                       ",2,18)
      confirmPass = sha256.sha256(readInput(12,18,"*"))
    until masterPass == confirmPass
    if masterPass == sha256.sha256("") then
      noPass = true
    else
      noPass = false
    end
    f = fs.open("/os/.masterpass","w")
    f.write(masterPass)
    f.close()
    clearScreen()
    fillLine(1)
    writeText("Initial Setup",2,1,true)
    slowWrite("Installation complete!",2,3)
    slowWrite("Just some small configurations to do!",2,4)
    slowWrite("Computer Name: ",2,6)
    compName = readInput(17,6)
    f = fs.open("/os/settings","w")
    os.setComputerLabel(compName)
    f.writeLine(textutils.serialise({
      ["name"] = compName,
      ["noPass"] = noPass,
      ["motd"] = {"Whether you think you can or cant, your right",
                  "With great power comes great responsibility",
                 },
    }))
    f.close()
    scrollMenu(18,{"Reboot"})
    os.reboot()
  end
  f = fs.open("/os/attempts","r")
  attempts = tonumber(f.readLine())
  f.close()
  symbols = {"!","@","#","$","%","^","&","*","(",")","-","+",".","'","?"}
  function symbGen(len)
    str = ""
    for i=1,len do
      str = str..symbols[math.random(1,#symbols)]
    end
    return str
  end
  symbListA = {}
  symbListB = {}
  for i=1,12 do
    symbListA[i] = symbGen(10)
  end
  for i=1,12 do
    symbListB[i] = symbGen(10)
  end
  msgHistory = {}
  if not password then unlocked = true end
  repeat
    if unlocked then break end
    clearScreen()
    writeText(string.upper(setting.name),2,2)
    writeText("ENTER PASSWORD NOW",2,3)
    writeText(tostring(attempts).." ATTEMPT(S) LEFT:",2,5)
    if attempts >= 1 then
      writeText(" ",21,5,true)
    end
    if attempts >= 2 then
      writeText(" ",23,5,true)
    end
    if attempts >= 3 then
      writeText(" ",25,5,true)
    end
    for i=1,12 do
      writeText("0xF"..tostring(485+i),2,6+i)
      writeText(symbListA[i],9,6+i)
      writeText("0xF"..tostring(495+i),20,6+i)
      writeText(symbListB[i],27,6+i)
    end
    for i=1,11 do
      if msgHistory[i] then
        writeText("> "..msgHistory[i]..string.rep(" ",16),38,18-i)
      end
    end
    writeText(">",38,18)
    local dupeHist = msgHistory
    msgHistory = {}
    for i,v in pairs(dupeHist) do
      msgHistory[i+2] = v
    end
    if attempts > 0 then
      local inPass = readInput(40,18,"*")
      msgHistory[2] = string.rep("*",#inPass)
      if sha256.sha256(inPass) == password then
        msgHistory[1] = "GRANTED"
        unlocked = true
        attempts = 3
        f = fs.open("/os/attempts","w")
        f.write("3")
        f.close()
      else
        msgHistory[1] = "DENIED"
        attempts = attempts - 1
        f = fs.open("/os/attempts","w")
        f.write(tostring(attempts))
        f.close()
      end
    end
    if attempts <= 0 then
      disabledTime = 60
      repeat
        disabledTime = disabledTime - 1
        clearScreen()
        centerText("TERMINAL LOCKED",math.floor((height/2)-1),false,false)
        centerText("PLEASE CONTACT AN ADMINISTRATOR",math.floor((height/2)+1),false,false)
        --centerText("DISABLED FOR "..tostring(disabledTime).."S",height-1,false,false)
        sleep(1)
      until disabledTime <= 0
      attempts = 3
      f = fs.open("/os/attempts","w")
      f.write(tostring(attempts))
      f.close()
    end
    sleep(1)
  until unlocked
  clearScreen()
  slowWrite(string.upper(setting.name),2,2)
  motd = '"'..(setting.motd[math.random(1,#setting.motd)])..'"'
  slowWrite(motd,2,3)
  group = false
  options = {}
  msg = ""
  while true do
    if not group then
      options = {}
      for i,v in pairs(commands) do
        options[#options+1] = "[ "..i.." ]"
      end
    else
      options = {}
      for i,v in pairs(commands[group]) do
        options[#options+1] = "[ "..i.." ]"
      end
    end
    clearScreen()
    writeText(string.upper(setting.name),2,2)
    writeText(motd,2,3)
    writeText("> "..msg,2,18)
    setCursor(4+#msg,18)
    if group then
      options[#options+1] = "[ Back ]"
    end
    if #options == 0 then
      options[#options+1] = "No option available"
    end
    prompt = scrollMenu(5,options)
    msg = ""
    setCursorPos(4,18)
    writeText("> "..msg,2,18)
    local tempOpt = {}
    for i,v in pairs(options) do
      tempOpt[i] = string.sub(v,3,#v-2)
    end
    options = tempOpt
    if group then
      func = commands[group][options[prompt]]
    else
      func = commands[options[prompt]]
    end
    if type(func) == "table" then
      group = options[prompt]
    elseif func == nil then
      group = false
    elseif type(func) == "function" then
      writeText(string.rep(" ",48),3,18)
      msg = func()
      if type(msg) == "string" then
        cursorTrail = true
        slowWrite(msg,4,18)
        cursorTrail = false
      elseif type(msg) == "table" then
        clearScreen()
        writeText(">",2,18)
        writeText(string.upper(setting.name),2,2)
        writeText(motd,2,3)
        for i=1,#msg do
          slowWrite(msg[i],2,4+i)
        end
        os.pullEvent("key")
        msg = ""
        clearScreen()
      end
    end
  end
end

--[[ Boot Kernel ]]--

if fs.exists("/os/commands") then
  commands = dofile("/os/commands")
else
  commands = {}
end
if not firstRun then
  os.loadAPI("/os/sha256")
  f = fs.open("/os/settings","r")
  setting = textutils.unserialise(f.readAll())
  f.close()
else
  setting = {}
end
password = false
if firstRun then
  password = false
else
  f = fs.open("/os/.masterpass","r")
  password = f.readLine()
  f.close()
end
if setting.noPass then
  password = false
end
function kernelRoutine()
  cursorTrail = true
  slowWrite("INITIALIZING KERNEL",2,2)
  slowWrite("ALT FOR BOOT OPTIONS",2,3)
  tmr = os.startTimer(1.5)  
  options = false
  while true do
    e,k = os.pullEvent()
    if e == "key" and k == keys.leftAlt then
      options = true
    elseif e == "timer" and k == tmr then
      break
    end
  end
  if options then
    if not bootOptions then
      clearScreen()
      slowWrite("BOOT OPTIONS ARE DISABLED",2,2)
      slowWrite("CONTACT AN ADMINISTRATOR.",2,3)
      while true do sleep(10) end
    end
    clearScreen()
    if password then
      slowWrite("BOOT OPTIONS LOCKED!",2,2)
      slowWrite("ENTER MASTER PASS:",2,3)
      repeat
        writeText(">                           ",2,4)
        input = sha256.sha256(readInput(4,4,"*"))
      until input == password
    end
    cursorTrail = false
    setCursor(false)
    clearScreen()
    slowWrite("Boot Menu",2,2)
    prompt = scrollMenu(4,{"Resume Boot","Run Shell","Reinstall OS","Update OS"})
    if prompt == 1 then
      --just do nothing
    elseif prompt == 2 then
      rendering = false
      term.clear()
      term.setCursorPos(1,1)
      return
    elseif prompt == 3 then
      clearScreen()
      slowWrite("Are you sure you want to reinstall OS?",2,2)
      slowWrite("You will lose passwords, user data, etc.",2,3)
      if scrollMenu(5,{"No","Yes"}) == 2 then
        fs.delete("/os")
        slowWrite("Completed, rebooting!",2,18)
        sleep(1)
        os.reboot()
      end
    elseif prompt == 4 then
      clearScreen()
      slowWrite("Would you like to update your OS?",2,2)
      slowWrite("(It is recommended that you reinstall)",2,3)
      prompt = scrollMenu(5,{"Cancel","Update","Update + Reinstall"})
      if prompt == 3 then
        fs.delete("/os")
      end
      if prompt == 2 or prompt == 3 then
        f = fs.open("/startup","w")
        h = http.get("https://raw.github.com/jakemroman/JakeHub/master/TermLink")
        f.writeLine(h.readAll())
        h.close()
        f.close()
        slowWrite("Update in progress!",2,18)
        sleep(3)
        os.reboot()
      end
    end
  end
  cursorTrail = false
  setCursor(false)
  clearScreen()
  ok,err = pcall(mainRoutine)
  clearScreen()
  fillLine(2)
  writeText("OS Fatal Error",2,2,true)
  slowWrite("The OS ran into a fatal issue",2,4)
  slowWrite("and the routine was killed",2,5)
  if err then
    slowWrite("ERR: "..err,2,7)
  else
    slowWrite("No Error Provided",2,7)
  end
  slowWrite("Reboot in 5s",2,18)
  sleep(1)
  writeText("Reboot in 4s",2,18)
  sleep(1)
  writeText("Reboot in 3s",2,18)
  sleep(1)
  writeText("Reboot in 2s",2,18)
  sleep(1)
  writeText("Reboot in 1s",2,18)
  sleep(1)
  writeText("Rebooting now!",2,18)
  sleep(1)
  os.reboot()
end
kernelRoutine()
term.clear()
term.setCursorPos(1,1)
