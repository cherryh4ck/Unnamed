extends Resource

class_name Itemdata

enum ItemType { GENERIC, MELEE_WEAPON, SPECIAL }

@export var name: String = ""
@export_multiline var description: String = ""
@export var stackable: bool = false
@export var item_type: ItemType = ItemType.GENERIC
@export var texture: Texture2D
@export var model_3d: PackedScene


func get_display_name() -> String:
	if name.is_empty():
		return "objeto desconocido"
	return name
