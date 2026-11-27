import fried.scene.serialization.SceneBinary;
import haxe.Json;
import sys.io.File;

// Decodes each compiled scene given as `<source>=<compiled>` and compares it with the text it was compiled from.
class SceneBinaryTest {
	static function main() {
		var failures = 0;
		for (pair in Sys.getEnv("SCENE_PAIRS").split(" ")) {
			var parts = pair.split("=");
			var expected = Json.parse(File.getContent(parts[0]));
			var decoded = SceneBinary.decode(File.getBytes(parts[1]), parts[1]);
			if (!YamlCorpusTest.same(decoded, expected)) {
				Sys.println('FAIL ${parts[0]}');
				failures++;
			}
		}
		Sys.println('scenes decoded, $failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
