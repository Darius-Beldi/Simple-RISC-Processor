`ifndef TEST_SHIFT
`define TEST_SHIFT

`include "macros.svh"

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

`endif