import 'package:flutter/material.dart';

/// Shared look for the redesigned screens: same colours as the Accounting,
/// Salary Sheet and Parties Report screens.
class Pro {
  static const navy = Color(0xFF03213D);
  static const head = Color(0xFF0B3D91); // table header / dialog header
  static const blue = Color(0xFF0D6EFD); // primary buttons
  static const green = Color(0xFF198754);
  static const red = Color(0xFFDC3545);
  static const orange = Color(0xFFE67E00);
  static const line = Color(0xFFDEE2E6);
  static const tint = Color(0xFFEAF1FB);
  static const grey = Color(0xFF6C757D);
  static const headBg = Color(0xFFF8F9FA);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// 12,345 (or 12,345.50 when [decimals] is 2).
  static String money(double v, {int decimals = 0}) {
    final fixed = v.abs().toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final digits = parts[0];
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    final isZero = fixed.replaceAll(RegExp(r'[0.]'), '').isEmpty;
    final neg = v < 0 && !isZero;
    return '${neg ? '-' : ''}$b${decimals > 0 ? '.${parts[1]}' : ''}';
  }

  /// Quantities: 12, 2.5, 0.125 (no useless trailing zeros).
  static String qty(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  static String date(DateTime? d) => d == null
      ? '-'
      : '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';

  static void snack(BuildContext context, String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(msg)),
    );
  }

  /// Plain table/cell text.
  static Widget t(String text,
      {bool bold = false,
        Color? color,
        TextAlign align = TextAlign.left,
        double size = 14}) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? Colors.black87,
      ),
    );
  }

  static Widget button(String label, IconData icon, VoidCallback? onTap,
      {Color color = blue}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ---------------------------------------------------------------- card

class ProCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const ProCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
      ),
      child: child,
    );
  }
}

// -------------------------------------------------------------- header

class ProHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ProHeader(
      {super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!,
                  style: const TextStyle(color: Pro.grey, fontSize: 13)),
            ],
          ],
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 10, runSpacing: 8, children: actions),
      ],
    );
  }
}

// --------------------------------------------------------- stat tiles

class ProStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const ProStat(this.label, this.value, this.icon, this.color);
}

class ProStatRow extends StatelessWidget {
  final List<ProStat> stats;
  const ProStatRow(this.stats, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final n = stats.length;
      var cols = c.maxWidth >= 760 ? n : (c.maxWidth >= 420 ? 2 : 1);
      if (cols > n) cols = n;
      final w = ((c.maxWidth - 14 * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          for (final s in stats)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 8)
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.icon, color: s.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Pro.grey, fontSize: 12)),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(s.value,
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: s.color)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

// -------------------------------------------------------------- search

class ProSearch extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double width;
  const ProSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search...',
    this.width = 300,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth < width ? c.maxWidth : width;
      const border = OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: Pro.line),
      );
      return SizedBox(
        width: w,
        height: 42,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: border,
            enabledBorder: border,
          ),
        ),
      );
    });
  }
}

// --------------------------------------------------------------- chip

class ProChip extends StatelessWidget {
  final String text;
  final Color color;
  const ProChip(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// --------------------------------------------------------------- table

class ProCol {
  final String label;
  final int flex;
  final Alignment align;
  const ProCol(this.label, this.flex, {this.align = Alignment.centerLeft});
}

class ProTable extends StatelessWidget {
  final List<ProCol> columns;
  final List<List<Widget>> rows;
  final List<Widget>? footer;
  final double minWidth;
  final String emptyText;

  const ProTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
    this.minWidth = 760,
    this.emptyText = 'No records found.',
  });

  Widget _cell(Widget child, ProCol col, {bool header = false}) {
    return Expanded(
      flex: col.flex,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: header ? 13 : 10),
        alignment: col.align,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: header ? Colors.white24 : Pro.line),
            bottom: const BorderSide(color: Pro.line),
          ),
        ),
        child: child,
      ),
    );
  }

  bool _isSr(ProCol c) => c.label.startsWith('Sr');
  bool _isAction(ProCol c) => c.label.isEmpty || c.label == 'Action';

  /// Phone layout: one card per row (title, "label : value" lines and the
  /// action buttons at the bottom) instead of a sideways-scrolling table.
  Widget _cards() {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pro.grey, fontSize: 15)),
        ),
      );
    }

    final titleIdx =
    columns.indexWhere((c) => !_isSr(c) && !_isAction(c));

    return Column(
      children: [
        for (final row in rows)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Pro.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (titleIdx >= 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                        alignment: Alignment.centerLeft, child: row[titleIdx]),
                  ),
                for (var j = 0; j < columns.length; j++)
                  if (j != titleIdx &&
                      !_isSr(columns[j]) &&
                      !_isAction(columns[j]))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(columns[j].label,
                              style: const TextStyle(
                                  color: Pro.grey, fontSize: 12)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: row[j]),
                          ),
                        ],
                      ),
                    ),
                for (var j = 0; j < columns.length; j++)
                  if (_isAction(columns[j]))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                          alignment: Alignment.centerRight, child: row[j]),
                    ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 640) return _cards();
      final w = c.maxWidth < minWidth ? minWidth : c.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: w,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(color: Pro.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  color: Pro.head,
                  child: Row(
                    children: [
                      for (final col in columns)
                        _cell(
                          Text(col.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          col,
                          header: true,
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text(emptyText,
                        style: const TextStyle(color: Pro.grey, fontSize: 15)),
                  ),
                for (var i = 0; i < rows.length; i++)
                  Container(
                    color: i.isOdd ? const Color(0xFFFAFBFD) : Colors.white,
                    child: Row(
                      children: [
                        for (var j = 0; j < columns.length; j++)
                          _cell(rows[i][j], columns[j]),
                      ],
                    ),
                  ),
                if (footer != null && rows.isNotEmpty)
                  Container(
                    color: Pro.headBg,
                    child: Row(
                      children: [
                        for (var j = 0; j < columns.length; j++)
                          _cell(footer![j], columns[j]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// -------------------------------------------------------------- dialog

/// Rounded dialog with a blue title bar, scrolling body and a footer for
/// the buttons. Used by every form on the redesigned screens.
class ProDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final List<Widget> actions;
  final double width;

  const ProDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.icon,
    this.width = 460,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              color: Pro.head,
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Pro.headBg,
                border: Border(top: BorderSide(color: Pro.line)),
              ),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}