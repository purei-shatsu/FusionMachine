--[[Game Rules
Very modified:
	Can only play each zone once per turn (prevents boring semi-safe fusions)
	Can play a max of 8 stars from hand per turn
Slightly modified
	Só pode jogar uma carta/fusão por turno (igual ao original)
	Nível total das cartas do deck não pode passar de um certo valor
Only non-fusion and non-ritual can go into the main deck (fusion and rituals can only be obtained through fusion)
Rest are Forbidden Memories rules
[TODO Spells/equips/traps]
--]]

local sqlite3 = require("sqlite3")

local path = system.pathForFile("cards.cdb")
local db = sqlite3.open(path)

--override transition.to to allow slow mode
local oldTransTo = transition.to
local slow = 1
function transition.to(target, param)
	param.time = param.time*slow
	param.delay = param.delay*slow
	oldTransTo(target, param)
end

local function onSystemEvent(event)
    if event.type=="applicationExit" then             
        db:close()
    end
end
Runtime:addEventListener("system", onSystemEvent)

for card in db:nrows('select * from datas as d inner join texts as t on d.id==t.id order by atk,def') do
	print(card.name, card.level, card.atk, card.def)
end

local cardsGroup = display.newGroup()
local uiGroup = display.newGroup()

local hand = {}
local material = {}
local scale = 1.5
for card in db:nrows('select * from datas as d inner join texts as t on d.id==t.id order by random() limit 5') do
	hand[#hand+1] = card
	card.image = display.newImageRect(cardsGroup, 'pics/' .. card.id .. '.jpg', 177*scale, 254*scale)
	local finalX = display.contentCenterX + (#hand-3)*card.image.width
	card.image.x = finalX + display.contentWidth*1.5
	card.image.y = display.contentCenterY
	--card.image.y = card.image.height/2
	transition.to(card.image, {time=250, transition=easing.outSine, delay=150*(#hand-1), x=finalX})
	
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
	tap() --TODO deleta isso
	card.image:addEventListener('tap', tap)
end

--keyboard
local lastFusion --TODO deleta isso
Runtime:addEventListener("key", function(event)
	if event.keyName=="space" and event.phase=='down' and #material>0 then
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
		
		--move first material to second card position
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
			transition.to(m.image, {time=duration, transition=easing.linear, delay=delay, x=lastCard.image.x})
			delay = delay + duration
			
			--check fusion
			--biggest atk within (if atk draws, use def, then id):
			--((a-type and b-attribute) or (b-type and a-attribute)) and
			--atk>a.atk and atk>b.atk and atk<=a.def+b.def
			local a = lastCard
			local b = m
			local sql = string.format([[
			select * from datas as d inner join texts as t on d.id==t.id where
			((race==%d and attribute==%d) or (race==%d and attribute==%d)) and
			atk>%d and atk<=%d
			order by atk desc,def desc,id limit 1
			]], a.race, b.attribute, b.race, a.attribute, math.max(a.atk, b.atk), a.def+b.def)
			
			local success = false
			for fusion in db:nrows(sql) do
				success = true
				local centerX,centerY = lastCard.image.x, lastCard.image.y
				
				--start fusion!
				duration = 500
				local radius = a.image.width*0.6
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay, x=-radius, delta=true})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay, x=radius, delta=true})
				delay = delay + duration
				
				--spiral around each other
				local radiusFactor = 0.8
				duration = 500
				transition.to(a.image, {time=duration/2, transition=easing.outSine, delay=delay, y=centerY-radius})
				transition.to(b.image, {time=duration/2, transition=easing.outSine, delay=delay, y=centerY+radius})
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX+radius})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX-radius})
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay+duration/2, y=centerY+radius})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay+duration/2, y=centerY-radius})
				delay = delay + duration
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX-radius})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX+radius})
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay+duration/2, y=centerY-radius})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay+duration/2, y=centerY+radius})
				delay = delay + duration
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX+radius})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay, x=centerX-radius})
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration, transition=easing.inOutSine, delay=delay+duration/2, y=centerY+radius})
				transition.to(b.image, {time=duration, transition=easing.inOutSine, delay=delay+duration/2, y=centerY-radius})
				delay = delay + duration
				radius = radius*radiusFactor
				transition.to(a.image, {time=duration/2, transition=easing.inSine, delay=delay, x=centerX})
				transition.to(b.image, {time=duration/2, transition=easing.inSine, delay=delay, x=centerX})
				delay = delay + duration
				
				transition.to({}, {time=0, delay=delay, onComplete=function()
					--complete fusion
					lastCard = fusion
					lastCard.image = display.newImageRect(cardsGroup, 'pics/' .. fusion.id .. '.jpg', 177*scale, 254*scale)
					lastCard.image.x = centerX
					lastCard.image.y = centerY
					lastFusion = lastCard
					
					--TODO actually destroy materials
					b.image.y = bottomY
					a.image.y = bottomY
					
					--go to next material
					duration = 100
					delay = duration
					transition.to({}, {time=duration, delay=delay, onComplete=function()
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
				transition.to(lastCard.image, {time=duration, transition=easing.outQuad, delay=delay, y=-jumpHeight, delta=true})
				delay = delay + duration
				local a = jumpHeight/(duration*duration)
				local b = -2*jumpHeight/duration
				local c = display.contentCenterY-bottomY
				local x1 = (-b + (b*b-4*a*c)^0.5)/(2*a)
				local x2 = (-b - (b*b-4*a*c)^0.5)/(2*a)
				duration = math.max(x1, x2) - duration
				duration2 = duration2 + duration
				transition.to(lastCard.image, {time=duration, transition=easing.inQuad, delay=delay, y=bottomY})
				transition.to(lastCard.image, {time=duration2, transition=easing.linear, delay=delay2, x=b*duration2, delta=true, onComplete=useNextMaterial})
				delay = delay + duration
				lastCard = m
			end
		end
		transition.to({}, {time=duration, delay=delay, onComplete=useNextMaterial})
	end
	if event.keyName=="x" then
		slow = event.phase=='down' and 4 or 1
	end
end)




















