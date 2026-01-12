import 'package:flutter/material.dart';
import 'package:pos_coffeeshop_ayudian/core/pos_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pos_coffeeshop_ayudian/services/printer_service.dart';
import 'package:pos_coffeeshop_ayudian/services/bt_permission.dart';
import '../core/notifier.dart';
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user;
  late Future<PrinterSettings> _printerFuture;
  bool _connected = false;
  bool _testingPrint = false;

  @override
  void initState() {
    super.initState();
    user = Supabase.instance.client.auth.currentUser;
    _printerFuture = PrinterService.loadSettings();
    _refreshPrinter();
  }

  Future<void> _refreshPrinter() async {
    _printerFuture = PrinterService.loadSettings();
    try {
      _connected = await PrinterService.isConnected();
    } catch (_) {
      _connected = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickPrinter() async {
    try {
      final okPerm = await BtPermission.ensureForPairedList();
      if (!okPerm) {
        // Jika user deny permanen, arahkan ke settings.
        await BtPermission.openSettingsIfPermanentlyDenied();
        if (!mounted) return;
        notify(
          context,
          'Izin Bluetooth/Nearby devices belum diizinkan. Buka App Settings lalu izinkan.',
          error: true,
        );
        return;
      }

      final devices = await PrinterService.pairedDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        notify(context, 'Tidak ada printer bluetooth yang ter-pair. Pair dulu di Bluetooth HP.', error: true);
        return;
      }

      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.print_rounded),
                      SizedBox(width: 10),
                      Text('Pilih Printer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...devices.map((d) {
                    final name = (d.name ?? '').trim().isEmpty ? 'Unknown' : d.name!;
                    final mac = d.macAdress ?? '';
                    return ListTile(
                      leading: const Icon(Icons.bluetooth_rounded),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(mac, style: const TextStyle(fontWeight: FontWeight.w700, color: PosTokens.subtext)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await PrinterService.saveDevice(name: name, mac: mac);
                        await _refreshPrinter();
                        notify(context, 'Printer dipilih: $name');
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) notify(context, e.toString(), error: true);
    }
  }

  Future<void> _clearPrinter() async {
    await PrinterService.clearDevice();
    await _refreshPrinter();
    if (mounted) notify(context, 'Printer dihapus');
  }

  Future<void> _testPrint() async {
    if (_testingPrint) return;
    setState(() => _testingPrint = true);
    try {
      await PrinterService.testPrint();
      await _refreshPrinter();
      if (mounted) notify(context, 'Test print terkirim');
    } catch (e) {
      if (mounted) notify(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _testingPrint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const PosBackground(
        child: Scaffold(body: Center(child: Text('Session tidak ditemukan'))),
      );
    }

    final role = user!.userMetadata?['role'] ?? 'kasir';
    final email = user!.email ?? '-';

    return Scaffold(
      body: PosBackground(
        child: SafeArea(
          child: PosSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PosHeaderBar(title: 'Activity', crumb: 'Profile'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: PosTokens.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDAE6FF)),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: PosTokens.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (user!.userMetadata?['name'] ?? 'User')
                                  .toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: PosTokens.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: PosTokens.subtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF0FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFBBD0FF)),
                        ),
                        child: Text(
                          role.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2F6BFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),


const SizedBox(height: 12),
FutureBuilder<PrinterSettings>(
  future: _printerFuture,
  builder: (context, snap) {
    final s = snap.data ?? const PrinterSettings(name: null, mac: null, paperMm: 58);
    final label = (s.name == null || (s.name ?? '').trim().isEmpty) ? 'Belum dipilih' : s.name!;
    final mac = (s.mac ?? '').trim();
    final paper = s.paperMm;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.print_rounded, color: PosTokens.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Printer Settings',
                  style: TextStyle(fontWeight: FontWeight.w900, color: PosTokens.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_connected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (_connected ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5)),
                  ),
                ),
                child: Text(
                  _connected ? 'Connected' : 'Not connected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _connected ? const Color(0xFF166534) : const Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      mac.isEmpty ? '-' : mac,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: PosTokens.subtext),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickPrinter,
                icon: const Icon(Icons.bluetooth_searching_rounded),
                label: const Text('Pilih'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(
                width: 110,
                child: Text('Paper', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              DropdownButton<int>(
                value: paper == 80 ? 80 : 58,
                items: const [
                  DropdownMenuItem(value: 58, child: Text('58 mm')),
                  DropdownMenuItem(value: 80, child: Text('80 mm')),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await PrinterService.savePaperMm(v);
                  await _refreshPrinter();
                },
              ),
              const Spacer(),
              if (mac.isNotEmpty)
                TextButton(
                  onPressed: _clearPrinter,
                  child: const Text('Hapus'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Catatan: Pair printer dulu di Bluetooth HP. Print tersedia di Transaction Detail (status PAID).',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: PosTokens.subtext),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: (mac.isEmpty || _testingPrint) ? null : _testPrint,
              icon: _testingPrint
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print_rounded),
              label: Text(_testingPrint ? 'Testing...' : 'Test Print'),
            ),
          ),
        ],
      ),
    );
  },
),

                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444), // merah
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (_) => false,
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
