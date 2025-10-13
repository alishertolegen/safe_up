import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'login.dart';
import 'register.dart';
import 'home.dart';
import 'scenario.dart';
import 'profile_page.dart';

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
                      context.go('/scenario');
                      break;
                    case 2:
                      context.go('/profile');
                      break;
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_max_sharp, color: Colors.black),
                    label: 'Главная',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.safety_check, color: Colors.black),
                    label: 'Сценарий',
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
              path: '/scenario',
              builder: (context, state) => const ScenarioScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

int _calculateSelectedIndex(GoRouterState state) {
  final location = state.matchedLocation;
  if (location.startsWith('/scenario')) return 1;
  return 0;
}
