import 'package:pusula_news/core/theme/app_icons.dart';
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
    icon: AppIcons.world,
    color: AppColors.brandSeed,
  );

  static const List<NewsCategory> values = [
    all,
    NewsCategory(
      id: 'gundem',
      name: 'Gündem',
      icon: AppIcons.news,
      color: AppColors.categoryGundem,
    ),
    NewsCategory(
      id: 'spor',
      name: 'Spor',
      icon: AppIcons.ballFootball,
      color: AppColors.categorySpor,
    ),
    NewsCategory(
      id: 'ekonomi',
      name: 'Ekonomi',
      icon: AppIcons.trendingUp,
      color: AppColors.categoryEkonomi,
    ),
    NewsCategory(
      id: 'teknoloji',
      name: 'Teknoloji',
      icon: AppIcons.cpu,
      color: AppColors.categoryTeknoloji,
    ),
    NewsCategory(
      id: 'dunya',
      name: 'Dünya',
      icon: AppIcons.world,
      color: AppColors.categoryDunya,
    ),
    NewsCategory(
      id: 'kultur',
      name: 'Kültür',
      icon: AppIcons.masksTheater,
      color: AppColors.categoryKultur,
    ),
    NewsCategory(
      id: 'saglik',
      name: 'Sağlık',
      icon: AppIcons.heart,
      color: AppColors.categorySaglik,
    ),
    NewsCategory(
      id: 'bilim',
      name: 'Bilim',
      icon: AppIcons.flask,
      color: AppColors.categoryBilim,
    ),
    NewsCategory(
      id: 'egitim',
      name: 'Eğitim',
      icon: AppIcons.school,
      color: AppColors.categoryEgitim,
    ),
    NewsCategory(
      id: 'yasam',
      name: 'Yaşam',
      icon: AppIcons.coffee,
      color: AppColors.categoryYasam,
    ),
    NewsCategory(
      id: 'sanat',
      name: 'Sanat',
      icon: AppIcons.palette,
      color: AppColors.categorySanat,
    ),
    NewsCategory(
      id: 'seyahat',
      name: 'Seyahat',
      icon: AppIcons.planeDeparture,
      color: AppColors.categorySeyahat,
    ),
  ];

  static NewsCategory byId(String id) {
    return values.firstWhere((c) => c.id == id, orElse: () => all);
  }
}
