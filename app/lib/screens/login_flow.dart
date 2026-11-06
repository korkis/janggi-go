import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../managers/app_managers.dart';
import '../utils/dialog_utils.dart';
import 'login_sheet.dart';
import 'nickname_screen.dart';

/// 로그인을 띄운 까닭. 로그인 창 제목과 닉네임 정하기의 안내를 하려던 일에 맞춘다(`docs/screens.md`의 로그인).
/// 로그인이 필요한 기능을 만들 때 값을 더한다.
enum LoginPurpose {
  /// 홈 내 카드의 로그인 버튼. 로그인 뒤 이어서 할 일이 없다.
  home,
  quickMatch,
  createRoom,
  lobby,

  /// 초대 링크로 방에 들어간다.
  joinRoom,

  /// 관전 화면에서 관전 채팅을 연다.
  spectateChat,

  /// 내 기보 목록을 연다.
  records,

  /// 내 정보를 연다.
  profile,
}

/// 로그인과 첫 가입의 닉네임 정하기를 거친다. 하려던 일을 이어서 할 수 있으면 true, 사용자가 그만뒀으면 false.
///
/// 로그인이 필요한 기능은 이 함수가 true를 돌려주면 사용자가 다시 누르지 않아도 바로 하려던 일을 한다.
Future<bool> ensureSignedInWithProfile(BuildContext context, LoginPurpose purpose) async {
  final authManager = managers.authManager;
  if (!authManager.signedIn) {
    final signedIn = await LoginSheet.show(context, purpose);
    if (!signedIn || !context.mounted) {
      return false;
    }
  }
  try {
    await authManager.ensureProfileLoaded();
  } catch (error, stackTrace) {
    developer.log('AuthManager.ensureProfileLoaded 실패', error: error, stackTrace: stackTrace);
    if (context.mounted) {
      // 내 정보를 불러오지 못했어요. 잠시 후 다시 해 주세요
      await DialogUtils.showMessage(context, message: AppLocalizations.of(context).errorProfileLoad);
    }
    return false;
  }
  // 남아 있던 로그인이 무효라 로그아웃됐으면 다시 로그인하게 한다.
  if (!authManager.signedIn) {
    if (!context.mounted) {
      return false;
    }
    return ensureSignedInWithProfile(context, purpose);
  }
  if (authManager.profile != null) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  if (!managers.appConfigManager.signupEnabled) {
    // 지금은 새로 가입할 수 없어요
    await DialogUtils.showMessage(context, message: AppLocalizations.of(context).errorSignupDisabled);
    await authManager.signOut();
    return false;
  }
  final created = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (context) => NicknameScreen(purpose: purpose)));
  return created == true;
}
