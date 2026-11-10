import fried.scene.serialization.ComponentRegistry;

// The components of this game that a scene file may use. The editor's player lists them through here too, since it never runs Main.
class Components {
	public static function register():Void {
		ComponentRegistry.register([
			Box.describeComponent(),
			CameraFollow.describeComponent(),
			PlayerController.describeComponent(),
			RegionLabel.describeComponent(),
			RegionScroller.describeComponent(),
			Spinner.describeComponent()
		]);
	}
}
