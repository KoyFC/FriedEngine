package components;

import fried.Log;
import fried.physics2d.Body2D;
import fried.physics2d.Physics2D;
import fried.scene.Component;
import fried.scene.Transform2D;

// Reports where the crate of the scene is each second, what it touches, and what a ray down from the top finds, which reads the same on every physics backend.
@:serializable
class PhysicsDemo extends Component {
	public var crate:Body2D;

	var elapsed:Float = 0.0;
	var reported:Int = 0;

	public function new(crate:Body2D) {
		super();
		this.crate = crate;
	}

	override function update(delta:Float):Void {
		elapsed += delta;
		if (elapsed < reported + 1) {
			return;
		}
		reported++;
		var place = crate.gameObject.getComponent(Transform2D);
		var hit = Physics2D.raycast(gameObject.scene, 0, -300, 0, 1, 1000);
		Log.info('t=$reported crate y=${Std.int(place.y)} touching=${crate.contacts.length} ray=${hit == null ? "none" : Std.string(Std.int(hit.y))}');
	}
}
