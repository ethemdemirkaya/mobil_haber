import 'package:flutter/material.dart';
import 'empty_state.dart';

class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.tone,
  });
  final IconData icon;
  final String title;
  final String? subtitle, actionLabel;
  final VoidCallback? onAction;
  final Color? tone;
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: icon,
    title: title,
    subtitle: subtitle,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
