// Calls from one recompiled game DLL into another (Halo 3: the Waves audio
// plugins in waves\ call functions exported by WavesLibDLL.dll).
//
// On the console these go through a small import thunk that the loader fills
// in. The recompiler only links kernel imports, so for these thunks the
// function body is defined here: it reads the export ordinal that the thunk
// still holds, asks the loaded WavesLibDLL module for that export's address
// (once, then cached) and calls the recompiled function at that address.

#pragma once

#include <atomic>

#include <rex/logging.h>
#include <rex/system/kernel_state.h>
#include <rex/system/xmodule.h>

namespace halo3 {

inline PPCFunc* ResolveDllImport(uint8_t* base, uint32_t thunk) {
  uint32_t record = __builtin_bswap32(*reinterpret_cast<uint32_t*>(base + thunk));
  uint16_t ordinal = static_cast<uint16_t>(record & 0xFFFF);
  auto* ks = rex::system::kernel_state();
  auto lib = ks ? ks->GetModule("WavesLibDLL.dll", /*user_only=*/true) : nullptr;
  uint32_t target = lib ? lib->GetProcAddressByOrdinal(ordinal) : 0;
  PPCFunc* func = target ? rex::runtime::ResolveIndirectFunction(target) : nullptr;
  if (!func) {
    REXLOG_ERROR("halo3: import thunk {:08X} (WavesLibDLL ordinal {}) could not be resolved",
                 thunk, ordinal);
  }
  return func;
}

}  // namespace halo3

#define HALO3_DLL_IMPORT(addr)                                         \
  DEFINE_REX_FUNC(sub_##addr) {                                        \
    static std::atomic<PPCFunc*> cached{nullptr};                      \
    PPCFunc* func = cached.load(std::memory_order_acquire);            \
    if (!func) {                                                       \
      func = halo3::ResolveDllImport(base, 0x##addr);                  \
      if (!func) {                                                     \
        return;                                                        \
      }                                                                \
      cached.store(func, std::memory_order_release);                   \
    }                                                                  \
    func(ctx, base);                                                   \
  }
