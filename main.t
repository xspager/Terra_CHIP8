--local ffi = require("ffi")
local bit = require('bit')
local C = terralib.includec("stdio.h")
exit = terralib.externfunction("exit", int -> {})
local caca = terralib.includec("caca.h")

local system = io.popen("uname -s"):read("*l")
if system ~= "Linux" then
	terralib.linklibrary("/usr/local/Cellar/libcaca/0.99b19/lib/libcaca.0.dylib")
else
	terralib.linklibrary("libcaca.so")
end

--[[
    Memory map
    0x000-0x1FF - Chip 8 interpreter (contains font set in emu)
    0x050-0x0A0 - Used for the built in 4x5 pixel font set (0-F)
    0x200-0xFFF - Program ROM and work RAM
--]]

local chip8_fontset = constant(`arrayof(uint8,
  0xF0, 0x90, 0x90, 0x90, 0xF0, -- 0
  0x20, 0x60, 0x20, 0x20, 0x70, -- 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0, -- 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0, -- 3
  0x90, 0x90, 0xF0, 0x10, 0x10, -- 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0, -- 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0, -- 6
  0xF0, 0x10, 0x20, 0x40, 0x40, -- 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0, -- 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0, -- 9
  0xF0, 0x90, 0xF0, 0x90, 0x90, -- A
  0xE0, 0x90, 0xE0, 0x90, 0xE0, -- B
  0xF0, 0x80, 0x80, 0x80, 0xF0, -- C
  0xE0, 0x90, 0x90, 0x90, 0xE0, -- D
  0xF0, 0x80, 0xF0, 0x80, 0xF0, -- E
  0xF0, 0x80, 0xF0, 0x80, 0x80  -- F
))

struct Chip8{
    opcode: uint16,
    memory: uint8[1024*4],
    gfx: uint8[64*32],
    V: uint8[16],
    I: uint16, pc: uint16,
    delay_timer: uint8, sound_timer: uint8,
    stack: uint16[16], sp: uint16,
    key: uint8[16],
    drawflag: bool
}

terra clear_screen(chip8: &Chip8)
    for y=0, 32 do
        for x=0, 64 do
            chip8.gfx[x+(y*64)] = 0x00
        end
    end
    chip8.drawflag = true
end

terra Chip8:initialize()
    self.pc = 0x200
    self.opcode = 0
    self.I = 0
    self.sp = 0

    -- clear display
    clear_screen(self)

    -- clear stack
    -- clear registers V0-VF
    -- clear memory

    -- Load fontset
    for i = 0, 80 do
        self.memory[i] = chip8_fontset[i]
    end
end

terra Chip8:loadGame(filename: &int8)
    var f = C.fopen(filename, 'rb')
    if f == nil then
        C.perror("Error opening file")
    else
        C.fseek(f, 0, C.SEEK_END)
        var size = C.ftell(f)
        --C.printf("File size: %d bytes\n", size)
        if size < 1024 * 3 then
            C.fseek(f, 0, C.SEEK_SET)
            C.fread(&self.memory[0x200], 8, size, f)
        end
    end

end

function lua_decode_opcode(chip8, masked_opcode)

    local opcodes = {
        [0x0000] = function(chip8)
            local subops = {
                [0] = function(chip8)
                    exit(0)
                end,
                [0x00E0] = function(chip8)
                    -- CLS 00E0 Clear the screen
                    clear_screen(chip8)
                end,
                [0x00EE] = function(chip8)
                    -- RET 00EE return from subrotine
                end
            }
            subops[chip8.opcode](chip8)
        end,
        [0x1000] = function(chip8)
        end,
        [0x2000] = function(chip8)
            -- CALL 2xxx
            chip8.stack[chip8.sp] = chip8.pc
            chip8.sp = chip8.sp + 1
            chip8.pc = bit.band(chip8.opcode, 0x0FFF)
        end,
        [0x3000] = function(chip8)
        end,
        [0x4000] = function(chip8)
        end,
        [0x5000] = function(chip8)
        end,
        [0x6000] = function(chip8)
        end,
        [0x7000] = function(chip8)
        end,
        [0x8000] = function(chip8)
            local subops = {
            }
            -- 8XY
        end,
        [0x9000] = function(chip8)
        end,
        [0xA000] = function(chip8)
            -- store last three nibles on I
            chip8.I = bit.band(chip8.opcode, 0x0FFF)
        end,
        [0xB000] = function(chip8)
        end,
        [0xC000] = function(chip8)
        end,
        [0xD000] = function(chip8)
            -- DRW Vx, Vy, nibble
            local x = bit.rshift(
                bit.band(
                chip8.opcode, 0x0F00), 8)
            local y = bit.rshift(
                bit.band(
                chip8.opcode, 0x00F0), 4)
            local N = bit.band(
                chip8.opcode, 0x000F)
            --print("x:"..x.." y:"..y.." N:"..N)
            chip8.gfx[0] =  0xFF
            chip8.gfx[63] = 0xFF
            chip8.gfx[31*64] = 0xFF
            chip8.gfx[31*64+63] = 0xFF
            chip8.drawflag = true
        end,
        [0x1000] = function(chip8)
        end,
        [0x1000] = function(chip8)
        end
    }

    opcodes[masked_opcode](chip8)
end

decode_opcode = terralib.cast({&Chip8,uint16} -> {}, lua_decode_opcode)

terra Chip8:emulateCycle()
    -- Fetch Opcode
    self.opcode = self.memory[self.pc]
    self.opcode = self.opcode << 8 or self.memory[self.pc+1]
    --C.printf("OPCODE = 0x%04X\n", self.opcode)
    -- Decode Opcode
    var masked_opcode: uint16 = self.opcode and 0xF000
    self.pc = self.pc + 2
    decode_opcode(self, masked_opcode)
    --C.printf("pc = 0x%X\n", self.pc)
    --C.printf("I = 0x%X\n", self.I)
    -- Execute Opcode

    -- Update timers
    if self.delay_timer > 0 then
        self.delay_timer = self.delay_timer - 1
    end
 
    if self.sound_timer > 0 then
        if self.sound_timer == 1 then
            C.printf("BEEP!\n");
            self.sound_timer = self.sound_timer -1;
        end
    end
end

struct Graphics {
    width: int32,
    height: int32,
    display: &caca.caca_display_t,
    canvas: &caca.caca_canvas_t,
    dither: &caca.caca_dither_t
}

terra Graphics:update(chip8: &Chip8)
    caca.caca_dither_bitmap(self.canvas, 0, 0, self.width, self.height, self.dither, &chip8.gfx)
    caca.caca_refresh_display(self.display)
end

terra Graphics:free()
    caca.caca_free_display(self.display)
end

terra setupGraphics(): Graphics
    var cv: &caca.caca_canvas_t, dp: &caca.caca_display_t, ev: &caca.caca_event_t
    
    var graphics: Graphics

    graphics.display = caca.caca_create_display(nil);
    if graphics.display == nil then
        exit(1)
    end

    graphics.canvas = caca.caca_get_canvas(graphics.display)
    graphics.dither = caca.caca_create_dither(8, 64, 32, 64, 0,0,0,0)
    graphics.width = caca.caca_get_canvas_width(graphics.canvas)
    graphics.height = caca.caca_get_canvas_height(graphics.canvas)
    caca.caca_set_display_title(graphics.display, "Hello!")
    caca.caca_refresh_display(graphics.display)
    --caca.caca_set_color_ansi(cv, caca.CACA_BLUE, caca.CACA_WHITE)
    --caca.caca_put_str(cv, 0, 0, "This is a message")
    --caca.caca_get_event(dp, caca.CACA_EVENT_KEY_PRESS, ev, -1)
    return graphics
end

terra main()
    var chip8: Chip8

    var graphics = setupGraphics()
    
    -- setupInput()
    chip8:initialize()

    chip8:loadGame("test.bin")

    while chip8.pc < 0x200 + 32 do
        chip8:emulateCycle()
        if chip8.drawflag then
            graphics:update(&chip8)
            chip8.drawflag = false
        end
        -- setKeys() 
    end
    graphics:free()
end

main()
--terralib.saveobj('main', {main=main})
--terralib.saveobj('main.S', 'llvmir', {main=main})
