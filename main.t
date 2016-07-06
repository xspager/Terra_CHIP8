local bit = require('bit')
local C = terralib.includec("stdio.h")

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
    --memory: uint8[1024*4],
    memory: uint8[4],
    gfx: uint8[64*32],
    V: uint8[16],
    I: uint16, pc: uint16,
    delay_timer: uint8, sound_timer: uint8,
    stack: uint16[16], sp: uint16,
    key: uint8[16],
}

terra Chip8:initialize()
    self.pc = 0x200
    self.opcode = 0
    self.I = 0
    self.sp = 0

    -- clear display
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
        C.printf("File size: %d bytes\n", size)
        if size < 1024 * 3 then
            C.fseek(f, 0, C.SEEK_SET)
            C.fread(&self.memory[0x200], 8, size, f)
        end
    end

end

function decode_opcode(chip8, masked_opcode)

    local opcodes = {
        [0x0000] = function(chip8)
            -- clear screen
        end,
        [0x000E] = function(chip8)
            -- return from subrotine
        end,
        [0x2000] = function(chip8)
            chip8.stack[chip8.sp] = chip8.pc
            chip8.sp = chip8.sp + 1
            chip8.pc = bit.band(chip8.opcode, 0x0FFF)
        end,
        [0xA000] = function(chip8)
            -- store last three nibles on I
            chip8.I = bit.band(chip8.opcode, 0x0FFF)
        end
    }

    opcodes[masked_opcode](chip8)
end

lua_decode_opcode = terralib.cast({&Chip8,uint16} -> {}, decode_opcode)

terra Chip8:emulateCycle()
    -- Fetch Opcode
    self.opcode = self.memory[self.pc]
    self.opcode = self.opcode << 8 or self.memory[self.pc+1]
    C.printf("OPCODE = 0x%X\n", self.opcode)
    -- Decode Opcode
    var masked_opcode: uint16 = self.opcode and 0xF000
    self.pc = self.pc + 2
    lua_decode_opcode(self, masked_opcode)
    C.printf("pc = 0x%X\n", self.pc)
    C.printf("I = 0x%X\n", self.I)
    -- Execute Opcode

    -- Update timers

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

terra main()
    var chip8: Chip8

    -- setupGraphics()
    -- setupInput()
    chip8:initialize()

    chip8:loadGame("pong.bin")

    while chip8.pc < 0x200 + 20 do
        chip8:emulateCycle()
        --if drawflag then
            -- draw
        -- end
        -- setKeys()
        
    end
end

main()
--terralib.saveobj('main', {main=main})
--terralib.saveobj('main.S', 'llvmir', {main=main})
