function love.conf(t)
  t.identity = "osman-biome-core"
  t.window.title = "Oyun / 2D World"
  t.window.width = 720
  t.window.height = 1100
  t.window.minwidth = 320
  t.window.minheight = 480
  t.window.resizable = true
  -- Keep one logical screen pixel per render pixel on high-DPI phones.
  -- Optional native-DPI visual comparison: TAMU_NATIVE_DPI=1.
  t.window.highdpi = os.getenv("TAMU_NATIVE_DPI") == "1"
  t.window.usedpiscale = true
end
