// R6 PROTOTYPE paint geometry: fit/layout artwork only, not paint-ready production masks.
// The visible surfaces swap against R5: the cover is the keyboard lid; the deck is the
// cassette's Waveshare 7-inch display frame.  Component dimensions and the host/plate outlines
// come from common.scad.  Proposed R6-only placements are named here, not hidden in paint.py.
// The keyboard-lid parameters are now shared with r6_lid_plate.scad through common.scad.
// Display-frame positions and its controls remain proposals until that separate CAD is complete.
include <../common.scad>

// Waveshare 7inch DSI LCD (C), measured in cad/r5_lid_cover_waveshare_7in.scad.
R6_PANEL_W = 192.96;
R6_PANEL_H = 110.76;
R6_PANEL_R = 8;
R6_ACTIVE_W = 154.88;
R6_ACTIVE_H = 86.72;
R6_PANEL_X = (COVER_W - R6_PANEL_W) / 2;
R6_PANEL_Y = 30.0;  // hinge-side proposal from the R6 first-pass plan study

// Proposed display-frame controls, right of/below the panel.  Verify connectors and cable bends
// against the final R6 frame before using any generated mask for paint.
R6_BTN_X = 225.0;
R6_BTN_Y = 160.0;
R6_CHG_X = 225.0;
R6_CHG_Y = 90.0;

// Common painted outlines.  The lower frame retains R5's cavity-height plate outline.
echo(P_W = COVER_W);
echo(P_L = COVER_L);
echo(P_DECK_W = R5_DECK_W);
echo(P_DECK_L = R5_DECK_L);
echo(P_DECK_X0 = R5_DECK_X0);
echo(P_DECK_Y0 = R5_DECK_Y0);
echo(P_DECK_R = R5_DECK_R);
echo(P_DECK_T = R5_DECK_T);
echo(P_COVER_R = COVER_R);

// R6 lid: the measured K06 envelope at the R5-derived coordinates. The lid carries no display
// or status hardware, so the keyboard opening is its only aperture.
echo(P_KB_X0 = R5_KB_X0);
echo(P_KB_Y0 = R5_KB_Y0);
echo(P_KB_W = R5_KB_POCKET[0]);
echo(P_KB_H = R5_KB_POCKET[1]);
echo(P_KB_R = R5_KB_CORNER + R5_KB_CLR);

// R6 display frame: panel, flat paint-border datum and active-area annotation.
echo(P_C_GAP = COVER_GAP);
echo(P_C_FRAME = COVER_FRAME);
echo(P_PANEL_X = R6_PANEL_X);
echo(P_PANEL_Y = R6_PANEL_Y);
echo(P_DISP_W = R6_PANEL_W);
echo(P_DISP_H = R6_PANEL_H);
echo(P_DISP_R = R6_PANEL_R);
echo(P_ACTIVE_W = R6_ACTIVE_W);
echo(P_ACTIVE_H = R6_ACTIVE_H);

// Controls on the display frame, not on the keyboard lid.
echo(P_BTN_X = R6_BTN_X);
echo(P_BTN_Y = R6_BTN_Y);
echo(P_BTN_D = R5_BTN_D);
echo(P_BTN_BODY = R5_BTN_BODY);
echo(P_CHG_X = R6_CHG_X);
echo(P_CHG_Y = R6_CHG_Y);
echo(P_CHG_D = R5_CHG_D);
echo(P_CHG_NUT_D = R5_CHG_NUT_D);

// Proposed removable-frame fastener positions, inherited from the R5 plate for this study.
echo(P_S0 = R5_SCREWS[0][0]); echo(P_S0Y = R5_SCREWS[0][1]);
echo(P_S1 = R5_SCREWS[1][0]); echo(P_S1Y = R5_SCREWS[1][1]);
echo(P_S2 = R5_SCREWS[2][0]); echo(P_S2Y = R5_SCREWS[2][1]);
echo(P_S3 = R5_SCREWS[3][0]); echo(P_S3Y = R5_SCREWS[3][1]);
echo(P_S4 = R5_SCREWS[4][0]); echo(P_S4Y = R5_SCREWS[4][1]);
echo(P_S5 = R5_SCREWS[5][0]); echo(P_S5Y = R5_SCREWS[5][1]);
echo(P_S6 = R5_SCREWS[6][0]); echo(P_S6Y = R5_SCREWS[6][1]);

cube(1);
