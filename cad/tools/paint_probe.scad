// Echoes the r5 paint-relevant dimensions so paint.py never hardcodes a number that common.scad
// already owns.  Driven by cad/tools/paint.py; runnable on its own for a quick look:
//   openscad -D R5=true -o /tmp/x.csg cad/tools/paint_probe.scad
include <../common.scad>
assert(R5, "the paint schemes are r5: use -D R5=true");

echo(P_W = R5_W);
echo(P_L = R5_L);
// the deck's plate is larger than the cassette (HOST_TOP / R5_DECK_* in common.scad): its own
// outline, centred on the cassette, in the cassette frame (so x0/y0 are negative)
echo(P_DECK_W = R5_DECK_W);
echo(P_DECK_L = R5_DECK_L);
echo(P_DECK_X0 = R5_DECK_X0);
echo(P_DECK_Y0 = R5_DECK_Y0);
echo(P_DECK_R = R5_DECK_R);
echo(P_DECK_T = R5_DECK_T);

echo(P_KB_X0 = R5_KB_X0);
echo(P_KB_Y0 = R5_KB_Y0);
echo(P_KB_W = R5_KB_POCKET[0]);
echo(P_KB_H = R5_KB_POCKET[1]);
echo(P_KB_R = R5_KB_CORNER + R5_KB_CLR);

echo(P_OLED_X0 = R5_OLED_WIN_X0);
echo(P_OLED_Y0 = R5_OLED_WIN_Y0);
echo(P_OLED_W = R5_OLED_WIN[0]);
echo(P_OLED_H = R5_OLED_WIN[1]);

echo(P_OPEN_X0 = R5_OPEN_X0);
echo(P_OPEN_X1 = R5_OPEN_X1);
echo(P_OPEN_D = R5_OPEN_D);

echo(P_FB_X = R5_FB_X + 6);
echo(P_FB_Y = R5_FB_Y + R5_FB_HOLE_Y0);
echo(P_FB_W = 16);
echo(P_FB_H = 10);

echo(P_FAN_X = DECK_FAN_CTRL[0][0]);
echo(P_FAN_Y = DECK_FAN_CTRL[0][1]);
echo(P_FAN_D = DECK_FAN_D);
echo(P_FAN_BARS = DECK_GRILL_BARS);
echo(P_FAN_BAR = DECK_GRILL_BAR);

echo(P_COVER_W = COVER_W);
echo(P_COVER_L = COVER_L);
echo(P_COVER_R = COVER_R);
echo(P_COVER_T = COVER_T);
echo(P_C_FRAME = COVER_FRAME);
echo(P_C_GAP = COVER_GAP);
echo(P_PANEL_X = PANEL_X);
echo(P_PANEL_Y = PANEL_Y);
echo(P_DISP_W = R5_PANEL[0]);
echo(P_DISP_H = R5_PANEL[1]);
echo(P_DISP_R = R5_PANEL[2]);
echo(P_ACTIVE_W = R5_PANEL_ACTIVE[0]);
echo(P_ACTIVE_H = R5_PANEL_ACTIVE[1]);
// the button is on the deck now, so it is a deck feature, not a cover one
echo(P_BTN_X = R5_BTN_X);
echo(P_BTN_Y = R5_BTN_Y);
echo(P_BTN_D = R5_BTN_D);
echo(P_BTN_BODY = R5_BTN_BODY);
echo(P_CHG_X = R5_CHG_X);
echo(P_CHG_Y = R5_CHG_Y);
echo(P_CHG_D = R5_CHG_D);
echo(P_CHG_NUT_D = R5_CHG_NUT_D);
echo(P_SLOT_A = COVER_FRAME + 11);
echo(P_SLOT_B = COVER_W - COVER_FRAME - 11);
echo(P_SLOT_Y = COVER_L - COVER_FRAME - 5);

echo(P_DH_IX = R5_DISP_HOLE_IX);
echo(P_DH_IY = R5_DISP_HOLE_IY);
echo(P_DH_SPAN_X = R5_PANEL_HOLES[0]);
echo(P_DH_SPAN_Y = R5_PANEL_HOLES[1]);
// the DSI notch: from the cover's hinge edge to the panel, through bezel wall and plate
echo(P_CABLE_X = PANEL_X + R5_CABLE_X0);
echo(P_CABLE_Y = 0);
echo(P_CABLE_W = R5_CABLE_W);
echo(P_CABLE_H = PANEL_Y - COVER_GAP);

echo(P_S0 = R5_SCREWS[0][0]); echo(P_S0Y = R5_SCREWS[0][1]);
echo(P_S1 = R5_SCREWS[1][0]); echo(P_S1Y = R5_SCREWS[1][1]);
echo(P_S2 = R5_SCREWS[2][0]); echo(P_S2Y = R5_SCREWS[2][1]);
echo(P_S3 = R5_SCREWS[3][0]); echo(P_S3Y = R5_SCREWS[3][1]);
echo(P_S4 = R5_SCREWS[4][0]); echo(P_S4Y = R5_SCREWS[4][1]);
echo(P_S5 = R5_SCREWS[5][0]); echo(P_S5Y = R5_SCREWS[5][1]);
echo(P_S6 = R5_SCREWS[6][0]); echo(P_S6Y = R5_SCREWS[6][1]);

cube(1);
