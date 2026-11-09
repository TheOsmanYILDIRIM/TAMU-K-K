extends RefCounted
# TAMU 2.5D solar projection. Equinox at an illustrative mid-northern latitude.
# Source-world +X is east and +Y is north for solar purposes; game world IDs
# and its fixed 45-degree rendering projection are never changed.
const WorldProjection = preload("res://scripts/world_projection.gd")
const LATITUDE_DEGREES := 39.0
const DECLINATION_DEGREES := 0.0
const MOON_CAST_DIRECTION := Vector2(-0.58, 0.815)

static func sample(hour: float) -> Dictionary:
    var latitude := deg_to_rad(LATITUDE_DEGREES)
    var declination := deg_to_rad(DECLINATION_DEGREES)
    var hour_angle := deg_to_rad((fposmod(hour, 24.0) - 12.0) * 15.0)
    var east := -cos(declination) * sin(hour_angle)
    var north := cos(latitude) * sin(declination) - sin(latitude) * cos(declination) * cos(hour_angle)
    var sine_altitude := clampf(sin(latitude) * sin(declination)
        + cos(latitude) * cos(declination) * cos(hour_angle), -1.0, 1.0)
    var altitude_degrees := rad_to_deg(asin(sine_altitude))
    var daylight := clampf(sine_altitude / cos(latitude - declination), 0.0, 1.0)
    var day_weight := smoothstep(0.015, 0.18, sine_altitude)
    var sun_cast := -WorldProjection.to_screen(Vector2(east, north)).normalized()
    var moon_cast := MOON_CAST_DIRECTION.normalized()
    var blended := moon_cast.lerp(sun_cast, day_weight)
    var cast_direction := (sun_cast if day_weight >= 0.5 else moon_cast) if blended.length_squared() < 0.0001 else blended.normalized()
    # Finite noon shadow, bounded sunrise length. The crown has its own depth.
    var horizontal := sqrt(maxf(0.0, 1.0 - sine_altitude * sine_altitude))
    var sun_length := clampf(0.74 * horizontal / maxf(0.16, sine_altitude), 0.52, 2.6)
    return {
        "altitude_deg": altitude_degrees,
        "light": daylight,
        "cast_direction": cast_direction,
        "cast_length": lerpf(0.82, sun_length, day_weight),
        "cast_opacity": lerpf(0.10, 0.18 + 0.18 * daylight, day_weight)
    }

static func verify_contract() -> bool:
    var dawn := sample(6.0)
    var noon := sample(12.0)
    var dusk := sample(18.0)
    var night := sample(0.0)
    var early := sample(9.0)
    var late := sample(15.0)
    if absf(float(noon["altitude_deg"]) - 51.0) > 0.01:
        return false
    if float(noon["altitude_deg"]) >= 75.0 or float(early["altitude_deg"]) >= float(noon["altitude_deg"]):
        return false
    if absf(float(early["altitude_deg"]) - float(late["altitude_deg"])) > 0.01:
        return false
    if float(dawn["light"]) > 0.001 or float(dusk["light"]) > 0.001 or float(night["light"]) > 0.001:
        return false
    if float(noon["cast_length"]) < 0.52 or float(night["cast_opacity"]) < 0.09:
        return false
    for t in [dawn, noon, dusk, night, early, late]:
        var direction: Vector2 = t["cast_direction"]
        if not is_finite(direction.x) or not is_finite(direction.y) or absf(direction.length() - 1.0) > 0.01:
            return false
    return true
