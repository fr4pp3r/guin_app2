import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:guin_app/providers/connectivity_provider.dart';
import 'package:guin_app/utils/constants.dart';

/// App-wide "You're offline" indicator, wired once via `MaterialApp.builder`
/// in `main.dart` so it floats above the Navigator and survives navigation on
/// every route.
///
/// Design notes:
/// * **Shape / placement** — a compact, fully-rounded pill centered on the
///   bottom edge (above the system-nav inset). This is deliberately unlike
///   the per-fetch offline banners inside My Requests / My Reports (amber-50
///   rounded cards with a circular icon badge): the different shape and
///   edge make this read as a system-level status chip, not a second content
///   banner, so the two never look doubled-up.
/// * **Colors** — the app's existing amber "info" language (amber-50 fill,
///   `AppColors.warning` border, deep-orange wifi-off glyph). Never red:
///   being offline is a status, not an error.
/// * **Interaction** — wrapped in [IgnorePointer] so it never blocks taps on
///   the UI underneath; when back online it animates out and collapses to
///   [SizedBox.shrink] (zero visual footprint).
///
/// Caveat: `connectivity_plus` is interface-level — an interface that is up
/// behind a captive portal (or with no real internet) still reads "online".
/// The per-screen offline banners, which react to actual request failures,
/// remain the authoritative per-fetch signal; this pill is a best-effort
/// global hint only.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isOffline = context.watch<ConnectivityProvider>().isOffline;

    // viewPadding (not padding): stay pinned above the system-nav area even
    // while the keyboard is up.
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomInset + 12,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    // Slide up from just below the pill's own height.
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.7),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              // Distinct keys make AnimatedSwitcher treat online/offline as a
              // real child swap, so the exit transition actually plays.
              child: isOffline
                  ? const _OfflinePill(key: ValueKey<String>('offline-pill'))
                  : const SizedBox.shrink(key: ValueKey<String>('online')),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill itself: icon + text, in the app's amber "info" palette.
class _OfflinePill extends StatelessWidget {
  const _OfflinePill({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'You\u2019re offline. Some actions need a connection.',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1), // amber 50 — warm, never alarming
            borderRadius: BorderRadius.circular(999), // pill, not a card
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 15,
                color: Color(0xFFE65100),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'You\u2019re offline',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' \u2014 some actions need a connection',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: const Color(0xFF616161),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
