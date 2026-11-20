# DS 3D measurements

What was measured about the DS's 3D frame, how, and what was decided from it, so that an option that was rejected can be taken up again when the numbers it rested on change. The mesh path itself is described in the [DS page](../platforms/nds.md).

## How it was measured

Everything ran in melonDS as an interpreter, with its own SD image and configuration, comparing variants of the same ROM and scene against each other. melonDS is deterministic, so one ROM run twice gives the same figures, and a difference between two variants is real. Absolute times are not a DS's: the emulator does not model the ARM9's data cache, so a loop that streams through main RAM costs several times more there than on the hardware, while the geometry engine's cost follows the real cycle counts. A conclusion that depends on the CPU against the GPU has to be confirmed on a DS.

The per-frame phases come from timers in `Application.run` (update, draw, flush and the whole), with a `swiWaitForVBlank()` right after `glFlush`, because the engine's FIFO stalls after the flush until the next vblank and a wait placed earlier in the frame hides the real work. Inside the renderer, ticks of the system clock (1.9 us) timed the preparation of each mesh and its polygon loop, and the status register told how full the command FIFO was as each mesh began and ended. The hardware's polygon and vertex counters (`GFX_POLYGON_RAM_USAGE` and `GFX_VERTEX_RAM_USAGE`) have to be read before the buffers swap, since the swap starts them again from zero. All of that was temporary, and so is the harness, which lives outside the repository.

Two scenes. WhiteCellSimulator's `game3d` on the DS, which is the floor in 6 blocks, 9 boxes, the player, enemies and projectiles, about 21 instances and 900 polygons a frame. The game is chaotic, and any change in cycle counts changes where enemies appear, so the game's time step was fixed at 1/60 and several runs of each variant were taken. And a stress scene of spheres of a chosen number of triangles in a grid, to separate what an instance costs from what a polygon costs.

## What the frame was made of

| | Before |
|---|---|
| `game3d`, work per frame | 11.4 ms (flush 4.4 ms, of which the polygon loop 3.0 ms and mesh preparation 0.85 ms) |
| 40 spheres of 300 triangles | 35.2 ms, of which the polygon loop 32.6 ms |

- An instance cost about 57 us whatever its size, and a polygon about 2.7 us. An instance was worth about 20 polygons.
- The 57 us were the Haxe side (`MeshPass.place`, `copyForRenderer`, `submitMesh`) 13.5 us, the conversions of the placement to fixed point 25 us, the matrix commands about 10 us and the queue's dispatch about 9 us.
- The command FIFO was empty every time a mesh began, and drained when the frame ended. In the emulator the CPU was the limit and the geometry engine waited for it.
- `game3d` stays far from the engine's limits: at most 629 of 2048 polygons and 2376 of 6144 vertices a frame, the HUD included. Forty spheres of 300 triangles send 12000 polygons, the hardware keeps 2041 and 6143, and the CPU still pays for all of them, so the limit is the first problem only for scenes of that size.

## What was decided

| Option | Measured | Decision |
|---|---|---|
| Display lists | The polygon loop cost the CPU about 2.2 us of the 2.7 us a polygon, and the writes to the engine only 0.5 us | Done. Meshes are packed once into command words and sent by DMA |
| Culling an instance by `BOX_TEST` | Costs 103 geometry cycles and its result is read from a status bit that clears only once the engine has run everything queued before it, so it makes the CPU wait for the GPU once for every instance, and it needs the instance's matrices set first, which is most of what an instance costs | Not worth it, with any numbers |
| Culling an instance on the CPU, with a sphere test in integers | 0.7% of `game3d`'s instances were outside the view. In a scene where 25% were, skipping them saved 29% of the frame | Not done. Worth it where a level is larger than the view. The test must be native: in Haxe it cost 45 us an instance, as much as the instance |
| Fusing static meshes into one | 15 of `game3d`'s 21 instances never move, so fusing them saves about 14 x 50 us, 0.7 ms, 7% of the frame after display lists | Not done. A game decision, the next one to take when the instance cost is the largest part of the frame |

## After the display lists

| Scene | Work per frame before | After |
|---|---|---|
| `game3d` (flush) | 11.4 ms (4.4 ms) | 9.6 ms (2.7 ms) |
| 40 spheres of 300 triangles | 35.2 ms | 10.0 ms |
| 2 spheres of 900 triangles | 5.3 ms | 1.8 ms |
| 6 spheres of 300 triangles | 5.6 ms | 2.0 ms |
| 18 spheres of 100 triangles | 6.2 ms | 2.5 ms |
| 60 spheres of 30 triangles | 8.6 ms | 4.6 ms |

The same polygon and vertex counts reach the hardware, and the picture is the same, pixel for pixel, as the one the CPU loop drew. Now an instance costs about 50 us and a polygon about 0.9 us, the rate at which the geometry engine takes them: an instance is worth about 55 polygons, so the cost of a frame of small meshes is mostly in the instances, 40% of the flush in `game3d`. That is where the next saving is: fusing the meshes that do not move, and keeping the placement of an instance that does not move converted, since the conversions are the largest part of what an instance costs.

The size of the lists is about that of the polygons they replace, 32 bytes a triangle, but a quad takes 44 and a color change 16 more: for `game3d`'s meshes, 16.4 KB against 11.5 KB.

## What is not known

- Whether a DS spends its time as the emulator does. If the CPU writes the polygons faster than the engine takes them there, the FIFO fills and the CPU waits, and the saving of display lists is smaller than the figures above, which are an upper bound. Running the same scene with a ROM from before and one from after, on a DS, and comparing the `work` each prints, shows it.
- Meshes with an alpha below 255, and a mesh drawn under two different ambient lights in a frame, take paths the measurements did not exercise.
