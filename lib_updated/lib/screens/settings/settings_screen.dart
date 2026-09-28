import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _createUserFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _newUserNameController = TextEditingController();
  final _newUsernameController = TextEditingController();
  final _newUserEmailController = TextEditingController();
  final _newUserPhoneController = TextEditingController();
  final _newUserPasswordController = TextEditingController();
  String _newUserRole = 'employee';
  bool _creatingUser = false;

  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  String _email = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loadingProfile = false;
        _loadError = 'No user is signed in.';
      });
      return;
    }

    try {
      final doc = await _userService.getUserProfile(user.uid);
      final data = doc.data();

      if (data != null && mounted) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _email = data['email'] ?? user.email ?? '';
          _loadingProfile = false;
        });
      } else if (mounted) {
        setState(() {
          _email = user.email ?? '';
          _loadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _savingProfile = true);

    try {
      await _userService.updateUserProfile(
        uid: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _createUser() async {
    if (!_createUserFormKey.currentState!.validate()) return;

    setState(() => _creatingUser = true);

    try {
      final uid = await _authService.createManagedUser(
        email: _newUserEmailController.text.trim(),
        password: _newUserPasswordController.text.trim(),
      );

      await _userService.createUserProfile(
        uid: uid,
        name: _newUserNameController.text.trim(),
        username: _newUsernameController.text.trim(),
        email: _newUserEmailController.text.trim(),
        phone: _newUserPhoneController.text.trim(),
        role: _newUserRole,
      );

      _newUserNameController.clear();
      _newUsernameController.clear();
      _newUserEmailController.clear();
      _newUserPhoneController.clear();
      _newUserPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text('$_newUserRole account created successfully.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not create account.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingUser = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _savingPassword = true);

    try {
      await user.updatePassword(_newPasswordController.text.trim());

      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Could not change password.';
      if (e.code == 'requires-recent-login') {
        message =
        'For security, please log out and log back in before changing your password.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Could not load your profile.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loadingProfile = true;
                    _loadError = null;
                  });
                  _loadProfile();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackVertically = constraints.maxWidth < 700;

            final profileCard = _sectionCard(
              title: 'Profile',
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: _email,
                      enabled: false,
                      decoration:
                      const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration:
                      const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration:
                      const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _savingProfile ? null : _saveProfile,
                        child: _savingProfile
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                            : const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final passwordCard = _sectionCard(
              title: 'Change Password',
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration:
                      const InputDecoration(labelText: 'New Password'),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Minimum 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Confirm New Password'),
                      validator: (v) {
                        if (v != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed:
                        _savingPassword ? null : _changePassword,
                        child: _savingPassword
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                            : const Text('Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (stackVertically) {
              return Column(
                children: [
                  profileCard,
                  const SizedBox(height: 16),
                  passwordCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: profileCard),
                const SizedBox(width: 16),
                Expanded(child: passwordCard),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Create Team Login',
          child: Form(
            key: _createUserFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a login for an employee, supplier, or customer. '
                      'They will be shown by their username everywhere in '
                      'the app — the email is only used behind the scenes '
                      'to sign in.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 500;

                    final nameField = TextFormField(
                      controller: _newUserNameController,
                      decoration:
                      const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    );

                    final roleField = DropdownButtonFormField<String>(
                      value: _newUserRole,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: const [
                        DropdownMenuItem(
                            value: 'employee', child: Text('Manager')),
                        DropdownMenuItem(
                            value: 'supplier',
                            child: Text('Delivery Boy')),
                        DropdownMenuItem(
                            value: 'customer',
                            child: Text('Counter Sale')),
                        DropdownMenuItem(
                            value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) =>
                          setState(() => _newUserRole = v ?? 'employee'),
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          nameField,
                          const SizedBox(height: 12),
                          roleField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: nameField),
                        const SizedBox(width: 12),
                        Expanded(child: roleField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newUsernameController,
                  decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText:
                      'Shown across the app instead of their email'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newUserEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText:
                      'Still needed to sign in — kept private, never '
                          'shown in the app UI'),
                  validator: (v) {
                    if (v == null || !v.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newUserPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newUserPasswordController,
                  obscureText: true,
                  decoration:
                  const InputDecoration(labelText: 'Temporary Password'),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Minimum 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _creatingUser ? null : _createUser,
                    icon: _creatingUser
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.person_add_alt_1),
                    label: Text(
                        _creatingUser ? 'Creating...' : 'Create Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Company Branding',
          child: const Text(
            'To change the company name shown in the sidebar, open '
                'lib/screens/admin/admin_dashboard.dart and edit the '
                'kCompanyName and kAppTagline constants near the top of the file.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}