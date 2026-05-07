import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ArticleImage extends StatelessWidget {
  const ArticleImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
    this.borderRadius = 16,
  });

  final String url;
  final BoxFit fit;
  final double? height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        height: height,
        width: width,
        fadeInDuration: const Duration(milliseconds: 220),
        placeholder: (context, _) => Container(
          color: cs.surfaceContainerHighest,
          height: height,
          width: width,
        ),
        errorWidget: (context, _, __) => Container(
          color: cs.surfaceContainerHighest,
          height: height,
          width: width,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            color: cs.onSurfaceVariant,
            size: 32,
          ),
        ),
      ),
    );
  }
}
