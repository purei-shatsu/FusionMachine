local Sound = require("Sound")
local DisplayGroups = require("DisplayGroups")
local CardView = require("CardView")
local Camera = require("Camera")

local Animator = {}

local zero = 1e-5
local effect = {
    spiral = display.newImageRect(DisplayGroups.effects, "images/spiral.png", 600, 600),
    white = display.newRect(
        DisplayGroups.effects,
        display.contentCenterX,
        display.contentCenterY,
        display.actualContentWidth,
        display.actualContentHeight
    ),
    flare = {}
}
effect.spiral.alpha = 0
effect.white.alpha = 0
effect.white:setFillColor(1)
for i = 1, 5 do
    effect.flare[i] = display.newImageRect(DisplayGroups.effects, "images/flare.png", 420, 277)
    effect.flare[i].alpha = 0
end

local resumeCoroutine
local delay
function Animator.performFusion(hand, materials, results, callback)
    resumeCoroutine =
        coroutine.wrap(
        function()
            Animator._hideNonMaterials(hand, materials)
            Animator._moveMaterialsToStartPosition(materials)
            local finalCard = Animator._fuseMaterials(materials, results)
            callback(finalCard)
        end
    )
    resumeCoroutine()
end

function Animator._resetDelay()
    delay = 0
end

function Animator._addDelay(duration)
    delay = delay + duration
end

function Animator._hideNonMaterials(hand, materials)
    Animator._resetDelay()

    --make a dictionary of material cards
    local isMaterial = {}
    for _, card in ipairs(materials) do
        isMaterial[card] = true
    end

    --find which cards in hand are not materials
    local nonMaterials = {}
    for _, card in ipairs(hand) do
        if not isMaterial[card] then
            table.insert(nonMaterials, card)
        end
    end

    --move non-materials off-screen
    if #nonMaterials > 0 then
        local bottomY = display.contentHeight + 0.5 * nonMaterials[1].height
        local topY = -display.contentHeight - 0.5 * nonMaterials[1].height
        local duration = 200
        local side = nonMaterials[1]:getSide()
        for _, card in ipairs(nonMaterials) do
            transition.to(
                card.displayObject,
                {
                    time = duration,
                    transition = easing.inSine,
                    delay = delay,
                    y = side == 1 and bottomY or topY
                }
            )
        end
        Animator._addDelay(duration)
    end
end

function Animator._moveMaterialsToStartPosition(materials)
    local duration = 400
    local side = materials[1]:getSide()
    local centerY = display.contentCenterY + Camera.getY()
    --move first material to correct position
    transition.to(
        materials[1].displayObject,
        {
            time = duration,
            transition = easing.inOutSine,
            delay = delay,
            x = materials[1].width / 2,
            y = centerY
        }
    )
    materials[1].displayObject:toFront()

    --move other to correct positions, putting first cards on front
    for i = #materials, 2, -1 do
        local card = materials[i]
        card.displayObject:toFront()
        transition.to(
            card.displayObject,
            {
                time = duration,
                transition = easing.inOutSine,
                delay = delay,
                x = display.contentWidth - card.width * (0.5 + (#materials - i) / 3) + 150,
                y = centerY
            }
        )
    end
end

function Animator._fuseMaterials(materials, results)
    effect.white.y = display.contentCenterY + Camera.getY()

    local bottomY = display.contentHeight + materials[1].height / 2 + Camera.getY()
    local contentCenterY = display.contentCenterY + Camera.getY()
    timer.performWithDelay(400 + delay, resumeCoroutine)
    coroutine.yield()
    Animator._resetDelay()

    local materialA = materials[1]
    local side = materialA:getSide()

    for i, resultModel in ipairs(results) do
        local materialB = materials[i + 1]

        --bring both materials to front
        materialA.displayObject:toFront()
        materialB.displayObject:toFront()

        --move right material towards left material
        local duration = (materialB.displayObject.x - materialA.displayObject.x) / 5
        transition.to(
            materialB.displayObject,
            {
                time = duration,
                onStart = Sound.playWrapper("move"),
                transition = easing.linear,
                delay = delay,
                x = materialA.displayObject.x
            }
        )
        Animator._addDelay(duration)

        --if result is not right material, then fusion was a success
        if resultModel ~= materialB:getModel() then
            --start fusion!
            local centerX, centerY = materialA.displayObject.x, materialA.displayObject.y
            duration = 300
            local duration2 = duration / 2
            local radius = materialA.width * 0.6

            --flip both cards
            materialA:rotateCardTo(
                {
                    angle = -math.pi / 2,
                    time = duration2,
                    delay = delay
                }
            )
            materialB:rotateCardTo(
                {
                    angle = -math.pi / 2,
                    time = duration2,
                    delay = delay,
                    onComplete = resumeCoroutine
                }
            )
            Animator._resetDelay()
            Animator._addDelay(duration - duration2)
            coroutine.yield()

            materialB.displayObject.x = materialB.displayObject.x + 2 * radius
            materialA:setCardRotation(math.pi / 2)
            materialB:setCardRotation(math.pi / 2)
            materialA:rotateCardTo(
                {
                    angle = 0,
                    time = duration2,
                    delay = 0
                }
            )
            materialB:rotateCardTo(
                {
                    angle = 0,
                    time = duration2,
                    delay = 0
                }
            )

            --spiral around each other
            local totalTime
            local initialTime
            duration = 1000
            local rotations = 2.75
            centerX = centerX + radius --translate center to keep A on it's original position
            Animator._executeEveryFrame(
                {
                    time = duration,
                    transition = easing.inSine,
                    delay = delay,
                    onStart = function()
                        Sound.play("fusion")

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
                        transition.to(
                            spiral,
                            {
                                time = duration,
                                transition = easing.linear,
                                alpha = 1,
                                xScale = finalScale,
                                yScale = finalScale,
                                rotation = 540,
                                onComplete = function()
                                    spiral.alpha = 0
                                end
                            }
                        )

                        --show flares
                        for i = 1, #effect.flare do
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
                            local flareDelay = duration * 0.4
                            transition.to(
                                flare,
                                {
                                    alpha = 0.5,
                                    time = duration - flareDelay,
                                    delay = flareDelay,
                                    transition = easing.linear,
                                    xScale = finalScale,
                                    yScale = finalScale,
                                    rotation = finalAngle,
                                    onComplete = function()
                                        flare.alpha = 0
                                    end
                                }
                            )
                        end
                    end,
                    onFrame = function(completion)
                        --apply spiral parametrics
                        local timeRadius = radius * (1 - completion)
                        local angle = rotations * 2 * math.pi * completion
                        materialA.displayObject.x = centerX + timeRadius * math.cos(angle + math.pi)
                        materialA.displayObject.y = centerY + timeRadius * math.sin(angle + math.pi)
                        materialB.displayObject.x = centerX + timeRadius * math.cos(angle)
                        materialB.displayObject.y = centerY + timeRadius * math.sin(angle)
                    end,
                    onComplete = resumeCoroutine
                }
            )
            coroutine.yield()
            Animator._resetDelay()

            --play sound
            Sound.play("fusionEnd")

            --blink white
            effect.white.alpha = 1
            local duration = 500
            transition.to(effect.white, {time = duration, transition = easing.linear, alpha = 0})

            --destroy materials
            materialA.displayObject:removeSelf()
            materialB.displayObject:removeSelf()

            --finish fusion
            Animator._addDelay(duration * 0.3)
            local resultView = CardView:new(resultModel, side, 1)
            resultView.displayObject.x = centerX
            resultView.displayObject.y = centerY
            resultView.displayObject.xScale = 1.7
            resultView.displayObject.yScale = 1.7
            resultView:setCardRotation(math.pi / 2)
            resultView:rotateCardTo({angle = 0, time = duration2, delay = delay})
            Animator._addDelay(duration2 + 500)
            resultView:rotateCardTo(
                {
                    angle = -math.pi / 2,
                    time = duration2,
                    delay = delay,
                    onComplete = function()
                        resultView.displayObject.xScale = 1
                        resultView.displayObject.yScale = 1
                        resultView:setCardRotation(math.pi / 2)
                        resultView:rotateCardTo({angle = 0, time = duration2})
                    end
                }
            )

            --go to next material
            Animator._addDelay(200) --duration of fusion result frozen for admiration
            duration = 500
            centerX = centerX - radius --undo center translation
            transition.to(
                resultView.displayObject,
                {
                    time = duration,
                    transition = easing.inOutSine,
                    delay = delay,
                    x = centerX,
                    onComplete = resumeCoroutine
                }
            )
            coroutine.yield()
            Animator._resetDelay()

            materialA = resultView
        else --fusion failed, throw left material away
            --move up
            local duration = 100
            local duration2 = duration
            local delay2 = delay
            local jumpHeight = 50
            transition.to(
                materialA.displayObject,
                {
                    time = duration,
                    onStart = Sound.playWrapper("discard"),
                    transition = easing.outQuad,
                    delay = delay,
                    y = -jumpHeight,
                    delta = true
                }
            )

            --move down
            Animator._addDelay(duration)
            local a = jumpHeight / (duration * duration)
            local b = -2 * jumpHeight / duration
            local c = contentCenterY - bottomY
            local x1 = (-b + (b * b - 4 * a * c) ^ 0.5) / (2 * a)
            local x2 = (-b - (b * b - 4 * a * c) ^ 0.5) / (2 * a)
            duration = math.max(x1, x2) - duration
            duration2 = duration2 + duration
            transition.to(
                materialA.displayObject,
                {
                    time = duration,
                    transition = easing.inQuad,
                    delay = delay,
                    y = bottomY
                }
            )
            delay2 = delay2
            transition.to(
                materialA.displayObject,
                {
                    time = duration2,
                    transition = easing.linear,
                    delay = delay2,
                    x = b * duration2,
                    delta = true,
                    onComplete = function()
                        timer.performWithDelay(150, resumeCoroutine)
                    end
                }
            )
            coroutine.yield()
            Animator._resetDelay()

            materialA = materialB
        end
    end

    --materialA will contain the last remaining card
    return materialA
end

function Animator._executeEveryFrame(param)
    local duration = param.time
    local easing = param.transition or easing.linear
    timer.performWithDelay(
        param.delay,
        function(event)
            if param.onStart then
                param.onStart()
            end
            local initialTime = event.time
            local function enterFrame(event)
                totalTime = math.min(event.time - initialTime, duration) --cap at max to choose correct position
                param.onFrame(easing(totalTime, duration, 0, 1)) --execute onFrame callback
                if totalTime >= duration then
                    Runtime:removeEventListener("enterFrame", enterFrame)
                    if param.onComplete then
                        param.onComplete()
                    end
                end
            end
            Runtime:addEventListener("enterFrame", enterFrame)
        end
    )
end

return Animator
