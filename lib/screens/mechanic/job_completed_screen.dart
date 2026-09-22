import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cores/providers/bookings_provider.dart';
import '../../cores/theme/app_theme.dart';
import '../../widgets/app_buttons.dart';
import 'mechanic_home_screen.dart';

class JobCompletedScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const JobCompletedScreen({super.key, required this.bookingId});

  @override
  ConsumerState<JobCompletedScreen> createState() => _JobCompletedScreenState();
}

class _JobCompletedScreenState extends ConsumerState<JobCompletedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final random = math.Random();
    _particles = List.generate(45, (i) {
      return _ConfettiParticle(
        x: random.nextDouble(),
        y: random.nextDouble() * -0.5,
        size: random.nextDouble() * 7 + 4,
        speed: random.nextDouble() * 0.4 + 0.3,
        drift: random.nextDouble() * 60 - 30,
        rotationSpeed: random.nextDouble() * 4 + 2,
        seed: random.nextDouble() * 100,
        isCircle: random.nextBool(),
        color: [
          Colors.amber,
          Colors.tealAccent,
          Colors.pinkAccent,
          Colors.lightBlueAccent,
          Colors.greenAccent,
          Colors.orangeAccent,
          Colors.purpleAccent,
        ][random.nextInt(7)],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingDetailsProvider(widget.bookingId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Animated Confetti Party Popper background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    animation: _controller,
                    particles: _particles,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: booking.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
              data: (data) {
                if (data == null) {
                  return const Center(child: Text('Booking not found.'));
                }

                final rawAmount = data['agreed_price'] ?? data['budget_price'];
                final amount = rawAmount is num ? rawAmount.toDouble() : 0.0;
                final method = data['payment_method']?.toString() ?? 'Cash';

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Spacer(),
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.1).animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.celebration,
                            size: 52,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Job Completed! 🎉',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customer confirmed payment & rated your service',
                        style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.colors.borderStrong.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payment Earned:'),
                                Text(
                                  'PKR ${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Payment Method:'),
                                Text(
                                  method,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      AccentButton(
                        label: 'Back to Dashboard',
                        onPressed: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MechanicHomeScreen(),
                          ),
                          (_) => false,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double drift;
  final double rotationSpeed;
  final double seed;
  final bool isCircle;
  final Color color;

  const _ConfettiParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.drift,
    required this.rotationSpeed,
    required this.seed,
    required this.isCircle,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.animation, required this.particles})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    for (final p in particles) {
      final dx = (p.x * size.width + math.sin(progress * 6 + p.seed) * p.drift) % size.width;
      final dy = ((p.y + progress * p.speed) % 1.0) * size.height;
      final opacity = (1.0 - (dy / size.height)).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(progress * p.rotationSpeed);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size * 1.8, height: p.size * 0.9),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
