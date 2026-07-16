// PENTING: File ini adalah PLACEHOLDER dan TIDAK akan berfungsi apa adanya.
//
// Firebase mewajibkan kredensial (apiKey, appId, messagingSenderId, projectId,
// dll) yang unik per project & tidak bisa saya buatkan dari sini karena saya
// tidak punya akses ke Firebase Console project kamu ("smart-turbin").
//
// CARA GENERATE FILE INI YANG BENAR (jalankan di komputermu, sekali saja):
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure --project=smart-turbin
//      (pilih platform Android/iOS yang kamu pakai saat diminta)
//   3. Perintah itu otomatis MENIMPA file ini dengan kredensial asli project
//      "smart-turbin" kamu, dan juga menaruh google-services.json di
//      android/app/ secara otomatis.
//
// databaseURL di bawah sudah saya isikan sesuai yang kamu berikan supaya
// jelas ke mana RTDB harus menunjuk -- tapi field lain (apiKey dst) HARUS
// diganti hasil flutterfire configure, bukan dipakai seperti ini.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Jalankan flutterfire configure untuk menambahkan opsi Web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions belum dikonfigurasi untuk platform ini.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyARWxBHI7Gz2RWSPC_c6kRrxqw30wOY3dw',
    appId: '1:835039149527:android:5c95e0fe173b4ec4f71f92',
    messagingSenderId: '835039149527',
    projectId: 'smart-turbin',
    databaseURL: 'https://smart-turbin-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'smart-turbin.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDktau3tMgm3Tw-JstrB-KKsTRgCGM-hCQ',
    appId: '1:835039149527:ios:092f50c84ef20bc9f71f92',
    messagingSenderId: '835039149527',
    projectId: 'smart-turbin',
    databaseURL: 'https://smart-turbin-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'smart-turbin.firebasestorage.app',
    iosBundleId: 'com.example.smartTurbinApp',
  );
}
