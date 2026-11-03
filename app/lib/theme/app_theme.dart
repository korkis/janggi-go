import 'package:flutter/material.dart';

import '../widgets/adaptive_layout.dart';

/// 일반 화면(밝은 화면)의 색. 기준은 `docs/ui.md`의 디자인 방향이다.
abstract final class LightColors {
  static const background = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF15171A);
  static const subText = Color(0xFF5A6069);
  static const accent = Color(0xFF1E6A4E);

  /// 입력칸과 흰 버튼의 테두리.
  static const outline = Color(0xFFD5D9DF);

  /// 바탕보다 조금 진한 회색 면. 이메일 로그인 버튼 등.
  static const mutedSurface = Color(0xFFF0F2F4);

  /// 접장기 표시. 방 조건 칩에서 다른 조건보다 눈에 띄게 한다(`docs/screens.md`의 대국실).
  static const handicap = Color(0xFFA4471F);
  static const handicapSurface = Color(0xFFFBE9DF);

  /// 방 조건 칩 같은 강조색 면.
  static const accentSurface = Color(0xFFE3F1EA);
}

/// 대국 화면(어두운 화면)의 색. 기준은 `docs/ui.md`의 디자인 방향이고, 표에 없는 색은 시안을 따른다.
abstract final class GameColors {
  static const background = Color(0xFF101216);
  static const surface = Color(0xFF1B1E24);
  static const text = Color(0xFFF2F0EB);
  static const subText = Color(0xFF9AA1AC);
  static const accent = Color(0xFF4CC79A);

  /// 강조색 버튼 위의 글자.
  static const onAccent = Color(0xFF0B2A1F);

  /// 고른 상차림 버튼 등 강조색이 옅게 깔리는 면.
  static const accentSurface = Color(0xFF1F3B30);

  /// 차례가 아닌 쪽의 큰 숫자.
  static const inactiveText = Color(0xFF6E7581);
  static const buttonText = Color(0xFFE4E6EA);
  static const outline = Color(0xFF3A3F48);
  static const raisedButton = Color(0xFF262A31);

  /// 결과 창 등을 띄울 때 뒤에 깔리는 판을 어둡게 하는 막.
  static const scrim = Color(0x9908090C);

  /// 결과 창의 승리 표시. 판의 금빛 표시와 같은 색 계열이다.
  static const gold = Color(0xFFFFD678);
  static const goldSurface = Color(0xFF3A3220);
  static const goldGlow = Color(0x55FFD678);

  /// 장군 알림. 빨강·파랑은 한·초의 색이라 쓰지 않는다.
  static const check = Color(0xFFFFC65C);

  static const hanAvatar = Color(0xFF2E1C1B);
  static const hanAvatarText = Color(0xFFF08B7E);
  static const choAvatar = Color(0xFF17273B);
  static const choAvatarText = Color(0xFF8DB6F0);
}

/// 글자 크기. 본문은 18sp 이상이다(`docs/ui.md`의 글자).
abstract final class AppTextSizes {
  static const body = 18.0;
  static const title = 20.0;
  static const large = 26.0;
  static const headline = 40.0;
}

/// 누르는 영역의 최소 크기(`docs/ui.md`의 터치).
const double minTouchSize = 48;

/// 홈 등 일반 화면의 밝은 테마.
final lightTheme = _buildLightTheme();

/// 대국 화면과 대국 화면에서 띄우는 창의 어두운 테마.
final gameTheme = _buildGameTheme();

ThemeData _buildLightTheme() => _buildTheme(
  brightness: Brightness.light,
  background: LightColors.background,
  surface: LightColors.surface,
  text: LightColors.text,
  subText: LightColors.subText,
  accent: LightColors.accent,
  onAccent: Colors.white,
);

ThemeData _buildGameTheme() => _buildTheme(
  brightness: Brightness.dark,
  background: GameColors.background,
  surface: GameColors.surface,
  text: GameColors.text,
  subText: GameColors.subText,
  accent: GameColors.accent,
  onAccent: GameColors.onAccent,
);

ThemeData _buildTheme({
  required Brightness brightness,
  required Color background,
  required Color surface,
  required Color text,
  required Color subText,
  required Color accent,
  required Color onAccent,
}) {
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    secondary: accent,
    onSecondary: onAccent,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: subText,
  );
  final base = ThemeData(brightness: brightness, colorScheme: colorScheme, useMaterial3: true);
  final textTheme = base.textTheme
      .copyWith(
        headlineMedium: const TextStyle(fontSize: AppTextSizes.headline, fontWeight: FontWeight.w800),
        titleLarge: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
        titleMedium: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
        bodyLarge: const TextStyle(fontSize: AppTextSizes.body),
        bodyMedium: const TextStyle(fontSize: AppTextSizes.body),
        bodySmall: const TextStyle(fontSize: AppTextSizes.body),
        labelLarge: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
        labelMedium: const TextStyle(fontSize: AppTextSizes.body),
        labelSmall: const TextStyle(fontSize: AppTextSizes.body),
      )
      .apply(bodyColor: text, displayColor: text);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const buttonMinimumSize = Size(minTouchSize, 56);
  return base.copyWith(
    scaffoldBackgroundColor: background,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final platform in TargetPlatform.values) platform: AdaptivePageTransitionsBuilder()},
    ),
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonMinimumSize,
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonMinimumSize,
        shape: buttonShape,
        foregroundColor: brightness == Brightness.dark ? GameColors.buttonText : text,
        side: BorderSide(color: brightness == Brightness.dark ? GameColors.outline : subText, width: 1.5),
        textStyle: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchSize, minTouchSize),
        textStyle: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(minTouchSize, minTouchSize)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBarrierColor: brightness == Brightness.dark ? GameColors.scrim : null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      contentTextStyle: TextStyle(fontSize: AppTextSizes.body, color: text, height: 1.4),
    ),
  );
}
