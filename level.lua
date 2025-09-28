function startLevel(level)
    local BeansCount = math.max(6, 2 + (level - 1) * 2)
    settings.BeansCount = BeansCount
    
    if settings.difficulty == 2 then 
        BeansCount = math.max(3, math.floor(settings.BeansCount * 0.6)) 
    elseif settings.difficulty == 3 then 
        BeansCount = math.max(1, math.floor(settings.BeansCount * 0.25)) 
    end
    
    settings.BeansCount = BeansCount
    gameInit()
    gameState = "playing"
end
-- function startLevel(level)
--     currentLevel = level
--     gameInit()
--     gameState = "playing"
--     levelCompleted = false
--     levelCompleteTimer = 0
-- end

function drawLevelCompleteScreen()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.06)))
    love.graphics.printf("Level " .. tostring(currentLevel) .. " Completed!", 0, screenHeight/2 - 80, screenWidth, "center")
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.03)))
    
    local btnW = screenWidth * 0.28
    local btnH = screenHeight * 0.09
    local btnX = (screenWidth - btnW) / 2
    local btnY = screenHeight/2 + 10
    love.graphics.setColor(0.2, 0.7, 0.2)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 12, 12)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Play Level " .. tostring(currentLevel + 1), btnX, btnY + btnH/3, btnW, "center")
end

function handleLevelCompleteInput(key)
    if key == "space" or key == "return" or key == "kpenter" then
        currentLevel = currentLevel + 1
        startLevel(currentLevel)
    elseif key == "escape" then
        love.event.quit()
    end
end


function handleLevelCompleteMouseInput(x, y)
    local btnW = screenWidth * 0.28
    local btnH = screenHeight * 0.09
    local btnX = (screenWidth - btnW) / 2
    local btnY = screenHeight/2 + 10
    if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
        currentLevel = currentLevel + 1
        startLevel(currentLevel)
        return
    end
end