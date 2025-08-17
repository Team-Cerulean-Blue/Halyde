local module = {}

function module.check()
  return true -- This module should always be loaded
end

function module.init()
  _G._PUBLIC.keyboard = {["keys"] = {}}

  _PUBLIC.keyboard.keys["1"]           = 0x02
  _PUBLIC.keyboard.keys["2"]           = 0x03
  _PUBLIC.keyboard.keys["3"]           = 0x04
  _PUBLIC.keyboard.keys["4"]           = 0x05
  _PUBLIC.keyboard.keys["5"]           = 0x06
  _PUBLIC.keyboard.keys["6"]           = 0x07
  _PUBLIC.keyboard.keys["7"]           = 0x08
  _PUBLIC.keyboard.keys["8"]           = 0x09
  _PUBLIC.keyboard.keys["9"]           = 0x0A
  _PUBLIC.keyboard.keys["0"]           = 0x0B
  _PUBLIC.keyboard.keys.a               = 0x1E
  _PUBLIC.keyboard.keys.b               = 0x30
  _PUBLIC.keyboard.keys.c               = 0x2E
  _PUBLIC.keyboard.keys.d               = 0x20
  _PUBLIC.keyboard.keys.e               = 0x12
  _PUBLIC.keyboard.keys.f               = 0x21
  _PUBLIC.keyboard.keys.g               = 0x22
  _PUBLIC.keyboard.keys.h               = 0x23
  _PUBLIC.keyboard.keys.i               = 0x17
  _PUBLIC.keyboard.keys.j               = 0x24
  _PUBLIC.keyboard.keys.k               = 0x25
  _PUBLIC.keyboard.keys.l               = 0x26
  _PUBLIC.keyboard.keys.m               = 0x32
  _PUBLIC.keyboard.keys.n               = 0x31
  _PUBLIC.keyboard.keys.o               = 0x18
  _PUBLIC.keyboard.keys.p               = 0x19
  _PUBLIC.keyboard.keys.q               = 0x10
  _PUBLIC.keyboard.keys.r               = 0x13
  _PUBLIC.keyboard.keys.s               = 0x1F
  _PUBLIC.keyboard.keys.t               = 0x14
  _PUBLIC.keyboard.keys.u               = 0x16
  _PUBLIC.keyboard.keys.v               = 0x2F
  _PUBLIC.keyboard.keys.w               = 0x11
  _PUBLIC.keyboard.keys.x               = 0x2D
  _PUBLIC.keyboard.keys.y               = 0x15
  _PUBLIC.keyboard.keys.z               = 0x2C

  _PUBLIC.keyboard.keys.apostrophe      = 0x28
  _PUBLIC.keyboard.keys.at              = 0x91
  _PUBLIC.keyboard.keys.back            = 0x0E -- backspace
  _PUBLIC.keyboard.keys.backslash       = 0x2B
  _PUBLIC.keyboard.keys.capital         = 0x3A -- capslock
  _PUBLIC.keyboard.keys.colon           = 0x92
  _PUBLIC.keyboard.keys.comma           = 0x33
  _PUBLIC.keyboard.keys.enter           = 0x1C
  _PUBLIC.keyboard.keys.equals          = 0x0D
  _PUBLIC.keyboard.keys.grave           = 0x29 -- accent grave
  _PUBLIC.keyboard.keys.lbracket        = 0x1A
  _PUBLIC.keyboard.keys.lcontrol        = 0x1D
  _PUBLIC.keyboard.keys.lmenu           = 0x38 -- left Alt
  _PUBLIC.keyboard.keys.lshift          = 0x2A
  _PUBLIC.keyboard.keys.minus           = 0x0C
  _PUBLIC.keyboard.keys.numlock         = 0x45
  _PUBLIC.keyboard.keys.pause           = 0xC5
  _PUBLIC.keyboard.keys.period          = 0x34
  _PUBLIC.keyboard.keys.rbracket        = 0x1B
  _PUBLIC.keyboard.keys.rcontrol        = 0x9D
  _PUBLIC.keyboard.keys.rmenu           = 0xB8 -- right Alt
  _PUBLIC.keyboard.keys.rshift          = 0x36
  _PUBLIC.keyboard.keys.scroll          = 0x46 -- Scroll Lock
  _PUBLIC.keyboard.keys.semicolon       = 0x27
  _PUBLIC.keyboard.keys.slash           = 0x35 -- / on main _PUBLIC.keyboard
  _PUBLIC.keyboard.keys.space           = 0x39
  _PUBLIC.keyboard.keys.stop            = 0x95
  _PUBLIC.keyboard.keys.tab             = 0x0F
  _PUBLIC.keyboard.keys.underline       = 0x93

  -- Keypad (and numpad with numlock off)
  _PUBLIC.keyboard.keys.up              = 0xC8
  _PUBLIC.keyboard.keys.down            = 0xD0
  _PUBLIC.keyboard.keys.left            = 0xCB
  _PUBLIC.keyboard.keys.right           = 0xCD
  _PUBLIC.keyboard.keys.home            = 0xC7
  _PUBLIC.keyboard.keys["end"]         = 0xCF
  _PUBLIC.keyboard.keys.pageUp          = 0xC9
  _PUBLIC.keyboard.keys.pageDown        = 0xD1
  _PUBLIC.keyboard.keys.insert          = 0xD2
  _PUBLIC.keyboard.keys.delete          = 0xD3

  -- Function keys
  _PUBLIC.keyboard.keys.f1              = 0x3B
  _PUBLIC.keyboard.keys.f2              = 0x3C
  _PUBLIC.keyboard.keys.f3              = 0x3D
  _PUBLIC.keyboard.keys.f4              = 0x3E
  _PUBLIC.keyboard.keys.f5              = 0x3F
  _PUBLIC.keyboard.keys.f6              = 0x40
  _PUBLIC.keyboard.keys.f7              = 0x41
  _PUBLIC.keyboard.keys.f8              = 0x42
  _PUBLIC.keyboard.keys.f9              = 0x43
  _PUBLIC.keyboard.keys.f10             = 0x44
  _PUBLIC.keyboard.keys.f11             = 0x57
  _PUBLIC.keyboard.keys.f12             = 0x58
  _PUBLIC.keyboard.keys.f13             = 0x64
  _PUBLIC.keyboard.keys.f14             = 0x65
  _PUBLIC.keyboard.keys.f15             = 0x66
  _PUBLIC.keyboard.keys.f16             = 0x67
  _PUBLIC.keyboard.keys.f17             = 0x68
  _PUBLIC.keyboard.keys.f18             = 0x69
  _PUBLIC.keyboard.keys.f19             = 0x71

  -- Japanese keyboards
  _PUBLIC.keyboard.keys.kana            = 0x70
  _PUBLIC.keyboard.keys.kanji           = 0x94
  _PUBLIC.keyboard.keys.convert         = 0x79
  _PUBLIC.keyboard.keys.noconvert       = 0x7B
  _PUBLIC.keyboard.keys.yen             = 0x7D
  _PUBLIC.keyboard.keys.circumflex      = 0x90
  _PUBLIC.keyboard.keys.ax              = 0x96

  -- Numpad
  _PUBLIC.keyboard.keys.numpad0         = 0x52
  _PUBLIC.keyboard.keys.numpad1         = 0x4F
  _PUBLIC.keyboard.keys.numpad2         = 0x50
  _PUBLIC.keyboard.keys.numpad3         = 0x51
  _PUBLIC.keyboard.keys.numpad4         = 0x4B
  _PUBLIC.keyboard.keys.numpad5         = 0x4C
  _PUBLIC.keyboard.keys.numpad6         = 0x4D
  _PUBLIC.keyboard.keys.numpad7         = 0x47
  _PUBLIC.keyboard.keys.numpad8         = 0x48
  _PUBLIC.keyboard.keys.numpad9         = 0x49
  _PUBLIC.keyboard.keys.numpadmul       = 0x37
  _PUBLIC.keyboard.keys.numpaddiv       = 0xB5
  _PUBLIC.keyboard.keys.numpadsub       = 0x4A
  _PUBLIC.keyboard.keys.numpadadd       = 0x4E
  _PUBLIC.keyboard.keys.numpaddecimal   = 0x53
  _PUBLIC.keyboard.keys.numpadcomma     = 0xB3
  _PUBLIC.keyboard.keys.numpadenter     = 0x9C
  _PUBLIC.keyboard.keys.numpadequals    = 0x8D

  -- Create inverse mapping for name lookup.
  setmetatable(_PUBLIC.keyboard.keys,
  {
    __index = function(tbl, k)
      if type(k) ~= "number" then return end
      for name,value in pairs(tbl) do
        if value == k then
          return name
        end
      end
    end
  })
end

function module.exit()
  _G._PUBLIC.keyboard = nil
end

return module
