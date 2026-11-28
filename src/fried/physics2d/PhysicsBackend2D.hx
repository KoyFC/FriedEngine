package fried.physics2d;

import fried.scene.SceneStepper;

// What a scene's physics world gives the components when the project's backend for physics2d is not the default one, which moves bodies and tests colliders itself. The world is stepped with the scene and answers the queries of Physics2D.
interface PhysicsBackend2D extends SceneStepper {
	function addBody(body:Body2D):Void;
	function removeBody(body:Body2D):Void;
	function addCollider(collider:Collider2D):Void;
	function removeCollider(collider:Collider2D):Void;
	function rebuildCollider(collider:Collider2D):Void;
	function raycast(originX:Float, originY:Float, directionX:Float, directionY:Float, maxDistance:Float):Null<RaycastHit2D>;
	function overlapBox(x:Float, y:Float, width:Float, height:Float, out:Array<Collider2D>):Int;
}
