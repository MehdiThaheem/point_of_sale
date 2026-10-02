import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/branch.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/supplier.dart';
import '../../services/auth_service.dart';
import '../../services/branch_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/supplier_service.dart';
import '../../services/user_service.dart';
import '../../utils/branch_filter.dart';

// Handles adding a new Employee record. It also doubles as the single
// place to create ANY portal account (Admin / Employee / Supplier /
// Customer) via the "Account Type" picker below, so there's no need to
// separately visit Settings > Create Team Login for those. Editing an
// existing employee always stays in "Employee" mode.
class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;

  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final EmployeeService _service = EmployeeService();
  final BranchService _branchService = BranchService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _cnicController;
  late final TextEditingController _contactController;
  late final TextEditingController _salaryController;
  late final TextEditingController _qualificationController;
  late final TextEditingController _addressController;
  late final TextEditingController _emailController;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();

  static const Map<String, String> accountTypeLabels = {
    'employee': 'Manager',
    'admin': 'Admin',
    'supplier': 'Delivery Boy',
    'customer': 'Counter Sale',
  };

  DateTime? _hireDate;
  String _status = 'active';
  String? _selectedBranchId;
  String? _selectedArea; // supplier/customer area
  String _accountType = 'employee';
  Uint8List? _pickedPhotoBytes;
  bool _saving = false;

  bool get _isEditing => widget.employee != null;

  // Show the "create portal login" fields for brand-new employees, or for
  // existing employees who don't have a login linked yet. For Admin /
  // Supplier / Customer, a login is the whole point of the entry, so it's
  // always shown (and required) for those. Once an employee has a uid,
  // their login already exists — resetting the password is done via the
  // key icon on the Employees list instead.
  bool get _canCreateLogin =>
      widget.employee == null || widget.employee!.uid.isEmpty;

  bool get _loginIsRequired =>
      _accountType != 'employee' && widget.employee == null;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?.name ?? '');
    _cnicController = TextEditingController(text: e?.cnic ?? '');
    _contactController = TextEditingController(text: e?.phone ?? '');
    _salaryController =
        TextEditingController(text: e?.salary.toString() ?? '0');
    _qualificationController =
        TextEditingController(text: e?.qualification ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _hireDate = e?.hireDate?.toDate();
    _status = e?.status ?? 'active';
    _selectedBranchId = e?.branchId.isNotEmpty == true
        ? e!.branchId
        : selectedBranchId.value; // default: branch from the top bar
    // Preserve the original account type on edit — every type is stored
    // in the employees collection with "position" holding its label
    // (Manager/Admin/Delivery Boy/Counter Sale), so look up which key
    // that label belongs to rather than assuming "employee".
    if (e != null) {
      _accountType = accountTypeLabels.entries
          .firstWhere(
            (entry) => entry.value == e.position,
        orElse: () => const MapEntry('employee', 'Manager'),
      )
          .key;
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _pickedPhotoBytes = bytes);
  }

  Future<String> _uploadPhotoIfNeeded(String employeeId) async {
    if (_pickedPhotoBytes == null) return widget.employee?.photoUrl ?? '';

    return await _cloudinaryService.uploadImage(
      _pickedPhotoBytes!,
      folder: 'employee_photos',
      publicId: employeeId,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final wantsLogin = _canCreateLogin &&
        (_loginIsRequired ||
            _usernameController.text.trim().isNotEmpty ||
            _passwordController.text.trim().isNotEmpty);

    if (wantsLogin) {
      if (_emailController.text.trim().isEmpty ||
          !_emailController.text.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'A valid email is required to create a portal login.')),
        );
        return;
      }
      if (_usernameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a username for the login.')),
        );
        return;
      }
      if (_passwordController.text.trim().length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password must be at least 6 characters.')),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      // Create the Firebase Auth account + Firestore profile first (if
      // requested), so the employee record can be saved with its uid
      // already linked in one go, instead of a separate Settings step.
      String uid = widget.employee?.uid ?? '';
      if (wantsLogin) {
        uid = await _authService.createManagedUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await _userService.createUserProfile(
          uid: uid,
          name: _nameController.text.trim(),
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _contactController.text.trim(),
          role: _accountType,
        );
      }

      // Every account type is saved with the same full set of details
      // (CNIC, branch, salary, qualification, hire date, photo, etc.) in
      // the employees collection, with "position" recording which kind
      // of account it is (Manager / Admin / Delivery Boy / Counter Sale).
      String branchName = widget.employee?.branchName ?? '';
      if (_selectedBranchId != null) {
        final branches = await _branchService.streamBranches().first;
        final match = branches
            .where((b) => b.id == _selectedBranchId)
            .toList();
        if (match.isNotEmpty) branchName = match.first.name;
      } else {
        branchName = '';
      }

      final baseEmployee = Employee(
        id: widget.employee?.id ?? '',
        uid: uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _contactController.text.trim(),
        position: accountTypeLabels[_accountType] ?? '',
        salary: double.tryParse(_salaryController.text.trim()) ?? 0,
        status: _status,
        cnic: _cnicController.text.trim(),
        qualification: _qualificationController.text.trim(),
        address: _addressController.text.trim(),
        photoUrl: widget.employee?.photoUrl ?? '',
        branchId: _selectedBranchId ?? '',
        branchName: branchName,
        hireDate: _hireDate != null ? Timestamp.fromDate(_hireDate!) : null,
        createdAt: widget.employee?.createdAt,
      );

      if (_isEditing) {
        final photoUrl = await _uploadPhotoIfNeeded(widget.employee!.id);
        await _service.updateEmployee(
          widget.employee!.id,
          Employee(
            id: baseEmployee.id,
            uid: baseEmployee.uid,
            name: baseEmployee.name,
            email: baseEmployee.email,
            phone: baseEmployee.phone,
            position: baseEmployee.position,
            salary: baseEmployee.salary,
            status: baseEmployee.status,
            cnic: baseEmployee.cnic,
            qualification: baseEmployee.qualification,
            address: baseEmployee.address,
            photoUrl: photoUrl,
            branchId: baseEmployee.branchId,
            branchName: baseEmployee.branchName,
            hireDate: baseEmployee.hireDate,
            createdAt: baseEmployee.createdAt,
          ),
        );
      } else {
        final docId = await _service.addEmployeeAndGetId(baseEmployee);
        if (_pickedPhotoBytes != null) {
          final photoUrl = await _uploadPhotoIfNeeded(docId);
          await _service.updateEmployee(
            docId,
            Employee(
              id: docId,
              uid: baseEmployee.uid,
              name: baseEmployee.name,
              email: baseEmployee.email,
              phone: baseEmployee.phone,
              position: baseEmployee.position,
              salary: baseEmployee.salary,
              status: baseEmployee.status,
              cnic: baseEmployee.cnic,
              qualification: baseEmployee.qualification,
              address: baseEmployee.address,
              photoUrl: photoUrl,
              branchId: baseEmployee.branchId,
              branchName: baseEmployee.branchName,
              hireDate: baseEmployee.hireDate,
              createdAt: baseEmployee.createdAt,
            ),
          );
        }

        // Delivery Boy / Counter Sale accounts also need a matching
        // Supplier/Customer business record — that's what the Purchases
        // and Sales screens pick from, and what tracks their
        // payable/receivable balance.
        if (_accountType == 'supplier') {
          await _supplierService.addSupplier(Supplier(
            id: '',
            name: _nameController.text.trim(),
            businessName: _businessNameController.text.trim(),
            phone: _contactController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            area: _selectedArea ?? '',
            status: _status,
          ));
        } else if (_accountType == 'customer') {
          await _customerService.addCustomer(Customer(
            id: '',
            name: _nameController.text.trim(),
            businessName: _businessNameController.text.trim(),
            phone: _contactController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            area: _selectedArea ?? '',
            status: _status,
          ));
        }
      }

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  e.message ?? 'Could not create the portal login.')),
        );
      }
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
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Header — same blue bar and color for every account type
          // (Admin / Manager / Delivery Boy / Counter Sale), so the
          // form always feels like one consistent screen.
          Container(
            width: double.infinity,
            color: const Color(0xFF3159C9),
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Edit Employee'
                          : 'New ${accountTypeLabels[_accountType]}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
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
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isEditing) ...[
                          _labeledField(
                            'Account Type',
                            DropdownButtonFormField<String>(
                              value: _accountType,
                              decoration: _fieldDecoration(),
                              items: accountTypeLabels.entries
                                  .map((entry) => DropdownMenuItem(
                                  value: entry.key, child: Text(entry.value)))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                _accountType = v ?? 'employee';
                              }),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _twoCol(
                          _labeledField(
                            'Full Name',
                            TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration(),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          _labeledField(
                            'CNIC Number',
                            TextFormField(
                              controller: _cnicController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _labeledField(
                          'Branch',
                          StreamBuilder<List<Branch>>(
                            stream: _branchService.streamBranches(),
                            builder: (context, snapshot) {
                              final branches = snapshot.data ?? [];
                              return DropdownButtonFormField<String>(
                                value: _selectedBranchId,
                                decoration:
                                _fieldDecoration(hint: 'Select Branch'),
                                items: branches
                                    .map((b) => DropdownMenuItem(
                                    value: b.id, child: Text(b.name)))
                                    .toList(),
                                // Fixed for Managers (locked to their branch).
                                onChanged: branchLocked.value
                                    ? null
                                    : (v) =>
                                    setState(() => _selectedBranchId = v),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _twoCol(
                          _labeledField(
                            'Contact',
                            TextFormField(
                              controller: _contactController,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          _labeledField(
                            'Salary',
                            TextFormField(
                              controller: _salaryController,
                              keyboardType: TextInputType.number,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _twoCol(
                          _labeledField(
                            'Email (for portal login, Must)',
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                          _labeledField(
                            'Qualification',
                            TextFormField(
                              controller: _qualificationController,
                              decoration: _fieldDecoration(),
                            ),
                          ),
                        ),
                        if (_canCreateLogin) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _loginIsRequired
                                      ? 'Portal Login'
                                      : 'Portal Login ',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _loginIsRequired
                                      ? 'This account signs in with the '
                                      'username and password below.'
                                      : 'Fill these in to let this employee '
                                      'sign in right away — no separate '
                                      'step in Settings needed. Leave '
                                      'blank to add a login for them '
                                      'later.',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 14),
                                _twoCol(
                                  _labeledField(
                                    'Username/E_mail',
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: _fieldDecoration(),
                                    ),
                                  ),
                                  _labeledField(
                                    ' Password For Login',
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: _fieldDecoration(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Portal login already linked. Use the '
                                        'key icon on the Employees list to '
                                        'send a password reset link.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _twoCol(
                          _labeledField(
                            'Hire Date',
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _hireDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() => _hireDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: _fieldDecoration(),
                                child: Text(
                                  _hireDate == null
                                      ? 'Select date'
                                      : '${_hireDate!.month}/${_hireDate!.day}/${_hireDate!.year}',
                                ),
                              ),
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
                        const SizedBox(height: 16),
                        _labeledField(
                          'Address',
                          TextFormField(
                            controller: _addressController,
                            maxLines: 3,
                            decoration: _fieldDecoration(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _labeledField(
                          'Photo',
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.upload_outlined,
                                    size: 18),
                                label: const Text('Choose File'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _pickedPhotoBytes != null
                                      ? 'Photo selected'
                                      : (widget.employee?.photoUrl
                                      .isNotEmpty ==
                                      true
                                      ? 'Existing photo on file'
                                      : 'No file chosen'),
                                  style:
                                  const TextStyle(color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_pickedPhotoBytes != null)
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                  MemoryImage(_pickedPhotoBytes!),
                                )
                              else if (widget.employee?.photoUrl
                                  .isNotEmpty ==
                                  true)
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                  NetworkImage(widget.employee!.photoUrl),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3159C9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                                : Text(
                              _isEditing
                                  ? 'SAVE RECORD'
                                  : 'ADD ${accountTypeLabels[_accountType]!.toUpperCase()}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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