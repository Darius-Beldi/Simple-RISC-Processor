`ifndef TEST_ALU
`define TEST_ALU

`include "macros.svh"


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


`endif