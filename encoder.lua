local encoder = {}

local types = require "eventTypes"

local random = math.random

encoder.SUCCESS = -1
encoder.ERR_NOT_ENOUGH_INPUTS = 0
encoder.ERR_NOT_ALL_INPUTS = 1

local TYPE_ROW = 1
-- i have no idea where 2 is lmao
local TYPE_VFX = 3
local TYPE_SFX = 4
local TYPE_ROOM = 5
local TYPE_DECO = 6

function encoder.removeTrailingCommas(str)
	-- Kinda hacky. Finds commas which are followed by a newline, new tab and ] and removes the comma

	local h = ",\n\t]"

	local ln = str:len()
	local hl = h:len()

	for i=1,ln-hl do

		if str:sub(i,i+hl-1) == h then

			str = str:sub(1,i-1) .. str:sub(i+1,-1)
			i = i - 1

		end

	end

	return str

end

local function addTabs(str, tabs)
	for i=1,tabs do
		str = "\t" .. str
	end
	return str
end

-- thanks stackoverflow lmao https://stackoverflow.com/questions/1426954/split-string-in-lua
function encoder.splitStr(inputstr, sep)
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

function encoder.encodeInJsonFormat(t, tabs)

	-- hey wouldnt it be funny if i made my own function to encode tables in json format
	-- haha, jk

	-- unless?? :flushed:

	tabs = tabs or 0

	local str = ""

	str = addTabs(str, tabs)

	local flag = true
	for k,v in pairs(t) do
		if type(k) ~= "number" then
			flag = false
			break
		end
	end

	if flag then
		str = str .. "["
	else
		str = str .. "{"
	end
	str = str .. "\n"

	for k,v in pairs(t) do

		if type(v) == "table" then

			if type(k) ~= "number" then
				str = str .. addTabs("\"", tabs+1) .. k .. "\":\n"
			end

			str = str .. encoder.encodeInJsonFormat(v, tabs+1)

		else

			local s = tostring(v)
			if type(v) == "string" then s = "\"" .. s .. "\"" end

			if v == "IAMPRAYINGANDSHITTINGANDHOPINGTHATNOBODYWILLEVERUSESUCHACOMPLICATEDSETOFLETTERSPLEASEIDONOTWANTANYEDGECASESPOPPINGUP:EDEGABUDGETCUTS::EDEGABUDGETCUTS:__NULL_NULL____NULL" then
				s = "null"
			end

			local finalstr = ""
			if type(k) ~= "number" then finalstr = "\"" .. k .. "\": " end
			finalstr = finalstr .. s .. ",\n"

			str = str .. addTabs(finalstr, tabs+1)

		end

	end

	str = str .. "\n"
	if flag then
		str = str .. addTabs("],", tabs)
	else
		str = str .. addTabs("},", tabs)
	end
	str = str .. "\n"

	return str

end

function encoder.tryencode(inputs, inputcount)

	if inputcount < 2 then
		return encoder.ERR_NOT_ENOUGH_INPUTS
	end

	for i=1,inputcount do
		if not inputs[i].level then

			return encoder.ERR_NOT_ALL_INPUTS

		end
	end

	local final = {}
	final.settings = inputs[1].level.settings -- steal the metadata from the first level lmao

	for _,input in ipairs(inputs) do

		print(_)

		local actions = input.actions
		input = input.level

		for k,_ in pairs(input) do -- Just in case, make sure every table in the final table like row, decorations, events etc. is properly set up
			final[k] = final[k] or {}
		end

		-- Add the conditionals
		if actions.addConds then

			local offset = #final.conditionals

			for _,v in pairs(input.conditionals) do

				v.id = v.id + offset
				table.insert(final.conditionals, v)

			end

			for _,v in pairs(input.events) do

				if v['if'] then

					local leftRightSideDuration = encoder.splitStr(v['if'], "d")

					local individualConditionals = encoder.splitStr( leftRightSideDuration[1] , "&")

					local str = ""

					for i=1,#individualConditionals do

						local s = individualConditionals[i]

						if s:sub(1,1) == "~" then

							str = str .. "~"
							s = s:sub(2,-1)

						end
						
						s = tonumber(s)
						str = str .. tostring(s + offset) .. "&"

					end

					str = str:sub(1,-2) .. "d" .. leftRightSideDuration[2]

					v['if'] = str

				end

			end

		end

		-- Add the decos
		if actions.addDeco then

			local decoList = {}

			-- Very ugly hack, makes the deco id a lot larger with random gibberish so that (hopefully) no compatibility issues arise
			-- I am not sorry for any surgerying that may occur after this
			for _,v in ipairs(input.decorations) do

				if v.id:len() < 10 then -- Only make it run if the deco id was unchanged, don't wanna end up with a 1k+ character deco id

					decoList[v.id] = ""

					local r = random(3,7)
					for i=1,r do
						decoList[v.id] = decoList[v.id] .. v.id
					end

					for i=1,30 do
						decoList[v.id] = decoList[v.id] .. tostring(random(1000,99999))
					end

					v.id = decoList[v.id]

				end

				table.insert(final.decorations, v)

			end

			for i = #input.events, 1, -1 do

				local v = input.events[i]

				if types[v.type] == TYPE_DECO then
					v.target = decoList[v.target] or v.target -- Set the target to the new randomized id, don't set if it somehow doesn't exist in the table (it should, but)
					table.insert(final.events, v)
				end

			end
		
		end

		local rowList = {} -- We're gonna be using this for other stuff too, later on

		-- Add the rows
		if actions.addRows then

			local offset = #final.rows

			local rowRoomCount = {}

			for _,v in ipairs(final.rows) do

				rowRoomCount[v.rooms[1]] = (rowRoomCount[v.rooms[1]] or 0) + 1 -- Get how many rows are in each room to make sure we don't go over the 4-row-per-room limit
				-- Sure, you can have up to 8 rows per room and it's perfectly fine as long as you have less than 16 rows in total but I'm not gonna worry about that lmao die

			end

			for _,v in ipairs(input.rows) do

				local room = v.rooms[1]

				rowRoomCount[room] = rowRoomCount[room] or 0

				if rowRoomCount[room] < 4 then -- only do stuff if we have less than 4 rows in this room
					
					rowList[v.row] = offset
					v.row = v.row + offset

					rowRoomCount[room] = rowRoomCount[room] + 1

					table.insert(final.rows, v)

				end

			end

			for _2,v in ipairs(input.events) do

				if types[v.type] == TYPE_ROW then

					if rowList[v.row] then

						v.row = v.row + offset

						table.insert(final.events, v)

					end

				end

			end

		end

		-- Add the rooms
		if actions.addRooms then

			for _,v in ipairs(input.events) do

				if types[v.type] == TYPE_ROOM then

					table.insert(final.events, v)

				end

			end

		end

		-- Add the VFX
		if actions.addVFX then

			for _,v in ipairs(input.events) do

				if types[v.type] == TYPE_VFX then

					if not v.row then

						table.insert(final.events, v)

					else

						if v.row == -1 then

							table.insert(final.events, v)

						else

							if rowList[v.row] then

								v.row = v.row + rowList[v.row]
								table.insert(final.events, v)

							end

						end

					end

				end

			end

		end

		-- Add the SFX
		if actions.addSFX then

			for _,v in ipairs(input.events) do

				if types[v.type] == TYPE_SFX then

					if not v.row then

						table.insert(final.events, v)

					else

						if rowList[v.row] then

							v.row = v.row + rowList[v.row]
							table.insert(final.events, v)

						end

					end

				end

			end

		end

	end

	local finalStr = encoder.encodeInJsonFormat(final)

	return encoder.SUCCESS, finalStr

end

return encoder