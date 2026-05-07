import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/news_source.dart';

/// Haber kaynağı logosunu fallback zinciri ile yükleyen widget.
///
/// Sıra:
///   1. Google s2/favicons API (`https://www.google.com/s2/favicons?domain=&sz=128`)
///   2. DuckDuckGo ip3 (`https://icons.duckduckgo.com/ip3/{domain}.ico`)
///   3. Brand renkli harf placeholder (kaynağın `shortName` ilk harfi)
///
/// Google bazen rate limit yapıyor / belirli bölgelerde yavaş. DuckDuckGo
/// benzer servis sunuyor ve genelde Google'ın yaramadığı durumda çalışıyor.
class SourceLogo extends StatefulWidget {
  const SourceLogo({
    super.key,
    required this.source,
    this.size = 44,
    this.borderRadius = 12,
  });

  final NewsSource source;
  final double size;
  final double borderRadius;

  @override
  State<SourceLogo> createState() => _SourceLogoState();
}

class _SourceLogoState extends State<SourceLogo> {
  // Hangi fallback denenmiş — primary fail → secondary.
  bool _primaryFailed = false;
  bool _secondaryFailed = false;

  String get _primaryUrl =>
      'https://www.google.com/s2/favicons?domain=${widget.source.domain}&sz=128';
  String get _secondaryUrl =>
      'https://icons.duckduckgo.com/ip3/${widget.source.domain}.ico';

  @override
  Widget build(BuildContext context) {
    final placeholder = _LetterPlaceholder(
      source: widget.source,
      size: widget.size,
    );

    if (_secondaryFailed) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: placeholder,
      );
    }

    final activeUrl = _primaryFailed ? _secondaryUrl : _primaryUrl;
    final cacheKey = _primaryFailed
        ? 'ddg-${widget.source.id}'
        : 'g-${widget.source.id}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.size,
        height: widget.size,
        color: widget.source.brandColor.withValues(alpha: 0.10),
        child: CachedNetworkImage(
          imageUrl: activeUrl,
          cacheKey: cacheKey,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) {
            // İlk fail → DuckDuckGo'ya geç. Onun da fail'i → harf.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                if (!_primaryFailed) {
                  _primaryFailed = true;
                } else {
                  _secondaryFailed = true;
                }
              });
            });
            return placeholder;
          },
        ),
      ),
    );
  }
}

class _LetterPlaceholder extends StatelessWidget {
  const _LetterPlaceholder({required this.source, required this.size});

  final NewsSource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = source.shortName.isNotEmpty
        ? source.shortName.substring(0, 1).toUpperCase()
        : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: source.brandColor.withValues(alpha: 0.18),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: source.brandColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}
