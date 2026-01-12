import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper permission Bluetooth untuk Android (terutama Android 12+).
///
/// Catatan:
/// - Pairing di Settings TIDAK otomatis memberi izin ke aplikasi.
/// - Android 12+ (SDK 31+) wajib runtime permission: BLUETOOTH_CONNECT (+ SCAN untuk beberapa device).
class BtPermission {
  static Future<int?> _androidSdk() async {
    if (!Platform.isAndroid) return null;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  static Future<bool> ensureForPairedList() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _androidSdk() ?? 0;

    if (sdk >= 31) {
      final r = await [
        Permission.bluetoothConnect,
        // Sebagian ROM butuh ini walau hanya ambil bonded list.
        Permission.bluetoothScan,
      ].request();
      return (r[Permission.bluetoothConnect]?.isGranted ?? false) &&
          (r[Permission.bluetoothScan]?.isGranted ?? false);
    }

    // Android <= 11: beberapa plugin butuh location untuk discovery.
    final r = await [
      Permission.location,
      Permission.bluetooth,
    ].request();
    final locOk = r[Permission.location]?.isGranted ?? true;
    final btOk = r[Permission.bluetooth]?.isGranted ?? true;
    return locOk && btOk;
  }

  static Future<bool> ensureForConnectAndPrint() async {
    // sama saja dengan ensureForPairedList, tapi dipisah untuk readability.
    return ensureForPairedList();
  }

  static Future<bool> isDeniedPermanently() async {
    if (!Platform.isAndroid) return false;
    final sdk = await _androidSdk() ?? 0;
    if (sdk >= 31) {
      final s1 = await Permission.bluetoothConnect.status;
      final s2 = await Permission.bluetoothScan.status;
      return s1.isPermanentlyDenied || s2.isPermanentlyDenied;
    }
    final s = await Permission.location.status;
    return s.isPermanentlyDenied;
  }

  static Future<void> openSettingsIfPermanentlyDenied() async {
    if (await isDeniedPermanently()) {
      await openAppSettings();
    }
  }
}
