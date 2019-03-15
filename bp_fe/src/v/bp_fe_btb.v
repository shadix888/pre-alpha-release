/*
 * bp_fe_btb.v
 * 
 * Branch Target Buffer (BTB) stores the addresses of the branch targets and the
 * corresponding branch sites. Branch happens from the branch sites to the branch
 * targets. In order to save the logic sizes, the BTB is designed to have limited 
 * entries for storing the branch sites, branch target pairs. The implementation 
 * uses the bsg_mem_1rw_sync_synth RAM design.
*/

module bp_fe_btb
 import bp_fe_pkg::*; 
 #(parameter   bp_fe_pc_gen_btb_idx_width_lp=9
   , parameter eaddr_width_p="inv"
   , localparam els_lp=2**bp_fe_pc_gen_btb_idx_width_lp
   ) 
  (input                                       clk_i
   , input                                     reset_i 

   , input [bp_fe_pc_gen_btb_idx_width_lp-1:0] idx_w_i
   , input [bp_fe_pc_gen_btb_idx_width_lp-1:0] idx_r_i
   , input                                     r_v_i
   , input                                     w_v_i

   , input [eaddr_width_p-1:0]                 branch_target_i
   , output logic [eaddr_width_p-1:0]          branch_target_o

   , output logic                              read_valid_o
   );

   
logic [els_lp-1:0] valid;

always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
      begin
        valid <= '{default:'0};
      end 
    else if (w_v_i) 
      begin
        valid[idx_w_i] <= '1;
      end
  end

assign read_valid_o = valid[idx_r_i];

// logic required to crack the ram into upper and lower addressed halves
logic high_w_v_i, high_r_v_i, low_w_v_i, low_r_v_i;
assign high_w_v_i = idx_w_i[bp_fe_pc_gen_btb_idx_width_lp-1] && w_v_i;
assign high_r_v_i = idx_r_i[bp_fe_pc_gen_btb_idx_width_lp-1] && r_v_i;
assign low_w_v_i = (!idx_w_i[bp_fe_pc_gen_btb_idx_width_lp-1]) && w_v_i;
assign low_r_v_i = (!idx_r_i[bp_fe_pc_gen_btb_idx_width_lp-1]) && r_v_i;

logic [bp_fe_pc_gen_btb_idx_width_lp-2:0] write_addr, read_addr;
assign write_addr = idx_w_i[bp_fe_pc_gen_btb_idx_width_lp-2:0];
assign read_addr = idx_r_i[bp_fe_pc_gen_btb_idx_width_lp-2:0];

// pick between the output of the two rams
logic [eaddr_width_p-1:0] branch_target_high, branch_target_low;

// ram for upper half of addresses
bsg_mem_1r1w 
 #(.width_p(eaddr_width_p)
   ,.els_p(2**(bp_fe_pc_gen_btb_idx_width_lp-1))
   ,.addr_width_lp(bp_fe_pc_gen_btb_idx_width_lp-1)
   ,.enable_clock_gating_p(1'b1)
   ) 
 bsg_mem_1rw_sync_synth_1 
  (.w_clk_i(clk_i)
   ,.w_reset_i(reset_i)

   ,.w_v_i(high_w_v_i)
   ,.w_addr_i(write_addr)
   ,.w_data_i(branch_target_i)
   
   ,.r_v_i(high_r_v_i)
   ,.r_addr_i(read_addr)
   ,.r_data_o(branch_target_high)
   );

// ram for lower half of addresses
bsg_mem_1r1w
 #(.width_p(eaddr_width_p)
  ,.els_p(2**(bp_fe_pc_gen_btb_idx_width_lp-1))
  ,.addr_width_lp(bp_fe_pc_gen_btb_idx_width_lp-1)
  ,.enable_clock_gating_p(1'b1)
  )
 bsg_mem_1rw_sync_synth_2
  (.w_clk_i(clk_i)
  ,.w_reset_i(reset_i)

  ,.w_v_i(low_w_v_i)
  ,.w_addr_i(write_addr)
  ,.w_data_i(branch_target_i)

  ,.r_v_i(low_r_v_i)
  ,.r_addr_i(read_addr)
  ,.r_data_o(branch_target_low)
  );

assign branch_target_o = high_r_v_i ? branch_target_high : branch_target_low;
endmodule
