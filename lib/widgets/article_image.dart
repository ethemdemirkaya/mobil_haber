import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/repositories/og_image_resolver.dart';

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
    final useFallback =
        widget.url.isEmpty || (_primaryFailed && _resolvedFallback != null);
    final activeUrl =
        useFallback ? (_resolvedFallback ?? '') : widget.url;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: activeUrl.isEmpty
          ? _buildPlaceholderOrLoading(cs)
          : CachedNetworkImage(
              imageUrl: activeUrl,
              fit: widget.fit,
              height: widget.height,
              width: widget.width,
              fadeInDuration: const Duration(milliseconds: 220),
              placeholder: (_, _) => Container(
                color: cs.surfaceContainerHighest,
                height: widget.height,
                width: widget.width,
              ),
              errorWidget: (_, _, _) {
                // Primary başarısız → og:image fallback'i tetikle.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _onPrimaryError();
                });
                return _buildPlaceholderOrLoading(cs);
              },
            ),
    );
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
