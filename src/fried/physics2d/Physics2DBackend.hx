package fried.physics2d;

import fried.Application;
import fried.scene.PlatformList;
import fried.scene.Scene;

// Which physics backend the scene runs on, by the platform it runs as. The default one is the components themselves, and another is a world kept by the scene, made when the first body or collider asks for it.
class Physics2DBackend {
	static var uses:Null<Bool>;

	// The world of the scene, or null where the project keeps the default backend for the platform.
	public static function of(scene:Scene):Null<PhysicsBackend2D> {
		if (scene == null || !usesWorld()) {
			return null;
		}
		var found = scene.findStepper(PhysicsBackend2D);
		if (found == null) {
			found = Box2DFactory.make();
			if (found != null) {
				scene.addStepper(found);
			}
		}
		return found;
	}

	static function usesWorld():Bool {
		var platform = PlatformList.previewed == "" ? Application.platformName : PlatformList.previewed;
		for (entry in Modules.backendsByPlatform()) {
			if (entry.platform == platform && entry.module == "physics2d") {
				return entry.backend == "box2d";
			}
		}
		return false;
	}
}
