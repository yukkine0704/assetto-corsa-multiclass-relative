local Theme = {}

Theme.palettes = {
  dark = {
    void = rgbm(0x0B / 255, 0x09 / 255, 0x07 / 255, 0.98),
    panel = rgbm(0x0D / 255, 0x0B / 255, 0x09 / 255, 0.98),
    panelRaised = rgbm(0x1A / 255, 0x13 / 255, 0x0E / 255, 0.98),
    primary = rgbm(0xF2 / 255, 0xDB / 255, 0xAE / 255, 1),
    secondary = rgbm(0x98 / 255, 0x7A / 255, 0x4C / 255, 0.95),
    amberDim = rgbm(0x5E / 255, 0x43 / 255, 0x19 / 255, 0.92),
    red = rgbm(0xD8 / 255, 0x4B / 255, 0x3E / 255, 1)
  },

  light = {
    void = rgbm(0xD8 / 255, 0xD2 / 255, 0xC6 / 255, 0.98),
    panel = rgbm(0xF7 / 255, 0xF3 / 255, 0xEA / 255, 0.98),
    panelRaised = rgbm(0xFF / 255, 0xFC / 255, 0xF5 / 255, 0.98),
    primary = rgbm(0x2E / 255, 0x2B / 255, 0x26 / 255, 1),
    secondary = rgbm(0x65 / 255, 0x59 / 255, 0x48 / 255, 0.95),
    amberDim = rgbm(0xF0 / 255, 0xD2 / 255, 0x9C / 255, 0.92),
    red = rgbm(0xAD / 255, 0x29 / 255, 0x22 / 255, 1)
  }
}

function Theme.get(name)
  return Theme.palettes[name] or Theme.palettes.dark
end

function Theme.withAlpha(color, alpha)
  return rgbm(color.r, color.g, color.b, alpha)
end

function Theme.fromRgb(color, alpha)
  return rgbm(color.r, color.g, color.b, alpha)
end

return Theme
