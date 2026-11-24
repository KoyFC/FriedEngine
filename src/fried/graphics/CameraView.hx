package fried.graphics;

// Where a 2D camera looks and how far it is zoomed in, which is all the draw queue needs of one. A camera writes it before its scene is drawn, and the queue reads it when it flushes.
class CameraView {
	public var x:Single;
	public var y:Single;
	public var zoom:Single;

	public function new() {
		x = 0.0;
		y = 0.0;
		zoom = 1.0;
	}
}
