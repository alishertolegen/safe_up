// lib/screens/create_training_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Задавай API_BASE через --dart-define=API_BASE or оставь дефолт
const String apiBase = String.fromEnvironment('API_BASE',
    defaultValue: 'http://localhost:5000');

class CreateTrainingScreen extends StatefulWidget {
  const CreateTrainingScreen({super.key});

  @override
  State<CreateTrainingScreen> createState() => _CreateTrainingScreenState();
}

class _CreateTrainingScreenState extends State<CreateTrainingScreen> {
  final _titleController = TextEditingController();
  final _otherLocationController = TextEditingController();

  // UI state
  String _selectedType = 'пожар';
  String _selectedLocation = 'Офис'; // values: predefined names + "🎲 Случайная" + "Другое"
  String _selectedDifficulty = 'medium'; // easy | medium | hard
  bool _isLoading = false;

  // preset lists
  final List<Map<String, String>> _types = [
    {'key': 'пожар', 'label': 'Пожар'},
    {'key': 'землетрясение', 'label': 'Землетрясение'},
    {'key': 'наводнение', 'label': 'Наводнение'},
    {'key': 'газовая_утечка', 'label': 'Газовая утечка'},
    {'key': 'иное', 'label': 'Иное'},
  ];

  final List<String> _locationOptions = [
    'Офис',
    'Дом',
    'Школа',
    'Улица',
    '🎲 Случайная',
    'Другое'
  ];

  // difficulty mapping for display
  final Map<String, String> _difficultyLabels = {
    'easy': 'Лёгкий',
    'medium': 'Средний',
    'hard': 'Сложный'
  };

  @override
  void dispose() {
    _titleController.dispose();
    _otherLocationController.dispose();
    super.dispose();
  }

  Future<void> _createTraining() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Требуется авторизация. Войдите в аккаунт.')));
        setState(() => _isLoading = false);
        return;
      }

      // Build payload
      final String? titleInput = _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim();

      final Map<String, dynamic> payload = {};

      // Always ask AI to generate content (allows sending only type/location/difficulty)
      payload['aiGenerate'] = true;

      // include title if user provided it
      if (titleInput != null) payload['title'] = titleInput;

      // type (use backend-friendly lowercase key)
      if (_selectedType.isNotEmpty) payload['type'] = _selectedType;

      // difficulty (already stored as backend value)
      payload['difficulty'] = _selectedDifficulty;

      // location logic:
      // - if user selected 🎲 Случайная -> omit location so backend will invent one
      // - if user selected 'Другое' -> use text from _otherLocationController if provided
      // - otherwise include selected location name
      if (_selectedLocation == '🎲 Случайная') {
        // omit location entirely
      } else if (_selectedLocation == 'Другое') {
        final other = _otherLocationController.text.trim();
        if (other.isNotEmpty) {
          payload['location'] = { 'name': other };
        }
      } else {
        payload['location'] = { 'name': _selectedLocation };
      }

      // optional: let user tune scenes count in the future; for now we rely on server DEFAULT_SCENES

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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Тренировка успешно сгенерирована')));
        // navigate to MyTrainings
        if (mounted) context.go('/mytrainings');
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неавторизован. Пожалуйста, войдите.')));
      } else {
        // try parse body message
        String msg = 'Сервер вернул ${resp.statusCode}.';
        try {
          final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : null;
          if (body != null && body['message'] != null) msg = body['message'];
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $msg')));
      }
    } catch (e, st) {
      // debug print
      // ignore: avoid_print
      print('Create training error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка при создании тренировки: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _types.map((t) {
        final key = t['key']!;
        final label = t['label']!;
        final selected = key == _selectedType;
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _selectedType = key),
          selectedColor: Colors.blue.shade700,
        );
      }).toList(),
    );
  }

  Widget _buildLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _locationOptions.map((loc) {
            final selected = loc == _selectedLocation;
            return ChoiceChip(
              label: Text(loc),
              selected: selected,
              onSelected: (_) => setState(() => _selectedLocation = loc),
            );
          }).toList(),
        ),
        if (_selectedLocation == 'Другое') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _otherLocationController,
            decoration: const InputDecoration(
              labelText: 'Введите локацию',
              border: OutlineInputBorder(),
            ),
          )
        ]
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _difficultyLabels.keys.map((k) {
        final label = _difficultyLabels[k]!;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: _selectedDifficulty == k ? Colors.white : Colors.black87,
                backgroundColor: _selectedDifficulty == k ? Colors.blue : Colors.grey.shade200,
                elevation: 0,
              ),
              onPressed: () => setState(() => _selectedDifficulty = k),
              child: Text(label),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Создать тренировку'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Название (опционально)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Например: Пожар в офисе QazTech',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Тип чрезвычайной ситуации', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildTypeSelector(),

              const SizedBox(height: 16),
              const Text('Локация', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildLocationSelector(),

              const SizedBox(height: 16),
              const Text('Сложность', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildDifficultySelector(),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTraining,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Создать тренировку', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Подсказка: можно отправить только тип и/или локацию — ИИ сам сгенерирует остальное.', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
