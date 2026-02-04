extends Node

##
# Simple global ID generator.  Generates monotonically increasing integer IDs.

class_name IDGenerator

static var _next_id: int = 1

static func next_id() -> int:
    var id: int = _next_id
    _next_id += 1
    return id

static func sync_next_id(max_id: int) -> void:
    _next_id = max(_next_id, max_id + 1)
