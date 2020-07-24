package hxd;
import kha.Assets;
import kha.System;
import kha.Window;
import kha.WindowMode;

enum Platform {
	IOS;
	Android;
	WebGL;
	PC;
	Console;
	FlashPlayer;
}

enum SystemValue {
	IsTouch;
	IsWindowed;
	IsMobile;
}

class SystemKha {

	public static var width(get,never) : Int;
	public static var height(get, never) : Int;
	public static var lang(get, never) : String;
	public static var platform(get, never) : Platform;
	public static var screenDPI(get,never) : Float;
	public static var setCursor = setNativeCursor;
	public static var allowTimeout(get, set) : Bool;

	public static function timeoutTick() : Void {
	}

	static var loopFunc : Void -> Void;

	// JS
	static var loopInit = false;
	static var currentNativeCursor:hxd.Cursor;
	static var currentCustomCursor:hxd.Cursor.CustomCursor;

	public static function getCurrentLoop() : Void -> Void {
		return loopFunc;
	}

	public static function setLoop( f : Void -> Void ) : Void {
		
		//if( !loopInit ) {
		//	loopInit = true;
		//	browserLoop();
		//}		
		loopFunc = f;
	}
	
	/*
	static function browserLoop() {
		var window : Dynamic = js.Browser.window;
		var rqf : Dynamic = window.requestAnimationFrame ||
			window.webkitRequestAnimationFrame ||
			window.mozRequestAnimationFrame;
		rqf(browserLoop);
		if( loopFunc != null ) loopFunc();
	}	
	*/

	public static function start( callb : Void -> Void ) : Void {
	
		var options: SystemOptions = {
			title: "Kheable",
			width: 800,
			height: 600,
			window: {
				mode: WindowMode.Fullscreen
			},
			framebuffer: {
				samplesPerPixel: 0,
				verticalSync: true
			}
		};

		kha.System.start(options, function(_) {
			kha.System.notifyOnFrames(function (frames:Array<kha.Framebuffer>) {
				h3d.impl.KhaDriver.framebuffer = frames[0];
				h3d.impl.KhaDriver.g = frames[0].g4;
				if (loopFunc != null) {
					loopFunc();
				}
				h3d.impl.KhaDriver.g = null;
			});
			callb();
		});
	}

	public static function setNativeCursor( c : Cursor ) : Void {
		throw 'setNativeCursor';
	}

	public static function getDeviceName() : String {
		return "Unknown";
	}

	public static function getDefaultFrameRate() : Float {
		return 60.;
	}

	public static function getValue( s : SystemValue ) : Bool {
		return switch( s ) {
		case IsWindowed: true;
		case IsTouch: platform==Android || platform==IOS;
		case IsMobile: platform==Android || platform==IOS;
		default: false;
		}
	}

	public static function exit() : Void {
	}

	public static function openURL( url : String ) : Void {
		js.Browser.window.open(url, '_blank');
	}

	static function updateCursor() : Void {
		throw 'updateCursor';	
	}

	// getters
	static function get_width() : Int return kha.System.windowWidth(0);
	static function get_height() : Int return kha.System.windowHeight(0);
	static function get_lang() : String return "en";
	static function get_platform() : Platform {
		var ua = js.Browser.navigator.userAgent.toLowerCase();
		if( ua.indexOf("android")>=0 )
			return Android;
		else if( ua.indexOf("ipad")>=0 || ua.indexOf("iphone")>=0 || ua.indexOf("ipod")>=0 )
			return IOS;
		else
			return PC;
	}
	static function get_screenDPI() : Int return 72;
	static function get_allowTimeout() return false;
	static function set_allowTimeout(b) return false;

	
	static function __init__() : Void {		
	}	

}