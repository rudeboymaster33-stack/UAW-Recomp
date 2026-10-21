// uaw - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>
#include <rex/audio/audio_system.h>
#include <rex/ui/overlay/debug_overlay.h>

rex::ui::FrameStats UawGetFrameStats();
// Pause/resume the game (the game's main loop waits in the swap hook).
void UawSetPaused(bool paused);

class UawApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<UawApp>(new UawApp(ctx, "uaw",
        PPCImageConfig));
  }

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  // void OnPreSetup(rex::RuntimeConfig& config) override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  void OnPostSetup() override { SetGuestFrameStats([] { return UawGetFrameStats(); }); }
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  // void OnShutdown() override {}

#if defined(__ANDROID__)
  // Pause the game while the app is not in front (swiped away, home screen,
  // another app, notification shade): no battery drain, the match does not
  // run on, and the sound stops. Resumes when the app comes back.
  void OnWindowFocusChanged(bool focused) override {
    if (focused == !paused_) {
      return;
    }
    paused_ = !focused;
    UawSetPaused(paused_);
    if (runtime() && runtime()->audio_system()) {
      auto* audio = static_cast<rex::audio::AudioSystem*>(runtime()->audio_system());
      if (paused_) {
        audio->Pause();
      } else {
        audio->Resume();
      }
    }
  }

 private:
  bool paused_ = false;
#endif
  // void OnConfigurePaths(rex::PathConfig& paths) override {}
};
