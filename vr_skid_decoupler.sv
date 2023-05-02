// -----------------------------------------------------------------------------
// Module name: vr_skid_decoupler
// HDL        : System Verilog
// Author     : Alin Parcalab (AP)
// Description: The main task of this module is to help with timing closure 
//              between modules that uses valid ready interfaces (like AXI stream)
// Date       : 01 May, 2023
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module vr_skid_decoupler #
(  // ------------------------------------------
   // ------- Module Parameters  ---------------
   // ------------------------------------------ 
	parameter DATA_W = 32,                     // Data Width
	parameter TP     = 1                       // Time propagation
)( // ------------------------------------------
   
   // ------------------------------------------ 
   // ------- System IO ------------------------
   // ------------------------------------------   
   input  logic              clk_i,           // Clock
   input  logic              rsn_i,           // Asynchronous Reset Active low '0'
   input  logic              clr_i,           // Synchronous Reset Active high '1'
   // ------------------------------------------
   
   // ------------------------------------------
   // ------- RX Vld - Rdy Itf -----------------
   // ------------------------------------------
   input  logic [DATA_W-1:0] rx_data_i,       // Rx Data
   input  logic              rx_vld_i,        // Rx Data Valid
   output logic              rx_rdy_o,        // Rx Rdy For Data
   // ------------------------------------------

   // ------------------------------------------
   // ------- TX Vld - Rdy Itf -----------------
   // ------------------------------------------
   output logic [DATA_W-1:0] tx_data_o,       // Tx Data  
   output logic              tx_vld_o,        // Tx Data Valid  
   input  logic              tx_rdy_i         // Tx Rdy For Data  
); // ------------------------------------------

   // ------------------------------------------
   // ------- Internal Signals -----------------
   // ------------------------------------------

   // "_n" -> comb 
   // "_q" -> Flop

   logic [DATA_W-1:0] 
         skid_buff_q, tx_data_q;

   logic rx_rdy_q, tx_vld_q, skid_q;
   // ------------------------------------------

   // ------------------------------------------
   // ------- Output Signals -------------------
   // ------------------------------------------
   assign rx_rdy_o = rx_rdy_q; 
   assign tx_vld_o = tx_vld_q;
   assign tx_data_o = tx_data_q;
   // ------------------------------------------

   // ------------------------------------------
   // ------- Skid Control ---------------------
   // ------------------------------------------
   always_ff @(posedge clk_i or negedge rsn_i) // Asynchronous reset "rsn_i" Active Low '0'
   if (!rsn_i || clr_i /**************/) skid_q <= #(TP) 1'b0; else // Synchronous reset Active High '1'
   if (tx_rdy_i /*********************/) skid_q <= #(TP) 1'b0; else // if the consumer is ready for data, the skid is not needed
   if (rx_rdy_q && tx_vld_q && rx_vld_i) skid_q <= #(TP) 1'b1;      // skid is needed if rx_ready, rx_valid, and tx_vld are high and tx_rdy is low
   // ------------------------------------------                    // in this case, skid will latch the incoming data while tx_data will keep the current data that wasn't taken yet

   // ------------------------------------------
   // ------- Rx Rdy Control -------------------
   // ------------------------------------------
   always_ff @(posedge clk_i or negedge rsn_i) // Asynchronous reset "rsn_i" Active Low '0'
   if (!rsn_i || clr_i /***************/) rx_rdy_q <= #(TP) 1'b1; else // Synchronous reset Active High '1'
   if ((rx_vld_i && !tx_rdy_i) || skid_q) rx_rdy_q <= #(TP) 1'b0; else // rx_rdy goes low if incoming data is ready and the consumer is not ready to take the incoming data or if the skid is busy
   if (/***********/ tx_rdy_i /********/) rx_rdy_q <= #(TP) 1'b1;      // rx_rdy goes high if the consumer is ready to take the data if skid data was read by the consumer
   // ------------------------------------------

   // ------------------------------------------
   // ------- Tx Vld Control -------------------
   // ------------------------------------------
   always_ff @(posedge clk_i or negedge rsn_i) // Asynchronous reset "rsn_i" Active Low '0'
   if (!rsn_i || clr_i /**************/) tx_vld_q <= #(TP) 1'b0; else // Synchronous reset Active High '1'
   if ((rx_vld_i && rx_rdy_q) || skid_q) tx_vld_q <= #(TP) 1'b1; else // tx_vld goes high if incoming data is valid and rx_rdy is high or if the skid is busy
   if ( tx_vld_q && tx_rdy_i /********/) tx_vld_q <= #(TP) 1'b0;      // tx_vld goes low if the data is valid, the consumer is ready to take the data and there is no incoming data 
   // ------------------------------------------

   // ------------------------------------------
   // ------- Tx Data --------------------------
   // ------------------------------------------
   always_ff @(posedge clk_i or negedge rsn_i) // Asynchronous reset "rsn_i" Active Low '0'
   if (!rsn_i /**************************************/) tx_data_q <= #(TP) 0 /*******/; else // Synchronous reset Active High '1'
   if (skid_q && tx_rdy_i /**************************/) tx_data_q <= #(TP) skid_buff_q; else // tx_data takes the skid_buff Data if the skid is high and if the consumer read the current data
   if (rx_vld_i && rx_rdy_q && (!tx_vld_q || tx_rdy_i)) tx_data_q <= #(TP) rx_data_i  ;      // tx_data takes the incoming data if rx_valid and rx_rdy are high and if there is no output data 
   // ------------------------------------------                                             // or if the consumer is ready to take the output data 

   // ------------------------------------------
   // ------- Skid Buffer ----------------------
   // ------------------------------------------
   always_ff @(posedge clk_i or negedge rsn_i) // Asynchronous reset "rsn_i" Active Low '0'
   if (!rsn_i /************************************/) skid_buff_q <= #(TP) 0 /*****/; else // Synchronous reset Active High '1'
   if (!tx_rdy_i && rx_rdy_q && tx_vld_q && rx_vld_i) skid_buff_q <= #(TP) rx_data_i;      // skid condition, if the incoming data is valid and the unit is ready for the incoming data, and the current output data is still valid 
   // ------------------------------------------                                           // and the consumer drops the ready signal then the skid_buffer will save the incoming data instead of losing it

endmodule : vr_skid_decoupler