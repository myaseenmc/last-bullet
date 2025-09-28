function updatePlayer(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    local targetRotation = math.atan2(mouseY - player.y, mouseX - player.x)

    if player.smoothing and player.smoothing > 0 then
        player.rotation = lerp(player.rotation, targetRotation, 1 - player.smoothing)
    else
        player.rotation = targetRotation
    end

  
    if player.isAffectedByGravity then
        player.velocityY = player.velocityY + GRAVITY * dt
    end

   
    player.x = player.x + player.velocityX * dt
    player.y = player.y + player.velocityY * dt

    player.velocityX = player.velocityX * 0.98
    player.velocityY = player.velocityY * 0.98


    if player.x < 0 then 
        player.x = 0
        player.velocityX = 0 
    end
    if player.x > screenWidth then 
        player.x = screenWidth
        player.velocityX = 0 
    end
    if player.y > screenHeight and gameOver ~= true then
        gameOver = true
        gameState = "gameover"
    end
    if player.y < 0 then 
        player.y = 0
        player.velocityY = 0 
    end
    if settings.wallBounceEnabled then
        checkWallBounces()
    end
end
