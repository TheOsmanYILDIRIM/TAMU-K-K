extends Resource
# A trusted, prevalidated content package. External user mods MUST be parsed
# as data, never loaded as arbitrary GDScript-bearing .res/.pck resources.
@export var schema_version: int = 1
@export var pack_namespace: String = ""
@export var catalog_version: int = 1
@export var source_hashes: Dictionary = {}
@export var definitions: Array[Resource] = []
@export var recipes: Array[Resource] = []
