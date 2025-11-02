import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail; // <- новый параметр

  const ResetPasswordScreen({super.key, this.initialEmail});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController confirmPassController = TextEditingController();

  bool _isLoading = false;
  String? emailError;
  String? codeError;
  String? newPassError;

  @override
  void initState() {
    super.initState();
    // Подставляем email, если он был передан через state.extra
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Введите email';
    final email = value.trim();
    final emailRegExp = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (!emailRegExp.hasMatch(email)) return 'Некорректный email';
    return null;
  }

  bool _validateAll() {
    final eErr = _emailValidator(emailController.text);
    final c = codeController.text.trim();
    final n = newPassController.text;
    final conf = confirmPassController.text;

    String? nErr;
    if (n.isEmpty) nErr = 'Введите новый пароль';
    else if (n.length < 8) nErr = 'Пароль должен содержать минимум 8 символов';
    else if (n != conf) nErr = 'Пароли не совпадают';

    setState(() {
      emailError = eErr;
      codeError = c.isEmpty ? 'Введите код' : null;
      newPassError = nErr;
    });

    return eErr == null && codeError == null && newPassError == null;
  }

  Future<void> _reset() async {
    if (!_validateAll()) return;
    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('http://localhost:5000/reset-password');
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': emailController.text.trim(),
            'code': codeController.text.trim(),
            'newPassword': newPassController.text,
          }));
      final body = jsonDecode(resp.body);
      if (resp.statusCode == 200) {
        // optionally save token
        if (body['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', body['token']);
          await prefs.setString('userEmail', emailController.text.trim());
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Пароль успешно изменён'), backgroundColor: Colors.green),
          );
          context.go('/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['message'] ?? 'Ошибка при сбросе пароля'), backgroundColor: const Color.fromARGB(255, 177, 42, 32)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка соединения: $e'), backgroundColor: const Color.fromARGB(255, 177, 42, 32)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сброс пароля — код'),
        backgroundColor: const Color.fromARGB(255, 255, 35, 49),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: emailController,
                readOnly: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email', errorText: emailError),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Код из письма', errorText: codeError),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Новый пароль', errorText: newPassError),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Повторите пароль'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 255, 35, 49)),
                  onPressed: _isLoading ? null : _reset,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Сменить пароль'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
