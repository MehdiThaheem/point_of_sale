import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/brand.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/brand_service.dart';
import '../../services/branch_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';

const _kBlue = Color(0xFF3159C9);
const _kGreen = Color(0xFF2E7D32);
const _kGreenBg = Color(0xFFEAF7EC);
const _kAmberBg = Color(0xFFFFF8E1);
const _kAmberText = Color(0xFFB26A00);
const _kRed = Color(0xFFD32F2F);

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _service = ProductService();
  final BrandService _brandService = BrandService();
  final CategoryService _categoryService = CategoryService();
  final BranchService _branchService = BranchService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _viewMode = 'table'; // 'table' or 'cards'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openForm({
    Product? product,
    required List<Brand> brands,
    required List<Category> categories,
    required List<Branch> branches,
  }) {
    final barcodeController =
    TextEditingController(text: product?.barcode ?? '');
    final nameController = TextEditingController(text: product?.name ?? '');
    final shelfController =
    TextEditingController(text: product?.shelfLocation ?? '');
    final unitController = TextEditingController(text: product?.unit ?? 'pcs');
    final packSizeController =
    TextEditingController(text: (product?.packSize ?? 1).toString());
    final minStockController =
    TextEditingController(text: product?.minStock.toString() ?? '1');
    final stockController =
    TextEditingController(text: product?.currentStock.toString() ?? '');
    final descController =
    TextEditingController(text: product?.description ?? '');

    // Pack Price / Pack Cost aren't stored fields on Product — only the
    // resulting per-item salePrice/purchasePrice are (that's what the
    // rest of the app, e.g. sales screens, already reads). So on edit we
    // reverse-derive a starting pack price/cost from the saved per-item
    // values * pack size, and on save we go the other direction.
    final initialPackSize = product?.packSize ?? 1;
    final packPriceController = TextEditingController(
        text: ((product?.salePrice ?? 0) * initialPackSize)
            .toStringAsFixed(2));
    final packCostController = TextEditingController(
        text: ((product?.purchasePrice ?? 0) * initialPackSize)
            .toStringAsFixed(2));

    final formKey = GlobalKey<FormState>();

    Category? selectedCategory = categories.isEmpty
        ? null
        : categories.firstWhere((c) => c.id == product?.categoryId,
        orElse: () => categories.first);
    Brand? selectedBrand = brands.isEmpty
        ? null
        : brands.firstWhere((b) => b.id == product?.brandId,
        orElse: () => brands.first);
    String? selectedFormBranchId =
    product?.branchId.isNotEmpty == true ? product!.branchId : null;

    double itemPrice() {
      final packSize = double.tryParse(packSizeController.text.trim()) ?? 1;
      final packPrice = double.tryParse(packPriceController.text.trim()) ?? 0;
      if (packSize <= 0) return 0;
      return packPrice / packSize;
    }

    double itemCost() {
      final packSize = double.tryParse(packSizeController.text.trim()) ?? 1;
      final packCost = double.tryParse(packCostController.text.trim()) ?? 0;
      if (packSize <= 0) return 0;
      return packCost / packSize;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog.fullscreen(
          backgroundColor: const Color(0xFFF5F7FA),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: _kBlue,
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product == null ? 'Add Product' : 'Edit Product',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _fieldRow([
                          _labeledField(
                            label: 'BARCODE / SKU',
                            child: TextFormField(
                              controller: barcodeController,
                              decoration: _boxedDecoration(
                                hint: 'Scan or enter barcode...',
                                prefixIcon: Icons.qr_code_scanner,
                              ),
                            ),
                          ),
                          _labeledField(
                            label: 'PRODUCT NAME',
                            child: TextFormField(
                              controller: nameController,
                              decoration: _boxedDecoration(
                                  hint: 'Enter product name...'),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _fieldRow([
                          _labeledField(
                            label: 'CATEGORY',
                            child: DropdownButtonFormField<Category>(
                              value: categories.any(
                                      (c) => c.id == selectedCategory?.id)
                                  ? selectedCategory
                                  : null,
                              isExpanded: true,
                              decoration: _boxedDecoration(),
                              items: categories
                                  .map((c) => DropdownMenuItem(
                                  value: c, child: Text(c.name)))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                      () => selectedCategory = v),
                            ),
                          ),
                          _labeledField(
                            label: 'BRAND',
                            child: DropdownButtonFormField<Brand>(
                              value: brands
                                  .any((b) => b.id == selectedBrand?.id)
                                  ? selectedBrand
                                  : null,
                              isExpanded: true,
                              decoration: _boxedDecoration(),
                              items: brands
                                  .map((b) => DropdownMenuItem(
                                  value: b, child: Text(b.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedBrand = v),
                            ),
                          ),
                          _labeledField(
                            label: 'SHELF LOCATION',
                            child: TextFormField(
                              controller: shelfController,
                              decoration:
                              _boxedDecoration(hint: 'A1, B2...'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _fieldRow([
                          _labeledField(
                            label: 'BRANCH',
                            child: DropdownButtonFormField<String>(
                              value: branches.any(
                                      (b) => b.id == selectedFormBranchId)
                                  ? selectedFormBranchId
                                  : null,
                              isExpanded: true,
                              decoration: _boxedDecoration(),
                              items: branches
                                  .map((b) => DropdownMenuItem(
                                  value: b.id, child: Text(b.name)))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                      () => selectedFormBranchId = v),
                            ),
                          ),
                          _labeledField(
                            label: 'UNIT',
                            child: TextFormField(
                              controller: unitController,
                              decoration:
                              _boxedDecoration(hint: 'pcs, litre, kg...'),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        _fieldRow([
                          _labeledField(
                            label: 'PACK SIZE (ITEMS IN PACK)',
                            child: TextFormField(
                              controller: packSizeController,
                              keyboardType: TextInputType.number,
                              decoration: _boxedDecoration(),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          _labeledField(
                            label: 'LOW STOCK ALERT',
                            child: TextFormField(
                              controller: minStockController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: _kRed),
                              decoration: _boxedDecoration(borderColor: _kRed),
                            ),
                          ),
                          _labeledField(
                            label: 'CURRENT STOCK',
                            child: TextFormField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: _boxedDecoration(),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 560;
                            final sellingBox = _priceBox(
                              title: 'SELLING PRICE',
                              titleColor: _kGreen,
                              bg: _kGreenBg,
                              packLabel: 'Pack Price',
                              packController: packPriceController,
                              autoLabel: 'Item Price (Auto)',
                              autoValue: itemPrice(),
                              onPackChanged: () => setDialogState(() {}),
                            );
                            final costBox = _priceBox(
                              title: 'PURCHASE COST',
                              titleColor: Colors.black87,
                              bg: _kAmberBg,
                              packLabel: 'Pack Cost',
                              packController: packCostController,
                              autoLabel: 'Item Cost (Auto)',
                              autoValue: itemCost(),
                              onPackChanged: () => setDialogState(() {}),
                            );

                            if (stacked) {
                              return Column(
                                children: [
                                  sellingBox,
                                  const SizedBox(height: 12),
                                  costBox,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: sellingBox),
                                const SizedBox(width: 16),
                                Expanded(child: costBox),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _labeledField(
                          label: 'DESCRIPTION (OPTIONAL)',
                          child: TextFormField(
                            controller: descController,
                            decoration: _boxedDecoration(),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final branchName = selectedFormBranchId == null
                              ? ''
                              : branches
                              .firstWhere(
                                  (b) => b.id == selectedFormBranchId)
                              .name;

                          final newProduct = Product(
                            id: product?.id ?? '',
                            name: nameController.text.trim(),
                            barcode: barcodeController.text.trim(),
                            categoryId: selectedCategory?.id ?? '',
                            categoryName: selectedCategory?.name ?? '',
                            brandId: selectedBrand?.id ?? '',
                            brandName: selectedBrand?.name ?? '',
                            branchId: selectedFormBranchId ?? '',
                            branchName: branchName,
                            shelfLocation: shelfController.text.trim(),
                            unit: unitController.text.trim(),
                            packSize:
                            double.tryParse(packSizeController.text.trim()) ??
                                1,
                            purchasePrice: itemCost(),
                            salePrice: itemPrice(),
                            currentStock: double.tryParse(
                                stockController.text.trim()) ??
                                0,
                            minStock: double.tryParse(
                                minStockController.text.trim()) ??
                                0,
                            description: descController.text.trim(),
                            createdAt: product?.createdAt,
                          );

                          if (product == null) {
                            await _service.addProduct(newProduct);
                          } else {
                            await _service.updateProduct(
                                product.id, newProduct);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save Product'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Lays fields out as a Row on wide screens, or stacked on narrow ones,
  // so the form doesn't overflow on phones (the same class of bug fixed
  // earlier on the Counter Sale screen).
  Widget _fieldRow(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                fields[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: fields[i]),
            ],
          ],
        );
      },
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _boxedDecoration({
    String? hint,
    IconData? prefixIcon,
    Color? borderColor,
  }) {
    final color = borderColor ?? Colors.grey.shade400;
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor ?? _kBlue, width: 1.5),
      ),
    );
  }

  Widget _priceBox({
    required String title,
    required Color titleColor,
    required Color bg,
    required String packLabel,
    required TextEditingController packController,
    required String autoLabel,
    required double autoValue,
    required VoidCallback onPackChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: titleColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(packLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          TextFormField(
            controller: packController,
            keyboardType: TextInputType.number,
            decoration: _boxedDecoration(),
            onChanged: (_) => onPackChanged(),
          ),
          const SizedBox(height: 14),
          Text(autoLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              autoValue.toStringAsFixed(2),
              style: const TextStyle(
                  color: _kAmberText, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Quick-add dialogs so a missing Category/Brand can be created without
  // leaving the Items screen — same full-screen look as the dedicated
  // Categories/Brands screens, just triggered from here for convenience.
  void _quickAddCategory() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF17A2B8),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Category',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: TextFormField(
                    controller: nameController,
                    decoration:
                    const InputDecoration(labelText: 'Category Name'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF17A2B8),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        await _categoryService.addCategory(
                          Category(id: '', name: nameController.text.trim()),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _quickAddBrand() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFFE0A800),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add Brand',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: TextFormField(
                    controller: nameController,
                    decoration:
                    const InputDecoration(labelText: 'Brand Name'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0A800),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        await _brandService.addBrand(
                          Brand(id: '', name: nameController.text.trim()),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Product',
      message: 'Are you sure you want to delete "${product.name}"?',
    );
    if (confirmed) {
      await _service.deleteProduct(product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchFilter, _) {
        return StreamBuilder<List<Brand>>(
          stream: _brandService.streamBrands(),
          builder: (context, brandSnapshot) {
            final brands = brandSnapshot.data ?? [];

            return StreamBuilder<List<Category>>(
              stream: _categoryService.streamCategories(),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.data ?? [];

                return StreamBuilder<List<Branch>>(
                  stream: _branchService.streamBranches(),
                  builder: (context, branchSnapshot) {
                    final branches = branchSnapshot.data ?? [];

                    return StreamBuilder<List<Product>>(
                      stream: _service.streamProducts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child:
                            Center(child: CircularProgressIndicator()),
                          );
                        }

                        var products = snapshot.data ?? [];
                        if (branchFilter != null) {
                          products = products
                              .where((p) => p.branchId == branchFilter)
                              .toList();
                        }

                        var visibleProducts = products;
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          visibleProducts = visibleProducts
                              .where((p) =>
                          p.name.toLowerCase().contains(q) ||
                              p.barcode.toLowerCase().contains(q))
                              .toList();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Table/Cards toggle + the three add
                            // buttons, wrapping onto a new line on
                            // narrow screens instead of overflowing.
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                const Text(
                                  'Products',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                                _viewToggle(),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF17A2B8),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _quickAddCategory,
                                  child: const Text('Add Category'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE0A800),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _quickAddBrand,
                                  child: const Text('Add Brand'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF28A745),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _openForm(
                                    brands: brands,
                                    categories: categories,
                                    branches: branches,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Product'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Search Products...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (visibleProducts.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    products.isEmpty
                                        ? 'No products yet. Tap "Add Product" to create one.'
                                        : 'No products match your search.',
                                    style:
                                    const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else if (_viewMode == 'cards')
                              _buildCardsView(visibleProducts, brands,
                                  categories, branches)
                            else
                              _buildTableView(visibleProducts, brands,
                                  categories, branches),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _viewToggle() {
    Widget segment(String mode, String label) {
      final selected = _viewMode == mode;
      return InkWell(
        onTap: () => setState(() => _viewMode = mode),
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4)
            ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('table', 'Table'),
          segment('cards', 'Cards'),
        ],
      ),
    );
  }

  Widget _buildTableView(List<Product> products, List<Brand> brands,
      List<Category> categories, List<Branch> branches) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          headingRowColor:
          MaterialStateProperty.all(const Color(0xFFF5F7FA)),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Barcode')),
            DataColumn(label: Text('Items')),
            DataColumn(label: Text('Pack Price')),
            DataColumn(label: Text('Item Price')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Alert')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Brand')),
            DataColumn(label: Text('Action')),
          ],
          rows: List.generate(products.length, (i) {
            final product = products[i];
            final packPrice = product.salePrice * product.packSize;
            final total = product.salePrice * product.currentStock;
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(product.name,
                  style:
                  const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(
                  product.barcode.isEmpty ? '-' : product.barcode)),
              DataCell(Text(product.packSize.toStringAsFixed(0))),
              DataCell(Text(packPrice.toStringAsFixed(2))),
              DataCell(Text(product.salePrice.toStringAsFixed(2))),
              DataCell(Text(
                product.currentStock.toStringAsFixed(3),
                style: TextStyle(
                  color: product.isLowStock ? _kRed : Colors.black87,
                  fontWeight: product.isLowStock
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              )),
              DataCell(Text(total.toStringAsFixed(2))),
              DataCell(Text(product.minStock.toStringAsFixed(0))),
              DataCell(Text(product.shelfLocation.isEmpty
                  ? '-'
                  : product.shelfLocation)),
              DataCell(Text(product.categoryName.isEmpty
                  ? '-'
                  : product.categoryName)),
              DataCell(Text(
                  product.brandName.isEmpty ? '-' : product.brandName)),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _openForm(
                      product: product,
                      brands: brands,
                      categories: categories,
                      branches: branches,
                    ),
                    child: const Text('Edit'),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => _deleteProduct(product),
                    child: const Text('Del'),
                  ),
                ],
              )),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildCardsView(List<Product> products, List<Brand> brands,
      List<Category> categories, List<Branch> branches) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 260).floor().clamp(
            1, 5);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, i) {
            final product = products[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: product.isLowStock
                        ? Colors.red.withOpacity(0.12)
                        : Colors.green.withOpacity(0.12),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color:
                      product.isLowStock ? _kRed : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${product.categoryName.isEmpty ? "-" : product.categoryName} • '
                        '${product.brandName.isEmpty ? "-" : product.brandName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                    const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'Stock: ${product.currentStock.toStringAsFixed(0)} ${product.unit}',
                    style: TextStyle(
                      color: product.isLowStock ? _kRed : Colors.black87,
                      fontWeight: product.isLowStock
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  Text('Rs. ${product.salePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: _kBlue)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _openForm(
                            product: product,
                            brands: brands,
                            categories: categories,
                            branches: branches,
                          ),
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side:
                            const BorderSide(color: Colors.redAccent),
                            padding:
                            const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () => _deleteProduct(product),
                          child: const Text('Del'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}