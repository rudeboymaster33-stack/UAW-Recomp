// Universe at War recomp hooks: frame counter (FPS) + earlier diagnostics (unused now)
#include <rex/ppc.h>
#include <rex/logging.h>
#include <atomic>
#include <chrono>
#include <rex/ui/overlay/debug_overlay.h>

namespace {
std::atomic<uint64_t> g_swaps{0};
std::atomic<int64_t> g_last_swap_us{0};
int64_t NowUs() {
  return std::chrono::duration_cast<std::chrono::microseconds>(
             std::chrono::steady_clock::now().time_since_epoch()).count();
}
int64_t g_log_window_start = 0;
uint64_t g_log_window_frames = 0;
}  // namespace

// Called right before the game's VdSwap (0x828C0054): one call per presented guest frame.
void UawHook_Swap() {
  int64_t now = NowUs();
  uint64_t n = ++g_swaps;
  g_last_swap_us.store(now, std::memory_order_relaxed);
  if (g_log_window_start == 0) g_log_window_start = now;
  ++g_log_window_frames;
  int64_t dt = now - g_log_window_start;
  if (dt >= 1000000) {
    double fps = g_log_window_frames * 1e6 / double(dt);
    REXLOG_INFO("[uaw-fps] {:.1f} fps (frame {})", fps, n);
    g_log_window_start = now;
    g_log_window_frames = 0;
  }
}

// Stats for the F3 debug overlay.
rex::ui::FrameStats UawGetFrameStats() {
  static int64_t s_t0 = 0;
  static uint64_t s_n0 = 0;
  static rex::ui::FrameStats s_stats;
  int64_t now = NowUs();
  uint64_t n = g_swaps.load(std::memory_order_relaxed);
  if (s_t0 == 0) { s_t0 = now; s_n0 = n; }
  int64_t dt = now - s_t0;
  if (dt >= 500000) {
    uint64_t dn = n - s_n0;
    s_stats.fps = dn * 1e6 / double(dt);
    s_stats.frame_time_ms = dn ? (dt / 1000.0) / dn : 0.0;
    s_t0 = now; s_n0 = n;
  }
  s_stats.frame_count = n;
  return s_stats;
}

// ---- older JPEG diagnostics (kept so old manifests still link) ----
void UawHook_ReadMarkersEntry(PPCRegister&, PPCRegister&) {}
void UawHook_InitMarkerReader(PPCRegister&) {}
void UawHook_ReadMarkersLoop(PPCRegister&) {}
void UawHook_FirstMarkerEntry(PPCRegister&) {}
void UawHook_FirstMarkerBeforeFill(PPCRegister&, PPCRegister&, PPCRegister&) {}
void UawHook_FirstMarkerAfterFill(PPCRegister&, PPCRegister&, PPCRegister&) {}
void UawHook_ReadMarkersAfterFirst(PPCRegister&, PPCRegister&, PPCRegister&) {}
