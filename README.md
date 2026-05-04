# Godot GameKit

This plugin provides an API to use the GameKit framework in Godot Engine. It is experimental and incomplete. But it is working in an actual published game project with several 10K users.

## Installation for Godot 4.5

1. Download the content of the addon folder into your ios plugins folder
2. Enable the ios plugin in the export preset

## Usage

Initialize the GameCenter connection by instantiating the GameKit plugin when you want this to happen:

var game_kit

func connect_GameCenter() -> void:
	game_kit = ClassDB.instantiate("GodotGameKit")
	initialize_game_center()


## API

### Methods

initialize_game_center()	starts the connection with the GameCenter

is_authenticated()	self-explanatory, returns true or false



