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

The HTML has to be well formed: every element is closed, and one without content ends with a slash, as in `<link rel="stylesheet" href="theme.css" />` and `<img src="icon.png" />`. A file that is not is refused with the parser's message. The `<body>` is the root of the document and fills the node's box, so `body { display: flex; justify-content: center; align-items: center; }` centers a panel on the screen. The text of an element is cut at spaces and its blanks are collapsed; there is no text mixed with elements in one line, so a `<span>` inside a sentence is a block of its own.

The sheets apply in this order, each over the one before: the engine's own (`assets/ui/default.css`, which sets the font, the sizes of headings and the look of a `<button>`), the `<link rel="stylesheet">` and `<style>` of the file in order, and the `theme`. Inside a sheet the most specific selector wins, and the later rule wins a tie. `!important` is not supported.

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

Every property, value, selector, element or rule that is not supported is reported once in the log with where it is and what to write instead, as `ui/theme.css:12:3: "foo" is not a color the subset reads (fix: ...)`, and the rest of the file still applies. An HTML problem is reported by its file, as the parser does not give lines. Examples are `@media`, `position`, `var()`, `calc()`, a pseudo-element, `margin: auto` (use `justify-content` and `align-items` on the parent), `rem` and `em` (read as 16 pixels each, and reported).

Each size of a font is a separate atlas of glyphs in memory, so a document that uses more than four sizes of a family is told so.

## Pointer

A press on a `<button>`, or on an element with an `onClick`, is held until it is let go, and `onClick` is called when it is let go over the same element. `:hover` and `:active` are set on the element under the pointer and on its ancestors, and `:active` ends when the pointer leaves what took the press. A press or a click is marked as handled only when it lands on something that takes it or on an element with a background that is not transparent, so a transparent part of a document lets the pointer through to the game.

## Layout is lazy

The style of an element is worked out again only when its classes or states changed, and then for it and its descendants, and the layout only after a style, a text, a visibility or the size of the node changed.
