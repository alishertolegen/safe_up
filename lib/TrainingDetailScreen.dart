// lib/screens/training_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/training.dart';
import 'training_runner_screen.dart';

class TrainingDetailScreen extends StatelessWidget {
  final Training training;
  const TrainingDetailScreen({required this.training, super.key});

  Widget _badge(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Icon _iconForConsequence(String type) {
    switch (type) {
      case 'correct':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'warning':
        return const Icon(Icons.warning_amber_rounded, color: Colors.orange);
      case 'fatal':
        return const Icon(Icons.cancel, color: Colors.red);
      default:
        return const Icon(Icons.help_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = training.createdAt.toLocal().toString().split(' ').first;
    final updatedAt = training.updatedAt.toLocal().toString().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(training.title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(child: _badge(training.difficulty.toUpperCase())),
          ),
          if (training.aiGenerated)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(child: _badge('AI', color: Colors.purple.shade100)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text('${training.type} · ${training.location.name.isNotEmpty ? training.location.name : "Локация не указана"}'),
                subtitle: Text(training.summary.isNotEmpty ? training.summary : 'Описание отсутствует'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${training.lastScorePercent.toStringAsFixed(0)}%'),
                    const SizedBox(height: 4),
                    Text('Попыток: ${training.stats.attempts}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // meta row
            Row(
              children: [
                Expanded(child: Text('Этаж/зона: ${training.location.floor} ${training.location.extra.isNotEmpty ? "· ${training.location.extra}" : ""}')),
                const SizedBox(width: 8),
                if (training.createdBy != null)
                  Expanded(child: Text('Создал: ${training.createdBy!.username ?? training.createdBy!.id}')),
              ],
            ),
            const SizedBox(height: 10),
            // stats summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatColumn(label: 'Успехи', value: training.stats.successes.toString()),
                    _StatColumn(label: 'Попытки', value: training.stats.attempts.toString()),
                    _StatColumn(label: 'Avg sec', value: training.stats.avgTimeSec.toString()),
                    _StatColumn(label: 'Choices', value: training.summaryMetrics.totalChoices.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // scenes header
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Сцены', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            // scenes list — показываем только когда успехи >= 1
            training.stats.successes >= 1
                ? Expanded(
                    child: ListView.builder(
                      itemCount: training.scenes.length,
                      itemBuilder: (ctx, idx) {
                        final s = training.scenes[idx];
                        return Card(
                          child: ExpansionTile(
                            key: PageStorageKey('scene_${s.id}'),
                            title: Text('${s.id}. ${s.title}'),
                            subtitle: Text(s.hint),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
                                child: Text(s.description),
                              ),
                              const Divider(),
                              ...s.choices.map((c) {
                                return ListTile(
                                  leading: _iconForConsequence(c.consequenceType),
                                  title: Text(c.text),
                                  subtitle: c.consequenceText.isNotEmpty ? Text(c.consequenceText) : null,
                                  trailing: Text('${c.scoreDelta >= 0 ? '+' : ''}${c.scoreDelta}'),
                                );
                              }).toList(),
                              const SizedBox(height: 6)
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : Expanded(
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Сцены будут видны после того, как Успехи станут 1 или больше.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 8),
            // footer buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => TrainingRunnerScreen(training: training)),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Начать тренировку'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    // короткая информация / raw json
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Информация'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${training.id}'),
                              Text('Создан: $createdAt'),
                              Text('Обновлён: $updatedAt'),
                              Text('Опубликован: ${training.isPublished ? "Да" : "Нет"}'),
                              if (training.aiMeta != null) ...[
                                const SizedBox(height: 6),
                                Text('AI model: ${training.aiMeta!.model ?? "—"}'),
                                Text('AI seed: ${training.aiMeta!.promptSeed ?? "—"}'),
                              ]
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Закрыть')),
                        ],
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Инфо'),
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

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value, super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}
