import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_type.dart';
import '../../core/widgets/dp_card.dart';
import '../../core/widgets/page_header.dart';
import '../../data/services/settings_store.dart';
import '../../features/shell/app_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.shield_outlined,
      eyebrow: 'OFFLINE BY DESIGN',
      title: 'Your drives.\nFully local.',
      body:
          'DrivePulse never asks for an account, never uploads a filename and '
          'ships without a network permission. Everything stays on your device.',
      points: <String>[
        'No sign-up, no cloud, no tracking',
        'Files never leave the phone',
        'Works with the radio off',
      ],
    ),
    _Slide(
      icon: Icons.folder_copy_outlined,
      eyebrow: 'REAL FILE CONTROL',
      title: 'Every file,\nunder control.',
      body:
          'Browse USB drives, SD cards and internal storage. Copy, move, rename, '
          'search and clean up — with a live transfer queue you can pause.',
      points: <String>[
        'Scoped storage access on Android',
        'Copy & move with progress',
        'AES-256 encryption vault',
      ],
    ),
    _Slide(
      icon: Icons.speed_rounded,
      eyebrow: 'HARDWARE TELEMETRY',
      title: 'Know before\nyou unplug.',
      body:
          'Measured read/write benchmarks, capacity gauges and a safe-eject '
          'checklist so a half-written file never costs you a drive.',
      points: <String>[
        'Local read/write benchmark',
        'Junk, duplicate and large-file scans',
        'Safe eject with open-file checks',
      ],
    ),
  ];

  Future<void> _finish() async {
    await context.read<SettingsController>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.screen, Insets.md, Insets.screen, 0),
              child: Row(
                children: <Widget>[
                  const BrandMark(size: 32),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: AppType.bodySmall(c.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (int index) => setState(() => _page = index),
                itemBuilder: (BuildContext context, int index) =>
                    _SlideView(slide: _slides[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.sm, Insets.xl, Insets.xl),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: DpDurations.base,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page ? c.primary : c.borderStrong,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  SizedBox(
                    width: double.infinity,
                    child: DpPrimaryButton(
                      label: _page == _slides.length - 1
                          ? 'Open DrivePulse'
                          : 'Continue',
                      icon: _page == _slides.length - 1
                          ? Icons.arrow_forward_rounded
                          : null,
                      onPressed: _next,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Android & iOS • no account required',
                    style: AppType.bodySmall(c.textFaint).copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.points,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final List<String> points;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, Insets.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 196,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      c.surface,
                      c.surfaceAlt,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: c.border),
                ),
                child: Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: c.primary.withValues(alpha: 0.25)),
                    ),
                    child: Icon(slide.icon, size: 38, color: c.primary),
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text(slide.eyebrow, style: AppType.labelCaps(c.primary)),
              const SizedBox(height: Insets.sm),
              Text(
                slide.title,
                style: AppType.displayMedium(c.text).copyWith(height: 1.06),
              ),
              const SizedBox(height: Insets.md),
              Text(
                slide.body,
                style: AppType.bodyLarge(c.textMuted).copyWith(height: 1.45),
              ),
              const SizedBox(height: Insets.xl),
              for (final String point in slide.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c.successSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.success.withValues(alpha: 0.3)),
                        ),
                        child: Icon(Icons.check_rounded, size: 12, color: c.success),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          point,
                          style: AppType.bodyMedium(c.text).copyWith(fontSize: 13.5),
                        ),
                      ),
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
