import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../painting/coloring_bitmap.dart';
import '../providers/coloring_session.dart';
import '../widgets/coloring_canvas.dart';
import '../widgets/paint_side_rail.dart';

/// Interaktiver Mal-Screen mit PNG-Flood-Fill, Stift, Zoom, Undo und Fertig.
class ColoringPreviewScreen extends StatefulWidget {
  const ColoringPreviewScreen({super.key, required this.page});

  final ColoringPage page;

  static const _paperBackground = 'assets/images/ausmalhintergund.png';

  @override
  State<ColoringPreviewScreen> createState() => _ColoringPreviewScreenState();
}

class _ColoringPreviewScreenState extends State<ColoringPreviewScreen> {
  late final ColoringSession _session;
  late final Future<ColoringBitmap> _bitmapFuture;

  @override
  void initState() {
    super.initState();
    _session = ColoringSession();
    _bitmapFuture = ColoringBitmap.load(widget.page.assetPath);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            ColoringPreviewScreen._paperBackground,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 52, 8, 16),
                          child: FutureBuilder<ColoringBitmap>(
                            future: _bitmapFuture,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Bild konnte nicht geladen werden',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Color(0xFF8FA0C8),
                                    ),
                                  ),
                                );
                              }
                              return ColoringCanvas(
                                bitmap: snapshot.data!,
                                session: _session,
                              );
                            },
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 12,
                        child: _RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 12,
                        child: AnimatedBuilder(
                          animation: _session,
                          builder: (context, _) {
                            return Row(
                              children: [
                                _RoundIconButton(
                                  icon: Icons.undo_rounded,
                                  onPressed:
                                      _session.canUndo ? _session.undo : null,
                                  dimmed: !_session.canUndo,
                                ),
                                const SizedBox(width: 10),
                                _DoneButton(onPressed: _finish),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PaintSideRail(session: _session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB6F5C8),
                Color(0xFF3DDC84),
                Color(0xFF1FA855),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3DDC84).withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF0E3B22),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    this.dimmed = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7F9FC),
                  Color(0xFFC5CCD8),
                  Color(0xFF9AA3B5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF243044), size: 24),
          ),
        ),
      ),
    );
  }
}
