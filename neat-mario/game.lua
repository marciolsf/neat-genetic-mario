--Notes here
config = require "config"
spritelist = require "spritelist"
local _M = {}


--#################################
--functions to get level info
--#################################

--Equally shamelessly borrowed from Dwood15 so I get level info
-- as well as a few other very smart bits
local mainmemory = mainmemory

-- Compatibility
local u8  = mainmemory.read_u8
local s8  = mainmemory.read_s8
local u16 = mainmemory.read_u16_le
local s16 = mainmemory.read_s16_le
local u24 = mainmemory.read_u24_le
local s24 = mainmemory.read_s24_le
local WRAM = {
    -- General
    game_mode = 0x0100,
    room_index = 0x00ce,
    level_index = 0x13bf,
    game_mode = 0x0100,
    end_level_timer = 0x1493,
    OW_x = 0x1f17,
    OW_y = 0x1f19,
    message_box_timer = 0x1b89
}

local SMW = {
    -- Game Modes
    game_mode_overworld = 0x0e,
    game_mode_fade_to_level = 0x0f,
    game_mode_level = 0x14

}


function _M.getMessageTimer()
	return math.floor(u8(WRAM.message_box_timer)/4)
end

function _M.getCurrentRoom()
	return bit.lshift(u8(WRAM.room_index), 16) + bit.lshift(u8(WRAM.room_index + 1), 8) + u8(WRAM.room_index + 2)
end

function _M.getLevelStats()
	return u8(WRAM.level_index), u8(WRAM.game_mode), u8(WRAM.end_level_timer), _M.getCurrentRoom()
end 


function _M.getOWPosition()
    local offset = 0
    if Current_character == "Luigi" then offset = 4 end
    
    local OW_x = s16(WRAM.OW_x + offset)
    local OW_y = s16(WRAM.OW_y + offset)

    return OW_x, OW_y
end

function _M.getPositions()

    local OW_x, OW_y

	previous_OW_x = OW_x
	previous_OW_y = OW_y

	previous_marioX = marioX
	previous_marioY = marioY
	
	OW_x, OW_y = _M.getOWPosition()
    local Current_Level_Index, game_mode, End_Level_Timer, CurrentRoomID = _M.getLevelStats()
	
	if CurrentRoomID == 0 then
        marioX = OW_x
        marioY = marioY
    else
		marioX = memory.read_s16_le(0x94)
		marioY = memory.read_s16_le(0x96)
	end
		
	local layer1x = memory.read_s16_le(0x1A);
	local layer1y = memory.read_s16_le(0x1C);

	if marioY == nil then 
		marioY = 0 
	end

	_M.screenX = marioX-layer1x
	_M.screenY = marioY-layer1y
end

function _M.getPlayerStats()
	return s16(WRAM.x), s16(WRAM.y), u24(WRAM.mario_score), u8(WRAM.game_over_time_out_flag), u8(WRAM.exit_level_byte), u8(WRAM.mario_lives)
end


function _M.getCoins()
	local coins = memory.readbyte(0x0DBF)
	return coins
end

function _M.getScore()
	local scoreLeft = memory.read_s16_le(0x0F34)
	local scoreRight = memory.read_s16_le(0x0F36)
	local score = ( scoreLeft * 10 ) + scoreRight
	return score
end

function _M.getLives()
	local lives = memory.readbyte(0x0DBE) + 1
	return lives
end

function _M.writeLives(lives)
	memory.writebyte(0x0DBE, lives - 1)
end

function _M.getPowerup()
	local powerup = memory.readbyte(0x0019)
	return powerup
end

function _M.writePowerup(powerup)
	memory.writebyte(0x0019, powerup)
end


function _M.getMarioHit(alreadyHit)
	local timer = memory.readbyte(0x1497)
	if timer > 0 then
		if alreadyHit == false then
			return true
		else
			return false
		end
	else
		return false
	end
end

function _M.getMarioHitTimer()
	local timer = memory.readbyte(0x1497)
	return timer
end

function _M.getTile(dx, dy)
	x = math.floor((marioX+dx+8)/16)
	y = math.floor((marioY+dy)/16)
		
	return memory.readbyte(0x1C800 + math.floor(x/0x10)*0x1B0 + y*0x10 + x%0x10)
end

function _M.getSprites()
	local sprites = {}
	for slot=0,11 do
		local status = memory.readbyte(0x14C8+slot)
		if status ~= 0 then
			spritex = memory.readbyte(0xE4+slot) + memory.readbyte(0x14E0+slot)*256
			spritey = memory.readbyte(0xD8+slot) + memory.readbyte(0x14D4+slot)*256
			sprites[#sprites+1] = {["x"]=spritex, ["y"]=spritey, ["good"] = spritelist.Sprites[memory.readbyte(0x009e + slot) + 1]}
		end
	end		
		
	return sprites
end

function _M.getExtendedSprites()
	local extended = {}
	for slot=0,11 do
		local number = memory.readbyte(0x170B+slot)
		if number ~= 0 then
			spritex = memory.readbyte(0x171F+slot) + memory.readbyte(0x1733+slot)*256
			spritey = memory.readbyte(0x1715+slot) + memory.readbyte(0x1729+slot)*256
			extended[#extended+1] = {["x"]=spritex, ["y"]=spritey, ["good"]  =  spritelist.extSprites[memory.readbyte(0x170B + slot) + 1]}
		end
	end		
		
	return extended
end

function _M.getInputs()
	_M.getPositions()
	
	sprites = _M.getSprites()
	extended = _M.getExtendedSprites()
	
	local inputs = {}
	local inputDeltaDistance = {}
	
	--these two are already called by getPositions(), and they're not used in here anyway
	--local layer1x = memory.read_s16_le(0x1A);
	--local layer1y = memory.read_s16_le(0x1C);
	
	
	for dy=-config.BoxRadius*16,config.BoxRadius*16,16 do
		for dx=-config.BoxRadius*16,config.BoxRadius*16,16 do
			inputs[#inputs+1] = 0
			inputDeltaDistance[#inputDeltaDistance+1] = 1
			
			tile = _M.getTile(dx, dy)
			if tile == 1 and marioY+dy < 0x1B0 then
				inputs[#inputs] = 1
			end
			
			for i = 1,#sprites do
				distx = math.abs(sprites[i]["x"] - (marioX+dx))
				disty = math.abs(sprites[i]["y"] - (marioY+dy))
				if distx <= 8 and disty <= 8 then
					inputs[#inputs] = sprites[i]["good"]
					
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
						--gui.drawLine(screenX, screenY, sprites[i]["x"] - layer1x, sprites[i]["y"] - layer1y, 0x50000000)
					end
				end
			end

			for i = 1,#extended do
				distx = math.abs(extended[i]["x"] - (marioX+dx))
				disty = math.abs(extended[i]["y"] - (marioY+dy))
				if distx < 8 and disty < 8 then
					
					--console.writeline(screenX .. "," .. screenY .. " to " .. extended[i]["x"]-layer1x .. "," .. extended[i]["y"]-layer1y) 
					inputs[#inputs] = extended[i]["good"]
					local dist = math.sqrt((distx * distx) + (disty * disty))
					if dist > 8 then
						inputDeltaDistance[#inputDeltaDistance] = mathFunctions.squashDistance(dist)
						--gui.drawLine(screenX, screenY, extended[i]["x"] - layer1x, extended[i]["y"] - layer1y, 0x50000000)
					end
					--if dist > 100 then
						--dw = mathFunctions.squashDistance(dist)
						--console.writeline(dist .. " to " .. dw)
						--gui.drawLine(screenX, screenY, extended[i]["x"] - layer1x, extended[i]["y"] - layer1y, 0x50000000)
					--end
					--inputs[#inputs] = {["value"]=-1, ["dw"]=dw}
				end
			end
		end
	end
	
	return inputs, inputDeltaDistance
end

function _M.clearJoypad()
	controller = {}
	for b = 1,#config.ButtonNames do
		controller["P1 " .. config.ButtonNames[b]] = false
		--console.writeline("Set " .. config.ButtonNames[b] .. " to false")
	end
	joypad.set(controller)
end

function _M.moveOveworld()
	controller["Left"] = false
	controller["Up"] = false
	controller["Down"] = false
	controller["Right"] = false
	controller["Down"] = false


	for i=1,20 do


		joypad.set(controller,1)
		
		controller["Left"] = true
		controller["A"] = true
		joypad.set(controller,1)

		console.writeline(buttons)

		buttons = joypad.get(1)



	end
--	joypad.set(controller)


end


return _M

