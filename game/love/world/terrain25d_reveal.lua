-- GPU-only 3px creation pixels. Pixels appear as an expanding magic wave;
-- never a slow full-surface alpha fade or CPU particle storm.
local Reveal={}
Reveal.shader=[[
extern number radial;
extern number waveFront;
extern vec2 waveOrigin;

number shimmer_hash(vec2 p) {
    // Quasi-random 3px creation cells without a per-fragment sin() call.
    vec2 cell=floor(p / 3.0);
    return fract(cell.x*0.754877666 + cell.y*0.569840296);
}
vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screenCoords) {
    vec4 pixel=Texel(texture,uv);
    number d=distance(screenCoords,waveOrigin);
    number cover=clamp(color.a,0.0,1.0);
    if(radial>0.5) {
        cover=clamp((waveFront-d+14.0)/28.0,0.0,1.0);
    }
    if(shimmer_hash(screenCoords)>cover) discard;
    number edge=(radial>0.5)
        ? (1.0-smoothstep(0.0,22.0,abs(waveFront-d)))
        : (1.0-cover);
    vec3 tint=pixel.rgb*color.rgb;
    tint=mix(tint,vec3(0.44,0.89,1.0),edge*0.28);
    return vec4(tint,pixel.a);
}
]]
function Reveal.new()
 if not (love and love.graphics and love.graphics.newShader) then return nil end
 return love.graphics.newShader(Reveal.shader)
end
return Reveal
