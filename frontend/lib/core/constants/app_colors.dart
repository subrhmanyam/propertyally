import 'package:flutter/material.dart';

/// Bogineni Group design system — boginenigroup.com
/// Luxury minimalist: pure black backgrounds, silver text, gold accents.
class AppColors {
  AppColors._();

  // ── Outer shell ───────────────────────────────────────────────────
  static const Color bgOuter = Color(0xFF000000); // Pure black

  // ── Sidebar ───────────────────────────────────────────────────────
  static const Color sidebarBg = Color(0xFF0A0A0A); // Near-black
  static const Color sidebarIcon = Color(0xFF606060); // Muted
  static const Color sidebarIconActive = Color(0xFFC0C0C0); // Silver
  static const Color sidebarItemHover = Color(0xFF161616);
  static const Color sidebarItemActive = Color(0xFF1E1E1E);
  static const Color sidebarAddBtn = Color(0xFF2A2A2A); // Charcoal

  // ── Content / page ────────────────────────────────────────────────
  static const Color contentBg = Color(0xFF131313); // Dark content bg
  static const Color pageBg = Color(0xFF0D0D0D); // Slightly darker
  static const Color cardBg = Color(0xFF1A1A1A); // Card surface
  static const Color progressCardBg = Color(0xFF1E1E1E); // Elevated card
  static const Color divider = Color(0xFF242424); // Subtle divider
  static const Color border = Color(0xFF2A2A2A); // Standard border

  // ── Text ──────────────────────────────────────────────────────────
  static const Color textHeading = Color(0xFFFFFFFF); // White — headings
  static const Color textPrimary = Color(0xFFC0C0C0); // Silver — body
  static const Color textSecondary = Color(0xFF908787); // Muted silver
  static const Color textMuted = Color(0xFF606060); // Taupe — captions
  static const Color textGreen = Color(0xFFC0C0C0); // Alias → silver (compat)
  static const Color textLink = Color(0xFFD4AF37); // Gold links

  // ── Accent ────────────────────────────────────────────────────────
  static const Color accentSilver = Color(0xFFC0C0C0); // Primary action
  static const Color accentGold = Color(0xFFD4AF37); // Gold highlight
  static const Color accentGoldDark = Color(0xFF9E7C1A); // Muted gold bg
  // Legacy aliases — kept for widgets that still reference these names
  static const Color accentGreen = Color(0xFFC0C0C0); // → silver
  static const Color accentGreenLight = Color(0xFF797373); // → muted silver

  // ── Status badges (dark-theme adapted) ───────────────────────────
  static const Color occupiedBg = Color(0xFF1A2E1A); // Dark green wash
  static const Color occupiedText = Color(0xFF66BB6A); // Green text
  static const Color vacantBg = Color(0xFF2E2000); // Dark amber wash
  static const Color vacantText = Color(0xFFFFA726); // Amber text
  static const Color pendingBg = Color(0xFF2E1500); // Dark orange wash
  static const Color pendingText = Color(0xFFFF8A50); // Orange text

  // ── Chart ─────────────────────────────────────────────────────────
  static const Color chartGreen = Color(0xFFC0C0C0); // Silver bars
  static const Color chartGold = Color(0xFFD4AF37); // Gold bars

  // ── Semantic ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFCF6679);
  static const Color info = Color(0xFF64B5F6);

  // ── Top bar ───────────────────────────────────────────────────────
  static const Color topBarBg = Color(0xFF131313);
  static const Color topBarIcon = Color(0xFF606060);
  static const Color searchBg = Color(0xFF1A1A1A);
  static const Color searchBorder = Color(0xFF2A2A2A);
  static const Color searchPlaceholder = Color(0xFF606060);
}
