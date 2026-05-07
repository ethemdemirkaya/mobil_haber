import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/og_image_resolver.dart';
import '../providers/preferences_provider.dart';

/// Haber kartı/detayı için görsel widget'ı.
///
/// İki kademeli görsel kaynağı:
///   1. **Primary URL** — RSS feed'inden gelen `media:content`/`enclosure`/img.
///   2. **OpenGraph fallback** — primary boşsa veya yüklenemezse, makalenin
///      kendi sayfasından `og:image` çekilip kullanılır (lazy + cached).
///
/// `articleUrl` parametresi verilirse fallback aktiftir; yoksa basit
/// görsel davranışı.
class ArticleImage extends StatefulWidget {
  const ArticleImage({
    super.key,
    required this.url,
    this.articleUrl,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.borderRadius = 16,
  });

  final String url;

  /// Makalenin orijinal URL'i. Verilirse, primary `url` boş veya hatalı
  /// olduğunda og:image fallback'i tetiklenir.
  final String? articleUrl;

  final BoxFit fit;
  final double? height;
  final double? width;
  final double borderRadius;

  @override
  State<ArticleImage> createState() => _ArticleImageState();
}

class _ArticleImageState extends State<ArticleImage> {
  // Static resolver — singleton process-wide; cache'i paylaşmak için.
  static final OgImageResolver _resolver = OgImageResolver();

  String? _resolvedFallback;
  bool _resolving = false;
  bool _primaryFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.isEmpty && widget.articleUrl != null) {
      _kickFallback();
    }
  }

  @override
  void didUpdateWidget(covariant ArticleImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.articleUrl != oldWidget.articleUrl) {
      _resolvedFallback = null;
      _primaryFailed = false;
      if (widget.url.isEmpty && widget.articleUrl != null) {
        _kickFallback();
      }
    }
  }

  Future<void> _kickFallback() async {
    if (_resolving) return;
    final src = widget.articleUrl;
    if (src == null || src.isEmpty) return;
    setState(() => _resolving = true);
    final result = await _resolver.resolve(src);
    if (!mounted) return;
    setState(() {
      _resolvedFallback = result;
      _resolving = false;
    });
  }

  void _onPrimaryError() {
    if (_primaryFailed) return;
    setState(() => _primaryFailed = true);
    if (widget.articleUrl != null) _kickFallback();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dataSaver =
        context.watch<PreferencesProvider>().dataSaverImages;
    final useFallback =
        widget.url.isEmpty || (_primaryFailed && _resolvedFallback != null);
    final rawUrl =
        useFallback ? (_resolvedFallback ?? '') : widget.url;
    final activeUrl = dataSaver ? _downscale(rawUrl) : rawUrl;

    // Data saver açıkken cached_network_image'in kendi memCacheWidth/Height
    // limitlerini de küçültüyoruz (decode aşamasında bellek).
    final memWidth = dataSaver ? 480 : null;
    final memHeight = dataSaver ? 320 : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: activeUrl.isEmpty
          ? _buildPlaceholderOrLoading(cs)
          : CachedNetworkImage(
              imageUrl: activeUrl,
              fit: widget.fit,
              height: widget.height,
              width: widget.width,
              memCacheWidth: memWidth,
              memCacheHeight: memHeight,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, _) => Container(
                color: cs.surfaceContainerHighest,
                height: widget.height,
                width: widget.width,
              ),
              errorWidget: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _onPrimaryError();
                });
                return _buildPlaceholderOrLoading(cs);
              },
            ),
    );
  }

  /// Data saver açıkken bilinen kaynaklarda URL'in büyük varyantını
  /// küçük thumbnail'a geri çeviriyoruz — RSS'ten geleni rsv'le büyütmüştük,
  /// burada tersi: kullanıcının veri planını korumak için minimal indir.
  String _downscale(String url) {
    if (url.isEmpty) return url;
    var u = url;
    if (u.contains('cdnuploads.aa.com.tr') &&
        !u.contains('thumbs_b_c_')) {
      // hash → thumbs_b_c_hash
      u = u.replaceFirstMapped(
        RegExp(r'(/Contents/\d{4}/\d{2}/\d{2}/)'),
        (m) => '${m.group(1)}thumbs_b_c_',
      );
      return u;
    }
    if (u.contains('image.hurimg.com')) {
      return u.replaceFirst(RegExp(r'/\d{2,4}x\d{2,4}/'), '/640x360/');
    }
    if (u.contains('image.cnnturk.com')) {
      return u.replaceFirst(RegExp(r'/\d{2,4}x\d{2,4}/'), '/640x360/');
    }
    if (u.contains('ichef.bbci.co.uk')) {
      return u.replaceFirst(
          RegExp(r'/\d+/cps'), '/480/cps');
    }
    if (u.contains('images.ntv.com.tr')) {
      return u.replaceFirst(RegExp(r'width=\d+'), 'width=640');
    }
    if (u.contains('i.gazeteduvar.com.tr') ||
        u.contains('i.artigercek.com')) {
      return u.replaceFirst(RegExp(r'/2/\d+/\d+/'), '/2/640/360/');
    }
    return u;
  }

  Widget _buildPlaceholderOrLoading(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      height: widget.height,
      width: widget.width,
      alignment: Alignment.center,
      child: _resolving
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(cs.onSurfaceVariant),
              ),
            )
          : Icon(
              Icons.image_outlined,
              color: cs.onSurfaceVariant,
              size: 32,
            ),
    );
  }
}
