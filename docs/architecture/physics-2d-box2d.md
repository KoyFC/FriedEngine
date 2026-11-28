# 2D physics with Box2D

`physics2d: box2d` gives a platform rigid bodies on Box2D 3.1, built from source by `cmake/Box2D.cmake` (downloaded once and checked against a SHA-256). The kinematic physics of [Collisions](collisions.md) stays the default and is what the DS and the fx-CG50 use. The two do not behave alike and are different components, so a game for both has two sets of objects, and the importer keeps the right one for each platform.

## Components

`RigidBody2D` has a `bodyType` (`Static`, `Kinematic`, `Dynamic`), `velocityX`, `velocityY`, `angularVelocity`, `gravityScale`, `fixedRotation` and `bullet`, `applyForce` and `applyImpulse`, and `contacts`. A shape is on the same object as its body or on a child: `BoxShape2D`, `CircleShape2D`, `CapsuleShape2D` (vertical) and `PolygonShape2D` (convex, at most 8 points). All have `offsetX`, `offsetY`, `density`, `friction`, `restitution`, `isSensor`, `collisionLayer` and `collisionMask`, with the meaning those have for a `Collider`. A shape without a body makes a static one. Each needs a `Transform2D`.

`Physics2D.raycast` and `Physics2D.overlapBox` query the world.

## Units and the step

Project units are pixels; Box2D works in meters and radians. `physics2d.pixelsPerMeter` (32 by default) and `physics2d.gravity` in pixels a second squared (`[0, 980]`) are in `project.fried`. In each fixed step the scene pushes the changes the game made to the bodies, steps the world in 4 substeps, collects the contact and sensor events and writes positions and rotation (degrees) back to the `Transform2D`. As with `KinematicBody`, a parent that is scaled or rotated is not accounted for.

## Native layer

`native/modules/box2d` is a plain C API over handles, in meters, with a fixed buffer for events. `box2d_stub.cpp` has the same functions and does nothing, for the platforms that do not use the module. Box2D is compiled with floating point contraction off, and without SIMD on the 3DS, Vita and web, so a step is repeatable.
