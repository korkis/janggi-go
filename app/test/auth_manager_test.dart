import 'package:flutter_test/flutter_test.dart';
import 'package:janggigo/managers/app_managers.dart';

import 'fakes.dart';

void main() {
  test('프로필 읽기가 실패했는데 남은 로그인이 무효면 로그아웃한다', () async {
    final fakes = setUpFakeApp();
    // 웹이 브라우저에 남겨 둔 지난 로그인으로 열었는데 계정이 지워졌거나 토큰이 무효가 된 경우다.
    fakes.auth.signInValid = false;
    fakes.users.nextGetUserError = Exception('permission-denied');
    await managers.authManager.signInWithEmail(email: 'me', password: 'password');

    expect(managers.authManager.signedIn, isFalse);
    expect(fakes.auth.currentUid, isNull);
  });

  test('프로필 읽기가 실패해도 로그인이 유효하면(네트워크 오류 등) 로그인을 두고 오류를 던진다', () async {
    final fakes = setUpFakeApp();
    fakes.users.nextGetUserError = Exception('unavailable');
    await expectLater(managers.authManager.signInWithEmail(email: 'me', password: 'password'), throwsException);

    expect(managers.authManager.signedIn, isTrue);
    expect(fakes.auth.currentUid, 'me');
  });
}
