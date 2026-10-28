

`define A_BITS 10
`define D_BITS 32
`define MEMSIZE (1<<`A_BITS)

// registers
`define R0 3'd0
`define R1 3'd1
`define R2 3'd2
`define R3 3'd3
`define R4 3'd4 
`define R5 3'd5 
`define R6 3'd6 
`define R7 3'd7


// OPCODES
`define NOP     16'b00_00_0000_0000_0000    
`define HALT    16'b01_11_1111_1111_1111

//ALU
`define ADD     7'b00_11_000
`define ADDF    7'b00_11_010
`define SUB     7'b00_11_001
`define SUBF    7'b00_11_011
`define AND     7'b00_00_100
`define OR      7'b00_00_101
`define XOR     7'b00_00_110
`define NAND    7'b00_01_100
`define NOR     7'b00_01_101
`define NXOR    7'b00_01_110
`define SHIFTR  7'b00_10_000
`define SHIFTRA 7'b00_10_001
`define SHIFTL  7'b00_10_010

//MEMORY 
`define LOAD    5'b10_00_0
`define LOADC   5'b10_00_1
`define STORE   5'b10_01_0

//JUMPS

`define JMP     4'b11_00
`define JMPR    4'b11_10
`define JMPCOND 4'b11_01
`define JMPRCOND 4'b11_11

// Conditional jump conditions

`define N  3'b000
`define NN 3'b001
`define Z  3'b010
`define NZ 3'b011

