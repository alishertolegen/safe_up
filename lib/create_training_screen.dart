// lib/screens/create_training_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CreateTrainingScreen extends StatefulWidget {
  const CreateTrainingScreen({super.key});

  @override
  State<CreateTrainingScreen> createState() => _CreateTrainingScreenState();
}

class _CreateTrainingScreenState extends State<CreateTrainingScreen> {
  final _titleController = TextEditingController();
  String _type = 'Пожар';
  String _location = 'Офис';
  String _difficulty = 'Новичок';
  bool _isLoading = false;

  // TODO: поменяй на реальный адрес твоего сервера
  static String apiBase = String.fromEnvironment('API_BASE',
    defaultValue:
        'http://localhost:5000'); // для Android эмулятора. Для iOS/реального девайса укажи http://localhost:5000 или IP.


  String _mapDifficulty(String d) {
    switch (d) {
      case 'Новичок':
        return 'easy';
      case 'Средний':
        return 'medium';
      case 'Профи':
        return 'hard';
      default:
        return 'medium';
    }
  }

  Future<void> _onSave() async {
    // создаём локальный title если не указан
    final title = _titleController.text.trim().isEmpty
        ? 'Тренировка — ${_type.toLowerCase()} ($_location)'
        : _titleController.text.trim();

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); // ключ токена в SharedPreferences

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Требуется авторизация. Войдите в аккаунт.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Минимальный валидный payload: title + хотя бы одна сцена
      final payload = {
        'title': title,
        'summary': 'Тренировка: $_type, локация: $_location',
        'type': _type.toLowerCase(), // на бэке хранят произвольную строку типа
        'location': {
          'name': _location,
          'floor': '',
          'extra': ''
        },
        'difficulty': _mapDifficulty(_difficulty),
        'aiGenerated': false,
        // Одна базовая сцена чтобы пройти валидацию на бэке
        'scenes': [
          {
            'id': 1,
            'title': 'Стартовая сцена',
            'description': 'Автоматически созданная стартовая сцена — отредактируй позже',
            'hint': '',
            'choices': [
              {
                'id': 'a',
                'text': 'Правильное действие (пример)',
                'consequenceType': 'correct',
                'consequenceText': 'Вы действовали правильно',
                'scoreDelta': 10
              },
              {
                'id': 'b',
                'text': 'Неправильное действие (пример)',
                'consequenceType': 'warning',
                'consequenceText': 'Это было неверно',
                'scoreDelta': 0
              }
            ],
            'defaultChoiceId': 'a'
          }
        ],
        'durationEstimateSec': 120,
        'tags': [_type.toLowerCase(), _location.toLowerCase()],
        'isPublished': false
      };

      final uri = Uri.parse('$apiBase/trainings');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 201) {
        // можно распарсить тело если нужно
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Тренировка "$title" создана.')),
        );
        if (!mounted) return;
        context.go('/mytrainings');
      } else if (resp.statusCode == 400) {
        // Пробуем получить сообщение ошибки от сервера
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
        final msg = body != null && body['message'] != null
            ? body['message']
            : 'Некорректные данные.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $msg')),
        );
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неавторизован. Пожалуйста, войдите.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сервер вернул ${resp.statusCode}: ${resp.body}')),
        );
      }
    } catch (e, st) {
      // debug
      // ignore: avoid_print
      print('Create training error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при создании тренировки: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Создать тренировку',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название (опционально)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'Пожар', child: Text('Пожар')),
                      DropdownMenuItem(value: 'Землетрясение', child: Text('Землетрясение')),
                      DropdownMenuItem(value: 'Наводнение', child: Text('Наводнение')),
                      DropdownMenuItem(value: 'Иное', child: Text('Иное')),
                    ],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                    decoration: const InputDecoration(labelText: 'Тип ЧС'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _location,
                    items: const [
                      DropdownMenuItem(value: 'Офис', child: Text('Офис')),
                      DropdownMenuItem(value: 'Дом', child: Text('Дом')),
                      DropdownMenuItem(value: 'Школа', child: Text('Школа')),
                      DropdownMenuItem(value: 'Улица', child: Text('Улица')),
                    ],
                    onChanged: (v) => setState(() => _location = v ?? _location),
                    decoration: const InputDecoration(labelText: 'Локация'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _difficulty,
              items: const [
                DropdownMenuItem(value: 'Новичок', child: Text('Новичок')),
                DropdownMenuItem(value: 'Средний', child: Text('Средний')),
                DropdownMenuItem(value: 'Профи', child: Text('Профи')),
              ],
              onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              decoration: const InputDecoration(labelText: 'Сложность'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onSave,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Создать'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
