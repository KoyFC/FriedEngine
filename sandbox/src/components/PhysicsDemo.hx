package components;

import fried.Log;
import fried.physics2d.Physics2D;
import fried.physics2d.RigidBody2D;
import fried.physics2d.Shape2D;
import fried.scene.Component;

// Reports what the box2d backend does with the crate of the scene: where it is each second, what touches the zone, and what a ray down from the top finds.
@:serializable
class PhysicsDemo extends Component {
	public var crate:RigidBody2D;
	public var zone:Shape2D;

	var elapsed:Float = 0.0;
	var reported:Int = 0;

	public function new(crate:RigidBody2D, zone:Shape2D) {
		super();
		this.crate = crate;
		this.zone = zone;
	}

	override function update(delta:Float):Void {
		elapsed += delta;
		if (elapsed < reported + 1) {
			return;
		}
		reported++;
		var place = crate.transform;
		var hit = Physics2D.raycast(gameObject.scene, 0, -300, 0, 1, 1000);
		Log.info('t=$reported crate y=${Std.int(cast(place, fried.scene.Transform2D).y)} zone contacts=${zone.contacts.length} ray=${hit == null ? "none" : Std.string(Std.int(hit.y))}');
	}
}
