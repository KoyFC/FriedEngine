package fried.physics2d;

import haxe.macro.Expr;

class Box2DFactory {
	// Makes the box2d world only in a build that some platform runs on box2d, which is the only one that has its class.
	public static macro function make():Expr {
		return Modules.isInBuild("physics2d", "box2d") ? macro new fried.physics2d.Box2DWorld() : macro null;
	}
}
