--[[Game Rules
Very modified:
	Can only play each zone once per turn (prevents boring semi-safe fusions)
	Can play a max of 8 stars from hand per turn
Slightly modified
	Can only play one card/fusion per turn (same as original)
	[MAYBE] Total levels of cards in the deck can't go over a certain value
		Provavelmente é desnecessário, já é melhor usar cartas com atk 0 pra fazer fusões rápidas
Only monsters with atk<=3000 and def<=3000 can go into the main deck (the rest can only be obtained through fusion)
Rest are Forbidden Memories rules
[TODO Spells/equips/traps]
--]]

--[[TODO
Effects:
	Particles
]]

require 'utils'
local sqlite3 = require("sqlite3")

local path = system.pathForFile("cards.cdb")
local db = sqlite3.open(path)
local zero = 1e-5

--override transition.to to allow slow mode
--[[
local oldTransTo = transition.to
local slow = 1
function transition.to(target, param)
	if param.time then
		param.time = param.time*slow
	end
	if param.delay then
		param.delay = param.delay*slow
	end
	oldTransTo(target, param)
end
--]]

local sound = {
	confirm = audio.loadSound("sounds/confirm.mp3"),
	material = audio.loadSound("sounds/material.mp3"),
	move = audio.loadSound("sounds/move.mp3"),
	discard = audio.loadSound("sounds/discard.mp3"),
	fusion = audio.loadSound("sounds/fusion.mp3"),
	fusionEnd = audio.loadSound("sounds/fusionEnd.mp3"),
}

--clear memory
local function onSystemEvent(event)
    if event.type=="applicationExit" then
    	for i,s in pairs(sound) do
    		audio.dispose(s)
    	end
    	sound = nil
    	collectgarbage()
        db:close()
    end
end
Runtime:addEventListener("system", onSystemEvent)

--[[
for card in db:nrows('select * from datas as d inner join texts as t on d.id==t.id order by atk,def') do
	print(card.name, card.level, card.atk, card.def)
end
--]]

local cardsGroup = display.newGroup()
local effectsGroup = display.newGroup()
local uiGroup = display.newGroup()

local hand = {}
local material = {}
local scale = 1.5
local cardWidth, cardHeight = 177*scale, 254*scale
local effect = {
	spiral = display.newImageRect(effectsGroup, 'images/spiral.png', 600, 600),
	white = display.newRect(effectsGroup, display.contentCenterX, display.contentCenterY, display.actualContentWidth, display.actualContentHeight),
	flare = {},
}
effect.spiral.alpha = 0
effect.white.alpha = 0
effect.white:setFillColor(1)
for i=1,5 do
	effect.flare[i] = display.newImageRect(effectsGroup, 'images/flare.png', 420, 277)
	effect.flare[i].alpha = 0
end

local fov = 500
local function getCardRotationPath(angle)
	local dx = cardWidth*0.5*(1-math.cos(angle))
	--local dz = cardWidth*0.5*(1-math.sin(angle))
	--local fz1 = fov/(dz+fov)
	--local fz2 = fov/(-dz+fov)
	local dy = cardHeight*0.1*(math.sin(angle))
	return {
		x1 =  dx, y1 = -dy,
		x2 =  dx, y2 = dy,
		x3 = -dx, y3 = -dy,
		x4 = -dx, y4 = dy,
	}
end

local function setCardRotation(path, angle)
	for p,v in pairs(getCardRotationPath(angle)) do
		path[p] = v
	end
end

local function rotateCardTo(target, params)
	for p,v in pairs(getCardRotationPath(params.angle)) do
		params[p] = v
	end
	transition.to(target, params)
end

local canPlaySound = false
local function playSoundF(name)
	--if canPlaySound then
		return function()
			audio.play(sound[name])
		end
	--end
end

--select five non-special cards for starting hand
for card in db:nrows('select * from datas as d inner join texts as t on d.id==t.id and atk<=3000 and def<=3000 order by random() limit 5') do
	hand[#hand+1] = card
	card.image = display.newImageRect(cardsGroup, 'pics/' .. card.id .. '.jpg', cardWidth, cardHeight)
	local finalX = display.contentCenterX + (#hand-3)*card.image.width
	card.image.x = finalX + display.contentWidth*1.5
	card.image.y = display.contentCenterY
	--card.image.y = card.image.height/2
	transition.to(card.image, {time=250, onStart=playSoundF('move'), transition=easing.outSine, delay=150*(#hand-1), x=finalX})
	
	--fusion material number
	local materialNumber = {}
	materialNumber.rect = display.newRoundedRect(uiGroup, finalX-card.image.width/2+22, card.image.y-card.image.height/2, 50, 30, 5)
	materialNumber.rect.strokeWidth = 4
	materialNumber.rect:setFillColor(0.15)
	materialNumber.rect:setStrokeColor(0.63)
	materialNumber.text = display.newText(uiGroup, #hand, materialNumber.rect.x, materialNumber.rect.y, native.systemFont, 36)
	materialNumber.text:setFillColor(0.38, 0.5, 0.97)
	materialNumber.text:setStrokeColor(0.01, 0.25, 0.49)
	materialNumber.text.alpha = 0
	materialNumber.rect.alpha = 0
	card.materialNumber = materialNumber
	
	local function tap()
		if canPlaySound then
			audio.play(sound.material)
		end
		if card.isMaterial then
			--unmark
			materialNumber.text.alpha = 0
			materialNumber.rect.alpha = 0
			card.image.y = card.image.y + 20
			
			--remove from table
			for i=#material,1,-1 do
				if material[i]==card then
					table.remove(material, i)
					break
				end
			end
			
			--update texts
			for i,m in ipairs(material) do
				m.materialNumber.text.text = i
			end
			
		else
			--mark
			table.insert(material, card)
			materialNumber.text.text = #material
			materialNumber.text.alpha = 1
			materialNumber.rect.alpha = 1
			card.image.y = card.image.y - 20
		end
		card.isMaterial = not card.isMaterial
	end
	--if math.random(5)~=5 then
		tap() --TODO deleta isso
	--end
	card.image:addEventListener('tap', tap)
end
canPlaySound = true

local function executeEveryFrame(param)
	local duration = param.time
	local easing = param.transition or easing.linear
	timer.performWithDelay(param.delay, function(event)
		if param.onStart then
			param.onStart()
		end
		local initialTime = event.time
		local function enterFrame(event)
			totalTime = math.min(event.time-initialTime, duration) --cap at max to choose correct position
			param.onFrame(easing(totalTime, duration, 0, 1)) --execute onFrame callback
			if totalTime>=duration then
				Runtime:removeEventListener("enterFrame", enterFrame)
				if param.onComplete then
					param.onComplete()
				end
			end
		end
		Runtime:addEventListener("enterFrame", enterFrame)
	end)
end

--keyboard
local lastFusion --TODO deleta isso
local function performFusion()
	--stop all transitions
	transition.cancel()

	local bottomY = display.contentHeight+hand[1].image.height/2
	if lastFusion then
		--hide last fusion (TODO deleta isso)
		lastFusion.image.y = bottomY
	end

	local isMat = {}
	for i,m in ipairs(material) do
		m.materialNumber.text.alpha = 0
		m.materialNumber.rect.alpha = 0
		isMat[m] = true
	end

	--hide non-material cards
	local duration = 200
	local delay = 0
	for i,c in ipairs(hand) do
		if not isMat[c] then
			transition.to(c.image, {time=duration, transition=easing.inSine, delay=delay, y=bottomY})
		end
	end

	--move other to correct positions, putting first cards on front
	delay = delay + duration
	duration = 400
	for i=#material,2,-1 do
		local m = material[i]
		m.image:toFront()
		transition.to(m.image, {time=duration, transition=easing.inOutSine, delay=delay, x=display.contentWidth-m.image.width*(0.5+(#material-i)/3)+150, y=display.contentCenterY})
	end

	--move first material to correct position
	local lastCard = material[1]
	transition.to(lastCard.image, {time=duration, transition=easing.inOutSine, delay=delay, x=lastCard.image.width/2, y=display.contentCenterY})

	--move other materials
	local mid = 1
	local function useNextMaterial()
		mid = mid + 1
		local m = material[mid]
		if not m then
			return
		end
			
		--send target to back
		lastCard.image:toBack()
		
		--move card towards target
		delay = 0
		duration = (m.image.x-lastCard.image.x)/5
		transition.to(m.image, {time=duration, onStart=playSoundF('move'), transition=easing.linear, delay=delay, x=lastCard.image.x})
		delay = delay + duration
		
		--check fusion
		--biggest atk within (if atk draws, use def, then id):
		--Type from one and attribute from the other
		--Atk no bigger than total def
		--Atk bigger than both or (both atks are 0 and def bigger than both)
		local a = lastCard
		local b = m
		local sql = string.format([[
		select * from datas as d inner join texts as t on d.id==t.id where
		((race==%d and attribute==%d) or (race==%d and attribute==%d)) and
		atk<=%d and (atk>%d or (%d==0 and def>%d))
		order by atk desc,def desc,id limit 1
		]], a.race, b.attribute, b.race, a.attribute, a.def+b.def, math.max(a.atk, b.atk), math.max(a.atk, b.atk), math.max(a.def, b.def))
		
		local success = false
		for fusion in db:nrows(sql) do
			success = true
			local centerX,centerY = lastCard.image.x, lastCard.image.y
			
			--start fusion!
			duration = 300
			local duration2 = duration/2
			local radius = a.image.width*0.6
			rotateCardTo(a.image.path, {angle=-math.pi/2, time=duration2, delay=delay})
			rotateCardTo(b.image.path, {angle=-math.pi/2, time=duration2, delay=delay, onComplete=function()
				b.image.x = b.image.x + 2*radius
				setCardRotation(a.image.path, math.pi/2)
				setCardRotation(b.image.path, math.pi/2)
				rotateCardTo(a.image.path, {angle=0, time=duration2, delay=0})
				rotateCardTo(b.image.path, {angle=0, time=duration2, delay=0})
			end})
			--transition.to(b.image, {time=duration, transition=easing.outSine, delay=delay, x=2*radius, delta=true})
			delay = delay + duration
			
			--spiral around each other
			local totalTime
			local initialTime
			duration = 1000
			local rotations = 2.75
			centerX = centerX + radius --translate center to keep A on it's original position
			executeEveryFrame({time=duration, transition=easing.inSine, delay=delay, onStart=function()
				audio.play(sound.fusion)

				--show spiral image gradually
				local spiral = effect.spiral
				spiral.alpha = 0
				spiral.x = centerX
				spiral.y = centerY
				spiral.rotation = 0
				local initialScale = 0.5
				local finalScale = 1.5
				spiral.xScale = initialScale
				spiral.yScale = initialScale
				transition.to(spiral, {time=duration, transition=easing.linear, alpha=0.8, xScale=finalScale, yScale=finalScale, rotation=540, onComplete=function()
					spiral.alpha = 0
				end})

				--show flares
				for i=1,#effect.flare do
					--choose initial and final angle
					local initialAngle = math.random(360)
					local finalAngle = initialAngle + math.random(-90, 90)

					--show, scale and rotate flare
					local flare = effect.flare[i]
					flare.alpha = 0
					flare.x = centerX
					flare.y = centerY
					initialScale = zero
					finalScale = math.random(2.5, 3.5)
					flare.rotation = initialAngle
					flare.xScale = initialScale
					flare.yScale = initialScale
					local flareDelay = duration*0.4
					transition.to(flare, {alpha=0.5, time=duration-flareDelay, delay=flareDelay, transition=easing.linear, xScale=finalScale, yScale=finalScale, rotation=finalAngle, onComplete=function()
						flare.alpha = 0
					end})
				end

			end, onFrame=function(completion)
				--apply spiral parametrics
				local timeRadius = radius*(1-completion)
				local angle = rotations*2*math.pi*completion
				a.image.x = centerX + timeRadius*math.cos(angle + math.pi)
				a.image.y = centerY + timeRadius*math.sin(angle + math.pi)
				b.image.x = centerX + timeRadius*math.cos(angle)
				b.image.y = centerY + timeRadius*math.sin(angle)

			end, onComplete=function()
				--play sound
				audio.play(sound.fusionEnd)

				--show white
				effect.white.alpha = 1
				local duration = 500
				transition.to(effect.white, {time=duration, transition=easing.linear, alpha=0})
				
				--TODO actually destroy materials
				b.image.y = bottomY
				a.image.y = bottomY

				--finish fusion
				delay = duration*0.3 --TODO wait some time before fusion appears
				lastCard = fusion
				lastCard.image = display.newImageRect(cardsGroup, 'pics/' .. fusion.id .. '.jpg', cardWidth, cardHeight)
				lastCard.image.x = centerX
				lastCard.image.y = centerY
				lastCard.image.xScale = 1.7
				lastCard.image.yScale = 1.7
				setCardRotation(lastCard.image.path, math.pi/2)
				rotateCardTo(lastCard.image.path, {angle=0, time=duration2, delay=delay})
				delay = delay + duration2 + 500
				rotateCardTo(lastCard.image.path, {angle=-math.pi/2, time=duration2, delay=delay, onComplete=function()
					lastCard.image.xScale = 1
					lastCard.image.yScale = 1
					setCardRotation(lastCard.image.path, math.pi/2)
					rotateCardTo(lastCard.image.path, {angle=0, time=duration2})
				end})
				lastFusion = lastCard
				
				--go to next material
				delay = delay + 200 --duration of fusion result frozen for admiration
				duration = 500
				centerX = centerX - radius --undo center translation
				transition.to(lastCard.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX, onComplete=function()
					useNextMaterial()
				end})
			end})
		end
		
		if not success then
			--throw last card away
			duration = 100
			local duration2 = duration
			local delay2 = delay
			local jumpHeight = 50
			transition.to(lastCard.image, {time=duration, onStart=playSoundF('discard'),transition=easing.outQuad, delay=delay, y=-jumpHeight, delta=true})
			delay = delay + duration
			local a = jumpHeight/(duration*duration)
			local b = -2*jumpHeight/duration
			local c = display.contentCenterY-bottomY
			local x1 = (-b + (b*b-4*a*c)^0.5)/(2*a)
			local x2 = (-b - (b*b-4*a*c)^0.5)/(2*a)
			duration = math.max(x1, x2) - duration
			duration2 = duration2 + duration
			transition.to(lastCard.image, {time=duration, transition=easing.inQuad, delay=delay, y=bottomY})
			delay2 = delay2
			transition.to(lastCard.image, {time=duration2, transition=easing.linear, delay=delay2, x=b*duration2, delta=true, onComplete=function()
				timer.performWithDelay(150, useNextMaterial)
			end})
			delay = delay + duration
			lastCard = m
		end
	end
	transition.to({}, {time=duration, delay=delay, onComplete=useNextMaterial})
end
--performFusion() --TODO deleta isso


Runtime:addEventListener("key", function(event)
	if event.keyName=="space" and event.phase=='down' and #material>0 then
		audio.play(sound.confirm)
		performFusion()
	end
	if event.keyName=="x" then
		slow = event.phase=='down' and 4 or 1
	end
end)


















