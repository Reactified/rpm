-- AXIOS | React Industries
local version = "1"
local channel = 8712
os.setComputerLabel("AX-"..tostring(os.getComputerID()))

local modem = peripheral.find("modem")
if not modem then
  printError("AXIOS cannot start, no modem")
end

modem.open(channel)
while true do
  term.clear()
  term.setCursorPos(2,2)
  write("AXIOS Control Active | v"..version)
  term.setCursorPos(2,3)
  write("Fuel: "..tostring(turtle.getFuelLevel()).."/"..tostring(turtle.getFuelLimit()))
  local e,s,c,r,m = os.pullEvent("modem_message")
  if c == channel and r == os.getComputerID() then
    if type(m) == "string" then
      local ok,err = pcall(loadstring(m))
      modem.transmit(channel,os.getComputerID(),{ok,err})
    end
  elseif c == channel and r == 0 then
    if type(m) == "string" then
      pcall(loadstring(m))
    end
  end
end
