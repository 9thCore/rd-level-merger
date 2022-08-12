--[[

	RD Level Merger 1.2 (<-- i'll probably forget to change this version later)

	
	-- WHAT IS THIS? --
	
	A simple level merger that takes in a number of levels and merges them together into one giant mess.


	-- WHY WOULD I EVER NEED IT? --

	Unless you're doing crazy shit like 15k events or a giant collab with 3000 individual sections, never!
	For the 1% left remaining though...


	-- WHAT CAN I DO WITH IT? --
	
	You have a few options to choose what gets merged, you can choose to add the rows and their respective beats or add the decos and their respective events, etc.
	Yeah that's, it what else did you expect


	-- IS THIS SAFE? --
	I'd uh, say so.. you can compile it yourself using LÖVE if you don't trust the executable (or are on another platform, sorry about that) and you can look at the lua files.
	The files are all not encrypted so you can easily look through the whole thing to find malicious stuff.
	(i dont know how to write malicious code anyway :p)


]]

-- [[ VARIABLES AND STUFF ]]
local json = require "json"
local easings = require "easings"
local types = require "eventTypes"
local encoder = require "encoder"
local credits = require "credits"


local __VERSION = "1.2"


math.randomseed(os.time())


local rdfont = love.graphics.newFont("rdfont.otf", 16)
rdfont:setFilter("nearest", "nearest")

local rdfont_scale2 = love.graphics.newFont("rdfont.otf", 32)
rdfont_scale2:setFilter("nearest", "nearest")

local rdfont_scale15 = love.graphics.newFont("rdfont.otf", 24)
rdfont_scale15:setFilter("nearest", "nearest")


sound = love.audio.newSource("sfx.ogg", "static")
love.audio.setVolume(1/4)

local STATE_IDLE = 0
local STATE_LOAD = 1
local STATE_INPUTLIST = 2
local STATE_SETTINGS = 3

local currentState = 0
local stateArg = 0

local buttons = {}
local tickboxes = {}

local inputs = {}
local totalinputs = 2

local lastError = ""
local lastDesc  = ""
local lastGen   = ""

local levelScroll = 0
local maxScroll = 0
local updateMaxScroll
local scrollBar = {
	x = 75,
	y = 150,
	w = 15,
	h = 350
}

local lastHolding = false
local startHoldX = 0
local startHoldY = 0

local anims = {
	camera = {
		x  = 0, startx = 0, endx = 0,
		y  = 0, starty = 0, endy = 0,
		timer = 0, endTime = 0,
		easing = easings.linear,
		animates = {"x", "y"}
	}
}


-- [[ FUNCTIONS ]]

local floor = math.floor
local random = math.random
local min = math.min
local max = math.max

local function lerp(a, b, t)
	return a*(1-t) + b*t
end


local function createButton(x, y, w, h, text, state, func)

	-- this looks so bad :samuraisword:
	local newbutton = {
		x = floor(x+0.5),
		y = floor(y+0.5),
		w = floor(w+0.5),
		h = floor(h+0.5),
		text = text,
		func = func,
		state = state
	}

	buttons[#buttons+1] = newbutton

	return newbutton

end

local function createTickbox(x, y, w, h, active, text, desc)

	-- this looks so bad :samuraisword:
	local newtick = {
		x = floor(x+0.5),
		y = floor(y+0.5),
		w = floor(w+0.5),
		h = floor(h+0.5),
		text = text,
		desc = desc, 
		active = active
	}

	tickboxes[#tickboxes+1] = newtick

	return newtick

end

local loaders = 0
local function createLoader(x, y, w, h)

	loaders = loaders + 1

	local btn = createButton(x, y, w, h, "Select level\n"..tostring(loaders), STATE_INPUTLIST, function() end)

	btn.idx = loaders
	btn.tableidx = #buttons

	inputs[btn.idx] = {}

	inputs[btn.idx].actions = {
		addRows = tickboxes[1].active,
		keepRowEvents = tickboxes[2].active,
		addVFX = tickboxes[3].active,
		addSFX = tickboxes[4].active,
		addRooms = tickboxes[5].active,
		addDeco = tickboxes[6].active,
		addConds = tickboxes[7].active
	}

	btn.func = function()

		currentState = STATE_LOAD
		stateArg = btn.idx

	end

	if btn.idx > 2 then

		btn.xbtn = createButton(x + w/2, y - h/2, 20, 20, "X", STATE_INPUTLIST, function()

			loaders = loaders - 1
			totalinputs = totalinputs - 1

			table.remove(buttons, btn.tableidx)
			table.remove(inputs, btn.idx)

			for i,button in ipairs(buttons) do

				if button.idx then
					if button.idx > btn.idx then

						button.idx = button.idx - 1
						button.tableidx = button.tableidx - 1

						button.text = "Select level\n"..tostring(button.idx)

						button.y = button.y - 75
						button.xbtn.y = button.xbtn.y - 75
						button.settings.y = button.settings.y - 75

					end
				end

			end

			btn.xbtn = nil
			btn.settings = nil
			btn = nil

			updateMaxScroll()

		end)

		btn.xbtn.isx = true

		buttons[#buttons] = nil

	end

	btn.settings = createButton(x + w/2, y + h/2, 20, 20, "S", STATE_INPUTLIST, function()

		currentState = STATE_SETTINGS
		stateArg = btn.idx

		local input = inputs[stateArg].actions

		local cnt = #tickboxes/2
		tickboxes[cnt+1].active = input.addRows
		tickboxes[cnt+2].active = input.keepRowEvents
		tickboxes[cnt+3].active = input.addVFX
		tickboxes[cnt+4].active = input.addSFX
		tickboxes[cnt+5].active = input.addRooms
		tickboxes[cnt+6].active = input.addDeco
		tickboxes[cnt+7].active = input.addConds

	end)

	buttons[#buttons] = nil

end

local function checkDone(idx, x, y, w)

	local t = "Not done"

	love.graphics.setColor(1, 0, 0, 1)

	if inputs[idx].level then

		t = "Done!"
		love.graphics.setColor(0, 1, 0, 1)

	end

	love.graphics.printf(t, rdfont, x - w*0.5, y, w, 'center')

end

local function mouseTouchingButton(button)

	if currentState ~= button.state and button.active == nil then return false end

	if button.idx then
		if button.idx > 2 and mouseTouchingButton(button.xbtn) then
			return false
		elseif mouseTouchingButton(button.settings) then
			return false
		end

		if love.mouse.getY() > 500 then
			return false
		end
	end

	local x = love.mouse.getX() + anims.camera.x
	local y = love.mouse.getY() + anims.camera.y

	if button.idx or button.isx or button.text == "S" then
		y = y - levelScroll
	end

	if  x >= button.x - button.w*0.5 and x <= button.x + button.w*0.5
	and y >= button.y - button.h*0.5 and y <= button.y + button.h*0.5
	then
		return true
	end

	return false

end

local function drawButton(button)

	if button.x + button.w/2 < anims.camera.x
	or button.x - button.w/2 > anims.camera.x + 800
	then
		return
	end

	local _, linecount = string.gsub(button.text, "\n", "\n") -- find how many newlines we have in the text
	linecount = linecount + 1

	love.graphics.setColor(0.8, 0.8, 0.8, 1)

	if mouseTouchingButton(button) then
		love.graphics.setColor(1, 1, 1, 1)
	end

	love.graphics.rectangle("fill", button.x - button.w*0.5, button.y - button.h*0.5, button.w, button.h, min(10,button.w/4), min(10,button.h/4), 20)
	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.printf(button.text, rdfont, button.x - button.w*0.5, button.y - rdfont:getHeight()/2*linecount, button.w, 'center')
	love.graphics.setColor(1, 1, 1, 1)
end

local function drawTick(tick)

	if tick.x + tick.w/2 < anims.camera.x
	or tick.x - tick.w/2 > anims.camera.x + 800
	then
		return
	end

	love.graphics.setColor(0.75, 0.75, 0.75, 1)
	if mouseTouchingButton(tick) then
		love.graphics.setColor(0.85, 0.85, 0.85, 1)
	end

	love.graphics.rectangle("fill", tick.x - tick.w*0.5, tick.y - tick.h*0.5, tick.w, tick.h, 10, 10, 20)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", tick.x - tick.w*0.5 + 10, tick.y - tick.h*0.5 + 10, 30, 30, 5, 5, 20)

	love.graphics.setColor(0, 0, 0, 1)
	if tick.active then
		love.graphics.printf("x", rdfont_scale2, tick.x - tick.w*0.5 + 12, tick.y - tick.h*0.5 + 2, 30, 'center')
	end

	local font = rdfont_scale2
	local h = font:getHeight()/16

	if tick.text:len() > 12 then font = rdfont_scale15 h = h*4 end

	love.graphics.printf(tick.text, font, tick.x - tick.w*0.5 + 30, tick.y - tick.h*0.5 + h, tick.w - 30, 'center', 0)

	love.graphics.setColor(1, 1, 1, 1)

end

function updateMaxScroll()

	maxScroll = (max(totalinputs,4) - 4) * 75
	levelScroll = max(min(levelScroll, 0), -maxScroll)

end

local function drawLoader(loader)

	drawButton(loader)

	if loader.xbtn then

		drawButton(loader.xbtn)

	end

	drawButton(loader.settings)

end

local function readFile(data)

	data = data:gsub("null", "\"IAMPRAYINGANDSHITTINGANDHOPINGTHATNOBODYWILLEVERUSESUCHACOMPLICATEDSETOFLETTERSPLEASEIDONOTWANTANYEDGECASESPOPPINGUP:EDEGABUDGETCUTS::EDEGABUDGETCUTS:__NULL_NULL____NULL\"")

	data = encoder.removeTrailingCommas(data)

	local status, arg = pcall(json.decode, data)

	return status, arg

end

local function drawButtonsWithState(state)

	for i=1,#buttons do
		if buttons[i].state == state then
			drawButton(buttons[i])
		end
	end

end

local function checkButtonPress(x, y)

	local touching = false

	for i=#buttons,1,-1 do

		local button = buttons[i]

		if button.xbtn then
			if mouseTouchingButton(button.xbtn) then
				touching = button.xbtn
				break
			end
		end

		if button.settings then
			if mouseTouchingButton(button.settings) then
				touching = button.settings
				break
			end
		end

		if mouseTouchingButton(button) then

			touching = button
			break

		end

	end

	if not touching then return end

	lastError = ""
	lastGen = ""

	touching.func()

end

local function save()

	local str = ""

	str = str .. "VERSION " .. __VERSION .. "\n\n"


	str = str .. "- START DEFAULTS -\n"

	for _,t in ipairs(tickboxes) do

		if not t.special then
			str = str .. tostring(t.active) .. "\n"
		end

	end

	str = str .. "- END DEFAULTS -\n"

	love.filesystem.write("save.dat", str)

end

local function readsave()

	local str = ""

	local READING = {
		NONE = 0,
		DEFAULTS = 1
	}

	local reading = READING.NONE

	local i = 0

	for line in love.filesystem.lines("save.dat") do

		if line:sub(1,7) == "VERSION" then
			if line:sub(9,-1) ~= __VERSION then
				break
			end
		end

		if reading == READING.NONE then

			if line == "- START DEFAULTS -" then

				i = 0
				reading = READING.DEFAULTS

			end

		elseif reading == READING.DEFAULTS then

			if line == "- END DEFAULTS -" then

				reading = READING.NONE

			else

				local myBool = false
				if line == "true" then myBool = true end

				i = i + 1
				tickboxes[i].active = myBool

				if i > #tickboxes - 1 then -- If we go over the amount of defaults, stop interpreting the rest of the defaults forcefully

					reading = READING.NONE

				end

			end

		end

	end

end

local function scrollbarSetProgress(x, y)

	local ratio = 350 / (350 + maxScroll)
	local h = scrollBar.h * ratio

	local progressDownTheScrollBar = min(max((scrollBar.y + h/2 - y) / (scrollBar.h - h), -1), 0)
	levelScroll = progressDownTheScrollBar * maxScroll

end

local function checkTickboxPress(x, y)

	local touching = false

	for i=1,#tickboxes do

		local tickbox = tickboxes[i]
		local continue = true

		if tickbox.special and currentState ~= STATE_SETTINGS then continue = false end

		if continue and mouseTouchingButton(tickbox) then

			touching = i
			break

		end

	end

	if not touching then return end

	lastError = ""

	tickboxes[touching].active = not tickboxes[touching].active

end

local function inputStencil()
	love.graphics.rectangle("fill", 0, 150, 500, 350)
end

local function drawInputList()

	love.graphics.setColor(0, 0, 0, 0.8)
	love.graphics.rectangle("fill", 0, 0, 800, 600)

	for _,button in ipairs(buttons) do

		if button.state == STATE_INPUTLIST and not button.idx then

			drawButton(button)

		end

	end

	love.graphics.stencil(inputStencil, "replace", 1)
	love.graphics.setStencilTest("greater", 0)

	love.graphics.push()
	love.graphics.translate(0, levelScroll)

	for _,button in ipairs(buttons) do

		if button.idx then

			drawLoader(button)
			checkDone(button.idx, button.x + button.w/2 + 50, button.y - 12, 100)

		end

	end

	love.graphics.pop()

	love.graphics.setStencilTest()

	love.graphics.setColor(0.25, 0.25, 0.25, 1)
	love.graphics.rectangle("fill", scrollBar.x, scrollBar.y, scrollBar.w, scrollBar.h, 10, 10, 20)

	local ratio = 350 / (350 + maxScroll)
	local h = scrollBar.h * ratio

	local t = 0
	if maxScroll > 0 then t = levelScroll/maxScroll end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", scrollBar.x, lerp(scrollBar.y, scrollBar.y - scrollBar.h + h, t), scrollBar.w, h, 20, 20, 20)

end

-- [[ CREATING BUTTONS ]]

createButton(800/2, 200, 800/4, 100, "Set the rdlevels", STATE_IDLE, function()

	currentState = STATE_INPUTLIST
	levelScroll = 0

end)

createButton(800/2, 400, 800/4, 100, "Generate\nthe output", STATE_IDLE, function()

	local res, finalStr = encoder.tryencode(inputs, totalinputs)

	if res == encoder.ERR_NOT_ENOUGH_INPUTS then

		lastError = "Uh oh!\nYou need to provide at least 2 files!"

	elseif res == encoder.ERR_NOT_ALL_INPUTS then

		lastError = "Uh oh!\nIt seems like you didn't provide all the files!"

	elseif res == encoder.SUCCESS then

		success, message = love.filesystem.write("output.rdlevel", finalStr)

		if success then

			sound:stop()
			sound:play()

			local dir = love.filesystem.getSaveDirectory()

			lastGen = "Generated the output at '" .. dir .. "/output.rdlevel" .. "' at " .. os.date("%X", os.time()) .. "!"

			love.system.openURL("file://"..dir)

		else

			lastError = "Uh oh, something went wrong!\nReport this to 9thCore if you did everything right\n" .. message

		end

	end

end)

createButton(800/2, 550, 800/4, 75, "Cancel", STATE_LOAD, function()
	
	currentState = STATE_INPUTLIST
	lastError = ""

end)

createButton(150, 550, 200, 75, "Back", STATE_INPUTLIST, function()
	
	currentState = STATE_IDLE
	lastError = ""

end)

createButton(150, 550, 200, 75, "Back", STATE_SETTINGS, function()

	local cnt = #tickboxes/2

	inputs[stateArg].actions = {
		addRows = tickboxes[cnt+1].active,
		keepRowEvents = tickboxes[cnt+2].active,
		addVFX = tickboxes[cnt+3].active,
		addSFX = tickboxes[cnt+4].active,
		addRooms = tickboxes[cnt+5].active,
		addDeco = tickboxes[cnt+6].active,
		addConds = tickboxes[cnt+7].active
	}
	
	currentState = STATE_INPUTLIST
	lastError = ""

end)

createButton(400, 550, 200, 75, "Add rdlevel", STATE_INPUTLIST, function()
	
	totalinputs = totalinputs + 1
	createLoader(200, 200 + (totalinputs-1)*75, 150, 50)

	updateMaxScroll()

end)

createButton(650, 550 + 75/4 + 5, 200, 75/2, "Add all rdlevels\nfrom Levels directory", STATE_INPUTLIST, function()

	if not love.filesystem.getInfo("Levels") then

		local success = love.filesystem.createDirectory("Levels")

	end

	local items = love.filesystem.getDirectoryItems("Levels")
	stateArg = 0

	table.sort(items, function(a,b) return a:upper() < b:upper() end)

	for _,item in ipairs(items) do

		if item:sub(-8,-1) == ".rdlevel" then

			local data = love.filesystem.read("Levels/"..item)

			local success, arg = readFile(data:sub(4,-1), false)

			if success then

				stateArg = stateArg + 1

				if stateArg > totalinputs then

					totalinputs = totalinputs + 1
					createLoader(200, 200 + (totalinputs-1)*75, 150, 50)

					updateMaxScroll()

				end

				inputs[stateArg] = inputs[stateArg] or {}

				inputs[stateArg].level = arg

			end

		end

	end

end)

createButton(650, 550 - 75/4 - 5, 200, 75/2, "Open Levels directory", STATE_INPUTLIST, function()

	local dir = love.filesystem.getSaveDirectory()
	love.system.openURL("file://" .. dir .. "/Levels")

end)

createButton(800-50, 600/2, 75, 50, "Defaults", STATE_IDLE, function()

	anims.camera.startx = anims.camera.x
	anims.camera.endx = 800
	anims.camera.timer = 0
	anims.camera.endTime = 2/3
	anims.camera.easing = easings.outQuart

end)

createButton(800+50, 600/2, 75, 50, "Back", STATE_IDLE, function()

	anims.camera.startx = anims.camera.x
	anims.camera.endx = 0
	anims.camera.timer = 0
	anims.camera.endTime = 2/3
	anims.camera.easing = easings.outQuart

	save()

end)

createButton(0+50, 600/2, 75, 50, "Credits", STATE_IDLE, function()

	anims.camera.startx = anims.camera.x
	anims.camera.endx = -800
	anims.camera.timer = 0
	anims.camera.endTime = 2/3
	anims.camera.easing = easings.outQuart

end)

createButton(0-50, 600/2, 75, 50, "Back", STATE_IDLE, function()

	anims.camera.startx = anims.camera.x
	anims.camera.endx = 0
	anims.camera.timer = 0
	anims.camera.endTime = 2/3
	anims.camera.easing = easings.outQuart

end)


local spacing = 60
createTickbox(800+250, 140+spacing*0, 300, 50, false, "Add rows", "Adds all the rows to the first rdlevel, as well as their corresponding beats.\nThere will not be more than 16 rows total in the output and there will not be more than 4 rows per room so you might lose beats if not careful!")
createTickbox(800+250, 140+spacing*1, 300, 50, true, "Keep row events", "Keep row-dependent events (not the beats) such as Move Row events even if the rows aren't merged on this level.\nNote that this will not check for invalid events, it will not get rid of the event if the row doesn't exist!\nWill not do anything if 'Add rows' is enabled.")
createTickbox(800+250, 140+spacing*2, 300, 50, true , "Add VFX", "Adds the vfx events to the first rdlevel.\nIf there is an event that affects a particular row and said row isn't present, it will simply delete the event!")
createTickbox(800+250, 140+spacing*3, 300, 50, true , "Add sounds", "Adds the sounds to the first rdlevel.\nIf there is an event that affects a particular row and said row isn't present, it will simply delete the event!")
createTickbox(800+250, 140+spacing*4, 300, 50, true , "Add room events", "Adds all the room events to the first rdlevel.")
createTickbox(800+250, 140+spacing*5, 300, 50, true , "Add decorations", "Adds all the decorations to the first rdlevel, as well as their corresponding events.")
createTickbox(800+250, 140+spacing*6, 300, 50, true , "Add conditionals", "Adds all the conditionals to the first rdlevel.\nOtherwise, events might have invalid conditionals and not work!")


local cnt = #tickboxes
for i=1,cnt do
	local t = createTickbox(500, 140+spacing*(i-1), 300, 50, true, tickboxes[i].text, tickboxes[i].desc)
	t.special = true
end

-- Really basic save file loading
if not love.filesystem.getInfo("save.dat") then
	love.filesystem.write("save.dat", "")
else
	readsave()
end

createLoader(200, 200, 150, 50)
createLoader(200, 275, 150, 50)


if not love.filesystem.getInfo("Levels") then

	local success = love.filesystem.createDirectory("Levels")

	if success then

		love.filesystem.write("Levels/Add all of your rdlevels here!", "🤨")

	end

end


-- [[ CODE ]]

function love.filedropped(file)

	if currentState == STATE_LOAD then

		if file:getFilename():sub(-8,-1) ~= ".rdlevel" then

			lastError = "Uh oh!\nThe file doesn't seem to be a rdlevel!\nAre you sure its extension is .rdlevel?"
			return

		end

		local str = file:read():sub(4,-1)
		local isstringer = false

		for i=1,#str do
			local ch = str:sub(i,i)
			if ch == '"' then
				isstringer = not isstringer
			end

			if isstringer then
				if ch == '	' then -- tab
					str = str:sub(1,i-1) .. '__thisusedtobeatabbuttoavoiddeathitsnot__' .. str:sub(i+1,-1)
					i = i - 1

				elseif str:sub(i,i+1) == '\r\n' and str:sub(i-2,i-1) ~= '},' then
					str = str:sub(1,i-1) .. str:sub(i+4,-1)
					i = i - 1

				end
			end

		end

		local status, arg = readFile(str, true)

		if status then

			lastError = ""
			inputs[stateArg].level = arg

			for _,e in ipairs(arg.events) do
				for k,v in pairs(e) do
					if type(v) == 'string' then
						v = v:gsub('__thisusedtobeatabbuttoavoiddeathitsnot__', '	')
					end
				end
			end

			currentState = STATE_INPUTLIST
			stateArg = 0

		else

			lastError = "Uh oh!\nCould not read the file!\nAre you sure it's valid?"
			print(arg)

		end

	end

end

function love.mousepressed(x, y, button, istouch, presses)

	if button ~= 1 then return end

	if currentState == STATE_INPUTLIST then

		startHoldX = x
		startHoldY = y

		if  x >= scrollBar.x and x <= scrollBar.x + scrollBar.w
		and y >= scrollBar.y and y <= scrollBar.y + scrollBar.h
		then

			scrollbarSetProgress(x, y)
			return

		end

	end

	checkButtonPress(x, y)
	checkTickboxPress(x, y)

end

function love.mousemoved(x, y, dx, dy, istouch)

	for _,v in ipairs(tickboxes) do

		if mouseTouchingButton(v) then

			lastDesc = v.desc
			return

		end

	end

	lastDesc = ""

end

function love.wheelmoved(x,y)

	if currentState ~= STATE_INPUTLIST then return end

	levelScroll = max(min(levelScroll + y*25, 0), -maxScroll)

end

function love.load(args)

	local data = love.image.newImageData("icon.png")
	local success = love.window.setIcon(data)

	love.window.setTitle('Level Merger')

end

function love.update(dt)

	if currentState == STATE_INPUTLIST and love.mouse.isDown(1) then

		if  startHoldX >= scrollBar.x and startHoldX <= scrollBar.x + scrollBar.w
		and startHoldY >= scrollBar.y and startHoldY <= scrollBar.y + scrollBar.h
		then

			scrollbarSetProgress(love.mouse.getX(), love.mouse.getY())

		end

	end

	for _,v in pairs(anims) do

		if v.timer < v.endTime then

			v.timer = v.timer + dt
			for _,a in pairs(v.animates) do
				v[a] = floor(v.easing(v.timer, v["start"..a], v["end"..a] - v["start"..a], v.endTime)+0.5)
			end

		end

	end

end

function love.draw()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf("Level Merger v"..__VERSION, rdfont, 800*0.5 - 400, 10, 400, 'center', 0, 2, 2)

	love.graphics.push()
    love.graphics.translate(-anims.camera.x, -anims.camera.y)


    love.graphics.printf("Main Menu", rdfont, 800*0.5 - 400, 50, 400, 'center', 0, 2, 2)
    love.graphics.printf("Defaults", rdfont, 800*1.5 - 400, 50, 400, 'center', 0, 2, 2)
    love.graphics.printf("Credits", rdfont, 800*-0.5 - 400, 50, 400, 'center', 0, 2, 2)

	drawButtonsWithState(STATE_IDLE)

	for i=1,#tickboxes do
		if not tickboxes[i].special then
			drawTick(tickboxes[i])
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(lastDesc, rdfont_scale15, 800 + 800 - 350 - 25, 140, 350, 'center')

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.printf(credits.credits, rdfont_scale15, -800 + 100, 140, 600, 'center')

	love.graphics.pop()


	if currentState == STATE_LOAD then

		drawInputList()

		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", 0, 0, 800, 600)

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.printf("Drag and drop\nthe .rdlevel here!", rdfont, 800*0.5 - 800, 600*0.5 - 100, 400, 'center', 0, 4, 4)

		drawButtonsWithState(STATE_LOAD)

	elseif currentState == STATE_INPUTLIST then

		drawInputList()

	elseif currentState == STATE_SETTINGS then

		drawInputList()

		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", 0, 0, 800, 600)

		drawButtonsWithState(STATE_SETTINGS)

		local cnt = #tickboxes/2
		for i=1,cnt do

			local tick = tickboxes[i+cnt]

			drawTick(tick)

		end

	end

	if lastError:len() > 0 then
		love.graphics.setColor(1, 0, 0, 1)
		love.graphics.printf(lastError, rdfont, 800*0.5 - 400, 80, 400, 'center', 0, 2, 2)
	end

	if lastGen:len() > 0 then
		love.graphics.setColor(0, 1, 0, 1)
		love.graphics.printf(lastGen, rdfont, 800*0.5 - 400 - anims.camera.x, 600 - 120, 400, 'center', 0, 2, 2)
	end


end