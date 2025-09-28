-- requiring stuff 
require "level"
require "utils"
require "player"

-- Game state management
gameState = "home"
showIntro = true
gameOver = false
levelCompleted = false
levelCompleteTimer = 0
currentLevel = 1
highscore = 0

-- Screen dimensions
screenWidth, screenHeight = 0, 0

-- Game settings
settings = {
    backgroundColor = {0.12, 0.12, 0.12},
    backgroundColorName = "Gray",
    bulletFallSpeed = 40,
    difficulty = 1,
    BeansCount = 5,
    initialAmmo = 10,
       wallBounceEnabled = true,
    bounceDamping = 0.8 
}

-- Settings UI state
settingsUI = {
    selectedInput = nil,
    inputText = "",
}


-- Game objects
Beanss = {}
bullets = {}
fallingAmmo = {}
bloodSplatters = {}

-- Game assets
playerImage = nil
bulletImage = nil

-- Audio
gunSound = nil
gunSoundTimer = 0
levelCompletionSound = love.audio.newSource("yay.mp3", "static")

-- Intro system
introScenes = {
    "welcome....\nBehind every success lies a story of sacrifice..",
    "Sacrifice your bullets to earn more."
}

introSceneTypewrite = love.audio.newSource("typewriter.wav", "static")

introSceneIndex = 1
introTextProgress = 0
introTimer = 0
introSpeed = 0.04

-- Game constants
BULLET_SPEED = 600
BULLET_SCALE = 4
RECOIL_FORCE = -400
GRAVITY = 950
AMMO_DROP_INTERVAL = 10

    love.window.setTitle("The Last Bullet")
    love.window.setMode(800, 600, {resizable=true})

    screenWidth, screenHeight = love.graphics.getDimensions()

    -- Load assets
    playerImage = love.graphics.newImage("guns/husher.png")
    bulletImage = love.graphics.newImage("bullet.png")

    -- Set pixel art filtering
    love.graphics.setDefaultFilter("nearest", "nearest")
    playerImage:setFilter("nearest", "nearest")
    bulletImage:setFilter("nearest", "nearest")

function gameInit()


    -- Reset level state
    levelCompleted = false
    levelCompleteTimer = 0
    gameOver = false

    -- Calculate Beans count based on level (base count + level)
    local baseBeansCount = settings.BeansCount
    local actualBeansCount = baseBeansCount + currentLevel
    
    -- Adjust Beans count based on difficulty
    local adjustedBeansCount = actualBeansCount
    if settings.difficulty == 2 then 
        adjustedBeansCount = math.max(3, math.floor(actualBeansCount * 0.6)) 
    elseif settings.difficulty == 3 then 
        adjustedBeansCount = math.max(1, math.floor(actualBeansCount * 0.25)) 
    end

    -- Initialize player
    player = {
        x = screenWidth / 2,
        y = screenHeight / 2,
        velocityX = 0,
        velocityY = 0,
        rotation = 0,
        smoothing = 0,
        originX = playerImage:getWidth() / 4,
        originY = playerImage:getHeight() / 2,
        scale = 4,
        score = 1,
        isAffectedByGravity = false,
        ammo = settings.initialAmmo
    }

    -- Initialize game object arrays
    bloodSplatters = {}
    Beanss = {}
    bullets = {}
    fallingAmmo = {}

    -- Create Beanss with collected counter
    for i = 1, adjustedBeansCount do
        table.insert(Beanss, {
            x = math.random(50, screenWidth - 50),
            y = math.random(50, screenHeight - 50),
            collected = false,
            timesCollected = 0
        })
    end

    fallingAmmoTimer = 0

    -- Initialize audio
    gunSound = love.audio.newSource("gun.mp3", "static")
    gunSound:setLooping(false)
    gunSoundTimer = 0
end

function gameLoad()
    gameInit()
end
function gameUpdate(dt)
    if showIntro then
        updateIntro(dt)
        return
    end

    if gameState == "home" or gameState == "settings" then return end
    if gameOver then return end

    updatePlayer(dt)
    updateBullets(dt)
    updateBeanss(dt)
    updateFallingAmmo(dt)
    updateAudio(dt)
    checkLevelComplete()

    -- Update highscore
    if player.score > highscore then
        highscore = player.score
    end

    if levelCompleted then
        levelCompleteTimer = levelCompleteTimer + dt
        if levelCompleteTimer > 2 then
            currentLevel = currentLevel + 1
            startLevel(currentLevel)
            gameState = "playing"
        end
        return
    end
end

function updateIntro(dt)
    introTimer = introTimer + dt
    local currentText = introScenes[introSceneIndex]
    
    -- Typewriter effect
    if introTextProgress < #currentText then
        if introTimer >= introSpeed then
            introTextProgress = introTextProgress + 1
            introSceneTypewrite:stop()
            introSceneTypewrite:play()
            introTimer = 0
        end
    end
end

function updateBullets(dt)
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.x = bullet.x + math.cos(bullet.rotation) * BULLET_SPEED * dt
        bullet.y = bullet.y + math.sin(bullet.rotation) * BULLET_SPEED * dt

        -- Remove bullets that go off screen
        if bullet.x < -50 or bullet.x > screenWidth + 50 or 
           bullet.y < -50 or bullet.y > screenHeight + 50 then
            table.remove(bullets, i)
        end
    end
end

function relocateBeans(Beans)
    -- Find a new position that's not too close to the player
    local attempts = 0
    local newX, newY
    repeat
        newX = math.random(50, screenWidth - 50)
        newY = math.random(50, screenHeight - 50)
        local distanceToPlayer = math.sqrt((newX - player.x)^2 + (newY - player.y)^2)
        attempts = attempts + 1
    until distanceToPlayer > 100 or attempts > 20 -- Minimum distance from player or give up after 20 attempts
    
    Beans.x = newX
    Beans.y = newY
    Beans.collected = false
end

function updateBeanss(dt)
    for _, Beans in ipairs(Beanss) do
        if not Beans.collected then
            local playerWidth = playerImage:getWidth() * player.scale
            local playerHeight = playerImage:getHeight() * player.scale
            local BeansWidth = bulletImage:getWidth() * BULLET_SCALE
            local BeansHeight = bulletImage:getHeight() * BULLET_SCALE
            
            if math.abs(player.x - Beans.x) < (playerWidth/2 + BeansWidth/2) and 
               math.abs(player.y - Beans.y) < (playerHeight/2 + BeansHeight/2) then
                Beans.collected = true
                Beans.timesCollected = Beans.timesCollected + 1
                player.score = player.score + 1
                player.ammo = player.ammo + 2
                
                -- Relocate the Beans after a short delays
                relocateBeans(Beans)
            end
        end
    end
end

function updateFallingAmmo(dt)
    fallingAmmoTimer = fallingAmmoTimer + dt
    if fallingAmmoTimer >= AMMO_DROP_INTERVAL then
        dropAmmo()
        fallingAmmoTimer = 0
    end

    for i = #fallingAmmo, 1, -1 do
        local ammo = fallingAmmo[i]
        ammo.y = ammo.y + ammo.velocityY * dt
        
        if ammo.y > screenHeight + 20 then
            table.remove(fallingAmmo, i)
        else
            local dx = player.x - ammo.x
            local dy = player.y - ammo.y
            if dx*dx + dy*dy < (32*32) then
                player.ammo = player.ammo + 1
                table.remove(fallingAmmo, i)
            end
        end
    end
end

function updateAudio(dt)
    if gunSound:isPlaying() then
        gunSoundTimer = gunSoundTimer - dt
        if gunSoundTimer <= 0 then
            love.audio.stop(gunSound)
            gunSoundTimer = 0
        end
    end
end

function checkLevelComplete()
    if gameState == "playing" and not levelCompleted then
        local totalCollected = 0
        for _, Beans in ipairs(Beanss) do
            totalCollected = totalCollected + Beans.timesCollected
        end
        
        -- Required collections = current level (1 for level 1, 2 for level 2, etc.)
        local requiredCollections = currentLevel
        if totalCollected >= requiredCollections then
            levelCompleted = true 
            levelCompletionSound:stop()
            levelCompletionSound:play()
            gameState = "levelcomplete"
            player.velocityX = 0
            player.velocityY = 0
            player.isAffectedByGravity = false
            fallingAmmo = {} -- Clear falling ammo when level completes
        end
    end
end

function dropAmmo()
    local x = math.random(50, screenWidth - 50)
    local y = -20
    table.insert(fallingAmmo, {
        x = x, 
        y = y, 
        velocityY = settings.bulletFallSpeed
    })
end

function gameDraw()
    if showIntro then
        drawIntro()
        return
    end

    if gameState == "home" then
        drawHomeScreen()
        return
    end

    if gameState == "settings" then
        drawSettingsScreen()
        return
    end

    drawGameplay()
end

function drawIntro()
    love.graphics.clear(settings.backgroundColor)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.045)))
    
    local currentText = introScenes[introSceneIndex]
    local displayText = currentText:sub(1, introTextProgress)
    love.graphics.printf(displayText, screenWidth*0.1, screenHeight*0.35, screenWidth*0.8, "center")
    
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.025)))
    if introTextProgress >= #currentText then
        love.graphics.setColor(0.7,0.7,1)
        love.graphics.printf("Press SPACE to continue...", 0, screenHeight*0.8, screenWidth, "center")
    end
end

function drawHomeScreen()
    love.graphics.clear(settings.backgroundColor)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("The Last Bullet", 0, 120, screenWidth, "center")
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Press N for New Game", 0, 220, screenWidth, "center")
    love.graphics.printf("Press S for Settings", 0, 260, screenWidth, "center")
end

function drawSettingsScreen()
    love.graphics.clear(settings.backgroundColor)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.05)))
    love.graphics.printf("Settings", 0, screenHeight * 0.08, screenWidth, "center")
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.03)))

    local marginX = screenWidth * 0.15
    local marginY = screenHeight * 0.18
    local spacingY = screenHeight * 0.07
    local buttonW = screenWidth * 0.18
    local buttonH = screenHeight * 0.06

    -- Background color buttons
    local bgOptions = {
        {"Gray", {0.12,0.12,0.12}}, 
        {"Blue", {0.18,0.22,0.45}}, 
        {"Green", {0.1,0.25,0.1}}
    }
    
    for i, option in ipairs(bgOptions) do
        local bx = marginX + (i-1)*(buttonW + screenWidth*0.04)
        local by = marginY
        love.graphics.setColor(settings.backgroundColorName == option[1] and {0.7,0.7,1} or {0.3,0.3,0.3})
        love.graphics.rectangle("fill", bx, by, buttonW, buttonH)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(option[1], bx, by+buttonH*0.25, buttonW, "center")
    end
    
    love.graphics.setColor(1,1,1)
    love.graphics.print("BG Color: " .. settings.backgroundColorName, marginX, marginY + buttonH + screenHeight*0.01)

    -- Fall speed controls
    local fsx = marginX
    local fsy = marginY + buttonH + spacingY
    local fsw = buttonH
    local fsh = buttonH
    love.graphics.setColor({0.3,0.3,0.3})
    love.graphics.rectangle("fill", fsx, fsy, fsw, fsh)
    love.graphics.rectangle("fill", fsx+fsw+screenWidth*0.08, fsy, fsw, fsh)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("-", fsx, fsy+fsh*0.25, fsw, "center")
    love.graphics.printf("+", fsx+fsw+screenWidth*0.08, fsy+fsh*0.25, fsw, "center")
    love.graphics.print("Fall Speed: " .. tostring(settings.bulletFallSpeed), fsx+fsw+screenWidth*0.15, fsy+fsh*0.25)

    -- Difficulty buttons
    local difficulties = {{"Easy",1},{"Medium",2},{"Hard",3}}
    for i, diff in ipairs(difficulties) do
        local dx = marginX + (i-1)*(buttonW*0.7 + screenWidth*0.03)
        local dy = fsy + fsh + spacingY
        local dw = buttonW*0.7
        local dh = buttonH
        love.graphics.setColor(settings.difficulty == diff[2] and {0.7,0.7,1} or {0.3,0.3,0.3})
        love.graphics.rectangle("fill", dx, dy, dw, dh)
        love.graphics.setColor(1,1,1)
        love.graphics.printf(diff[1], dx, dy+dh*0.25, dw, "center")
    end
    
    love.graphics.setColor(1,1,1)
    local diffName = difficulties[settings.difficulty][1]
    love.graphics.print("Difficulty: " .. diffName, marginX, fsy + fsh + spacingY + buttonH + screenHeight*0.01)

    -- Input fields and other UI elements...
    drawSettingsInputFields(marginX, marginY, spacingY, buttonW, buttonH, fsy, fsh)
    drawSettingsButtons(marginX, buttonW, buttonH)
    drawSettingsSummary(marginX, marginY, spacingY, buttonW, diffName)
end

function drawSettingsInputFields(marginX, marginY, spacingY, buttonW, buttonH, fsy, fsh)
    -- Bean count input
    local bx = marginX
    local by = fsy + fsh + spacingY + buttonH + spacingY
    local bw = buttonW
    local bh = buttonH
    love.graphics.setColor(settingsUI.selectedInput == "beans" and {0.7,0.7,1} or {0.3,0.3,0.3})
    love.graphics.rectangle("fill", bx, by, bw, bh)
    love.graphics.setColor(1,1,1)
    local beanText = settingsUI.selectedInput == "beans" and settingsUI.inputText or tostring(settings.BeansCount)
    love.graphics.printf(beanText, bx, by+bh*0.25, bw, "center")
    love.graphics.print("Base Bean Count", bx+bw+screenWidth*0.03, by+bh*0.25)

    -- Initial bullets input
    local ix = marginX
    local iy = by + bh + spacingY
    local iw = buttonW
    local ih = buttonH
    love.graphics.setColor(settingsUI.selectedInput == "bullets" and {0.7,0.7,1} or {0.3,0.3,0.3})
    love.graphics.rectangle("fill", ix, iy, iw, ih)
    love.graphics.setColor(1,1,1)
    local bulletText = settingsUI.selectedInput == "bullets" and settingsUI.inputText or tostring(settings.initialAmmo)
    love.graphics.printf(bulletText, ix, iy+ih*0.25, iw, "center")
    love.graphics.print("Initial Bullets", ix+iw+screenWidth*0.03, iy+ih*0.25)
end

function drawSettingsButtons(marginX, buttonW, buttonH)
    -- Default button
    local dx = screenWidth/2 - buttonW/2
    local dy = screenHeight - buttonH*2 - screenHeight*0.03
    local dw = buttonW
    local dh = buttonH
    love.graphics.setColor({0.5,0.5,0.8})
    love.graphics.rectangle("fill", dx, dy, dw, dh)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.035)))
    love.graphics.printf("Default", dx, dy+dh*0.25, dw, "center")

    -- Back button
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.025)))
    local backW = buttonW*0.7
    local backH = buttonH
    local backX = screenWidth*0.03
    local backY = screenHeight - backH - screenHeight*0.03
    love.graphics.setColor({0.5,0.5,0.5})
    love.graphics.rectangle("fill", backX, backY, backW, backH)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Back", backX, backY+backH*0.25, backW, "center")
end

function drawSettingsSummary(marginX, marginY, spacingY, buttonW, diffName)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.022)))
    love.graphics.setColor(1,1,1)
    local summaryX = screenWidth - marginX - buttonW
    local summaryY = marginY + screenHeight * 0.10
    love.graphics.print("Current Settings:", summaryX, summaryY)
    love.graphics.print("BG Color: " .. settings.backgroundColorName, summaryX, summaryY + spacingY*0.7)
    love.graphics.print("Fall Speed: " .. tostring(settings.bulletFallSpeed), summaryX, summaryY + spacingY*1.4)
    love.graphics.print("Difficulty: " .. diffName, summaryX, summaryY + spacingY*2.1)
    love.graphics.print("Base Bean Count: " .. tostring(settings.BeansCount), summaryX, summaryY + spacingY*2.8)
    love.graphics.print("Initial Bullets: " .. tostring(settings.initialAmmo), summaryX, summaryY + spacingY*3.5)
end

function drawGameplay()
    love.graphics.clear(settings.backgroundColor)

    -- Draw crosshair
    local mouseX, mouseY = love.mouse.getPosition()
    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.setLineWidth(1)
    love.graphics.line(mouseX - 10, mouseY, mouseX + 10, mouseY)
    love.graphics.line(mouseX, mouseY - 10, mouseX, mouseY + 10)
    love.graphics.circle("line", mouseX, mouseY, 12)

    -- Draw Beanss
    for _, Beans in ipairs(Beanss) do
        if not Beans.collected then
            love.graphics.setColor(1, 1, 0)
            love.graphics.draw(
                bulletImage,
                Beans.x, Beans.y,
                0,
                BULLET_SCALE, BULLET_SCALE,
                bulletImage:getWidth()/2, bulletImage:getHeight()/2
            )
        end
    end

    -- Draw player
    love.graphics.setColor(1,1,1)
    love.graphics.draw(
        playerImage,
        player.x, player.y,
        player.rotation,
        player.scale, player.scale,
        player.originX, player.originY
    )

    -- Draw bullets
    for _, bullet in ipairs(bullets) do
        love.graphics.draw(
            bulletImage,
            bullet.x, bullet.y,
            bullet.rotation,
            BULLET_SCALE, BULLET_SCALE,
            bulletImage:getWidth()/2, bulletImage:getHeight()/2
        )
    end

    -- Draw falling ammo
    for _, ammo in ipairs(fallingAmmo) do
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.draw(
            bulletImage,
            ammo.x, ammo.y,
            0,
            BULLET_SCALE, BULLET_SCALE,
            bulletImage:getWidth()/2, bulletImage:getHeight()/2
        )
    end

    -- Draw UI
    drawGameUI()
    
    -- Draw overlays
    if gameState == "gameover" or gameOver then
        drawGameOverScreen()
    end

    if gameState == "levelcomplete" then
        drawLevelCompleteScreen()
    end
end

function drawGameUI()
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.03)))
    love.graphics.printf("Highscore: " .. tostring(highscore), 0, 8, screenWidth, "center")

    -- Calculate total collections for progress display
    local totalCollected = 0
    for _, Beans in ipairs(Beanss) do
        totalCollected = totalCollected + Beans.timesCollected
    end

    love.graphics.print("The last Bullet | Ammo: " .. tostring(player.ammo), 8, 8)

    love.graphics.setFont(love.graphics.newFont(math.floor(screenHeight * 0.025)))
    love.graphics.setColor(1,1,1)
    love.graphics.print("Level: " .. tostring(currentLevel), 8, 40)
    love.graphics.print("Collections: " .. tostring(totalCollected) .. "/" .. tostring(currentLevel), 8, 65)
    love.graphics.print("Bullets on screen: " .. tostring(#Beanss), 8, 90)
end

function drawGameOverScreen()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(1, 0, 0)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("Game Over", 0, screenHeight/2 - 40, screenWidth, "center")
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Press R to Restart", 0, screenHeight/2 + 10, screenWidth, "center")
    love.graphics.printf("Press H for Home", 0, screenHeight/2 + 40, screenWidth, "center")
end

function drawLevelCompleteScreen()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(love.graphics.newFont(32))
    love.graphics.printf("Level " .. tostring(currentLevel) .. " Complete!", 0, screenHeight/2 - 40, screenWidth, "center")
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Collectible beans are now  " .. tostring(settings.BeansCount + currentLevel + 1) .. " bullets!", 0, screenHeight/2 + 10, screenWidth, "center")
end

function handleLevelCompleteInput(key)
    if key == "space" or key == "return" then
        currentLevel = currentLevel + 1
        startLevel(currentLevel)
        gameState = "playing"
    elseif key == "h" then
        gameState = "home"
    end
end

function handleLevelCompleteMouseInput(x, y)
    -- Click anywhere to continue to next level
    currentLevel = currentLevel + 1
    startLevel(currentLevel)
    gameState = "playing"
end

-- Input handling
function inputKey(key)
    if showIntro then
        handleIntroInput(key)
        return
    end

    if gameState == "home" then
        handleHomeInput(key)
        return
    end

    if gameState == "settings" then
        handleSettingsInput(key)
        return
    end

    if gameState == "gameover" or gameOver then
        handleGameOverInput(key)
        return
    end

    if gameState == "levelcomplete" then
        handleLevelCompleteInput(key)
        return
    end

    if key == "escape" then
        love.event.quit()
    end
end

function handleIntroInput(key)
    local currentText = introScenes[introSceneIndex]
    if key == "space" then
        if introTextProgress < #currentText then
            introTextProgress = #currentText
        else
            if introSceneIndex < #introScenes then
                introSceneIndex = introSceneIndex + 1
                introTextProgress = 0
                introTimer = 0
            else
                showIntro = false
                gameState = "home"
            end
        end
    elseif key == "escape" then
        love.event.quit()
    end
end
function checkWallBounces()
    local margin = 20 
    if player.x < margin and player.velocityX < 0 then
        player.velocityX = -player.velocityX * settings.bounceDamping
        player.x = margin
    end
    if player.x > screenWidth - margin and player.velocityX > 0 then
        player.velocityX = -player.velocityX * settings.bounceDamping
        player.x = screenWidth - margin
    end
    if player.y < margin and player.velocityY < 0 then
        player.velocityY = -player.velocityY * settings.bounceDamping
        player.y = margin
    end
    -- if player.y > screenHeight - margin and player.velocityY > 0 then
    --     player.velocityY = -player.velocityY * settings.bounceDamping
    --     player.y = screenHeight - margin
    -- end
end
function handleHomeInput(key)
    if key == "n" then
        currentLevel = 1
        startLevel(currentLevel)
    elseif key == "s" then
        gameState = "settings"
    elseif key == "escape" then
        love.event.quit()
    end
end

function handleSettingsInput(key)
    if settingsUI.selectedInput then
        if key == "return" or key == "kpenter" then
            local val = tonumber(settingsUI.inputText)
            if settingsUI.selectedInput == "beans" and val and val > 0 then
                settings.BeansCount = math.floor(val)
            elseif settingsUI.selectedInput == "bullets" and val and val >= 0 then
                settings.initialAmmo = math.floor(val)
            end
            settingsUI.selectedInput = nil
            settingsUI.inputText = ""
        elseif key == "backspace" then
            settingsUI.inputText = settingsUI.inputText:sub(1, -2)
        elseif key:match("%d") then
            settingsUI.inputText = settingsUI.inputText .. key
        elseif key == "escape" then
            settingsUI.selectedInput = nil
            settingsUI.inputText = ""
        end
        return
    end
    
    if key == "b" then
        gameState = "home"
    elseif key == "1" then
        settings.backgroundColor = {0.12, 0.12, 0.12}
        settings.backgroundColorName = "Gray"
    elseif key == "2" then
        settings.backgroundColor = {0.18, 0.22, 0.45}
        settings.backgroundColorName = "Blue"
    elseif key == "3" then
        settings.backgroundColor = {0.1, 0.25, 0.1}
        settings.backgroundColorName = "Green"
    elseif key == "+" or key == "kp+" then
        settings.bulletFallSpeed = math.min(settings.bulletFallSpeed + 5, 100)
    elseif key == "-" or key == "kp-" then
        settings.bulletFallSpeed = math.max(settings.bulletFallSpeed - 5, 10)
    elseif key == "d" then
        settings.difficulty = 1
    elseif key == "f" then
        settings.difficulty = 2
    elseif key == "g" then
        settings.difficulty = 3
    elseif key == "escape" then
        love.event.quit()
    end
end

function handleGameOverInput(key)
    if key == "r" then
        gameState = "playing"
        gameInit()
    elseif key == "h" then
        gameState = "home"
    elseif key == "escape" then
        love.event.quit()
    end
end



function inputMouse(x, y, button)
    if gameState == "settings" and button == 1 then
        handleSettingsMouseInput(x, y)
        return
    end

    if gameState ~= "playing" then return end
    if button == 1 and player.ammo > 0 then
        shootBullet()
    end

    if gameState == "levelcomplete" and button == 1 then
        handleLevelCompleteMouseInput(x, y)
    end
end

function handleSettingsMouseInput(x, y)
    local marginX = screenWidth * 0.15
    local marginY = screenHeight * 0.18
    local spacingY = screenHeight * 0.07
    local buttonW = screenWidth * 0.18
    local buttonH = screenHeight * 0.06

    -- Background color buttons
    local bgOptions = {{"Gray",{0.12,0.12,0.12}},{"Blue",{0.18,0.22,0.45}},{"Green",{0.1,0.25,0.1}}}
    for i, option in ipairs(bgOptions) do
        local bx = marginX + (i-1)*(buttonW + screenWidth*0.04)
        local by = marginY
        if x >= bx and x <= bx+buttonW and y >= by and y <= by+buttonH then
            settings.backgroundColor = option[2]
            settings.backgroundColorName = option[1]
            return
        end
    end
    -- Fall speed buttons
    local fsx = marginX
    local fsy = marginY + buttonH + spacingY
    local fsw = buttonH
    local fsh = buttonH
    if x >= fsx and x <= fsx+fsw and y >= fsy and y <= fsy+fsh then
        settings.bulletFallSpeed = math.max(settings.bulletFallSpeed - 5, 10)
        return
    end
    if x >= fsx+fsw+screenWidth*0.08 and x <= fsx+fsw+screenWidth*0.08+fsw and y >= fsy and y <= fsy+fsh then
        settings.bulletFallSpeed = math.min(settings.bulletFallSpeed + 5, 100)
        return
    end
    -- Difficulty buttons
    local difficulties = {{"Easy",1},{"Medium",2},{"Hard",3}}
    for i, diff in ipairs(difficulties) do
        local dx = marginX + (i-1)*(buttonW*0.7 + screenWidth*0.03)
        local dy = fsy + fsh + spacingY
        local dw = buttonW*0.7
        local dh = buttonH
        if x >= dx and x <= dx+dw and y >= dy and y <= dy+dh then
            settings.difficulty = diff[2]
            return
        end
    end

    -- Bean count input
    local bx = marginX
    local by = fsy + fsh + spacingY + buttonH + spacingY
    local bw = buttonW
    local bh = buttonH
    if x >= bx and x <= bx+bw and y >= by and y <= by+bh then
        settingsUI.selectedInput = "beans"
        settingsUI.inputText = ""
        return
    end
    -- Initial bullets input
    local ix = marginX
    local iy = by + bh + spacingY
    local iw = buttonW
    local ih = buttonH
    if x >= ix and x <= ix+iw and y >= iy and y <= iy+ih then
        settingsUI.selectedInput = "bullets"
        settingsUI.inputText = ""
        return
    end
    -- Default button
    local dx = screenWidth/2 - buttonW/2
    local dy = screenHeight - buttonH*2 - screenHeight*0.03
    local dw = buttonW
    local dh = buttonH
    if x >= dx and x <= dx+dw and y >= dy and y <= dy+dh then
        settings.backgroundColor = {0.12, 0.12, 0.12}
        settings.backgroundColorName = "Gray"
        settings.bulletFallSpeed = 40
        settings.difficulty = 1
        settings.BeansCount = 12
        settings.initialAmmo = 10
        return
    end
    -- Back button
    local backW = buttonW*0.7
    local backH = buttonH
    local backX = screenWidth*0.03
    local backY = screenHeight - backH - screenHeight*0.03
    if x >= backX and x <= backX+backW and y >= backY and y <= backY+backH then
        gameState = "home"
        return
    end
end

function shootBullet()
    player.isAffectedByGravity = true

    -- Apply recoil to player
    player.velocityX = player.velocityX + math.cos(player.rotation) * RECOIL_FORCE
    player.velocityY = player.velocityY + math.sin(player.rotation) * RECOIL_FORCE

    -- Create bullet
    local bulletOffset = 80
    local bulletX = player.x + math.cos(player.rotation) * bulletOffset
    local bulletY = player.y + math.sin(player.rotation) * bulletOffset
    table.insert(bullets, {
        x = bulletX, 
        y = bulletY, 
        rotation = player.rotation
    })

    player.ammo = player.ammo - 1

    -- Play gun sound
    love.audio.stop(gunSound)
    love.audio.play(gunSound)
    gunSoundTimer = 0.1
end



-- Initialize the game
gameInit()

-- Set up Love2D callbacks
love.update = gameUpdate
love.draw = gameDraw
love.keypressed = inputKey
love.mousepressed = inputMouse