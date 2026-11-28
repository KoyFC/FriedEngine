# Scene files

A scene can also be data. `fried.scene.serialization.SceneLoader.register(name, assetPath, renderer)` registers a scene file under the game's assets, written in YAML (see [YAML in Fried files](../reference/yaml.md)), as a scene `SceneManager` can load, and `SceneLoader.build()` turns the parsed data into a `Scene`. The file is written by the editor and only ever read here, so there is no saving on the engine's side. A scene is `scenes/<name>.scene.yaml`, and a file still named `.scene.json` is read the same way. It holds a `version`, a `name`, an optional `camera` naming an object, and `objects`, a list of exactly one object, the root of the scene. A file with no root or with several is refused. Each object has a stable `id`, an optional `name`, an optional `active`, an optional `transform`, an optional list of `components` and an optional list of `children`, drawn in order. The transform and each component have a `type`, and every other key is a field of a class in its chain. A transform with no `type` is a plain `Transform`. Ids exist because names are not unique, and `Scene.findById()` and the typed `Scene.getById(id, Type)` are how game code reaches an object a file created, to give a button its `onClick`, which a file cannot hold. A file of another `version` is refused: a version 2 file says to run `fried_import migrate-scenes`, and the version is 3.

```yaml
version: 3
name: Sandbox
camera: camera
objects:
  - id: sandbox
    transform: {type: Transform2D}
    children:
      - id: camera
        transform: {type: Transform2D, x: 320, y: 240}
        components:
          - type: Camera
      - id: player
        transform: {type: Transform2D, x: 288, y: 160}
        components:
          - type: SpriteRenderer
            texture: {root: game, path: sprite.png}
          - type: Player
            speed: 240
        children:
          - id: player-hitbox
            transform: {type: Transform2D}
            components:
              - type: Collider
                width: 32
                height: 96
```

Components are described, not reflected. A subclass of `Component` marked `@:serializable` gets a static `describeComponent()` from the build macro `ComponentBuilder`, which returns a `ComponentType`: its name, the name of the nearest serializable class above it, the fields it declares itself, and how to create a component, apply fields to one and read them back. `create`, `apply` and `read` cover the fields of the whole chain, so a `Label`'s data may set a `Renderer2D`'s `priority` as well as its own `text`, and `fields` holds only the class's own, which is how an inspector shows one section per class. Every public, writable `var` of a supported type is a field: `Int`, `Float`, `Bool`, `String`, `Color`, `FlipMode`, `Rect`, `Texture` and `Font` as asset references, and any `GameObject` or `Component` class as a reference to another object of the scene, which a file spells as that object's id and the loader resolves with `getComponent()` of the field's type. A reference stays null while the objects are being built and the loader assigns it once all of them exist, so a component cannot use one in its constructor or `awake()`, only from `start()` on. Functions and read-only properties are not fields, and `@:noSerialize` leaves one out by hand. A class field named `type` is a compile error, since a file's component already uses that key. Constructor parameters are matched to fields by name and a required one with no field is a compile error, so a component that a file could not build never compiles as serializable. Assignment goes through the property, so a setter such as `Camera.zoom` still runs. A scene may use only the components `Builtins` lists and the ones a game adds with `ComponentRegistry.register()`, because Haxe never types a class only a file names; a game's own classes in the `components` package are found by `ComponentDiscovery`. `Builtins` does not register all of them: the macro `UsedTypes` reads every scene file of `assets/scenes` while the game compiles, takes each `type` it finds, in transforms and components and in the meshes and materials inside them, and the autoloads, and only those types are registered, so Haxe leaves out the code of the others. A type a scene names that is not registered still fails to load with `has the unknown type`. A class that extends one is registered together with its ancestors, since `ComponentType.parentType` describes the parent. A build for the editor, one with `-D fried_text_scenes`, and one with `-D fried_all_components`, for a game that creates components by name while it runs, register every type. `SceneLoader.load(assetPath, renderer)` builds a file's scene without pushing a layer for it, for a game that pushes its own layers, and what a file cannot know, such as a component that needs an `InputAction`, is set in code after it loads. A position taken from the view is a `RectTransform`'s anchors, which the editor sees too.

An asset reference is `{root, path}`, and a font adds `"size"`, resolved through `Filesystem.resolveAsset()`. A file that is wrong fails at load with the object and field in the message.

A scene has no per-platform values: a component that behaves differently on a platform says so in its own code, by asking `Application.platformName`.

A scene file is built whole before any component starts: every object and reference exists, and then `start()` runs on each component, children before parents, so a component's `start()` can read the rest of its scene. `SceneLoader.build()` can skip that for the editor, which only looks, so a component that draws must not need `start()` to have run. A `Scene` knows the size of the view it is drawn to (`viewWidth`, `viewHeight`), so a component reads it from there instead of holding a `Renderer`. `SceneManager.loadAdditive()` loads a scene on top of the active one, such as an interface over a level, and loading another scene unloads it.

## Instancing a scene

An entry with an `instance` key, `{id: player, instance: player, transform: {x: 40}}`, puts another scene file in the tree as one object. `instance` names a scene the way `startScene` does, and the object is the instanced file's root: the entry's `transform` overrides the fields of the root's transform, each entry of its `components` overrides the fields of the root's component of the same `type` or adds one the root lacks, and `name` and `active` replace the root's. An entry cannot have children. Only a file with exactly one top-level object can be instanced, its `camera` is ignored, and its root cannot itself be an instance entry. A scene that ends up instancing itself fails at load, naming the chain.

The ids of an instanced file belong to the instance, which is how two instances of one file never clash and how a file's own references keep meaning its own objects. They are not in the outer scene's `findById()`: the instance's root has the id the entry gave it, and `instance.getById("hitbox", Collider)` reaches an object inside. An override of a reference field, such as `wall: wall`, names an object of the outer scene. A component meant to be instanced should not require such a reference in its constructor, since its own file cannot give one.

Code does the same with `Prefab`: `Prefab.load("player").instantiate()` builds the root with its subtree and no id, ready to be added to a scene with `scene.add()` or put under an object with `transform.setParent()`, and its components start when it joins a scene. The file is read once and kept. The editor shows an instance as the one object it is, with the box of everything inside it.

## Compiled scenes

A game never reads the text. The asset import tool (`tools/fried_import`) compiles each `.scene.yaml` or `.scene.json` into `scenes/<name>.fscene` in the imported copy of the assets, and refuses at build time what the loader would refuse at run time: another `version`, or a file with no root object or several. The file keeps what the text said, so everything after reading, the loader, instances and references, is the same code for both.

A `.fscene` is little-endian: `FSCN`, the format (1), the version of the scene (2), a table of the strings the scene uses once each, keys and values alike, and then the data as tagged values (null, false, true, a 32-bit whole number, a 32-bit or 64-bit float, a string by its place in the table, a list and a map). `fried.scene.serialization.SceneBinary` reads it into the objects, lists and numbers `haxe.Json.parse` would have given, without scanning any text. The sandbox's `sandbox_3d` is 6,398 bytes of JSON and 3,713 as a `.fscene`, and 1,768 compressed with `compress: lz` (see [Import settings](../reference/import-settings.md#compression)).

The editor's player and a build made with `-D fried_text_scenes` read the YAML or JSON as it is, which is what lets the editor show an edit at once. Nothing else links the YAML reader: a game's build leaves it out.

## Migrating a project

`fried_import migrate-scenes <projectDir>` rewrites the version 2 scenes of a project as version 3, and keeps the originals in `<projectDir>/.fried/v2-backup/`. It reads the project's `src/**/*.hx` to learn which engine class each of the game's classes extends, then splits every node into an object: its position, rotation and scale go to a `Transform2D`, `Transform3D` or `RectTransform`, the fields of an engine class to its component, the rest to a component of the game's own class, and `visible: false` becomes `enabled: false`. A field it cannot place stays on the game's component and is reported. The result should be read before it is kept, and the game's classes still have to be ported by hand (see [Game objects](game-objects.md#moving-from-nodes)).
