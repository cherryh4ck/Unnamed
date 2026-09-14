extends Resource
class_name Slotdata

const MAX_STACK_SIZE: int = 99

@export var item_data: Itemdata
@export_range(1,MAX_STACK_SIZE) var quantity: int = 1
