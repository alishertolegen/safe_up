import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'login.dart';
import 'register.dart';
import 'home.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';



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
                indicatorColor: Colors.indigoAccent,
                selectedIndex: _calculateSelectedIndex(state),
                onDestinationSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go('/home');
                      break;
                    case 1:
                      context.go('/generate');
                      break;
                    case 2:
                      context.go('/courses');
                      break;
                    case 3:
                      context.go('/profile');
                      break;
                  }
                },
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.home, color: Colors.black), label: 'Главная',),
                  NavigationDestination(icon: Icon(Icons.auto_awesome_outlined, color: Colors.black), label: 'Создать'),
                  NavigationDestination(icon: Icon(Icons.book_online_outlined, color: Colors.black), label: 'Курсы'),
                  NavigationDestination(icon: Icon(Icons.person, color: Colors.black), label: 'Профиль'),
                ],
              ),
            );
          },
          routes: [
            GoRoute(
              path: '/course/:id',
              builder: (context, state) => const HomeScreen(),
            ),

            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/generate',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/courses',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const HomeScreen(),
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
  if (location.startsWith('/profile')) return 3;
  if (location.startsWith('/courses')) return 2;
  if (location.startsWith('/generate')) return 1;
  return 0;
}
