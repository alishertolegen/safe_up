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
import 'rating.dart';


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
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            String? initialEmail;
            if (state.extra != null && 
                state.extra is Map && 
                (state.extra as Map).containsKey('email')) {
              initialEmail = (state.extra as Map)['email'] as String?;
            }
            return ResetPasswordScreen(initialEmail: initialEmail);
          },
        ),
        ShellRoute(
          builder: (context, state, child) {
            final selectedIndex = _calculateSelectedIndex(state);
            
            return Scaffold(
              body: child,
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: NavigationBar(
                  backgroundColor: Colors.white,
                  indicatorColor: Colors.blue.shade600.withOpacity(0.15),
                  selectedIndex: selectedIndex,
                  elevation: 0,
                  height: 70,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
                      case 4:
                        context.go('/rating');
                        break;
                    }
                  },
                  destinations: [
                    NavigationDestination(
                      icon: Icon(
                        Icons.home_outlined,
                        color: selectedIndex == 0 
                            ? Colors.blue.shade600 
                            : Colors.grey.shade600,
                      ),
                      selectedIcon: Icon(
                        Icons.home,
                        color: Colors.blue.shade600,
                      ),
                      label: 'Главная',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.add_box_outlined,
                        color: selectedIndex == 1 
                            ? Colors.blue.shade600 
                            : Colors.grey.shade600,
                      ),
                      selectedIcon: Icon(
                        Icons.add_box,
                        color: Colors.blue.shade600,
                      ),
                      label: 'Создать',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.list_alt_outlined,
                        color: selectedIndex == 2 
                            ? Colors.blue.shade600 
                            : Colors.grey.shade600,
                      ),
                      selectedIcon: Icon(
                        Icons.list_alt,
                        color: Colors.blue.shade600,
                      ),
                      label: 'Тренировки',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.person_outline,
                        color: selectedIndex == 3 
                            ? Colors.blue.shade600 
                            : Colors.grey.shade600,
                      ),
                      selectedIcon: Icon(
                        Icons.person,
                        color: Colors.blue.shade600,
                      ),
                      label: 'Профиль',
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.star_outline,
                        color: selectedIndex == 4
                            ? Colors.blue.shade600
                            : Colors.grey.shade600,
                      ),
                      selectedIcon: Icon(
                        Icons.star,
                        color: Colors.blue.shade600,
                      ),
                      label: 'Рейтинг',
                    ),

                  ],
                ),
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
  path: '/rating',
  builder: (context, state) => const RatingScreen(),
),


          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SafeUp',
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey.shade800,
          titleTextStyle: TextStyle(
            color: Colors.grey.shade800,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

int _calculateSelectedIndex(GoRouterState state) {
  final location = state.matchedLocation;
  if (location.startsWith('/profile')) return 3;
  if (location.startsWith('/mytrainings')) return 2;
  if (location.startsWith('/create')) return 1;
  if (location.startsWith('/rating')) return 4; // новая страница
  return 0; 
}
