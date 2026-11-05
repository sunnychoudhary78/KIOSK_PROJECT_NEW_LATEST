import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 3D Pulse Oximeter Graphic with Glowing OLED Screen (SpO2 98%, Heart Rate, Wave).
class Oximeter3DGraphic extends StatelessWidget {
  const Oximeter3DGraphic({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _Oximeter3DPainter(),
      ),
    );
  }
}

class _Oximeter3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;

    // 1. Glowing pedestal base
    final baseCenter = Offset(center.dx, center.dy + radius * 0.72);
    final baseRect = Rect.fromCenter(
      center: baseCenter,
      width: radius * 1.6,
      height: radius * 0.38,
    );
    canvas.drawOval(
      baseRect,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawOval(
      baseRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
        ).createShader(baseRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 2. 3D Oximeter Body (isometric angled rounded box)
    final bodyCenter = Offset(center.dx, center.dy - radius * 0.08);
    final bodyW = radius * 1.15;
    final bodyH = radius * 1.35;
    final bodyRect = Rect.fromCenter(center: bodyCenter, width: bodyW, height: bodyH);

    // Body shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect.translate(0, 6), const Radius.circular(18)),
      Paint()
        ..color = const Color(0xFF1E1B4B).withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Lower clip jaw (purple/indigo)
    final lowerJawRect = Rect.fromCenter(
      center: Offset(bodyCenter.dx, bodyCenter.dy + 8),
      width: bodyW,
      height: bodyH,
    );
    final lowerJawShader = const LinearGradient(
      colors: [Color(0xFF4338CA), Color(0xFF312E81), Color(0xFF1E1B4B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(lowerJawRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lowerJawRect, const Radius.circular(18)),
      Paint()..shader = lowerJawShader,
    );

    // Glowing finger slot aperture
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bodyCenter.dx, bodyCenter.dy + bodyH * 0.38), width: bodyW * 0.75, height: 10),
        const Radius.circular(5),
      ),
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Upper clip body (sleek white/lavender with gradient)
    final upperJawShader = const LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bodyRect);
    final upperRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(18));
    canvas.drawRRect(upperRRect, Paint()..shader = upperJawShader);

    // Chrome edge border
    canvas.drawRRect(
      upperRRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFFC084FC)],
        ).createShader(bodyRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 3. Dark OLED Screen
    final screenRect = Rect.fromCenter(
      center: Offset(bodyCenter.dx, bodyCenter.dy - 6),
      width: bodyW * 0.76,
      height: bodyH * 0.65,
    );
    final screenRRect = RRect.fromRectAndRadius(screenRect, const Radius.circular(10));
    canvas.drawRRect(
      screenRRect,
      Paint()..color = const Color(0xFF0B0F19),
    );
    canvas.drawRRect(
      screenRRect,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 4. Screen Content: "SpO2", "98%", Heart, Wave
    // SpO2 Label
    final tpSpo2 = TextPainter(
      text: const TextSpan(
        text: 'SpO2',
        style: TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpSpo2.paint(canvas, Offset(screenRect.left + 6, screenRect.top + 6));

    // Heart icon
    final tpHeart = TextPainter(
      text: const TextSpan(
        text: '♥',
        style: TextStyle(
          color: Color(0xFFF43F5E),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpHeart.paint(canvas, Offset(screenRect.right - 14, screenRect.top + 5));

    // "98%"
    final tpValue = TextPainter(
      text: const TextSpan(
        text: '98%',
        style: TextStyle(
          color: Color(0xFF38BDF8),
          fontSize: 16.0,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpValue.paint(canvas, Offset(screenRect.left + 5, screenRect.top + 16));

    // ECG wave line at bottom of screen
    final wavePath = Path();
    final waveY = screenRect.bottom - 9;
    final wLeft = screenRect.left + 5;
    final wRight = screenRect.right - 5;
    final wWidth = wRight - wLeft;

    wavePath.moveTo(wLeft, waveY);
    wavePath.lineTo(wLeft + wWidth * 0.25, waveY);
    wavePath.lineTo(wLeft + wWidth * 0.35, waveY - 4);
    wavePath.lineTo(wLeft + wWidth * 0.45, waveY + 5);
    wavePath.lineTo(wLeft + wWidth * 0.55, waveY - 7);
    wavePath.lineTo(wLeft + wWidth * 0.65, waveY + 2);
    wavePath.lineTo(wLeft + wWidth * 0.75, waveY);
    wavePath.lineTo(wRight, waveY);

    canvas.drawPath(
      wavePath,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Circular Thermometer Gauge with 3D Glowing Arc and Thermometer.
class Thermometer3DGraphic extends StatelessWidget {
  const Thermometer3DGraphic({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _Thermometer3DPainter(),
      ),
    );
  }
}

class _Thermometer3DPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.46;

    // 1. Soft glowing background circle
    final glowRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius * 0.95,
      Paint()
        ..color = const Color(0xFFF43F5E).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Track circle (light pink)
    canvas.drawCircle(
      center,
      radius * 0.85,
      Paint()
        ..color = const Color(0xFFFCE7F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0,
    );

    // 2. Glowing pink measurement progress arc (~220 degrees)
    final arcPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF43F5E), Color(0xFFFB7185), Color(0xFFFDA4AF)],
      ).createShader(glowRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      -math.pi * 0.8,
      math.pi * 1.3,
      false,
      arcPaint,
    );

    // Arc tip glow point
    final tipAngle = -math.pi * 0.8 + math.pi * 1.3;
    final tipPoint = Offset(
      center.dx + radius * 0.85 * math.cos(tipAngle),
      center.dy + radius * 0.85 * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tipPoint,
      4.0,
      Paint()
        ..color = const Color(0xFFF43F5E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(tipPoint, 3.0, Paint()..color = Colors.white);

    // 3. Modern 3D Thermometer in center
    final thermoW = radius * 0.32;
    final thermoH = radius * 0.95;
    final stemTop = center.dy - thermoH * 0.45;
    final bulbCenter = Offset(center.dx, center.dy + thermoH * 0.30);
    final bulbRadius = thermoW * 0.9;

    // Thermometer outer glass tube
    final tubeRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - thermoH * 0.05),
      width: thermoW,
      height: thermoH * 0.72,
    );
    final tubeRRect = RRect.fromRectAndRadius(tubeRect, Radius.circular(thermoW / 2));

    // Bulb outer glass
    canvas.drawCircle(bulbCenter, bulbRadius, Paint()..color = const Color(0xFFFCE7F3));
    canvas.drawRRect(tubeRRect, Paint()..color = const Color(0xFFFCE7F3));

    // Red liquid column & bulb
    final liquidShader = const LinearGradient(
      colors: [Color(0xFFFB7185), Color(0xFFE11D48), Color(0xFFBE185D)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(center.dx - thermoW / 2, stemTop, thermoW, thermoH));

    // Liquid bulb
    canvas.drawCircle(
      bulbCenter,
      bulbRadius * 0.75,
      Paint()
        ..color = const Color(0xFFE11D48)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(bulbCenter, bulbRadius * 0.70, Paint()..shader = liquidShader);

    // Liquid stem
    final innerTubeRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - thermoH * 0.05),
      width: thermoW * 0.42,
      height: thermoH * 0.58,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerTubeRect, Radius.circular(thermoW * 0.21)),
      Paint()..shader = liquidShader,
    );

    // Measurement tick marks on right side of tube
    final tickPaint = Paint()
      ..color = const Color(0xFFE11D48)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final y = center.dy - thermoH * 0.28 + i * 8.0;
      canvas.drawLine(
        Offset(center.dx + thermoW * 0.6, y),
        Offset(center.dx + thermoW * 0.95, y),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3D Health Hero Illustration: Glossy Red Heart + ECG Pulse Wave + Athena Kiosk Terminal.
class HealthHeroIllustration extends StatelessWidget {
  const HealthHeroIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 280,
      height: 120,
      child: CustomPaint(
        painter: _HealthHeroPainter(),
      ),
    );
  }
}

class _HealthHeroPainter extends CustomPainter {
  const _HealthHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Concentric elliptical pedestal glow rings
    final baseCenter = Offset(size.width * 0.68, size.height * 0.88);
    final baseRect1 = Rect.fromCenter(center: baseCenter, width: 180, height: 26);
    canvas.drawOval(
      baseRect1,
      Paint()
        ..color = const Color(0xFFE11D48).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawOval(
      baseRect1,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFDA4AF), Color(0xFFF43F5E), Color(0xFFC084FC)],
        ).createShader(baseRect1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // 2. ECG Heartbeat line glowing across behind heart
    final ecgPath = Path();
    const ecgY = 56.0;
    ecgPath.moveTo(0, ecgY);
    ecgPath.lineTo(size.width * 0.18, ecgY);
    ecgPath.lineTo(size.width * 0.24, ecgY - 14);
    ecgPath.lineTo(size.width * 0.28, ecgY + 16);
    ecgPath.lineTo(size.width * 0.33, ecgY - 26);
    ecgPath.lineTo(size.width * 0.38, ecgY + 8);
    ecgPath.lineTo(size.width * 0.44, ecgY);
    ecgPath.lineTo(size.width * 0.85, ecgY);

    canvas.drawPath(
      ecgPath,
      Paint()
        ..color = const Color(0xFFF43F5E).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      ecgPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFB7185), Color(0xFFF43F5E), Color(0xFFD946EF)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // 3. 3D Glossy Red Heart
    final heartCenter = Offset(size.width * 0.42, 54.0);
    const hSize = 34.0;
    final heartPath = Path();
    heartPath.moveTo(heartCenter.dx, heartCenter.dy + hSize * 0.38);
    heartPath.cubicTo(
      heartCenter.dx - hSize * 0.78,
      heartCenter.dy - hSize * 0.18,
      heartCenter.dx - hSize * 0.78,
      heartCenter.dy - hSize * 0.75,
      heartCenter.dx,
      heartCenter.dy - hSize * 0.50,
    );
    heartPath.cubicTo(
      heartCenter.dx + hSize * 0.78,
      heartCenter.dy - hSize * 0.75,
      heartCenter.dx + hSize * 0.78,
      heartCenter.dy - hSize * 0.18,
      heartCenter.dx,
      heartCenter.dy + hSize * 0.38,
    );
    heartPath.close();

    // Heart shadow and glow
    canvas.drawPath(
      heartPath,
      Paint()
        ..color = const Color(0xFFF43F5E).withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    final heartShader = const RadialGradient(
      center: Alignment(-0.3, -0.4),
      colors: [Color(0xFFFDA4AF), Color(0xFFF43F5E), Color(0xFFBE185D), Color(0xFF881337)],
      stops: [0.0, 0.4, 0.8, 1.0],
    ).createShader(Rect.fromCircle(center: heartCenter, radius: hSize));
    canvas.drawPath(heartPath, Paint()..shader = heartShader);

    // Specular highlight on left lobe
    canvas.drawOval(
      Rect.fromCenter(center: Offset(heartCenter.dx - 10, heartCenter.dy - 12), width: 10, height: 6),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // 4. Sleek Athena Kiosk Terminal on right
    final kioskCenter = Offset(size.width * 0.78, 52.0);
    const kW = 48.0;
    const kH = 76.0;
    final kRect = Rect.fromCenter(center: kioskCenter, width: kW, height: kH);
    final kRRect = RRect.fromRectAndRadius(kRect, const Radius.circular(12));

    // Terminal shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(kRect.translate(0, 8), const Radius.circular(12)),
      Paint()
        ..color = const Color(0xFF1E1B4B).withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Terminal White Cabinet
    final kShader = const LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFEDE9FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(kRect);
    canvas.drawRRect(kRRect, Paint()..shader = kShader);
    canvas.drawRRect(
      kRRect,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Screen Bezel (midnight purple)
    final scrRect = Rect.fromCenter(
      center: Offset(kioskCenter.dx, kioskCenter.dy - 14),
      width: kW * 0.78,
      height: 38,
    );
    final scrRRect = RRect.fromRectAndRadius(scrRect, const Radius.circular(8));
    canvas.drawRRect(scrRRect, Paint()..color = const Color(0xFF1E1035));

    // Athena Purple Target Logo on screen
    canvas.drawCircle(
      Offset(kioskCenter.dx, scrRect.top + 13),
      7,
      Paint()
        ..color = const Color(0xFF9333EA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(
      Offset(kioskCenter.dx, scrRect.top + 13),
      3,
      Paint()..color = const Color(0xFFEC4899),
    );

    // Athena label
    final tpAthena = TextPainter(
      text: const TextSpan(
        text: 'ATHENA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 5.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpAthena.paint(canvas, Offset(kioskCenter.dx - tpAthena.width / 2, scrRect.bottom - 11));

    // Pulse Sensor Aperture Bay on lower body
    final sensorRect = Rect.fromCenter(
      center: Offset(kioskCenter.dx, kioskCenter.dy + 20),
      width: 14,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sensorRect, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFFF43F5E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sensorRect, const Radius.circular(5)),
      Paint()..color = const Color(0xFFBE185D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

