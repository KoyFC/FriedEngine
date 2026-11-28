package fried.scene;

// The place of a game object in the scene: its parent and children, and where it is in the world. This one has no position of its own, and the classes under it add the kind a place has.
@:serializable
@:allow(fried.scene)
@:allow(fried.editor)
class Transform extends Component {
	@:noSerialize public var parent(default, null):Null<Transform>;
	@:noSerialize public var childCount(get, never):Int;

	// Where the object is in the world, after every ancestor's transform. Worked out when read, and again only after something changed.
	@:noSerialize public var worldX(get, never):Single;
	@:noSerialize public var worldY(get, never):Single;
	@:noSerialize public var worldRotation(get, never):Single;
	@:noSerialize public var worldScaleX(get, never):Single;
	@:noSerialize public var worldScaleY(get, never):Single;

	@:allow(fried.scene.Scene)
	@:allow(fried.scene.serialization.SceneLoader)
	@:allow(fried.editor)
	var children:Array<Transform>;

	var worldDirty:Bool;
	var parentItem:Null<Transform>;
	var wx:Single;
	var wy:Single;
	var wrot:Single;
	var wsx:Single;
	var wsy:Single;

	public function new() {
		super();
		children = [];
		worldDirty = true;
		wx = 0.0;
		wy = 0.0;
		wrot = 0.0;
		wsx = 1.0;
		wsy = 1.0;
	}

	// Whether a 2D transform below this one is placed against it.
	function isPlaced2D():Bool {
		return false;
	}

	function isPlaced3D():Bool {
		return false;
	}

	function ensureWorld():Void {
		worldDirty = false;
	}

	// Stops at a transform that is already dirty, whose subtree is dirty with it.
	function markWorldDirty():Void {
		if (worldDirty) {
			return;
		}
		worldDirty = true;
		for (child in children) {
			child.parentTransformChanged();
		}
	}

	function parentTransformChanged():Void {
		markWorldDirty();
	}

	// A 2D transform is placed in the plane of the screen, so a 3D one above it places it as no parent would.
	function parentChanged():Void {
		parentItem = parent != null && parent.isPlaced2D() ? parent : null;
		markWorldDirty();
	}

	// The size of the view the scene is drawn to changed.
	function viewChanged():Void {}

	public function setParent(value:Null<Transform>, ?index:Int):Void {
		var ancestor = value;
		while (ancestor != null) {
			if (ancestor == this) {
				throw 'The object ${gameObject.name} cannot be a child of ${value.gameObject.name}, which is inside it.';
			}
			ancestor = ancestor.parent;
		}
		var wasIn = gameObject.scene;
		var willBeIn = value != null ? value.gameObject.scene : null;
		if (wasIn != null) {
			gameObject.leaveScene();
		}
		if (parent != null) {
			parent.children.remove(this);
		}
		parent = value;
		if (value != null) {
			if (index == null || index >= value.children.length) {
				value.children.push(this);
			} else {
				value.children.insert(index < 0 ? 0 : index, this);
			}
		}
		parentChanged();
		refreshFlags();
		if (willBeIn != null) {
			gameObject.enterScene(willBeIn);
			startTree();
		}
	}

	public function getChild(index:Int):Transform {
		return children[index];
	}

	public function indexOfChild(child:Transform):Int {
		return children.indexOf(child);
	}

	public function find(name:String):Null<Transform> {
		for (child in children) {
			if (child.gameObject.name == name) {
				return child;
			}
		}
		return null;
	}

	// Recomputes what depends on the objects above, and passes a change down once.
	function refreshFlags():Void {
		var object = gameObject;
		var isActive = object.active && (parent == null || parent.gameObject.activeInHierarchy);
		if (isActive == object.activeInHierarchy) {
			return;
		}
		object.activeInHierarchy = isActive;
		object.refreshComponents();
		for (child in children) {
			child.refreshFlags();
		}
	}

	function startTree():Void {
		for (child in children) {
			child.startTree();
		}
		gameObject.startComponents();
	}

	inline function get_childCount():Int {
		return children.length;
	}

	inline function get_worldX():Single {
		if (worldDirty) {
			ensureWorld();
		}
		return wx;
	}

	inline function get_worldY():Single {
		if (worldDirty) {
			ensureWorld();
		}
		return wy;
	}

	inline function get_worldRotation():Single {
		if (worldDirty) {
			ensureWorld();
		}
		return wrot;
	}

	inline function get_worldScaleX():Single {
		if (worldDirty) {
			ensureWorld();
		}
		return wsx;
	}

	inline function get_worldScaleY():Single {
		if (worldDirty) {
			ensureWorld();
		}
		return wsy;
	}
}
