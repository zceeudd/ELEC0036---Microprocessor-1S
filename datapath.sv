module datapath(
	input logic clk,
	input logic we3, //rf write-enable signal
	input logic ALUsrc, //ALU input mux select 
	input logic [4:0] ALUcontrol, //ALU control signal (selects ALU operation)
	output logic ALUcout, //ALU carryout 
	input logic we, //datamemory write enable
	input logic [1:0] regdata, //select signal for 4x1 mux (for selecting rf write data value)
	input logic [1:0] regwrite, //select signal for 4x1 mux (for selecting rf write address)
	input logic j, //select signal for 2x1 mux 'PC_J_MUX' (for selecting jump address if we have a j instruction)
	input logic wehilo, //write enable signal for hi and lo registers (single write enable signal shared by both 
	//for now since we assume they are both written to together)
	input logic jr, //jr select signal for selecting the jr mux 
	input logic multdiv, //This is the select signal for the mux's into the hi and lo registers (chooses between loading from
	//mult or from div)
	input logic [1:0] branch, //this is the control signal for the branch circuit
	output logic [5:0] opcode, //this is the opcode from the instruction, that is to be sent to the control unit
	input logic mod
	);

	//Control signal inputs to this datapath are generated from
	//a controller module	

	//////////////////////INTERNAL SIGNALS//////////////////////
	wire [15:0] pcinput;
	wire [15:0] pcoutput;
	wire [17:0] instructionmemoryoutput; //this is an instruction
	wire [3:0] rfreadaddress1; //4-bit register address (rf input) from instruction
	wire [3:0] rfreadaddress2; //4-bit register address (rf input) from instruction
	//CHECK THIS...
	assign rfreadaddress1 = instructionmemoryoutput[11:8];
	assign rfreadaddress2 = instructionmemoryoutput[7:4];
	wire [3:0] rfwriteaddress; //4-bit register address (rf input) from multiplexer
	//selecting from instruction
	//CHECK THIS...
	wire [3:0] rfwriteaddressoption1;
	assign rfwriteaddressoption1 = instructionmemoryoutput[7:4];
	wire [3:0] rfwriteaddressoption2; 
	assign rfwriteaddressoption2 = instructionmemoryoutput[3:0];
	wire [15:0] rfwritedata; //data to be written to rf (rf input) selected from 16x1 mux
	wire [15:0] rfreadoutput1; //16-bit output read from register file
	wire [15:0] rfreadoutput2; //16-bit output read from register file
	wire zeroflag;
	wire [15:0] ALUinputA; //ALU defined input 'A' is either the rf output or sign-extended immediate
	wire [15:0] signx_immediate; //sign-extended immediate (from instruction)
	wire [15:0] ALUoutput; //ALU output
	wire [15:0] dataoutput; //Data Memory Output
	wire branchsrc; //generated via the branch circuit (i.e.output of branch circuit)
	wire [15:0] J_MUX_INPUT; //zero extended address from j instruction 	
	wire [15:0] hiregout; //16-bit output of the hi register
	wire [15:0] loregout; //16-bit output of the lo register
	wire [15:0] hiregin; //16-bit input of the hi register (selected from a mux depending on whether we do mult or div)
	wire [15:0] loregin; //16-bit input of the lo register (selected from a mux depending on whether we do mult or div)
	wire [31:0] multout; //32-bit output (result of our multiply circuit)
	wire [31:0] divout; //32-bit output (result of our divide circuit)
	wire [15:0] lslout; //16-bit output of logical shift left (logically shifted left by 1 bit) that goes into the 16x1 mux for rf write data 
	wire [15:0] lsrout; //16-bit output of logical shift right (logically shifted right by 1 bit) that goes into the 16x1 mux for rf write data 
	wire [15:0] asrout; //16-bit output of arithematic shift right (logically shifted right by 1 bit, with MSB taking previous MSB value) that
	//goes into the 16x1 mux for rf write data
	wire [15:0] lslVout; //16-bit output of logical shift left VARIABLE (logically shifted by the amount specified by 4 LSB of rf output 2) that goes
	//into the 16x1 mux for rf write data
	wire [15:0] lsrVout; //16-bit output of logical shift right VARIABLE (logically shifted by the amount specified by 4 LSB of rf output 2) that goes
	//into the 16x1 mux for rf write data
	wire [15:0] zerox_immediate; //this is the 16-bit zero extended immediate value from our instruction
	wire [1:0] pcinputmuxsel; //this is the select signal for the pc input mux
	wire [15:0] modout; //modulus output from divider
	wire [15:0] modmuxout; //output of mux for selecting if we should write modulus to rf
	////////////////////////////////////////////////////////////

	assign opcode = instructionmemoryoutput[17:12];

	////////////ZERO EXTENDER - J INSTRUCTION ADDRESS//////////////
	//input signal 'a1' into this mux is the zero (because address isnt signed) extended address in the J instruction
	zeroextender_j data_zeroextender_j(
	.nextended(instructionmemoryoutput[11:0]),.extended(J_MUX_INPUT)
	);
	////////////////////////////////////////////////////////////

	/////////////////////PC INPUT MUX SELECT/////////////////////
	//THIS IS CAUSING ISSUES WITH ENSURING THE J AND JR ARE PROPERLY
	//SHARED ACROSS DATAPATH, CONTROL UNIT AND PROCESSOR1
	//
	logic [1] jism;
	assign jism = j;
	logic [1] jrism;
	assign jrism = jr;
	PCinputselectmux data_PCinputselectmux(
	.out(pcinputmuxsel),.branch(branchsrc),.j(jism),.jr(jrism)
	);
	//instantiates the circuit which takes the branch, j and jr
	//signals and decides what the input to the PC should be based
	//on these
	/////////////////////////////////////////////////////////////

	///////////////////////PC INPUT MUX/////////////////////////
	fourTOone_mux2 PCinputmux(
	.a0(16'b0000000000000001+pcoutput),.a1(16'b0000000000000001+pcoutput+zerox_immediate),.a2(J_MUX_INPUT),.a3(rfreadoutput1),.sel(pcinputmuxsel),.out(pcinput)
	);
	//a0 - simply increment pc
	//a1 - branch: increment of pc added to a branch value
	//specified by instruction immediate
	//a2 - j: jump to address specified by the instruction - this
	//value is bits [11:0] of the instruction which are zero extended
	//to generate a 16-bit value for our PC
	//a3 - jr: jump to an address specified in a register 
	////////////////////////////////////////////////////////////

	/////////////////////////////PC/////////////////////////////
	PC data_PC(
	.clk(clk),.pcnext(pcinput),.pcout(pcoutput)
	);
	////////////////////////////////////////////////////////////

	/////////////////////INSTRUCTION MEMORY/////////////////////
	instructionmemory data_im(
	.a(pcoutput),.rd(instructionmemoryoutput)
	);
	////////////////////////////////////////////////////////////

	///////////////////////REGISTER FILE////////////////////////	
	registerfile data_rf(
	.rd1(rfreadoutput1),.rd2(rfreadoutput2),.clk(clk),.we3(we3),.ra1(rfreadaddress1),
	.ra2(rfreadaddress2),.wa3(rfwriteaddress),.wd3(modmuxout)
	);
	//////////////////////INSTANTIATE ALU///////////////////////
	ALU data_ALU(
	.a(ALUinputA),.b(rfreadoutput1),.ALUcontrol(ALUcontrol),.y(ALUoutput),.Cout(ALUcout),.zeroflag(zeroflag)
	);	
	//what we defined as 'b' for the ALU is the output 1 of the rf
	//what we defined as 'a' for the ALU is either output 2 of the rf or the sign-extended immediate
	/////////////////////ALU INPUT MUX//////////////////////////
	//This is the ALU input MUX that selects ALU input 'A' (rf output or sign-extended immediate)
	twoTOone_mux ALUinputselectmux(
	.a0(rfreadoutput2),.a1(signx_immediate),.sel(ALUsrc),.out(ALUinputA)
	);
	////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////

	////////////////////////BRANCH ZERO EXTENDER////////////////
	//this is for zero extending the immediate - while we already have a signextender for immediate
	//extension for the ALU functionality, when branching the immediate value for branching should
	//be positive which is why we zero extend it
	zeroextender_immediate data_zeroextender_immediate(
	.nextended(instructionmemoryoutput[3:0]),.extended(zerox_immediate)
	);
	////////////////////////////////////////////////////////////

	///////////////////////SIGN-EXTENDER////////////////////////
	sign_extension data_signx_immediate(
	.imm(instructionmemoryoutput[3:0]),.signimm(signx_immediate)
	);
	//'imm' input of sign extender is an index of the instruction (output from im)
	//INDEXING MAY CAUSE PROBLEMS
	////////////////////////////////////////////////////////////

	////////////////////////DATA MEMORY/////////////////////////
	datamemory data_datamemory(
	.clk(clk),.we(we),.a(ALUoutput),.wd(rfreadoutput2),.rd(dataoutput)
	);
	//value written to data memory is only ever the second output from the rf
	////////////////////////////////////////////////////////////

	///////////////////4x1 MUX FOR RF WRITE DATA///////////////
	//This MUX selects the value to be written to the register file
	//MUX is selected with regdata control signal
	fourTOone_mux2 data_rfwritedata_mux(
	.a0(ALUoutput),.a1(dataoutput),.a2(hiregout),.a3(loregout),.sel(regdata),.out(rfwritedata)
	);
	////////////////////////////////////////////////////////////

	/////////////////4x1 MUX FOR RF WRITE ADDRESS///////////////
	//This MUX takes the regwrite signal to determine the RF address to write to
	fourTOone_mux data_rfwriteaddress_mux(
	.a0(rfwriteaddressoption1),.a1(rfwriteaddressoption2),.a2(4'b0000),.a3(4'b0000),.sel(regwrite),.out(rfwriteaddress)
	);
	//INDEX MAY CAUSE ISSUES
	////////////////////////////////////////////////////////////

	/////////HILO REGISTERS (SPECIAL PURPOSE REGISTER)//////////
	twoTOone_mux hiMUX(
	.a0(multout[31:16]),.a1(divout[31:16]),.sel(multdiv),.out(hiregin)
	);
	twoTOone_mux loMUX(
	.a0(multout[15:0]),.a1(divout[15:0]),.sel(multdiv),.out(loregin)
	);	
	//MAY BE INDEXING PROBLEMS
	/////////////////////////HI/////////////////////////////////
	hiloreg data_hi(
	.rd(hiregout),.clk(clk),.wehilo(wehilo),.wd(hiregin)
	);
	/////////////////////////LO/////////////////////////////////
	hiloreg data_lo(
	.rd(loregout),.clk(clk),.wehilo(wehilo),.wd(loregin)
	);
	////////////////////////////////////////////////////////////

	//////////////////////BRANCH CIRCUIT////////////////////////
	//Branch circuit determines branchsrc
	branchcircuit data_branchcircuit(
	.branch(branch),.zeroflag(zeroflag),.PCsrc(branchsrc)	
	);
	//branch is a control signal generated from the control unit
	////////////////////////////////////////////////////////////

	//////////////////////MULTIPLIER////////////////////////////
	multiply data_multiply(
	.a(rfreadoutput1),.b(rfreadoutput2),.y(multout)
	);
	//The multiplication function carried out by the multiply module is coded behaviourally - the structural model for multiplication
	//is complicated
	////////////////////////////////////////////////////////////

	////////////////////////DIVIDE//////////////////////////////
	/////NEED TO DO THIS - TEMPORARILY USING MULTIPLY AGAIN/////
	divide data_divide(
	.a(rfreadoutput1),.b(rfreadoutput2),.y(divout),.mod(modout)
	);
	////////////////////////////////////////////////////////////

	/////////////////////MOD MUX////////////////////////////////
	//mux for selecting whether to write modulus to RF
	twoTOone_mux data_modmux(
	.a0(rfwritedata),.a1(modout),.sel(mod),.out(modmuxout)
	);
	/////////////////////////////////////////////////////////////
	

endmodule