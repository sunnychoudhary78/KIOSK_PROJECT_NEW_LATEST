import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/core/ui/skp_nav_shell.dart';
import 'package:skp_mobile/features/auth/application/citizen_auth.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));
    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(citizenAuthProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    if (auth.restoring) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F1E6),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAuthenticated) {
      return const SkpNavShell();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1E6),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBF7EF),
                    Color(0xFFF7F1E6),
                    Color(0xFFF3EBDC),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -70,
            top: -50,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SkpColors.accent.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: 80,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SkpColors.accentBright.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: size.height * 0.12,
            child: IgnorePointer(
              child: SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _LeafClusterPainter(
                    color: SkpColors.accent.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.28,
            child: const IgnorePointer(
              child: CustomPaint(painter: _WelcomeWavePainter()),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      Text(
                        l10n.brandName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontFamily: 'serif',
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B4F42),
                          fontSize: 42,
                          height: 1.05,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: SizedBox(
                          width: 110,
                          height: 16,
                          child: CustomPaint(painter: _GoldSwooshPainter()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.guestSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF6B6A7A),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 36),
                      _WelcomeSteps(
                        steps: [
                          l10n.stepUpload,
                          l10n.stepOtpSms,
                          l10n.stepPrint,
                        ],
                      ),
                      const Spacer(flex: 3),
                      _GoldEdgeButton(
                        label: l10n.signInCta,
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.login),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeSteps extends StatelessWidget {
  const _WelcomeSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SkpColors.line,
                      SkpColors.accent.withValues(alpha: 0.35),
                      SkpColors.line,
                    ],
                  ),
                ),
              ),
            ),
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8EFE6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SkpColors.accent.withValues(alpha: 0.25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SkpColors.accent.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  '${i + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF0B4F42),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                steps[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: SkpColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GoldEdgeButton extends StatelessWidget {
  const _GoldEdgeButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8C872), Color(0xFFF5E6A8), Color(0xFFD4A84B)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.2),
      child: Material(
        color: const Color(0xFF0B4F42),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoldSwooshPainter extends CustomPainter {
  const _GoldSwooshPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFD4A84B), Color(0xFFF5E6A8), Color(0xFFE8C872)],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.08,
        size.width * 0.7,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.72,
        size.width,
        size.height * 0.35,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WelcomeWavePainter extends CustomPainter {
  const _WelcomeWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final mandalaPaint = Paint()
      ..color = const Color(0x22C4B59A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final center = Offset(size.width * 0.78, size.height * 0.62);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(center, 16.0 * i, mandalaPaint);
    }

    final wave = Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.18,
        size.width * 0.4,
        size.height * 0.55,
        size.width * 0.58,
        size.height * 0.4,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.24,
        size.width * 0.9,
        size.height * 0.2,
        size.width,
        size.height * 0.34,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      wave,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F6A5A).withValues(alpha: 0.92),
            const Color(0xFF0B4F42),
            const Color(0xFF083D34),
          ],
        ).createShader(Offset.zero & size),
    );

    final goldPath = Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.18,
        size.width * 0.4,
        size.height * 0.55,
        size.width * 0.58,
        size.height * 0.4,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.24,
        size.width * 0.9,
        size.height * 0.2,
        size.width,
        size.height * 0.34,
      );

    canvas.drawPath(
      goldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFFD4A84B), Color(0xFFF8E7A0), Color(0xFFE8C872)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LeafClusterPainter extends CustomPainter {
  const _LeafClusterPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    void leaf(Offset tip, double angle, double len, double width) {
      canvas.save();
      canvas.translate(tip.dx, tip.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(width, -len * 0.45, 0, -len)
        ..quadraticBezierTo(-width, -len * 0.45, 0, 0)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    leaf(Offset(size.width * 0.55, size.height * 0.7), -0.4, 42, 14);
    leaf(Offset(size.width * 0.65, size.height * 0.62), 0.35, 36, 12);
    leaf(Offset(size.width * 0.4, size.height * 0.58), -1.0, 30, 11);
  }

  @override
  bool shouldRepaint(covariant _LeafClusterPainter oldDelegate) =>
      oldDelegate.color != color;
}
