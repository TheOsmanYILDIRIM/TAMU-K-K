extends SceneTree
## Main branch native UI regression, no fake inventory except isolated fixtures.
const Gameplay = preload("res://scripts/gameplay_session.gd")
const Book = preload("res://scripts/crafting_book_ui.gd")
const Axe = preload("res://scripts/crafting_axe_preview.gd")
var domain: RefCounted
var view: CanvasLayer
var checks := 0
var failed := false

func assert_ui(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failed = true
        push_error("TAMU_CRAFT_MAIN_UI_FAILED "+label)

func submit(id: String) -> Dictionary:
    return domain.begin_craft("ui-ci-craft-01",id)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    domain = Gameplay.new()
    view = Book.new()
    view.setup(domain,Callable(self,"submit"))
    root.add_child(view)
    await process_frame
    assert_ui(view.verify_contract(),"initial_contract")
    assert_ui(not view.is_open(),"initially_closed")
    view.open_library()
    await process_frame
    assert_ui(view.is_open(),"open_via_codex")
    assert_ui(view.close_button.visible,"close_visible")
    var close_rect := view.close_button.get_global_rect()
    assert_ui(close_rect.size.x >= 72.0 and close_rect.size.y >= 72.0,"touch_target_72px")
    var window_rect := Rect2(Vector2.ZERO,root.size)
    assert_ui(window_rect.encloses(close_rect),"close_inside_viewport")
    assert_ui(view.close_button.get_parent() == view.root_panel,"close_not_inside_scroll")
    assert_ui(view.close_button.z_index > view.material_drawer.z_index,"close_always_on_top")
    view.selected_category = "Araçlar"
    assert_ui(view.schema_ids() == ["_axe_prototype"],"tools_filter")
    view.selected_category = "Yapılar"
    assert_ui(view.schema_ids().has("core:bench_from_planks"),"building_category")
    view.selected_category = "İşleme"
    assert_ui(view.schema_ids().has("core:planks_from_log"),"processing_category")
    view.selected_category = "Tümü"
    view._render_library()
    var old_input: LineEdit = view.search_box
    old_input.text = "Tahta"
    old_input.text_changed.emit("Tahta")
    assert_ui(old_input == view.search_box and view.schema_ids().has("core:planks_from_log"),"search_focus_stable")
    view.search_text = ""
    view._open_schema("_axe_prototype")
    await process_frame
    assert_ui(view.current_page == "axe","axe_open")
    assert_ui(view.axe_visual != null and view.axe_visual.texture != null,"axe_image_visible")
    assert_ui(view.axe_visual.get_child_count() >= 6,"labels_on_image")
    assert_ui(not domain.catalog.recipes.has("_axe_prototype"),"axe_not_fabricated")
    var mask := Axe.new()
    root.add_child(mask)
    await process_frame
    assert_ui(mask.original != null and mask.mask_image != null,"mask_loaded")
    assert_ui(mask.original.get_width() == 128 and mask.mask_image.get_width() == 192,"mask_dimensions")
    assert_ui(mask.role_at_uv(Vector2(0,0)) == "","transparent_mask_ignored")
    assert_ui(view._inventory_material_ids().is_empty(),"no_fake_inventory")
    var staged: Array = domain.inventory.preview()
    assert_ui(domain.inventory.preview_add(staged,"core:wood_log",1),"seed_real_log")
    assert_ui(domain.inventory.commit_preview(staged),"commit_real_inventory_fixture")
    assert_ui(view._inventory_material_ids().has("core:wood_log"),"inventory_material_available")
    view._open_drawer("handle")
    await process_frame
    assert_ui(view.material_drawer.visible,"material_drawer_open")
    assert_ui(view.close_button.get_global_rect().size.x >= 72.0,"close_still_accessible_with_drawer")
    view._select_material("handle","core:wood_log")
    assert_ui(view.role_materials.get("handle","") == "core:wood_log","material_saved")
    view.go_back()
    assert_ui(view.current_page == "library","back_to_library")
    view.open_inventory()
    assert_ui(view.current_page == "inventory","bag_uses_real_slots")
    view.open_library()
    view._open_schema("core:planks_from_log")
    assert_ui(view.current_page == "recipe","recipe_view")
    view._craft_recipe("core:planks_from_log")
    assert_ui(not domain.active_craft.is_empty(),"real_craft_started")
    for i in range(6):
        domain.tick(0.1,Vector2.ZERO)
    assert_ui(domain.count_item("core:wood_log") == 0,"real_log_debit")
    assert_ui(domain.count_item("core:wood_plank") == 4,"real_planks_credit")
    view.close_button.pressed.emit()
    assert_ui(not view.is_open(),"close_wired")
    view.open_library()
    view._open_schema("_axe_prototype")
    if OS.get_environment("TAMU_UI_CAPTURE") == "1":
        await process_frame
        await RenderingServer.frame_post_draw
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
        # On this UI-only test the running viewport still uses project portrait dimensions.
        view.open_library()
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://screenshots/book-library.png")
        view._open_schema("_axe_prototype")
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://screenshots/book-axe.png")
    if failed:
        quit(41)
    else:
        print("TAMU_CRAFT_MAIN_UI_OK checks=",checks)
        quit(0)
