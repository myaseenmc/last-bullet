function blopInit()
    love.window.setTitle("Blop Zorp")
    love.window.setMode(800, 600, {resizable=false})

    flib, flab = love.graphics.getDimensions()

    zorpPic = love.graphics.newImage("guns/husher.png")
    blipPic = love.graphics.newImage("bullet.png")

    love.graphics.setDefaultFilter("nearest", "nearest")
    zorpPic:setFilter("nearest", "nearest")
    blipPic:setFilter("nearest", "nearest")

    levelCompleted = false
    levelCompleteTimer = 0

    local beanCount = settings.beanCount
    if settings.difficulty == 2 then beanCount = math.max(3, math.floor(settings.beanCount * 0.6)) end
    if settings.difficulty == 3 then beanCount = math.max(1, math.floor(settings.beanCount * 0.25)) end

    zorp = {
        px = flib / 2,
        py = flab / 2,
        vx = 0,
        vy = 0,
        theta = 0,
        smoof = 0,
        ox = zorpPic:getWidth() / 4,
        oy = zorpPic:getHeight() / 2,
        scl = 4,
        beans = 1,
        grav = 900,
        splat = false,
        ammo = settings.initialBullets
    }

    splatters = {}
    blipSpeed = 600
    blipScl = 4

    beanlets = {}
    for i = 1, settings.beanCount do
        table.insert(beanlets, {
            px = math.random(50, flib - 50),
            py = math.random(50, flab - 50),
            got = false
        })
    end

    airBullets = {}
    airBulletTimer = 0

    gameOver = false

    gunSound = love.audio.newSource("gun.mp3", "static")
    gunSound:setLooping(false)
    gunSoundTimer = 0
end

local function flerp(a, b, t)
    return a + (b - a) * t
end

introScenes = {
    "welcome....\nBehind every success lies a story of sacrifice..",
    "Sacrifice your bullets to earn more."
}
introSceneIndex = 1
introTextProgress = 0
introTimer = 0
introSpeed = 0.04 
showIntro = true

function blopUpdate(dt)
    if showIntro then
        introTimer = introTimer + dt
        local currentText = introScenes[introSceneIndex]
        if introTextProgress < #currentText then
            if introTimer >= introSpeed then
                introTextProgress = introTextProgress + 1
                introTimer = 0
            end
        end
        return
    end

    if gameState == "home" or gameState == "settings" then return end
    if gameOver then return end

    local mx, my = love.mouse.getPosition()

    local ttheta = math.atan2(my - zorp.py, mx - zorp.px)

    if zorp.smoof and zorp.smoof > 0 then
        zorp.theta = flerp(zorp.theta, ttheta, 1 - zorp.smoof)
    else
        zorp.theta = ttheta
    end

    if zorp.splat then
        zorp.vy = zorp.vy + zorp.grav * dt
    end

    zorp.px = zorp.px + zorp.vx * dt
    zorp.py = zorp.py + zorp.vy * dt

    zorp.vx = zorp.vx * 0.98
    zorp.vy = zorp.vy * 0.98

    if zorp.px < 0 then zorp.px = 0; zorp.vx = 0 end
    if zorp.px > flib then zorp.px = flib; zorp.vx = 0 end
    if zorp.py > flab then
        gameOver = true
        gameState = "gameover"
    end
    if zorp.py < 0 then zorp.py = 0; zorp.vy = 0 end

    for i = #splatters, 1, -1 do
        local b = splatters[i]
        b.px = b.px + math.cos(b.theta) * blipSpeed * dt
        b.py = b.py + math.sin(b.theta) * blipSpeed * dt

        if b.px < -50 or b.px > flib + 50 or b.py < -50 or b.py > flab + 50 then
            table.remove(splatters, i)
        end
    end

    for _, p in ipairs(beanlets) do
        if not p.got then
            local dx, dy = zorp.px - p.px, zorp.py - p.py
            local zorpW = zorpPic:getWidth() * zorp.scl
            local zorpH = zorpPic:getHeight() * zorp.scl
            local beanW = blipPic:getWidth() * blipScl
            local beanH = blipPic:getHeight() * blipScl
            if math.abs(zorp.px - p.px) < (zorpW/2 + beanW/2) and math.abs(zorp.py - p.py) < (zorpH/2 + beanH/2) then
                p.got = true
                zorp.beans = zorp.beans + 1
                zorp.ammo = zorp.ammo + 5
            end
        end
    end

    airBulletTimer = airBulletTimer + dt
    if airBulletTimer >= 10 then
        dropAirBullet()
        airBulletTimer = 0
    end

    for i = #airBullets, 1, -1 do
        local b = airBullets[i]
        b.py = b.py + b.vy * dt
        if b.py > flab + 20 then
            table.remove(airBullets, i)
        else
            local dx = zorp.px - b.px
            local dy = zorp.py - b.py
            if dx*dx + dy*dy < (32*32) then
                zorp.ammo = zorp.ammo + 1
                table.remove(airBullets, i)
            end
        end
    end

    if zorp.beans > highscore then
        highscore = zorp.beans
    end

    if gunSound:isPlaying() then
        gunSoundTimer = gunSoundTimer - dt
        if gunSoundTimer <= 0 then
            love.audio.stop(gunSound)
            gunSoundTimer = 0
        end
    end

    if gameState == "playing" and not levelCompleted then
        local collected = 0
        for _, p in ipairs(beanlets) do
            if p.got then
                collected = collected + 1
            end
        end
        local requiredBeans = 2 + (level - 1) * 2
        if collected >= requiredBeans then
            levelCompleted = true
            gameState = "levelcomplete"
            zorp.vx = 0
            zorp.vy = 0
        end
    end

    if levelCompleted then
        levelCompleteTimer = levelCompleteTimer + dt
        if levelCompleteTimer > 2 then
            level = level + 1
            startLevel(level)
            gameState = "playing"
        end
        return
    end
end

function blopDraw()
    if showIntro then
        love.graphics.clear(settings.bgcolor)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(math.floor(flab * 0.045)))
        local currentText = introScenes[introSceneIndex]
        local displayText = currentText:sub(1, introTextProgress)
        love.graphics.printf(displayText, flib*0.1, flab*0.35, flib*0.8, "center")
        love.graphics.setFont(love.graphics.newFont(math.floor(flab * 0.025)))
        if introTextProgress >= #currentText then
            love.graphics.setColor(0.7,0.7,1)
            love.graphics.printf("Press SPACE to continue...", 0, flab*0.8, flib, "center")
        end
        return
    end

    if gameState == "home" then
        love.graphics.clear(settings.bgcolor)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("Blop Zorp", 0, 120, flib, "center")
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf("Press N for New Game", 0, 220, flib, "center")
        love.graphics.printf("Press S for Settings", 0, 260, flib, "center")
        return
    end

    if gameState == "settings" then
        love.graphics.clear(settings.bgcolor)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.05) ))
        love.graphics.printf("Settings", 0, flab * 0.08, flib, "center")
        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.03) ))

        local marginX = flib * 0.15
        local marginY = flab * 0.18
        local spacingY = flab * 0.07
        local buttonW = flib * 0.18
        local buttonH = flab * 0.06

        local bgNames = {{"Gray", {0.12,0.12,0.12}}, {"Blue", {0.18,0.22,0.45}}, {"Green", {0.1,0.25,0.1}}}
        for i, bg in ipairs(bgNames) do
            local bx = marginX + (i-1)*(buttonW + flib*0.04)
            local by = marginY
            love.graphics.setColor(settings.bgcolorName == bg[1] and {0.7,0.7,1} or {0.3,0.3,0.3})
            love.graphics.rectangle("fill", bx, by, buttonW, buttonH)
            love.graphics.setColor(1,1,1)
            love.graphics.printf(bg[1], bx, by+buttonH*0.25, buttonW, "center")
        end
        love.graphics.setColor(1,1,1)
        love.graphics.print("BG Color: " .. settings.bgcolorName, marginX, marginY + buttonH + flab*0.01)

        local fsx = marginX
        local fsy = marginY + buttonH + spacingY
        local fsw = buttonH
        local fsh = buttonH
        love.graphics.setColor({0.3,0.3,0.3})
        love.graphics.rectangle("fill", fsx, fsy, fsw, fsh)
        love.graphics.rectangle("fill", fsx+fsw+flib*0.08, fsy, fsw, fsh)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("-", fsx, fsy+fsh*0.25, fsw, "center")
        love.graphics.printf("+", fsx+fsw+flib*0.08, fsy+fsh*0.25, fsw, "center")
        love.graphics.print("Fall Speed: " .. tostring(settings.fallspeed), fsx+fsw+flib*0.15, fsy+fsh*0.25)

        local diffs = {{"Easy",1},{"Medium",2},{"Hard",3}}
        for i, d in ipairs(diffs) do
            local dx = marginX + (i-1)*(buttonW*0.7 + flib*0.03)
            local dy = fsy + fsh + spacingY
            local dw = buttonW*0.7
            local dh = buttonH
            love.graphics.setColor(settings.difficulty == d[2] and {0.7,0.7,1} or {0.3,0.3,0.3})
            love.graphics.rectangle("fill", dx, dy, dw, dh)
            love.graphics.setColor(1,1,1)
            love.graphics.printf(d[1], dx, dy+dh*0.25, dw, "center")
        end
        love.graphics.setColor(1,1,1)
        local diffName = diffs[settings.difficulty][1]
        love.graphics.print("Difficulty: " .. diffName, marginX, fsy + fsh + spacingY + buttonH + flab*0.01)

        local bx = marginX
        local by = fsy + fsh + spacingY + buttonH + spacingY
        local bw = buttonW
        local bh = buttonH
        love.graphics.setColor(settingsUI.selectedInput == "beans" and {0.7,0.7,1} or {0.3,0.3,0.3})
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(1,1,1)
        local beanText = settingsUI.selectedInput == "beans" and settingsUI.inputText or tostring(settings.beanCount)
        love.graphics.printf(beanText, bx, by+bh*0.25, bw, "center")
        love.graphics.print("Bean Count", bx+bw+flib*0.03, by+bh*0.25)

        local ix = marginX
        local iy = by + bh + spacingY
        local iw = buttonW
        local ih = buttonH
        love.graphics.setColor(settingsUI.selectedInput == "bullets" and {0.7,0.7,1} or {0.3,0.3,0.3})
        love.graphics.rectangle("fill", ix, iy, iw, ih)
        love.graphics.setColor(1,1,1)
        local bulletText = settingsUI.selectedInput == "bullets" and settingsUI.inputText or tostring(settings.initialBullets)
        love.graphics.printf(bulletText, ix, iy+ih*0.25, iw, "center")
        love.graphics.print("Initial Bullets", ix+iw+flib*0.03, iy+ih*0.25)

        local dx = flib/2 - buttonW/2
        local dy = flab - buttonH*2 - flab*0.03
        local dw = buttonW
        local dh = buttonH
        love.graphics.setColor({0.5,0.5,0.8})
        love.graphics.rectangle("fill", dx, dy, dw, dh)
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.035) ))
        love.graphics.printf("Default", dx, dy+dh*0.25, dw, "center")

        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.025) ))
        local backW = buttonW*0.7
        local backH = buttonH
        local backX = flib*0.03
        local backY = flab - backH - flab*0.03
        love.graphics.setColor({0.5,0.5,0.5})
        love.graphics.rectangle("fill", backX, backY, backW, backH)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Back", backX, backY+backH*0.25, backW, "center")

        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.022) ))
        love.graphics.setColor(1,1,1)
        local summaryX = flib - marginX - buttonW
        local summaryY = marginY + flab * 0.10
        love.graphics.print("Current Settings:", summaryX, summaryY)
        love.graphics.print("BG Color: " .. settings.bgcolorName, summaryX, summaryY + spacingY*0.7)
        love.graphics.print("Fall Speed: " .. tostring(settings.fallspeed), summaryX, summaryY + spacingY*1.4)
        love.graphics.print("Difficulty: " .. diffName, summaryX, summaryY + spacingY*2.1)
        love.graphics.print("Bean Count: " .. tostring(settings.beanCount), summaryX, summaryY + spacingY*2.8)
        love.graphics.print("Initial Bullets: " .. tostring(settings.initialBullets), summaryX, summaryY + spacingY*3.5)
        return
    end

    love.graphics.clear(settings.bgcolor)

    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.setLineWidth(1)
    love.graphics.line(mx - 10, my, mx + 10, my)
    love.graphics.line(mx, my - 10, mx, my + 10)
    love.graphics.circle("line", mx, my, 12)

    for _, p in ipairs(beanlets) do
        if not p.got then
            love.graphics.setColor(1, 1, 0)
            love.graphics.draw(
                blipPic,
                p.px, p.py,
                0,
                blipScl, blipScl,
                blipPic:getWidth()/2, blipPic:getHeight()/2
            )
        end
    end

    love.graphics.setColor(1,1,1)
    love.graphics.draw(
        zorpPic,
        zorp.px, zorp.py,
        zorp.theta,
        zorp.scl, zorp.scl,
        zorp.ox, zorp.oy
    )

    for _, b in ipairs(splatters) do
        love.graphics.draw(
            blipPic,
            b.px, b.py,
            b.theta,
            blipScl, blipScl,
            blipPic:getWidth()/2, blipPic:getHeight()/2
        )
    end

    for _, b in ipairs(airBullets) do
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.draw(
            blipPic,
            b.px, b.py,
            0,
            blipScl, blipScl,
            blipPic:getWidth()/2, blipPic:getHeight()/2
        )
    end

    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.03) ))
    love.graphics.printf("Highscore: " .. tostring(highscore), 0, 8, flib, "center")

    love.graphics.print("Zorp click splat. Beans: " .. tostring(zorp.beans) .. "  Ammo: " .. tostring(zorp.ammo), 8, 8)

    love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.025) ))
    love.graphics.setColor(1,1,1)
    love.graphics.print("Level: " .. tostring(level), 8, 40)

    if gameState == "gameover" or gameOver then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, flib, flab)
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(love.graphics.newFont(32))
        love.graphics.printf("Game Over", 0, flab/2 - 40, flib, "center")
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf("Press R to Restart", 0, flab/2 + 10, flib, "center")
        love.graphics.printf("Press H for Home", 0, flab/2 + 40, flib, "center")
    end

    if gameState == "levelcomplete" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, flib, flab)
        love.graphics.setColor(0, 1, 0)
        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.06) ))
        love.graphics.printf("Level " .. tostring(level) .. " Completed!", 0, flab/2 - 80, flib, "center")
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(love.graphics.newFont( math.floor(flab * 0.03) ))
        local btnW = flib * 0.28
        local btnH = flab * 0.09
        local btnX = (flib - btnW) / 2
        local btnY = flab/2 + 10
        love.graphics.setColor(0.2, 0.7, 0.2)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 12, 12)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Play Level " .. tostring(level + 1), btnX, btnY + btnH/3, btnW, "center")
        return
    end
end

function blopKey(key)
    if showIntro then
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
        return
    end

    if gameState == "home" then
        if key == "n" then
            level = 1
            startLevel(level)
        elseif key == "s" then
            gameState = "settings"
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    if gameState == "settings" then
        if settingsUI.selectedInput then
            if key == "return" or key == "kpenter" then
                local val = tonumber(settingsUI.inputText)
                if settingsUI.selectedInput == "beans" and val and val > 0 then
                    settings.beanCount = math.floor(val)
                elseif settingsUI.selectedInput == "bullets" and val and val >= 0 then
                    settings.initialBullets = math.floor(val)
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
            settings.bgcolor = {0.12, 0.12, 0.12}
            settings.bgcolorName = "Gray"
        elseif key == "2" then
            settings.bgcolor = {0.18, 0.22, 0.45}
            settings.bgcolorName = "Blue"
        elseif key == "3" then
            settings.bgcolor = {0.1, 0.25, 0.1}
            settings.bgcolorName = "Green"
        elseif key == "+" or key == "kp+" then
            settings.fallspeed = math.min(settings.fallspeed + 5, 100)
        elseif key == "-" or key == "kp-" then
            settings.fallspeed = math.max(settings.fallspeed - 5, 10)
        elseif key == "d" then
            settings.difficulty = 1
        elseif key == "f" then
            settings.difficulty = 2
        elseif key == "g" then
            settings.difficulty = 3
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    if gameState == "gameover" or gameOver then
        if key == "r" then
            gameState = "playing"
            blopInit()
        elseif key == "h" then
            gameState = "home"
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    if gameState == "levelcomplete" then
        if key == "space" or key == "return" or key == "kpenter" then
            level = level + 1
            startLevel(level)
        elseif key == "escape" then
            love.event.quit()
        end
        return
    end

    if key == "escape" then
        love.event.quit()
    end
end

function blopMouse(x, y, button)
    if gameState == "settings" and button == 1 then
        local marginX = flib * 0.15
        local marginY = flab * 0.18
        local spacingY = flab * 0.07
        local buttonW = flib * 0.18
        local buttonH = flab * 0.06

        local bgNames = {{"Gray",{0.12,0.12,0.12}},{"Blue",{0.18,0.22,0.45}},{"Green",{0.1,0.25,0.1}}}
        for i, bg in ipairs(bgNames) do
            local bx = marginX + (i-1)*(buttonW + flib*0.04)
            local by = marginY
            if x >= bx and x <= bx+buttonW and y >= by and y <= by+buttonH then
                settings.bgcolor = bg[2]
                settings.bgcolorName = bg[1]
                return
            end
        end
        local fsx = marginX
        local fsy = marginY + buttonH + spacingY
        local fsw = buttonH
        local fsh = buttonH
        if x >= fsx and x <= fsx+fsw and y >= fsy and y <= fsy+fsh then
            settings.fallspeed = math.max(settings.fallspeed - 5, 10)
            return
        end
        if x >= fsx+fsw+flib*0.08 and x <= fsx+fsw+flib*0.08+fsw and y >= fsy and y <= fsy+fsh then
            settings.fallspeed = math.min(settings.fallspeed + 5, 100)
            return
        end
        local diffs = {{"Easy",1},{"Medium",2},{"Hard",3}}
        for i, d in ipairs(diffs) do
            local dx = marginX + (i-1)*(buttonW*0.7 + flib*0.03)
            local dy = fsy + fsh + spacingY
            local dw = buttonW*0.7
            local dh = buttonH
            if x >= dx and x <= dx+dw and y >= dy and y <= dy+dh then
                settings.difficulty = d[2]
                return
            end
        end
        local bx = marginX
        local by = fsy + fsh + spacingY + buttonH + spacingY
        local bw = buttonW
        local bh = buttonH
        if x >= bx and x <= bx+bw and y >= by and y <= by+bh then
            settingsUI.selectedInput = "beans"
            settingsUI.inputText = ""
            return
        end
        local ix = marginX
        local iy = by + bh + spacingY
        local iw = buttonW
        local ih = buttonH
        if x >= ix and x <= ix+iw and y >= iy and y <= iy+ih then
            settingsUI.selectedInput = "bullets"
            settingsUI.inputText = ""
            return
        end
        local dx = flib/2 - buttonW/2
        local dy = flab - buttonH*2 - flab*0.03
        local dw = buttonW
        local dh = buttonH
        if x >= dx and x <= dx+dw and y >= dy and y <= dy+dh then
            settings.bgcolor = {0.12, 0.12, 0.12}
            settings.bgcolorName = "Gray"
            settings.fallspeed = 40
            settings.difficulty = 1
            settings.beanCount = 12
            settings.initialBullets = 10
            return
        end
        local backW = buttonW*0.7
        local backH = buttonH
        local backX = flib*0.03
        local backY = flab - backH - flab*0.03
        if x >= backX and x <= backX+backW and y >= backY and y <= backY+backH then
            gameState = "home"
            return
        end
    end

    if gameState ~= "playing" then return end
    if button == 1 and zorp.ammo > 0 then
        zorp.splat = true

        local splatForce = -600
        zorp.vx = zorp.vx + math.cos(zorp.theta) * splatForce
        zorp.vy = zorp.vy + math.sin(zorp.theta) * splatForce

        local offset = 80
        local bx = zorp.px + math.cos(zorp.theta) * offset
        local by = zorp.py + math.sin(zorp.theta) * offset
        table.insert(splatters, {px = bx, py = by, theta = zorp.theta})

        zorp.ammo = zorp.ammo - 1

        love.audio.stop(gunSound)
        love.audio.play(gunSound)
        gunSoundTimer = 0.1
    end

    if gameState == "levelcomplete" and button == 1 then
        local btnW = flib * 0.28
        local btnH = flab * 0.09
        local btnX = (flib - btnW) / 2
        local btnY = flab/2 + 10
        if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
            level = level + 1
            startLevel(level)
            return
        end
    end
end

function dropAirBullet()
    local x = math.random(50, flib - 50)
    local y = -20
    table.insert(airBullets, {px = x, py = y, vy = settings.fallspeed})
end

gameState = "home"

settings = {
    bgcolor = {0.12, 0.12, 0.12},
    bgcolorName = "Gray",
    fallspeed = 40,
    difficulty = 1,
    beanCount = 12,
    initialBullets = 10,
}

settingsUI = {
    selectedInput = nil,
    inputText = "",
}

highscore = 0

level = 1

function startLevel(lvl)
    local beanCount = math.max(6, 2 + (lvl - 1) * 2)
    settings.beanCount = beanCount
    if settings.difficulty == 2 then beanCount = math.max(3, math.floor(settings.beanCount * 0.6)) end
    if settings.difficulty == 3 then beanCount = math.max(1, math.floor(settings.beanCount * 0.25)) end
    settings.beanCount = beanCount
    blopInit()
    gameState = "playing"
end

blopInit()

love.update = blopUpdate
love.draw = blopDraw
love.keypressed = blopKey
love.mousepressed = blopMouse
-- Settings
settings = {
    bgcolor = {0.12, 0.12, 0.12},
    bgcolorName = "Gray",
    fallspeed = 40,
    difficulty = 1,
    beanCount = 12,
    initialBullets = 10,
}

settingsUI = {
    selectedInput = nil, -- "beans" or "bullets"
    inputText = "",
}

highscore = 0 -- Add highscore variable

level = 1

function startLevel(lvl)
    local beanCount = math.max(6, 2 + (lvl - 1) * 2) -- Always spawn at least 6 beans for variety
    settings.beanCount = beanCount
    -- Difficulty scaling
    if settings.difficulty == 2 then beanCount = math.max(3, math.floor(settings.beanCount * 0.6)) end
    if settings.difficulty == 3 then beanCount = math.max(1, math.floor(settings.beanCount * 0.25)) end
    settings.beanCount = beanCount
    blopInit()
    gameState = "playing"
end

blopInit()

love.update = blopUpdate
love.draw = blopDraw
love.keypressed = blopKey
love.mousepressed = blopMouse

