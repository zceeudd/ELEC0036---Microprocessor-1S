module processor1_tb();

	logic clk;

	processor1 processor1TEST(
	.clk(clk)
	);

	initial begin
	clk = 0;
	processor1TEST.processor1_datapath.data_PC.pc=16'b0000000000000000;
	$readmemh("remainder.dat",processor1TEST.processor1_datapath.data_im.SRAM);
	forever #10ps clk = ~clk;
	end

endmodule
	
