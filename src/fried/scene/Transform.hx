package fried.scene;

class Transform extends Component {
	public var x:Float;
	public var y:Float;
	public var rotation:Float;
	public var scaleX:Float;
	public var scaleY:Float;

	public function new(x:Float = 0.0, y:Float = 0.0) {
		super();
		this.x = x;
		this.y = y;
		rotation = 0.0;
		scaleX = 1.0;
		scaleY = 1.0;
	}

	public function translate(dx:Float, dy:Float):Void {
		x += dx;
		y += dy;
	}

	public function setScale(scale:Float):Void {
		scaleX = scale;
		scaleY = scale;
	}
}
