import 'package:pusula_news/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/notifications/scheduled_briefing_service.dart';
import '../../providers/onboarding_provider.dart';

class NotificationIntroScreen extends StatefulWidget {
  const NotificationIntroScreen({super.key});
  @override
  State<NotificationIntroScreen> createState() =>
      _NotificationIntroScreenState();
}

class _NotificationIntroScreenState extends State<NotificationIntroScreen> {
  bool _busy = false;
  Future<void> _finish(bool enable) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (enable) {
      try {
        await ScheduledBriefingService.requestPermission();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bildirim iznini daha sonra ayarlardan açabilirsin.',
              ),
            ),
          );
        }
      }
    }
    if (!mounted) return;
    await context.read<OnboardingProvider>().complete();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Son bir şey')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        AppIcons.bell,
                        size: 42,
                        color: t.colorScheme.primary,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Gündeme kendi\nzamanında yetiş.',
                        style: t.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bildirimleri açarak ayarlardan oluşturacağın sesli brifingler için hatırlatma alabilirsin.',
                        style: t.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 32),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ÖRNEK HATIRLATMA',
                                style: t.textTheme.labelSmall?.copyWith(
                                  color: t.colorScheme.primary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sabah brifingin hazır.',
                                style: t.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bir kahve molasında gündeme kulak ver.',
                                style: t.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Saat ve konuları Ayarlar → Zamanlanmış Brifingler bölümünden sen belirlersin.',
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _finish(true),
                child: Text(_busy ? 'Hazırlanıyor…' : 'Bildirimlere izin ver'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _finish(false),
                child: const Text('Şimdilik geç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
