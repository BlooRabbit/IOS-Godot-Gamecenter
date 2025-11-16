#pragma once

#include "core/object/ref_counted.h"
#include "core/string/ustring.h"
#include "core/variant/dictionary.h"

@class GodotGameKitProxy;
@class InitializationData;

class GodotGameKit : public RefCounted {
	GDCLASS(GodotGameKit, RefCounted)

		GodotGameKitProxy* proxy;

	static void _bind_methods();

	// Called from the native side when Game Center initialization resolves.
	void _on_initialized(InitializationData* p_data);

public:
	// Start Game Center initialization (auth flow).
	// Emit a signal when _on_initialized is called.
	Signal initialize_game_center();

	// Simple helper to query Game Center auth state.
	bool is_authenticated() const;

	GodotGameKit();
};
