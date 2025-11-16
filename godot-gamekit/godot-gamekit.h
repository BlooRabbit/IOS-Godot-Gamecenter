#pragma once

#include "core/object/ref_counted.h"
#include "core/string/ustring.h"
#include "core/variant/dictionary.h"

@class GodotGameKitProxy;
@class InitializationData;
@class AchievementData;
@class AchievementNameData;

class GodotGameKit : public RefCounted {
	GDCLASS(GodotGameKit, RefCounted)

		GodotGameKitProxy* proxy = nullptr;

	static void _bind_methods();

	void _on_initialized(InitializationData* p_data);
	void _on_achievement_reported(AchievementData* p_data);
	void _on_achievements_loaded(const NSArray<AchievementData*>* p_list);
	void _on_achievement_names_loaded(void* p_list);

public:
	// Game Center
	Signal initialize_game_center();
	bool is_authenticated() const;

	// Achievements
	Signal report_achievement(String p_achievement_id, double p_percent_complete = 100.0);
	Signal load_achievements();
	Signal load_achievement_names();

	GodotGameKit();
};
