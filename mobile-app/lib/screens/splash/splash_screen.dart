import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/app_lifecycle_service.dart';
import '../../core/services/notification_service.dart';
import '../../widgets/common/app_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runStartupFlow();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  Future<void> _runStartupFlow() async {
    final authService = ref.read(authServiceProvider);
    final startupDelay = Future<void>.delayed(const Duration(seconds: 3));
    final authRefresh = authService.reloadCurrentUser().timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
    final updateCheck = ref.read(appUpdateCoordinatorProvider).checkOnStartup(
          context,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );

    await startupDelay;
    await authRefresh;
    await updateCheck;

    if (mounted) {
      unawaited(NotificationService.init());

      if (authService.isLoggedIn) {
        context.go('/main');
      } else {
        context.go('/auth/login');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    const AppLogo(
                      size: 120,
                      borderRadius: 20,
                      padding: EdgeInsets.all(16),
                      backgroundColor: Colors.white,
                      showShadow: true,
                    ),

                    const SizedBox(height: 32),

                    // App Name
                    Text(
                      'Blue Video',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 8),

                    // App Tagline
                    Text(
                      'Your Video Social Platform',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: Colors.white70),
                    ),

                    const SizedBox(height: 48),

                    // Loading Indicator
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
