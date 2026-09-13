# Helyi Android-build: letöltési és builder-vizsgálat

Ellenőrzés: 2026-09-13T13:50:17.249Z. APK ezen a lépésen **nem készült**.

## Ténylegesen elvégzett munka

Négy verzióhoz kötött natív könyvtár POM/AAR fájlja letöltve a Google Mavenből, illetve a RevenueCat Maven Central-bejegyzéséből. A tárhely által közölt SHA-1 egyezett a letöltött archívuméval; külön SHA-256 is rögzítve. Ez sértetlenségi ellenőrzés, nem független biztonsági audit.

| Könyvtár | Méret | Tárhelyi SHA-1 |
|---|---:|---|
| com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.3.1 | 5.45 MiB | egyezik |
| com.google.android.gms:play-services-ads:25.4.0 | 5.56 MiB | egyezik |
| com.google.android.ump:user-messaging-platform:4.0.0 | 0.39 MiB | egyezik |
| com.revenuecat.purchases:purchases-hybrid-common:18.37.0 | 0.16 MiB | egyezik |

Helyi fájlok: .tools/native-sdk-probe/ (Gitből kizárva). Újrafuttatható letöltési próba: node tool/native-sdk-probe.mjs. A próba nem telepíti a fájlokat és nem oldja fel a teljes tranzitív függőségi gráfot.

## Miért nem elég bemásolni őket?

A telepített kliens diagnosztikája: 0.28.39-experimental / build 77. A rendelkezésre álló FlutterAndroid.java és FlutterBuilder.java forrás, valamint a tényleges buildhiba alapján:

1. A Flutter-build előre csomagolt SDK-koordinátákhoz ellenőrzi a függőségeket; nem használ általános Maven-letöltést.
2. A Flutter-build ág nem veszi fel a projekt libs/ könyvtárát. A Java/Kotlin-only builder képessége itt nem alkalmazható automatikusan.
3. Az ellenőrzés mindkét feltételes AdMob-ágat látja. A plugin alapértelmezett ága play-services-ads; a Next-Gen alternatíva, nem szükséges mindkettőt egy végső appba csomagolni.
4. A plugin src/playServices és src/adsNextGenSdk forrás-/erőforrásválasztását is támogatni kell; csak src/main nem elég.
5. A letöltött AAR-ok osztályait, erőforrásait, manifestjeit és tranzitív függőségeit ténylegesen csomagolni kell. Egy koordináta felvétele az engedélyezett listába vagy egy JAR puszta compile-classpath felvétele nem hozza létre a futtatható SDK-t.
6. Nem csak AdMob érintett. A jelenlegi ellenőrzés hiányokat/változókat talált ezeknél: google_mobile_ads, photo_manager, purchases_flutter, url_launcher_android, video_player_android, webview_flutter_android. A változókat tartalmazó koordináták nem tényleges Maven-címek; a buildkonfiguráció értelmezése is szükséges.

## Valódi helyi megoldás

A Pocket Codex fordítórészének külön, tesztelt bővítése kell: projektszintű, verziózott dependency lock; hivatalos Maven/POM/metadata feloldás és cache; tranzitív verzió-/variánskezelés; biztonságos AAR-kibontás; manifest/erőforrás/R-osztály kezelés; kiválasztott source set; megfelelő Android API; D8 programfüggőségek és a meglévő Flutter-shell osztályütközéseinek kezelése. Utána valódi APK-fordítás és készülékes pluginpróbák.

Ez nem a reklám/fizetés kivétele, és nem a globális SDK vagy Pub-cache ellenőrizetlen módosítása. A builder forrását és a telepített kliens SDK-ját e vizsgálatban nem módosítottam. A kliens frissítésének telepítését a felhasználónak kell kezdeményeznie; Android közben leállítja az appot, ezért futó feladatok mellett nem telepítünk.

A másik út teljes Android SDK-s távoli build (például GitHub Actions). Ebben a vizsgálatban nem történt push, workflow-indítás vagy forrásfeltöltés. iOS-archiválás továbbra is külön Xcode-környezetet igényel.

## Rögzített SHA-256 összegek

- ads-mobile-sdk-1.3.1.aar: `7c0c8ce659bbd9b290432ae2864a880177c228e8be1d645cf752c2292f4ca6c6`
- play-services-ads-25.4.0.aar: `fc18d3cde6dec8c927cac5048b2dfff1fbe377a15474805a643b723d1e850219`
- user-messaging-platform-4.0.0.aar: `429889c7108caf88207d5d078e8fa7655a0ec6aca718399f27455bebe5978621`
- purchases-hybrid-common-18.37.0.aar: `96f30f6fb6576ee8c93e00fb3c0c087f1b6e2d70e05074ec9d928c2c8e9fe996`

## Hivatalos háttér

- [Google Mobile Ads Flutter-telepítés](https://developers.google.com/admob/flutter/quick-start)
- [Google Next-Gen Android SDK és Maven-repository beállítás](https://developers.google.com/admob/android/next-gen/quick-start)

A konkrét függőségeket a Pub által letöltött google_mobile_ads 9.1.0 és purchases_flutter 10.12.0 build.gradle fájljaiból ellenőriztem.


## 2026-09-13 – Elkészült Android APK

- SpaceMaker **1.1.0 (3)**, `app.spacemaker.swipe`, ARM64, minSdk 24 / targetSdk 36.
- 140 natív JAR/AAR, 8 teljesen újrafordított DEX; Dart ARM64 AOT.
- A v78 appból induló Node linkerútvonala hiányzott. Ugyanaz a telepített builder külön, azonos UID-jű helyi folyamatban kapta meg a helyes környezetet.
- A csomagoláshoz a Flutter platformfüggő asset-deklarációit is kezelni kellett: a RevenueCat webes állományai Androidon nem csomagolandók. Függőséget/funkciót nem cseréltünk le.
- Az alkalmazásmanifest singleton-összevonása javítva; pontosan egy application, SpaceMaker címkével és ikonnal. A relinkelt resources.arsc bájtpontosan változatlan, a natív R osztályok érvényesek.
- A Pocket Codex forrásjavításai elkészültek és Java-fordításon átmentek; **nem részei a korábban kiadott v78 APK-nak**.
- A végleges APK aláírás-ellenőrzése, 13 natív kapcsolódási ellenőrzés, 6 projektellenőrzés és csomagtartalom-ellenőrzés sikeres.
- A hibás köztes jelölt nincs a kiosztható APK-k között; helyi diagnosztikai mappában maradt.
- Nincs automatikus telepítés vagy push. Galéria, videó, reklám és vásárlás élő készülékes tesztje még szükséges; ez nem éles monetizációs kiadás.

APK: `spacemaker--1.1.0-v3--5b42a9ae.apk`

SHA-256: `5b42a9ae882c8f3c62ec5c365090d619e5f34a4ee3836ae4a10269b83fb542ce`

Platform asset referencia: https://docs.flutter.dev/tools/pubspec#assets
