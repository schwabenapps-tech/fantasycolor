import 'package:flutter/material.dart';

import '../models/coloring_page.dart';
import '../services/print_template_export.dart';
import '../widgets/silver_back_button.dart';

/// Vollbild-Vorschau einer Ausmalvorlage mit Speichern / Teilen.
class PrintPreviewScreen extends StatefulWidget {
  const PrintPreviewScreen({super.key, required this.page});

  final ColoringPage page;

  static const backgroundAsset = 'assets/images/in_app_background.png';

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  bool _busy = false;

  Future<void> _saveToPhotos() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PrintTemplateExport.saveToPhotos(widget.page);
      if (!mounted) return;
      _toast('Vorlage in Fotos gespeichert');
    } on PrintTemplateExportException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('Speichern hat nicht geklappt');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareOrPrint() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PrintTemplateExport.shareOrPrint(widget.page);
    } catch (_) {
      if (!mounted) return;
      _toast('Teilen hat nicht geklappt');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            PrintPreviewScreen.backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      SilverBackButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          page.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: page.aspectRatio <= 0
                            ? 1
                            : page.aspectRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              page.assetPath,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PreviewActionButton(
                          icon: Icons.photo_library_rounded,
                          label: 'In Fotos speichern',
                          color: const Color(0xFF7AD7A8),
                          enabled: !_busy,
                          onPressed: _saveToPhotos,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PreviewActionButton(
                          icon: Icons.print_rounded,
                          label: 'Teilen & Drucken',
                          color: const Color(0xFF9EC8FF),
                          enabled: !_busy,
                          onPressed: _shareOrPrint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFFE8EEF8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewActionButton extends StatelessWidget {
  const _PreviewActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: enabled ? 0.2 : 0.1),
            border: Border.all(
              color: color.withValues(alpha: enabled ? 0.6 : 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
