package fried.scene;

import fried.graphics3d.BoxMesh;
import fried.graphics3d.Material;
import fried.graphics3d.Mesh;

@:allow(fried.graphics3d.MeshPass)
@:serializable
class MeshRenderer extends Component {
	public var mesh:Mesh;

	public var materialOverride:Material;

	var place:Transform3D;

	public function new() {
		super();
		mesh = new BoxMesh();
	}

	override function awake():Void {
		place = need(Transform3D);
	}

	override function hookFlags():Int {
		return Component.MESH;
	}
}
