// lib/screens/training_runner_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training.dart';

const String API_BASE = String.fromEnvironment('API_BASE', defaultValue: 'https://safe-up.onrender.com');

class TrainingRunnerScreen extends StatefulWidget {
  final Training training;
  const TrainingRunnerScreen({required this.training, super.key});

  @override
  State<TrainingRunnerScreen> createState() => _TrainingRunnerScreenState();
}

class _TrainingRunnerScreenState extends State<TrainingRunnerScreen> {
  int _currentIndex = 0;
  final Map<int, String> _answers = {};
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

  void _handleTapChoice(int sceneId, String choiceId) {
    if (_results.containsKey(sceneId)) return;

    final scene = widget.training.scenes.firstWhere((s) => s.id == sceneId);
    final selected = scene.choices.firstWhere((c) => c.id == choiceId);
    final correct = scene.choices.firstWhere((c) => c.consequenceType == 'correct', orElse: () => scene.choices.first);

    final isCorrect = selected.consequenceType == 'correct';

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isCorrect ? Icons.check_circle : Icons.cancel,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(isCorrect ? 'Правильно!' : 'Неправильно'),
          ],
        ),
        backgroundColor: isCorrect ? Colors.green : Colors.red,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      _timer.cancel();

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: success ? Colors.green.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.emoji_events : Icons.info_outline,
                  color: success ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Text(success ? 'Успешно!' : 'Результат'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ResultStat(
                            icon: Icons.stars,
                            label: 'Очки',
                            value: totalScore,
                            color: Colors.blue,
                          ),
                          _ResultStat(
                            icon: Icons.check_circle,
                            label: 'Верно',
                            value: '$correctAnswers/$totalChoices',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (updatedStats != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Общая статистика',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatsRow(
                    icon: Icons.replay,
                    label: 'Попыток',
                    value: updatedStats['attempts']?.toString() ?? '-',
                  ),
                  _StatsRow(
                    icon: Icons.emoji_events,
                    label: 'Успехов',
                    value: updatedStats['successes']?.toString() ?? '-',
                  ),
                  _StatsRow(
                    icon: Icons.timer,
                    label: 'Среднее время',
                    value: '${updatedStats['avgTimeSec'] ?? '-'}с',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
                context.go('/profile');
              },
              child: const Text('Закрыть'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _answers.clear();
                  _results.clear();
                  _elapsedSec = 0;
                  _currentIndex = 0;
                  _startTimer();
                  _submitting = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Пройти ещё раз'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scenes = widget.training.scenes;
    final scene = scenes[_currentIndex];
    final answeredCount = _results.length;
    final total = scenes.length;
    final progress = answeredCount / total;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.training.title),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.article, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Text(
                                '$answeredCount / $total',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(_elapsedSec),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scene card
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
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${scene.id}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                scene.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          scene.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                        if (scene.hint.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb, size: 18, color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    scene.hint,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.amber.shade900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Choices
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scene.choices.length,
                    itemBuilder: (ctx, i) {
                      final c = scene.choices[i];
                      final res = _results[scene.id];
                      bool isSelected = _answers[scene.id] == c.id;
                      bool isCorrectChoice = c.consequenceType == 'correct';
                      
                      Color? bgColor;
                      Color? borderColor;
                      Widget? leading;

                      if (res == null) {
                        bgColor = Colors.white;
                        borderColor = isSelected ? Colors.blue : Colors.grey.shade300;
                        leading = Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected ? Colors.blue : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        );
                      } else {
                        if (isSelected && res.isCorrect) {
                          bgColor = Colors.green.shade50;
                          borderColor = Colors.green;
                          leading = const Icon(Icons.check_circle, color: Colors.green, size: 24);
                        } else if (isSelected && !res.isCorrect) {
                          bgColor = Colors.red.shade50;
                          borderColor = Colors.red;
                          leading = const Icon(Icons.cancel, color: Colors.red, size: 24);
                        } else if (isCorrectChoice) {
                          bgColor = Colors.green.shade50;
                          borderColor = Colors.green.shade300;
                          leading = const Icon(Icons.check_circle_outline, color: Colors.green, size: 24);
                        } else {
                          bgColor = Colors.white;
                          borderColor = Colors.grey.shade300;
                          leading = const SizedBox(width: 24);
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor!, width: 2),
                          boxShadow: [
                            if (res == null)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () => _handleTapChoice(scene.id, c.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                leading!,
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.text,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Result feedback
                  if (_results.containsKey(scene.id)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _results[scene.id]!.isCorrect
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _results[scene.id]!.isCorrect
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_results[scene.id]!.consequenceText.isNotEmpty) ...[
                            Text(
                              _results[scene.id]!.consequenceText,
                              style: TextStyle(
                                fontSize: 14,
                                color: _results[scene.id]!.isCorrect
                                    ? Colors.green.shade900
                                    : Colors.red.shade900,
                              ),
                            ),
                          ],
                          if (!_results[scene.id]!.isCorrect) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.info_outline, size: 18, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                const Text(
                                  'Правильный ответ:',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _results[scene.id]!.correctChoiceText,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentIndex > 0 ? _goPrev : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _currentIndex < total - 1 ? _goNext : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: Text(
                        _currentIndex < total - 1 ? 'Далее' : 'Последняя',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitAttempt,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
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

class _ResultStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ResultStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}