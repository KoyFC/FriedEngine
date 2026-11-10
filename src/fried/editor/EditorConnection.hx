package fried.editor;

#if fried_editor
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Eof;
import sys.net.Host;
import sys.net.Socket;

// The editor's end of the player's link: messages are a 32-bit little-endian length and then JSON, and a message that says how many "pixels" it has is followed by that many raw bytes.
class EditorConnection {
	public static inline var PROTOCOL:Int = 1;

	public var isClosed(default, null):Bool;

	var socket:Socket;
	var received:Bytes;
	var chunk:Bytes;

	public function new(port:Int) {
		socket = new Socket();
		socket.connect(new Host("127.0.0.1"), port);
		socket.output.bigEndian = false;
		received = Bytes.alloc(0);
		chunk = Bytes.alloc(65536);
		isClosed = false;
	}

	// Every message that has arrived in full since the last call.
	public function poll():Array<Dynamic> {
		var messages = [];
		while (!isClosed && Socket.select([socket], null, null, 0).read.length > 0) {
			try {
				var count = socket.input.readBytes(chunk, 0, chunk.length);
				var joined = Bytes.alloc(received.length + count);
				joined.blit(0, received, 0, received.length);
				joined.blit(received.length, chunk, 0, count);
				received = joined;
			} catch (_:Eof) {
				isClosed = true;
			}
		}
		while (received.length >= 4) {
			var length = received.getInt32(0);
			if (received.length < 4 + length) {
				break;
			}
			messages.push(Json.parse(received.getString(4, length)));
			received = received.sub(4 + length, received.length - 4 - length);
		}
		return messages;
	}

	public function send(message:Dynamic, ?pixels:Bytes):Void {
		if (pixels != null) {
			Reflect.setField(message, "pixels", pixels.length);
		}
		var text = Bytes.ofString(Json.stringify(message));
		try {
			socket.output.writeInt32(text.length);
			socket.output.write(text);
			if (pixels != null) {
				socket.output.write(pixels);
			}
		} catch (_:Dynamic) {
			isClosed = true;
		}
	}

	public function close():Void {
		socket.close();
		isClosed = true;
	}
}
#end
