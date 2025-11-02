import 'package:flutter/material.dart';
import '../models/training.dart';
class TrainingDetailScreen extends StatelessWidget {
  final Training training;
  const TrainingDetailScreen({required this.training, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(training.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text('${training.type} — ${training.location}'),
                subtitle: Text('Сложность: ${training.difficulty}'),
                trailing: Text('${training.lastScorePercent.toStringAsFixed(0)}%'),
              ),
            ),
            const SizedBox(height: 12),
            const Text('История прохождений', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Прохождение 01.10.2025'),
                    subtitle: Text('Результат: 78% — улучшить время эвакуации'),
                  ),
                  ListTile(
                    leading: Icon(Icons.error_outline),
                    title: Text('Прохождение 25.09.2025'),
                    subtitle: Text('Результат: 45% — ошибка: использован лифт'),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Запуск тренировки "${training.title}" (статично)')),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Text('Начать тренировку'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
