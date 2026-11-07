import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/game_enums.dart';
import '../models/store_item.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/piece_icon.dart';
import 'login_flow.dart';

/// 상점(`docs/screens.md`의 상점). 엽전 충전, 장기알, 광고 제거를 판다.
///
/// 결제는 앱에서만 한다. 웹은 구매 자리에 "앱에서 살 수 있어요"를 둔다. 산 것은 서버가 지급하므로 지갑과 보관함을 듣는 것으로 들어온다.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  /// 로그인과 닉네임 정하기를 거쳐 상점을 연다.
  static Future<void> open(BuildContext context) async {
    final ready = await ensureSignedInWithProfile(context, LoginPurpose.store);
    if (!ready || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: _buildRoute));
  }

  static Widget _buildRoute(BuildContext context) => const StoreScreen();

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  // 장기알 미리보기. 양 진영의 궁, 차, 포를 보여준다.
  static const _previewPieces = [
    Piece(Side.han, PieceType.king),
    Piece(Side.han, PieceType.chariot),
    Piece(Side.cho, PieceType.king),
    Piece(Side.cho, PieceType.cannon),
  ];

  // 결제 창을 띄우고 있거나 복원하고 있어 다른 구매를 막는다.
  var _busy = false;

  @override
  void initState() {
    super.initState();
    managers.storeManager.loadPrices();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppPage(
      layout: PageLayout.wide,
      child: Scaffold(
        appBar: AppBar(
          // 상점
          title: Text(l10n.menuStore),
          actions: [
            ListenableBuilder(listenable: managers.coinManager, builder: _buildBalance),
            const SizedBox(width: 16),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([managers.storeManager, managers.appConfigManager, managers.adManager]),
            builder: _buildList,
          ),
        ),
      ),
    );
  }

  Widget _buildBalance(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final balance = managers.coinManager.balance;
    if (balance == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      // 엽전 330개
      label: l10n.coinBalanceLabel(balance),
      excludeSemantics: true,
      child: Row(
        children: [
          const Icon(Icons.toll, size: 22, color: LightColors.accent),
          const SizedBox(width: 4),
          Text(
            // 330
            l10n.coinBalanceAmount(balance),
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final web = managers.appConfigManager.onWeb;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (managers.adManager.rewardedAdReward != null) ...[
          // 엽전 받기
          _buildSectionTitle(l10n.storeEarnCoinsTitle),
          _buildRewardedAdCard(context),
          const SizedBox(height: 24),
        ],
        if (managers.appConfigManager.coinSaleEnabled) ...[
          // 엽전 충전
          _buildSectionTitle(l10n.storeCoinsTitle),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [for (final item in StoreItem.coinItems) _buildCoinTile(context, item)]),
          ),
          const SizedBox(height: 24),
        ],
        // 장기알
        _buildSectionTitle(l10n.storePiecesTitle),
        for (final material in PieceMaterial.values) ...[
          _buildMaterialCard(context, material),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        // 광고 제거
        _buildSectionTitle(l10n.storeRemoveAdsTitle),
        _buildRemoveAdsCard(context),
        const SizedBox(height: 24),
        Text(
          // 쓰지 않은 엽전과 상품은 결제하고 7일 안에 구글 플레이나 앱스토어에서 환불을 신청할 수 있어요
          l10n.storeWithdrawalNotice,
          style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
        ),
        if (!web) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _onRestore,
              // 구매 복원
              child: Text(l10n.storeRestore),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.w800),
      ),
    );
  }

  /// 보상형 광고 줄. 지갑을 읽기 전에는 남은 횟수를 쓰지 않고 버튼을 끈다.
  Widget _buildRewardedAdCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ads = managers.adManager;
    final left = ads.rewardedAdsLeft;
    String? subtitle;
    if (left != null) {
      // 오늘 3번 남았어요 / 오늘은 다 받았어요
      subtitle = left > 0 ? l10n.storeAdsLeft(left) : l10n.storeAdsDone;
    }
    return Card(
      child: _ProductRow(
        leading: const Icon(Icons.play_circle_outline, color: LightColors.accent),
        // 광고 보고 30엽전 받기
        title: l10n.adRewardAction(ads.rewardedAdReward!),
        subtitle: subtitle,
        trailing: FilledButton(
          onPressed: _busy || !ads.rewardedAdWatchable || ads.rewardedAdShowing ? null : _onWatchRewardedAd,
          // 보기
          child: Text(l10n.storeAdWatch),
        ),
      ),
    );
  }

  Widget _buildCoinTile(BuildContext context, StoreItem item) {
    final l10n = AppLocalizations.of(context);
    return _ProductRow(
      leading: const Icon(Icons.toll, color: LightColors.accent),
      // 300엽전
      title: l10n.storeCoinsAmount(item.coins!),
      trailing: _buildBuyButton(context, item),
    );
  }

  Widget _buildMaterialCard(BuildContext context, PieceMaterial material) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getMaterialName(context, material),
              style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [for (final piece in _previewPieces) PieceIcon(piece: piece, size: 48, material: material)],
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: _buildMaterialAction(context, material)),
          ],
        ),
      ),
    );
  }

  /// 쓰는 중, 쓰기, 또는 구매 자리.
  Widget _buildMaterialAction(BuildContext context, PieceMaterial material) {
    final l10n = AppLocalizations.of(context);
    final store = managers.storeManager;
    if (store.selectedMaterial == material) {
      return Text(
        // 쓰는 중
        l10n.storeMaterialSelected,
        style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700, color: LightColors.accent),
      );
    }
    if (store.isOwned(material)) {
      return OutlinedButton(
        onPressed: () => _onSelectMaterial(material),
        // 쓰기
        child: Text(l10n.storeMaterialSelect),
      );
    }
    final item = StoreItem.values.firstWhere((candidate) => candidate.material == material);
    return _buildBuyButton(context, item);
  }

  Widget _buildRemoveAdsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: _ProductRow(
        // 배너 광고가 나오지 않아요
        title: l10n.storeRemoveAdsDescription,
        trailing: managers.storeManager.adsRemoved
            ? Text(
                // 샀어요
                l10n.storeOwned,
                style: const TextStyle(
                  fontSize: AppTextSizes.body,
                  fontWeight: FontWeight.w700,
                  color: LightColors.accent,
                ),
              )
            : _buildBuyButton(context, StoreItem.removeAds),
      ),
    );
  }

  /// 앱은 가격이 적힌 구매 버튼, 웹은 "앱에서 살 수 있어요"다.
  Widget _buildBuyButton(BuildContext context, StoreItem item) {
    final l10n = AppLocalizations.of(context);
    if (managers.appConfigManager.onWeb) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            // 4,900원
            l10n.storePriceWon(item.priceWon),
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w700),
          ),
          Text(
            // 앱에서 살 수 있어요
            l10n.storeBuyInApp,
            style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
          ),
        ],
      );
    }
    return FilledButton(
      onPressed: _busy ? null : () => _onBuy(item),
      // 4,900원
      child: Text(managers.storeManager.getPrice(item) ?? l10n.storePriceWon(item.priceWon)),
    );
  }

  String _getMaterialName(BuildContext context, PieceMaterial material) {
    final l10n = AppLocalizations.of(context);
    return switch (material) {
      // 기본 장기알
      PieceMaterial.plastic => l10n.storeMaterialPlastic,
      // 나무 장기알
      PieceMaterial.wood => l10n.storeMaterialWood,
      // 알루미늄 장기알
      PieceMaterial.aluminum => l10n.storeMaterialAluminum,
    };
  }

  Future<void> _onWatchRewardedAd() => watchRewardedAd(context);

  Future<void> _onBuy(StoreItem item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() {
        _busy = true;
      });
      await managers.storeManager.purchase(item);
      // 결제했어요. 곧 들어와요
      messenger.showSnackBar(SnackBar(content: Text(l10n.storePurchased)));
    } on AppException catch (error, stackTrace) {
      if (error.code != AppErrorCode.purchaseCanceled) {
        developer.log('StoreManager.purchase 실패', error: error, stackTrace: stackTrace);
        if (mounted) {
          await DialogUtils.showMessage(context, message: error.getMessage(l10n));
        }
      }
    } catch (error, stackTrace) {
      developer.log('StoreManager.purchase 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 결제하지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorPurchase);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _onRestore() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() {
        _busy = true;
      });
      await managers.storeManager.restorePurchases();
      // 구매를 다시 확인했어요
      messenger.showSnackBar(SnackBar(content: Text(l10n.storeRestored)));
    } catch (error, stackTrace) {
      developer.log('StoreManager.restorePurchases 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 구매를 복원하지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorRestorePurchases;
        await DialogUtils.showMessage(context, message: message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _onSelectMaterial(PieceMaterial material) async {
    final l10n = AppLocalizations.of(context);
    try {
      await managers.storeManager.selectMaterial(material);
    } catch (error, stackTrace) {
      developer.log('StoreManager.selectMaterial 실패', error: error, stackTrace: stackTrace);
      if (mounted) {
        // 장기알을 바꾸지 못했어요. 잠시 후 다시 해 주세요
        await DialogUtils.showMessage(context, message: l10n.errorSelectMaterial);
      }
    }
  }
}

/// 상품 한 줄. 오른쪽의 구매 자리가 두 줄이어도 넘치지 않게 내용만큼 높아진다.
class _ProductRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _ProductRow({this.leading, required this.title, this.subtitle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final subtitle = this.subtitle;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 16)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: AppTextSizes.body)),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: AppTextSizes.body, color: LightColors.subText),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// 서버가 거절한 일의 사유를 알린다. 엽전이 모자라서면(`docs/monetization.md`) 광고 버튼과 상점으로 가는 버튼을 붙인다. 충전을 멈췄으면 상점에서
/// 해결할 수 없으므로 상점 버튼을 붙이지 않는다. 광고를 볼 수 없으면(웹, 스위치 꺼짐, 오늘 횟수를 다 썼다) 광고 버튼을 붙이지 않는다. 상점을 열면 닫을 때까지
/// 기다린다.
Future<void> showActionError(BuildContext context, {required Object error, required String fallback}) async {
  final l10n = AppLocalizations.of(context);
  if (error is! AppException) {
    await DialogUtils.showMessage(context, message: fallback);
    return;
  }
  final storeAvailable = managers.appConfigManager.coinSaleEnabled;
  final adAvailable = managers.adManager.rewardedAdWatchable;
  if (error.code != AppErrorCode.coinsInsufficient || (!storeAvailable && !adAvailable)) {
    await DialogUtils.showMessage(context, message: error.getMessage(l10n));
    return;
  }
  final goToStore = await showDialog<bool>(
    context: context,
    builder: (context) => _CoinsInsufficientDialog(storeAvailable: storeAvailable, adAvailable: adAvailable),
  );
  if ((goToStore ?? false) && context.mounted) {
    await StoreScreen.open(context);
  }
}

/// 보상형 광고를 보여준다. 끝까지 보면 곧 들어온다고 알린다. 엽전은 서버가 주고 지갑을 듣는 쪽에 들어온다(`docs/server.md`의 앱 광고).
Future<void> watchRewardedAd(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final reward = managers.adManager.rewardedAdReward;
  if (reward == null) {
    return;
  }
  try {
    await managers.adManager.showRewardedAd();
    // 곧 30엽전이 들어와요
    messenger.showSnackBar(SnackBar(content: Text(l10n.adRewardComing(reward))));
  } catch (error, stackTrace) {
    if (error is AppException && error.code == AppErrorCode.adNotCompleted) {
      return;
    }
    developer.log('AdManager.showRewardedAd 실패', error: error, stackTrace: stackTrace);
    if (context.mounted) {
      // 지금은 광고를 볼 수 없어요. 잠시 후 다시 해 주세요
      final message = error is AppException ? error.getMessage(l10n) : l10n.errorAdUnavailable;
      await DialogUtils.showMessage(context, message: message);
    }
  }
}

/// "엽전이 모자라요" 창. 상점으로 가면 true로 닫는다. 광고를 불러오는 동안 창을 그대로 두어 누른 것이 보이게 한다.
class _CoinsInsufficientDialog extends StatefulWidget {
  final bool storeAvailable;
  final bool adAvailable;

  const _CoinsInsufficientDialog({required this.storeAvailable, required this.adAvailable});

  @override
  State<_CoinsInsufficientDialog> createState() => _CoinsInsufficientDialogState();
}

class _CoinsInsufficientDialogState extends State<_CoinsInsufficientDialog> {
  var _watching = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reward = managers.adManager.rewardedAdReward;
    return PopScope(
      canPop: !_watching,
      child: AlertDialog(
        // 엽전이 모자라요
        content: Text(l10n.errorCoinsInsufficient),
        actions: [
          TextButton(
            onPressed: _watching ? null : _onCancel,
            // 취소
            child: Text(l10n.cancel),
          ),
          if (widget.storeAvailable)
            TextButton(
              onPressed: _watching ? null : _onStore,
              // 상점으로 가기
              child: Text(l10n.storeGo),
            ),
          if (widget.adAvailable && reward != null)
            TextButton(
              onPressed: _watching ? null : _onWatchAd,
              // 광고 보고 30엽전 받기
              child: Text(l10n.adRewardAction(reward)),
            ),
        ],
      ),
    );
  }

  void _onCancel() {
    Navigator.of(context).pop(false);
  }

  void _onStore() {
    Navigator.of(context).pop(true);
  }

  Future<void> _onWatchAd() async {
    final navigator = Navigator.of(context);
    setState(() {
      _watching = true;
    });
    await watchRewardedAd(context);
    if (mounted) {
      setState(() {
        _watching = false;
      });
      navigator.pop(false);
    }
  }
}
