import fried.scene.Component;
import fried.scene.Sprite;
import fried.scene.Text;

class RegionLabel extends Component {
	var sprite:Sprite;
	var label:Text;

	public function new(sprite:Sprite) {
		super();
		this.sprite = sprite;
	}

	override function start():Void {
		label = gameObject.getComponent(Text);
		if (label == null) {
			throw 'A RegionLabel needs a Text on ${gameObject.name}.';
		}
	}

	override function update():Void {
		label.text = 'region x ${sprite.source.x}';
	}
}
