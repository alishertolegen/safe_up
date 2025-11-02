import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? nameError;
  String? emailError;
  String? passwordError;
  String? confirmError;

  static const int minPasswordLength = 8;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите имя';
    if (value.trim().length < 2) return 'Имя слишком короткое';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите email';
    final email = value.trim();
    final emailRegExp = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
      r"[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    );
    if (!emailRegExp.hasMatch(email)) return 'Некорректный email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (value.length < minPasswordLength) {
      return 'Пароль должен содержать минимум $minPasswordLength символов';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Подтвердите пароль';
    if (value != passwordController.text) return 'Пароли не совпадают';
    return null;
  }

  bool _validateAll() {
    final nErr = _validateName(nameController.text);
    final eErr = _validateEmail(emailController.text);
    final pErr = _validatePassword(passwordController.text);
    final cErr = _validateConfirm(confirmController.text);

    setState(() {
      nameError = nErr;
      emailError = eErr;
      passwordError = pErr;
      confirmError = cErr;
    });

    return nErr == null && eErr == null && pErr == null && cErr == null;
  }

Future<void> _register(
  BuildContext context,
  String name,
  String email,
  String password,
) async {
  if (!_validateAll()) return;

  setState(() => _isLoading = true);

  try {
    final url = Uri.parse("http://localhost:5000/register"); 

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": name,
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("userEmail", email);

      if (data["token"] != null) {
        await prefs.setString("token", data["token"]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Регистрация успешна!"),
            backgroundColor: Colors.green,
          ),
        );
        context.go("/home");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["message"] ?? "Ошибка регистрации"),
          backgroundColor: const Color.fromARGB(255, 177, 42, 32),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Ошибка соединения: $e"),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 35, 49),
      // appBar: AppBar(
      //   title: const Text(
      //     "Регистрация",
      //     style: TextStyle(
      //       color: Colors.white,
      //       fontSize: 20,
      //       fontWeight: FontWeight.w600,
      //     ),
      //   ),
      //   backgroundColor: Colors.indigo,
      //   elevation: 0,
      //   iconTheme: const IconThemeData(color: Colors.white),
      // ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_outlined,
                    size: 45,
                    color: Color.fromARGB(255, 255, 35, 49),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "Создать аккаунт",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Заполните данные для регистрации",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (nameError != null)
                              setState(() => nameError = null);
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: Color.fromARGB(255, 255, 35, 49),
                            ),
                            labelText: "Имя",
                            errorText: nameError,
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 255, 35, 49),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (emailError != null)
                              setState(() => emailError = null);
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Color.fromARGB(255, 255, 35, 49),
                            ),
                            labelText: "Email",
                            errorText: emailError,
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 255, 35, 49),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) {
                            if (passwordError != null)
                              setState(() => passwordError = null);
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.lock_outlined,
                              color: Color.fromARGB(255, 255, 35, 49),
                            ),
                            labelText: "Пароль",
                            errorText: passwordError,
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 255, 35, 49),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: confirmController,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (confirmError != null)
                              setState(() => confirmError = null);
                          },
                          onSubmitted: (_) {
                            _register(
                              context,
                              nameController.text,
                              emailController.text,
                              passwordController.text,
                            );
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.lock_outlined,
                              color: Color.fromARGB(255, 255, 35, 49),
                            ),
                            labelText: "Подтвердите пароль",
                            errorText: confirmError,
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color.fromARGB(255, 255, 35, 49),
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.grey[600],
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                255,
                                35,
                                49,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    _register(
                                      context,
                                      nameController.text,
                                      emailController.text,
                                      passwordController.text,
                                    );
                                  },
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "Зарегистрироваться",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Уже есть аккаунт? ",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              child: const Text(
                                "Войти",
                                style: TextStyle(
                                  color: Color.fromARGB(255, 255, 35, 49),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
