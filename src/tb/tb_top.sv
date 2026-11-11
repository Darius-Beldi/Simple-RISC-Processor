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
      data_in = rb_value; instr_manual = {`LOAD, rb, 8'b0}; @(negedge clk);
      model[rb] = rb_value;
      data_in = rc_value; instr_manual = {`LOAD, rc, 8'b0}; @(negedge clk);
      model[rc] = rc_value;
      
      // execute
      instr_manual = {alu_op, ra, rb, rc};
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

      data_in = ra_value; instr_manual = {`LOAD, ra, 8'b0}; @(negedge clk);

      // execute
      instr_manual = {alu_op, ra, shift_value};
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
// Drop-in replacement for test_JMP (also delete the jmp_cond_t typedef
// and remove JMP/JMPR/JMPCOND/JMPRCOND from alu_op_t).
task automatic test_JMP();
    string              names[4] = '{"JMP", "JMPR", "JMPCOND", "JMPRCOND"};
 
    logic [2:0]         ra, rb, cond;
    logic [`D_BITS-1:0] ra_value, rb_value;
    logic [5:0]         offset;
    logic [A_SIZE-1:0]  pc_jmp, expected;   // pc_jmp = address of the jump instruction
    logic               taken;
    int                 kind;
    logic [31:0]        n_passed = 0;
 
    repeat (`TEST_COUNT) begin
      ra       = $urandom_range(0, `REGISTER_COUNT-1);
      rb       = $urandom_range(0, `REGISTER_COUNT-1);
      kind     = $urandom_range(0, 3);
      cond     = $urandom_range(0, 3);        // N, NN, Z, NZ  (000..011)
      offset   = $urandom();                  // full signed 6-bit range
      rb_value = $urandom();
 
      // make zero / negative / positive ra_value all likely
      ra_value = $urandom();
      case ($urandom_range(0, 2))
        0: ra_value = '0;
        1: ra_value[`D_BITS-1] = 1'b1;
        2: ra_value[`D_BITS-1] = 1'b0;
      endcase
 
      // load ra, then rb (if ra == rb the second load wins)
      data_in = ra_value; instr_manual = {`LOAD, ra, 8'b0}; @(negedge clk);
      data_in = rb_value; instr_manual = {`LOAD, rb, 8'b0}; @(negedge clk);
      if (ra == rb) ra_value = rb_value;
 
      pc_jmp = pc;   // pc now points at the jump instruction
 
      case (cond)
        `N  : taken = ($signed(ra_value) <  0);
        `NN : taken = ($signed(ra_value) >= 0);
        `Z  : taken = (ra_value == 0);
        `NZ : taken = (ra_value != 0);
        default: taken = 1'b0;
      endcase
 
      case (kind)
        0: begin
             instr_manual = {`JMP, 9'b0, ra};
             expected    = ra_value[A_SIZE-1:0];
           end
        1: begin
             instr_manual = {`JMPR, 6'b0, offset};
             expected    = pc_jmp + A_SIZE'($signed(offset));
           end
        2: begin
             instr_manual = {`JMPCOND, cond, ra, 3'b0, rb};
             expected    = taken ? rb_value[A_SIZE-1:0] : pc_jmp + 1'b1;
           end
        3: begin
             instr_manual = {`JMPRCOND, cond, ra, offset};
             expected    = taken ? pc_jmp + A_SIZE'($signed(offset)) : pc_jmp + 1'b1;
           end
      endcase
 
      @(negedge clk);
 
      if (expected !== pc)
        $error("[ERROR] test_JMP | FAILED | %s ra=R%0d rb=R%0d cond=%0d ra_value=%0d rb_value=%0d offset=%0d exp=%0d got=%0d",
                names[kind], ra, rb, cond, $signed(ra_value), rb_value, $signed(offset), expected, pc);
      else
        n_passed = n_passed + 1;
    end
    $display("[INFO] test_JMP | JMP PASSED TESTS : %0d / %0d", n_passed, `TEST_COUNT);
    passed_tests = passed_tests + n_passed;
endtask


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

//task automatic multiplicationAlgorithm()

//     instructionSet = '{
//     0: {},
//     1: {},
//     2: {}
//     }










//endtask




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