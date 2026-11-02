package com.gazuacup.janggigo;

import android.content.SharedPreferences;
import android.os.RemoteException;
import android.util.Log;

import androidx.annotation.NonNull;

import com.android.installreferrer.api.InstallReferrerClient;
import com.android.installreferrer.api.InstallReferrerStateListener;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    /** 앱의 DeepLinkRepository(lib/repositories/deep_link_repository.dart)와 같은 채널 이름. */
    private static final String INSTALL_REFERRER_CHANNEL = "janggigo/install_referrer";

    private static final String PREFERENCES = "install_referrer";

    /** 설치 정보를 이미 앱에 넘겼다는 기록. 설치 정보는 앱을 지울 때까지 같은 값이 오므로 처음 한 번만 넘긴다. */
    private static final String TAKEN_KEY = "taken";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), INSTALL_REFERRER_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("takeInstallReferrer".equals(call.method)) {
                        takeInstallReferrer(result);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    /**
     * 플레이 스토어 설치 정보(Play Install Referrer)의 referrer를 설치 뒤 처음 한 번만 돌려준다. 초대 링크의 입장 페이지가
     * "앱 설치"에 referrer=room%3D(방 ID)를 붙여 스토어를 열므로, 설치 뒤 처음 켤 때 그 방으로 들어가는 데 쓴다
     * (docs/game/matching.md의 링크). 이미 넘겼거나 읽을 수 없으면 null이다. 플레이 스토어 서비스가 잠깐 안 되면 기록을 남기지
     * 않아 다음에 켤 때 다시 읽는다.
     */
    private void takeInstallReferrer(MethodChannel.Result result) {
        final SharedPreferences preferences = getSharedPreferences(PREFERENCES, MODE_PRIVATE);
        if (preferences.getBoolean(TAKEN_KEY, false)) {
            result.success(null);
            return;
        }
        final InstallReferrerClient client = InstallReferrerClient.newBuilder(this).build();
        client.startConnection(new InstallReferrerStateListener() {
            private boolean replied = false;

            @Override
            public void onInstallReferrerSetupFinished(int responseCode) {
                String referrer = null;
                if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                    try {
                        referrer = client.getInstallReferrer().getInstallReferrer();
                    } catch (RemoteException error) {
                        Log.w("MainActivity", "getInstallReferrer 실패", error);
                    }
                }
                if (responseCode != InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE) {
                    preferences.edit().putBoolean(TAKEN_KEY, true).apply();
                }
                client.endConnection();
                reply(referrer);
            }

            @Override
            public void onInstallReferrerServiceDisconnected() {
                reply(null);
            }

            private void reply(String referrer) {
                if (replied) {
                    return;
                }
                replied = true;
                runOnUiThread(() -> result.success(referrer));
            }
        });
    }
}
