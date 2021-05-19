-- REACT INDUSTRIES | Elevator Panel
local m = peripheral.wrap("bottom")

-- Display
m.setTextScale(0.5)
term.redirect(m)
local w,h = term.getSize()

term.setBackgroundColor(colors.gray)
term.clear()
term.setCursorPos(2,h-1)
term.setTextColor(colors.lightGray)
term.write("React Industries")
term.setCursorPos(1,1)
term.setTextColor(colors.white)
print("Open")
print("Floor 1")
print("Floor 2")
print("Floor 3")

while true do
    local e,c,x,y = os.pullEvent("monitor_touch")
    print()
    print("Selected "..tostring(y-1))
    rs.setOutput("right",true)
    sleep(y/10)
    rs.setOutput("right",false)
end
