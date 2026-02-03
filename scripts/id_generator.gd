extends Node

##
# Simple global ID generator.  Generates monotonically increasing integer IDs.

class_name IDGenerator

var _next_id: int = 1

static func next_id() -> int:
    var id := _next_id
    _next_id += 1
    return id
