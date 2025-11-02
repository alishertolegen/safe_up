import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;
  String? emailError;

  @override
  void initState() {
    super.initState();
    // optionally receive email from LoginScreen
    final extra = GoRouter.of(context).routerDelegate.currentConfiguration.fullPath; // fallback
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите email';
    final email = value.trim();
    final emailRegExp = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
      r"[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    );
    if (!emailRegExp.hasMatch(email)) return 'Некорректный email';
    return null;
  }

  bool _validate() {
    final err = _emailValidator(emailController.text);
    setState(() => emailError = err);
    return err == null;
  }

  Future<void> _sendCode() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('http://localhost:5000/forgot-password');
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': emailController.text.trim()}));

      final body = jsonDecode(resp.body);

      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Код отправлен (проверьте почту или логи сервера).'),
              backgroundColor: Colors.green,
            ),
          );
          // Перейти на экран сброса пароля и передать email
          context.push('/reset-password', extra: {'email': emailController.text.trim()});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message'] ?? 'Ошибка отправки кода'),
              backgroundColor: const Color.fromARGB(255, 177, 42, 32),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка соединения: $e'),
            backgroundColor: const Color.fromARGB(255, 177, 42, 32),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // try to read optional email passed from previous page
    final extra = (ModalRoute.of(context)?.settings.arguments ?? (GoRouter.of(context).routerDelegate.currentConfiguration.toString())) ;
    // But better to read via context.push extra param if you use go_router routes config.
    // We'll accept manual typing too.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сброс пароля'),
        backgroundColor: const Color.fromARGB(255, 255, 35, 49),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  'Введите email. Мы отправим код для сброса пароля.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: emailError,
                    prefixIcon: const Icon(Icons.email_outlined, color: Color.fromARGB(255, 255, 35, 49)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 255, 35, 49),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _sendCode,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Получить код'),
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
