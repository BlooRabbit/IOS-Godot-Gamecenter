#pragma once

#include "core/object/ref_counted.h"
#include "core/string/ustring.h"
#include "core/variant/dictionary.h"

// Forward declarations of Objective-C classes (Swift-exposed)
@class GodotGameKitProxy;
@class InitializationData;
@class AchievementData;
@class AchievementNameData;

class GodotGameKit : public RefCounted {
	GDCLASS(GodotGameKit, RefCounted)

		GodotGameKitProxy* proxy = nullptr;

	static void _bind_methods();

	// Internal callbacks from native/Swift side
	void _on_initialized(InitializationData* p_data);
	void _on_achievement_reported(AchievementData* p_data);

	// IMPORTANT: use void* here, not NSArray or Obj-C types
	void _on_achievements_loaded(void* p_list);
	void _on_achievement_names_loaded(void* p_list);

public:
	// Game Center
	Signal initialize_game_center();
	bool is_authenticated() const;

	// Achievements (player progress)
	Signal report_achievement(String p_achievement_id, double p_percent_complete = 100.0);
	Signal load_achievements();

	// Achievement names (full list from Game Center metadata)
	Signal load_achievement_names();

	GodotGameKit();
};
