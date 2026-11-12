extends RefCounted
# Approximate physical solar elevation (39N, equinox), render-only.
# Solar cast fades to ZERO near/below horizon; never morphs into a night cast.
# The always-on soft night footprint lives in the batched contact AO layer.
const WorldProjection = preload("res://scripts/world_projection.gd")
const LATITUDE_DEGREES := 39.0
const DECLINATION_DEGREES := 0.0

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
    var sun_cast := -WorldProjection.to_screen(Vector2(east, north)).normalized()
    var horizontal := sqrt(maxf(0.0, 1.0 - sine_altitude * sine_altitude))
    # Never shorten the sunset shadow into a moon shadow. Hold a finite,
    # bounded cast length and progressively remove its opacity.
    var sun_length := clampf(0.71 * horizontal / maxf(0.22, sine_altitude), 0.55, 2.45)
    var twilight := smoothstep(0.0, 0.18, maxf(0.0, sine_altitude))
    var solar_opacity := (0.18 + 0.17 * daylight) * twilight
    var moon_ao := 1.0 - smoothstep(0.0, 0.09, maxf(0.0, sine_altitude))
    return {
        "altitude_deg": altitude_degrees,
        "light": daylight,
        "cast_direction": sun_cast,
        "cast_length": sun_length,
        "cast_opacity": solar_opacity,
        "moon_ao": moon_ao
    }

static func verify_contract() -> bool:
    var dawn := sample(6.0)
    var noon := sample(12.0)
    var dusk := sample(18.0)
    var night := sample(0.0)
    var early := sample(9.0)
    var late := sample(15.0)
    var near_dusk := sample(17.75)
    if absf(float(noon["altitude_deg"]) - 51.0) > 0.01:
        return false
    if float(noon["altitude_deg"]) >= 75.0 or float(early["altitude_deg"]) >= float(noon["altitude_deg"]):
        return false
    if absf(float(early["altitude_deg"]) - float(late["altitude_deg"])) > 0.01:
        return false
    if float(dawn["light"]) > 0.001 or float(dusk["light"]) > 0.001 or float(night["light"]) > 0.001:
        return false
    if float(noon["cast_length"]) < 0.55 or float(noon["cast_opacity"]) < 0.25:
        return false
    if float(near_dusk["cast_opacity"]) >= float(late["cast_opacity"]) or float(near_dusk["cast_opacity"]) < 0.0:
        return false
    if absf(float(near_dusk["cast_length"]) - float(dusk["cast_length"])) > 0.01:
        return false
    if float(dusk["cast_opacity"]) > 0.0001 or float(night["cast_opacity"]) > 0.0001:
        return false
    if float(night["moon_ao"]) < 0.99 or float(noon["moon_ao"]) > 0.01:
        return false
    for t in [dawn, noon, dusk, night, early, late, near_dusk]:
        var direction: Vector2 = t["cast_direction"]
        if not is_finite(direction.x) or not is_finite(direction.y) or absf(direction.length() - 1.0) > 0.01:
            return false
    return true
