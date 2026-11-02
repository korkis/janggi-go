import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:janggi_core/janggi_core.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../models/active_game.dart';
import '../repositories/app_repositories.dart';
import '../theme/app_theme.dart';
import '../utils/app_exception.dart';
import '../utils/dialog_utils.dart';
import '../utils/game_clock.dart';
import '../utils/rank_format.dart';
import '../widgets/game_scaffold.dart';
import '../widgets/player_bar.dart';
import 'setup_screen.dart';

/// 빠른 대국 대기 화면(`docs/screens.md`의 빠른 대국 대기). 대국 화면과 같은 어두운 바탕을 쓴다.
///
/// 열리면 대기열에 들어가고 "상대 찾는 중"을 보여준다. 대국 서버가 대국을 만들어 `player_states.gameId`가 생기면 "상대 찾음"을
/// 상차림 시작 시각(`setup.startsAt`)까지 보여준 뒤 상차림으로 넘어간다. "그만 찾기"와 뒤로 가기는 대기열에서 나와 홈으로 간다.
class QuickMatchScreen extends StatefulWidget {
  const QuickMatchScreen({super.key});

  @override
  State<QuickMatchScreen> createState() => _QuickMatchScreenState();
}

class _QuickMatchScreenState extends State<QuickMatchScreen> with TickerProviderStateMixin {
  /// 규칙 팁의 개수. `quickMatchTip`의 select 항목 수와 같다.
  static const _tipCount = 5;

  /// 규칙 팁을 바꾸는 간격.
  static const _tipInterval = Duration(seconds: 8);

  late final AnimationController _ripple;
  final _waited = ValueNotifier(Duration.zero);
  final _startedAt = DateTime.now();
  Timer? _ticker;

  // 처음 보여줄 팁. 열 때마다 다른 팁부터 보여준다.
  final _firstTip = Random().nextInt(_tipCount);

  // 찾은 대국. null이면 상대를 찾는 중이다.
  String? _gameId;
  ActiveGame? _game;
  StreamSubscription<ActiveGame?>? _gameSubscription;

  // 상대 찾음 화면에서 상차림까지 남은 시간을 채우는 막대.
  AnimationController? _intro;

  // 그만 찾기를 보내는 중이다.
  var _leaving = false;

  // 상차림으로 넘어가기 시작했다.
  var _opened = false;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    managers.playerStateManager.addListener(_onPlayerStateChanged);
    _join();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRipple();
  }

  @override
  void dispose() {
    managers.playerStateManager.removeListener(_onPlayerStateChanged);
    _ticker?.cancel();
    _gameSubscription?.cancel();
    _ripple.dispose();
    _intro?.dispose();
    _waited.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return GameScaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: _onPopInvoked,
        child: game == null ? _buildSearching(context) : _buildFound(context, game),
      ),
    );
  }

  Widget _buildSearching(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(child: _Ripple(animation: _ripple)),
          const SizedBox(height: 32),
          Text(
            // 상대를 찾고 있어요
            l10n.quickMatchSearching,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800, color: GameColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            // 급수가 비슷한 상대와 바로 시작해요
            l10n.quickMatchSearchingDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<Duration>(valueListenable: _waited, builder: _buildWaited),
          const Spacer(),
          ValueListenableBuilder<Duration>(valueListenable: _waited, builder: _buildTip),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _leaving || _gameId != null ? null : _onStop,
            // 그만 찾기
            child: Text(l10n.quickMatchStop),
          ),
        ],
      ),
    );
  }

  Widget _buildWaited(BuildContext context, Duration waited, Widget? child) {
    return Text(
      formatClock(waited),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: AppTextSizes.title,
        fontWeight: FontWeight.w700,
        color: GameColors.text,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildTip(BuildContext context, Duration waited, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final index = (_firstTip + waited.inSeconds ~/ _tipInterval.inSeconds) % _tipCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // 장기 규칙
            l10n.quickMatchTipTitle,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w800, color: GameColors.accent),
          ),
          const SizedBox(height: 4),
          Text(
            // 초가 먼저 두고, 한은 덤 1.5점을 받아요
            l10n.quickMatchTip('$index'),
            style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.text),
          ),
        ],
      ),
    );
  }

  Widget _buildFound(BuildContext context, ActiveGame game) {
    final l10n = AppLocalizations.of(context);
    final mySide = _getMySide(game);
    final timeControl = game.meta.timeControl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            // 상대를 찾았어요
            l10n.quickMatchFound,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w800, color: GameColors.text),
          ),
          const Spacer(),
          _FoundPlayer(player: game.meta.players.get(mySide.opponent), side: mySide.opponent),
          const SizedBox(height: 16),
          Text(
            // VS
            l10n.quickMatchVersus,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppTextSizes.large, fontWeight: FontWeight.w900, color: GameColors.accent),
          ),
          const SizedBox(height: 16),
          _FoundPlayer(player: game.meta.players.get(mySide), side: mySide),
          const Spacer(),
          Text(
            // 기본 5분 · 초읽기 30초 3회
            l10n.quickMatchTimeRule(
              Duration(milliseconds: timeControl.baseMs).inMinutes,
              Duration(milliseconds: timeControl.periodMs).inSeconds,
              timeControl.periods,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
          ),
          if (game.meta.rated) ...[
            const SizedBox(height: 8),
            Center(
              child: PlayerBadge(
                // 급수 대국
                label: l10n.quickMatchRated,
                color: GameColors.accent,
                background: GameColors.accentSurface,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(animation: _intro ?? _ripple, builder: _buildIntroProgress),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroProgress(BuildContext context, Widget? child) {
    return LinearProgressIndicator(
      value: _intro?.value ?? 0,
      minHeight: 8,
      color: GameColors.accent,
      backgroundColor: GameColors.surface,
    );
  }

  /// 내 진영. 빠른 대국은 서버가 나를 넣어 만든 대국만 보여주므로 내가 대국자가 아니면 초 쪽으로 본다.
  Side _getMySide(ActiveGame game) => game.meta.players.han.uid == managers.authManager.uid ? Side.han : Side.cho;

  void _syncRipple() {
    if (_gameId == null && !MediaQuery.disableAnimationsOf(context)) {
      if (!_ripple.isAnimating) {
        _ripple.repeat();
      }
    } else {
      _ripple.stop();
    }
  }

  void _onTick(Timer timer) {
    _waited.value = DateTime.now().difference(_startedAt);
  }

  Future<void> _join() async {
    try {
      final gameId = await repositories.gameRepository.joinQuickQueue();
      if (gameId != null) {
        _onMatched(gameId);
      }
    } catch (error, stackTrace) {
      developer.log('GameRepository.joinQuickQueue 실패', error: error, stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      // 상대를 찾지 못했어요. 잠시 후 다시 해 주세요
      final message = error is AppException ? error.getMessage(l10n) : l10n.errorQuickMatch;
      await DialogUtils.showMessage(context, message: message);
      if (mounted && _gameId == null) {
        Navigator.of(context).pop();
      }
    }
  }

  void _onPlayerStateChanged() {
    final gameId = managers.playerStateManager.gameId;
    if (gameId != null) {
      _onMatched(gameId);
    }
  }

  /// 대국이 만들어졌다. 대국을 들어 상대 찾음 화면을 보여준다.
  void _onMatched(String gameId) {
    if (_gameId != null || !mounted) {
      return;
    }
    setState(() {
      _gameId = gameId;
    });
    _syncRipple();
    _gameSubscription = repositories.gameRepository.watchGame(gameId).listen(_onGameChanged, onError: _onGameError);
  }

  void _onGameChanged(ActiveGame? game) {
    if (game == null || !mounted) {
      return;
    }
    setState(() {
      _game = game;
    });
    if (_intro != null) {
      return;
    }
    final remaining = game.state.setup.startsAt - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) {
      _openSetup();
      return;
    }
    final intro = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: remaining),
    );
    _intro = intro;
    intro.forward().whenComplete(_openSetup);
  }

  void _onGameError(Object error, StackTrace stackTrace) {
    developer.log('QuickMatchScreen 대국 듣기 실패', error: error, stackTrace: stackTrace);
    _openSetup();
  }

  /// 상차림 화면으로 넘어간다. 상차림 화면이 대국을 다시 듣고 오류도 보여준다.
  void _openSetup() {
    final gameId = _gameId;
    if (_opened || gameId == null || !mounted) {
      return;
    }
    _opened = true;
    Navigator.of(context).pushReplacement(createGameRoute<void>((context) => SetupScreen.online(gameId: gameId)));
  }

  /// 대기열에서 나와 홈으로 간다. 그새 상대를 찾았으면(`busy`) 남아서 대국으로 넘어간다.
  Future<void> _onStop() async {
    try {
      setState(() {
        _leaving = true;
      });
      await repositories.gameRepository.leaveQuickQueue();
      if (mounted && _gameId == null) {
        Navigator.of(context).pop();
      }
    } catch (error, stackTrace) {
      developer.log('GameRepository.leaveQuickQueue 실패', error: error, stackTrace: stackTrace);
      if (error is AppException && error.code == AppErrorCode.gameBusy) {
        return;
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // 그만 찾지 못했어요. 잠시 후 다시 해 주세요
        final message = error is AppException ? error.getMessage(l10n) : l10n.errorLeaveQuickMatch;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _leaving = false;
        });
      }
    }
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop || _leaving || _gameId != null) {
      return;
    }
    _onStop();
  }
}

/// 상대 찾는 중 화면의 가운데. 내 급수 둘레로 물결이 천천히 퍼진다.
class _Ripple extends StatelessWidget {
  final Animation<double> animation;

  const _Ripple({required this.animation});

  static const _size = 200.0;
  static const _coreSize = 96.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: AnimatedBuilder(animation: animation, builder: _buildRipple),
    );
  }

  Widget _buildRipple(BuildContext context, Widget? child) {
    final l10n = AppLocalizations.of(context);
    final rankLevel = managers.rankManager.rankLevel;
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var wave = 0; wave < 3; wave++) _buildWave((animation.value + wave / 3) % 1),
        Container(
          width: _coreSize,
          height: _coreSize,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: GameColors.accentSurface),
          child: rankLevel == null
              ? const Icon(Icons.person, size: 48, color: GameColors.accent)
              : Text(
                  getRankLabel(l10n, rankLevel),
                  style: const TextStyle(
                    fontSize: AppTextSizes.title,
                    fontWeight: FontWeight.w800,
                    color: GameColors.accent,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildWave(double t) {
    final size = _coreSize + (_size - _coreSize) * t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GameColors.accent.withValues(alpha: (1 - t) * 0.6), width: 2),
      ),
    );
  }
}

/// 상대 찾음 화면의 대국자 한 사람. 닉네임, 급수, 진영과 두는 순서를 보여준다.
class _FoundPlayer extends StatelessWidget {
  final GamePlayer player;
  final Side side;

  const _FoundPlayer({required this.player, required this.side});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: GameColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          SideAvatar(side: side, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // {nickname} · {rank}
                  getPlayerName(l10n, player),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppTextSizes.title,
                    fontWeight: FontWeight.w800,
                    color: GameColors.text,
                  ),
                ),
                Text(
                  // 초 · 먼저 둬요 / 한 · 나중에 둬요
                  l10n.quickMatchMoveOrder(side.name),
                  style: const TextStyle(fontSize: AppTextSizes.body, color: GameColors.subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
