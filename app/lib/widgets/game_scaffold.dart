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
