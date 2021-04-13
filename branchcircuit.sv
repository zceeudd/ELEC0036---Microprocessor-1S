module branchcircuit(
	input logic [1:0] branch, //this is the control signal 'branch', based on the operation
	//we choose it determines if we should alter PCsrc so as to branch
	input logic zeroflag, //this is the zeroflag output from the ALU
	output logic PCsrc
	);

	//I have determined and drawn the structural circuit model for this branch operation, but
	//will code its operation behaviourally
	
	always_comb
	case({branch,zeroflag})
		3'b000 :PCsrc = 0;
		3'b001 :PCsrc = 1;
		3'b010 :PCsrc = 1;
		3'b011 :PCsrc = 0;
		3'b100 :PCsrc = 0;
		3'b101 :PCsrc = 0;
		3'b110 :PCsrc = 0;
		3'b111 :PCsrc = 0;
	endcase

endmodule