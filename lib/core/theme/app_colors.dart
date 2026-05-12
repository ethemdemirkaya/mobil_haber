import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // v2 (özetleyici) palet — kırmızı yumuşatılıp modern bir tonla değiştirildi.
  // Eski: #D32F2F (Material red 700) — kuvvetli ve klasik haber-app kırmızısı.
  // Yeni: #E5484D — daha rafine, hafif desatüre, monitör/karanlık modda nazik.
  static const Color brandSeed = Color(0xFFE5484D);
  static const Color accent = Color(0xFFFFA000);

  // Gündem rengi seed ile aynı çizgide (haber kategorilerinin temel kırmızısı).
  static const Color categoryGundem = Color(0xFFE5484D);
  static const Color categorySpor = Color(0xFF2E7D32);
  static const Color categoryEkonomi = Color(0xFF1565C0);
  static const Color categoryTeknoloji = Color(0xFF6A1B9A);
  static const Color categoryDunya = Color(0xFF00838F);
  static const Color categoryKultur = Color(0xFFAD1457);
  static const Color categorySaglik = Color(0xFFEF6C00);
  static const Color categoryBilim = Color(0xFF283593);
  static const Color categoryEgitim = Color(0xFF558B2F);
  static const Color categoryYasam = Color(0xFF8D6E63);
  static const Color categorySanat = Color(0xFF512DA8);
  static const Color categorySeyahat = Color(0xFF00695C);
}
