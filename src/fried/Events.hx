package fried;

class Events {
	public static function pump():Bool {
		return EventsNative.pump() != 0;
	}
}

@:include("events.h")
private extern class EventsNative {
	@:native("fried_events_pump")
	static function pump():Int;
}
