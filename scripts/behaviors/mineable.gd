class_name Mineable
extends Object
## Kazma davranışı — tüm kazılabilir objelerde TEK kod kaynağı.
## Kural verisi BlockDef'ten (hardness, tool_type), araç bilgisi ItemDef'ten okunur.


static func break_time(def: BlockDef, tool: ItemDef) -> float:
	## Bloğu kırmanın süresini (saniye) döndürür. Kırılamaz -> INF.
	if def == null or def.hardness <= 0.0:
		return INF
	var mult := 1.0
	if tool != null and tool.tool_type != &"none" and tool.tool_type == def.tool_type:
		mult = maxf(tool.tool_power, 0.1)
	return def.hardness / mult


static func can_harvest(def: BlockDef, tool: ItemDef) -> bool:
	## MVP: her tool kırabilir (drop kuralı DropRule'da). İleride tier eklenecek.
	return def != null and def.hardness > 0.0
