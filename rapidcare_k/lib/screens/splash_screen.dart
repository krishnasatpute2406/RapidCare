import 'package:flutter/material.dart';
import 'patient/patient_dashboard.dart'; // Update path if necessary

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _lineAnimation;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _lineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientDashboard()),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Changed from deep green to black
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _lineAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(36, 24),
                      painter: ECGPainter(progress: _lineAnimation.value),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            FadeTransition(
              opacity: _textFadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.2, 0.0),
                  end: Offset.zero,
                ).animate(_textFadeAnimation),
                child: const Text(
                  'RapidCare',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ECGPainter extends CustomPainter {
  final double progress;

  ECGPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    final points = [
      Offset(0, h * 0.5),
      Offset(w * 0.25, h * 0.5),
      Offset(w * 0.35, h * 0.2),
      Offset(w * 0.45, h * 0.85),
      Offset(w * 0.55, h * 0.35),
      Offset(w * 0.65, h * 0.5),
      Offset(w, h * 0.5),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final metric = path.computeMetrics().first;
    final extractPath = metric.extractPath(0.0, metric.length * progress);

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant ECGPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}