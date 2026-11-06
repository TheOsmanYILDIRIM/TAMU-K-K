extends RefCounted
# LÖVE systems/inventory.lua semantics, in-memory until Stage6 durable adapter.
var catalog: RefCounted
var capacity := 12
var slots: Array = []
var applied: Dictionary = {}

func _init(source: RefCounted, size: int = 12) -> void:
    catalog = source
    assert(size >= 1 and size <= 256)
    capacity = size
    slots.resize(size)
    slots.fill(null)

func count_item(id: String) -> int:
    if catalog.max_stack(id) <= 0:
        return 0
    return count_in(slots, id)

static func count_in(records: Array, id: String) -> int:
    var value := 0
    for entry in records:
        if entry is Dictionary and str(entry.get("def_id", "")) == id:
            value += int(entry["count"])
    return value

func preview() -> Array:
    return slots.duplicate(true)

func validate_preview(records: Array) -> bool:
    if records.size() != capacity:
        return false
    for entry in records:
        if entry == null:
            continue
        if not entry is Dictionary:
            return false
        var id := str(entry.get("def_id", ""))
        var n: Variant = entry.get("count", 0)
        if not n is int or int(n) <= 0 or int(n) > catalog.max_stack(id):
            return false
    return true

func commit_preview(records: Array) -> bool:
    if not validate_preview(records):
        return false
    slots = records.duplicate(true)
    return true

func preview_add(records: Array, id: String, quantity: int) -> bool:
    var limit: int = catalog.max_stack(id)
    if records.size() != capacity or limit <= 0 or quantity <= 0:
        return false
    var remaining := quantity
    for i in range(capacity):
        var entry: Variant = records[i]
        if entry is Dictionary and str(entry.get("def_id", "")) == id and int(entry["count"]) < limit:
            var amount := mini(remaining, limit - int(entry["count"]))
            entry["count"] = int(entry["count"]) + amount
            remaining -= amount
            if remaining == 0:
                return true
    for i in range(capacity):
        if records[i] == null:
            var amount := mini(remaining, limit)
            records[i] = {"def_id": id, "count": amount}
            remaining -= amount
            if remaining == 0:
                return true
    return false

func preview_remove(records: Array, id: String, quantity: int) -> bool:
    if records.size() != capacity or catalog.max_stack(id) <= 0 or quantity <= 0 or count_in(records, id) < quantity:
        return false
    var remaining := quantity
    for i in range(capacity - 1, -1, -1):
        var entry: Variant = records[i]
        if entry is Dictionary and str(entry.get("def_id", "")) == id:
            var amount := mini(remaining, int(entry["count"]))
            entry["count"] = int(entry["count"]) - amount
            remaining -= amount
            if int(entry["count"]) == 0:
                records[i] = null
            if remaining == 0:
                return true
    return false

func snapshot() -> Dictionary:
    var records: Array = []
    for i in range(capacity):
        if slots[i] is Dictionary:
            records.append({"slot": i + 1, "def_id": str(slots[i]["def_id"]), "count": int(slots[i]["count"])})
    return {"version": 1, "catalog_version": catalog.version,
        "capacity": capacity, "slots": records}

func can_add(id: String, quantity: int) -> bool:
    return preview_add(preview(), id, quantity)

func credit_harvest(event: Dictionary) -> Dictionary:
    if str(event.get("type", "")) != "HarvestCompleted":
        return {"ok": false, "status": "invalid_event"}
    var transaction_id := str(event.get("transaction_id", ""))
    if transaction_id.is_empty():
        return {"ok": false, "status": "invalid_transaction"}
    if applied.has(transaction_id):
        return {"ok": false, "status": "duplicate"}
    var staged := preview()
    if not preview_add(staged, str(event.get("item_id", "")), int(event.get("amount", 0))):
        return {"ok": false, "status": "inventory_full"}
    if not commit_preview(staged):
        return {"ok": false, "status": "invalid_preview"}
    applied[transaction_id] = true
    return {"ok": true, "status": "credited"}

# Runtime slot operations: no save schema migration. These accept only the
# existing v1 stack shape. Stateful/unstackable instance metadata needs its
# own versioned save migration before being enabled.
static func _plain_stack(entry: Dictionary) -> bool:
    return entry.size() == 2 and entry.has("def_id") and entry.has("count")

func move_stack(from_slot: int, to_slot: int, quantity: int) -> Dictionary:
    if from_slot < 0 or from_slot >= capacity or to_slot < 0 or to_slot >= capacity or from_slot == to_slot:
        return {"ok": false, "status": "invalid_slot"}
    if quantity <= 0:
        return {"ok": false, "status": "invalid_quantity"}
    var staged: Array = preview()
    if not validate_preview(staged):
        return {"ok": false, "status": "invalid_inventory"}
    var source: Variant = staged[from_slot]
    if not source is Dictionary or not _plain_stack(source):
        return {"ok": false, "status": "invalid_source"}
    if quantity > int(source["count"]):
        return {"ok": false, "status": "insufficient_items"}
    var target: Variant = staged[to_slot]
    if target == null:
        staged[to_slot] = {"def_id": source["def_id"], "count": quantity}
    elif target is Dictionary:
        if not _plain_stack(target):
            return {"ok": false, "status": "unsupported_instance_state"}
        if str(target["def_id"]) != str(source["def_id"]):
            return {"ok": false, "status": "incompatible_stack"}
        var available: int = catalog.max_stack(str(source["def_id"])) - int(target["count"])
        if quantity > available:
            return {"ok": false, "status": "stack_full"}
        target["count"] = int(target["count"]) + quantity
    else:
        return {"ok": false, "status": "invalid_target"}
    source["count"] = int(source["count"]) - quantity
    if int(source["count"]) == 0:
        staged[from_slot] = null
    if not commit_preview(staged):
        return {"ok": false, "status": "invalid_preview"}
    return {"ok": true, "status": "moved", "quantity": quantity}
