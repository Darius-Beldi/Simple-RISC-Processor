`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/28/2026 01:13:33 PM
// Design Name: 
// Module Name: seq_core
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`include "macros.vh"

module seq_core #(
        parameter A_SIZE  = `A_BITS,
        parameter D_SIZE  = `D_BITS,
        parameter MEMSIZE = `MEMSIZE
        
        
    )(
    // general
    input  logic              rst,   // active 0 active low
    input  logic	          clk,
    // program memory
    output logic [A_SIZE-1:0] pc,
    input  logic [15:0]       instruction,
    // data memory
    output logic 	          read,  // active 1
    output logic              write, // active 1
    
    output logic [A_SIZE-1:0] address,
    input  logic [D_SIZE-1:0] data_in,
    output logic [D_SIZE-1:0] data_out    
);
    
    // the registers
    logic [D_SIZE-1:0] R [0:7];
    logic halted;

    // memory
    logic [D_SIZE-1:0] SRAM [MEMSIZE];
    
    logic [2:0] op0, op1, op2, 
                mem_op0, mem_op1,
                jmp_op0, jmpc_op0, jmpc_op1, jmpc_cond;
    logic [5:0] val, jmp_offset;  
    logic [7:0] mem_const;
    
    assign op0 = instruction[8:6];
    assign op1 = instruction[5:3];
    assign op2 = instruction[2:0];
    assign val = instruction[5:0];
    
    assign mem_op0   = instruction[10:8];
    assign mem_op1   = instruction[2:0];
    assign mem_const = instruction[7:0];
    
    assign jmp_op0    = instruction[2:0];
    assign jmp_offset = instruction[5:0];
    assign jmpc_cond  = instruction[11:9];
    assign jmpc_op0   = instruction[8:6];
    assign jmpc_op1   = instruction[2:0];
    
    
    integer i;
    
    // populate the SRAM
    initial begin
        for (int i = 0; i < MEMSIZE; i++)
            SRAM[i] = '0;
    end
    
    always_ff @(posedge clk or negedge rst) begin 
        if(!rst) begin // if the reset is triggered
            // reset the registers
            for (i =0; i < 8; i++) R[i] <= 0;    
            pc <= 0; halted <= 0; 
            read <= 0; write <= 0; 
        end else if(!halted) begin
            read <= 0; write <= 0;
            pc <= pc + 1;
            // decode the instruction
            case(instruction[15:14])
                // ---------------- HALT --------------
                2'b01: begin
                    if(instruction == `HALT) halted <=1;
                end
                
                // ------------ ALU -----------
                2'b00: begin
                    case(instruction[15:9])
                        `ADD    : R[op0] <= R[op1] + R[op2];
                        `ADDF   : R[op0] <= R[op1] + R[op2];
                        `SUB    : R[op0] <= R[op1] - R[op2];
                        `SUBF   : R[op0] <= R[op1] - R[op2];
                        `AND    : R[op0] <= R[op1] & R[op2];
                        `OR     : R[op0] <= R[op1] | R[op2];
                        `XOR    : R[op0] <= R[op1] ^ R[op2];
                        `NAND   : R[op0] <= ~( R[op1] & R[op2] );
                        `NOR    : R[op0] <= ~( R[op1] | R[op2] );
                        `NXOR   : R[op0] <= ~( R[op1] ^ R[op2] );
                        `SHIFTR : R[op0] <= R[op0] >> val;
                        `SHIFTRA: R[op0] <= $signed(R[op0]) >>> val;
                        `SHIFTL : R[op0] <= R[op0] << val; 
                        default : ; //NOP
                    endcase
                end
                
                2'b10: begin
                    case(instruction[15:11])
                        `LOAD   : R[mem_op0] <= SRAM[R[mem_op1][A_SIZE-1:0]]; 
                        `LOADC  : R[mem_op0] <= {R[mem_op0][D_SIZE-1:8], mem_const};
                        `STORE  : SRAM[R[mem_op0][A_SIZE-1:0]] <= R[mem_op1];
                        default : ; //NOP
                    endcase
                end
                
                2'b11: begin
                    case(instruction[15:12])
                        `JMP     : pc <= R[jmp_op0];
                        `JMPR    : pc <= pc + A_SIZE'($signed(jmp_offset));
                        `JMPCOND : begin
                                case(instruction[11:9])
                                    `N  : if(R[jmpc_op0] < 0)  pc = R[jmpc_op1];
                                    `NN : if(R[jmpc_op0] >= 0) pc = R[jmpc_op1];
                                    `Z  : if(R[jmpc_op0] == 0) pc = R[jmpc_op1];
                                    `NZ : if(R[jmpc_op0] != 0) pc = R[jmpc_op1];
                                    default : ;//NOP
                                endcase
                              end                       
                        `JMPRCOND:  begin
                                case(instruction[11:9])
                                    `N  : if(R[jmpc_op0] < 0)  pc = pc + A_SIZE'($signed(jmp_offset));
                                    `NN : if(R[jmpc_op0] >= 0) pc = pc + A_SIZE'($signed(jmp_offset));
                                    `Z  : if(R[jmpc_op0] == 0) pc = pc + A_SIZE'($signed(jmp_offset));
                                    `NZ : if(R[jmpc_op0] != 0) pc = pc + A_SIZE'($signed(jmp_offset));
                                    default : ;//NOP
                                endcase
                              end      
                    endcase
                end
            endcase
            
        end
      
    end
endmodule
    