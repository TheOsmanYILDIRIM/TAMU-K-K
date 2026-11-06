extends RefCounted
const CATALOG := "res://data/catalog/production_sandbox.v1.json"
var definitions: Dictionary = {}
func initialize() -> bool:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
    if not data is Dictionary or data.get("schema_version",0) != 1:
        return false
    definitions = data
    return true
