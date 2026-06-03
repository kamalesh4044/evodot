# Velocity.io (Godot Edition) - Game Design Document

This document serves as the master blueprint for the new Godot 4.x Multiplayer FPS. Pass this document to your AI assistant in any new chat to immediately restore all context and continue building!

## 1. Core Architecture
- **Engine:** Godot 4.x (v4.6.2+)
- **Language:** GDScript
- **Multiplayer System:** Godot High-Level Multiplayer (`ENetMultiplayerPeer`)
- **Hosting:** Headless Linux Export hosted on Render.com
- **Version Control:** Git / GitHub

## 2. Advanced Movement Mechanics (Skillwarz Style)
The game relies on smooth, momentum-based movement rather than instant snapping.
- **Velocity Accumulation:** Player movement is driven by acceleration and ground friction, creating a heavy, tactical feel.
- **Air Strafing & B-Hopping:** Jumping out of a sprint/slide preserves momentum. Players have `1.25x` air control to curve their jumps.
- **Sliding:** Sprinting and crouching triggers a slide that applies an immediate `1.35x` speed boost that gradually decays. Includes a cooldown to prevent spamming.

## 3. Tactical Shooting Mechanics
Run-and-gun is penalized; tactical positioning is rewarded.
- **Dynamic Spread:** Bullet spread increases based on movement speed (`movePenalty`) and being airborne (`airPenalty`). Crouching or Aiming Down Sights (ADS) reduces spread.
- **Procedural Recoil:** Firing weapons kicks the camera with a randomized pitch (up) and yaw (side-to-side). The camera lerps back to the original position during recovery.
- **Pellet Mechanics:** Shotguns fire multiple pellets in a single shot, all influenced by the dynamic spread multiplier.

## 4. Multiplayer Character Aesthetics
- **Model:** `city_soldier_outdated.glb` (Fully textured).
- **Procedural Animation (No Mixamo required):** 
  - **Dynamic Lean:** The character's core mesh rotates/leans forward (`~0.15` radians) based on movement speed.
  - **Footstep Bobbing:** The mesh bobs up and down on a sine wave that scales with velocity.
  - **Aim Tracking:** The weapon is attached to a shoulder pivot that syncs directly with the player's camera pitch across the network.

## 5. Next Steps for New Chat
1. Create a new Godot project in `c:\Users\kamal\OneDrive\Desktop\code\godot-fps`.
2. Initialize a Git repository.
3. Set up the `CharacterBody3D` node and translate the Javascript movement physics into `Player.gd`.
