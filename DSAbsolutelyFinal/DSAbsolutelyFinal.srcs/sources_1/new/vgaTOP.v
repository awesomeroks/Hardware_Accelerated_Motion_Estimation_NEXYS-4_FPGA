module vgaTOP(
    input wire clk,             // board clock: 100 MHz on Arty/Basys3/Nexys
    output wire VGA_HS_O,       // horizontal sync output
    output wire VGA_VS_O,       // vertical sync output
    output reg [3:0] VGA_R,    // 4-bit VGA red output
    output reg [3:0] VGA_G,    // 4-bit VGA green output
    output reg [3:0] VGA_B,     // 4-bit VGA blue output
    output reg [6:0] seg,
    output reg [7:0] an,
    output dp,
    input reset
    );
    parameter imageWidth = 96;
    parameter imageHeight = 96;
    parameter imageSize =  imageHeight*imageWidth;
    parameter imageOneStart =  0;
    parameter imageTwoStart =  imageSize;
    parameter pixelWidth  = 23 ;
    parameter addressLength =  13;
    parameter blockWidth  = 16;
    parameter blockHeight =  16;
    parameter blockSize =  blockWidth*blockHeight;
    parameter searchWidth = 16;
    parameter RESET = 0;
    parameter CALCULATING = 1;
    parameter DONE = 2;
    parameter DOUBLEDONE = 3;
    //BLOCKSAD Calculator
    reg [pixelWidth:0] blockSAD = 0 ;
    reg [pixelWidth:0] blockSADFinal = 0 ;
    reg [addressLength:0] addrA = 0;
    reg [addressLength:0] addrB = 0;
    
       
    //BRAM variables
    wire [pixelWidth:0] outA;
    wire [pixelWidth:0] outB;
    reg [addressLength:0] aA;
    reg [addressLength:0] aB;
    
    
    //variables for pixel values of image
    reg [7:0] rA, gA, bA, rB, gB, bB;
    
    //looping integers
    integer ia = 0;
    integer tempi = 0;
    integer j = 0;
    reg [15:0] cnt;
    reg pix_stb;
    reg [14:0] counter = 0;
    reg [14:0] counterB = 0;
    wire [9:0] x;  
    wire [8:0] y;
    wire isDraw;
    wire [23:0] vgaOUT1, vgaOUT2;
    wire [23:0] unused;
    reg [14:0] whiteEndpoint = 0;
    reg writeWhite = 1'b0;
    reg flag= 1 ;
    integer i = 0;
    reg isWrite = 1;
    reg [3:0] sevenSegVal = 0;
    assign dp = 1'b1;
    integer si = 3;
    reg [15:0] displayed_number; // counting number to be displayed
    reg [3:0] LED_BCD;
    reg [19:0] sevenSegRefreshCounter; // 20-bit for creating 10.5ms refresh period or 380Hz refresh rate
    wire [2:0] sevenSegCounter; 
    reg [addressLength:0] endpoint;
    reg [pixelWidth:0] min_sad =  24'b111111111111111111111111; //min SAD of all of the searchArea
    reg [pixelWidth:0] minSADFinal =  0;
    integer  jM = 0;
    integer  iM = 0;
    //VGA display generator
    vga640x480 display (
        .i_clk(clk),
        .i_pix_stb(pix_stb),
        .o_hs(VGA_HS_O), 
        .o_vs(VGA_VS_O),
        .o_active(isDraw), 
        .o_x(x), 
        .o_y(y)
    );
    //BRAM for reading frame 1. One port for calculations, and one port for VGA display
    imageFrame1 frame1(
      //CALCULATIONS READ
      .clka(clk), 
      .wea(1'b0), 
      .addra(aA), 
      .dina(24'b000000001000000000000000), 
      .douta(outA),
      //VGA Frame 1 READ
      .clkb(clk), 
      .web(1'b0), 
      .addrb(counter), 
      .dinb(24'b000000001000000000000000), 
      .doutb(vgaOUT1)
    );
    //BRAM for reading frame 2. Port A for VGA display Read, Port B for endpoint write
    imageFrame2 frame2(
      //READING VGA
      .clka(clk), 
      .wea(1'b0), 
      .addra(counterB), 
      .dina(24'b000000001000000000000000), 
      .douta(vgaOUT2),
      //WRITING
      .clkb(clk), 
      .enb(isWrite),
      .web(writeWhite), 
      .addrb(whiteEndpoint), 
      .dinb(24'b000000001000000000000000), 
      .doutb(unused)
    ); 
    //BRAM for calculations on Frame 2
    imageFrame2Read frame2a( 
      .ena(1'b1),
      .clka(clk), 
      .wea(1'b0), 
      .addra(aB), 
      .dina(24'b000000001000000000000000), 
      .douta(outB)
    );
    
    reg blockSadReset = 1;
    always @(posedge clk)
    begin
        {pix_stb, cnt} <= cnt + 16'h4000;  // divide by 4: (2^16)/4 = 0x4000
        counter <= (x-100) + (y-20)*96;
        counterB <= (x - 200) + (y-20)*96;
        if(isWrite == 1)
        begin
            if(flag == 1)
            begin
                writeWhite <= 1'b1; //make it write only
                // whiteEndpoint <= 5000;
                flag <= 0;
            end
            else
            begin
                writeWhite <= 1'b0; //make it read only
                // isWrite <= 0;
                flag <= 1;
            end
        end
        else
        begin 
            if(((x-200-8)%16 == 0 && (y-20-8)%16 == 0) &&((x-200)<96 &&(y-20)<96))
            begin
                VGA_R <= 4'b0000;
                VGA_G <= 4'b0000;
                VGA_B <= 4'b0000;
            end
            else if(x>100 && y>20 && x<196 && y <116)
            begin
                VGA_R <=  vgaOUT1[23:20];
                VGA_G <=  vgaOUT1[15:12];
                VGA_B <=  vgaOUT1[7:4];
            end
            else if(x>=200 && y>20 && x<296 && y <116)
            begin
                VGA_R <=  vgaOUT2[23:20];
                VGA_G <=  vgaOUT2[15:12];
                VGA_B <=  vgaOUT2[7:4];
            end
            else
            begin
                VGA_R <=  4'b0000;
                VGA_G <=  4'b0000;
                VGA_B <=  4'b0000;
            end
        end
    end
    reg [2:0] programState = CALCULATING;
    reg [2:0] minErrorState = DONE;
    reg [2:0] minErrorSwitchState = DONE;
    reg [2:0] sadSwitchState = DOUBLEDONE;
    reg [2:0] blockSadState = DOUBLEDONE;
    integer randomcounter = 0;
    integer writeFlag = 0;
    integer jT = 0;
    integer iT = 0;
    
    always@(posedge clk)
    begin
        if(minErrorSwitchState == CALCULATING)
            minErrorState <= CALCULATING;
        else if(minErrorSwitchState == DONE)
            minErrorState <= DONE;
        else if(minErrorSwitchState == RESET)
            minErrorState <= RESET;

        if(minErrorState == DONE)
        begin
            if(jT<(imageHeight/blockWidth)) //if block is over, then fix SAD for that block.
            begin       
                randomcounter <= randomcounter + 1;     
                //move to next address?
                minErrorState <= RESET;
                if(iT<(imageHeight/blockWidth)-1) //advance to next pixel (same row,if row is not completely traversed)
                begin
                    iT <= iT + 1;
                    addrA <= addrA + blockWidth;
                end
                else //if row is complete goto next row
                begin
                    if(jT<(imageHeight/blockWidth)-1)
                    begin
                        iT <= 0;
                        jT <= jT+1; 
                        addrA <= addrA + imageHeight*blockWidth - imageWidth + blockWidth;    
                    end
                    else
                        jT <= jT + 1;                                       
                end 
            end
            else 
            begin
                minErrorState <= DOUBLEDONE;
            end  
        end
        else
        begin
            programState <= DOUBLEDONE;
        end
    end

    always @(posedge clk)
    begin 
        if(sadSwitchState == CALCULATING)
            blockSadState <= CALCULATING;
        else if(sadSwitchState == DONE)
            blockSadState <= DONE;
        else if(sadSwitchState == RESET)
            blockSadState <= RESET;
        
        if(minErrorState == RESET)
        begin 
            iM <= 0;
            jM <= 0;
            min_sad <=  24'b111111111111111111111111;
            if( addrA == 0 ) //top left corner
                addrB <= addrA;   
            else if( addrA == imageWidth-blockWidth  ) //topRight corner
                addrB <= addrA-searchWidth-searchWidth ; //move left twice 
            else if( addrA == imageWidth*(imageHeight - blockWidth) ) //bottom left corner
                addrB <= addrA -(searchWidth*2)*imageWidth;   
            else if( addrA ==  (1+imageWidth)*(imageHeight - blockWidth)) //bottom right corner
                addrB <= addrA-(searchWidth*2)*imageWidth-searchWidth-searchWidth  ;   
            else if( addrA > 0 && addrA < imageWidth-blockWidth  ) //top edge
                addrB <= addrA-searchWidth;   
            else if(  addrA > imageWidth*(imageHeight - blockWidth ) && addrA < (1+imageWidth)*(imageHeight - blockWidth) ) //bottom edge 
                addrB <= addrA-(searchWidth*2)*imageWidth-searchWidth  ;   
            else if( addrA %(blockWidth*imageWidth) == 0  ) // left edge
                addrB <= addrA - searchWidth*imageWidth;   
            else if(addrA %(blockWidth*imageWidth) == 176) //right edge
                addrB <= addrA-searchWidth-searchWidth -(searchWidth)*imageWidth  ;
            else //not corner or edge
                addrB <= addrA - searchWidth*imageWidth - searchWidth  ; //aB is the startpoint of searchArea
            minErrorSwitchState <= CALCULATING;
            blockSadState <= RESET;
            writeFlag <= 0;
        end
        else if(blockSadState == DONE)
        begin
                
                if( jM<(searchWidth+searchWidth)) //then fix blockSADFinal for that block.
                begin
                    blockSadState <= RESET;
                    //find min blockSADFinal
                    if(blockSADFinal<min_sad)
                          begin
                            min_sad <= blockSADFinal;
                            endpoint <= aB - blockWidth/2 - (blockWidth/2)*imageWidth; //endpoint of vector
                          end
                    else
                          minSADFinal <= min_sad;                          
                    
                    //move to next address?
                    if( iM<searchWidth+searchWidth-1) //advance to next pixel (same row,if row is not completely traversed)
                    begin
                        iM <=  iM+1;
                        addrB <= addrB +1;
                    end
                    else //if row is complete goto next row
                    begin
                         iM <= 0;
                         jM <=  jM+1;
                         addrB <= addrB + imageWidth-(searchWidth+searchWidth) + 1;  
                    end 
                end
                else 
                begin
                    minSADFinal <= min_sad; //fixate here
                    
                    if(writeFlag == 0)
                    begin
                        whiteEndpoint<=endpoint;
                        isWrite <= 1;
                        writeFlag <= 1;
                    end
                    else
                        isWrite <= 0;

                    minErrorSwitchState <= DONE;
                    blockSadState <= DOUBLEDONE;
                end
            end
        else
        begin
         //TODO
        end
    end
   
    //matcher.v   
    always@(posedge clk)    
    begin
        case(blockSadState)
            RESET: 
                begin
                    aA <= addrA;  
                    aB <= addrB;
                    i <= 0;
                    j <= 0;
                    blockSAD <= 0;
                    
                    sadSwitchState <= CALCULATING;
                end
            CALCULATING: 
                begin
                    
                    if(j<blockWidth) //if block is over, then fix SAD for that block.
                    begin
                        //taking RGB values of pixels from frames A and B of respective addresses
                        rA <= outA[23:16];
                        gA <= outA[15:8];
                        bA <= outA[7:0];
            
                        rB <= outB[23:16];
                        gB <= outB[15:8];
                        bB <= outB[7:0];
                        
                        //implementing SAD (Sum of Absolute Differences) of pixels
                        if (rA>rB) 
                            blockSAD <= blockSAD+rA-rB;
                        else
                            blockSAD <= blockSAD+rB-rA;
                        
                        if (gA>gB) 
                            blockSAD <= blockSAD+gA-gB;
                        else 
                            blockSAD <= blockSAD+gB-gA;
                        
                        if (bA>bB) 
                            blockSAD <= blockSAD+bA-bB;
                        else 
                            blockSAD <= blockSAD+bB-bA;                            
                        //move to next address?
                        if(i<blockWidth-1) //advance to next pixel (same row,if row is not completely traversed)
                        begin
                            i <= i + 1;
                            aA <= aA +1;
                            aB <= aB +1;
                        end
                        else //if row is complete goto next row
                        begin
                            if(j<blockWidth - 1)
                            begin
                                i <= 0;
                                j <= j+1; 
                                aA <= aA + imageWidth-blockWidth + 1;
                                aB <= aB + imageWidth-blockWidth + 1;     
                            end
                            else
                                j <= j + 1;                                       
                        end 
                  end
                    else 
                    begin
                        blockSADFinal <= blockSAD;
                        sadSwitchState <= DONE;
                    end    
                end
            default:
            begin
                blockSADFinal <= blockSAD;
            end    
        endcase        
      end 

    
    //block for seven segment mapping value to display
    wire [32:0] ledDisplay;
//    assign ledDisplay = {10'b0000000000,endpoint};
    assign ledDisplay = {randomcounter};
    always @(*)
    begin
        case(sevenSegCounter)
        3'b111: begin
            an = 8'b11111110; 
                      LED_BCD  = ledDisplay[3:0];
//            LED_BCD =endpoint[3:0];
//           LED_BCD =min_sad[23:20];
              end
        3'b110: begin
            an = 8'b11111101; 
//             LED_BCD =min_sad[19:16];
                LED_BCD  = ledDisplay[7:4];
//                LED_BCD =endpoint[7:4];
              end
        3'b101: begin
            an = 8'b11111011; 
            
            LED_BCD  = ledDisplay[11:8];
//            LED_BCD =min_sad[15:12];
//                LED_BCD =endpoint[11:8];
                end
        3'b100: begin
            an = 8'b11110111; 
           
           LED_BCD  = ledDisplay[15:12];
//             LED_BCD =min_sad[11:8];
//                LED_BCD =endpoint[13:12];
               end
               
        3'b011: begin
            an = 8'b11101111; 
            LED_BCD  = ledDisplay[19:16]; 
//             LED_BCD =min_sad[7:4];
//               LED_BCD =0;
              end
        3'b010: begin
            an = 8'b11011111; 
            LED_BCD  = ledDisplay[23:20];
//            LED_BCD =min_sad[3:0];
//                LED_BCD =0;
              end
        3'b001: begin
            an = 8'b10111111; 
            LED_BCD  = ledDisplay[27:24];
            // LED_BCD =0;
//             LED_BCD =randomcounter[3:0];
                end
        3'b000: begin
            an = 8'b01111111; 
            LED_BCD  = ledDisplay[31:28];
            // LED_BCD =0;    
//             LED_BCD =randomcounter[7:4];
               end
        endcase
    end
    always @(*)
    begin
        case(LED_BCD)
        4'b0000: seg = 7'b1000000; // "0"     
        4'b0001: seg = 7'b1111001; // "1" 
        4'b0010: seg = 7'b0100100; // "2" 
        4'b0011: seg = 7'b0110000; // "3" 
        4'b0100: seg = 7'b0011001; // "4" 
        4'b0101: seg = 7'b0010010; // "5" 
        4'b0110: seg = 7'b0000010; // "6" 
        4'b0111: seg = 7'b1111000; // "7" 
        4'b1000: seg = 7'b0000000; // "8"     
        4'b1001: seg = 7'b0011000; // "9"
        4'b1010: seg = 7'b0001000; // "A" 
        4'b1011: seg = 7'b0000011; // "B"
        4'b1100: seg = 7'b1000110; // "C"
        4'b1101: seg = 7'b0100001; // "D"
        4'b1110: seg = 7'b0000110; // "E" 
        4'b1111: seg = 7'b0001110; // "F"
        default: seg = 7'b1000000; // "0"
        endcase
    end    
    always @(posedge clk or negedge reset)
    begin 
        if(reset==1)
            sevenSegRefreshCounter <= 0;
        else
            sevenSegRefreshCounter <= sevenSegRefreshCounter + 1;
    end 
    assign sevenSegCounter = sevenSegRefreshCounter[19:17];
endmodule