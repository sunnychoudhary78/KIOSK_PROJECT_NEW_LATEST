import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_mobile/app/router.dart';
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
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (auth.isAuthenticated) {
      return const SkpNavShell();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -size.width * 0.18,
            top: -size.height * 0.06,
            child: IgnorePointer(
              child: SizedBox(
                width: size.width * 0.78,
                height: size.height * 0.34,
                child: const CustomPaint(painter: _TopWavePainter()),
              ),
            ),
          ),
          Positioned(
            left: -size.width * 0.12,
            right: -size.width * 0.08,
            bottom: -size.height * 0.04,
            height: size.height * 0.34,
            child: const IgnorePointer(
              child: CustomPaint(painter: _BottomWavePainter()),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 22),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      const _AthenaaLogo(),
                      const SizedBox(height: 22),
                      Text(
                        l10n.guestSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5C5C66),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _WelcomeSteps(
                        steps: [
                          l10n.stepUpload,
                          l10n.stepOtpSms,
                          l10n.stepPrint,
                        ],
                      ),
                      const Spacer(flex: 3),
                      _GradientCtaButton(
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

class _AthenaaLogo extends StatelessWidget {
  const _AthenaaLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/logo/athenaa_immortech.png',
        height: 92,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _WelcomeSteps extends StatelessWidget {
  const _WelcomeSteps({required this.steps});

  final List<String> steps;

  static const _pink = Color(0xFFFF4FA3);
  static const _pinkSoft = Color(0xFFFFD6EC);

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
                color: const Color(0xFFE5E5EA),
              ),
            ),
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _pinkSoft, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _pink.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  '${i + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _pink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                steps[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B6B76),
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

class _GradientCtaButton extends StatelessWidget {
  const _GradientCtaButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFFF4FA3),
                Color(0xFFE84AB5),
                Color(0xFF8B5CFF),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4FA3).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.smartphone_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopWavePainter extends CustomPainter {
  const _TopWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFF4FA3),
          Color(0xFFE84AB5),
          Color(0xFF7B6CFF),
          Color(0xFF4DA3FF),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(size.width * 0.18, 0)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.22,
        size.width * 0.55,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.12,
        size.width,
        size.height * 0.42,
      )
      ..quadraticBezierTo(
        size.width * 1.02,
        size.height * 0.72,
        size.width * 0.72,
        size.height * 0.86,
      )
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.98,
        size.width * 0.28,
        size.height * 0.62,
      )
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.28,
        size.width * 0.18,
        0,
      )
      ..close();

    canvas.drawPath(path, paint);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWavePainter extends CustomPainter {
  const _BottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFF4DA3FF),
          Color(0xFF7B6CFF),
          Color(0xFFE84AB5),
          Color(0xFFFF4FA3),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.22,
        size.width * 0.4,
        size.height * 0.38,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.55,
        size.width * 0.78,
        size.height * 0.32,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.12,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final crest = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.18,
        size.height * 0.22,
        size.width * 0.4,
        size.height * 0.38,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.55,
        size.width * 0.78,
        size.height * 0.32,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.12,
        size.width,
        size.height * 0.28,
      );

    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
