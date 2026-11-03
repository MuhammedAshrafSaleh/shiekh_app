// lib/features/home/widgets/home_slider_config.dart

/// Auto-scroll cadence for the Home banners carousel.
const int _kBannerAutoScrollSeconds = 4;

/// Banners carousel auto-scroll interval (shared so the suggestions slider can
/// derive a faster cadence from it — no magic numbers duplicated).
const Duration kBannerAutoScrollInterval = Duration(
  seconds: _kBannerAutoScrollSeconds,
);

/// Suggestions ("مقترحات") slider auto-scroll interval. Spec: slightly FASTER
/// than banners — derived as banners − 1s.
const Duration kSuggestionsAutoScrollInterval = Duration(
  seconds: _kBannerAutoScrollSeconds - 1,
);
