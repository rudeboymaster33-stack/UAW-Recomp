// Universe at War recomp hooks: frame counter (FPS) + earlier diagnostics (unused now)
#include <rex/ppc.h>
#include <rex/logging.h>
#include <atomic>
#include <string>
#include <vector>
#include <chrono>
#include <cstdlib>
#include <thread>
#include <rex/chrono/clock.h>
#include <rex/graphics/swap_hints.h>
#include <rex/system/kernel_state.h>
#include <rex/system/xmemory.h>
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

void UawProfilerSecond(double fps);
void UawFrameSyncCounters();

// Frame pacing: the game runs at most one world update per drawn frame, and only
// when >= 1/30 s has passed since the previous update (no catch-up). Drawing
// faster shows updates for an uneven number of frames (judder); pacing at exactly
// 33.3 ms makes updates miss whenever the game's clock reads a hair short. So
// frames are paced slightly wider than 1/30 s, which gives exactly one update
// per frame. UAW_FRAME_US sets the interval in microseconds (0 = off); default
// 34000 on Android, off on PC.
extern std::atomic<uint32_t> g_fsync_ptr;
// The game's update clock is KeTimeStampBundle.TickCount minus a start offset;
// learned in UawHook_TickCarry (absolute tick count - the game's "now").
std::atomic<uint32_t> g_game_time_base{0};
std::atomic<bool> g_game_time_base_known{false};
uint32_t g_pace_held = 0;
namespace {
uint32_t g_fsync_ptr_early() { return g_fsync_ptr.load(std::memory_order_relaxed); }
int64_t g_frame_us_override = -1;  // set by the A/B diagnostic
int64_t FrameIntervalUs() {
  if (g_frame_us_override >= 0) return g_frame_us_override;
  static int64_t us = [] {
    const char* env = std::getenv("UAW_FRAME_US");
    if (env && *env) return int64_t(std::atoll(env));
#if defined(__ANDROID__)
    return int64_t(33333);
#else
    return int64_t(0);
#endif
  }();
  return us;
}
int64_t g_next_present_us = 0;
// The game reads time from KeTimeStampBundle.TickCount (ms), which a 1 ms host
// timer refreshes; on Android that timer can lag a few ms, so the game sometimes
// sees < 33 ms between frames and skips its world update. Refresh the value
// right at the swap so the game's per-frame time steps are exact.
void RefreshGuestTickCount() {
  auto mem = REX_KERNEL_MEMORY();
  // 0x82000698: the game's import slot holding the KeTimeStampBundle address.
  auto slot = mem->TranslateVirtual<uint8_t*>(0x82000698);
  uint32_t bundle = (uint32_t(slot[0]) << 24) | (uint32_t(slot[1]) << 16) |
                    (uint32_t(slot[2]) << 8) | slot[3];
  if (!bundle) return;
  uint32_t ms = uint32_t(rex::chrono::Clock::QueryGuestUptimeMillis());
  auto p = mem->TranslateVirtual<uint8_t*>(bundle + 16);
  p[0] = uint8_t(ms >> 24); p[1] = uint8_t(ms >> 16); p[2] = uint8_t(ms >> 8); p[3] = uint8_t(ms);
}

// Skirmish runs as a lockstep network match: a world update waits for every
// player's turn confirmation, and after a late one the game catches up by
// updating every 25-28 ms. So only frames that contain a world update are
// paced (evenly, one per interval); frames without one go out immediately,
// letting the game catch up. g_pace_mode: 0 = off, 1 = update-aware, 2 = every
// frame (fixed). Diagnostic env UAW_FPS_CAP_AB=1 cycles off / update-aware /
// fixed every 20 s.
int g_pace_mode = 3;
uint32_t g_pace_tick_seen = 0;
uint32_t ReadLogicTick() {
  uint32_t ptr = g_fsync_ptr_early();
  if (!ptr) return 0;
  auto p = REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(ptr);
  return (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) | (uint32_t(p[2]) << 8) | p[3];
}
// Mode 3: hold each frame until the game's next world update is due (from
// its own FrameSynchronizer: last update time +80, TargetFPS +24), so the
// next frame starts exactly on the update beat and its camera position is
// sampled at an even time. When the game is behind (update already due), no
// waiting at all, so the lockstep network match can catch up.
bool PaceToNextUpdate() {
  uint32_t ptr = g_fsync_ptr_early();
  if (!ptr) return false;
  auto obj = REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(ptr);
  auto rd = [&](int off) {
    return (uint32_t(obj[off]) << 24) | (uint32_t(obj[off + 1]) << 16) |
           (uint32_t(obj[off + 2]) << 8) | obj[off + 3];
  };
  uint32_t last = rd(80);
  int32_t target = int32_t(rd(24));
  if (!last || target <= 0 || target > 240) return false;
  if (!g_game_time_base_known.load(std::memory_order_relaxed)) return false;
  // Game-relative due time -> absolute guest uptime ms.
  uint32_t due_ms = last + 1000u / uint32_t(target) + g_game_time_base.load(std::memory_order_relaxed);
  // Guest ms clock = Clock::QueryGuestUptimeMillis (what we write into
  // KeTimeStampBundle.TickCount at every swap).
  int64_t now_ms = int64_t(rex::chrono::Clock::QueryGuestUptimeMillis());
  int64_t wait_ms = int64_t(int32_t(due_ms - uint32_t(now_ms)));
  if (wait_ms <= 0 || wait_ms > 40) return true;  // due already (or odd): go now
  ++g_pace_held;
  int64_t until = NowUs() + wait_ms * 1000;
  if (wait_ms > 2) {
    std::this_thread::sleep_for(std::chrono::microseconds((wait_ms - 2) * 1000));
  }
  while (NowUs() < until &&
         int32_t(due_ms - uint32_t(rex::chrono::Clock::QueryGuestUptimeMillis())) > 0) {
    std::this_thread::yield();
  }
  return true;
}

void PaceSwap() {
  static const bool ab = [] {
    const char* env = std::getenv("UAW_FPS_CAP_AB");
    return env && *env == '1';
  }();
  if (g_pace_mode == 3 && !ab) {
    PaceToNextUpdate();
    return;
  }
  if (ab) {
    g_pace_mode = int((NowUs() / 20000000) % 3);
  }
  const int64_t interval = FrameIntervalUs();
  if (g_pace_mode == 0 || interval <= 0 || interval > 100000) {
    g_next_present_us = 0;
    return;
  }
  if (g_pace_mode == 1) {
    static bool prev_updated = true;
    uint32_t tick = ReadLogicTick();
    bool updated = tick != g_pace_tick_seen;
    g_pace_tick_seen = tick;
    bool after_gap = !prev_updated;
    prev_updated = updated;
    if (!updated) {
      return;  // No world update in this frame: don't hold it back.
    }
    if (after_gap) {
      // First update after a wait: show it now and restart the cadence.
      g_next_present_us = NowUs() + interval;
      return;
    }
  }
  int64_t now = NowUs();
  if (g_next_present_us == 0 || now - g_next_present_us > interval) {
    // First frame, or running late by more than a frame: restart the cadence.
    g_next_present_us = now + interval;
    return;
  }
  if (now < g_next_present_us) {
    // Sleep most of the wait, then spin briefly for accuracy.
    int64_t wait = g_next_present_us - now;
    if (wait > 2000) {
      std::this_thread::sleep_for(std::chrono::microseconds(wait - 1500));
    }
    while (NowUs() < g_next_present_us) {
      std::this_thread::yield();
    }
  }
  g_next_present_us += interval;
}
}  // namespace

// Per-frame pacing stats, logged once a second as [uaw-pace]: how many logic
// ticks the game ran for each presented frame, and the frame interval spread.
extern std::atomic<uint32_t> g_fsync_ptr;
uint32_t g_pace_ticks_hist[4] = {};  // 0, 1, 2, 3+ logic ticks per frame
uint32_t g_pace_int_hist[5] = {};    // <25, 25-31, 31-36, 36-45, >45 ms
uint32_t g_pace_last_tick = 0;
int64_t g_pace_last_swap = 0;
void PaceStatsFrame(int64_t now);
void PaceStatsLog();

// Show only frames with a new world update: the game draws ~45-50 frames a
// second but the world updates 30 times, so the extra frames repeat the last
// state and make motion uneven. Repeats are still drawn (the game needs them)
// but not displayed. A frame is always shown if nothing was shown for 34 ms
// (menus, pauses). Env UAW_SKIP_REPEATS=0 disables; default on for Android.
// Diagnostic env UAW_SKIP_AB=1: on for 20 s, off for 20 s.
namespace {
bool g_skip_repeats_active = false;
uint32_t g_shown_tick = 0;
int64_t g_last_shown_us = 0;
uint32_t g_frames_shown = 0;
bool DecideShowFrame(int64_t now) {
  static const bool enabled = [] {
    const char* env = std::getenv("UAW_SKIP_REPEATS");
    if (env && *env) return *env != '0';
#if defined(__ANDROID__)
    return true;
#else
    return false;
#endif
  }();
  static const bool ab = [] {
    const char* env = std::getenv("UAW_SKIP_AB");
    return env && *env == '1';
  }();
  g_skip_repeats_active = enabled && (!ab || ((now / 20000000) & 1) == 0);
  uint32_t tick = ReadLogicTick();
  bool show = !g_skip_repeats_active || tick != g_shown_tick || now - g_last_shown_us >= 34000;
  if (show) {
    g_shown_tick = tick;
    g_last_shown_us = now;
    ++g_frames_shown;
  }
  return show;
}
}  // namespace

// Called right before the game's VdSwap (0x828C0054): one call per presented guest frame.
void UawHook_Swap() {
  PaceSwap();
  RefreshGuestTickCount();
  rex::graphics::swap_hints::PushGuestSwap(DecideShowFrame(NowUs()));
  int64_t now = NowUs();
  PaceStatsFrame(now);
  uint64_t n = ++g_swaps;
  g_last_swap_us.store(now, std::memory_order_relaxed);
  if (g_log_window_start == 0) g_log_window_start = now;
  ++g_log_window_frames;
  int64_t dt = now - g_log_window_start;
  if (dt >= 1000000) {
    double fps = g_log_window_frames * 1e6 / double(dt);
    REXLOG_INFO("[uaw-fps] {:.1f} fps (frame {})", fps, n);
    UawProfilerSecond(fps);
    UawFrameSyncCounters();
    PaceStatsLog();
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

// ---- Experimental: override FrameSynchronizer TargetFPS (opt-in via env UAW_TARGET_FPS) ----
#include <cstdlib>
std::atomic<uint32_t> g_fsync_ptr{0};
// Hook at 0x8225CF14 in FrameSynchronizer::Init, right after it stores TargetFPS (r31+24) = 30.
void UawHook_FrameSyncInit(PPCRegister& r31) {
  const char* env = std::getenv("UAW_TARGET_FPS");
  auto mem = REX_KERNEL_MEMORY();
  auto p = mem->TranslateVirtual<uint8_t*>(r31.u32);
  auto rd = [&](int off) { return (uint32_t(p[off]) << 24) | (uint32_t(p[off + 1]) << 16) | (uint32_t(p[off + 2]) << 8) | p[off + 3]; };
  REXLOG_WARN("[uaw-fsync] Init: TargetFPS={} mid={} LogicalFPS={}", rd(24), rd(28), rd(32));
  g_fsync_ptr.store(r31.u32);
  if (!env || !*env) return;
  int target = std::atoi(env);
  if (target < 10 || target > 240) return;
  p[24] = uint8_t(target >> 24); p[25] = uint8_t(target >> 16); p[26] = uint8_t(target >> 8); p[27] = uint8_t(target);
  REXLOG_WARN("[uaw-fsync] TargetFPS overridden to {}", target);
}

// Once per second: log FrameSynchronizer fields that count up (logic frame
// counters), to see whether game logic keeps up with real time.
extern std::atomic<uint32_t> g_fsync_ptr;
// zlib inflate() entry (0x82A09CE0): count calls and requested output bytes.
std::atomic<uint64_t> g_zlib_calls{0}, g_zlib_out_req{0}, g_zlib_in{0};
void UawHook_Inflate(PPCRegister& r3) {
  if (!r3.u32) return;
  auto* z = REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(r3.u32);
  auto be32 = [&](int o) { return (uint32_t(z[o]) << 24) | (uint32_t(z[o + 1]) << 16) | (uint32_t(z[o + 2]) << 8) | z[o + 3]; };
  g_zlib_calls.fetch_add(1, std::memory_order_relaxed);
  g_zlib_in.fetch_add(be32(4), std::memory_order_relaxed);        // avail_in
  g_zlib_out_req.fetch_add(be32(16), std::memory_order_relaxed);  // avail_out
}

void UawFrameSyncCounters() {
  {
    uint64_t c = g_zlib_calls.exchange(0), o = g_zlib_out_req.exchange(0), i = g_zlib_in.exchange(0);
    if (c) REXLOG_INFO("[uaw-zlib] inflate calls={} in={}KB out_space={}KB", c, i / 1024, o / 1024);
  }
  static uint32_t s_ptr = 0;
  static std::vector<uint32_t> s_prev;
  uint32_t ptr = g_fsync_ptr.load();
  if (!ptr) return;
  auto* p = REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(ptr);
  constexpr int kWords = 1024;
  std::vector<uint32_t> cur(kWords);
  for (int i = 0; i < kWords; ++i)
    cur[i] = (uint32_t(p[i * 4]) << 24) | (uint32_t(p[i * 4 + 1]) << 16) | (uint32_t(p[i * 4 + 2]) << 8) | p[i * 4 + 3];
  if (ptr == s_ptr && s_prev.size() == cur.size()) {
    std::string out;
    for (int i = 0; i < kWords; ++i) {
      uint32_t d = cur[i] - s_prev[i];
      if (d >= 1 && d <= 400) out += fmt::format(" +{}:{}", i * 4, d);
    }
    if (!out.empty()) REXLOG_INFO("[uaw-fsc]{}", out.substr(0, 600));
  }
  s_ptr = ptr;
  s_prev.swap(cur);
}

// ---- Sampling profiler (Windows, opt-in via env UAW_PROFILE=1) ----
// Samples every thread's instruction pointer a few hundred times a second,
// maps it to the recompiled guest function (via PPCFuncMappings) or the host
// module, and groups samples by whether that second ran slow (<26.5 fps) or
// normal (27.5-31.5 fps, i.e. at the battle cap). Tables go to the log as
// [uaw-prof2] lines every 30 classified seconds.
#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <tlhelp32.h>
#pragma comment(lib, "winmm.lib")
extern "C" __declspec(dllimport) unsigned int __stdcall timeBeginPeriod(unsigned int);
#include <algorithm>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

extern PPCFuncMapping PPCFuncMappings[];

namespace {
struct Prof {
  std::vector<std::pair<uintptr_t, uint32_t>> funcs;  // host addr -> guest addr, sorted
  uintptr_t lo = 0, hi = 0;
  std::mutex mu;
  // key: (tid << 40) | target, target = guest addr or module base>>12 | 1<<39
  std::unordered_map<uint64_t, uint32_t> cur;
  std::unordered_map<uint64_t, uint64_t> agg[2];
  uint64_t agg_total[2] = {0, 0};
  uint32_t cur_total = 0;
  int classified = 0;
  std::unordered_map<uint32_t, std::string> tnames;
  std::map<uintptr_t, std::string> mods;
};
Prof* g_prof = nullptr;

std::string ModuleName(uintptr_t base) {
  wchar_t buf[MAX_PATH];
  DWORD n = GetModuleFileNameW(reinterpret_cast<HMODULE>(base), buf, MAX_PATH);
  if (!n) return fmt::format("mod@{:X}", base);
  std::wstring w(buf, n);
  auto slash = w.find_last_of(L"\\/");
  if (slash != std::wstring::npos) w = w.substr(slash + 1);
  return std::string(w.begin(), w.end());
}

uint64_t Classify(Prof& p, uintptr_t rip) {
  if (rip >= p.lo && rip < p.hi) {
    auto it = std::upper_bound(p.funcs.begin(), p.funcs.end(), std::make_pair(rip, ~0u));
    if (it != p.funcs.begin()) return (--it)->second;
  }
  HMODULE mod = nullptr;
  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         reinterpret_cast<LPCWSTR>(rip), &mod) && mod) {
    uintptr_t base = reinterpret_cast<uintptr_t>(mod);
    return (uint64_t(1) << 39) | (base >> 12);
  }
  return (uint64_t(1) << 39);
}

std::string TargetName(Prof& p, uint64_t target) {
  if (!(target & (uint64_t(1) << 39))) return fmt::format("sub_{:08X}", uint32_t(target));
  uintptr_t base = uintptr_t(target & ((uint64_t(1) << 39) - 1)) << 12;
  if (!base) return "unknown";
  auto it = p.mods.find(base);
  if (it == p.mods.end()) it = p.mods.emplace(base, ModuleName(base)).first;
  return it->second;
}

std::string ThreadName(Prof& p, uint32_t tid) {
  auto it = p.tnames.find(tid);
  if (it != p.tnames.end()) return it->second;
  std::string name = fmt::format("t{}", tid);
  if (HANDLE h = OpenThread(THREAD_QUERY_LIMITED_INFORMATION, FALSE, tid)) {
    using GetDescFn = HRESULT(WINAPI*)(HANDLE, PWSTR*);
    static auto get_desc = reinterpret_cast<GetDescFn>(
        GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "GetThreadDescription"));
    PWSTR desc = nullptr;
    if (get_desc && SUCCEEDED(get_desc(h, &desc)) && desc && *desc) {
      std::wstring w(desc);
      name = fmt::format("t{} {}", tid, std::string(w.begin(), w.end()));
    }
    if (desc) LocalFree(desc);
    CloseHandle(h);
  }
  p.tnames.emplace(tid, name);
  return name;
}

bool IsIdleTarget(Prof& p, uint64_t target) {
  if (!(target & (uint64_t(1) << 39))) return false;
  const std::string& n = TargetName(p, target);
  return n == "ntdll.dll" || n == "win32u.dll" || n == "KERNELBASE.dll" || n == "kernel32.dll" ||
         n == "unknown";
}

void Dump(Prof& p) {
  static const char* kClass[2] = {"SLOW", "NORMAL"};
  for (int c = 0; c < 2; ++c) {
    if (!p.agg_total[c]) continue;
    // Samples per thread == time that thread existed; busy = not in a wait (ntdll etc.).
    std::unordered_map<uint32_t, uint64_t> per_thread, busy_thread;
    for (auto& [k, v] : p.agg[c]) {
      uint32_t t = uint32_t(k >> 40);
      per_thread[t] += v;
      if (!IsIdleTarget(p, k & ((uint64_t(1) << 40) - 1))) busy_thread[t] += v;
    }
    std::vector<std::pair<double, uint32_t>> th;
    for (auto& [t, v] : busy_thread) th.push_back({100.0 * v / per_thread[t], t});
    std::sort(th.rbegin(), th.rend());
    REXLOG_WARN("[uaw-prof2] ===== {} seconds: {} samples, {} threads", kClass[c], p.agg_total[c],
                per_thread.size());
    for (size_t i = 0; i < th.size() && i < 12; ++i)
      REXLOG_WARN("[uaw-prof2] {} busy {:5.1f}% {}", kClass[c], th[i].first, ThreadName(p, th[i].second));
    // Busy entries as % of that thread's time.
    std::vector<std::pair<double, uint64_t>> top;
    for (auto& [k, v] : p.agg[c]) {
      if (IsIdleTarget(p, k & ((uint64_t(1) << 40) - 1))) continue;
      top.push_back({100.0 * v / per_thread[uint32_t(k >> 40)], k});
    }
    std::sort(top.rbegin(), top.rend());
    for (size_t i = 0; i < top.size() && i < 60; ++i) {
      uint64_t k = top[i].second;
      REXLOG_WARN("[uaw-prof2] {} {:5.2f}% {} | {}", kClass[c], top[i].first,
                  TargetName(p, k & ((uint64_t(1) << 40) - 1)), ThreadName(p, uint32_t(k >> 40)));
    }
  }
}

void SamplerMain(Prof* pp) {
  Prof& p = *pp;
  timeBeginPeriod(1);
  DWORD self = GetCurrentThreadId(), pid = GetCurrentProcessId();
  std::vector<std::pair<uint32_t, HANDLE>> threads;
  auto refresh = [&]() {
    for (auto& t : threads) CloseHandle(t.second);
    threads.clear();
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    THREADENTRY32 te{sizeof(te)};
    if (Thread32First(snap, &te)) {
      do {
        if (te.th32OwnerProcessID != pid || te.th32ThreadID == self) continue;
        HANDLE h = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT | THREAD_QUERY_LIMITED_INFORMATION,
                              FALSE, te.th32ThreadID);
        if (h) threads.push_back({te.th32ThreadID, h});
        te.dwSize = sizeof(te);
      } while (Thread32Next(snap, &te));
    }
    CloseHandle(snap);
  };
  auto last_refresh = std::chrono::steady_clock::now() - std::chrono::seconds(10);
  std::vector<std::pair<uint32_t, uintptr_t>> ips;
  for (;;) {
    auto now = std::chrono::steady_clock::now();
    if (now - last_refresh > std::chrono::seconds(2)) { refresh(); last_refresh = now; }
    ips.clear();
    for (auto& [tid, h] : threads) {
      if (SuspendThread(h) == DWORD(-1)) continue;
      CONTEXT ctx{};
      ctx.ContextFlags = CONTEXT_CONTROL;
      BOOL ok = GetThreadContext(h, &ctx);
      ResumeThread(h);
      if (ok) ips.push_back({tid, uintptr_t(ctx.Rip)});
    }
    {
      std::lock_guard<std::mutex> lock(p.mu);
      for (auto& [tid, rip] : ips) {
        uint64_t key = (uint64_t(tid) << 40) | Classify(p, rip);
        ++p.cur[key];
        ++p.cur_total;
      }
    }
    Sleep(3);
  }
}
}  // namespace

void UawProfilerSecond(double fps) {
  static bool s_init = false;
  if (!s_init) {
    s_init = true;
    const char* env = std::getenv("UAW_PROFILE");
    if (!env || *env != '1') return;
    g_prof = new Prof();
    for (PPCFuncMapping* m = PPCFuncMappings; m->host; ++m)
      g_prof->funcs.push_back({reinterpret_cast<uintptr_t>(m->host), uint32_t(m->guest)});
    std::sort(g_prof->funcs.begin(), g_prof->funcs.end());
    g_prof->lo = g_prof->funcs.front().first;
    g_prof->hi = g_prof->funcs.back().first + 0x10000;
    REXLOG_WARN("[uaw-prof2] sampling profiler on: {} functions, host {:X}-{:X}", g_prof->funcs.size(),
                g_prof->lo, g_prof->hi);
    std::thread(SamplerMain, g_prof).detach();
    return;
  }
  if (!g_prof) return;
  Prof& p = *g_prof;
  std::lock_guard<std::mutex> lock(p.mu);
  int c = (fps > 10.0 && fps < 26.5) ? 0 : (fps >= 27.5 && fps <= 31.5) ? 1 : -1;
  if (c >= 0) {
    for (auto& [k, v] : p.cur) p.agg[c][k] += v;
    p.agg_total[c] += p.cur_total;
    if (++p.classified % 30 == 0) Dump(p);
  }
  p.cur.clear();
  p.cur_total = 0;
}
#elif defined(__ANDROID__)
// Android: sample running threads with SIGPROF (tgkill), read the interrupted
// pc from the signal context, map to guest function / host library.
#include <dirent.h>
#include <dlfcn.h>
#include <signal.h>
#include <sys/syscall.h>
#include <ucontext.h>
#include <unistd.h>
#include <algorithm>
#include <fstream>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

extern PPCFuncMapping PPCFuncMappings[];

namespace {
constexpr uint32_t kRing = 1 << 14;
struct Slot { std::atomic<uint32_t> seq{0}; uint32_t tid; uintptr_t pc; };
Slot g_ring[kRing];
std::atomic<uint32_t> g_ring_w{0};

void ProfSignal(int, siginfo_t*, void* uc_void) {
  auto* uc = static_cast<ucontext_t*>(uc_void);
  uint32_t i = g_ring_w.fetch_add(1, std::memory_order_relaxed);
  Slot& s = g_ring[i & (kRing - 1)];
  s.tid = uint32_t(gettid());
  s.pc = uintptr_t(uc->uc_mcontext.pc);
  s.seq.store(i + 1, std::memory_order_release);
}

struct Prof {
  std::vector<std::pair<uintptr_t, uint32_t>> funcs;
  uintptr_t lo = 0, hi = 0;
  std::mutex mu;
  std::unordered_map<uint64_t, uint32_t> cur;  // (tid<<40)|target ; target bit39 = host lib base>>12
  std::unordered_map<uint32_t, uint32_t> cur_seen;  // tid -> samples taken (running or sleeping)
  std::unordered_map<uint64_t, uint64_t> agg[3];
  std::unordered_map<uint32_t, uint64_t> seen[3];
  int classified = 0;
  std::unordered_map<uint32_t, std::string> tnames;
  std::unordered_map<uintptr_t, std::string> libs;
};
Prof* g_prof = nullptr;

uint64_t Classify(Prof& p, uintptr_t pc) {
  if (pc >= p.lo && pc < p.hi) {
    auto it = std::upper_bound(p.funcs.begin(), p.funcs.end(), std::make_pair(pc, ~0u));
    if (it != p.funcs.begin()) return (--it)->second;
  }
  Dl_info info{};
  if (dladdr(reinterpret_cast<void*>(pc), &info) && info.dli_fbase) {
    uintptr_t b = reinterpret_cast<uintptr_t>(info.dli_fbase);
    if (!p.libs.count(b)) {
      std::string n = info.dli_fname ? info.dli_fname : "?";
      auto sl = n.find_last_of('/');
      p.libs[b] = sl == std::string::npos ? n : n.substr(sl + 1);
    }
    return (uint64_t(1) << 39) | (b >> 12);
  }
  return uint64_t(1) << 39;
}

std::string TargetName(Prof& p, uint64_t t) {
  if (!(t & (uint64_t(1) << 39))) return fmt::format("sub_{:08X}", uint32_t(t));
  uintptr_t b = uintptr_t(t & ((uint64_t(1) << 39) - 1)) << 12;
  auto it = p.libs.find(b);
  return it == p.libs.end() ? std::string("unknown") : it->second;
}

std::string ThreadName(Prof& p, uint32_t tid) {
  auto it = p.tnames.find(tid);
  if (it != p.tnames.end()) return it->second;
  std::ifstream f(fmt::format("/proc/self/task/{}/comm", tid));
  std::string n;
  std::getline(f, n);
  return p.tnames[tid] = fmt::format("t{} {}", tid, n);
}

void Dump(Prof& p) {
  static const char* kClass[3] = {"SLOW", "NORMAL", "ALL"};
  for (int c = 0; c < 3; ++c) {
    uint64_t total = 0;
    for (auto& [t, v] : p.seen[c]) total += v;
    if (!total) continue;
    std::unordered_map<uint32_t, uint64_t> busy;
    for (auto& [k, v] : p.agg[c]) busy[uint32_t(k >> 40)] += v;
    std::vector<std::pair<double, uint32_t>> th;
    for (auto& [t, v] : busy) th.push_back({100.0 * v / std::max<uint64_t>(1, p.seen[c][t]), t});
    std::sort(th.rbegin(), th.rend());
    REXLOG_WARN("[uaw-prof2] ===== {} seconds: {} thread-samples", kClass[c], total);
    for (size_t i = 0; i < th.size() && i < 14; ++i)
      REXLOG_WARN("[uaw-prof2] {} busy {:5.1f}% {}", kClass[c], th[i].first, ThreadName(p, th[i].second));
    std::vector<std::pair<double, uint64_t>> top;
    for (auto& [k, v] : p.agg[c])
      top.push_back({100.0 * v / std::max<uint64_t>(1, p.seen[c][uint32_t(k >> 40)]), k});
    std::sort(top.rbegin(), top.rend());
    for (size_t i = 0; i < top.size() && i < 70; ++i) {
      uint64_t k = top[i].second;
      REXLOG_WARN("[uaw-prof2] {} {:5.2f}% {} | {}", kClass[c], top[i].first,
                  TargetName(p, k & ((uint64_t(1) << 40) - 1)), ThreadName(p, uint32_t(k >> 40)));
    }
  }
}

void SamplerMain(Prof* pp) {
  Prof& p = *pp;
  pid_t pid = getpid();
  pid_t self = gettid();
  uint32_t r = 0;
  std::vector<std::pair<uint32_t, bool>> tids;
  for (;;) {
    tids.clear();
    if (DIR* d = opendir("/proc/self/task")) {
      while (dirent* e = readdir(d)) {
        if (e->d_name[0] == '.') continue;
        uint32_t tid = uint32_t(atoi(e->d_name));
        if (tid == uint32_t(self)) continue;
        char path[64], buf[256];
        snprintf(path, sizeof(path), "/proc/self/task/%u/stat", tid);
        bool running = false;
        if (FILE* f = fopen(path, "r")) {
          size_t n = fread(buf, 1, sizeof(buf) - 1, f);
          fclose(f);
          buf[n] = 0;
          const char* rp = strrchr(buf, ')');
          running = rp && rp[1] == ' ' && rp[2] == 'R';
        }
        tids.push_back({tid, running});
      }
      closedir(d);
    }
    for (auto& [tid, running] : tids)
      if (running) syscall(SYS_tgkill, pid, tid, SIGPROF);
    std::this_thread::sleep_for(std::chrono::microseconds(500));
    std::lock_guard<std::mutex> lock(p.mu);
    for (auto& [tid, running] : tids) ++p.cur_seen[tid];
    uint32_t w = g_ring_w.load(std::memory_order_acquire);
    if (w - r > kRing) r = w - kRing;
    for (; r != w; ++r) {
      Slot& s = g_ring[r & (kRing - 1)];
      if (s.seq.load(std::memory_order_acquire) != r + 1) continue;
      ++p.cur[(uint64_t(s.tid) << 40) | Classify(p, s.pc)];
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(3));
  }
}
}  // namespace

void UawProfilerSecond(double fps) {
  static bool s_init = false;
  if (!s_init) {
    s_init = true;
    const char* env = std::getenv("UAW_PROFILE");
    if (!env || *env != '1') return;
    g_prof = new Prof();
    for (PPCFuncMapping* m = PPCFuncMappings; m->host; ++m)
      g_prof->funcs.push_back({reinterpret_cast<uintptr_t>(m->host), uint32_t(m->guest)});
    std::sort(g_prof->funcs.begin(), g_prof->funcs.end());
    g_prof->lo = g_prof->funcs.front().first;
    g_prof->hi = g_prof->funcs.back().first + 0x10000;
    struct sigaction sa{};
    sa.sa_sigaction = ProfSignal;
    sa.sa_flags = SA_SIGINFO | SA_RESTART;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGPROF, &sa, nullptr);
    REXLOG_WARN("[uaw-prof2] Android sampling profiler on: {} functions", g_prof->funcs.size());
    std::thread(SamplerMain, g_prof).detach();
    return;
  }
  if (!g_prof) return;
  Prof& p = *g_prof;
  std::lock_guard<std::mutex> lock(p.mu);
  bool battle = g_fsync_ptr.load() != 0;
  int cls[2] = {(fps > 10.0 && fps < 26.5) ? 0 : (fps >= 27.5 && fps <= 31.5) ? 1 : -1,
                (battle && fps > 3.0 && fps < 75.0) ? 2 : -1};
  for (int c : cls) {
    if (c < 0) continue;
    for (auto& [k, v] : p.cur) p.agg[c][k] += v;
    for (auto& [t, v] : p.cur_seen) p.seen[c][t] += v;
  }
  if (cls[1] >= 0 && ++p.classified % 20 == 0) Dump(p);
  p.cur.clear();
  p.cur_seen.clear();
}
#else
void UawProfilerSecond(double) {}
#endif

void PaceStatsFrame(int64_t now) {
  uint32_t ptr = g_fsync_ptr.load(std::memory_order_relaxed);
  if (ptr) {
    auto p = REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(ptr);
    uint32_t tick = (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) | (uint32_t(p[2]) << 8) | p[3];
    if (g_pace_last_tick) {
      uint32_t d = tick - g_pace_last_tick;
      ++g_pace_ticks_hist[d > 3 ? 3 : d];
    }
    g_pace_last_tick = tick;
  }
  if (g_pace_last_swap) {
    int64_t ms10 = (now - g_pace_last_swap) / 100;  // tenths of a ms
    int b = ms10 < 250 ? 0 : ms10 < 310 ? 1 : ms10 < 360 ? 2 : ms10 < 450 ? 3 : 4;
    ++g_pace_int_hist[b];
  }
  g_pace_last_swap = now;
}

void PaceStatsLog() {
  extern std::atomic<uint64_t> g_tick_carry_count;
  REXLOG_INFO("[uaw-pace] held={} shown={} skip_repeats={} carried={} mode={} ticks/frame 0:{} 1:{} 2:{} 3+:{} | interval <25ms:{} 25-31:{} 31-36:{} 36-45:{} >45:{}",
              g_pace_held, g_frames_shown, g_skip_repeats_active ? 1 : 0, g_tick_carry_count.exchange(0), g_pace_mode, g_pace_ticks_hist[0], g_pace_ticks_hist[1], g_pace_ticks_hist[2], g_pace_ticks_hist[3],
              g_pace_int_hist[0], g_pace_int_hist[1], g_pace_int_hist[2], g_pace_int_hist[3],
              g_pace_int_hist[4]);
  g_frames_shown = 0;
  g_pace_held = 0;
  for (auto& v : g_pace_ticks_hist) v = 0;
  for (auto& v : g_pace_int_hist) v = 0;
}

// ---- Game-speed fix: keep leftover time between world updates ----
// At 0x8225C6A4 the game is about to store "last update time = now" (r19) into
// FrameSynchronizer+80. Replace now with last + interval (never later than
// now), so time past the 33 ms threshold carries over instead of being lost.
// Set env UAW_TICK_CARRY=0 to disable.
std::atomic<uint64_t> g_tick_carry_count{0};
void UawHook_TickCarry(PPCRegister& r19, PPCRegister& r27) {
  static const bool enabled = [] {
    const char* env = std::getenv("UAW_TICK_CARRY");
    return !(env && *env == '0');
  }();
  if (!enabled) return;
  auto mem = REX_KERNEL_MEMORY();
  auto obj = mem->TranslateVirtual<uint8_t*>(r27.u32);
  auto rd = [&](int off) {
    return (uint32_t(obj[off]) << 24) | (uint32_t(obj[off + 1]) << 16) |
           (uint32_t(obj[off + 2]) << 8) | obj[off + 3];
  };
  uint32_t last = rd(80);
  int32_t target = int32_t(rd(24));
  uint32_t now = r19.u32;
  if (!last || target <= 0 || target > 240) return;
  {
    // Learn the game's time offset: the absolute tick count (which we keep
    // equal to the guest uptime at every swap) minus the game's "now".
    uint32_t abs_ms = uint32_t(rex::chrono::Clock::QueryGuestUptimeMillis());
    uint32_t base = abs_ms - now;
    uint32_t old_base = g_game_time_base.load(std::memory_order_relaxed);
    // The tick count can lag the uptime by a few ms; keep the smallest base
    // seen recently (closest to exact), refreshing if it drifts a lot.
    if (!g_game_time_base_known.load(std::memory_order_relaxed) ||
        int32_t(base - old_base) < 0 || int32_t(base - old_base) > 50) {
      g_game_time_base.store(base, std::memory_order_relaxed);
      g_game_time_base_known.store(true, std::memory_order_relaxed);
    }
  }
  uint32_t interval = 1000u / uint32_t(target);
  uint32_t elapsed = now - last;
  // Only carry over small amounts; after a long pause (loading, alt-tab) resync.
  if (elapsed >= interval && elapsed < interval * 2) {
    // 1000 / target is rounded down (33 for 30 fps); spread the remainder so
    // the average is exact (33, 33, 34 ms for 30 fps).
    static uint32_t remainder_acc = 0;
    uint32_t step = interval;
    remainder_acc += 1000u % uint32_t(target);
    if (remainder_acc >= uint32_t(target)) {
      remainder_acc -= uint32_t(target);
      ++step;
    }
    if (step > elapsed) step = elapsed;
    r19.u32 = last + step;  // <= now, so the game can never run ahead
    g_tick_carry_count.fetch_add(1, std::memory_order_relaxed);
  }
}
