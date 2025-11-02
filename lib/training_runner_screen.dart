// lib/screens/training_runner_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training.dart';

const String API_BASE = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:5000');

class TrainingRunnerScreen extends StatefulWidget {
  final Training training;
  const TrainingRunnerScreen({required this.training, super.key});

  @override
  State<TrainingRunnerScreen> createState() => _TrainingRunnerScreenState();
}

class _TrainingRunnerScreenState extends State<TrainingRunnerScreen> {
  int _currentIndex = 0;

  // sceneId -> выбранный choiceId
  final Map<int, String> _answers = {};

  // sceneId -> результат (selectedId, isCorrect, consequenceText, correctChoiceId)
  final Map<int, _AnswerResult> _results = {};

  late Timer _timer;
  int _elapsedSec = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _elapsedSec++;
      });
    });
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Мгновенная обработка выбора — отвечает сразу же
  void _handleTapChoice(int sceneId, String choiceId) {
    // если уже отвечали на эту сцену — не позволяем менять ответ
    if (_results.containsKey(sceneId)) return;

    final scene = widget.training.scenes.firstWhere((s) => s.id == sceneId);
    final selected = scene.choices.firstWhere((c) => c.id == choiceId);
    final correct = scene.choices.firstWhere((c) => c.consequenceType == 'correct', orElse: () => scene.choices.first);

    final isCorrect = selected.consequenceType == 'correct';

    // сохраняем выбор и результат
    setState(() {
      _answers[sceneId] = choiceId;
      _results[sceneId] = _AnswerResult(
        selectedId: choiceId,
        isCorrect: isCorrect,
        consequenceText: selected.consequenceText ?? '',
        correctChoiceId: correct.id,
        correctChoiceText: correct.text,
      );
    });

    // показываем небольшой SnackBar с результатом (опционально)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCorrect ? 'Правильно' : 'Неправильно — показан правильный ответ'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _goNext() {
    final max = widget.training.scenes.length - 1;
    setState(() {
      if (_currentIndex < max) _currentIndex++;
    });
  }

  void _goPrev() {
    setState(() {
      if (_currentIndex > 0) _currentIndex--;
    });
  }

  bool get _allAnswered {
    for (var s in widget.training.scenes) {
      if (!_results.containsKey(s.id)) return false;
    }
    return true;
  }

  Future<void> _submitAttempt() async {
    if (_submitting) return;
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      _showMessage('Требуется авторизация. Войдите в аккаунт.');
      return;
    }

    setState(() => _submitting = true);

    // Собираем payload: если пользователь не выбрал вариант — используем defaultChoiceId
    final choicesPayload = widget.training.scenes.map((s) {
      final chosen = _answers[s.id] ?? s.defaultChoiceId;
      return {'sceneId': s.id, 'choiceId': chosen};
    }).toList();

    final body = jsonEncode({'choices': choicesPayload, 'timeSec': _elapsedSec});

    try {
      final uri = Uri.parse('$API_BASE/trainings/${widget.training.id}/attempt');
      final res = await http.post(uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body);

      if (res.statusCode == 401) {
        _showMessage('Неавторизован. Пожалуйста, войдите снова.');
        setState(() => _submitting = false);
        return;
      }
      if (res.statusCode != 200) {
        _showMessage('Ошибка сервера: ${res.statusCode}');
        setState(() => _submitting = false);
        return;
      }

      final Map<String, dynamic> data = json.decode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;

      // Остановим таймер — попытка завершена
      _timer.cancel();

      // Обновлённые статистики (если бэк вернул)
      final updatedStats = data['updatedStats'] as Map<String, dynamic>?;

      _showResultDialog(result, updatedStats);
    } catch (err) {
      _showMessage('Ошибка сети: $err');
      setState(() => _submitting = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showResultDialog(Map<String, dynamic>? result, Map<String, dynamic>? updatedStats) {
    final totalScore = result?['totalScore']?.toString() ?? '-';
    final correctAnswers = result?['correctAnswers']?.toString() ?? '-';
    final totalChoices = result?['totalChoices']?.toString() ?? '-';
    final success = result?['success'] == true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(success ? 'Успешно!' : 'Результат попытки'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Очки: $totalScore'),
                Text('Правильных: $correctAnswers / $totalChoices'),
                const SizedBox(height: 8),
                if (result?['details'] is List)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: (result!['details'] as List).map<Widget>((d) {
                      final sceneId = d['sceneId']?.toString() ?? '?';
                      final choiceId = d['choiceId']?.toString() ?? '-';
                      final cons = d['consequenceType']?.toString() ?? '-';
                      // scoreDelta не показываем
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('Сцена $sceneId — выбор $choiceId — $cons'),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                if (updatedStats != null) ...[
                  const Divider(),
                  const Text('Обновлённые статистики:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Попыток: ${updatedStats['attempts'] ?? '-'}'),
                  Text('Успехов: ${updatedStats['successes'] ?? '-'}'),
                  Text('Avg sec: ${updatedStats['avgTimeSec'] ?? '-'}'),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // закроет Runner screen
              },
              child: const Text('Закрыть'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // если захотим пройти ещё раз — сбросим
                setState(() {
                  _answers.clear();
                  _results.clear();
                  _elapsedSec = 0;
                  _startTimer();
                  _submitting = false;
                });
              },
              child: const Text('Пройти ещё раз'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scenes = widget.training.scenes;
    final scene = scenes[_currentIndex];
    final answeredCount = _results.length;
    final total = scenes.length;

    String formatTime(int sec) {
      final m = sec ~/ 60;
      final s = sec % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.training.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Text('Прогресс: $answeredCount / $total'),
                const Spacer(),
                Text('Время: ${formatTime(_elapsedSec)}'),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // сцена заголовок и описание
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Сцена ${scene.id}: ${scene.title}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(scene.description),
                    if (scene.hint.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Подсказка: ${scene.hint}', style: const TextStyle(fontStyle: FontStyle.italic)),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // варианты — теперь тап отвечает сразу
            Expanded(
              child: ListView.builder(
                itemCount: scene.choices.length,
                itemBuilder: (ctx, i) {
                  final c = scene.choices[i];

                  // текущий результат этой сцены (если уже отвечали)
                  final res = _results[scene.id];

                  // определяем визуальные состояния
                  bool isSelected = _answers[scene.id] == c.id;
                  bool isCorrectChoice = c.consequenceType == 'correct';
                  Color? tileColor;
                  Widget? leading;

                  if (res == null) {
                    // ещё не отвечали — обычный вид с радиомаркером
                    leading = Radio<String>(
                      value: c.id,
                      groupValue: _answers[scene.id],
                      onChanged: (v) {
                        if (v != null) _handleTapChoice(scene.id, v);
                      },
                    );
                    tileColor = null;
                  } else {
                    // уже отвечали — показываем результат:
                    if (isSelected && res.isCorrect) {
                      // выбран и правильный
                      leading = const Icon(Icons.check_circle, color: Colors.green);
                      tileColor = Colors.green.withOpacity(0.12);
                    } else if (isSelected && !res.isCorrect) {
                      // выбран и неверный
                      leading = const Icon(Icons.cancel, color: Colors.red);
                      tileColor = Colors.red.withOpacity(0.08);
                    } else if (isCorrectChoice) {
                      // не выбранный, но правильный — подчеркнём
                      leading = const Icon(Icons.check_circle_outline, color: Colors.green);
                      tileColor = Colors.green.withOpacity(0.06);
                    } else {
                      leading = const SizedBox(width: 24); // пустое место
                      tileColor = null;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: tileColor,
                      onTap: () => _handleTapChoice(scene.id, c.id),
                      leading: leading,
                      title: Text(c.text),
                      // не показываем consequenceText в самом tile до выбора
                      // удаляем показ scoreDelta (secondary)
                    ),
                  );
                },
              ),
            ),

            // После вариантов показываем consequenceText выбранного варианта (если есть),
            // и при неверном ответе — показываем правильный вариант и его текст.
            const SizedBox(height: 8),
            if (_results.containsKey(scene.id)) ...[
              Card(
                color: _results[scene.id]!.isCorrect ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.04),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // consequenceText выбранного варианта
                      if (_results[scene.id]!.consequenceText.isNotEmpty) ...[
                        Text(
                          _results[scene.id]!.consequenceText,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!_results[scene.id]!.isCorrect) ...[
                        const Divider(),
                        Text('Правильный ответ: ${_results[scene.id]!.correctChoiceId} — ${_results[scene.id]!.correctChoiceText}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // навигация и submit
            Row(
              children: [
                OutlinedButton(
                  onPressed: _currentIndex > 0 ? _goPrev : null,
                  child: const Text('Назад'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _currentIndex < total - 1 ? _goNext : null,
                    child: Text(_currentIndex < total - 1 ? 'Далее' : 'Последняя сцена'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitting ? null : _submitAttempt,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Отправить'),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _AnswerResult {
  final String selectedId;
  final bool isCorrect;
  final String consequenceText;
  final String correctChoiceId;
  final String correctChoiceText;

  const _AnswerResult({
    required this.selectedId,
    required this.isCorrect,
    required this.consequenceText,
    required this.correctChoiceId,
    required this.correctChoiceText,
  });
}
