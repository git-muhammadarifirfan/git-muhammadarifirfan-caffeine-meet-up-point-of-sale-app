import 'package:flutter/material.dart';

class PosTokens {
  static const bgTop = Color(0xFFF8FAFF);
  static const bgMid = Color(0xFFF6F8FC);
  static const bgBlue = Color(0xFFEAF0FF);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const text = Color(0xFF0F172A);
  static const subtext = Color(0xFF64748B);
  static const primary = Color(0xFF2F6BFF);
}

class PosBackground extends StatelessWidget {
  final Widget child;
  const PosBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PosTokens.bgTop,
            PosTokens.bgMid,
            PosTokens.bgBlue,
          ],
        ),
      ),
      child: child,
    );
  }
}

class PosSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double maxWidth;
  const PosSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.maxWidth = 1120,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          padding: padding,
          decoration: BoxDecoration(
            color: PosTokens.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: PosTokens.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class PosHeaderBar extends StatelessWidget {
  final String title;
  final String? crumb;
  final List<Widget> actions;
  final Widget? trailing;
  const PosHeaderBar({
    super.key,
    required this.title,
    this.crumb,
    this.actions = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Menu',
          onPressed: () {},
          icon: const Icon(Icons.menu),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: PosTokens.text,
                ),
              ),
              if (crumb != null) ...[
                const SizedBox(width: 6),
                Text(
                  '/ $crumb',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PosTokens.subtext,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
        ...actions,
      ],
    );
  }
}

class PosSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hint;
  const PosSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hint = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

class PosPill extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback? onTap;
  const PosPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? PosTokens.bgBlue : const Color(0xFFF8FAFC);
    final bd = selected ? const Color(0xFFBBD0FF) : PosTokens.border;
    final tx = selected ? const Color(0xFF1D4ED8) : PosTokens.subtext;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bd),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w800, color: tx, fontSize: 12),
        ),
      ),
    );
  }
}

class PosIconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  const PosIconCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PosTokens.border),
        ),
        child: Icon(icon, size: 18, color: PosTokens.text),
      ),
    );
  }
}

class PosKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? delta;
  const PosKpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PosTokens.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDAE6FF)),
            ),
            child: Icon(icon, color: PosTokens.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PosTokens.subtext,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: PosTokens.text,
                  ),
                ),
                if (delta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    delta!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}