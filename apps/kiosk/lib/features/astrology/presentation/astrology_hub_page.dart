// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:skp_kiosk/app/router.dart';
// import 'package:skp_kiosk/core/theme/athena_colors.dart';
// import 'package:skp_kiosk/core/ui/ui.dart';
// import 'package:skp_kiosk/features/astrology/presentation/widgets/reading_mark.dart';
// import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
// import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

// class AstrologyHubPage extends ConsumerWidget {
//   const AstrologyHubPage({super.key});

//   Future<void> _endSession(WidgetRef ref) {
//     return ref
//         .read(kioskSessionControllerProvider.notifier)
//         .endVisitorSession(attract: false);
//   }

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final colors = context.athenaColors;

//     final tiles = [
//       (
//         kind: AstrologyReadingKind.kundali,
//         icon: Icons.auto_awesome,
//         title: 'My Kundali',
//         subtitle: 'North or South Indian chart',
//         onTap: () =>
//             Navigator.of(context).pushNamed(AppRoutes.astrologyKundali),
//       ),
//       (
//         kind: AstrologyReadingKind.palm,
//         icon: Icons.back_hand_outlined,
//         title: 'Palm Insights',
//         subtitle: 'Photo · Lines · Guidance',
//         onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyPalm),
//       ),
//       (
//         kind: AstrologyReadingKind.match,
//         icon: Icons.favorite_outline,
//         title: 'Match Kundalis',
//         subtitle: 'Gun milan for two people',
//         onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyMatch),
//       ),
//       (
//         kind: AstrologyReadingKind.today,
//         icon: Icons.calendar_month_outlined,
//         title: 'Today & Periods',
//         subtitle: 'Panchang · Current dasha',
//         onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyToday),
//       ),
//     ];

//     return VisitorSessionPopScope(
//       endSessionOnPop: false,
//       child: KioskShell(
//         titleWidget: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
//           decoration: BoxDecoration(
//             color: isDark ? const Color(0xFF1E1738) : Colors.white,
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(
//               color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
//               width: 1.2,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFF7928CA).withValues(alpha: 0.08),
//                 blurRadius: 10,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text('🪐', style: TextStyle(fontSize: 16)),
//               const SizedBox(width: 8),
//               Text(
//                 'Astrology Services',
//                 style: TextStyle(
//                   fontFamily: 'PlusJakartaSans',
//                   fontSize: 14,
//                   fontWeight: FontWeight.w700,
//                   color: isDark ? Colors.white : const Color(0xFF1E1B4B),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         onHome: () => _endSession(ref),
//         stepLabel: 'Choose',
//         footerLeading: Container(
//           decoration: BoxDecoration(
//             color: isDark ? const Color(0xFF1E1738) : Colors.white,
//             borderRadius: BorderRadius.circular(22),
//             border: Border.all(
//               color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
//               width: 1.2,
//             ),
//             boxShadow: const [
//               BoxShadow(
//                 color: Color(0x0A000000),
//                 blurRadius: 8,
//                 offset: Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Material(
//             color: Colors.transparent,
//             child: InkWell(
//               onTap: () => _endSession(ref),
//               borderRadius: BorderRadius.circular(22),
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(
//                       Icons.arrow_back_rounded,
//                       size: 18,
//                       color: colors.textPrimary,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Back',
//                       style: TextStyle(
//                         fontFamily: 'PlusJakartaSans',
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: colors.textPrimary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//         body: Padding(
//           padding: const EdgeInsets.fromLTRB(32, 14, 32, 16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // 1. Headline + Gradient Accent + Subtitle
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.baseline,
//                 textBaseline: TextBaseline.alphabetic,
//                 children: [
//                   Text(
//                     'Choose a ',
//                     style: TextStyle(
//                       fontFamily: 'PlusJakartaSans',
//                       fontSize: 32,
//                       fontWeight: FontWeight.w800,
//                       letterSpacing: -0.6,
//                       color: isDark ? Colors.white : const Color(0xFF0F172A),
//                     ),
//                   ),
//                   ShaderMask(
//                     shaderCallback: (bounds) => const LinearGradient(
//                       colors: [Color(0xFF9333EA), Color(0xFFD946EF), Color(0xFFEC4899)],
//                     ).createShader(bounds),
//                     child: const Text(
//                       'Reading',
//                       style: TextStyle(
//                         fontFamily: 'PlusJakartaSans',
//                         fontSize: 32,
//                         fontWeight: FontWeight.w800,
//                         letterSpacing: -0.6,
//                         color: Colors.white,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 6),
//                   const Text(
//                     '✨',
//                     style: TextStyle(fontSize: 24),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 'Kundali, palm, matching, and daily periods.',
//                 style: TextStyle(
//                   fontFamily: 'PlusJakartaSans',
//                   fontSize: 15,
//                   fontWeight: FontWeight.w500,
//                   color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
//                 ),
//               ),
//               const SizedBox(height: 8),

//               // Glowing Underline Accent Bar
//               Container(
//                 width: 44,
//                 height: 4,
//                 alignment: Alignment.centerLeft,
//                 child: Container(
//                   width: 44,
//                   height: 4,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(2),
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFFD946EF).withValues(alpha: 0.5),
//                         blurRadius: 8,
//                         offset: const Offset(0, 1),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 12),

//               // 2. Privacy Banner (Matching Reference Image)
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 decoration: BoxDecoration(
//                   color: isDark
//                       ? const Color(0xFF064E3B).withValues(alpha: 0.35)
//                       : const Color(0xFFECFDF5),
//                   borderRadius: BorderRadius.circular(16),
//                   border: Border.all(
//                     color: isDark
//                         ? const Color(0xFF059669).withValues(alpha: 0.45)
//                         : const Color(0xFFA7F3D0),
//                     width: 1.2,
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(4),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF10B981).withValues(alpha: 0.15),
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         Icons.verified_user_rounded,
//                         color: Color(0xFF059669),
//                         size: 18,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         'We do not save birth details or palm photos. Data is used only for this reading, then cleared when you leave.',
//                         style: TextStyle(
//                           fontFamily: 'PlusJakartaSans',
//                           fontSize: 13.5,
//                           fontWeight: FontWeight.w600,
//                           color: isDark
//                               ? const Color(0xFFA7F3D0)
//                               : const Color(0xFF065F46),
//                           height: 1.3,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 16),

//               // 3. 2x2 Reading Cards
//               Expanded(
//                 child: Column(
//                   children: [
//                     for (var row = 0; row < 2; row++) ...[
//                       if (row > 0) const SizedBox(height: 16),
//                       Expanded(
//                         child: Row(
//                           children: [
//                             Expanded(
//                               child: AstrologyReadingCard(
//                                 kind: tiles[row * 2].kind,
//                                 icon: tiles[row * 2].icon,
//                                 title: tiles[row * 2].title,
//                                 subtitle: tiles[row * 2].subtitle,
//                                 onTap: tiles[row * 2].onTap,
//                               ),
//                             ),
//                             const SizedBox(width: 16),
//                             Expanded(
//                               child: AstrologyReadingCard(
//                                 kind: tiles[row * 2 + 1].kind,
//                                 icon: tiles[row * 2 + 1].icon,
//                                 title: tiles[row * 2 + 1].title,
//                                 subtitle: tiles[row * 2 + 1].subtitle,
//                                 onTap: tiles[row * 2 + 1].onTap,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/theme/athena_colors.dart';
import 'package:skp_kiosk/core/ui/ui.dart';
import 'package:skp_kiosk/features/astrology/presentation/widgets/reading_mark.dart';
import 'package:skp_kiosk/features/session/application/kiosk_session_controller.dart';
import 'package:skp_kiosk/features/session/presentation/visitor_session_pop_scope.dart';

class AstrologyHubPage extends ConsumerWidget {
  const AstrologyHubPage({super.key});

  Future<void> _endSession(WidgetRef ref) {
    return ref
        .read(kioskSessionControllerProvider.notifier)
        .endVisitorSession(attract: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.athenaColors;

    final tiles = [
      (
        kind: AstrologyReadingKind.kundali,
        image: 'assets/new_theme_icons/astrology/my_kundali.png',
        title: 'My Kundali',
        subtitle: 'North or South Indian chart',
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoutes.astrologyKundali),
      ),
      (
        kind: AstrologyReadingKind.palm,
        image: 'assets/new_theme_icons/astrology/palm_insights.png',
        title: 'Palm Insights',
        subtitle: 'Photo · Lines · Guidance',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyPalm),
      ),
      (
        kind: AstrologyReadingKind.match,
        image: 'assets/new_theme_icons/astrology/match_kundalis.png',
        title: 'Match Kundalis',
        subtitle: 'Gun milan for two people',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyMatch),
      ),
      (
        kind: AstrologyReadingKind.today,
        image: 'assets/new_theme_icons/astrology/today_periods.png',
        title: 'Today & Periods',
        subtitle: 'Panchang · Current dasha',
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.astrologyToday),
      ),
    ];

    return VisitorSessionPopScope(
      endSessionOnPop: false,
      child: KioskShell(
        titleWidget: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1738) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7928CA).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Astrology Services',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
        ),
        onHome: () => _endSession(ref),
        stepLabel: 'Choose',
        footerLeading: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1738) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF4A3474) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _endSession(ref),
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: colors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(32, 14, 32, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Headline + Gradient Accent + Subtitle
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Choose a ',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFFD946EF), Color(0xFFEC4899)],
                    ).createShader(bounds),
                    child: const Text(
                      'Reading',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '✨',
                    style: TextStyle(fontSize: 24),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Kundali, palm, matching, and daily periods.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),

              // Glowing Underline Accent Bar
              Container(
                width: 44,
                height: 4,
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9333EA), Color(0xFFEC4899)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD946EF).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Privacy Banner (Matching Reference Image)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF059669).withValues(alpha: 0.45)
                        : const Color(0xFFA7F3D0),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF059669),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We do not save birth details or palm photos. Data is used only for this reading, then cleared when you leave.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFF065F46),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. 2x2 Reading Cards
              Expanded(
                child: Column(
                  children: [
                    for (var row = 0; row < 2; row++) ...[
                      if (row > 0) const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: AstrologyReadingCard(
                                kind: tiles[row * 2].kind,
                                image: tiles[row * 2].image,
                                title: tiles[row * 2].title,
                                subtitle: tiles[row * 2].subtitle,
                                onTap: tiles[row * 2].onTap,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AstrologyReadingCard(
                                kind: tiles[row * 2 + 1].kind,
                                image: tiles[row * 2 + 1].image,
                                title: tiles[row * 2 + 1].title,
                                subtitle: tiles[row * 2 + 1].subtitle,
                                onTap: tiles[row * 2 + 1].onTap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}