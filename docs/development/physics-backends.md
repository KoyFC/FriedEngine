# Physics backends

Box2D is built as an optional backend of the `physics2d` [module](../architecture/modules.md), see [2D physics with Box2D](../architecture/physics-2d-box2d.md). This page records what was considered, and what is still open. The kinematic physics is described in [Collisions](../architecture/collisions.md).

## What the engine has and what Box2D is

The engine's physics is kinematic: axis aligned boxes, a body that is moved and stopped one axis at a time, triggers, layers and masks, and queries (overlap and raycast). It keeps its boxes in integers so that a query does no arithmetic on a `Float`, which on the DS is a call into software floating point, and so that the answer is the same on every platform.

Box2D is a rigid body dynamics library: forces, restitution and friction, rotation, circles, polygons and capsules, joints, stacking and rolling. It does its whole solve in 32 bit floats. The two do different jobs, so Box2D would add what the engine does not do and would not replace what it does.

## What would fit

A node would stay the face of a body, with the library's world held by the scene the way the collider grid is, and the objects and the bodies synchronized in the fixed step, which already exists. Layers and masks map to Box2D's filter bits, a trigger to a sensor, and overlap and raycast queries exist in it. Box2D 3 is plain C under an MIT license with no dependencies, so it would be built like the other dependencies. Whether it compiles for the Vita, the Switch, the 3DS and the web build has to be checked, and so does the claim that version 3.1 gives the same result on every platform, which was not verified.

## Why it cannot be the only physics

Its cost has not been measured here, so what follows is an estimate. It would be fine on the PC and the Switch for hundreds of bodies, and probably on the Vita for tens or hundreds. The 3DS has a floating point unit and is the platform to measure. The DS is out: every float operation of the solver is a call into software, and a step with a few dozen bodies in contact would take tens of milliseconds, besides the memory. The fx-CG50 is out for its memory.

So a game that needs dynamic bodies would run on a different set of platforms from one that does not, and the engine would have two physics backends: the kinematic one, on every platform, and a Box2D one, on the platforms that can afford it. They would not behave alike, so they would not be hidden behind one API. A project would choose by the `platforms` it declares in `project.fried`, which already excludes the others: a game that uses Box2D does not list the DS or the fx-CG50.

## What was built

A project chooses the backend per platform in its build profile, and a platform that does not use Box2D links a stub. The components are the same on both, and the default backend emulates what it can of a dynamic body. The manifest allows Box2D on the PC, Vita, Switch, 3DS, web and Android. It compiles for the PC, the Switch and the 3DS (without SIMD), and the Vita, web and Android builds were not tried. Its cost on the 3DS and the Vita is still to be measured.

## Jolt

`physics3d` registers `jolt` as planned, for the PC, Switch, web and Android. Nothing of it exists: there is no 3D physics in the engine yet, and the Vita and the 3DS are left out until a world of the size a game needs is measured there.

## Before building it

Find out what the games need that the kinematic physics does not do. If it is dynamic bodies, rotation, circles or joints, measure a Box2D world of the size the game needs on the 3DS and the Vita first, and build the optional backend after that. If it is a platformer or a top-down game, the kinematic physics is cheaper and enough.
