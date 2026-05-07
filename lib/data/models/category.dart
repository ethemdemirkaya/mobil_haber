import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class NewsCategory {
  const NewsCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  static const NewsCategory all = NewsCategory(
    id: 'all',
    name: 'Tümü',
    icon: Icons.public_outlined,
    color: AppColors.brandSeed,
  );

  static const List<NewsCategory> values = [
    all,
    NewsCategory(
      id: 'gundem',
      name: 'Gündem',
      icon: Icons.newspaper_outlined,
      color: AppColors.categoryGundem,
    ),
    NewsCategory(
      id: 'spor',
      name: 'Spor',
      icon: Icons.sports_soccer_outlined,
      color: AppColors.categorySpor,
    ),
    NewsCategory(
      id: 'ekonomi',
      name: 'Ekonomi',
      icon: Icons.trending_up_outlined,
      color: AppColors.categoryEkonomi,
    ),
    NewsCategory(
      id: 'teknoloji',
      name: 'Teknoloji',
      icon: Icons.memory_outlined,
      color: AppColors.categoryTeknoloji,
    ),
    NewsCategory(
      id: 'dunya',
      name: 'Dünya',
      icon: Icons.travel_explore_outlined,
      color: AppColors.categoryDunya,
    ),
    NewsCategory(
      id: 'kultur',
      name: 'Kültür',
      icon: Icons.theater_comedy_outlined,
      color: AppColors.categoryKultur,
    ),
    NewsCategory(
      id: 'saglik',
      name: 'Sağlık',
      icon: Icons.favorite_outline,
      color: AppColors.categorySaglik,
    ),
    NewsCategory(
      id: 'bilim',
      name: 'Bilim',
      icon: Icons.science_outlined,
      color: AppColors.categoryBilim,
    ),
    NewsCategory(
      id: 'egitim',
      name: 'Eğitim',
      icon: Icons.school_outlined,
      color: AppColors.categoryEgitim,
    ),
    NewsCategory(
      id: 'yasam',
      name: 'Yaşam',
      icon: Icons.local_cafe_outlined,
      color: AppColors.categoryYasam,
    ),
    NewsCategory(
      id: 'sanat',
      name: 'Sanat',
      icon: Icons.palette_outlined,
      color: AppColors.categorySanat,
    ),
    NewsCategory(
      id: 'seyahat',
      name: 'Seyahat',
      icon: Icons.flight_takeoff_outlined,
      color: AppColors.categorySeyahat,
    ),
  ];

  static NewsCategory byId(String id) {
    return values.firstWhere(
      (c) => c.id == id,
      orElse: () => all,
    );
  }
}
