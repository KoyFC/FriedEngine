package fried.ui;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.input.InputEvent;
import fried.input.MouseButton;
import fried.io.Assets;
import fried.scene.Control;
import fried.ui.css.ElementState;

// A screen written in HTML and CSS. It is one node: its box, which is placed like any control's, is the viewport of the document, and the elements inside are laid out and drawn by the document itself.
//
// The sheets apply in this order, each over the one before: the engine's own, the ones the file links or holds in a <style>, and then `theme`, which is how one sheet is shared between documents from the inspector. The cascade is simple on purpose: within a sheet, a more specific selector wins and then the later rule. What a document uses is reported once, with where it is, in the log when it is not supported.
//
// The document is sized to its box when it is drawn, with the body filling it, and works its layout out again only after a class, a state, a text or the size changed.
@:serializable
@:autoBuild(fried.ui.UIDocumentBuilder.build())
class UIDocument extends Control {
	// The HTML file the document shows.
	public var document(default, set):HtmlSource;

	// A sheet laid over the ones the document has, shared with every other document that names it.
	public var theme(default, set):StyleSheet;

	// The body of the document, once it has loaded.
	@:noSerialize public var root(default, null):Null<UIElement>;

	static inline var FRONT_TOUCH_DEVICE:Int = 0;

	static var scratch:Rect = new Rect(0, 0, 0, 0);

	var path:String;
	var elementsById:Map<String, UIElement>;
	var bindingValues:Map<String, String>;
	var boundTexts:Map<String, Array<UIText>>;
	var ownSheets:Array<StyleSheet>;
	var sheets:Array<StyleSheet>;
	var fontSizes:Map<String, Array<Int>>;
	var images:Array<UIImage>;
	var dirtyStyles:Array<UIElement>;
	var isLayoutDirty:Bool;
	var isLoaded:Bool;
	var laidWidth:Float;
	var laidHeight:Float;

	var hoveredLeaf:Null<UIElement>;
	var pressedTarget:Null<UIElement>;
	var pressedLeaf:Null<UIElement>;
	var isHeldByMouse:Bool;
	var isHeldByTouch:Bool;
	var heldFingerId:Int;

	public function new() {
		super("UIDocument");
		anchorMaxX = 1.0;
		anchorMaxY = 1.0;
		ownSheets = [];
		sheets = [];
		fontSizes = new Map();
		elementsById = new Map();
		bindingValues = new Map();
		boundTexts = new Map();
		images = [];
		dirtyStyles = [];
		isLayoutDirty = true;
		isLoaded = false;
		laidWidth = -1.0;
		laidHeight = -1.0;
		heldFingerId = 0;
	}

	// The asset path of the HTML a subclass shows, when it names one in code instead of in a scene file.
	function sourcePath():Null<String> {
		return null;
	}

	override function ready():Void {
		ensureLoaded();
	}

	override function draw():Void {
		ensureLoaded();
		ensureFresh();
		if (root != null) {
			drawElement(root, worldX, worldY, 1.0);
		}
	}

	override function onEvent(event:InputEvent):Void {
		if (root == null) {
			return;
		}
		var isHeld = isHeldByMouse || isHeldByTouch;
		switch (event.type) {
			case MouseMoved:
				var leaf = hitTest(event);
				updateHover(leaf);
				if (isHeldByMouse) {
					updatePressed(leaf);
				}
			case MouseButtonDown if (!isHeld && event.mouseButton == MouseButton.Left):
				isHeldByMouse = press(event);
			case TouchDown if (!isHeld && event.touchDevice == FRONT_TOUCH_DEVICE):
				isHeldByTouch = press(event);
				heldFingerId = event.fingerId;
			case TouchMoved if (isHeldByTouch && event.fingerId == heldFingerId):
				updatePressed(hitTest(event));
			case MouseButtonUp if (isHeldByMouse && event.mouseButton == MouseButton.Left):
				release(event);
			case TouchUp if (isHeldByTouch && event.fingerId == heldFingerId):
				release(event);
			case _:
		}
	}

	// Builds the elements from the HTML, once. A document with no file yet stays empty and tries again when it is drawn.
	function ensureLoaded():Void {
		if (isLoaded) {
			return;
		}
		var source = document;
		if (source == null) {
			var assetPath = sourcePath();
			if (assetPath == null) {
				return;
			}
			source = HtmlSource.from(assetPath);
		}
		isLoaded = true;
		build(source);
		bindElements();
		reportUnboundHandlers(root);
	}

	// Gives the fields of a subclass their elements and their handlers. The code of a class marked @:ui writes this one.
	function bindElements():Void {}

	// The element of a document with this id, which a class compiled against the file asks for. A file that no longer has it was changed after the class was compiled.
	function requireElement<T:UIElement>(id:String, type:Class<T>):T {
		var element = elementsById.get(id);
		if (element == null || !Std.isOfType(element, type)) {
			throw '$path has no ${Type.getClassName(type)} with the id "$id", which ${Type.getClassName(Type.getClass(this))} was compiled against. Build the game again.';
		}
		return cast element;
	}

	// Fills the {{name}} of the texts that show it.
	function setBinding(name:String, value:String):Void {
		bindingValues.set(name, value);
		var texts = boundTexts.get(name);
		if (texts != null) {
			for (text in texts) {
				text.refresh(bindingValues);
			}
		}
	}

	function reportUnboundHandlers(element:UIElement):Void {
		if (element.handlerName != null && element.onClick == null) {
			UIDiagnostics.report(path, 0, 0, 'onclick="${element.handlerName}" is not bound, since a document binds it only in a class marked @:ui', "make the document a class that extends UIDocument and is marked @:ui(\"file.html\"), or set onClick in code");
		}
		for (child in element.children) {
			reportUnboundHandlers(child);
		}
	}

	function build(source:HtmlSource):Void {
		path = source.path;
		var top = source.xml;
		var html = firstElementNamed(top, "html");
		var head = html != null ? firstElementNamed(html, "head") : top;
		var body = html != null ? firstElementNamed(html, "body") : null;
		ownSheets = [];
		if (head != null) {
			for (child in head.elements()) {
				readHead(child);
			}
		}
		var content = body != null ? body : (html != null ? html : top);
		var bodyRoot = new UIElement("body", content.nodeType == Element ? content.get("id") : null, content.nodeType == Element ? classesOf(content) : null);
		root = bodyRoot;
		images = [];
		elementsById = new Map();
		boundTexts = new Map();
		if (bodyRoot.id != null) {
			elementsById.set(bodyRoot.id, bodyRoot);
		}
		buildChildren(content, bodyRoot);
		bodyRoot.setDocument(this);
		rebuildSheets();
		invalidateStyle(bodyRoot);
	}

	function readHead(element:Xml):Void {
		switch (element.nodeName.toLowerCase()) {
			case "link":
				if (element.get("rel") == "stylesheet" && element.get("href") != null) {
					ownSheets.push(StyleSheet.from(UIPaths.resolve(path, element.get("href"))));
				}
			case "style":
				var text = [for (child in element) if (child.nodeType == PCData || child.nodeType == CData) child.nodeValue].join("");
				ownSheets.push(StyleSheet.parse(path + "#style", text));
			case "script":
				UIDiagnostics.report(path, 0, 0, "a <script> is not run", "bind the document in Haxe");
			case _:
		}
	}

	function buildChildren(xml:Xml, parent:UIElement):Void {
		for (child in xml) {
			switch (child.nodeType) {
				case Element:
					var element = createElement(child);
					if (element != null) {
						parent.appendChild(element);
						buildChildren(child, element);
					}
				case PCData | CData:
					var text = collapse(child.nodeValue);
					if (text != "") {
						var element = new UIText(text);
						for (name in element.bindTemplate(text)) {
							var texts = boundTexts.get(name);
							if (texts == null) {
								texts = [];
								boundTexts.set(name, texts);
							}
							texts.push(element);
						}
						element.refresh(bindingValues);
						parent.appendChild(element);
					}
				case _:
			}
		}
	}

	function createElement(xml:Xml):Null<UIElement> {
		var tag = xml.nodeName.toLowerCase();
		var id = xml.get("id");
		var classes = classesOf(xml);
		var element:UIElement;
		switch (tag) {
			case "link" | "style" | "script" | "head" | "meta" | "title":
				return null;
			case "button":
				element = new UIButton(id, classes);
			case "img":
				var source = xml.get("src");
				if (source == null) {
					UIDiagnostics.report(path, 0, 0, "an <img> has no src, so it is left out", 'write <img src="picture.png" />');
					return null;
				}
				var image = new UIImage(UIPaths.resolve(path, source), id, classes);
				images.push(image);
				element = image;
			case "div" | "section" | "header" | "footer" | "nav" | "main" | "ul" | "li" | "p" | "span" | "label" | "h1" | "h2" | "h3":
				element = new UIElement(tag, id, classes);
			case _:
				UIDiagnostics.report(path, 0, 0, '<$tag> is not an element the subset knows, so it is treated as a <div>', "use a <div>");
				element = new UIElement(tag, id, classes);
		}
		if (id != null) {
			elementsById.set(id, element);
		}
		element.handlerName = xml.get("onclick");
		element.hidden = xml.exists("hidden");
		element.disabled = xml.exists("disabled");
		return element;
	}

	static function classesOf(xml:Xml):Array<String> {
		var value = xml.get("class");
		return value == null ? [] : [for (name in ~/\s+/g.split(StringTools.trim(value))) if (name != "") name];
	}

	static function collapse(text:String):String {
		return StringTools.trim(~/\s+/g.replace(text, " "));
	}

	static function firstElementNamed(xml:Xml, name:String):Null<Xml> {
		for (child in xml.elements()) {
			if (child.nodeName.toLowerCase() == name) {
				return child;
			}
		}
		return null;
	}

	function rebuildSheets():Void {
		sheets = [StyleSheet.from(Assets.engine("ui/default.css"))].concat(ownSheets);
		if (theme != null) {
			sheets.push(theme);
		}
	}

	@:allow(fried.ui)
	function invalidateStyle(element:UIElement):Void {
		if (!element.isStyleDirty) {
			element.isStyleDirty = true;
			dirtyStyles.push(element);
		}
		isLayoutDirty = true;
	}

	@:allow(fried.ui)
	function invalidateLayout():Void {
		isLayoutDirty = true;
	}

	// Works out what is out of date: the style of the elements that changed and their descendants, and then the layout.
	function ensureFresh():Void {
		if (root == null) {
			return;
		}
		var renderer = DrawQueue.currentRenderTarget;
		if (renderer != null) {
			for (image in images) {
				if (image.load(renderer)) {
					isLayoutDirty = true;
				}
			}
		}
		if (dirtyStyles.length > 0) {
			for (element in dirtyStyles) {
				if (!hasDirtyAncestor(element)) {
					resolveSubtree(element);
				}
			}
			for (element in dirtyStyles) {
				element.isStyleDirty = false;
			}
			dirtyStyles = [];
		}
		var width = rectWidth;
		var height = rectHeight;
		if (isLayoutDirty || width != laidWidth || height != laidHeight) {
			FlexLayout.layoutRoot(root, width, height);
			laidWidth = width;
			laidHeight = height;
			isLayoutDirty = false;
		}
	}

	function hasDirtyAncestor(element:UIElement):Bool {
		var ancestor = element.parent;
		while (ancestor != null) {
			if (ancestor.isStyleDirty) {
				return true;
			}
			ancestor = ancestor.parent;
		}
		return false;
	}

	function resolveSubtree(element:UIElement):Void {
		StyleResolver.resolve(element, sheets, fontSizes, path);
		for (child in element.children) {
			resolveSubtree(child);
		}
	}

	function drawElement(element:UIElement, originX:Float, originY:Float, parentOpacity:Float):Void {
		if (!element.isDisplayed()) {
			return;
		}
		var style = element.style;
		var opacity = parentOpacity * style.opacity;
		if (style.isVisible) {
			var x = originX + element.boxX;
			var y = originY + element.boxY;
			var width = element.boxWidth;
			var height = element.boxHeight;
			if (style.backgroundColor.alpha > 0) {
				fill(x, y, width, height, style.backgroundColor, opacity);
			}
			drawBorder(style, x, y, width, height, opacity);
			if (Std.isOfType(element, UIText)) {
				drawText(cast element, x, y, opacity);
			} else if (Std.isOfType(element, UIImage)) {
				var texture = cast(element, UIImage).texture;
				if (texture != null) {
					DrawQueue.submitTexture(priority, texture, x + style.borderLeft + style.paddingLeft, y + style.borderTop + style.paddingTop, texture.width,
						texture.height);
				}
			}
		}
		for (child in element.children) {
			drawElement(child, originX, originY, opacity);
		}
	}

	function drawBorder(style:Style, x:Float, y:Float, width:Float, height:Float, opacity:Float):Void {
		if (style.borderTop <= 0 && style.borderRight <= 0 && style.borderBottom <= 0 && style.borderLeft <= 0) {
			return;
		}
		var color = style.hasBorderColor ? style.borderColor : style.color;
		fill(x, y, width, style.borderTop, color, opacity);
		fill(x, y + height - style.borderBottom, width, style.borderBottom, color, opacity);
		var sideHeight = height - style.borderTop - style.borderBottom;
		fill(x, y + style.borderTop, style.borderLeft, sideHeight, color, opacity);
		fill(x + width - style.borderRight, y + style.borderTop, style.borderRight, sideHeight, color, opacity);
	}

	function drawText(element:UIText, x:Float, y:Float, opacity:Float):Void {
		var style = element.style;
		var font = style.font;
		if (font == null) {
			return;
		}
		var contentX = x + style.borderLeft + style.paddingLeft;
		var contentWidth = element.boxWidth - style.horizontalExtras();
		var lineY = y + style.borderTop + style.paddingTop;
		var color = faded(style.color, opacity);
		for (index in 0...element.lines.length) {
			var line = element.lines[index];
			if (line != "") {
				var lineWidth = element.lineWidths[index];
				var spare = contentWidth - lineWidth;
				var lineX = contentX + switch (style.textAlign) {
					case Style.TEXT_CENTER: spare / 2;
					case Style.TEXT_RIGHT: spare;
					case _: 0.0;
				}
				DrawQueue.submitText(priority, font, line, lineX, lineY, lineWidth, font.lineHeight, color);
			}
			lineY += font.lineHeight;
		}
	}

	function fill(x:Float, y:Float, width:Float, height:Float, color:Color, opacity:Float):Void {
		if (width <= 0 || height <= 0) {
			return;
		}
		scratch.x = Std.int(x);
		scratch.y = Std.int(y);
		scratch.width = Std.int(width);
		scratch.height = Std.int(height);
		DrawQueue.submitFillRect(priority, scratch, faded(color, opacity));
	}

	static function faded(color:Color, opacity:Float):Color {
		return opacity >= 1.0 ? color : Color.rgba(color.red, color.green, color.blue, Std.int(color.alpha * opacity));
	}

	// The deepest element under the pointer, the last drawn of those that overlap.
	function hitTest(event:InputEvent):Null<UIElement> {
		return hitElement(root, eventX(event) - worldX, eventY(event) - worldY);
	}

	function hitElement(element:UIElement, x:Float, y:Float):Null<UIElement> {
		if (!element.isDisplayed()) {
			return null;
		}
		var index = element.children.length - 1;
		while (index >= 0) {
			var hit = hitElement(element.children[index], x, y);
			if (hit != null) {
				return hit;
			}
			index--;
		}
		var isInside = x >= element.boxX && x < element.boxX + element.boxWidth && y >= element.boxY && y < element.boxY + element.boxHeight;
		return isInside ? element : null;
	}

	static function isWithin(leaf:UIElement, ancestor:UIElement):Bool {
		var current:Null<UIElement> = leaf;
		while (current != null) {
			if (current == ancestor) {
				return true;
			}
			current = current.parent;
		}
		return false;
	}

	// Sets a state on the element and every one above it, the way a browser marks a hover or a press.
	static function setChain(leaf:Null<UIElement>, bit:Int, isOn:Bool):Void {
		var current = leaf;
		while (current != null) {
			current.setState(bit, isOn);
			current = current.parent;
		}
	}

	function updateHover(leaf:Null<UIElement>):Void {
		if (leaf == hoveredLeaf) {
			return;
		}
		var current = hoveredLeaf;
		hoveredLeaf = leaf;
		while (current != null) {
			if (leaf == null || !isWithin(leaf, current)) {
				current.setState(ElementState.HOVER, false);
			}
			current = current.parent;
		}
		setChain(leaf, ElementState.HOVER, true);
	}

	static function isClickable(element:UIElement):Bool {
		return (element.onClick != null || Std.isOfType(element, UIButton)) && !element.disabled;
	}

	// Starts a press on what is under the pointer. Returns whether it is held, which is when it is on something that takes a click.
	function press(event:InputEvent):Bool {
		var leaf = hitTest(event);
		if (leaf == null) {
			return false;
		}
		var target:Null<UIElement> = leaf;
		while (target != null && !isClickable(target)) {
			target = target.parent;
		}
		if (target != null) {
			pressedTarget = target;
			pressedLeaf = leaf;
			setChain(leaf, ElementState.ACTIVE, true);
			event.handled = true;
			return true;
		}
		var current:Null<UIElement> = leaf;
		while (current != null) {
			if (current.style.backgroundColor.alpha > 0) {
				event.handled = true;
				break;
			}
			current = current.parent;
		}
		return false;
	}

	// While held, the press is on only as long as the pointer is over what took it.
	function updatePressed(leaf:Null<UIElement>):Void {
		setChain(pressedLeaf, ElementState.ACTIVE, false);
		pressedLeaf = null;
		if (leaf != null && pressedTarget != null && isWithin(leaf, pressedTarget)) {
			pressedLeaf = leaf;
			setChain(leaf, ElementState.ACTIVE, true);
		}
	}

	function release(event:InputEvent):Void {
		var leaf = hitTest(event);
		var target = pressedTarget;
		var isClick = leaf != null && target != null && isWithin(leaf, target);
		setChain(pressedLeaf, ElementState.ACTIVE, false);
		pressedLeaf = null;
		pressedTarget = null;
		isHeldByMouse = false;
		isHeldByTouch = false;
		event.handled = true;
		if (isClick && target.onClick != null && !target.disabled) {
			target.onClick();
		}
	}

	function set_document(value:HtmlSource):HtmlSource {
		document = value;
		isLoaded = false;
		root = null;
		images = [];
		dirtyStyles = [];
		hoveredLeaf = null;
		pressedTarget = null;
		pressedLeaf = null;
		isHeldByMouse = false;
		isHeldByTouch = false;
		isLayoutDirty = true;
		return value;
	}

	function set_theme(value:StyleSheet):StyleSheet {
		theme = value;
		if (root != null) {
			rebuildSheets();
			invalidateStyle(root);
		}
		return value;
	}
}
