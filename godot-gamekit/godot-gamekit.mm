#include "godot-gamekit.h"

#include "core/object/class_db.h"

// For target "godot-gamekit", Swift header is "godot_gamekit-Swift.h"
#import "godot_gamekit-Swift.h"

@import GameKit;

static NSString *fromGodotString(const String &src) {
	return [NSString stringWithUTF8String:src.utf8().get_data()];
}

static String toGodotString(NSString *src) {
	return String::utf8(src.UTF8String);
}

void GodotGameKit::_bind_methods() {
	// Methods exposed to GDScript
	ClassDB::bind_method(D_METHOD("initialize_game_center"), &GodotGameKit::initialize_game_center);
	ClassDB::bind_method(D_METHOD("is_authenticated"), &GodotGameKit::is_authenticated);

	// Signals
	// "data" is a Dictionary with keys:
	//   "initialized" : bool
	//   "error"       : String
	ADD_SIGNAL(MethodInfo("game_center_initialized", PropertyInfo(Variant::DICTIONARY, "data")));
}

Signal GodotGameKit::initialize_game_center() {
	if (!proxy) {
		proxy = [GodotGameKitProxy shared];
	}

	[proxy initializeGameCenterWithCompletion:^(InitializationData *data) {
		_on_initialized(data);
	}];

	return Signal(this, "game_center_initialized");
}

bool GodotGameKit::is_authenticated() const {
	if (!proxy) {
		return false;
	}

	return [proxy isAuthenticated];
}

GodotGameKit::GodotGameKit() {
	proxy = [GodotGameKitProxy shared];
}

void GodotGameKit::_on_initialized(InitializationData *p_data) {
	Dictionary result;
	result["initialized"] = p_data.initialized;
	result["error"] = toGodotString(p_data.error);

	call_deferred("emit_signal", "game_center_initialized", result);
}
