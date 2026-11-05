extends SceneTree
## In-game book contract: real recipes, real inventory, PNG hit mask, no fake axe craft.
const GameplaySession = preload("res://scripts/gameplay_session.gd")
const CraftingBook = preload("res://scripts/crafting_book_ui.gd")
const AxePreview = preload("res://scripts/crafting_axe_preview.gd")
var gameplay: RefCounted
var book: CanvasLayer
var checks := 0

func check(condition: bool, reason: String) -> void:
    checks += 1
    if not condition:
        push_error("TAMU_CRAFT_BOOK_FAILED "+reason)
        quit(33)

func submit(id: String) -> Dictionary:
    return gameplay.begin_craft("book-ci-0001",id)

func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    gameplay = GameplaySession.new()
    book = CraftingBook.new()
    book.setup(gameplay,Callable(self,"submit"))
    root.add_child(book)
    await process_frame
    check(book.verify_contract(),"catalog_recipes")
    check(not book.is_open(),"closed_by_default")
    book.open_book()
    check(book.is_open(),"open_in_game")
    book.active_category = "Araçlar"
    check(book.visible_schema_ids() == ["_axe_draft"],"tool_category")
    book.active_category = "Yapılar"
    check(book.visible_schema_ids().has("core:bench_from_planks"),"structure_category")
    book.active_category = "İşleme"
    check(book.visible_schema_ids().has("core:planks_from_log"),"processing_category")
    book.active_category = "Tümü"
    book.search_query = "tezgâh"
    check(book.visible_schema_ids().has("core:bench_from_planks"),"search_filter")
    book.search_query = ""
    book._open_schema("_axe_draft")
    check(book.active_page == "axe","axe_scene")
    var axe := AxePreview.new()
    root.add_child(axe)
    await process_frame
    check(axe.original != null and axe.mask_image != null,"source_and_mask_embedded")
    check(axe.original.get_width() == 128 and axe.mask_image.get_width() == 192,"asset_dimensions")
    check(axe.role_at_uv(Vector2(0,0)) == "","transparent_hit_rejected")
    var seen := {}
    for y in range(1,40):
        for x in range(1,40):
            var role := axe.role_at_uv(Vector2(float(x)/40.0,float(y)/40.0))
            if role != "":
                seen[role] = true
    check(seen.size() > 0,"mask_region_detected")
    check(book._inventory_materials().is_empty(),"no_invented_inventory")
    check(not gameplay.catalog.recipes.has("_axe_draft"),"axe_not_fake_recipe")
    var draft: Array = gameplay.inventory.preview()
    check(gameplay.inventory.preview_add(draft,"core:wood_log",1),"seed_actual_wood")
    check(gameplay.inventory.commit_preview(draft),"commit_real_wood")
    check(book._inventory_materials().has("core:wood_log"),"real_inventory_candidate")
    book._bind_material("handle","core:wood_log")
    check(book.selections.get("handle","") == "core:wood_log","mask_selection_retained")
    book._open_schema("core:planks_from_log")
    check(book.active_page == "recipe","canonical_recipe_scene")
    book._craft_real_recipe("core:planks_from_log")
    check(not gameplay.active_craft.is_empty(),"real_transaction_started")
    for i in range(6):
        gameplay.tick(0.1,Vector2.ZERO)
    check(gameplay.count_item("core:wood_plank") == 4,"real_output_received")
    check(gameplay.count_item("core:wood_log") == 0,"real_input_debited")
    book.close_book()
    check(not book.is_open(),"close_returns_world")
    print("TAMU_CRAFT_BOOK_OK checks=",checks)
    quit(0)
