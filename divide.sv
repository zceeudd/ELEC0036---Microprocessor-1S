module divide#(parameter N=16)
	(
	input logic [N-1:0] a,b,
	output logic [2*N-1:0] y,
	output logic [N-1:0] mod
	);
	assign y  = a/b;
	//divider coded behaviourally
	assign mod = a%b;
endmodule