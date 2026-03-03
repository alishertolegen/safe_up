import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
class ConfirmEmailScreen extends StatefulWidget {
  final String email;
  const ConfirmEmailScreen({super.key, required this.email});

  @override
 State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final TextEditingController codeController = TextEditingController();
  bool _loading = false;

  Future<void> confirmCode() async {
    setState(() => _loading = true);

    try {
      final res = await http.post(
        Uri.parse("http://10.0.2.2:5000/confirm-email"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "code": codeController.text,
        }),
      );

      final data = jsonDecode(res.body);

if (res.statusCode == 200) {
  final prefs = await SharedPreferences.getInstance();

  if (data["token"] != null) {
    await prefs.setString("token", data["token"]);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Email подтвержден ✅")),
  );

  context.go("/home");
} else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Ошибка")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e")),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> resendCode() async {
    await http.post(
      Uri.parse("http://10.0.2.2:5000/resend-confirm"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": widget.email}),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Код отправлен повторно 📩")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Подтверждение email")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Код отправлен на ${widget.email}"),

            const SizedBox(height: 20),

            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Введите код",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _loading ? null : confirmCode,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Подтвердить"),
            ),

            TextButton(
              onPressed: resendCode,
              child: const Text("Отправить код снова"),
            )
          ],
        ),
      ),
    );
  }
}