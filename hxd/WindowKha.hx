package hxd;
import kha.input.KeyCode;

enum DisplayMode {
	Windowed;
	Borderless;
	Fullscreen;
	FullscreenResize;
}

class WindowKha {

	var resizeEvents : List<Void -> Void>;
	var eventTargets : List<Event -> Void>;

	public var width(get, never) : Int;
	public var height(get, never) : Int;
	public var mouseX(get, never) : Int;
	public var mouseY(get, never) : Int;
	public var mouseLock(get, set) : Bool;
	public var vsync(get, set) : Bool;
	public var isFocused(get, never) : Bool;
	public var propagateKeyEvents : Bool;

	public var title(get, set) : String;
	public var displayMode(get, set) : DisplayMode;

	var curMouseX : Float = 0.;
	var curMouseY : Float = 0.;
	var element : js.html.EventTarget;
	var timer : haxe.Timer;

	var curW : Int;
	var curH : Int;

	var focused : Bool;

	public var useScreenPixels : Bool = true;

	#if kha_html5 
	var canvas : js.html.CanvasElement;
	#end

	public function new() : Void {		
		eventTargets = new List();
		resizeEvents = new List();
		
		#if kha_html5 
			canvas = kha.SystemImpl.khanvas;
		#end
		kha.input.Mouse.get().notify(mouseDownListener, mouseUpListener, mouseMoveListener, mouseWheelListener);	
		kha.input.Keyboard.get().notify(keyboardDownListener, keyboardUpListener, pressListener);		
	}	

	public function dispose() {
		timer.stop();
	}

	public dynamic function onClose() : Bool {
		return true;
	}

	public function event( e : hxd.Event ) : Void {
		for( et in eventTargets )
			et(e);
	}

	public function addEventTarget( et : Event->Void ) : Void {
		eventTargets.add(et);
	}

	public function removeEventTarget( et : Event->Void ) : Void {
		for( e in eventTargets )
			if( Reflect.compareMethods(e,et) ) {
				eventTargets.remove(e);
				break;
			}
	}

	public function addResizeEvent( f : Void -> Void ) : Void {
		resizeEvents.push(f);
	}

	public function removeResizeEvent( f : Void -> Void ) : Void {
		for( e in resizeEvents )
			if( Reflect.compareMethods(e,f) ) {
				resizeEvents.remove(f);
				break;
			}
	}

	function onResize(e:Dynamic) : Void {
		for( r in resizeEvents )
			r();
	}

	public function resize( width : Int, height : Int ) : Void {
	}

	public function setCurrent() {
		inst = this;
	}

	static var inst : Window = null;
	public static function getInstance() : Window {
		if( inst == null ) inst = new Window();
		return inst;
	}

	function getPixelRatio() {
		return useScreenPixels ? js.Browser.window.devicePixelRatio : 1;
	}

	function get_width() {
		return kha.System.windowWidth(0);
	}

	function get_height() {
		return kha.System.windowHeight(0);
	}

	function get_mouseX() {
		return Math.round((curMouseX) * getPixelRatio());
	}

	function get_mouseY() {
		return Math.round((curMouseY) * getPixelRatio());
	}

	function get_mouseLock() : Bool {
		return false;
	}

	function set_mouseLock( v : Bool ) : Bool {
		if( v ) throw "Not implemented";
		return false;
	}

	function get_vsync() : Bool return true;

	function set_vsync( b : Bool ) : Bool {
		if( !b ) throw "Can't disable vsync on this platform";
		return true;
	}

	function mouseDownListener(button:Int, x:Int, y:Int) {		
    	if(x != curMouseX || y != curMouseY)
			mouseMoveListener(x, y, 0, 0);
		var ev = new Event(EPush, mouseX, mouseY);
		ev.button = switch(button) {
			case 1: 2;
			case 2: 1;
			case x: x;
		};
		event(ev);
    }

    function mouseUpListener(button:Int, x:Int, y:Int) {	
		if(x != curMouseX || y != curMouseY)
			mouseMoveListener(x, y, 0, 0);
		var ev = new Event(ERelease, x, y);
		ev.button = switch(button) {
			case 1: 2;
			case 2: 1;
			case x: x;
		};
		event(ev);
    }

    function mouseMoveListener(x:Int, y:Int, movementX:Int, movementY:Int) {
		curMouseX = x;
		curMouseY = y;
		event(new Event(EMove, mouseX, mouseY));
	}

	function mouseWheelListener(delta: Int) {
		var ev = new Event(EWheel, mouseX, mouseY);
		ev.wheelDelta = delta;
		event(ev);
	}

	/*
	function onTouchStart(e:js.html.TouchEvent) {
		e.preventDefault();
		var x, y, ev;
		for (touch in e.changedTouches) {
			x = Math.round((touch.clientX) * getPixelRatio());
			y = Math.round((touch.clientY) * getPixelRatio());
			ev = new Event(EPush, x, y);
			ev.touchId = touch.identifier;
			event(ev);
		}
	}

	function onTouchMove(e:js.html.TouchEvent) {
		e.preventDefault();
		var x, y, ev;
		for (touch in e.changedTouches) {
			x = Math.round((touch.clientX) * getPixelRatio());
			y = Math.round((touch.clientY) * getPixelRatio());
			ev = new Event(EMove, x, y);
			ev.touchId = touch.identifier;
			event(ev);
		}
	}

	function onTouchEnd(e:js.html.TouchEvent) {
		e.preventDefault();
		var x, y, ev;
		for (touch in e.changedTouches) {
			x = Math.round((touch.clientX) * getPixelRatio());
			y = Math.round((touch.clientY) * getPixelRatio());
			ev = new Event(ERelease, x, y);
			ev.touchId = touch.identifier;
			event(ev);
		}
	}
	*/
	function keyboardDownListener(code: KeyCode) {	
		//trace(code);
		var ev = new Event(EKeyDown, mouseX, mouseY);
		ev.keyCode = code;
		event(ev);
	}

	function keyboardUpListener(code: KeyCode) {	
		var ev = new Event(EKeyUp, mouseX, mouseY);
		ev.keyCode = code;
		event(ev);
	}

	function pressListener(char: String) {	
		//trace(char);
		//var ev = new Event(ETextInput, mouseX, mouseY);
		//ev.charCode = char;
		//event(ev);
	}

/*
	function onKeyUp(e:js.html.KeyboardEvent) {
		var ev = new Event(EKeyUp, mouseX, mouseY);
		ev.keyCode = e.keyCode;
		event(ev);
		if( !propagateKeyEvents ) {
			e.preventDefault();
			e.stopPropagation();
		}
	}

	function onKeyDown(e:js.html.KeyboardEvent) {
		var ev = new Event(EKeyDown, mouseX, mouseY);
		ev.keyCode = e.keyCode;
		event(ev);
		if( !propagateKeyEvents ) {
			switch ev.keyCode {
				case 37, 38, 39, 40, // Arrows
					33, 34, // Page up/down
					35, 36, // Home/end
					8, // Backspace
					9, // Tab
					16, // Shift
					17 : // Ctrl
						e.preventDefault();
				case _ :
			}
			e.stopPropagation();
		}
	}

	function onKeyPress(e:js.html.KeyboardEvent) {
		var ev = new Event(ETextInput, mouseX, mouseY);
		ev.charCode = e.charCode;
		event(ev);
		if( !propagateKeyEvents ) {
			e.preventDefault();
			e.stopPropagation();
		}
	}	
*/

	function onFocus(b: Bool) {
		event(new Event(b ? EFocus : EFocusLost));
		focused = b;
	}

	function get_isFocused() : Bool return focused;

	function get_displayMode() : DisplayMode {
		var doc = js.Browser.document;
		if ( doc.fullscreenElement != null) {
			return Borderless;
		}

		return Windowed;
	}

	function set_displayMode( m : DisplayMode ) : DisplayMode {
		var doc = js.Browser.document;
		var elt : Dynamic = doc.documentElement;
		var fullscreen = m != Windowed;
		if( (doc.fullscreenElement == elt) == fullscreen )
			return Windowed;
		if( m != Windowed )
			elt.requestFullscreen();
		else
			doc.exitFullscreen();

		return m;
	}

	function get_title() : String {
		return js.Browser.document.title;
	}
	function set_title( t : String ) : String {
		return js.Browser.document.title = t;
	}
}