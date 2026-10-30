extends Resource
class_name Slotdata

const MAX_STACK_SIZE: int = 99

@export var item_data: Itemdata
@export_range(1,MAX_STACK_SIZE) var quantity: int = 1
## Casilla de arriba a la izquierda que ocupa en la grilla del inventario.
@export var grid_pos: Vector2i = Vector2i.ZERO
