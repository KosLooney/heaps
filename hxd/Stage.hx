package hxd;

@:deprecated("hxd.Stage is now hxd.Window")
@:noCompletion
#if kha
typedef Stage = WindowKha;
#else
typedef Stage = Window;
#end