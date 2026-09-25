package fried;

class Events {
	public static function pump():Bool {
		var quitRequested = EventsNative.pump() != 0;
		dispatchWindowEvents();
		return quitRequested;
	}

	static function dispatchWindowEvents():Void {
		var type:WindowEventType = cast EventsNative.pollWindowEvent();

		while (type != None) {
			var window = Window.fromId(EventsNative.getWindowId());
			if (window != null) {
				switch (type) {
					case Close:
						if (window.onClose != null) {
							window.onClose();
						}
					case Resized:
						if (window.onResize != null) {
							window.onResize(EventsNative.getData1(), EventsNative.getData2());
						}
					case FocusGained:
						if (window.onFocusChanged != null) {
							window.onFocusChanged(true);
						}
					case FocusLost:
						if (window.onFocusChanged != null) {
							window.onFocusChanged(false);
						}
					case None:
				}
			}
			type = cast EventsNative.pollWindowEvent();
		}
	}
}

private enum abstract WindowEventType(Int) {
	var None = 0;
	var Close = 1;
	var Resized = 2;
	var FocusGained = 3;
	var FocusLost = 4;
}

@:include("events.h")
private extern class EventsNative {
	@:native("fried_events_pump")
	static function pump():Int;

	@:native("fried_events_poll_window_event")
	static function pollWindowEvent():Int;

	@:native("fried_events_get_window_id")
	static function getWindowId():Int;

	@:native("fried_events_get_data1")
	static function getData1():Int;

	@:native("fried_events_get_data2")
	static function getData2():Int;
}
