import 'package:flutter/material.dart';
import '../models/product.dart';

/// The product card used on the Counter Sale and Sale screens.
///
/// * a coloured avatar with the product's first letter (every product gets
///   its own colour, so a grid of products is easy to scan)
/// * bold product name, brand as a small pill
/// * optional price and stock status (green / orange / red)
/// * soft shadow that lifts on hover, blue border + tick when selected
class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool selected;
  final bool showBrand;
  final bool showPrice;
  final bool showStock;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.selected = false,
    this.showBrand = true,
    this.showPrice = false,
    this.showStock = false,
  });

  /// Fixed card height for the grid's `mainAxisExtent` (independent of the
  /// card width, so text can never overflow on narrow phones).
  static double heightFor({required bool showPrice, required bool showStock}) =>
      (showPrice || showStock) ? 156 : 132;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  static const _blue = Color(0xFF2F5FDE);
  static const _green = Color(0xFF12A150);
  static const _amber = Color(0xFFE3A008);
  static const _red = Color(0xFFD9362F);

  static const _accents = [
    Color(0xFF2F5FDE),
    Color(0xFF12A150),
    Color(0xFFE3A008),
    Color(0xFF7B61C9),
    Color(0xFF299FB0),
    Color(0xFFD9362F),
  ];

  bool _hover = false;

  Color get _accent {
    final name = widget.product.name;
    var sum = 0;
    for (final c in name.codeUnits) {
      sum += c;
    }
    return _accents[sum % _accents.length];
  }

  String get _initial {
    final name = widget.product.name.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  String _money(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final accent = _accent;
    final out = widget.showStock && p.currentStock <= 0;
    final low = widget.showStock && !out && p.isLowStock;
    final stockColor = out ? _red : (low ? _amber : _green);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.selected
                ? _blue
                : (_hover ? accent.withOpacity(0.55) : const Color(0xFFE7EAF0)),
            width: widget.selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.selected
                  ? _blue.withOpacity(0.18)
                  : Colors.black.withOpacity(_hover ? 0.10 : 0.04),
              blurRadius: _hover || widget.selected ? 14 : 6,
              offset: Offset(0, _hover ? 5 : 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: out ? 0.6 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withOpacity(0.95),
                                accent.withOpacity(0.70),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            _initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 17),
                          ),
                        ),
                        const Spacer(),
                        if (widget.selected)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                                color: _blue, shape: BoxShape.circle),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 15),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          height: 1.2,
                          color: Color(0xFF1B2433)),
                    ),
                    if (widget.showBrand && p.brandName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5A6478)),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (widget.showPrice || widget.showStock)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.showPrice)
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Rs ${_money(p.salePrice)}',
                                  style: const TextStyle(
                                      color: _blue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                              ),
                            )
                          else
                            const Spacer(),
                          if (widget.showStock) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  color: stockColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              out ? 'Out' : _qty(p.currentStock),
                              style: TextStyle(
                                  color: stockColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}