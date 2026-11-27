# Documents in HTML and CSS

A `fried.ui.UIDocument` is a screen written as an HTML file and styled by CSS files. It is one scene node, a `Control`: its box is the viewport of the document, so it is placed with anchors like any control, and by default it stretches over its parent. Inside, the document keeps its own tree of `UIElement`s, made from the HTML elements, and lays them out, draws them and gives them the pointer itself. A document costs the scene one node however many elements it has.

Nothing is converted at build time. The engine reads and parses the `.html` and `.css` files when the document loads, on every platform, so the editor's player, which reads assets as they are, shows the same as a console does. Everything is drawn with the primitives of the [draw queue](draw-queue.md): filled rectangles, text and textures.

## The files

The `document` field names the HTML file and the `theme` field an optional CSS file, both as asset references in a [scene file](scene-files.md).

```json
{ "type": "UIDocument", "id": "menu",
  "document": {"root": "game", "path": "ui/menu.html"},
  "theme": {"root": "game", "path": "ui/theme.css"} }
```

The HTML is read by the engine's own small parser (`fried.ui.html.HtmlParser`), which is forgiving the way a browser is: an element with no content such as `<link>` or `<img>` needs no slash, an end tag that does not match closes what it can, and `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, `&nbsp;` (a plain space) and numeric entities are decoded. Every repair is reported with its line and column. The parser does not close an element a browser would close by itself, such as a `<li>` before the next `<li>`, so close every element. (The engine does not use Haxe's `Xml` or `EReg`, because they pull a regular expression library into the program, which does not build for the DS.) The `<body>` is the root of the document and fills the node's box, so `body { display: flex; justify-content: center; align-items: center; }` centers a panel on the screen. The text of an element is cut at spaces and its blanks are collapsed; there is no text mixed with elements in one line, so a `<span>` inside a sentence is a block of its own.

The sheets apply in this order, each over the one before: the engine's own (`assets/ui/default.css`, which sets the font, the sizes of headings and the look of a `<button>`), the `<link rel="stylesheet">` and `<style>` of the file in order, and the `theme`. Across all of them the most specific selector wins, and between equal ones the later sheet and then the later rule, so a theme that styles `button` does not take away the `button:focus` of the engine's sheet. `!important` is not supported.

A `StyleSheet` is loaded once for its path, the way a `Font` is, and every document that links it or has it as its theme shares that one object. Changing the sheet changes all of them, and the file is read and parsed once.

A path in an `href`, `src` or `url()` is relative to the file that writes it, or starts with `engine:` or `game:` to name a file of that asset root, as in `url("engine:NunitoSans.ttf")`.

## What is supported

Elements: `div section header footer nav main ul li p span label h1 h2 h3` (all blocks), `button`, and `img`. Any other element is treated as a `div` and reported. `id`, `class`, `hidden` and `disabled` are read, and `src` of an image.

Selectors: a tag, `*`, `.class`, `#id` and `:hover`, `:active`, `:focus`, `:disabled`, put together in one compound selector, and compounds joined by a space (any ancestor) or `>` (the parent). Lists with commas are fine.

Properties:

| Group | Properties |
|---|---|
| Box | `width`, `height`, `min-*`, `max-*` (px or %, or auto), `margin`, `padding`, `border`, `border-width`, `border-color`, `border-style` (solid or none) in px, with the usual one to four value shorthands. The sizes are those of the content, as in a browser |
| Layout | `display` (block, flex, none), `flex-direction`, `justify-content` (flex-start, center, flex-end, space-between), `align-items` (stretch, flex-start, center, flex-end), `gap`, `flex-grow` and the `flex: <number>` shorthand |
| Looks | `background-color`, `color`, `opacity`, `visibility` |
| Text | `font-family`, `font-size`, `text-align` |
| Fonts | `@font-face { font-family; src: url() }` |

A block stacks its children and an auto width fills the space. A flex container lays its children in a row or a column, shares what is left over by `flex-grow`, and never shrinks them, so what does not fit overflows. Nothing is clipped. Colors are `#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb()`, `rgba()` and `white black red green blue gray transparent`.

The scale and rotation of the node are not applied to the document.

## What is left out is said

Every property, value, selector, element or rule that is not supported is reported once in the log with where it is and what to write instead, as `ui/theme.css:12:3: "foo" is not a color the subset reads (fix: ...)`, and the rest of the file still applies. Examples are `@media`, `position`, `var()`, `calc()`, a pseudo-element, `margin: auto` (use `justify-content` and `align-items` on the parent), `rem` and `em` (read as 16 pixels each, and reported).

Each size of a font is a separate atlas of glyphs in memory, so a document that uses more than four sizes of a family is told so.

## Binding in code

A class that extends `UIDocument` and is marked `@:ui("ui/menu.html")` is compiled against its HTML file, so the game never looks an element up by a string. The build macro (`UIDocumentBuilder`) reads the file while compiling and writes what it names into the class:

```haxe
@:ui("ui/menu.html")
@:serializable
class MainMenu extends UIDocument {
	var clicks:Int = 0;                       // shown by {{clicks}}

	function makeSound():Void {               // called by onclick="makeSound"
		clicks++;
	}

	override function ready():Void {
		super.ready();
		quit.disabled = true;                 // <button id="quit">, a UIButton field
	}
}
```

- Every element with an `id` is a public field of the class, `play-button` as `playButton`, typed by its tag: `UIButton` for a `button`, `UIImage` for an `img` and `UIElement` for the rest. It is filled when the document loads, so it can be used in `ready()` after `super.ready()`.
- `onclick="startGame"` sets that element's `onClick` to the method `startGame`, which takes no arguments. The element needs an id.
- `{{score}}` in a text shows the field `score`, which needs a type. Assigning it rewrites that text and lays the document out again, and nothing runs each frame.
- A method that does not exist, a `{{name}}` with no field, or an id that cannot be a field (`1x`, or two that give the same name) is a compile error that points at the place in the HTML file.

The file is read again when the game runs, so its styles, layout and fixed text can change without compiling. What the class was compiled against cannot: if an id the class needs is gone from the file, loading fails and says to build the game again. A scene file names a `@:ui` class as the node's `type`, with no `document`. A document that is not a `@:ui` class has no handlers, and an `onclick` in it is reported.

## Focus, keyboard and gamepad

A document can be used without a pointer. The elements that can have the focus are the `<button>`s, the elements with a `tabindex` and the ones with an `onClick`, as long as they are shown and not disabled. When the document loads, the first of them has the focus (`focusOnReady`, on by default), and `:focus` selects it, which the engine's sheet draws as a white border. A press on one gives it the focus too.

The arrow keys, the D-pad and the left stick (pushed past half way, once for each push) move the focus to the nearest element in that direction: the one that is farthest to the side counts double, so a column of buttons moves up and down and a row left and right. Enter, Space and the gamepad's South button press the focused element, which looks pressed while the key is down and is clicked when it is let go. Escape and the East button call `onCancel`. Each of these is marked as handled only when the document used it, so a document with nothing to focus leaves them to the game.

## Pointer

A press on a `<button>`, or on an element with an `onClick`, is held until it is let go, and `onClick` is called when it is let go over the same element. `:hover` and `:active` are set on the element under the pointer and on its ancestors, and `:active` ends when the pointer leaves what took the press. A press or a click is marked as handled only when it lands on something that takes it or on an element with a background that is not transparent, so a transparent part of a document lets the pointer through to the game.

## Layout is lazy

The style of an element is worked out again only when its classes or states changed, and then for it and its descendants, and the layout only after a style, a text, a visibility or the size of the node changed.

## Cost

Everything per frame is whole numbers, since the DS has no floating point unit, and an `Int` costs a fraction of a `Float` there. The text measures are kept for as long as the text and the font stay the same, the rules of a sheet are indexed by what they select so an element is only tried against a few, and the font of a family and size is looked up once. A change of style that touches only paint (a color, an opacity, a visibility) does not lay the document out again. The measurements are in [UI measurements](../development/ui-measurements.md).
