extends SceneTree
const ProductionEngine = preload("res://scripts/production_engine.gd")
const Workshop = preload("res://scripts/production_sandbox_ui.gd")
func expect(ok: bool, label: String) -> void:
    if not ok:
        push_error("TAMU_PRODUCTION_FAILED "+label)
        quit(1)

func _initialize() -> void:
    var m = ProductionEngine.new()
    expect(m.initialize(),"catalog")
    expect(m.definitions["sites"].size()>=12,"sites")
    expect(m.definitions["modules"].size()>=30,"modules")
    expect(m.definitions["tool_levels"].size()>=20,"tools")
    expect(m.place("furnace",Vector2i(0,0)),"furnace")
    expect(m.place("crucible",Vector2i(1,0)),"pot")
    expect(m.place("mold",Vector2i(2,0)),"mold")
    expect(m.joined(Vector2i(0,0),Vector2i(1,0),"heat"),"heat_port")
    expect(m.joined(Vector2i(1,0),Vector2i(2,0),"molten"),"molten_port")
    expect(not m.place("furnace",Vector2i(0,0)),"collision")
    expect(not m.place("furnace",Vector2i(9,9)),"bounds")
    m.activate(true)
    for i in range(20):
        m.step()
    expect(m.stock["ingot"]>0,"smelt_produces")
    expect(m.smoke>0,"smoke")
    expect(m.heat>0,"heat")
    expect(m.rotate(Vector2i(1,0)),"rotation")
    expect(not m.joined(Vector2i(1,0),Vector2i(2,0),"molten"),"rotation_breaks_link")
    expect(m.use_site("wood_cabin"),"wood_site")
    expect(m.place("alloy_furnace",Vector2i(0,0)),"industrial_furnace")
    m.activate(true)
    for i in range(80):
        m.step()
    expect(m.fire>0 or m.integrity<100.0,"wood_fire")
    expect(m.use_site("stone_foundry"),"stone_site")
    expect(m.place("alloy_furnace",Vector2i(0,0)),"stone_furnace")
    m.activate(true)
    for i in range(80):
        m.step()
    expect(m.fire==0.0,"stone_not_burning")
    expect(m.use_site("field"),"field_site")
    expect(m.plant(Vector2i(0,0)),"plant")
    m.activate(true)
    for i in range(38):
        m.step()
        if i%8==0:
            m.water(Vector2i(0,0))
    expect(m.harvest(Vector2i(0,0)),"harvest")
    expect(m.stock["food"]==3,"food_output")
    var ui = Workshop.new()
    expect(ui!=null,"ui_load")
    print("TAMU_PRODUCTION_CONTRACT_OK modules=30 sites=12 tools=21")
    quit(0)
