#pragma once

// Pure classification maths for the charge-input sense line: no Arduino, so a host test can
// drive it with synthetic samples (see work/scripts/../ tests and the bench procedure in
// docs/WIRING.md).
//
// The rail is the UPS HAT (B)'s DC input, the one socket every source shares (mains, solar via
// the MPPT, or the external crank converter). A divider drops 8.4 V to ~2.1 V for the ADC; this
// header only ever sees millivolts of the *rail* (already multiplied back up).
//
// What a voltage can and cannot say:
//   present / absent            yes, by level with hysteresis
//   a regulated supply vs one that sags   yes, by spread over a one-minute window
//   mains vs solar vs crank     no - that needs the declaration or a second sense point, so the
//                               UI says "steady" / "varying" and never claims to know the source

#include <cstdint>
#include <cstddef>

namespace chgs {

// Rail thresholds on the *undivided* input. The socket feeds an 8.4 V input; below 3.0 V there is
// no usable source (a shaded panel or an unplugged lead), and the drop-out is 0.5 V lower so a
// sagging supply does not chatter the state.
constexpr uint16_t PRESENT_ON_MV  = 3000;
constexpr uint16_t PRESENT_OFF_MV = 2500;

// A one-minute window at the 5 s UPS period. 12 samples covers a cloud or a crank pause without
// making the label stale.
constexpr uint8_t WINDOW = 12;

// (max - min) / median, in percent. A regulated 8.4 V supply holds well inside this; a solar panel
// under passing cloud, or a crank, does not.
constexpr uint16_t STABLE_SPREAD_PCT = 4;

struct Window {
  uint16_t mv[WINDOW] = {0};
  uint8_t count = 0;   // samples held, saturating at WINDOW
  uint8_t next = 0;    // ring write index
};

inline void reset(Window& w) { w = Window(); }

inline void push(Window& w, uint16_t mv) {
  w.mv[w.next] = mv;
  w.next = static_cast<uint8_t>((w.next + 1) % WINDOW);
  if (w.count < WINDOW) {
    w.count++;
  }
}

// Small-window median: copy, insertion sort, take the middle. WINDOW is 12, so this is free.
inline uint16_t median(const Window& w) {
  if (w.count == 0) {
    return 0;
  }
  uint16_t tmp[WINDOW];
  for (uint8_t i = 0; i < w.count; i++) {
    tmp[i] = w.mv[i];
  }
  for (uint8_t i = 1; i < w.count; i++) {
    const uint16_t key = tmp[i];
    int8_t j = static_cast<int8_t>(i) - 1;
    while (j >= 0 && tmp[j] > key) {
      tmp[j + 1] = tmp[j];
      j--;
    }
    tmp[j + 1] = key;
  }
  return tmp[w.count / 2];
}

// One entry per call: keep the level the previous call reported and apply the hysteresis band.
inline bool present(uint16_t mv, bool wasPresent) {
  return wasPresent ? mv >= PRESENT_OFF_MV : mv >= PRESENT_ON_MV;
}

// True once the window has at least a few samples and its spread is small. Before that the answer
// is "not stable yet", which the UI renders as no adjective at all.
inline bool stable(const Window& w) {
  if (w.count < 4) {
    return false;
  }
  uint16_t lo = 0xFFFF, hi = 0;
  for (uint8_t i = 0; i < w.count; i++) {
    if (w.mv[i] < lo) lo = w.mv[i];
    if (w.mv[i] > hi) hi = w.mv[i];
  }
  const uint16_t mid = median(w);
  if (mid == 0) {
    return false;
  }
  const uint32_t spread = static_cast<uint32_t>(hi - lo) * 100UL;
  return spread <= static_cast<uint32_t>(STABLE_SPREAD_PCT) * mid;
}

}  // namespace chgs
