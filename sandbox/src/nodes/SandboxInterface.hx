package nodes;

import fried.Bootstrap;
import fried.Log;
import fried.scene.CanvasLayer;
import fried.scene.Label;

// The sandbox's interface, a scene of its own that the world scene instances: the hints and the icons down the right edge.
@:serializable
class SandboxInterface extends CanvasLayer {
	static inline var ICON_SIZE = 64;

	override function ready():Void {
		var shell = SandboxShell.of();
		var renderer = Bootstrap.renderer;
		var hints = [
			'Run ${shell.runCount}',
			"Space/Enter/A/click: sound",
			"M/F6/B: music",
			"WASD/arrows/stick/d-pad: move",
			"Q/E/L/R: zoom",
			"Shift+arrows: move window",
			"F2/North: next scene",
			"F3/Select: overlay",
			"F4: interface",
			"F5: collider bounds",
			"F7: gameplay actions",
			"Esc/Start: quit"
		];

		// The hints stop short of the icons down the right edge, so a narrow screen stacks more lines.
		var hintText = getById("hints", Label);
		hintText.font = shell.font;
		hintText.text = hints.join("   ");
		hintText.maxWidth = renderer.width - ICON_SIZE - 16 * 3;
		var panel = getById("hint-panel", HintPanel);
		panel.width = hintText.textWidth + 8;
		panel.height = hintText.textHeight + 8;
		Log.info('The hints take ${hintText.textHeight / shell.font.lineHeight} lines, ${hintText.textWidth}x${hintText.textHeight}, before a frame has drawn them');

		getById("region-label", Label).font = shell.font;
	}
}
