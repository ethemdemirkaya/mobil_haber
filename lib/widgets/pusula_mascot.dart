import 'package:flutter/material.dart';

enum MascotPose { reading, listening, curious }

class PusulaMascot extends StatelessWidget {
  const PusulaMascot({
    super.key,
    this.pose = MascotPose.reading,
    this.size = 64,
  });
  final MascotPose pose;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      switch (pose) {
        MascotPose.reading => 'assets/brand/wise-owl.png',
        MascotPose.listening => 'assets/brand/wise-owl-listening.png',
        MascotPose.curious => 'assets/brand/wise-owl-curious.png',
      },
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}
