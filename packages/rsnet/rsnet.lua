-- Binary Networking API

function dec2Bin(dec)
	dec=dec*2
	local bin=""
	for i=0,7 do
		--print(dec.." "..math.ceil(math.floor(dec/2)%2))
		bin=bin..tostring(math.ceil(math.floor(dec/2)%2))
		dec=math.floor(dec/2)
	end
	return string.reverse(bin)
end

function bin2Dec(bin)
	return tonumber(bin, 2)
end

openSide = nil
sides = {
    ["top"] = true,
    ["bottom"] = true,
    ["left"] = true,
    ["right"] = true,
    ["front"] = true,
    ["back"] = true,
}

function open(side)
    if sides[side] then
        openSide = side
        return true
    else
        return false
    end
end
function receive()
    if not openSide then return false end
    repeat
    	os.pullEvent("redstone")
    until rs.getInput(openSide)
    sleep(1)
    msg = ""
    while true do
        byte = ""
        for i=1,8 do
            bit = rs.getInput(openSide)
            if bit then
                byte = byte.."1"
            else
                byte = byte.."0"
            end
            sleep(0.1)
        end
        byte = tonumber(byte)
        dec = bin2Dec(byte)
        if dec == 255 then
            break
        end
        msg = msg..string.char(dec)
    end
    return msg
end

function transmit(msg,continue)
    if not continue then
        if not openSide then return false end
        rs.setOutput(openSide,true)
        sleep(0.5)
        rs.setOutput(openSide,false)
        sleep(0.5)
    end
    for i=1,#msg do
        byte = tostring(dec2Bin(string.byte(string.sub(msg,i,i))))
        for k=1,#byte do
            bit = string.sub(byte,k,k)
            if bit == "1" then
                rs.setOutput(openSide,true)
            elseif bit == "0" then
                rs.setOutput(openSide,false)
            end
            sleep(0.1)
        end
    end
    for i=1,8 do
        rs.setOutput(openSide,true)
        sleep(0.1)
    end
    rs.setOutput(openSide,false)
    sleep(0.1)
end
