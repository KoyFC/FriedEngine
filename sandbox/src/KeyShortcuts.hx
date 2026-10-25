import fried.graphics.Renderer;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.Key;
import fried.scene.Component;

class KeyShortcuts extends Component {
	var keys:Array<Key>;
	var actions:Array<Void->Void>;

	public function new() {
		super();
		keys = [];
		actions = [];
	}

	public function add(key:Key, action:Void->Void):KeyShortcuts {
		keys.push(key);
		actions.push(action);
		return this;
	}

	override function onEvent(event:InputEvent, renderer:Renderer):Void {
		if (event.handled || event.type != InputEventType.KeyDown) {
			return;
		}
		var index = keys.indexOf(event.key);
		if (index < 0) {
			return;
		}
		event.handled = true;
		actions[index]();
	}
}
