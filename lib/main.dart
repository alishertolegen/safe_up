import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'login.dart';
import 'register.dart';
import 'home.dart';
import 'profile_page.dart';
import 'create_training_screen.dart';
import 'my_trainings_screen.dart';
import 'ProfileEditScreen.dart';
import 'reset_password_screen.dart';
import 'forgot_password_screen.dart';

void main() {
  runApp(const StartApp());
}

class StartApp extends StatelessWidget {
  const StartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return Scaffold(
              body: child,
              bottomNavigationBar: NavigationBar(
                backgroundColor: Colors.white,
                indicatorColor: const Color.fromARGB(255, 255, 35, 49),
                selectedIndex: _calculateSelectedIndex(state),
                onDestinationSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go('/home');
                      break;
                    case 1:
                      context.go('/create');
                      break;
                    case 2:
                      context.go('/mytrainings');
                      break;
                    case 3:
                      context.go('/profile');
                      break;
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_filled, color: Colors.black),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.add_box_outlined, color: Colors.black),
                    label: 'Создать',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.list_alt, color: Colors.black),
                    label: 'Мои тренировки',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person, color: Colors.black),
                    label: 'Профиль',
                  ),
                ],
              ),
            );
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/create',
              builder: (context, state) => const CreateTrainingScreen(),
            ),
            GoRoute(
              path: '/mytrainings',
              builder: (context, state) => const MyTrainingsScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/profile/edit',
              builder: (context, state) => const ProfileEditScreen(),
            ),

    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // Здесь: если state.extra — ожидаем Map с 'email'
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        String? initialEmail;
        if (state.extra != null && state.extra is Map && (state.extra as Map).containsKey('email')) {
          initialEmail = (state.extra as Map)['email'] as String?;
        }
        return ResetPasswordScreen(initialEmail: initialEmail);
      },
    ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Тренажёр эвакуации',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.red,
      ),
    );
  }
}

int _calculateSelectedIndex(GoRouterState state) {
  final location = state.matchedLocation;
  if (location.startsWith('/profile')) return 3;
  if (location.startsWith('/mytrainings')) return 2;
  if (location.startsWith('/create')) return 1;
  return 0; // /home и прочие
}
