-- Chunkloader Shop
os.pullEvent = os.pullEventRaw
os.loadAPI("apis/ccash.lua")
rednet.open("back") -- THIS SHOULD ONLY BE A WIRED MODEM

function shop()
	-- Persistent Data
	local datafile = "data/chunkload.dat"
	local data = {
		shopAccountName = "Chunkload",
		shopAccountPass = "Test",
		dailyChunkCost = 8,
	}

	local function saveData()
		local f = fs.open(datafile,"w")
		f.writeLine(textutils.serialise(data))
		f.close()
	end

	if fs.exists(datafile) then
		local f = fs.open(datafile,"r")
		data = textutils.unserialise(f.readAll())
		f.close()
	else
		-- First time setup
		print("first time setup")
		print("-----------------------")
		print("enter shop account name")
		data.shopAccountName = read()
		print("enter shop account password")
		data.shopAccountPass = read("*")
		print("enter target fund name")
		data.shopVaultName = read()
		print("enter daily chunk cost")
		data.dailyChunkCost = tonumber(read())
		local ok,err = ccash.user(data.shopAccountName,data.shopAccountPass)
		if ok and type(err) == "number" and err > 0 then
			print("success!")
			sleep(1)
		else
			printError("error: "..tostring(err))
			sleep(8)
			os.pullEvent("key")
		end
		saveData()
	end

	-- Chunk ID Function
	local function getID(chunkX,chunkY)
		return tostring(chunkX)..","..tostring(chunkY)
	end
	local function splitID(chunkID)
		local chunkX = tonumber(string.sub(chunkID,1,string.find(chunkID,",")-1))
		local chunkY = tonumber(string.sub(chunkID,string.find(chunkID,",")+1,#chunkID))
		return chunkX, chunkY
	end

	-- Command Interface Functions
	local function addChunkDays(chunkX,chunkY,days)
		rednet.broadcast({
			chunkloader = true,
			command = "add",
			chunkX = chunkX,
			chunkY = chunkY,
			days = days,
		})
		local id,cmd = rednet.receive(1)
		return cmd
	end
	local function listLoadedChunks()
		rednet.broadcast({
			chunkloader = true,
			command = "list",
		})
		local id,cmd = rednet.receive(1)
		return cmd
	end

	--/ Initialization /--
	local w,h = term.getSize()
	term.setPaletteColor(colors.blue,0.1,0.75,0.85)
	term.setPaletteColor(colors.cyan,0.4,0.85,0.95)
	term.setPaletteColor(colors.lightBlue,0.7,0.95,1)
	term.setPaletteColor(colors.magenta,0.9,0.9,0.9)

	--/ Functions /--
	local function drawLogo(x,y)
		term.setCursorPos(x,y)
		term.setBackgroundColor(colors.cyan)
		term.setTextColor(colors.white)
		term.write("/")
		term.write("\\")
		term.setCursorPos(x,y+1)
		term.write("\\")
		term.write("/")
	end
	local function drawHeader()
		paintutils.drawFilledBox(1,1,w,4,colors.gray)
		drawLogo(2,2)
		term.setBackgroundColor(colors.gray)
		term.setCursorPos(5,2)
		term.setTextColor(colors.cyan)
		write("Chunk")
		term.setCursorPos(5,3)
		term.setTextColor(colors.white)
		write("Loader")
		term.setBackgroundColor(colors.white)
	end
	local function center(str, ln)
		term.setCursorPos(w/2-(#str/2)+1,ln)
		write(str)
	end
	local function rightAlign(str,ln)
		term.setCursorPos(w-#str,ln)
		write(str)
	end

	--/ Map /--
	local mapX = 0
	local mapY = 0
	local loadedChunks = {}
	local displayedChunks = {}

	local function getMapData(x,y)
		local timeLeft = loadedChunks[getID(x,y)]
		if not timeLeft then
			return 0
		end
		timeLeft = timeLeft - os.epoch("utc")/1000
		return (timeLeft/86400)
	end

	local function setMapColor(mapValue,x,y)
		if mapValue >= 4 then
			term.setBackgroundColor(colors.blue)
		elseif mapValue >= 2 then
			term.setBackgroundColor(colors.cyan)
		elseif mapValue > 0 then
			term.setBackgroundColor(colors.lightBlue)
		else
			local xor = 0
			if x%2 == 0 then
				xor = xor + 1
			end
			if y%2 == 0 then
				xor = xor + 1
			end
			if xor == 1 then
				term.setBackgroundColor(colors.white)
			else
				term.setBackgroundColor(colors.magenta)
			end
		end
	end

	local function drawMap(x1,y1,x2,y2)
		local topLeftX = math.floor(mapX-(x2-x1)/2)
		local topLeftY = math.floor(mapY-(y2-y1)/2)
		displayedChunks = {}
		for x=x1,x2 do
			displayedChunks[x] = {}
			for y=y1,y2 do
				local chunkX,chunkY = topLeftX+x,topLeftY+y
				displayedChunks[x][y] = {chunkX,chunkY}
				term.setCursorPos(x,y)
				local mapValue = getMapData(chunkX,chunkY)
				setMapColor(mapValue,chunkX,chunkY)
				write(" ")
			end
		end
	end

	--/ Interface /--
	local preselect = false
	while true do
		loadedChunks = listLoadedChunks()

		drawHeader()
		term.setTextColor(colors.lightGray)
		term.setBackgroundColor(colors.gray)
		rightAlign("Arrow keys to move",2)
		term.setTextColor(colors.cyan)
		rightAlign("Go to chunk",3)
		drawMap(1,5,w,h)

		if preselect then
			os.queueEvent("mouse_click",1,math.floor(w/2),math.floor(h/2)+3)
			preselect = false
		end

		local e,c,x,y = os.pullEvent()
		if e == "mouse_click" then
			if displayedChunks[x] then
				local chunk = displayedChunks[x][y]
				if chunk then
					local chunkX,chunkY = chunk[1],chunk[2]
					local chunkDays = getMapData(chunkX,chunkY)
					setMapColor(chunkDays,chunkX,chunkY)
					term.setTextColor(colors.black)
					term.setCursorPos(x,y)
					write("+")
					paintutils.drawFilledBox(w-18,5,w,h,colors.lightGray)
					term.setCursorPos(w-17,6)
					term.setTextColor(colors.white)
					write("Chunk "..tostring(chunkX)..", "..tostring(chunkY))
					term.setCursorPos(w-17,7)
					if chunkDays <= 0 then
						term.setTextColor(colors.gray)
						write("Not loaded")
					elseif chunkDays > 0 then
						term.setTextColor(colors.cyan)
						write("Forceloaded")
					end
					term.setCursorPos(w-17,8)
					if chunkDays >= 1 then
						write(tostring(math.floor(chunkDays)).." days left")
                    elseif chunkDays > 0 then
                        write(tostring(math.floor(chunkDays*24)).." hours left")
					end
					term.setCursorPos(w-17,10)
					term.setBackgroundColor(colors.blue)
					term.setTextColor(colors.white)
					if chunkDays > 0 then
						write(" Add Days ")
					else
						write(" Load Chunk ")
					end
					term.setCursorPos(w-17,12)
					term.setBackgroundColor(colors.lightGray)
					term.setTextColor(colors.gray)
					write(tostring(data.dailyChunkCost).." CSH / day")

					local e,c,x,y = os.pullEvent("mouse_click")
					if x > w-17 and y == 10 then
						term.setTextColor(colors.white)
						term.setCursorPos(w-17,14)
						write("To add days, pay")
						term.setCursorPos(w-17,15)
						write("> ")
						term.setTextColor(colors.cyan)
						write(data.shopAccountName)
						term.setTextColor(colors.white)
						write(" <")
						term.setCursorPos(w-17,h-1)
						term.setTextColor(colors.gray)
						write("Cancel")
						term.setCursorPos(w-17,16)
						term.setTextColor(colors.cyan)
						local function cancelButton()
							while true do
								local e,c,x,y = os.pullEvent("mouse_click")
								if x > w-17 and y == h-1 then
									break
								end
							end
						end
						local function paymentLoop()
							while true do
								local ok,bal = ccash.bal(data.shopAccountName)
								if not ok then
									printError("CCASH OFFLINE")
									sleep(3)
									break
								elseif type(bal) ~= "number" then
									printError("BALANCE ERR")
									print(bal)
									sleep(3)
									break
								end
								if bal >= data.dailyChunkCost then
									local newDays = bal/data.dailyChunkCost
									ccash.simple.send(data.shopAccountName,data.shopAccountPass,data.shopVaultName,bal)
									addChunkDays(chunkX,chunkY,newDays)
									write("Added "..tostring(math.floor(newDays)).." days")
									sleep(1)
									break
								end
								sleep(1)
							end
						end
						parallel.waitForAny(cancelButton,paymentLoop)
					end
				end
			end
			if x > w/2 and y == 3 then
				term.setCursorPos(1,2)
				term.setBackgroundColor(colors.gray)
				term.clearLine()
				term.setCursorPos(1,3)
				term.clearLine()
				term.setTextColor(colors.white)
				term.setCursorPos(2,3)
				write("Target Y: ")
				term.setCursorPos(2,2)
				write("Target X: ")
				local chunkX = tonumber(read())
				if chunkX then
					term.setCursorPos(2,3)
					write("Target Y: ")
					local chunkY = tonumber(read())
					if chunkY then
						mapX = chunkX
						mapY = chunkY-5
					end
				end
				preselect = true
			end
		elseif e == "key" then
			if c == keys.up then
				mapY = mapY - 1
			elseif c == keys.down then
				mapY = mapY + 1
			elseif c == keys.right then
				mapX = mapX + 1
			elseif c == keys.left then
				mapX = mapX - 1
			end
		end
	end
end

-- Error Handling
while true do
	local ok,err = pcall(shop)
	term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(2,2)
	write(err)
	sleep(1)
	os.pullEvent("key")
end
