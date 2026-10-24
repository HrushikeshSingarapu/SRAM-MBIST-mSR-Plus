//============================================================
// Fault Injection  (verification-only behavioural fault model)
//
// One fault is injected at a time (fault_type). All models are
// PERSISTENT-STATE or READ-PATH faults, expressed with the
// standard static/dynamic functional-fault-model (FFM)
// primitives used in the memory-test literature. Data words are
// treated as a single logical cell: logic 0 = all-zero word,
// logic 1 = all-one word (the only values March mSR+ uses).
//
// Fault IDs (fault_type):
//   0  SAF    1  TF     2  CFID   3  CFDRD  4  CFIN   5  RDF
//   6  DRDF   7  IRF    8  CFTR   9  CFWD  10  WDF
//  11  CFDRD_P  (paper-literal reading of CFdrd, see below)
//  12  CFWD_P   (paper-literal reading of CFwd,  see below)
//
// Fault parameters (inputs):
//   fault_address     victim cell (V)
//   aggressor_address aggressor cell (A) - coupling faults only,
//                     must differ from V (otherwise no fault)
//   stuck_at_value    "fv" : see per-model meaning below
//   fault_variant     "fvar": see per-model meaning below
//
// Model definitions (x = fv, a/t = fvar, ~ = logical inversion)
//
//  SAF   cell stuck at fv. Writes are ignored, reads return fv.
//  TF    cell holding fv cannot make the transition fv -> ~fv.
//        (fv=0: up-transition fault, fv=1: down-transition fault)
//  WDF   write destructive: a NON-transition write x over x
//        flips the cell to ~x.
//  RDF   read destructive: reading a cell that holds x flips it
//        to ~x AND returns ~x.
//  DRDF  deceptive read destructive: reading a cell that holds x
//        returns x (correct) but flips the cell to ~x.
//  IRF   incorrect read: reading a cell that holds x returns ~x;
//        the stored value is unchanged.
//  CFIN  inversion coupling: a transition of A from t to ~t
//        (fvar=0: up, fvar=1: down) inverts V.
//  CFID  idempotent coupling: a transition of A from t to ~t
//        forces V to fv.
//  CFTR  transition coupling: while A holds a (fvar), V cannot
//        make the transition fv -> ~fv.
//  CFWD  write-disturb coupling: while A holds a (fvar), a
//        non-transition write x (fv) to V flips V to ~x.
//  CFDRD deceptive-read-destructive coupling: while A holds a
//        (fvar), reading V that holds x (fv) returns x but flips
//        V to ~x.
//
//  Paper-literal variants. Table I of the paper defines CFdrd as
//  "Aggressor read -> disturbs victim" and CFwd as "Aggressor
//  write -> unintended victim write", i.e. in terms of an
//  operation on the AGGRESSOR, whereas the standard FFM models
//  above sensitise on the victim. Both readings are provided and
//  reported separately:
//  CFDRD_P reading A while it holds a (fvar) flips V if V holds
//        x (fv); the read of A itself returns the correct value.
//  CFWD_P  writing the value fvar to A also (unintentionally)
//        writes fvar into V. (fv unused)
//  WDF_P   paper Table I: "word-line activation -> disturbs nearby
//        word-lines". Any access (read or write) to A, i.e. an
//        activation of A's word line, flips V from x (fv) to ~x.
//        (fvar unused)
//
// NOTE ON NAMING: Table I of the reference paper expands some of
// these abbreviations differently from the standard FFM
// literature (e.g. it calls CFid "inversion dominant" and CFin
// "idempotent"; IRF "inversion read fault"; WDF "word-line
// disturb"). Table I gives only one-line definitions, so the
// paper's exact fault models cannot be reproduced literally. The
// definitions above are the standard ones for each abbreviation;
// both an inversion-type and an idempotent-type coupling fault
// are modelled, so the paper's label swap does not change the
// set of behaviours covered.
//
// fault_activated (verification output) is high in a cycle where
// the injected fault actually changes the memory behaviour
// (a read result, a stored write value, or a victim cell). A
// testbench uses it to separate ACTIVATION from DETECTION.
//============================================================

module fault_injection #(
    parameter int ADDR_WIDTH = 4,
    parameter int DATA_WIDTH = 8
)(
    // clk/rst kept for interface compatibility; the model is
    // purely combinational (all state lives in the SRAM cells).
    input logic clk,
    input logic rst,

    //--------------------------------------------------------
    // Current memory operation
    //--------------------------------------------------------

    input logic                  mem_read,
    input logic                  mem_write,

    input logic [ADDR_WIDTH-1:0] addr,

    input logic [DATA_WIDTH-1:0] normal_read_data,
    input logic [DATA_WIDTH-1:0] write_data,

    //--------------------------------------------------------
    // Current content of victim and aggressor cells
    //--------------------------------------------------------

    input logic [DATA_WIDTH-1:0] victim_data,
    input logic [DATA_WIDTH-1:0] aggressor_data,

    //--------------------------------------------------------
    // Fault configuration
    //--------------------------------------------------------

    input logic                  fault_enable,
    input logic [3:0]            fault_type,

    input logic [ADDR_WIDTH-1:0] fault_address,
    input logic [ADDR_WIDTH-1:0] aggressor_address,

    input logic                  stuck_at_value,
    input logic                  fault_variant,

    //--------------------------------------------------------
    // Faulty current operation
    //--------------------------------------------------------

    output logic [DATA_WIDTH-1:0] faulty_read_data,
    output logic [DATA_WIDTH-1:0] faulty_write_data,

    //--------------------------------------------------------
    // Fault-induced write to the victim cell
    //--------------------------------------------------------

    output logic                  fault_write_en,
    output logic [ADDR_WIDTH-1:0] fault_write_addr,
    output logic [DATA_WIDTH-1:0] fault_write_data,

    //--------------------------------------------------------
    // Verification output
    //--------------------------------------------------------

    output logic                  fault_activated
);

    //--------------------------------------------------------
    // Fault IDs
    //--------------------------------------------------------

    localparam logic [3:0] SAF   = 4'd0;
    localparam logic [3:0] TF    = 4'd1;
    localparam logic [3:0] CFID  = 4'd2;
    localparam logic [3:0] CFDRD = 4'd3;
    localparam logic [3:0] CFIN  = 4'd4;
    localparam logic [3:0] RDF   = 4'd5;
    localparam logic [3:0] DRDF  = 4'd6;
    localparam logic [3:0] IRF   = 4'd7;
    localparam logic [3:0] CFTR  = 4'd8;
    localparam logic [3:0] CFWD  = 4'd9;
    localparam logic [3:0] WDF   = 4'd10;
    localparam logic [3:0] CFDRD_P = 4'd11;
    localparam logic [3:0] CFWD_P  = 4'd12;
    localparam logic [3:0] WDF_P   = 4'd13;

    //--------------------------------------------------------
    // Helper values
    //--------------------------------------------------------

    logic [DATA_WIDTH-1:0] fv_word;     // fv   as a data word
    logic [DATA_WIDTH-1:0] fvar_word;   // fvar as a data word

    logic is_victim;        // current access is to the victim
    logic is_aggressor;     // current access is to the aggressor
    logic pair_valid;       // aggressor and victim are distinct

    logic victim_holds_fv;          // victim == x
    logic nontrans_write_fv;        // write x over x to the victim
    logic blocked_transition;       // write ~fv over fv to the victim
    logic aggressor_in_state;       // aggressor == fvar
    logic aggressor_transition;     // write ~fvar over fvar to aggressor

    always_comb begin

        fv_word   = {DATA_WIDTH{stuck_at_value}};
        fvar_word = {DATA_WIDTH{fault_variant}};

        is_victim    = (addr == fault_address);
        pair_valid   = (aggressor_address != fault_address);
        is_aggressor = (addr == aggressor_address) && pair_valid;

        victim_holds_fv    = (victim_data == fv_word);

        nontrans_write_fv  = mem_write && is_victim &&
                             (victim_data == fv_word) &&
                             (write_data  == fv_word);

        blocked_transition = mem_write && is_victim &&
                             (victim_data == fv_word) &&
                             (write_data  == ~fv_word);

        aggressor_in_state = pair_valid &&
                             (aggressor_data == fvar_word);

        aggressor_transition = mem_write && is_aggressor &&
                               (aggressor_data == fvar_word) &&
                               (write_data     == ~fvar_word);

    end

    //--------------------------------------------------------
    // Fault behaviour
    //--------------------------------------------------------

    always_comb begin

        // Fault-free defaults
        faulty_read_data  = normal_read_data;
        faulty_write_data = write_data;

        fault_write_en    = 1'b0;
        fault_write_addr  = fault_address;
        fault_write_data  = victim_data;

        if (fault_enable) begin

            case (fault_type)

                //----------------------------------------------
                // SAF : stuck at fv
                //----------------------------------------------
                SAF: begin
                    if (is_victim) begin
                        faulty_read_data  = fv_word;
                        faulty_write_data = fv_word;
                    end
                end

                //----------------------------------------------
                // TF : cell holding fv cannot go to ~fv
                //----------------------------------------------
                TF: begin
                    if (blocked_transition)
                        faulty_write_data = victim_data;
                end

                //----------------------------------------------
                // CFID : aggressor transition forces victim = fv
                //----------------------------------------------
                CFID: begin
                    if (aggressor_transition) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = fv_word;
                    end
                end

                //----------------------------------------------
                // CFDRD : aggressor in state a; reading victim
                //         holding x returns x, flips victim
                //----------------------------------------------
                CFDRD: begin
                    if (mem_read && is_victim &&
                        aggressor_in_state && victim_holds_fv) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = ~fv_word;
                    end
                end

                //----------------------------------------------
                // CFIN : aggressor transition inverts victim
                //----------------------------------------------
                CFIN: begin
                    if (aggressor_transition) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = ~victim_data;
                    end
                end

                //----------------------------------------------
                // RDF : read flips cell and returns flipped value
                //----------------------------------------------
                RDF: begin
                    if (mem_read && is_victim && victim_holds_fv) begin
                        faulty_read_data = ~fv_word;
                        fault_write_en   = 1'b1;
                        fault_write_data = ~fv_word;
                    end
                end

                //----------------------------------------------
                // DRDF : read returns correct value, flips cell
                //----------------------------------------------
                DRDF: begin
                    if (mem_read && is_victim && victim_holds_fv) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = ~fv_word;
                    end
                end

                //----------------------------------------------
                // IRF : read returns inverted value, cell intact
                //----------------------------------------------
                IRF: begin
                    if (mem_read && is_victim && victim_holds_fv)
                        faulty_read_data = ~fv_word;
                end

                //----------------------------------------------
                // CFTR : aggressor in state a blocks victim fv->~fv
                //----------------------------------------------
                CFTR: begin
                    if (blocked_transition && aggressor_in_state)
                        faulty_write_data = victim_data;
                end

                //----------------------------------------------
                // CFWD : aggressor in state a; non-transition
                //        write x to victim flips it
                //----------------------------------------------
                CFWD: begin
                    if (nontrans_write_fv && aggressor_in_state)
                        faulty_write_data = ~fv_word;
                end

                //----------------------------------------------
                // WDF : non-transition write x over x flips cell
                //----------------------------------------------
                WDF: begin
                    if (nontrans_write_fv)
                        faulty_write_data = ~fv_word;
                end

                //----------------------------------------------
                // CFDRD_P : read of aggressor (holding a) flips
                //           victim holding x
                //----------------------------------------------
                CFDRD_P: begin
                    if (mem_read && is_aggressor &&
                        (aggressor_data == fvar_word) && victim_holds_fv) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = ~fv_word;
                    end
                end

                //----------------------------------------------
                // CFWD_P : writing a to the aggressor also writes
                //          a into the victim
                //----------------------------------------------
                CFWD_P: begin
                    if (mem_write && is_aggressor &&
                        (write_data == fvar_word)) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = fvar_word;
                    end
                end

                WDF_P: begin
                    if ((mem_read || mem_write) && is_aggressor && victim_holds_fv) begin
                        fault_write_en   = 1'b1;
                        fault_write_data = ~fv_word;
                    end
                end

                default: begin
                end

            endcase

        end

    end

    //--------------------------------------------------------
    // Activation indicator (verification only)
    //--------------------------------------------------------

    always_comb begin

        fault_activated =
            (fault_enable &&
             ( (mem_read  && (faulty_read_data  != normal_read_data)) ||
               (mem_write && (faulty_write_data != write_data))       ||
               (fault_write_en && (fault_write_data != victim_data)) ));

    end

endmodule
