import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://safe-up.onrender.com');

class GenerationLoadingScreen extends StatefulWidget {
  final Map<String, dynamic> payload;
  final String token;
  const GenerationLoadingScreen({super.key, required this.payload, required this.token});

  @override
  State<GenerationLoadingScreen> createState() => _GenerationLoadingScreenState();
}

class _GenerationLoadingScreenState extends State<GenerationLoadingScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late AnimationController _progressAnimController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnim;

  http.Client? _httpClient;
  bool _cancelled = false;

  double _progress = 0;
  double _displayedProgress = 0;
  int _stepIndex = 0;
  Timer? _stepTimer;
  Timer? _progressTimer;

  final List<Map<String, dynamic>> _steps = [
    {'icon': Icons.search_rounded,       'text': 'Анализируем сценарий...',          'color': Colors.blue},
    {'icon': Icons.psychology_rounded,   'text': 'ИИ генерирует тренировку...',      'color': Colors.purple},
    {'icon': Icons.assignment_rounded,   'text': 'Формируем задания...',             'color': Colors.orange},
    {'icon': Icons.bolt_rounded,         'text': 'Добавляем детали сценария...',     'color': Colors.amber},
    {'icon': Icons.auto_awesome_rounded, 'text': 'Финальная обработка...',           'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _progressAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOut),
    );

    _startProgress();
    _startRequest();
  }

  void _animateProgressTo(double target) {
    final oldValue = _displayedProgress;
    _progressAnim = Tween<double>(begin: oldValue, end: target).animate(
      CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOut),
    );
    _progressAnimController
      ..reset()
      ..forward();
    _progressAnim.addListener(() {
      if (mounted) setState(() => _displayedProgress = _progressAnim.value);
    });
  }

  void _startProgress() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (_cancelled || !mounted) { t.cancel(); return; }
      if (_progress < 88) {
        _progress += (88 / 70);
        if (_progress > 88) _progress = 88;
        _animateProgressTo(_progress);
      }
    });

    _stepTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (_cancelled || !mounted) { t.cancel(); return; }
      setState(() {
        if (_stepIndex < _steps.length - 1) _stepIndex++;
      });
    });
  }

  Future<void> _startRequest() async {
    _httpClient = http.Client();
    try {
      final uri = Uri.parse('$apiBase/trainings');
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..body = jsonEncode(widget.payload);

      final streamedResp = await _httpClient!.send(request);
      final resp = await http.Response.fromStream(streamedResp);

      if (_cancelled || !mounted) return;

      if (resp.statusCode == 201) {
        _animateProgressTo(100);
        setState(() { _progress = 100; _stepIndex = _steps.length - 1; });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go('/mytrainings');
      } else {
        String msg = 'Ошибка ${resp.statusCode}';
        try {
          final body = jsonDecode(resp.body);
          if (body['message'] != null) msg = body['message'];
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          context.pop();
        }
      }
    } catch (e) {
      if (_cancelled || !mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      if (mounted) context.pop();
    }
  }

  void _cancel() {
    _cancelled = true;
    _httpClient?.close();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _stepTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _progressAnimController.dispose();
    _httpClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_stepIndex];
    final stepColor = step['color'] as Color;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Тренажёр ЧС'),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Hero card — стиль как на главной
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Иконка с вращающимся кольцом
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Вращающееся кольцо
                              AnimatedBuilder(
                                animation: _rotateAnimation,
                                builder: (_, __) => Transform.rotate(
                                  angle: _rotateAnimation.value,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.0),
                                        width: 0,
                                      ),
                                    ),
                                    child: CustomPaint(painter: _DashedCirclePainter()),
                                  ),
                                ),
                              ),
                              // Центральная иконка
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome,
                                    size: 38,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Генерация тренировки',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'ИИ создаёт персональный сценарий для твоей тренировки',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Карточка прогресса
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                            Icon(Icons.trending_up, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Прогресс',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_displayedProgress.toInt()}%',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: _displayedProgress / 100,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Шаги — карточки как на главной (feature cards)
                  ...List.generate(_steps.length, (i) {
                    final s = _steps[i];
                    final color = s['color'] as Color;
                    final isActive = i == _stepIndex;
                    final isDone = i < _stepIndex;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? color.withOpacity(0.07)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive ? color.withOpacity(0.4) : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isActive ? 0.06 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDone
                                  ? Colors.green.withOpacity(0.1)
                                  : color.withOpacity(isActive ? 0.12 : 0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDone ? Icons.check_rounded : s['icon'] as IconData,
                              color: isDone ? Colors.green : color.withOpacity(isActive ? 1 : 0.4),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              s['text'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                color: isActive
                                    ? Colors.black87
                                    : isDone
                                        ? Colors.black54
                                        : Colors.grey.shade400,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (isActive)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: color,
                              ),
                            ),
                          if (isDone)
                            Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 20),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Кнопка отмены
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'Отменить',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Рисует пунктирное кольцо (вращающееся)
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dashCount = 16;
    const dashAngle = (2 * pi) / dashCount;
    const gapFraction = 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter _) => false;
}