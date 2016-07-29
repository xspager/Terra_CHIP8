local C = terralib.includec("stdio.h")

terra main()
    var memory: uint8[2]
    var opcode: uint16

    memory[0] = 0xDA
    memory[1] = 0x1E
    opcode = [uint16](memory[0]) << 8 or memory[1]
    C.printf("0x%04x\n", opcode)
 
end

--main:disas()
main()
--terralib.saveobj('main', {main=main})
--terralib.saveobj('simpleor.S', 'llvmir', {main=main})
--terralib.saveobj('simpleor.S', 'asm', {main=main})
