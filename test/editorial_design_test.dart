import 'package:pusula_news/widgets/pusula_launch_scene.dart';
import 'package:pusula_news/screens/splash/splash_screen.dart';
import 'package:pusula_news/providers/onboarding_provider.dart';
import 'package:pusula_news/widgets/editorial_art.dart';
import 'package:pusula_news/widgets/empty_state.dart';
import 'package:pusula_news/data/local/article_cache_store.dart';
import 'package:pusula_news/data/local/ai_cache_store.dart';
import 'package:pusula_news/data/local/reading_history_store.dart';
import 'package:pusula_news/screens/detail/article_detail_screen.dart';
import 'package:pusula_news/providers/ai_settings_provider.dart';
import 'package:pusula_news/providers/reading_progress_provider.dart';
import 'package:pusula_news/data/models/bias_report.dart';
import 'package:pusula_news/widgets/pusula_navigation_bar.dart';
import 'package:pusula_news/widgets/bias_indicator.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pusula_news/core/theme/app_theme.dart';
import 'package:pusula_news/data/local/local_db.dart';
import 'package:pusula_news/providers/preferences_provider.dart';
import 'package:pusula_news/providers/news_provider.dart';
import 'package:pusula_news/screens/onboarding/onboarding_screen.dart';
import 'package:pusula_news/screens/onboarding/source_picker_screen.dart';
import 'package:pusula_news/widgets/pusula_glyph.dart';
import 'package:pusula_news/widgets/article_card.dart';
import 'package:pusula_news/data/models/article.dart';
import 'package:pusula_news/core/utils/date_formatter.dart';
import 'package:pusula_news/providers/bookmark_provider.dart';
import 'package:pusula_news/providers/reading_theme_provider.dart';
import 'package:pusula_news/providers/reading_history_provider.dart';
import 'package:pusula_news/providers/keyword_filter_provider.dart';

void main() {
  sqfliteFfiInit();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDb.useInMemoryForTests(databaseFactoryFfi);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
  });

  Future<void> fonts() async {
    for (final name in ['Inter', 'Newsreader']) {
      await (FontLoader(
        name,
      )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
    }
    await (FontLoader('packages/flutter_tabler_icons/tabler-icons')..addFont(
          rootBundle.load(
            'packages/flutter_tabler_icons/assets/fonts/tabler-icons.ttf',
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/design/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Welcome and interests fit ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      await fonts();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = PreferencesProvider();
      final key = GlobalKey();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: prefs,
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: RepaintBoundary(key: key, child: const OnboardingScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/wise-owl.png'),
          key.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'welcome-${dark ? 'dark' : 'light'}');
      await tester.tap(find.text('Başlayalım'));
      await tester.pumpAndSettle();
      expect(find.text('Neyi merak\nediyorsun?'), findsOneWidget);
      await tester.ensureVisible(find.text('Bilim'));
      await tester.tap(find.widgetWithText(FilterChip, 'Bilim'));
      await tester.pumpAndSettle();
      expect(find.text('1 konu seçtin.'), findsOneWidget);
      await capture(tester, key, 'interests-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Small screen with large type keeps primary action reachable', (
    tester,
  ) async {
    await fonts();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PreferencesProvider(),
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();
    expect(find.text('Kaynaklarını seç'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('Interests persist across provider instances', () async {
    final prefs = PreferencesProvider();
    await Future<void>.delayed(Duration.zero);
    await prefs.setInterests({'bilim', 'ekonomi'});
    final restored = PreferencesProvider();
    await Future<void>.delayed(Duration.zero);
    expect(restored.interests, {'bilim', 'ekonomi'});
    prefs.dispose();
    restored.dispose();
  });
  testWidgets('Source picker supports search and requires a source', (
    tester,
  ) async {
    await fonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PreferencesProvider()),
          ChangeNotifierProvider(
            create: (_) => NewsProvider(cacheStore: const _ReviewFeedStore()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: RepaintBoundary(key: key, child: const SourcePickerScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'sources-light');
    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('Bu isimde kaynak bulunamadı.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Export the production compass icon', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RepaintBoundary(
          key: key,
          child: const ColoredBox(
            color: Color(0xFFF6F3EE),
            child: Center(child: PusulaGlyph(size: 780)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'launcher-master');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox.square(
              dimension: 128,
              child: PusulaGlyph(size: 128),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'launch-mark');
  });
  testWidgets('Narrow news card keeps metadata and bookmark usable', (
    tester,
  ) async {
    await fonts();
    await DateFormatter.ensureInitialized();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bookmarks = BookmarkProvider();
    final article = Article(
      id: 'design-test',
      title:
          'Türkçe karakterlerle uzun bir haber başlığı: İstanbul, eğitim ve bilim',
      summary: 'Yalnızca arayüz testi için kullanılan örnek metin.',
      content: '',
      categoryId: 'bilim',
      imageUrl: '',
      author: 'Test',
      publishedAt: DateTime.now(),
      readMinutes: 3,
      sourceName: 'Arayüz test kaynağı',
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: bookmarks),
          ChangeNotifierProvider(create: (_) => PreferencesProvider()),
          ChangeNotifierProvider(
            create: (_) => NewsProvider(cacheStore: const _ReviewFeedStore()),
          ),
          ChangeNotifierProvider(create: (_) => ReadingThemeProvider()),
          ChangeNotifierProvider(
            create: (_) =>
                ReadingHistoryProvider(store: const _ReviewHistoryStore()),
          ),
          ChangeNotifierProvider(create: (_) => KeywordFilterProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              appBar: AppBar(title: const Text('Haber kartı testi')),
              body: ArticleCard(article: article, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Sonra okumak için kaydet'));
    await tester.pumpAndSettle();
    expect(bookmarks.isBookmarked(article.id), isTrue);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'article-small-large-type');
  });
  for (final dark in [false, true]) {
    testWidgets('Article tools align and remain usable with large type $dark', (
      tester,
    ) async {
      await fonts();
      await DateFormatter.ensureInitialized();
      tester.view.physicalSize = Size(dark ? 320 : 390, dark ? 760 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        'flutter_tts',
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers.global/events',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (_) async => 1,
        );
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async {
          if (call.method == 'create') {
            final id = (call.arguments as Map)['playerId'];
            messenger.setMockMethodCallHandler(
              MethodChannel('xyz.luan/audioplayers/events/$id'),
              (_) async => null,
            );
          }
          return 1;
        },
      );
      final article = Article(
        id: 'detail-review',
        title: 'Şehir kütüphaneleri yeni okuma alanlarıyla açılıyor',
        summary: 'Devamı için tıklayınız',
        content: '',
        categoryId: 'gundem',
        imageUrl: '',
        author: 'Haber Merkezi',
        publishedAt: DateTime(2026, 10, 9, 10),
        readMinutes: 3,
        sourceName: 'Örnek kaynak',
        sourceUrl: 'https://example.org/haber',
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AiSettingsProvider>(
              create: (_) => _ReviewAi(),
            ),
            ChangeNotifierProvider(create: (_) => PreferencesProvider()),
            ChangeNotifierProvider(create: (_) => BookmarkProvider()),
            ChangeNotifierProvider(
              create: (_) =>
                  ReadingHistoryProvider(store: const _ReviewHistoryStore()),
            ),
            ChangeNotifierProvider(create: (_) => ReadingProgressProvider()),
            ChangeNotifierProvider(create: (_) => ReadingThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => NewsProvider(cacheStore: const _ReviewFeedStore()),
            ),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: key,
              child: ArticleDetailScreen(article: article),
            ),
          ),
        ),
      );
      if (!dark) {
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/brand/wise-owl-curious.png'),
            tester.element(find.byType(ArticleDetailScreen)),
          );
        });
      }
      await tester.pumpAndSettle();
      expect(find.text('Devamı için tıklayınız'), findsNothing);
      expect(tester.takeException(), isNull);
      await capture(
        tester,
        key,
        dark ? 'detail-dark-large-type' : 'detail-light-top',
      );
      await tester.ensureVisible(find.text('Okuma yardımı'));
      await tester.pumpAndSettle();
      await capture(
        tester,
        key,
        dark ? 'reading-help-dark-200' : 'reading-help-light',
      );
      await tester.ensureVisible(find.text('Haberin dilini incele'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haberin dilini incele'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(BiasIndicator));
      await tester.pumpAndSettle();
      await capture(
        tester,
        key,
        dark ? 'detail-dark-tools' : 'detail-light-tools',
      );
      await tester.tap(find.text('Değerlendirme hakkında'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('haberin doğruluğunu kontrol etmez'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Kısa özeti oku'));
      await tester.pumpAndSettle();
      final summaryButton = tester.getSize(
        find
            .ancestor(
              of: find.text('Kısa özeti oku'),
              matching: find.byType(TextButton),
            )
            .first,
      );
      expect(summaryButton.height, greaterThanOrEqualTo(64));
      await tester.tap(find.text('Kısa özeti oku'));
      await tester.pumpAndSettle();
      expect(find.text('Kısa özet'), findsOneWidget);
      expect(
        find.text('Kütüphanelerde yeni okuma alanları açılıyor.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Kısa özet'));
      await tester.pumpAndSettle();
      await capture(
        tester,
        key,
        dark ? 'reading-summary-dark-200' : 'reading-summary-light',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  for (final dark in [false, true]) {
    testWidgets('Mascot launch fits and respects reduced motion $dark', (
      tester,
    ) async {
      await fonts();
      tester.view.physicalSize = Size(dark ? 320 : 390, dark ? 640 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: RepaintBoundary(
            key: key,
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(dark ? 320 : 390, dark ? 640 : 844),
                textScaler: TextScaler.linear(dark ? 2 : 1),
              ),
              child: const PusulaLaunchScene(progress: .4),
            ),
          ),
        ),
      );
      if (!dark) {
        await tester.runAsync(
          () async => precacheImage(
            const AssetImage('assets/brand/wise-owl-welcome.png'),
            tester.element(find.byType(PusulaLaunchScene)),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(
        tester,
        key,
        dark ? 'mascot-launch-dark-large' : 'mascot-launch-light',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => OnboardingProvider()),
            ChangeNotifierProvider(create: (_) => PreferencesProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const SplashScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(PusulaLaunchScene), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Launch greeting finishes and reveals onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OnboardingProvider()),
          ChangeNotifierProvider(create: (_) => PreferencesProvider()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SplashScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PusulaLaunchScene), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(PusulaLaunchScene), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Export native mascot with Android safe circle padding', (
    tester,
  ) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(288, 288);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: const Center(
            child: Image(
              image: AssetImage('assets/brand/wise-owl-welcome.png'),
              width: 136,
              height: 136,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'native-launch-mascot');
  });
  for (final kind in EditorialArtKind.values) {
    testWidgets('Editorial illustration renders $kind in dark theme', (
      tester,
    ) async {
      await fonts();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: EmptyState(
                icon: Icons.bookmark,
                art: kind,
                title: switch (kind) {
                  EditorialArtKind.saved => 'Okumak istediklerin burada',
                  EditorialArtKind.briefing => 'Gündeme kulak ver',
                  EditorialArtKind.perspectives => 'Bir olay, farklı bakışlar',
                },
                subtitle: 'Haberleri kendi zamanında keşfet.',
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () async => precacheImage(
          AssetImage('assets/brand/editorial-${kind.name}.png'),
          tester.element(find.byType(EmptyState)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'editorial-${kind.name}-dark');
    });
  }
  testWidgets('Navigation fits large type and selects every destination', (
    tester,
  ) async {
    await fonts();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: RepaintBoundary(
              key: key,
              child: Scaffold(
                body: const Center(child: Text('Pusula')),
                bottomNavigationBar: PusulaNavigationBar(
                  selectedIndex: selected,
                  bookmarkCount: 124,
                  onSelected: (i) => setState(() => selected = i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final label in [
      'Çapraz',
      'Sana özel',
      'Kayıtlı',
      'Ayarlar',
      'Bugün',
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(selected, 0);
    await capture(tester, key, 'navigation-large-type');
  });
}

class _ReviewAi extends AiSettingsProvider {
  _ReviewAi() : super(aiCache: const _ReviewAiStore());
  @override
  bool isReady() => true;
  String? _summary;
  @override
  String? cachedSummary(String articleId) => _summary;
  @override
  Future<void> summarize(Article article) async {
    _summary = 'Kütüphanelerde yeni okuma alanları açılıyor.';
    notifyListeners();
  }

  @override
  BiasReport? cachedBias(String articleId) => const BiasReport(
    score: 10,
    label: 'Nötr',
    cues: [],
    summary:
        'Manşet gelişmeyi aktarıyor; duygusal veya yönlendirici bir ifade içermiyor.',
    confidence: BiasConfidence.high,
  );
}

class _ReviewFeedStore extends ArticleCacheStore {
  const _ReviewFeedStore();
  @override
  Future<CachedFeed> read() async => const CachedFeed(articles: []);
}

class _ReviewHistoryStore extends ReadingHistoryStore {
  const _ReviewHistoryStore();
  @override
  Future<List<HistoryEntry>> load() async => [];
  @override
  Future<void> upsertAll(List<HistoryEntry> entries) async {}
}

class _ReviewAiStore extends AiCacheStore {
  const _ReviewAiStore();
  @override
  Future<Map<String, String>> load(String kind) async => {};
}
