derive_pll_clocks
derive_clock_uncertainty

set_false_path -from {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk} -to [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path -from {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk} -to [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path -from {FPGA_CLK1_50} -to [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path -from {FPGA_CLK2_50} -to [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
set_false_path -from {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk} -to [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]

set_false_path -from [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -to {pll_hdmi|pll_hdmi_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}
set_false_path -from [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -to {sysmem|fpga_interfaces|clocks_resets|h2f_user0_clk}
set_false_path -from [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -to {FPGA_CLK1_50}

set_false_path -from [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -to [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
set_false_path -from [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -to [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]

set_false_path -from [get_clocks {emu|pll2|pll2_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}] -to [get_clocks {pll_audio|pll_audio_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
# savestates: data and handshakes between the CPU clock and clk1x are static while sampled or go through synchronizers
set_false_path -from [get_registers {*|cpu:icpu|SS_DataRead_CPU[*]}]
set_false_path -to [get_registers {*|cpu:icpu|ss_holdIRQ_sync[0]}]
set_false_path -to [get_registers {*|cpu:icpu|ss_flush_sync[0]}]
set_false_path -to [get_registers {*|savestates:isavestates|cpuHeld_sync[0]}]
set_false_path -to [get_registers {*|savestates:isavestates|flushDone_sync[0]}]
