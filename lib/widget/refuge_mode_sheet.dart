import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../apis/apis.dart';

class RefugeModeSheet extends StatefulWidget {
  const RefugeModeSheet({super.key});

  @override
  State<RefugeModeSheet> createState() => _RefugeModeSheetState();
}

class _RefugeModeSheetState extends State<RefugeModeSheet>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _completeSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  // Áudio
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Imagem
  String? _imageBase64;
  bool _loadingImage = true;

  // Respiração
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  bool _inhale = true;

  static const _sons = [
    'sounds/chuva.mp3',
    'sounds/floresta.mp3',
    'sounds/ondas.mp3',
    'sounds/vento.mp3',
  ];

  static const _prompts = [
    'sacred geometric mandala glowing teal gold cosmic dark background',
    'lotus mandala bioluminescent blue purple sacred geometry dark',
    'fractal mandala golden light cosmic energy dark background',
    'celestial mandala emerald jade light meditation dark background',
  ];

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _breathAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    _iniciar();
  }

  Future<void> _iniciar() async {
    final idx = DateTime.now().millisecond % _sons.length;

    // Gera imagem e toca áudio em paralelo
    await Future.wait([
      _gerarImagem(idx),
      _tocarAudio(idx),
    ]);
  }

  Future<void> _gerarImagem(int idx) async {
    final prompt = _prompts[idx];
    try {
      final base64 = await APIs.generateImage(prompt);
      if (mounted) {
        setState(() {
          _imageBase64 = base64.isNotEmpty ? base64 : null;
          _loadingImage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  Future<void> _tocarAudio(int idx) async {
    final asset = _sons[idx];
    try {
      await _player.play(AssetSource(asset));
      if (mounted) setState(() => _isPlaying = true);

      _durationSub = _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
        // Calibra respiração com a duração real do áudio
        _calibrarRespiracao(d);
      });

      _positionSub = _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _completeSub = _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
        _breathCtrl.stop();
      });
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _calibrarRespiracao(Duration audioDuration) {
    // Ciclo: 4s inspirar + 6s expirar = 10s por ciclo
    // Sincroniza com o BPM aproximado do som ambiente
    _breathCtrl.duration = const Duration(seconds: 4);
    _breathCtrl.repeat(reverse: true);

    _breathCtrl.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.forward) {
        setState(() => _inhale = true);
      } else if (status == AnimationStatus.reverse) {
        setState(() => _inhale = false);
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      _breathCtrl.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _player.resume();
      _breathCtrl.repeat(reverse: true);
      if (mounted) setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _breathCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  'Refuge Mode',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Mandala animada
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _breathAnim,
                builder: (_, child) => Transform.scale(
                  scale: _breathAnim.value,
                  child: child,
                ),
                child: _buildMandala(),
              ),
            ),
          ),

          // Label respiração
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Text(
                _isPlaying
                    ? (_inhale
                        ? 'Inspire suavemente...'
                        : 'Expire devagar...')
                    : 'Acalme sua mente. Sincronize sua respiração com a mandala.',
                key: ValueKey(_inhale),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
            ),
          ),

          // Controles de áudio
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(
              children: [
                // Barra de progresso
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                  ),
                  child: Slider(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds
                            .toDouble()
                            .clamp(0, _duration.inSeconds.toDouble())
                        : 0,
                    min: 0,
                    max: _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1,
                    onChanged: (v) async {
                      await _player
                          .seek(Duration(seconds: v.toInt()));
                    },
                  ),
                ),

                // Tempo
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white38)),
                      Text(_formatDuration(_duration),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white38)),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Botão play/pause
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: const Color(0xFF0A0E1A),
                      size: 30,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMandala() {
    if (_loadingImage) {
      return SizedBox(
        width: 260,
        height: 260,
        child: CircularProgressIndicator(
          color: Colors.tealAccent.withOpacity(0.5),
          strokeWidth: 1.5,
        ),
      );
    }

    if (_imageBase64 != null) {
      return Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.tealAccent.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            base64Decode(_imageBase64!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback: mandala geométrica em canvas
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.tealAccent.withOpacity(0.25),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: CustomPaint(
        painter: _MandalaFallbackPainter(),
      ),
    );
  }
}

class _MandalaFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    final paint = Paint()..style = PaintingStyle.stroke;

    // Círculos concêntricos
    for (int i = 1; i <= 6; i++) {
      paint.color =
          Color.lerp(const Color(0xFF00BFA5), const Color(0xFF7B61FF),
              i / 6)!.withOpacity(0.6);
      paint.strokeWidth = 1.0;
      canvas.drawCircle(center, maxR * (i / 6), paint);
    }

    // Pétalas
    paint.strokeWidth = 1.2;
    for (int ring = 1; ring <= 3; ring++) {
      final r = maxR * (ring / 3.5);
      final count = ring * 8;
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * 2 * 3.14159;
        final x = center.dx + r * 0.85 * _cos(angle);
        final y = center.dy + r * 0.85 * _sin(angle);
        paint.color = const Color(0xFF00E5C8).withOpacity(0.4);
        canvas.drawCircle(Offset(x, y), r * 0.18, paint);
      }
    }

    // Centro
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF00BFA5).withOpacity(0.3);
    canvas.drawCircle(center, maxR * 0.12, paint);
  }

  double _cos(double a) => _approxTrig(a, true);
  double _sin(double a) => _approxTrig(a, false);

  double _approxTrig(double a, bool isCos) {
    // Usar dart:math seria mais limpo mas evitamos import extra aqui
    final normalized = a % (2 * 3.14159265);
    if (isCos) {
      // cos via série de Taylor simplificada
      double x = normalized;
      return 1 - (x * x) / 2 + (x * x * x * x) / 24;
    } else {
      double x = normalized;
      return x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
    }
  }

  @override
  bool shouldRepaint(_MandalaFallbackPainter _) => false;
}
