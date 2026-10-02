import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/consent_service.dart';
import '../utils/app_layout.dart';
import '../widgets/silver_back_button.dart';

/// App settings: music, support, about / artwork credit.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const backgroundAsset = 'assets/images/in_app_background.png';
  static const supportEmail = 'fantasycolor@schwabenapps.com';
  static const appVersion = '1.0.0';
  static const privacyUrl =
      'https://cdn.schwabenapps.com/fantasy-color/legal/privacy.html';
  static const termsUrl =
      'https://cdn.schwabenapps.com/fantasy-color/legal/terms.html';

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final audio = context.watch<AudioService>();
    final consent = context.watch<ConsentService>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.hubHorizontalPadding * 0.9,
                    56,
                    layout.hubHorizontalPadding * 0.9,
                    20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        children: [
                          Text(
                            'Settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFFFF6E8),
                              fontSize: layout.isTablet ? 30 : 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              shadows: const [
                                Shadow(
                                  color: Color(0xAA000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _SettingsCard(
                            child: SwitchListTile.adaptive(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              secondary: Icon(
                                audio.muted
                                    ? Icons.music_off_rounded
                                    : Icons.music_note_rounded,
                                color: const Color(0xFF3A2810),
                              ),
                              title: const Text(
                                'Music',
                                style: TextStyle(
                                  color: Color(0xFF2A2410),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                audio.muted ? 'Muted' : 'Playing',
                                style: TextStyle(
                                  color: const Color(0xFF2A2410)
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              value: !audio.muted,
                              activeThumbColor: const Color(0xFFC9A06A),
                              onChanged: (on) {
                                unawaited(audio.setMuted(!on));
                                AnalyticsService.instance
                                    .logMuteToggled(muted: !on);
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SettingsCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Support'),
                                _SettingsTile(
                                  icon: Icons.mail_outline_rounded,
                                  title: 'Contact support',
                                  subtitle: 'Report an issue and get help',
                                  onTap: () => _openSupportMail(context),
                                ),
                                const Divider(height: 8),
                                _SettingsTile(
                                  icon: Icons.feedback_outlined,
                                  title: 'Send feedback',
                                  subtitle: 'Share ideas or report a problem',
                                  onTap: () => _openFeedbackDialog(context),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _SettingsCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('About'),
                                _SettingsTile(
                                  icon: Icons.palette_outlined,
                                  title: 'Original artwork',
                                  subtitle:
                                      'All images in Fantasy Color are '
                                      'original creations made for this app.',
                                  onTap: () => _showArtworkInfo(context),
                                ),
                                const Divider(height: 8),
                                _SettingsTile(
                                  icon: Icons.privacy_tip_outlined,
                                  title: 'Privacy',
                                  subtitle:
                                      'How Fantasy Color handles your data',
                                  onTap: () => _openUrl(context, privacyUrl),
                                ),
                                const Divider(height: 8),
                                _SettingsTile(
                                  icon: Icons.tune_rounded,
                                  title: 'Ad privacy choices',
                                  subtitle: consent.privacyOptionsRequired
                                      ? 'Review or change ad privacy settings'
                                      : 'Open privacy choices when available '
                                          'in your region',
                                  onTap: () => _openAdPrivacyChoices(context),
                                ),
                                const Divider(height: 8),
                                _SettingsTile(
                                  icon: Icons.description_outlined,
                                  title: 'Terms of Use',
                                  subtitle: 'Rules for using Fantasy Color',
                                  onTap: () => _openUrl(context, termsUrl),
                                ),
                                const Divider(height: 8),
                                const _SettingsTile(
                                  icon: Icons.info_outline_rounded,
                                  title: 'Fantasy Color',
                                  subtitle: 'Version $appVersion\nSchwaben Apps',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: SilverBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openSupportMail(BuildContext context) async {
    await _sendMail(
      context,
      subject: 'Fantasy Color Support',
      body: 'App version: $appVersion\n\n'
          'Issue:\n\n'
          'Message:\n',
    );
  }

  static Future<void> _openFeedbackDialog(BuildContext context) async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => const _FeedbackDialog(),
    );
    if (message == null || message.trim().isEmpty) return;
    if (!context.mounted) return;
    await _sendMail(
      context,
      subject: 'Fantasy Color Feedback',
      body: 'App version: $appVersion\n\n${message.trim()}',
    );
  }

  static Future<void> _sendMail(
    BuildContext context, {
    required String subject,
    required String body,
  }) async {
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: _encodeQuery({
        'subject': subject,
        'body': body,
      }),
    );

    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } on MissingPluginException catch (e, st) {
      debugPrint('url_launcher missing (full restart needed): $e\n$st');
    } catch (e, st) {
      debugPrint('mailto launch failed: $e\n$st');
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: subject,
          text: body,
          sharePositionOrigin: shareOrigin,
        ),
      );
      return;
    } catch (e, st) {
      debugPrint('share fallback failed: $e\n$st');
    }

    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: body));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message copied. You can paste it into a message to us.'),
      ),
    );
  }

  static String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (e, st) {
      debugPrint('openUrl failed: $e\n$st');
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open link:\n$url')),
    );
  }

  static void _showArtworkInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Original artwork'),
        content: const Text(
          'Every coloring page, puzzle image, and print template in '
          'Fantasy Color is an original creation made for this app. '
          'Thank you for coloring with us!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _openAdPrivacyChoices(BuildContext context) async {
    final consent = context.read<ConsentService>();
    if (!consent.privacyOptionsRequired) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No extra ad privacy form is required in your region. '
            'See Privacy for details.',
          ),
        ),
      );
      return;
    }

    final error = await consent.showPrivacyOptions();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open privacy choices: ${error.message}'),
        ),
      );
    }
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  late final TextEditingController _controller;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send feedback'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ideas, bugs, or anything we should improve.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 5,
              minLines: 4,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                height: 1.35,
              ),
              cursorColor: Colors.black87,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Tell us what you think…',
                hintStyle: TextStyle(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFC9A06A),
                    width: 1.6,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              _controller.text.trim().isEmpty || _sending ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC9A06A),
            foregroundColor: const Color(0xFF2A2410),
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B4E2E),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8EC),
            Color(0xFFE8C9A0),
            Color(0xFFD4B896),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.75),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC9A06A).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: const Color(0xFF3A2810)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF2A2410),
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                color: const Color(0xFF2A2410).withValues(alpha: 0.65),
                height: 1.25,
              ),
            ),
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFF2A2410).withValues(alpha: 0.45),
            ),
    );
  }
}
