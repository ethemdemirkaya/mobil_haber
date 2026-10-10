import 'package:flutter/material.dart';

enum EditorialArtKind { briefing, saved, perspectives }

/// Text and actions stay in Flutter so illustrations can remain decorative.
class EditorialArt extends StatelessWidget {
  const EditorialArt({super.key, required this.kind, this.size = 132});
  final EditorialArtKind kind;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/editorial-${kind.name}.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}
