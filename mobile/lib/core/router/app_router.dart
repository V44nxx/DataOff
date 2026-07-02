import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/person_form_screen.dart';
import '../../domain/repositories/auth_repository.dart';
import '../di/injection.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      redirect: (context, state) async {
        final authRepo = getIt<AuthRepository>();
        final isLoggedIn = await authRepo.isLoggedIn();
        if (isLoggedIn) {
          return AppRoutes.home;
        }
        return AppRoutes.login;
      },
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.personNew,
      builder: (context, state) => const PersonFormScreen(),
    ),
  ],
);
