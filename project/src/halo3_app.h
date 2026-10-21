// halo3 - ReXGlue Recompiled Project
//
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>
#include <rex/audio/downmix.h>

class Halo3App : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<Halo3App>(new Halo3App(ctx, "halo3",
        PPCImageConfig));
  }

  // Override virtual hooks for customization:
  // void OnPostInitLogging() override {}
  // void OnPreSetup(rex::RuntimeConfig& config) override {}
  // void OnLoadXexImage(std::string& xex_image) override {}
  // void OnPostLoadXexImage() override {}
  void OnPostSetup() override {
    // Louder stereo fold for the handheld's speakers: dialogue (center) and
    // surround kept near full level, and less headroom scaling than the
    // broadcast default (the output stage clamps any peaks).
    rex::audio::StereoFold fold;
    fold.center = 0.85f;
    fold.surround = 0.75f;
    fold.lfe = 0.0f;
    fold.scale = 0.85f;
    rex::audio::SetStereoFold(fold);
    rex::audio::SetOutputGain(1.0f);
  }
  // void OnCreateDialogs(rex::ui::ImGuiDrawer* drawer) override {}
  // std::unique_ptr<rex::ui::ImGuiDialog> CreateAchievementsOverlay() override;
  // std::unique_ptr<rex::ui::AchievementNotificationDialog>
  // CreateAchievementNotificationDialog() override;
  // void OnShutdown() override {}
  // void OnConfigurePaths(rex::PathConfig& paths) override {}
};
