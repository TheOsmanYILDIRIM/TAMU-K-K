extends RefCounted
# Stage 6 transaction boundary contract, ported from LÖVE save/transaction.lua.
# This adapter is intentionally UNWIRED to production without a verified store.
# In-memory domain commits are not crash durable; never pretend otherwise.
static func valid_command(command_id: String) -> bool:
    return not command_id.is_empty() and command_id.length() <= 128

static func valid_stage(before: Dictionary, candidate: Dictionary, command_id: String) -> bool:
    if not valid_command(command_id):
        return false
    if int(candidate.get("world_revision", -1)) != int(before.get("world_revision", -1)) + 1:
        return false
    if int(candidate.get("journal_sequence", -1)) != int(before.get("journal_sequence", -1)) + 1:
        return false
    var commands: Variant = candidate.get("applied_commands", null)
    return commands is Dictionary and bool(commands.get(command_id, false))

static func run(command_id: String, previous: Dictionary, meta: Dictionary,
        stage: Callable, commit: Callable, publish: Callable) -> Dictionary:
    if not valid_command(command_id):
        return {"ok": false, "status": "invalid_command"}
    if str(meta.get("status", "")) != "ok" or bool(meta.get("read_only", true)) or previous.is_empty():
        return {"ok": false, "status": "no_writable_checkpoint"}
    if not previous.get("applied_commands", null) is Dictionary:
        return {"ok": false, "status": "invalid_checkpoint"}
    if previous["applied_commands"].has(command_id):
        return {"ok": false, "status": "duplicate"}
    if not stage.is_valid() or not commit.is_valid() or not publish.is_valid():
        return {"ok": false, "status": "missing_transaction_port"}
    # A detached tree; changes here must not mutate the current published domain.
    var candidate: Dictionary = previous.duplicate(true)
    var accepted: Variant = stage.call(candidate, previous, command_id)
    if accepted != true:
        return {"ok": false, "status": "rejected"}
    if not valid_stage(previous, candidate, command_id):
        return {"ok": false, "status": "invalid_staged_revision"}
    var committed: Variant = commit.call(candidate)
    if committed != true:
        return {"ok": false, "status": "commit_failed"}
    # Publish only AFTER the store confirms the new durable checkpoint.
    var published: Variant = publish.call(candidate)
    if published != true:
        return {"ok": false, "status": "committed_reload_required"}
    return {"ok": true, "status": "committed"}

static func test_stage(candidate: Dictionary, _before: Dictionary, command_id: String) -> bool:
    candidate["world_revision"] = int(candidate["world_revision"]) + 1
    candidate["journal_sequence"] = int(candidate["journal_sequence"]) + 1
    candidate["applied_commands"][command_id] = true
    return true

static func test_accept(_candidate: Dictionary) -> bool:
    return true

static func test_reject(_candidate: Dictionary) -> bool:
    return false

static func verify_contract() -> bool:
    var state := {"world_revision": 4, "journal_sequence": 6, "applied_commands": {}}
    var valid := {"status": "ok", "read_only": false}
    var stage := Callable(load("res://scripts/domain_transaction.gd"), "test_stage")
    var accept := Callable(load("res://scripts/domain_transaction.gd"), "test_accept")
    var reject := Callable(load("res://scripts/domain_transaction.gd"), "test_reject")
    var failed := run("tx:1", state, valid, stage, reject, accept)
    if str(failed["status"]) != "commit_failed" or int(state["world_revision"]) != 4:
        return false
    var accepted := run("tx:1", state, valid, stage, accept, accept)
    if not bool(accepted["ok"]) or int(state["world_revision"]) != 4:
        return false
    if run("tx:1", state, {"status": "ok", "read_only": true}, stage, accept, accept).get("status") != "no_writable_checkpoint":
        return false
    if run("tx:1", state, valid, stage, accept, reject).get("status") != "committed_reload_required":
        return false
    print("TAMU_TRANSACTION_BOUNDARY_OK staged_revision=true publish_after_commit=true crash_durability=false")
    return true
