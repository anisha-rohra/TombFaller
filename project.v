`timescale 1ns/1ns

module project(CLOCK_50, KEY, SW, PS2_CLK, PS2_DAT, VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_R, VGA_G, VGA_B, LEDR, HEX0, HEX1, HEX2, HEX3);
	
	input CLOCK_50;
	input [3:0] KEY;
	input [9:0] SW;
	output [9:0] LEDR;
	output [6:0] HEX1;
	output [6:0] HEX2;
	output [6:0] HEX3;

	input PS2_CLK, PS2_DAT;
	output VGA_CLK;   				//	VGA Clock
	output VGA_HS;					//	VGA H_SYNC
	output VGA_VS;					//	VGA V_SYNC
	output VGA_BLANK_N;				//	VGA BLANK
	output VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   			//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 		//	VGA Green[9:0]
	output	[9:0]	VGA_B;   			//	VGA Blue[9:0]

	wire writeEN, count, start, add_x, subtract_x, add_y, subtract_y, erase, create, done;
	
	wire go, stop, reset, clock, box1, create_wait;
	
	assign go = ~KEY[1];
	assign reset = KEY[0];
	
	wire [7:0] x, x_reg, original_x;
	wire [6:0] y, y_reg, original_y;
	wire [2:0] colour;
	wire [4:0] draw_counter;
	wire [7:0] history1, history2;
	
	ps2lab1 p9(
		.CLOCK_50(CLOCK_50),
		.history1(history1),
		.history2(history2),
		.HEX0(HEX0),
		.HEX1(HEX1),
		.HEX2(HEX2),
		.HEX3(HEX3),
		.PS2_CLK(PS2_CLK),
		.PS2_DAT(PS2_DAT)
	);
	
	signals s0(
		.clock(CLOCK_50),
		.up(up),
		.down(down),
		.right(right),
		.left(left),
		.history1(history1),
		.history2(history2),
		.reset(reset)
	);
	
	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(reset),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEN),
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
	
	 defparam VGA.RESOLUTION = "160x120";
	 defparam VGA.MONOCHROME = "FALSE";
	 defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
 	 defparam VGA.BACKGROUND_IMAGE = "black.mif";
	
	// fsm with states
	control co ( 
		.go(go),
		.stop(stop),
		.reset(reset),
		.down(down),
		.left(left),
		.right(right),
		.up(up),
		.count(count),
		.clock(clock),
		.writeEN(writeEN),
		.start(start),
		.colour(colour),
		.draw_counter(draw_counter),
		.add_x(add_x),
		.subtract_x(subtract_x),
		.add_y(add_y),
		.subtract_y(subtract_y),
		.erase(erase),
		.create(create),
		.done(done),
		.create_wait(create_wait)
		// memory stuff
		/*.collision_check(collision_check),
		.done_reading(done_reading)*/
	);

	datapath d0 (
		// control signals
		.clock(clock),
		.reset(reset), 
		// datapath inputs
		.count(count),
		.start(start),
		.draw_counter(draw_counter),
		.add_x(add_x),
		.add_y(add_y),
		.subtract_x(subtract_x),
		.subtract_y(subtract_y),
		//datapath reg outputs
		.x(x), 
		.y(y), 
		.x_reg(x_reg),
		.y_reg(y_reg),
		.original_x(original_x),
		.original_y(original_y),
		.box1(box1),
		.create_wait(create_wait)
		//memory stuff
		/*.xycoords_read(xycoords_read),
		.stop(stop),
		.address(sprite_address),
		.collision_check(collision_check),
		.wren(wren),
		.done_reading(done_reading),
		.up(up),
		.down(down),
		.right(right),
		.left(left)*/
	);

	terminator t0 (
		.clock(clock),
		.x(x),
		.y(y),
		.reset(reset),
		.stop(stop)	
	);
	
	RateDivider rate_divider(
		.clk(CLOCK_50),
		.clear_b(reset),
		.enable(clock)
	);

endmodule

module control(go, reset, up, down, left, right, clock, writeEN, start, stop, colour, create_wait,
draw_counter, add_x, subtract_x, count, add_y, subtract_y, erase, create, done, box1, create_wait//, done_reading, collision_check
);

	// control inputs
	input clock, reset;
	// input from user
	input up, down, left, right;
	//input done_reading;
	// signals to states
	input go, stop;
	output reg done;
	// signals to counter?
	output reg writeEN, start, erase, create, count;
	// signals to change pixel coords
	output reg add_x, subtract_x, add_y, subtract_y, box1, create_wait;
	// output reg collision_check;
	output reg [4:0] draw_counter;
	output reg [2:0] colour;
	reg [4:0] current_state, next_state;
	
	localparam START = 5'b00000,
		CREATE = 5'b00001,
		DRAW = 5'b00010,
		TERMINATE = 5'b00101,
		ERASE = 5'b00110,
		UP = 5'b00111,
		DOWN = 5'b01000,
		LEFT = 5'b01010,
		RIGHT = 5'b01011,
		ERASE_WAIT = 5'b01100,
		DRAW_WAIT = 5'b00011,
		CREATE_WAIT = 5'b10000,
		BOX1 = 5'b00100,
		BOX_DRAW = 5'b10001;

	// combinational logic
	always @(*) 
	begin
		case(current_state)
			START: next_state = go ?  BOX1 : START;
			BOX1: begin
				next_state = BOX_DRAW;
			end
			BOX_DRAW: next_state = done ? CREATE_WAIT : BOX_DRAW;
			CREATE_WAIT: begin 
				next_state = CREATE;
			end
			CREATE: begin
				if (done) begin
					next_state = ERASE_WAIT;
				end
				else
					next_state = CREATE;
			end
			ERASE_WAIT: begin
				if ((up == 1'b1 | down == 1'b1 | right == 1'b1 | left == 1'b1)) begin
					next_state = ERASE;
				end
				else
					next_state = ERASE_WAIT;
			end
			ERASE: 
			begin 
				if (done == 1'b1) 
				begin
					if (up == 1'b1) 
						next_state = UP;
					else if (down == 1'b1) 
						next_state = DOWN;
					else if (right == 1'b1) 
						next_state = RIGHT;
					else if (left == 1'b1)
						next_state = LEFT;
				end 
				else
					next_state = ERASE;
			end
			UP: next_state = DRAW_WAIT;
			DOWN: next_state = DRAW_WAIT;
			RIGHT: next_state = DRAW_WAIT;
			LEFT: next_state = DRAW_WAIT;
			DRAW_WAIT: 
			begin
				//if (done_reading == 1'b1) begin
					if (stop == 1'b1) begin
						next_state = TERMINATE;
					end else if (~up & ~down & ~right & ~left) begin
						next_state = DRAW;
					end else begin
						next_state = DRAW_WAIT;
					end
				//end
			end
			DRAW: 
			begin
				if (done == 1'b1) begin
					next_state = ERASE_WAIT;
				end
				else
					next_state = DRAW;
			end
			TERMINATE : 
			begin
				if (done == 1'b1)
					next_state = START;
				else
					next_state = TERMINATE;
			end
		default: next_state = START;
		endcase
	end

	// sequential logic (output logic aka all of our datapath control signals?)
	always @(*) 
	begin
		count = 1'b0;
		writeEN = 1'b0;
		start = 1'b0;
		colour = 3'b0;
		add_x = 1'b0;
		add_y = 1'b0;
		subtract_x = 1'b0;
		subtract_y = 1'b0;
		erase = 1'b0;
		create = 1'b0;
		box1 = 1'b0;
		create_wait = 1'b0;
		//collision_check = 1'b0;

		case(current_state)
			START: 
				start = 1'b1;
			ERASE: 
			begin
				count = 1'b1;
				writeEN = 1'b1;
				erase = 1'b1;
			end
			ERASE_WAIT: 
				colour = 3'b111;
			CREATE_WAIT:
				create_wait = 1'b1;
			CREATE: 
			begin
				count = 1'b1;
				writeEN = 1'b1;
				colour = 3'b111;
				create = 1'b1;
			end
			BOX1: 
				box1 = 1'b1;
			BOX_DRAW:
			begin
				count = 1'b1;
				writeEN = 1'b1;
				colour = 3'b110;
			end
			UP: 
				add_y = 1'b1;
			DOWN: 
				subtract_y = 1'b1;
			RIGHT: 
				add_x = 1'b1;
			LEFT: 
				subtract_x = 1'b1;
			DRAW: 
			begin
				count = 1'b1;
				writeEN = 1'b1;
				colour = 3'b111;
			end
			//DRAW_WAIT: 
				//collision_check = 1'b1;
			TERMINATE: 
			begin
				count = 1'b1;
				writeEN = 1'b1;
			end
		endcase
	end

	// combinational logic
	always @(posedge clock) 
	begin
		if (!reset) 
		begin
			draw_counter <= 5'b0;
			current_state <= START;
			done <= 1'b0;
		end 
		else if (current_state == CREATE | current_state == DRAW | current_state == TERMINATE | current_state == ERASE | current_state == BOX_DRAW) begin
			if (draw_counter <= 5'b01111) begin
				draw_counter <= draw_counter + 1'b1;
				//done <= 1'b0;
			end 
			else begin
				draw_counter <= 5'b0;
				done <= 1'b1;
			end
			current_state <= next_state;
		end 
		else 
		begin
			draw_counter <= 5'b0;
			done <= 1'b0;
			current_state <= next_state;
		end
	end

endmodule

module datapath(clock, reset, start, x, y,// up, down, left, right
draw_counter, add_x, subtract_x, add_y, subtract_y, count, x_reg, y_reg, original_x, original_y, box1, create_wait// stop, done_reading, collision_check, wren, address, xycoords_read
);

	input clock, reset, count, start, add_x, subtract_x, add_y, subtract_y, box1, create_wait;
	//input collision_check, up, down, left, right;
	input [4:0] draw_counter;
	
	//output reg done_reading, stop, wren;
	//input [14:0] xycoords_read;
	//output reg [4:0] address;
	
	output reg [7:0] x;
	output reg [6:0] y;

	output reg [7:0] x_reg;
	output reg [6:0] y_reg;

	output reg [7:0] original_x;
	output reg [6:0] original_y;

	reg stop_add_y, stop_add_x, stop_sub_y, stop_sub_x;
	//reg [3:0] i;
	
	always @(posedge clock) 
	begin
		if (!reset) 
		begin
			x_reg <= 8'b0;
			y_reg <= 7'b0;
			original_x <= 8'b0;
			original_y <= 7'b0;
			stop_add_y <= 1'b1;
			stop_add_x <= 1'b1;
			stop_sub_x <= 1'b1;
			stop_sub_y <= 1'b1;
		end
		else 
		begin
			if (add_y == 1'b1 & stop_add_y == 1'b1) 
			begin
				y_reg <= original_y - 1'b1;
				original_y <= original_y - 1'b1;
				stop_add_y <= 1'b0;
			end
			else if (subtract_y == 1'b1 & stop_sub_y == 1'b1) 
			begin
				original_y <= original_y + 1'b1;
				y_reg <= original_y + 1'b1;
				stop_sub_y <= 1'b0;
			end
			else if (add_x == 1'b1 & stop_add_x == 1'b1) 
			begin
				original_x <= original_x + 1'b1;
				x_reg <= original_x + 1'b1;
				stop_add_x <= 1'b0;
			end
			else if (subtract_x == 1'b1 & stop_sub_x == 1'b1) 
			begin
				original_x <= original_x - 1'b1;
				x_reg <= original_x - 1'b1;
				stop_sub_x <= 1'b0;
			end
			else if (box1 == 1'b1)
			begin
				original_x <= 0;
				x_reg <= 0;
				original_y <= 0;
				y_reg <= 0;
			end
			else if (create_wait == 1'b1)
			begin
				original_x <= 80;
				x_reg <= 80;
				original_y <= 60;
				y_reg <= 60;
			end
			else if (count == 1'b1) 
			begin
				x_reg <= original_x + draw_counter[1:0];
				y_reg <= original_y + draw_counter[3:2];
				stop_add_x = 1'b1;
				stop_add_y = 1'b1;
				stop_sub_x = 1'b1;
				stop_sub_y = 1'b1;
			end
			// Check whether potential move is out of bounds. If yes,
			// signal to stop.
			/*else if (collision_check == 1'b1)
			begin
				wren <= 1'b0;
				address <= 5'b00000;
				begin
					if (up == 1'b1) 
					begin
						if(y == 13)
							stop <= 1'b1;
						for(i = 0; i < 1'd5; i = i + 1)
						begin
						//if(xy_coords_read[6:0] > 0)
						//if(xy_coords_read[6:0] > (y - 2'b11))
							// activate drawing new pixel
							// xy_coords_read[6:0] <= xy_coords_read[6:0] - 1'b1;
							if(xycoords_read[6:0] == (y - 2'b11)) // collision occurs
								stop <= 1'b1;
							address <= address + 1'b1;
						end
						done_reading <= 1'b1;
					end
					else if (down == 1'b1) 
					begin
						if(y == 100)
							stop <= 1'b1;
						for(i = 0; i < 1'd5; i = i + 1)
						begin
						//if(xy_coords_read[6:0] < 3'd116)
						//if(y < xy_coords_read[6:0] < (y + 2'b11))
							// activate drawing new pixel
							//xy_coords_read[6:0] <= xy_coords_read[6:0] + 1'b1;
							if(xycoords_read[6:0] == (y + 2'b11)) // collision occurs
								stop <= 1'b1;
							address <= address + 1'b1;
						end
						done_reading <= 1'b1;
					end
					else if (right == 1'b1) 
					begin
						if(x == 150)
							stop <= 1'b1;
						for(i = 0; i < 1'd5; i = i + 1)
						begin
						//if(xy_coords_read[14:7] < 3'd155)
							//if(xy_coords_read[14:7] < 3'd155)
							//	xy_coords_read[14:7] <= xy_coords_read[14:7] + 1'b1;
							if(xycoords_read[14:7] == (x + 2'b11))
								stop <= 1'b1;
							address <= address + 1'b1;
						end
						done_reading <= 1'b1;
					end
					else if (left == 1'b1) 
					begin
						if(x == 5)
							stop <= 1'b1;
						for(i = 0; i < 1'd5; i = i + 1)
						begin
							//if(xy_coords_read[14:7] > 3'b100)
							//	xy_coords_read[14:7] <= xy_coords_read[14:7] - 1'b1;
							if(xycoords_read[14:7] == (x - 2'b11))
								stop <= 1'b1;				
							address <= address + 1'b1;
						end
						done_reading <= 1'b1;
					end
				end
			end*/
			x <= x_reg;
			y <= y_reg;
		end
	end

endmodule

module terminator(clock, reset, x, y, stop);

	input clock, reset;
	input [7:0] x;
	input [6:0] y;
	output reg stop;

	always @(posedge clock) begin
		if (!reset) begin
			stop <= 1'b0;
		end
		else if (x == 4 | x == 156 | y == 104 | y == 12) begin
			stop <= 1'b1;
		end else begin
			stop <= 1'b0;
		end
	end

endmodule

module RateDivider(clk, enable, clear_b);
	input clk;
	input clear_b;
	output enable;
	
	reg [50:0]q;
	
	always@(posedge clk)
	begin
		if(clear_b == 1'b0)
			q <= 50_000_000;
		else if(q != 50'b0)
			q <= q - 1'b1;
		// set to automatically ParLoad - may want to adjust these settings
		else if(q == 50'b0)
			q <= 50_000_000;
	end

	// from lab handout - adjust width based on counter
	assign enable = ((q == 50'b0) ? 1 : 0);

endmodule

module signals(up, down, left, right, history1, history2, clock, reset);

	output reg up, down, left, right;
	input [7:0] history1, history2;
	input clock, reset;
	
	always @(posedge clock) begin
		if (!reset) begin
			up <= 1'b0;
			down <= 1'b0;
			right <= 1'b0;
			left <= 1'b0;
		end
		else if (history2[7:4] != 4'hf & history2[3:0] != 4'h0 & history1[7:4] == 4'h1 & history1[3:0] == 4'hd) begin
			up <= 1'b1;
		end
		else if (history2[7:4] != 4'hf & history2[3:0] != 4'h0 & history1[7:4] == 4'h1 & history1[3:0] == 4'hc) begin
			left <= 1'b1;
		end
		else if (history2[7:4] != 4'hf & history2[3:0] != 4'h0 & history1[7:4] == 4'h2 & history1[3:0] == 4'h3) begin
			right <= 1'b1;
		end
		else if (history2[7:4] != 4'hf & history2[3:0] != 4'h0 & history1[7:4] == 4'h1 & history1[3:0] == 4'hb) begin
			down <= 1'b1;
		end
		else if (history2[7:4] == 4'hf & history2[3:0] == 4'h0) begin
			up <= 1'b0;
			down <= 1'b0;
			right <= 1'b0;
			left <= 1'b0;
		end
	end

endmodule
