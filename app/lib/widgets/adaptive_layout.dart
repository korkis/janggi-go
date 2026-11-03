import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/lobby_screen.dart';
import '../theme/app_theme.dart';

/// 화면 폭에 따른 배치 구간(`docs/ui.md`의 넓은 화면). 폭은 앱 창의 논리 픽셀이다.
enum LayoutSize {
  /// 600 미만. 휴대폰. 지금 화면 그대로 쓴다.
  compact,

  /// 600~1023. 태블릿과 좁은 창. 일반 화면은 가운데로 모으고, 대국 화면은 판만 키운다.
  medium,

  /// 1024 이상. 데스크탑. 일반 화면은 왼쪽 메뉴를 두고, 대국 화면은 오른쪽 패널을 둔다.
  expanded,
}

/// 배치에 쓰는 폭(`docs/ui.md`의 넓은 화면).
abstract final class LayoutWidths {
  static const mediumMin = 600.0;
  static const expandedMin = 1024.0;

  /// 600~1023에서 일반 화면을 모으는 폭.
  static const mediumContent = 480.0;

  /// 1024 이상에서 왼쪽 메뉴를 뺀 일반 화면 내용의 최대 폭.
  static const expandedContent = 1040.0;

  static const sideMenu = 240.0;

  /// 1024 이상에서 입력 화면을 담는 카드의 폭.
  static const formCard = 480.0;

  /// 1024 이상 홈의 왼쪽 칸 폭.
  static const homeLeftColumn = 380.0;

  /// 1024 이상 대국 화면의 오른쪽 패널 폭.
  static const gamePanel = 400.0;
}

/// 지금 창 폭의 배치 구간. 창 크기가 바뀌면 이 값을 쓴 위젯이 다시 그려진다.
LayoutSize getLayoutSize(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= LayoutWidths.expandedMin) {
    return LayoutSize.expanded;
  }
  if (width >= LayoutWidths.mediumMin) {
    return LayoutSize.medium;
  }
  return LayoutSize.compact;
}

/// 일반 화면의 넓은 화면 배치 종류.
enum PageLayout {
  /// 홈과 목록. 1024 이상에서 내용을 폭 최대 1040으로 넓게 쓴다.
  wide,

  /// 입력 화면(로그인, 닉네임, 방 만들기 등). 1024 이상에서 가운데 폭 480 카드에 담는다.
  form,
}

/// 왼쪽 메뉴의 항목. 화면이 생긴 메뉴만 둔다.
enum AppMenu { home, lobby }

/// 일반 화면(밝은 화면)의 폭별 틀. 화면의 [Scaffold]를 [child]로 받는다.
///
/// 600 미만은 [child]를 그대로, 600~1023은 가운데 폭 480으로 모으고, 1024 이상은 왼쪽 메뉴를 두고 [layout]에 따라 내용을
/// 넓게 쓰거나 가운데 카드에 담는다. 창 크기가 바뀌어도 [child]의 상태가 남도록 구간마다 같은 위젯 구조를 쓴다.
class AppPage extends StatelessWidget {
  /// 왼쪽 메뉴에서 고른 것으로 보여줄 항목. 메뉴에 없는 화면이면 null이다.
  final AppMenu? menu;

  final PageLayout layout;
  final Widget child;

  const AppPage({super.key, this.menu, required this.layout, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = getLayoutSize(context);
    final expanded = size == LayoutSize.expanded;
    final card = expanded && layout == PageLayout.form;
    var maxWidth = double.infinity;
    if (size == LayoutSize.medium) {
      maxWidth = LayoutWidths.mediumContent;
    } else if (card) {
      maxWidth = LayoutWidths.formCard;
    } else if (expanded) {
      maxWidth = LayoutWidths.expandedContent;
    }
    final theme = Theme.of(context);
    var pageTheme = theme;
    if (card) {
      // 카드 안은 흰 바탕이므로 안쪽 카드는 회색으로 뒤집어 구분한다.
      pageTheme = theme.copyWith(
        scaffoldBackgroundColor: LightColors.surface,
        cardTheme: theme.cardTheme.copyWith(color: LightColors.background),
      );
    } else if (expanded) {
      // 내용 폭만큼만 흰 띠가 생기지 않게 제목 줄을 바탕과 같은 색으로 둔다.
      pageTheme = theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: LightColors.background,
          surfaceTintColor: Colors.transparent,
        ),
      );
    }
    return ColoredBox(
      color: LightColors.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expanded) SideMenu(selected: menu),
          Expanded(
            child: Center(
              child: Padding(
                padding: card ? const EdgeInsets.all(32) : EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: card ? 820 : double.infinity),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(card ? 24 : 0),
                    child: Theme(data: pageTheme, child: child),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 전환. 1024 이상은 왼쪽 메뉴가 화면과 같이 움직이지 않도록 새 화면을 겹쳐 나타내기만 하고, 그 밖에는 플랫폼 기본 전환을 쓴다.
class AdaptivePageTransitionsBuilder extends PageTransitionsBuilder {
  const AdaptivePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (getLayoutSize(context) == LayoutSize.expanded) {
      return FadeTransition(opacity: animation, child: child);
    }
    return const PageTransitionsTheme().buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}

/// 1024 이상 일반 화면의 왼쪽 메뉴(`docs/ui.md`의 넓은 화면). 아래 탭 줄 대신 쓴다.
class SideMenu extends StatelessWidget {
  final AppMenu? selected;

  const SideMenu({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: LightColors.surface,
      child: Container(
        width: LayoutWidths.sideMenu,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: LightColors.outline)),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Text(
                  // 장기고
                  l10n.appTitle,
                  style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800),
                ),
              ),
              _SideMenuItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                // 홈
                label: l10n.menuHome,
                selected: selected == AppMenu.home,
                onTap: () => _onSelect(context, AppMenu.home),
              ),
              _SideMenuItem(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                // 대국실
                label: l10n.lobbyTitle,
                selected: selected == AppMenu.lobby,
                onTap: () => _onSelect(context, AppMenu.lobby),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 메뉴 화면은 처음 화면(홈) 위에 하나만 쌓는다. 지금 화면을 다시 누르면 그대로 둔다.
  Future<void> _onSelect(BuildContext context, AppMenu menu) async {
    if (menu == selected) {
      return;
    }
    switch (menu) {
      case AppMenu.home:
        Navigator.of(context).popUntil(_isFirstRoute);
      case AppMenu.lobby:
        await LobbyScreen.open(context);
    }
  }

  static bool _isFirstRoute(Route<dynamic> route) => route.isFirst;
}

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideMenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? LightColors.accent : LightColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? LightColors.accentSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          hoverColor: selected ? null : LightColors.mutedSurface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(selected ? selectedIcon : icon, color: color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTextSizes.body,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
