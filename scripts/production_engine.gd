extends RefCounted
## Ephemeral production/farming simulation. Never writes Stage5 or Stage6.
const CATALOG := "res://data/catalog/production_sandbox.v1.json"
const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const SIDES := ["N","E","S","W"]
var definitions: Dictionary = {}
var site_id := "wood_cabin"
var remembered_sites: Dictionary = {}
var machines: Dictionary = {}
var crops: Dictionary = {}
var stock := {"fuel":45,"ore":30,"wood":25,"stone":25,"water":35,"seed":15,"ingot":0,"food":0,"plank":0,"gravel":0,"charcoal":0,"formed":0,"powder":0}
var running := false
var time_left := 0.0
var ticks := 0
var heat := 0.0
var smoke := 0.0
var fire := 0.0
var dust := 0.0
var pressure := 0.0
var integrity := 100.0
var exposure := 0.0
var message := "Bir modül yerleştir veya tarla ek."

func initialize() -> bool:
    if not FileAccess.file_exists(CATALOG):
        return false
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
    if not value is Dictionary or value.get("schema_version",0) != 1:
        return false
    for key in ["sites","modules","tool_levels","crops","interaction_families"]:
        if not value.get(key,null) is Dictionary:
            return false
    definitions = value
    return true

func site() -> Dictionary:
    return definitions.get("sites",{}).get(site_id,{})

func extent() -> Vector2i:
    var dims: Array = site().get("size",[3,3])
    return Vector2i(int(dims[0]),int(dims[1]))

func inside(p: Vector2i) -> bool:
    var e := extent()
    return p.x>=0 and p.y>=0 and p.x<e.x and p.y<e.y

func key(p: Vector2i) -> String:
    return "%d:%d" % [p.x,p.y]

func use_site(value: String) -> bool:
    if not definitions["sites"].has(value):
        return false
    if value == site_id:
        return true
    remembered_sites[site_id] = {"machines": machines.duplicate(true), "crops": crops.duplicate(true),
        "heat": heat, "smoke": smoke, "fire": fire, "dust": dust, "pressure": pressure,
        "integrity": integrity, "exposure": exposure}
    site_id = value
    var old: Dictionary = remembered_sites.get(value,{})
    machines = old.get("machines",{}).duplicate(true)
    crops = old.get("crops",{}).duplicate(true)
    running = false
    time_left = 0.0
    heat = float(old.get("heat",0.0))
    smoke = float(old.get("smoke",0.0))
    fire = float(old.get("fire",0.0))
    dust = float(old.get("dust",0.0))
    pressure = float(old.get("pressure",0.0))
    integrity = float(old.get("integrity",100.0))
    exposure = float(old.get("exposure",0.0))
    message = "Alan değiştirildi; önceki düzenler korunuyor."
    return true

func place(kind: String, p: Vector2i) -> bool:
    if not inside(p) or machines.has(key(p)) or crops.has(key(p)):
        return false
    if not definitions["modules"].has(kind):
        return false
    machines[key(p)] = {"kind":kind,"rotation":0}
    message = "Yerleştirildi: "+str(definitions["modules"][kind]["label"])
    return true

func remove(p: Vector2i) -> bool:
    if not machines.has(key(p)):
        return false
    machines.erase(key(p))
    return true

func rotate(p: Vector2i) -> bool:
    if not machines.has(key(p)):
        return false
    machines[key(p)]["rotation"] = (int(machines[key(p)]["rotation"])+1)%4
    return true

func at(p: Vector2i) -> Dictionary:
    return machines.get(key(p),{})

func has_socket(m: Dictionary, side: int, mode: String, flow: String) -> bool:
    if m.is_empty():
        return false
    var data: Dictionary = definitions["modules"][m["kind"]]
    var direction: int = posmod(side-int(m["rotation"]),4)
    for socket_data in data.get("ports",{}).get(SIDES[direction],[]):
        if socket_data.get("mode","")==mode and socket_data.get("flow","")==flow:
            return true
    return false

func joined(a: Vector2i,b: Vector2i,flow: String) -> bool:
    var side: int = DIRECTIONS.find(b-a)
    return side>=0 and has_socket(at(a),side,"out",flow) and has_socket(at(b),(side+2)%4,"in",flow)

func connects(p: Vector2i,kind: String,flow: String) -> bool:
    for dir in DIRECTIONS:
        if str(at(p+dir).get("kind",""))==kind and joined(p,p+dir,flow):
            return true
    return false

func feeds(p: Vector2i,kind: String,flow: String) -> bool:
    for dir in DIRECTIONS:
        if str(at(p+dir).get("kind",""))==kind and joined(p+dir,p,flow):
            return true
    return false

func nearby(p: Vector2i,kind: String) -> bool:
    for dir in DIRECTIONS:
        if str(at(p+dir).get("kind",""))==kind:
            return true
    return false

func supplied_by(target: Vector2i, source: String, flow: String) -> bool:
    if at(target).is_empty():
        return false
    var frontier: Array[Vector2i] = []
    var visited: Dictionary = {}
    for raw in machines:
        if machines[raw]["kind"] != source:
            continue
        var parts: PackedStringArray = str(raw).split(":")
        var p := Vector2i(int(parts[0]),int(parts[1]))
        frontier.append(p)
        visited[key(p)] = true
    var cursor := 0
    while cursor < frontier.size():
        var current: Vector2i = frontier[cursor]
        cursor += 1
        if current == target:
            return true
        for offset in DIRECTIONS:
            var next: Vector2i = current + offset
            if not visited.has(key(next)) and joined(current,next,flow):
                visited[key(next)] = true
                frontier.append(next)
    return false

func network_edges() -> int:
    var count := 0
    for raw in machines:
        var pair: PackedStringArray = str(raw).split(":")
        var point := Vector2i(int(pair[0]),int(pair[1]))
        for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
            for flow in ["heat","air","molten","exhaust","water","electric","steam","material"]:
                if joined(point,point+direction,flow):
                    count += 1
    return count

func count_machine(kind: String) -> int:
    var n := 0
    for entry in machines.values():
        if entry["kind"]==kind:
            n += 1
    return n

func activate(yes: bool) -> void:
    running = yes and integrity>0.0

func extinguish() -> bool:
    if stock["water"]<=0 or (fire<=0.0 and heat<8.0):
        return false
    stock["water"]-=1
    running=false
    fire=maxf(0.0,fire-28.0)
    heat=maxf(0.0,heat-22.0)
    smoke=maxf(0.0,smoke-8.0)
    message="Yangına suyla müdahale edildi."
    return true

func repair() -> bool:
    if running or integrity>=100.0 or stock["wood"]<=0 or stock["stone"]<=0:
        return false
    stock["wood"]-=1
    stock["stone"]-=1
    integrity=minf(100.0,integrity+16.0)
    message="Yapı onarıldı. Odun ve taş harcandı."
    return true

func advance(delta: float) -> void:
    if not is_finite(delta) or delta<=0.0:
        return
    time_left += clampf(delta,0.0,1.0)
    var loops := 0
    while time_left>=1.0 and loops<3:
        time_left-=1.0
        step()
        loops+=1

func step() -> void:
    if not running or integrity<=0:
        heat*=0.82
        smoke*=0.70
        dust*=0.65
        pressure*=0.65
        fire=maxf(0.0,fire-0.5)
        if fire>20.0:
            integrity=maxf(0.0,integrity-fire*0.016)
        return
    ticks += 1
    var features: Array = site().get("tags",[])
    var outside: bool = features.has("open_air")
    var ventilated: bool = outside or features.has("ventilated")
    var source_heat := 0.0
    var source_smoke := 0.0
    var source_dust := 0.0
    var source_pressure := 0.0
    var source_shake := 0.0
    for raw in machines:
        var module: Dictionary = machines[raw]
        var kind: String = str(module["kind"])
        var part: Dictionary = definitions["modules"][kind]
        var action: String = str(part["action"])
        var effects: Dictionary = part.get("effects",{})
        if action in ["heat","charcoal","forge","warm","pressure"] and stock["fuel"]>0:
            source_heat+=float(effects.get("heat",0.0))
            var exhaust: float = float(effects.get("smoke",0.0))
            if connects(Vector2i(int(str(raw).split(":")[0]),int(str(raw).split(":")[1])),"vent","exhaust"):
                exhaust*=0.20
            source_smoke+=exhaust
            var pressure_out: float = float(effects.get("pressure",0.0))
            if connects(Vector2i(int(str(raw).split(":")[0]),int(str(raw).split(":")[1])),"valve","steam"):
                pressure_out*=0.20
            source_pressure+=pressure_out
            if ticks%4==0:
                stock["fuel"]-=1
            if action=="charcoal" and ticks%6==0 and stock["wood"]>0:
                stock["wood"]-=1
                stock["charcoal"]+=1
            if action=="forge" and ticks%6==0 and stock["ingot"]>0:
                stock["ingot"]-=1
                stock["formed"]+=1
        if action in ["cut","crush","grind","press"]:
            var raw_point: PackedStringArray = str(raw).split(":")
            var location := Vector2i(int(raw_point[0]),int(raw_point[1]))
            source_dust+=float(effects.get("dust",0.0))*(0.35 if nearby(location,"filter") else 1.0)
            source_shake+=float(effects.get("vibration",0.0))
            if ticks%5==0 and action=="cut" and stock["wood"]>0:
                stock["wood"]-=1
                stock["plank"]+=2
            if ticks%5==0 and action=="crush" and stock["stone"]>0:
                stock["stone"]-=1
                stock["gravel"]+=2
            if ticks%5==0 and action=="grind" and stock["gravel"]>0:
                stock["gravel"]-=1
                stock["powder"]+=2
            if ticks%5==0 and action=="press" and stock["ingot"]>0:
                stock["ingot"]-=1
                stock["formed"]+=1
        if action=="heat" and stock["fuel"]>0:
            var parts: PackedStringArray = str(raw).split(":")
            var furnace := Vector2i(int(parts[0]),int(parts[1]))
            var is_boosted: bool = feeds(furnace,"bellows","air")
            if is_boosted:
                source_heat+=3.0
            if nearby(furnace,"cooler"):
                source_heat=maxf(0.0,source_heat-3.0)
            if ticks%(3 if is_boosted else 4)==0:
                var connected_mold := false
                for d in DIRECTIONS:
                    var pot: Vector2i = furnace+d
                    if at(pot).get("kind","")=="crucible" and joined(furnace,pot,"heat") and connects(pot,"mold","molten"):
                        connected_mold=true
                        break
                if connected_mold and stock["ore"]>0:
                    stock["ore"]-=1
                    stock["ingot"]+=1
                    message="Döküm tamamlandı: +1 demo külçe."
                elif not connected_mold:
                    message="Pota ve kalıp bağlanmadan cevher tüketilmez."
    if features.has("cultivation") and ticks%4==0:
        for raw in machines:
            if machines[raw]["kind"]!="sprinkler":
                continue
            var coords: PackedStringArray = str(raw).split(":")
            var sprinkler := Vector2i(int(coords[0]),int(coords[1]))
            if not supplied_by(sprinkler,"pump","water"):
                continue
            for dir in DIRECTIONS:
                var target_key: String = key(sprinkler+dir)
                if crops.has(target_key) and stock["water"]>0 and float(crops[target_key]["water"])<12.0:
                    stock["water"]-=1
                    crops[target_key]["water"]=minf(20.0,float(crops[target_key]["water"])+8.0)
                    message="Bağlı sulama hattı çalıştı."

    heat=clampf(heat*(0.55 if outside else 0.85)+source_heat,0,100)
    smoke=clampf(smoke*(0.35 if ventilated else 0.90)+source_smoke,0,100)
    dust=clampf(dust*(0.48 if ventilated else 0.80)+source_dust,0,100)
    pressure=clampf(pressure*0.6+source_pressure,0,100)
    if features.has("flammable") and heat>38:
        fire=clampf(fire+(heat-38)*0.08,0,100)
    else:
        fire=maxf(0,fire-0.5)
    if fire>20:
        integrity=maxf(0,integrity-fire*0.016)
    if not features.has("heavy_support") and source_shake>4:
        integrity=maxf(0,integrity-source_shake*0.014)
    if pressure>70 and count_machine("valve")==0:
        integrity=maxf(0,integrity-0.8)
    exposure=clampf(exposure+(smoke-28)*0.014 if smoke>28 else exposure-0.8,0,100)
    for crop in crops.values():
        if crop["water"]>0:
            crop["growth"]+=1.0
            crop["water"]=maxf(0,float(crop["water"])-0.6)
        if crop["growth"]>=definitions["crops"][crop["kind"]]["growth_seconds"]:
            crop["ripe"]=true
    if integrity<=0:
        running=false
        message="YAPI HASAR NEDENİYLE ÇÖKTÜ. Yalnız demo!"
    elif fire>30:
        message="YANGIN TEHLİKESİ: Aşırı sıcaklık."
    elif smoke>40:
        message="DUMAN: Yetersiz havalandırma."

func plant(p: Vector2i, crop_id: String = "grain") -> bool:
    if not definitions["crops"].has(crop_id):
        return false
    if not site().get("tags",[]).has("cultivation") or not inside(p) or stock["seed"]<=0:
        return false
    if crops.has(key(p)) or machines.has(key(p)):
        return false
    stock["seed"]-=1
    crops[key(p)]={"kind":crop_id,"water":4.0,"growth":0.0,"ripe":false}
    return true

func water(p: Vector2i) -> bool:
    if not crops.has(key(p)) or stock["water"]<=0:
        return false
    stock["water"]-=1
    crops[key(p)]["water"]=minf(20,float(crops[key(p)]["water"])+8.0)
    return true

func harvest(p: Vector2i) -> bool:
    if not crops.has(key(p)) or not crops[key(p)]["ripe"]:
        return false
    crops.erase(key(p))
    stock["food"]+=3
    return true

func summary() -> String:
    return "%s • %dx%d • Makine %d • Bağ %d\nIsı %.0f | Duman %.0f | Toz %.0f | Basınç %.0f\nYangın %.0f | Bina %.0f%% | Maruziyet %.0f\nYakıt %d | Cevher %d | Külçe %d | Tahta %d | Ürün %d\n%s" % [
        site().get("label",site_id),extent().x,extent().y,machines.size(),network_edges(),
        heat,smoke,dust,pressure,fire,integrity,exposure,stock["fuel"],stock["ore"],
        stock["ingot"],stock["plank"],stock["food"],message]
