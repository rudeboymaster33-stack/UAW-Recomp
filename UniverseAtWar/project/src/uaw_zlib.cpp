// Faster loading on Android: the game's zlib (statically linked Xbox code,
// recompiled) is replaced by the device's native zlib for the three calls the
// game uses: inflateInit_ (0x82A09B78), inflate (0x82A09CE0) and inflateEnd
// (0x82A0B580). Each guest z_stream gets a host z_stream; the guest struct's
// pointers/counters are kept in sync so the game sees normal zlib behaviour.
// On other platforms (and with env UAW_NATIVE_ZLIB=0) the hooks return false
// and the game's own code runs.
#include <rex/ppc.h>
#include <rex/logging.h>
#include <rex/system/kernel_state.h>
#include <rex/system/xmemory.h>

#include <atomic>
#include <cstdlib>
#include <memory>
#include <mutex>
#include <unordered_map>

#if defined(__ANDROID__)
#include <zlib.h>
#endif

namespace {
#if defined(__ANDROID__)
// Guest (32-bit, big-endian) z_stream layout, zlib 1.2.x.
constexpr uint32_t kNextIn = 0, kAvailIn = 4, kTotalIn = 8, kNextOut = 12, kAvailOut = 16,
                   kTotalOut = 20, kMsg = 24, kState = 28, kDataType = 44, kAdler = 48;

uint8_t* G(uint32_t addr) { return REX_KERNEL_MEMORY()->TranslateVirtual<uint8_t*>(addr); }
uint32_t Rd(uint32_t addr) {
  uint8_t* p = G(addr);
  return (uint32_t(p[0]) << 24) | (uint32_t(p[1]) << 16) | (uint32_t(p[2]) << 8) | p[3];
}
void Wr(uint32_t addr, uint32_t v) {
  uint8_t* p = G(addr);
  p[0] = uint8_t(v >> 24); p[1] = uint8_t(v >> 16); p[2] = uint8_t(v >> 8); p[3] = uint8_t(v);
}

bool Enabled() {
  static const bool enabled = [] {
    const char* env = std::getenv("UAW_NATIVE_ZLIB");
    bool on = !(env && *env == '0');
    REXLOG_INFO("[uaw-zlib] native zlib for game decompression: {}", on ? "on" : "off");
    return on;
  }();
  return enabled;
}

std::mutex g_mutex;
std::unordered_map<uint32_t, std::unique_ptr<z_stream>> g_streams;
std::atomic<uint64_t> g_native_out{0}, g_native_calls{0};
#endif
}  // namespace

// inflateInit_(strm, version, stream_size) -> r3
bool UawHook_ZInflateInit(PPCRegister& r3) {
#if defined(__ANDROID__)
  if (!Enabled()) return false;
  uint32_t strm = r3.u32;
  if (!strm) { r3.s64 = Z_STREAM_ERROR; return true; }
  auto h = std::make_unique<z_stream>();
  *h = {};
  int ret = inflateInit(h.get());  // the game always uses the default (zlib header, 32K window)
  if (ret != Z_OK) { r3.s64 = ret; return true; }
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_streams[strm] = std::move(h);
  }
  Wr(strm + kTotalIn, 0); Wr(strm + kTotalOut, 0); Wr(strm + kMsg, 0);
  Wr(strm + kState, strm);  // non-null marker; the real state is host-side
  Wr(strm + kAdler, 1);
  r3.s64 = Z_OK;
  return true;
#else
  (void)r3;
  return false;
#endif
}

// inflate(strm, flush) -> r3
bool UawHook_ZInflate(PPCRegister& r3, PPCRegister& r4) {
#if defined(__ANDROID__)
  if (!Enabled()) return false;
  uint32_t strm = r3.u32;
  z_stream* h = nullptr;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_streams.find(strm);
    if (it == g_streams.end()) return false;  // not ours: let the game's zlib run
    h = it->second.get();
  }
  uint32_t next_in = Rd(strm + kNextIn), avail_in = Rd(strm + kAvailIn);
  uint32_t next_out = Rd(strm + kNextOut), avail_out = Rd(strm + kAvailOut);
  h->next_in = avail_in ? G(next_in) : nullptr;
  h->avail_in = avail_in;
  h->next_out = avail_out ? G(next_out) : nullptr;
  h->avail_out = avail_out;
  int ret = inflate(h, int(r4.s32));
  uint32_t used_in = avail_in - h->avail_in, made_out = avail_out - h->avail_out;
  Wr(strm + kNextIn, next_in + used_in);
  Wr(strm + kAvailIn, h->avail_in);
  Wr(strm + kTotalIn, Rd(strm + kTotalIn) + used_in);
  Wr(strm + kNextOut, next_out + made_out);
  Wr(strm + kAvailOut, h->avail_out);
  Wr(strm + kTotalOut, Rd(strm + kTotalOut) + made_out);
  Wr(strm + kDataType, uint32_t(h->data_type));
  Wr(strm + kAdler, uint32_t(h->adler));
  Wr(strm + kMsg, 0);
  g_native_out.fetch_add(made_out, std::memory_order_relaxed);
  g_native_calls.fetch_add(1, std::memory_order_relaxed);
  r3.s64 = ret;
  return true;
#else
  (void)r3; (void)r4;
  return false;
#endif
}

// inflateEnd(strm) -> r3
bool UawHook_ZInflateEnd(PPCRegister& r3) {
#if defined(__ANDROID__)
  if (!Enabled()) return false;
  uint32_t strm = r3.u32;
  std::unique_ptr<z_stream> h;
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    auto it = g_streams.find(strm);
    if (it == g_streams.end()) return false;
    h = std::move(it->second);
    g_streams.erase(it);
  }
  inflateEnd(h.get());
  Wr(strm + kState, 0);
  r3.s64 = Z_OK;
  return true;
#else
  (void)r3;
  return false;
#endif
}

// For the once-a-second log: decompressed bytes and calls since last time.
void UawZlibStats(uint64_t& out_bytes, uint64_t& calls) {
#if defined(__ANDROID__)
  out_bytes = g_native_out.exchange(0);
  calls = g_native_calls.exchange(0);
#else
  out_bytes = calls = 0;
#endif
}
