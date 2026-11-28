# 2D physics with Box2D

2D physics has one set of components, `Body2D` and `Collider2D`, and a project chooses what runs them for each platform with the `physics2d` [module](modules.md): `kinematic`, the default, which every platform has, or `box2d`, Box2D 3.1 built from source by `cmake/Box2D.cmake` (downloaded once and checked against a SHA-256) for the platforms that can afford it. A scene does not change with the choice, so the same scene runs on the DS and on a computer.

## Components

`Collider2D` is the box described in [Collisions](collisions.md), with a `shape` inside it: `Box`, `Circle`, `Capsule` or `Polygon`. The box is always the collider's size and its top left corner is its object's position; a circle is as wide as the shorter side of the box, a capsule is upright, and a polygon is convex, up to eight points, written as pairs of pixels from the box's corner (`"0,16 16,16 8,0"`). Without a `Body2D` a collider is a static solid.

`Body2D` has a `bodyType` and a velocity in pixels a second:

| `bodyType` | What it does |
|---|---|
| `Static` | Does not move, whatever its velocity. |
| `Kinematic` (default) | Moves by its velocity and is stopped by the solids it meets, sliding along them. Gravity does not pull it and it does not turn. |
| `Dynamic` | Gravity pulls it, and it is stopped by what it meets. |

`gravityScale`, `applyForce` and `applyImpulse` work on both backends. A body takes the collider on its object or its first child on the default backend, and every collider under it on Box2D.

## What changes with the backend

| | `kinematic` | `box2d` |
|---|---|---|
| Shapes | Every shape is its box | Box, circle, capsule and polygon |
| `Dynamic` | Gravity and sliding contact, no rotation, bounce or friction | Rigid bodies: rotation, restitution, friction, stacking |
| `isBlockedX`, `isBlockedY` | Set by the last step | Not set |
| `contacts` | What stopped the body, then the triggers it overlaps | What touches its colliders, triggers included |
| Rotation | The object is never turned | The object turns with the body |

`density`, `friction`, `restitution`, `angularVelocity`, `fixedRotation`, `bullet`, `shape` and `points` are only used by Box2D. They are listed in `unsupportedFields` of the backend in `modules.json`, and the editor shows them greyed on the platforms that do not use them, so a value set once is kept when the platform changes.

A kinematic body is made a dynamic one in Box2D that gravity does not pull and that does not turn, since a Box2D kinematic body would go through static colliders, which a character does not.

## Units and the step

Project units are pixels; Box2D works in meters and radians. `physics2d.pixelsPerMeter` (32 by default) and `physics2d.gravity` in pixels a second squared (`[0, 980]`) are in `project.fried`, and the default backend uses the same gravity. In each fixed step the scene gives the world what the game changed, steps it in 4 substeps, collects the contacts and writes positions and rotation (degrees) back to the `Transform2D`. As on the default backend, a parent that is scaled or rotated is not accounted for.

## Native layer

`native/modules/box2d` is a plain C API over handles, in meters, with a fixed buffer for events. `box2d_stub.cpp` has the same functions and does nothing, for the platforms that do not use the module, so a build links the real part only where the project asks for it. Box2D is compiled with floating point contraction off, and without SIMD on the 3DS, Vita and web, so a step is repeatable.

`Physics2D.raycast`, `overlapPoint`, `overlapBox` and `overlapBoxAll` ask whichever world the scene has. A ray that starts inside a collider does not report it on Box2D.
