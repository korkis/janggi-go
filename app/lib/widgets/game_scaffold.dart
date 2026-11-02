import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// 대국 화면 계열(상차림, 대국)로 가는 경로.
///
/// 화면이 띄우는 창과 확인 창도 어두운 테마를 쓰도록 화면 바깥인 경로에 테마를 씌운다.
MaterialPageRoute<T> createGameRoute<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    builder: (context) => Theme(
      data: gameTheme,
      child: Builder(builder: builder),
    ),
  );
}

/// 대국 화면 계열의 어두운 바탕 화면 틀. [createGameRoute]로 연 경로 안에서 쓴다.
class GameScaffold extends StatelessWidget {
  final Widget body;

  const GameScaffold({super.key, required this.body});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: GameColors.background,
        body: SafeArea(child: body),
      ),
    );
  }
}

/// 대국 화면 계열 맨 위의 제목 줄. 왼쪽에 뒤로 버튼을 둔다.
class GameHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const GameHeader({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: GameColors.text),
            // 뒤로
            tooltip: AppLocalizations.of(context).back,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppTextSizes.body,
                fontWeight: FontWeight.w700,
                color: GameColors.subText,
              ),
            ),
          ),
          const SizedBox(width: minTouchSize),
        ],
      ),
    );
  }
}

/// 대국 화면 계열 아래쪽 버튼 줄. 테두리 있는 상자로 나누지 않고 한 줄 막대 안에 버튼을 담는다.
class GameButtonBar extends StatelessWidget {
  final List<Widget> children;

  const GameButtonBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(children: [for (final child in children) Expanded(child: child)]),
      ),
    );
  }
}

/// [GameButtonBar] 안의 아이콘과 글자 버튼. [emphasized]면 바탕을 깔아 자주 쓰는 버튼을 드러낸다.
class GameBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  const GameBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    var color = GameColors.buttonText;
    if (onPressed == null) {
      color = GameColors.inactiveText;
    } else if (emphasized) {
      color = Colors.white;
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchSize, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: emphasized ? GameColors.raisedButton : null,
        foregroundColor: GameColors.buttonText,
        disabledForegroundColor: GameColors.inactiveText,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: emphasized ? 26 : 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTextSizes.body,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
