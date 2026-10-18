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

// ---- Profile settings diagnostics (achievement progress error) ----
#include <rex/system/kernel_state.h>
#include <rex/system/xmemory.h>

namespace {
struct ReadArgs { uint32_t title, user, xuid_count, xuids, count, ids, size_ptr, buffer; };
thread_local ReadArgs t_read{};
uint32_t GuestU32(uint32_t addr) {
  if (!addr) return 0;
  auto p = REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(addr);
  return (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) | (uint32_t(p[2]) << 8) | p[3];
}
uint8_t GuestU8(uint32_t addr) { return REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(addr)[0]; }
}  // namespace

void UawHook_ReadProfileBefore(PPCRegister& r3, PPCRegister& r4, PPCRegister& r5, PPCRegister& r6,
                               PPCRegister& r7, PPCRegister& r8, PPCRegister& r9, PPCRegister& r10) {
  t_read = {r3.u32, r4.u32, r5.u32, r6.u32, r7.u32, r8.u32, r9.u32, r10.u32};
  std::string ids;
  for (uint32_t i = 0; i < r7.u32 && i < 8; ++i) ids += fmt::format("{:08X} ", GuestU32(r8.u32 + i * 4));
  REXLOG_WARN("[uaw-prof] READ title={:08X} user={} xuids={}@{:08X} count={} ids=[{}] size_ptr={:08X}(={}) buf={:08X}",
              r3.u32, r4.u32, r5.u32, r6.u32, r7.u32, ids, r9.u32, GuestU32(r9.u32), r10.u32);
}

void UawHook_ReadProfileAfter(PPCRegister& r3) {
  const auto& a = t_read;
  REXLOG_WARN("[uaw-prof] READ result={:08X} size_now={}", r3.u32, GuestU32(a.size_ptr));
  if (!a.buffer || r3.u32 == 0x7A /*insufficient buffer*/) return;
  uint32_t n = GuestU32(a.buffer), sp = GuestU32(a.buffer + 4);
  REXLOG_WARN("[uaw-prof]   header count={} settings_ptr={:08X}", n, sp);
  for (uint32_t i = 0; i < n && i < 8 && sp; ++i) {
    uint32_t s = sp + i * 40;
    REXLOG_WARN("[uaw-prof]   [{}] from={} id={:08X} type={} bin_size={} bin_ptr={:08X} first4={:08X}", i,
                GuestU32(s), GuestU32(s + 16), GuestU8(s + 24), GuestU32(s + 32), GuestU32(s + 36),
                GuestU32(GuestU32(s + 36)));
  }
}

void UawHook_WriteProfileBefore(PPCRegister& r5, PPCRegister& r6) {
  for (uint32_t i = 0; i < r5.u32 && i < 8; ++i) {
    uint32_t s = r6.u32 + i * 40;
    REXLOG_WARN("[uaw-prof] WRITE [{}] from={} id={:08X} type_byte={} word24={:08X} bin_size={} bin_ptr={:08X}", i,
                GuestU32(s), GuestU32(s + 16), GuestU8(s + 24), GuestU32(s + 24), GuestU32(s + 32), GuestU32(s + 36));
  }
}
