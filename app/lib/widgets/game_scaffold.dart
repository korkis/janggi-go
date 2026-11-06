import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'adaptive_layout.dart';
import 'board/board_geometry.dart';
import 'player_bar.dart';

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

/// 대국 화면 계열 맨 위의 제목 줄. 왼쪽에 뒤로 버튼을 둔다. [chip]이 있으면 제목 대신 가운데에 둔다(대국 결과 칩).
class GameHeader extends StatelessWidget {
  final String title;

  /// 없으면 뒤로 버튼을 두지 않는다. 온라인 대국의 상차림부터 대국이 끝날 때까지다(`docs/screens.md`의 대국 화면).
  final VoidCallback? onBack;

  final Widget? chip;

  const GameHeader({super.key, required this.title, required this.onBack, this.chip});

  @override
  Widget build(BuildContext context) {
    final chip = this.chip;
    final onBack = this.onBack;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // 버튼이 없어도 줄 높이와 제목 자리가 그대로이게 같은 크기를 비워 둔다.
          if (onBack == null)
            const SizedBox.square(dimension: minTouchSize)
          else
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, color: GameColors.text),
              // 뒤로
              tooltip: AppLocalizations.of(context).back,
            ),
          Expanded(
            child: chip != null
                ? Center(child: chip)
                : Text(
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

  /// 버튼마다의 폭 비율. 없으면 같은 폭이다. 글자 길이가 다른 버튼이 폭 320에 들어가게 할 때 쓴다.
  final List<int>? flexes;

  const GameButtonBar({super.key, required this.children, this.flexes});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var index = 0; index < children.length; index++)
              Expanded(flex: flexes?[index] ?? 1, child: children[index]),
          ],
        ),
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

  /// 흐리게 보여준다. [onPressed]가 있으면 그대로 누를 수 있다(엽전이 모자란 버튼).
  final bool dimmed;

  /// 아이콘 위에 보여줄 수. 0이면 보여주지 않는다.
  final int badgeCount;

  const GameBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.dimmed = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    var color = GameColors.buttonText;
    if (onPressed == null || dimmed) {
      color = GameColors.inactiveText;
    } else if (emphasized) {
      color = Colors.white;
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchSize, 60),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: emphasized ? GameColors.raisedButton : null,
        foregroundColor: GameColors.buttonText,
        disabledForegroundColor: GameColors.inactiveText,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            largeSize: 18,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            backgroundColor: GameColors.outline,
            textColor: GameColors.text,
            child: Icon(icon, color: color, size: emphasized ? 26 : 24),
          ),
          const SizedBox(height: 2),
          // 큰 글자 설정에서 넘칠 때만 글자를 줄인다(`docs/ui.md`의 터치).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: AppTextSizes.body,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 대국 화면 계열에서 띄우는 창(결과 창, 더보기 등).
///
/// 1024 미만은 아래에서 올리고, 1024 이상은 오른쪽 패널을 뺀 판 영역 가운데에 띄운다(`docs/ui.md`의 넓은 화면).
Future<T?> showGameSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  if (getLayoutSize(context) != LayoutSize.expanded) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: dismissible,
      enableDrag: dismissible,
      isScrollControlled: true,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: GameColors.scrim,
    builder: (context) => _GameSheetDialog(builder: builder),
  );
}

/// 1024 이상에서 판 영역 가운데에 띄우는 창의 틀.
class _GameSheetDialog extends StatelessWidget {
  static const _maxWidth = 440.0;

  final WidgetBuilder builder;

  const _GameSheetDialog({required this.builder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: LayoutWidths.gamePanel),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Material(
              color: GameColors.surface,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1024 이상 대국 화면 계열의 배치(`docs/ui.md`의 넓은 화면).
///
/// 왼쪽 판 영역의 왼쪽 위에 뒤로 버튼을 두고, 그 아래에 정보 줄과 판([boardColumn])을 판 폭에 맞춰 가운데 놓는다.
/// 오른쪽에는 폭 400 패널([panel])을 둔다.
class GameWideLayout extends StatelessWidget {
  /// 없으면 뒤로 버튼을 두지 않는다. [GameHeader.onBack]과 같다.
  final VoidCallback? onBack;

  /// 위 정보 줄, 판, 아래 정보 줄. [BoardColumnBox]로 판과 같은 폭이 된다.
  final Widget boardColumn;

  final Widget panel;

  const GameWideLayout({super.key, required this.onBack, required this.boardColumn, required this.panel});

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                // 버튼이 없어도 판 크기가 그대로이게 같은 크기를 비워 둔다.
                child: onBack == null
                    ? const SizedBox.square(dimension: minTouchSize)
                    : IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_ios_new, color: GameColors.text),
                        // 뒤로
                        tooltip: AppLocalizations.of(context).back,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: BoardColumnBox(child: boardColumn),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: LayoutWidths.gamePanel, child: panel),
      ],
    );
  }
}

/// 정보 줄 두 개와 판이 세로로 놓일 때 판이 남는 높이에 가장 크게 들어가는 폭으로 [child]를 좁혀 가운데 둔다.
/// 정보 줄이 판과 같은 폭이 된다.
class BoardColumnBox extends StatelessWidget {
  final Widget child;

  const BoardColumnBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildBox);
  }

  Widget _buildBox(BuildContext context, BoxConstraints constraints) {
    final boardHeight = max(0.0, constraints.maxHeight - PlayerBar.getEstimatedHeight(context) * 2);
    final width = min(constraints.maxWidth, boardHeight * BoardGeometry.aspectRatio);
    return Center(
      child: SizedBox(width: width, child: child),
    );
  }
}

/// 1024 이상 대국 화면 계열의 오른쪽 패널. 위에 대국 종류와 규칙, 가운데에 화면마다 다른 내용, 아래에 버튼을 둔다.
class GamePanel extends StatelessWidget {
  final String title;

  /// 제목 아래 칩(대국 종류, 급수 대국, 시간 규칙).
  final List<String> details;

  /// 가운데 내용. 없으면 비워 둔다.
  final Widget? body;

  /// 맨 아래 버튼 줄. 없으면 두지 않는다.
  final Widget? buttons;

  /// 제목 아래에 두는 대국 결과 칩. 없으면 두지 않는다.
  final Widget? chip;

  const GamePanel({super.key, required this.title, this.details = const [], this.body, this.buttons, this.chip});

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final buttons = this.buttons;
    final chip = this.chip;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: GameColors.panel,
        border: Border(left: BorderSide(color: GameColors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800, color: GameColors.text),
            ),
            if (chip != null) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: chip)],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final detail in details) _PanelChip(label: detail)]),
            ],
            const SizedBox(height: 20),
            Expanded(child: body ?? const SizedBox.shrink()),
            if (buttons != null) ...[const SizedBox(height: 16), buttons],
          ],
        ),
      ),
    );
  }
}

class _PanelChip extends StatelessWidget {
  final String label;

  const _PanelChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: GameColors.raisedButton, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w600, color: GameColors.buttonText),
      ),
    );
  }
}
