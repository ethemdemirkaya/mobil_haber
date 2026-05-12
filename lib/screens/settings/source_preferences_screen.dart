import '../onboarding/source_picker_screen.dart';

/// Ayarlar > Kaynak Tercihleri — Onboarding'deki seçim ekranını standalone
/// modda yeniden kullanır. Tek dosya, tek model.
class SourcePreferencesScreen extends SourcePickerScreen {
  const SourcePreferencesScreen({super.key})
      : super(standalone: true, title: 'Kaynak Tercihleri');
}
