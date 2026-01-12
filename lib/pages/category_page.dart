import 'package:flutter/material.dart';
import '../services/categorie_service.dart';
import '../core/notifier.dart';
import '../core/pos_ui.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List> categories;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void load() {
    categories = CategoryService.getCategories();
  }

  void _openAdd() {
    _openSheet();
  }

  void _openEdit(Map c) {
    _openSheet(category: c);
  }

  void _openSheet({Map? category}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        category: category,
        onSaved: () {
          Navigator.pop(context);
          setState(load);
        },
      ),
    );
  }

  Future<void> _confirmDelete(Map c) async {
    final id = c['id'];
    final name = (c['name'] ?? '-').toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus kategori?'),
          content: Text('Kategori "$name" akan dihapus permanen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('BATAL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('HAPUS'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      // Pastikan service kamu punya method ini:
      // static Future<void> deleteCategory(dynamic id)
      await CategoryService.deleteCategory(id);
      if (!mounted) return;
      notify(context, 'Kategori dihapus');
      setState(load);
    } catch (e) {
      if (!mounted) return;
      notify(context, 'Gagal hapus kategori', error: true);
    }
  }

  List<Map> _filter(List raw) {
    final q = _query.trim().toLowerCase();
    final items = raw.map((e) => Map.from(e as Map)).toList();

    if (q.isEmpty) return items;

    return items.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final id = (c['id'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PosBackground(
        child: SafeArea(
          child: PosSurface(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosHeaderBar(
                  title: 'Activity',
                  crumb: 'Categories',
                  actions: [
                    PosIconCircleButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Tambah kategori',
                      onPressed: _openAdd,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search bar modern + clear button
                _SearchBar(
                  controller: _searchCtrl,
                  hint: 'Cari kategori (nama / id)...',
                  onChanged: (v) => setState(() => _query = v),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: FutureBuilder(
                    future: categories,
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const _LoadingSkeleton();
                      }
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }

                      final raw = (snap.data as List?) ?? [];
                      final data = _filter(raw);

                      if (raw.isEmpty) {
                        return _EmptyState(
                          title: 'Belum ada kategori',
                          subtitle: 'Tambah kategori untuk mulai mengelompokkan produk.',
                          primaryText: 'Tambah Kategori',
                          onPrimary: _openAdd,
                        );
                      }

                      if (data.isEmpty) {
                        return _EmptyState(
                          title: 'Tidak ada hasil',
                          subtitle: 'Coba kata kunci lain.',
                          primaryText: 'Reset Pencarian',
                          onPrimary: () => setState(() {
                            _searchCtrl.clear();
                            _query = '';
                          }),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, c) {
                          final w = c.maxWidth;
                          final isWide = w >= 900;
                          final crossAxisCount = isWide ? 2 : (w >= 600 ? 2 : 1);

                          // Desktop/tablet: grid card, Mobile: list
                          if (crossAxisCount > 1) {
                            return GridView.builder(
                              padding: const EdgeInsets.only(bottom: 10),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: isWide ? 3.4 : 3.0,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: data.length,
                              itemBuilder: (context, i) {
                                final c = data[i];
                                return _CategoryCard(
                                  c: c,
                                  onEdit: () => _openEdit(c),
                                  onDelete: () => _confirmDelete(c),
                                );
                              },
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.only(bottom: 10),
                            itemCount: data.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final c = data[i];
                              return _CategoryCard(
                                c: c,
                                onEdit: () => _openEdit(c),
                                onDelete: () => _confirmDelete(c),
                              );
                            },
                          );
                        },
                      );
                    },
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

/// ----------------------
/// UI COMPONENTS
/// ----------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x0A000000),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) {
              if (v.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map c;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.c,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = (c['name'] ?? '-').toString();
    final id = (c['id'] ?? '-').toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 8),
            color: Color(0x0A000000),
          ),
        ],
      ),
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.grid_view_rounded,
            // tetap selaras dengan brand tokens kamu
            bg: const Color(0xFFF1F5FF),
            border: const Color(0xFFDAE6FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    color: PosTokens.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 14, color: PosTokens.subtext),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ID: $id',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PosTokens.subtext,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MiniAction(
            tooltip: 'Edit',
            icon: Icons.edit_rounded,
            onTap: onEdit,
          ),
          const SizedBox(width: 6),
          _MiniAction(
            tooltip: 'Hapus',
            icon: Icons.delete_rounded,
            danger: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color border;

  const _IconBadge({
    required this.icon,
    required this.bg,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Icon(icon, color: PosTokens.primary, size: 22),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _MiniAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFD92D20) : PosTokens.text;
    final bg = danger ? const Color(0xFFFFF1F0) : const Color(0xFFF6F7FB);
    final border = danger ? const Color(0xFFFFD7D4) : PosTokens.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 18, color: fg),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final crossAxisCount = w >= 900 ? 2 : (w >= 600 ? 2 : 1);

        Widget card() => Container(
              height: 74,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PosTokens.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F3F7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(height: 12, width: 180, color: const Color(0xFFF2F3F7)),
                          const SizedBox(height: 10),
                          Container(height: 10, width: 120, color: const Color(0xFFF2F3F7)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

        if (crossAxisCount > 1) {
          return GridView.builder(
            itemCount: 8,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: w >= 900 ? 3.4 : 3.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, __) => card(),
          );
        }

        return ListView.separated(
          itemCount: 8,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => card(),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryText;
  final VoidCallback onPrimary;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.primaryText,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PosTokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IconBadge(
                icon: Icons.category_rounded,
                bg: Color(0xFFF1F5FF),
                border: Color(0xFFDAE6FF),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: PosTokens.text,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PosTokens.subtext,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onPrimary,
                child: Text(primaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ----------------------
/// Bottom Sheet Form (Modal yang lebih bagus)
/// ----------------------

class _CategorySheet extends StatefulWidget {
  final Map? category;
  final VoidCallback onSaved;

  const _CategorySheet({this.category, required this.onSaved});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final TextEditingController name = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      name.text = (widget.category!['name'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final v = name.text.trim();
    if (v.isEmpty) {
      notify(context, 'Nama wajib diisi', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      if (widget.category == null) {
        await CategoryService.addCategory(v);
        if (!mounted) return;
        notify(context, 'Kategori ditambahkan');
      } else {
        await CategoryService.updateCategory(widget.category!['id'], v);
        if (!mounted) return;
        notify(context, 'Kategori diupdate');
      }
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      notify(context, 'Gagal simpan kategori', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: PosTokens.border),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 22,
                    offset: Offset(0, 12),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      _IconBadge(
                        icon: isEdit ? Icons.edit_rounded : Icons.add_rounded,
                        bg: const Color(0xFFF1F5FF),
                        border: const Color(0xFFDAE6FF),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Kategori' : 'Tambah Kategori',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: PosTokens.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: name,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => loading ? null : save(),
                    decoration: InputDecoration(
                      labelText: 'Nama Kategori',
                      hintText: 'Misal: Bahan Bangunan',
                      prefixIcon: const Icon(Icons.category_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: loading ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('BATAL'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: loading ? null : save,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(isEdit ? 'SIMPAN' : 'TAMBAH'),
                        ),
                      ),
                    ],
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
