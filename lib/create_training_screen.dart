import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBase = String.fromEnvironment('API_BASE',
    defaultValue: 'http://10.0.2.2:5000');

class CreateTrainingScreen extends StatefulWidget {
  const CreateTrainingScreen({super.key});

  @override
  State<CreateTrainingScreen> createState() => _CreateTrainingScreenState();
}

class _CreateTrainingScreenState extends State<CreateTrainingScreen> {
  final _titleController = TextEditingController();
  final _otherLocationController = TextEditingController();

  String _selectedType = 'пожар';
  String _selectedLocation = 'Офис';
  String _selectedDifficulty = 'medium';
  bool _isLoading = false;

  final List<Map<String, String>> _types = [
    {'key': 'пожар', 'label': 'Пожар', 'icon': '🔥'},
    {'key': 'землетрясение', 'label': 'Землетрясение', 'icon': '🌍'},
    {'key': 'наводнение', 'label': 'Наводнение', 'icon': '🌊'},
    {'key': 'газовая_утечка', 'label': 'Газовая утечка', 'icon': '💨'},
    {'key': 'иное', 'label': 'Иное', 'icon': '⚠️'},
  ];

  final List<Map<String, String>> _locationOptions = [
    {'value': 'Офис', 'icon': '🏢'},
    {'value': 'Дом', 'icon': '🏠'},
    {'value': 'Школа', 'icon': '🏫'},
    {'value': 'Улица', 'icon': '🛣️'},
    {'value': '🎲 Случайная', 'icon': '🎲'},
    {'value': 'Другое', 'icon': '📍'},
  ];

  final Map<String, Map<String, dynamic>> _difficultyData = {
    'easy': {'label': 'Лёгкий', 'color': Colors.green, 'icon': '😊'},
    'medium': {'label': 'Средний', 'color': Colors.orange, 'icon': '😐'},
    'hard': {'label': 'Сложный', 'color': Colors.red, 'icon': '😰'}
  };

  @override
  void dispose() {
    _titleController.dispose();
    _otherLocationController.dispose();
    super.dispose();
  }
Map<String, dynamic> _buildPayload() {
  final String? titleInput = _titleController.text.trim().isEmpty
      ? null
      : _titleController.text.trim();

  final Map<String, dynamic> payload = {};
  payload['aiGenerate'] = true;

  if (titleInput != null) payload['title'] = titleInput;
  if (_selectedType.isNotEmpty) payload['type'] = _selectedType;
  payload['difficulty'] = _selectedDifficulty;

  if (_selectedLocation == '🎲 Случайная') {
    // omit location
  } else if (_selectedLocation == 'Другое') {
    final other = _otherLocationController.text.trim();
    if (other.isNotEmpty) {
      payload['location'] = {'name': other};
    }
  } else {
    payload['location'] = {'name': _selectedLocation};
  }

  return payload;
}
Future<void> _createTraining() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null || token.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Требуется авторизация. Войдите в аккаунт.')));
    return;
  }

  final payload = _buildPayload();

  if (!mounted) return;
  context.push('/generating', extra: {'payload': payload, 'token': token});
}

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _types.map((t) {
        final key = t['key']!;
        final label = t['label']!;
        final icon = t['icon']!;
        final selected = key == _selectedType;
        
        return InkWell(
          onTap: () => setState(() => _selectedType = key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.blue.shade900 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _locationOptions.map((loc) {
            final value = loc['value']!;
            final icon = loc['icon']!;
            final selected = value == _selectedLocation;
            
            return InkWell(
              onTap: () => setState(() => _selectedLocation = value),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Colors.blue.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Colors.blue.shade900 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedLocation == 'Другое') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otherLocationController,
            decoration: InputDecoration(
              labelText: 'Введите локацию',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          )
        ]
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Row(
      children: _difficultyData.keys.map((k) {
        final data = _difficultyData[k]!;
        final label = data['label'] as String;
        final color = data['color'] as Color;
        final icon = data['icon'] as String;
        final selected = _selectedDifficulty == k;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => setState(() => _selectedDifficulty = k),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? color : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Создать тренировку'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Название (опционально)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Например: Пожар в офисе QazTech',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Type card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Тип чрезвычайной ситуации',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTypeSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Location card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Локация',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLocationSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Difficulty card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fitness_center_outlined, color: Colors.purple, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Сложность',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDifficultySelector(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Create button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createTraining,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Создать тренировку',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Hint
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Можно отправить только тип и/или локацию — ИИ сам сгенерирует остальное',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}