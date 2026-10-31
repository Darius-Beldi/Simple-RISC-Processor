`timescale 1ns / 1ps
`include "macros.vh"
`define MAXINSTRUCTIONS 16
`define INSTRUCTIONLENGHT 16
`define TEST_COUNT 1000


module tb_top ;

    localparam A_SIZE = `A_BITS;
    localparam D_SIZE = `D_BITS;
    
    // INPUT
    logic              rst;   
    logic              clk;
    logic [15:0]       instruction;
    logic [D_SIZE-1:0] data_in;

    // OUTPUT
    logic [A_SIZE-1:0] pc;
    logic              read;  
    logic              write; 
    logic [A_SIZE-1:0] address;
    logic [D_SIZE-1:0] data_out;  

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
//    JMP     = `JMP,     
//    JMPR    = `JMPR,    
//    JMPCOND = `JMPCOND, 
//    JMPRCOND= `JMPRCOND
} alu_op_t;

logic[31:0] passed_tests = 0;

task automatic test_ALU();
    alu_op_t alu_op;
    alu_op_t ops[] = '{ADD, ADDF, SUB, SUBF, AND_OP, OR_OP, XOR_OP,
                      NAND_OP, NOR_OP, NXOR_OP};

    logic [2:0]         ra, rb, rc;
    logic [`D_BITS-1:0] rb_value, rc_value;
    logic [31:0]        n_passed = 0;
    logic [`D_BITS-1:0] model [8];
    logic [`D_BITS-1:0] a, b, expected;
    
    foreach (model[i]) model[i] = '0;   // match DUT reset state

    repeat (`TEST_COUNT) begin
      ra = $urandom_range(0, `REGISTER_COUNT-1);
      rb = $urandom_range(0, `REGISTER_COUNT-1);        // avoid R0 if it's special
      rc = $urandom_range(0, `REGISTER_COUNT-1);

      rb_value = $urandom();
      rc_value = $urandom();
      alu_op   = ops[$urandom_range(0, ops.size()-1)];

      // load rb, then rc (order matters if rb == rc)
      data_in = rb_value; instruction = {`LOAD, rb, 8'b0}; @(negedge clk);
      model[rb] = rb_value;
      data_in = rc_value; instruction = {`LOAD, rc, 8'b0}; @(negedge clk);
      model[rc] = rc_value;
      
      // execute
      instruction = {alu_op, ra, rb, rc};
      @(negedge clk);

      a = model[rb];
      b = model[rc];
      case (alu_op)
        `ADD, `ADDF : expected = a + b;
        `SUB, `SUBF : expected = a - b;
        `AND        : expected = a & b;
        `OR         : expected = a | b;
        `XOR        : expected = a ^ b;
        `NAND       : expected = ~(a & b);
        `NOR        : expected = ~(a | b);
        `NXOR       : expected = ~(a ^ b);
      endcase
      model[ra] = expected;

      if (expected !== dut.R[ra])
        $error("[ERROR] test_ALU | FAILED | %s ra=R%0d rb=R%0d rc=R%0d a=%0d b=%0d exp=%0d got=%0d",
                alu_op.name(), ra, rb, rc, a, b, expected, dut.R[ra]);
      else
        // $display("TEST_PASSED | %s ra=R%0d rb=R%0d rc=R%0d got=%d", alu_op.name(), ra, rb, rc, dut.R[ra]);
        n_passed = n_passed + 1;
    end 
    $display("[INFO] test_ALU | ALU PASSED TESTS : %0d / %d", n_passed, `TEST_COUNT);
    passed_tests = passed_tests + n_passed;
    
endtask


task automatic test_Shift();
    alu_op_t alu_op;
    alu_op_t ops[] = '{SHIFTL, SHIFTRA, SHIFTR};

    logic [2:0]         ra;
    logic [`D_BITS-1:0] ra_value, expected;
    logic [5:0]         shift_value;
    logic [31:0]        n_passed = 0;

    repeat (`TEST_COUNT) begin
      ra          = $urandom_range(0, `REGISTER_COUNT-1);
      ra_value    = $urandom();
      shift_value = $urandom_range(0, 31);
      alu_op      = ops[$urandom_range(0, ops.size()-1)];

      data_in = ra_value; instruction = {`LOAD, ra, 8'b0}; @(negedge clk);

      // execute
      instruction = {alu_op, ra, shift_value};
      @(negedge clk);

      case (alu_op)
        `SHIFTR : expected = ra_value >> shift_value;
        `SHIFTRA: expected = $signed(ra_value) >>> shift_value;
        `SHIFTL : expected = ra_value << shift_value; 
      endcase
      

      if (expected !== dut.R[ra])
        $error("[ERROR] test_Shift | FAILED | %s ra=R%0d shift_value=%0d exp=%0d got=%0d",
                alu_op.name(), ra, shift_value,  expected, dut.R[ra]);
      else
       // $display("test_Shift | PASSED | %s ra=R%0d shift_value=%0d exp=%0d got=%0d",
             //   alu_op.name(), ra, shift_value,  expected, dut.R[ra]);
        n_passed = n_passed + 1;
    end 
    $display("[INFO] test_Shift | SHIFT PASSED TESTS : %0d / %d", n_passed, `TEST_COUNT);
    passed_tests = passed_tests + n_passed;
    

endtask

task automatic run_Tests();
    
    $display("[INFO] run_Tests | Started test_ALU() @ %0t", $time);
    test_ALU();
    $display("[INFO] run_Tests | Finished test_ALU()  @ %0t", $time);
    $display("[INFO] run_Tests | Started test_Shift()  @ %0t", $time);
    test_Shift();
    $display("[INFO] run_Tests | Finished test_Shift()  @ %0t", $time);
    
    $display("[INFO] run_Tests | TOTAL RUN TESTS : %0d PASSED : %0d", (`TEST_COUNT * 2) , passed_tests);

endtask

initial begin
    $display("TB START @ %0t", $time);
    rst = 1'b0;
    instruction = `NOP;
    data_in = '0;
    repeat(2)@(negedge clk);
    rst = 1'b1;
    @(negedge clk);
    run_Tests();
    $finish;
end

endmodule