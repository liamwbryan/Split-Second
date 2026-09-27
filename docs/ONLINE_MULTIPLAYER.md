# Online multiplayer: what it would mean

Status: **being considered, not started.** Liam wants to play with friends online. This note explains what it would take so the decision is informed.

## The core problem
Split-screen is easy because everyone shares one simulation. Online, each player's machine is 30–150 ms away from the others, and a fast movement shooter feels broken unless that delay is hidden:

- **Your own movement must feel instant.** That requires *client-side prediction*: your machine simulates your moves immediately, and the host confirms or corrects them. Corrections that aren't smoothed out show up as rubber-banding.
- **Other players have to look smooth.** That requires *interpolation*: you see them roughly 100 ms in the past, blended between network updates.
- **Hits have to feel fair.** That requires *lag compensation*: when you shoot, the host rewinds everyone to where *you* saw them. Otherwise you'd hit players that had already moved.

## Why this project is in good shape for it
- Movement runs at a **fixed 120 Hz tick driven only by inputs** (`InputRouter` → `PlayerMotor`). That's exactly what prediction needs: send inputs, replay them.
- **Moving geometry is a pure function of time** (`Mover.sample(t)`). Every machine computes identical crane and lift positions from a shared clock, with no need to sync each platform.
- Players are **never singletons** (from the split-screen design), so remote players slot in like extra local players whose input comes from the network.

## What it would add
| Piece | Work |
|---|---|
| Lobby, host/join, invites | Steam (GodotSteam) is easiest for "play with friends": relay servers handle NAT, with no port forwarding needed. Without Steam, it's direct IP or a small relay server. |
| Prediction + reconciliation for the motor | Medium-large. The motor must replay stored inputs deterministically, and random numbers must be seeded per tick. |
| Remote player interpolation + avatar animation | Medium (the avatar already animates from motor state). |
| Networked shooting, damage, respawns, scoring | Medium. The host is authoritative and applies lag compensation to hitscan. |
| Grapple, jump pads, mode rules | Small–medium each. |
| Testing | Ongoing. You'd need 2+ machines or a simulated-latency harness (Godot can add fake lag). |

A rough size is comparable to M2 + M3 combined. The main added cost is that every new feature afterward needs a "how does this sync?" answer, so later features take longer.

## Recommendation
1. **Now (cheap):** keep the simulation deterministic and input-driven. That means no gameplay randomness without a seeded RNG, all state changes go through the motor and weapon, and presentation stays separate from simulation. This is already mostly true; I'll keep it that way.
2. **After the core loop is fun** (guns, split-screen FFA, AI): build a **2-player online prototype** (direct connect, host-authoritative, prediction for movement only). That shows early how it feels.
3. **If it feels good:** Steam integration for friend invites, then online versions of the modes.

Consider the netfox addon for Godot (open source: prediction, rollback, lag compensation) to avoid writing the netcode core from scratch. Evaluate it at the prototype step.
