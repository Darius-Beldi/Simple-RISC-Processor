`ifndef TEST_JMP
`define TEST_JMP

`include "macros.svh"

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


`endif 