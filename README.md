# The Last Bullet

A small arcade-style survival game built with **Lua** and **LÖVE2D**.

In *The Last Bullet*, every bullet matters.  
Shoot to move, collect bullets to survive, and sacrifice ammo to gain momentum and score.

---

## 🎮 Gameplay

The game combines:

- Physics-based recoil movement
- Bullet collection mechanics
- Ammo management
- Progressive difficulty levels
- Retro arcade-style gameplay

You control a floating gun that moves through recoil force whenever you shoot.

Your objective is simple:

> Collect bullets, survive longer, and complete levels without running out of ammo or falling off the screen.

---

## ✨ Features

- Smooth recoil-based movement
- Dynamic level progression
- Adjustable difficulty settings
- Falling ammo pickups
- Multiple background themes
- Sound effects and intro scenes
- Mouse aiming and shooting
- High score tracking
- Lightweight Love2D game architecture

---

## 📁 Project Structure

```text
last-bullet/
│
├── guns/                # Gun sprites
├── bullet.png           # Bullet sprite
├── sprite.png           # Additional sprite asset
│
├── main.lua             # Main game loop and UI
├── player.lua           # Player movement and physics
├── level.lua            # Level progression system
├── utils.lua            # Utility/helper functions
├── conf.lua             # Love2D configuration
│
├── gun.mp3              # Shooting sound
├── yay.mp3              # Level complete sound
├── gameover.mp3         # Game over sound
├── typewriter.wav       # Intro typing sound
│
└── bullet.love          # Packaged game build
