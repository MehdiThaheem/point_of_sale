import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/area.dart';
import '../../models/branch.dart';
import '../../services/area_service.dart';
import '../../services/branch_service.dart';
import '../../services/cloudinary_service.dart';

const Color _branchBlue = Color(0xFF3159C9);

class BranchFormScreen extends StatefulWidget {
  final Branch? branch;

  const BranchFormScreen({super.key, this.branch});

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final BranchService _service = BranchService();
  final AreaService _areaService = AreaService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _branchNumberController;
  late final TextEditingController _nameController;
  late final TextEditingController _urduNameController;
  late final TextEditingController _managerController;
  late final TextEditingController _contactController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _ntnController;
  late final TextEditingController _strnController;
  late final TextEditingController _noteController;

  String _status = 'active';
  String? _selectedArea;
  bool _obscurePassword = true;
  Uint8List? _pickedLogoBytes;
  Uint8List? _pickedBannerBytes;
  bool _saving = false;

  bool get _isEditing => widget.branch != null;

  @override
  void initState() {
    super.initState();
    final b = widget.branch;
    _branchNumberController =
        TextEditingController(text: b?.branchNumber ?? '');
    _nameController = TextEditingController(text: b?.name ?? '');
    _urduNameController = TextEditingController(text: b?.urduName ?? '');
    _managerController = TextEditingController(text: b?.manager ?? '');
    _contactController = TextEditingController(text: b?.contact ?? '');
    _cityController = TextEditingController(text: b?.city ?? '');
    _addressController = TextEditingController(text: b?.address ?? '');
    _usernameController = TextEditingController(text: b?.username ?? '');
    _passwordController = TextEditingController(text: b?.password ?? '');
    _ntnController = TextEditingController(text: b?.ntn ?? '');
    _strnController = TextEditingController(text: b?.strn ?? '');
    _noteController = TextEditingController(text: b?.note ?? '');
    _status = b?.status ?? 'active';
    _selectedArea = b?.area.isNotEmpty == true ? b!.area : null;
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 400, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _pickedLogoBytes = bytes);
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _pickedBannerBytes = bytes);
  }

  Future<String> _uploadIfNeeded(
      Uint8List? bytes, String branchId, String fileName, String existingUrl) async {
    if (bytes == null) return existingUrl;
    // fileName is a suffix like '_logo.jpg' or '_banner.jpg' — folded into
    // the Cloudinary public_id so logo and banner don't overwrite each
    // other, while a re-upload of the same one replaces the old file.
    final publicId =
        '$branchId${fileName.replaceAll('.jpg', '')}';
    return await _cloudinaryService.uploadImage(
      bytes,
      folder: 'branch_photos',
      publicId: publicId,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final base = Branch(
        id: widget.branch?.id ?? '',
        branchNumber: _branchNumberController.text.trim(),
        name: _nameController.text.trim(),
        urduName: _urduNameController.text.trim(),
        manager: _managerController.text.trim(),
        contact: _contactController.text.trim(),
        status: _status,
        city: _cityController.text.trim(),
        area: _selectedArea ?? '',
        address: _addressController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        ntn: _ntnController.text.trim(),
        strn: _strnController.text.trim(),
        note: _noteController.text.trim(),
        logoUrl: widget.branch?.logoUrl ?? '',
        bannerUrl: widget.branch?.bannerUrl ?? '',
        createdAt: widget.branch?.createdAt,
      );

      String branchId = widget.branch?.id ?? '';
      if (!_isEditing) {
        branchId = await _service.addBranchAndGetId(base);
      }

      final logoUrl = await _uploadIfNeeded(
          _pickedLogoBytes, branchId, '_logo.jpg', base.logoUrl);
      final bannerUrl = await _uploadIfNeeded(
          _pickedBannerBytes, branchId, '_banner.jpg', base.bannerUrl);

      await _service.updateBranch(
        branchId,
        Branch(
          id: branchId,
          branchNumber: base.branchNumber,
          name: base.name,
          urduName: base.urduName,
          manager: base.manager,
          contact: base.contact,
          status: base.status,
          city: base.city,
          area: base.area,
          address: base.address,
          username: base.username,
          password: base.password,
          ntn: base.ntn,
          strn: base.strn,
          note: base.note,
          logoUrl: logoUrl,
          bannerUrl: bannerUrl,
          createdAt: base.createdAt,
        ),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _branchBlue,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Edit Branch' : 'Add Branch'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    icon: Icons.info_outline,
                    title: 'Basic Information',
                    child: Column(
                      children: [
                        _threeCol(
                          _labeledField(
                            'Branch #',
                            TextFormField(
                              controller: _branchNumberController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          _labeledField(
                            'Branch Name',
                            TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration(),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          _labeledField(
                            'Urdu Name',
                            TextFormField(
                              controller: _urduNameController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _threeCol(
                          _labeledField(
                            'Manager',
                            TextFormField(
                              controller: _managerController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          _labeledField(
                            'Contact',
                            TextFormField(
                              controller: _contactController,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          _labeledField(
                            'Status',
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: _fieldDecoration(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'active', child: Text('Active')),
                                DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('Inactive')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _status = v ?? 'active'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    child: Column(
                      children: [
                        _twoCol(
                          _labeledField(
                            'City',
                            TextFormField(
                              controller: _cityController,
                              decoration: _fieldDecoration(
                                  hint: 'Enter city'),
                            ),
                          ),
                          _labeledField(
                            'Area',
                            StreamBuilder<List<Area>>(
                              stream: _areaService.streamAreas(),
                              builder: (context, snapshot) {
                                final areas = snapshot.data ?? [];
                                return DropdownButtonFormField<String>(
                                  value: _selectedArea,
                                  decoration:
                                  _fieldDecoration(hint: 'Select Area'),
                                  items: areas
                                      .map((a) => DropdownMenuItem(
                                      value: a.name,
                                      child: Text(a.name)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedArea = v),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _labeledField(
                          'Branch Address',
                          TextFormField(
                            controller: _addressController,
                            maxLines: 3,
                            decoration: _fieldDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.lock_outline,
                    title: 'Branch Login',
                    child: _twoCol(
                      _labeledField(
                        'Username',
                        TextFormField(
                          controller: _usernameController,
                          decoration: _fieldDecoration(),
                        ),
                      ),
                      _labeledField(
                        'Password',
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _fieldDecoration().copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.description_outlined,
                    title: 'Tax Information',
                    child: Column(
                      children: [
                        _twoCol(
                          _labeledField(
                            'NTN',
                            TextFormField(
                              controller: _ntnController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          _labeledField(
                            'STRN',
                            TextFormField(
                              controller: _strnController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _labeledField(
                          'Note',
                          TextFormField(
                            controller: _noteController,
                            maxLines: 3,
                            decoration: _fieldDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    icon: Icons.image_outlined,
                    title: 'Logo & Banner',
                    child: _twoCol(
                      _labeledField(
                        'Branch Logo',
                        _filePickerField(
                          onTap: _pickLogo,
                          selected: _pickedLogoBytes,
                          existingUrl: widget.branch?.logoUrl,
                        ),
                      ),
                      _labeledField(
                        'Branch Banner',
                        _filePickerField(
                          onTap: _pickBanner,
                          selected: _pickedBannerBytes,
                          existingUrl: widget.branch?.bannerUrl,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _branchBlue,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _saving
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save Branch'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filePickerField({
    required VoidCallback onTap,
    Uint8List? selected,
    String? existingUrl,
  }) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: onTap,
          child: const Text('Choose File'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            selected != null
                ? 'File selected'
                : (existingUrl?.isNotEmpty == true
                ? 'Existing file on record'
                : 'No file chosen'),
            style: const TextStyle(color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircleAvatar(radius: 16, backgroundImage: MemoryImage(selected)),
          )
        else if (existingUrl?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: CircleAvatar(
                radius: 16, backgroundImage: NetworkImage(existingUrl!)),
          ),
      ],
    );
  }

  Widget _sectionCard(
      {required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _branchBlue),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }

  Widget _twoCol(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          return Column(children: [left, const SizedBox(height: 16), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _threeCol(Widget a, Widget b, Widget c) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return Column(children: [
            a,
            const SizedBox(height: 16),
            b,
            const SizedBox(height: 16),
            c,
          ]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
            const SizedBox(width: 16),
            Expanded(child: c),
          ],
        );
      },
    );
  }

  Widget _labeledField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }
}