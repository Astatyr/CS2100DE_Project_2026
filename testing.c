// =============================================================================
// Rhythm Game for Nexys 4 / RISC-V CPU
// =============================================================================
//
// DISPLAY LAYOUT  (AN7 = leftmost, AN0 = rightmost):
//
//   AN7   AN6   AN5   AN4   AN3   AN2   AN1   AN0
//  [miss] [ - ] [   ] [   ] [   ] [   ] [   ] [spwn]
//         LINE  <------- notes travel this way ------
//
// AN6 is the permanent LINE ('-').
// Notes spawn at AN0 and travel left one position every tick (~0.5 s).
// A note that is not hit at AN6 shifts to AN7 (leftmost) = MISS.
//
// NOTE TYPES (matching user sequence format):
//   0 = none      (blank, gap in the rhythm)
//   1 = left  '|' → press btnL
//   2 = right '|' → press btnR
//   3 = top   '-' → press btnU
//   4 = bottom'-' → press btnD
//
// SCREENS:
//   Start   : "SEEd XXXX"  where XXXX = 16-bit switch value (hex seed)
//             Press btnC → generate note sequence → start game
//   Game    : 16 LEDs = lives; notes scroll; hit to score
//   GameOver: 7-seg flashes "8888 8888" for ~1 s, then shows score in hex
//             Press btnC → return to start screen
//
// GODBOLT BUILD:
//   Target : RISC-V rv32gc gcc
//   Flags  : -O1 -march=rv32i -mabi=ilp32
//   Then assemble in RARS (compact memory config, text at 0x0).
//
// TIMING:
//   Hardware (clk_cpu = 100 MHz / 16 = 6.25 MHz) : TICK_DELAY = 1000000
//   Simulation (clk_cpu = clk, very fast)          : TICK_DELAY = 50
// =============================================================================

// ── MMIO addresses ────────────────────────────────────────────────────────────
#define LED_ADDR      0x2400
#define DIP_ADDR      0x2404
#define BTN_ADDR      0x2408
#define SEG_ADDR      0x2418
#define SEG_MODE_ADDR 0x241C   // 0 = hex digits, 1 = game segment shapes

// ── Button bitmasks  {27'b0, btnC, btnU, btnL, btnR, btnD} ───────────────────
#define BTN_C  (1 << 4)
#define BTN_U  (1 << 3)
#define BTN_L  (1 << 2)
#define BTN_R  (1 << 1)
#define BTN_D  (1 << 0)

// ── Game-mode segment nibble encoding (SEG_MODE_ADDR = 1) ─────────────────────
// Each nibble of the 32-bit SEG_ADDR word controls one AN display.
// Bit layout: bits[3:0]=AN0 (rightmost), bits[31:28]=AN7 (leftmost).
#define SEG_BLANK   0   // all segments off (empty lane slot)
#define SEG_LINE    1   // middle '-' (permanent line marker at AN6)
#define SEG_TOP     2   // top '-' note     → player must press btnU
#define SEG_BOT     3   // bottom '-' note  → player must press btnD
#define SEG_LEFT    4   // left '|' note    → player must press btnL
#define SEG_RIGHT   5   // right '|' note   → player must press btnR

// ── Note sequence encoding (stored in g_notes[], matches user spec) ───────────
// 0=none, 1=left, 2=right, 3=top, 4=bottom
// Maps 1:1 to user example "01102403" = none,left,left,none,right,bottom,none,top
#define NOTE_NONE   0
#define NOTE_LEFT   1
#define NOTE_RIGHT  2
#define NOTE_TOP    3
#define NOTE_BOT    4

// ── Game constants ────────────────────────────────────────────────────────────
#define MAX_LIVES    16
#define NOTE_COUNT   128    // notes generated per seed (increase for longer games)
#define LANE_SIZE    8      // AN0 (index 0) to AN7 (index 7)
#define LINE_IDX     6      // lane index of the line (AN6, 2nd from left)
#define MISS_IDX     7      // lane index of the miss zone (AN7, leftmost)
#define TICK_DELAY   1000000  // poll iterations per tick; tune for hw vs sim

// ── Lookup: note encoding → SEG nibble ────────────────────────────────────────
// note_to_seg[0]=SEG_BLANK, [1]=SEG_LEFT, [2]=SEG_RIGHT, [3]=SEG_TOP, [4]=SEG_BOT
int note_to_seg[5] = { 0, 4, 5, 2, 3 };

// =============================================================================
// Global state — avoids stack allocation issues on bare-metal RISC-V
// (stack pointer may be uninitialised without OS startup code)
// =============================================================================
volatile int* g_led;
volatile int* g_dip;
volatile int* g_btn;
volatile int* g_seg;
volatile int* g_mode;

int g_lane[LANE_SIZE];    // g_lane[0]=AN0 spawn point, g_lane[7]=AN7 miss zone
int g_lives;
int g_score;
int g_note_idx;           // next note to spawn from g_notes[]
int g_notes[NOTE_COUNT];  // pre-generated rhythm sequence
int g_seed;               // 16-bit value read from DIP switches
unsigned int g_rng;       // xorshift RNG state

// =============================================================================
// RNG — xorshift32, seeded from DIP switches
// =============================================================================
unsigned int rng_next() {
    g_rng ^= g_rng << 13;
    g_rng ^= g_rng >> 17;
    g_rng ^= g_rng << 5;
    return g_rng;
}

// =============================================================================
// Busy-wait delay
// =============================================================================
void delay(int n) {
    volatile int i;
    for (i = 0; i < n; i++) {}
}

// =============================================================================
// Wait for a button to be physically released (prevents re-trigger)
// =============================================================================
void btn_wait_release(int mask) {
    while (*g_btn & mask) {}
}

// =============================================================================
// LED update: lives lost right-to-left.
//   16 lives → 0xFFFF (all on)
//   15 lives → 0xFFFE (rightmost off)
//    0 lives → 0x0000 (all off)
//
//   Formula: (0xFFFF << (16 - lives)) & 0xFFFF
// =============================================================================
void update_leds() {
    unsigned int v;
    if (g_lives <= 0)       v = 0x0000u;
    else if (g_lives >= 16) v = 0xFFFFu;
    else                    v = (0xFFFFu << (16 - g_lives)) & 0xFFFFu;
    *g_led = (int)v;
}

// =============================================================================
// Build the 32-bit segment word from g_lane[0..7].
// Each nibble i controls AN_i (nibble 0 → AN0, nibble 7 → AN7).
// The line at AN6 shows SEG_LINE when its lane slot is empty,
// or the note character when a note is present (so the player sees what to press).
// =============================================================================
unsigned int make_seg_word() {
    unsigned int w = 0;
    int i;
    for (i = 0; i < LANE_SIZE; i++) {
        int v = g_lane[i];
        if (i == LINE_IDX && v == SEG_BLANK) v = SEG_LINE;
        w |= (unsigned int)(v & 0xF) << (i * 4);
    }
    return w;
}

// =============================================================================
// Check whether a button press matches the note at the line
// =============================================================================
int is_hit(int seg_note, int btn) {
    return (seg_note == SEG_TOP   && (btn & BTN_U)) ||
           (seg_note == SEG_BOT   && (btn & BTN_D)) ||
           (seg_note == SEG_LEFT  && (btn & BTN_L)) ||
           (seg_note == SEG_RIGHT && (btn & BTN_R));
}

// =============================================================================
// START SCREEN
// Continuously reads DIP switches and displays "SEEd XXXX" in hex mode,
// where XXXX is the current 4-digit hex switch value.
// Pressing btnC captures the seed and returns.
//
// "SEEd" is encoded using hex digit look-alikes:
//   AN7 = 5  → '5' (looks like 'S')
//   AN6 = E  → 'E' (looks like 'e')
//   AN5 = E  → 'E' (looks like 'e')
//   AN4 = D  → 'd'
//   AN3-AN0  = seed as 4 hex digits
// =============================================================================
void show_start_screen() {
    *g_mode = 0; // hex digit mode (game_mode = 0)
    *g_led  = 0; // LEDs off during start screen

    while (1) {
        g_seed = *g_dip & 0xFFFF;

        // Build "SEEd XXXX": upper 16 bits = 0x5EED, lower 16 bits = seed
        unsigned int word = (0x5EEDu << 16) | (unsigned int)(g_seed & 0xFFFF);
        *g_seg = word;

        if (*g_btn & BTN_C) {
            btn_wait_release(BTN_C); // debounce
            return;                  // seed locked in, move on to generation
        }
    }
}

// =============================================================================
// NOTE GENERATION
// Seeds the RNG with the DIP switch value and fills g_notes[] with a
// rhythm sequence of NOTE_NONE / NOTE_LEFT / NOTE_RIGHT / NOTE_TOP / NOTE_BOT.
//
// Sequence rules:
//   - Every 3rd slot is forced blank to ensure natural gaps (prevents
//     impossible back-to-back notes that the player can't react to).
//   - Remaining slots have a ~60% chance of containing a random note.
// =============================================================================
void generate_notes() {
    int i, gap = 0;
    g_rng = (unsigned int)g_seed;
    if (g_rng == 0) g_rng = 0xDEADBEEFu;

    for (i = 0; i < NOTE_COUNT; i++) {
        unsigned int r = rng_next();
        gap++;
        if (gap == 3) {           // every 3rd slot: forced blank
            gap = 0;
            g_notes[i] = NOTE_NONE;
        } else if ((r & 0xFF) < 154) {
            g_notes[i] = (int)(r % 4) + 1;
        } else {
            g_notes[i] = NOTE_NONE;
        }
    }
}

// =============================================================================
// Advance the game by one tick:
//   1. Shift every note one position left (toward AN7).
//   2. Miss check: if an unhit note has just arrived at AN7, deduct a life.
//   3. Spawn: place the next note from g_notes[] at AN0.
//   4. Refresh the 7-seg display.
// =============================================================================
void tick_advance() {
    int i;

    // 1. Shift all notes left (index increases = moves toward AN7)
    for (i = MISS_IDX; i > 0; i--) {
        g_lane[i] = g_lane[i - 1];
    }
    g_lane[0] = SEG_BLANK;

    // 2. Miss check: an unhit note has just moved to the miss zone (AN7)
    if (g_lane[MISS_IDX] != SEG_BLANK) {
        g_lives--;
        update_leds();
        g_lane[MISS_IDX] = SEG_BLANK; // remove it (not displayed at AN7)
    }

    // 3. Spawn next note from the pre-generated sequence at AN0
    if (g_note_idx < NOTE_COUNT) {
        int n = g_notes[g_note_idx++];
        g_lane[0] = (n >= 0 && n <= 4) ? note_to_seg[n] : SEG_BLANK;
    }

    // 4. Refresh display
    *g_seg = make_seg_word();
}

// =============================================================================
// GAME LOOP
// Runs until all lives are lost. Returns the player's final score.
// =============================================================================
int run_game() {
    int i;

    // Initialise game state
    for (i = 0; i < LANE_SIZE; i++) g_lane[i] = SEG_BLANK;
    g_lives    = MAX_LIVES;
    g_score    = 0;
    g_note_idx = 0;

    *g_mode = 1;         // game segment mode
    update_leds();       // all 16 LEDs on
    *g_seg = make_seg_word();

    while (g_lives > 0) {
        // ── Poll phase ──────────────────────────────────────────────────────
        // Check buttons continuously for one tick window (TICK_DELAY loops).
        // The SevenSegDecoder multiplexes the display in hardware, so we do
        // not need to refresh SEG_ADDR here — it stays valid until next write.
        volatile int t;
        for (t = 0; t < TICK_DELAY; t++) {
            int btn = *g_btn;

            // Centre button = instant reset → return negative score as signal
            if (btn & BTN_C) {
                btn_wait_release(BTN_C);
                return -1; // caller will go back to start screen
            }

            // Hit detection: correct button while note is at the line
            if (g_lane[LINE_IDX] != SEG_BLANK) {
                if (is_hit(g_lane[LINE_IDX], btn)) {
                    g_score++;
                    g_lane[LINE_IDX] = SEG_BLANK; // clear note
                    *g_seg = make_seg_word();       // immediate visual feedback
                }
            }
        }

        // ── Tick phase ───────────────────────────────────────────────────────
        tick_advance();
    }

    return g_score; // lives reached zero: return score for game-over screen
}

// =============================================================================
// GAME-OVER SCREEN
// Flashes "8888 8888" (all segments lit) for ~1 second to signal game over,
// then displays the final score in hex digits.
// Waits for btnC to return to the start screen.
// =============================================================================
void show_game_over(int score) {
    *g_led  = 0x0000; // all lives gone — reinforce with LEDs
    *g_mode = 0;      // hex digit mode so 0x8 → '8' (all segments on)

    // ~1 second flash: 2 × TICK_DELAY ≈ 2 × 0.5 s
    *g_seg = 0x88888888u;  // "8888 8888" — all segments on all 8 displays
    delay(TICK_DELAY * 2);

    // Show final score as hex (e.g. score=42 → rightmost 2 displays show '2A')
    *g_seg = (unsigned int)score;

    // Hold until btnC press to restart
    while (!(*g_btn & BTN_C)) {}
    btn_wait_release(BTN_C);
}

// =============================================================================
// Main
// =============================================================================
int main() {
    g_led  = (volatile int*)LED_ADDR;
    g_dip  = (volatile int*)DIP_ADDR;
    g_btn  = (volatile int*)BTN_ADDR;
    g_seg  = (volatile int*)SEG_ADDR;
    g_mode = (volatile int*)SEG_MODE_ADDR;

    while (1) {
        // 1. Start screen: user sets seed with DIP switches, presses btnC
        show_start_screen();

        // 2. Generate rhythm note sequence from the captured seed
        generate_notes();

        // 3. Run the game; returns score when lives = 0, or -1 if btnC reset
        int result = run_game();

        // 4. If btnC was pressed mid-game, skip game-over and restart
        if (result < 0) continue;

        // 5. Game-over screen: flash, show score, wait for btnC
        show_game_over(result);

        // 6. Outer while(1) loops back to start screen
    }
}
