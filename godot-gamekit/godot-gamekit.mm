#include "godot-gamekit.h"

#include "core/object/class_db.h"

#import "godot_gamekit-Swift.h"

@import GameKit;

static NSString *fromGodotString(const String &src) {
	return [NSString stringWithUTF8String:src.utf8().get_data()];
}

static String toGodotString(NSString *src) {
	return String::utf8(src.UTF8String);
}

void GodotGameKit::_bind_methods() {
	// Methods
	ClassDB::bind_method(D_METHOD("initialize_game_center"), &GodotGameKit::initialize_game_center);
	ClassDB::bind_method(D_METHOD("is_authenticated"), &GodotGameKit::is_authenticated);

	ClassDB::bind_method(
			D_METHOD("report_achievement", "achievement_id", "percent_complete"),
			&GodotGameKit::report_achievement,
			DEFVAL(100.0));

	ClassDB::bind_method(D_METHOD("load_achievements"), &GodotGameKit::load_achievements);
	ClassDB::bind_method(D_METHOD("load_achievement_names"), &GodotGameKit::load_achievement_names);

	// Signals

	// Game Center initialization: Dictionary { initialized: bool, error: String }
	ADD_SIGNAL(MethodInfo("game_center_initialized", PropertyInfo(Variant::DICTIONARY, "data")));

	// achievement_reported: Dictionary {
	//   identifier: String, percent_complete: float, completed: bool,
	//   last_reported: float (unix time, optional), error: String
	// }
	ADD_SIGNAL(MethodInfo("achievement_reported", PropertyInfo(Variant::DICTIONARY, "achievement")));

	// achievements_loaded: Array of the same dictionaries as above
	ADD_SIGNAL(MethodInfo("achievements_loaded", PropertyInfo(Variant::ARRAY, "achievements")));

	// achievement_names_loaded: Array of { identifier: String, title: String, error: String }
	ADD_SIGNAL(MethodInfo("achievement_names_loaded", PropertyInfo(Variant::ARRAY, "names")));
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

Signal GodotGameKit::report_achievement(String p_achievement_id, double p_percent_complete) {
	if (!proxy) {
		proxy = [GodotGameKitProxy shared];
	}

	NSString *identifier = fromGodotString(p_achievement_id);

	[proxy reportAchievementWithIdentifier:identifier
						   percentComplete:p_percent_complete
								completion:^(AchievementData *data) {
									_on_achievement_reported(data);
								}];

	return Signal(this, "achievement_reported");
}

Signal GodotGameKit::load_achievements() {
	if (!proxy) {
		proxy = [GodotGameKitProxy shared];
	}

	// NOTE: use plain NSArray* here (no generics)
	[proxy loadAchievementsWithCompletion:^(NSArray *list) {
		_on_achievements_loaded((__bridge void *)list);
	}];

	return Signal(this, "achievements_loaded");
}

Signal GodotGameKit::load_achievement_names() {
	if (!proxy) {
		proxy = [GodotGameKitProxy shared];
	}

	[proxy loadAchievementNamesWithCompletion:^(NSArray *list) {
		_on_achievement_names_loaded((__bridge void *)list);
	}];

	return Signal(this, "achievement_names_loaded");
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

void GodotGameKit::_on_achievement_reported(AchievementData *p_data) {
	Dictionary d;
	d["identifier"] = toGodotString(p_data.identifier);
	d["percent_complete"] = p_data.percentComplete;
	d["completed"] = p_data.completed;

	if (p_data.lastReportedDate) {
		NSTimeInterval t = [p_data.lastReportedDate timeIntervalSince1970];
		d["last_reported"] = (double)t;
	}

	d["error"] = toGodotString(p_data.error);

	call_deferred("emit_signal", "achievement_reported", d);
}

// p_list_raw is actually NSArray<AchievementData *> * from Swift/Obj-C
void GodotGameKit::_on_achievements_loaded(void *p_list_raw) {
	NSArray *list = (__bridge NSArray *)p_list_raw;

	Array arr;

	for (id obj in list) {
		AchievementData *p_data = (AchievementData *)obj;

		Dictionary d;
		d["identifier"] = toGodotString(p_data.identifier);
		d["percent_complete"] = p_data.percentComplete;
		d["completed"] = p_data.completed;

		if (p_data.lastReportedDate) {
			NSTimeInterval t = [p_data.lastReportedDate timeIntervalSince1970];
			d["last_reported"] = (double)t;
		}

		d["error"] = toGodotString(p_data.error);
		arr.push_back(d);
	}

	call_deferred("emit_signal", "achievements_loaded", arr);
}

// p_list_raw is actually NSArray<AchievementNameData *> * from Swift/Obj-C
void GodotGameKit::_on_achievement_names_loaded(void *p_list_raw) {
	NSArray *list = (__bridge NSArray *)p_list_raw;

	Array arr;

	for (id obj in list) {
		AchievementNameData *p_data = (AchievementNameData *)obj;

		Dictionary d;
		d["identifier"] = toGodotString(p_data.identifier);
		d["title"] = toGodotString(p_data.title);
		d["error"] = toGodotString(p_data.error);
		arr.push_back(d);
	}

	call_deferred("emit_signal", "achievement_names_loaded", arr);
}
