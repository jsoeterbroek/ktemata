#!/usr/bin/env python3
"""Power model for docs/POWER.md: Ktemata r5 vs Project NOMAD, all running 24/7.

Single source of truth for the numbers in that page. It prints the markdown tables and
writes the two charts, so the prose, the tables and the images cannot drift apart.

  python3 work/scripts/power_chart.py            # tables to stdout + charts to ../docs/
  python3 work/scripts/power_chart.py --tables   # tables only

Inputs are measured where a measurement exists (see docs/POWER.md for the sources); the
efficiency, depth-of-discharge, peak-sun-hour and panel-derate figures are assumptions and
are named as such in the output.
"""
import sys, os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = os.path.dirname(os.path.abspath(__file__))
DOCS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "docs")

# ---------------- assumptions ----------------
ETA = 0.88          # UPS HAT (B) 2S -> 5 V buck, assumed
DOD = 0.85          # usable depth of discharge of the 2S pack
PSH = 3.5           # peak sun hours, Netherlands annual average
DERATE = 0.65       # panel angle/soiling/temperature 0.70 x charger 0.93
GRID = 0.30         # EUR/kWh, for the cost row
PACK_WH = 7.4 * 3.0  # 2x18650 3.0 Ah in 2S = 22.2 Wh (3.5 Ah cells = 25.9 Wh)

# ---------------- Ktemata r5, at the 5 V rail ----------------
# Pi 5 4 GB: 3.0 W headless idle, 8.8 W all-core (raspberry.tips measurements, Oct 2026);
# Touch Display 2: 1.4 W; SN740 NVMe: 0.5 W idle / 4.7 W max; FireBeetle 2 + OLED ~0.2 W.
# r5 has no BME688, so the sensor line of r4 is gone (it was milliwatts in forced mode).
K = {
    "screen off, Pi up":  (4.0, "Pi 3.0 + NVMe 0.5 + panel logic 0.3 + ESP32 0.2"),
    "idle, screen on":    (5.1, "as above + 1.4 W backlight"),
    "reading / Kiwix":    (6.5, "idle + touch and page turns"),
    "browsing + maps":    (8.7, "Chromium, one tab set"),
    "heavy (video/CPU)":  (12.5, "~8.8 W CPU-bound + display; thermally capped in r5's sealed host"),
}

# ---------------- 24/7 duty profiles (at the 5 V rail) ----------------
# Every platform is scored over the same 24 h. Ktemata has a display bolted to it, so it gets
# a realistic profile; NOMAD is headless and serves over the LAN, so 100 % of its time is idle
# or loaded with no display of its own.
PROFILES = {   # values are energy per day at the 5 V rail (Wh), not watts
    "Ktemata r5 — screen off 24 h": (24 * K["screen off, Pi up"][0],
                                     "server role, display never lit"),
    "Ktemata r5 — 4 h reading + 20 h off": (20 * K["screen off, Pi up"][0] + 4 * K["reading / Kiwix"][0],
                                            "4 h reading, display off otherwise"),
    "Ktemata r5 — kiosk, display on 24 h": (24 * K["idle, screen on"][0],
                                            "display always lit; the worst case for r5"),
}

# ---------------- Project NOMAD, AI off (idle is unchanged by disabling AI) ----------------
# Measured: OptiPlex 7060/7070 Micro 18/13 W, ThinkCentre M710q 11-13 W, M920q 12-15 W,
# M75q Gen 2 ~12 W (ServeTheHome); Minisforum UM890 Pro 7-9 W idle / 80-90 W load.
# NOMAD's own figure is "15-65 W depending on load".
NOMAD = {
    "NOMAD budget (refurb SFF)":        (14.5, 50, "11-18 W idle measured, mid 14.5"),
    "NOMAD recommended (UM890 class)":   (8.0, 85, "7-9 W idle measured, mid 8.0"),
    "NOMAD power (+RTX 3060)":          (35.0, 250, "30-40 W idle INFERRED (3060 Ti alone ~11 W)"),
}


def pack(w5v):
    """5 V-rail watts -> watts drawn from the 2S pack."""
    return w5v / ETA


def wh_day_5v(w5v):
    return w5v * 24.0


def panel_w(wh_day_at_pack):
    return wh_day_at_pack / (PSH * DERATE)


def battery_wh(wh_day_at_pack):
    return wh_day_at_pack / DOD


def eur_year(wh_day):
    return wh_day * 365 / 1000.0 * GRID


def rows():
    """(label, headline draw in its own unit, Wh/day at the pack, note)"""
    out = []
    for name, (wh5v, note) in PROFILES.items():
        out.append((name, wh5v / 24.0, pack(wh5v), note))
    for name, (idle, load, note) in NOMAD.items():
        out.append((name, idle, wh_day_5v(idle), note))
    return out


def table_247():
    print("| Platform (24/7, AI off) | Draw | Wh/day | Panel | Battery, 1 day | €/yr at €0.30 |")
    print("|---|---|---|---|---|---|")
    for name, w, wh, note in rows():
        unit = "5 V" if name.startswith("Ktemata") else "wall"
        print(f"| {name} | {w:.1f} W ({unit}) | {wh:.0f} | {panel_w(wh):.0f} W | "
              f"{battery_wh(wh):.0f} Wh | €{eur_year(wh):.0f} |")
    print()


def table_ktemata():
    print("| State (r5) | 5 V rail | at pack | runtime, 22.2 Wh | runtime, 25.9 Wh |")
    print("|---|---|---|---|---|")
    for name, (w, note) in K.items():
        r22 = PACK_WH * ETA * DOD / w
        r26 = 7.4 * 3.5 * ETA * DOD / w
        print(f"| {name} | {w:.1f} W | {pack(w):.1f} W | {r22:.1f} h | {r26:.1f} h |")
    print()


def table_profile_power():
    print("| Platform | Idle | Load | Ratio load/idle |")
    print("|---|---|---|---|")
    print(f"| Ktemata r5 | {K['idle, screen on'][0]:.1f} W (5 V) | "
          f"{K['heavy (video/CPU)'][0]:.1f} W (5 V) | {K['heavy (video/CPU)'][0] / K['idle, screen on'][0]:.1f}x |")
    for name, (idle, load, note) in NOMAD.items():
        print(f"| {name} | {idle:.1f} W | {load} W | {load / idle:.1f}x |")
    print()


def chart_247(path):
    data = rows()
    names = [n for n, _, _, _ in data]
    wh = [w for _, _, w, _ in data]
    panels = [panel_w(w) for w in wh]
    fig, ax = plt.subplots(figsize=(9, 4.2))
    y = range(len(data))
    bars = ax.barh(list(y), wh, color="#4a72b0", height=0.62)
    for i, (b, w, p) in enumerate(zip(bars, wh, panels)):
        ax.text(b.get_width() + 12, i, f"{wh[i]:.0f} Wh/day  ·  {panels[i]:.0f} W panel",
                va="center", fontsize=9, color="#333")
    ax.set_yticks(list(y))
    ax.set_yticklabels(names, fontsize=9)
    ax.invert_yaxis()
    ax.set_xlabel("energy per day at the pack (Wh)", fontsize=9)
    ax.set_xlim(0, max(wh) * 1.42)
    ax.set_title("24/7 duty: daily energy and the solar panel that sustains it", fontsize=11)
    ax.grid(axis="x", color="#ddd", lw=0.6)
    ax.set_axisbelow(True)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def chart_profile(path):
    fig, ax = plt.subplots(figsize=(9, 3.9))
    groups = [("Ktemata r5\n(5 V rail)", K["idle, screen on"][0], K["heavy (video/CPU)"][0])]
    for name, (idle, load, note) in NOMAD.items():
        groups.append((name.replace(" (", "\n("), idle, load))
    x = range(len(groups))
    w = 0.36
    idle = [g[1] for g in groups]
    load = [g[2] for g in groups]
    b1 = ax.bar([i - w / 2 for i in x], idle, w, label="idle", color="#4a72b0")
    b2 = ax.bar([i + w / 2 for i in x], load, w, label="load", color="#c4622d")
    for bars in (b1, b2):
        for b in bars:
            ax.text(b.get_x() + b.get_width() / 2, b.get_height() * 1.08,
                    f"{b.get_height():.0f}", ha="center", fontsize=8, color="#333")
    ax.set_yscale("log")
    ax.set_ylabel("power (W, log scale)", fontsize=9)
    ax.set_xticks(list(x))
    ax.set_xticklabels([g[0] for g in groups], fontsize=8.5)
    ax.set_ylim(3, 900)
    ax.set_title("Idle versus load: the recommended NOMAD idles lower than a refurb, but loads far higher",
                 fontsize=10.5)
    ax.grid(axis="y", color="#ddd", lw=0.6)
    ax.set_axisbelow(True)
    ax.legend(frameon=False, fontsize=9)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    if "--tables" not in sys.argv:
        os.makedirs(DOCS, exist_ok=True)
        chart_247(os.path.join(DOCS, "power_24_7.png"))
        chart_profile(os.path.join(DOCS, "power_profile.png"))
        print(f"wrote {os.path.join(DOCS, 'power_24_7.png')}")
        print(f"wrote {os.path.join(DOCS, 'power_profile.png')}")
        print()
    table_247()
    table_ktemata()
    table_profile_power()
