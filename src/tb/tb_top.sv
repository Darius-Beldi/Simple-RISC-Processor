`timescale 1ns / 1ps

`include "macros.svh"
`define MAXINSTRUCTIONS 16
`define INSTRUCTIONLENGHT 16
`define TEST_COUNT 1000
`define INSTRUCTIONNUMBER 100

module tb_top ;

    localparam A_SIZE = `A_BITS;
    localparam D_SIZE = `D_BITS;
    
    // INPUT
    logic              rst;   
    logic              clk;
    logic [15:0]       instruction;      // driven ONLY by the assign below
    logic [15:0]       instr_manual;     // driven procedurally by the tests
    logic              use_imem = 1'b0;  // 0 = tests drive the core, 1 = instructionSet[pc] drives it
    logic [D_SIZE-1:0] data_in;

    // OUTPUT
    logic [A_SIZE-1:0] pc;
    logic              read;  
    logic              write; 
    logic [A_SIZE-1:0] address;
    logic [D_SIZE-1:0] data_out;  

    logic [`INSTRUCTIONLENGHT-1:0] instructionSet [`INSTRUCTIONNUMBER:0];

    assign instruction = use_imem ? instructionSet[pc] : instr_manual;

    initial clk = 0;

    always #5 clk = ~clk;

seq_core dut (
    .rst            (rst),
    .clk            (clk),
    .instruction    (instruction),
    .data_in        (data_in),
    .pc             (pc),
    .read           (read),
    .write          (write),
    .address        (address),
    .data_out       (data_out)
);

typedef enum logic [6:0] {
    ADD     = `ADD,
    ADDF    = `ADDF,
    SUB     = `SUB,
    SUBF    = `SUBF,
    AND_OP  = `AND,
    OR_OP   = `OR,
    XOR_OP  = `XOR,
    NAND_OP = `NAND,
    NOR_OP  = `NOR,
    NXOR_OP = `NXOR,
    SHIFTRA = `SHIFTRA,
    SHIFTR  = `SHIFTR,
    SHIFTL  = `SHIFTL
} alu_op_t;

logic[31:0] passed_tests = 0;


`include "test_alu.svh"
`include "test_shift.svh"
`include "test_jmp.svh"



task automatic runTests();
    
    $display("[INFO] runTests | Started test_ALU() @ %0t", $time);
    test_ALU();
    $display("[INFO] runTests | Finished test_ALU()  @ %0t", $time);

    $display("[INFO] runTests | Started test_Shift()  @ %0t", $time);
    test_Shift();
    $display("[INFO] runTests | Finished test_Shift()  @ %0t", $time);
    
    $display("[INFO] runTests | Started test_JMP()  @ %0t", $time);
    test_JMP();
    $display("[INFO] runTests | Finished test_JMP()  @ %0t", $time);

    $display("[INFO] runTests | TOTAL RUN TESTS : %0d PASSED : %0d", (`TEST_COUNT * 3) , passed_tests);

endtask

initial begin
    $display("TB START @ %0t", $time);
    rst = 1'b0;
    instr_manual = `NOP;
    data_in = '0;
    repeat(2)@(negedge clk);
    rst = 1'b1;
    @(negedge clk);
    runTests();
    $finish;
end

endmodule