module vga_bird (
    input  logic        clk,
    input  logic        reset,

    // Avalon-MM slave interface
    input  logic [1:0]  address,
    input  logic        write,
    input  logic [31:0] writedata,
    input  logic        chipselect,

    // Output to VGA controller (via Conduit)
    output logic [9:0]  bird_x,
    output logic [9:0]  bird_y
);

    // Internal registers
    logic [9:0] x_reg;
    logic [9:0] y_reg;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x_reg <= 10'd0;
            y_reg <= 10'd0;
        end else if (chipselect && write) begin
            case (address)
                2'd0: x_reg <= writedata[9:0];
                2'd1: y_reg <= writedata[9:0];
                default: ;
            endcase
        end
    end

    assign bird_x = x_reg;
    assign bird_y = y_reg;

endmodule

