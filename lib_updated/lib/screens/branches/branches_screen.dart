import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../services/branch_service.dart';
import '../../widgets/confirm_dialog.dart';
import 'branch_form_screen.dart';

const Color _branchBlue = Color(0xFF3159C9);

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final BranchService _service = BranchService();
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BranchFormScreen()),
    );
  }

  Future<void> _openEdit(Branch branch) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BranchFormScreen(branch: branch)),
    );
  }

  Future<void> _deleteBranch(Branch branch) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Branch',
      message: 'Are you sure you want to delete "${branch.name}"?',
    );
    if (confirmed) {
      await _service.deleteBranch(branch.id);
    }
  }

  void _viewDetails(Branch branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(branch.name),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Manager', branch.manager),
              _detailRow('Contact', branch.contact),
              _detailRow('City', branch.city),
              _detailRow('Area', branch.area),
              _detailRow('Address', branch.address),
              _detailRow('NTN', branch.ntn),
              _detailRow('STRN', branch.strn),
              _detailRow('Status', branch.status),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  void _showLoginCredentials(Branch branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Branch Login'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Branch: ${branch.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _detailRow(
                  'Username',
                  branch.username.isEmpty
                      ? 'Not set'
                      : branch.username),
              _detailRow(
                  'Password',
                  branch.password.isEmpty ? 'Not set' : branch.password),
              const SizedBox(height: 12),
              const Text(
                'Edit the branch to change these credentials.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openEdit(branch);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Branch>>(
      stream: _service.streamBranches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allBranches = snapshot.data ?? [];
        final total = allBranches.length;
        final active =
            allBranches.where((b) => b.status == 'active').length;
        final inactive = total - active;

        var branches = allBranches;
        if (_search.isNotEmpty) {
          branches = branches
              .where((b) =>
          b.name.toLowerCase().contains(_search) ||
              b.manager.toLowerCase().contains(_search) ||
              b.city.toLowerCase().contains(_search))
              .toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard('TOTAL BRANCHES', total.toString(), _branchBlue,
                    Icons.account_tree_outlined),
                _statCard('ACTIVE', active.toString(), Colors.green,
                    Icons.check_circle_outline),
                _statCard('INACTIVE', inactive.toString(), Colors.redAccent,
                    Icons.cancel_outlined),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 650;
              final title = Row(
                children: const [
                  Icon(Icons.account_tree_outlined, color: _branchBlue),
                  SizedBox(width: 8),
                  Text('Branch Management',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              );
              final search = SizedBox(
                width: stacked ? double.infinity : 260,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Branch...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              );
              final addButton = ElevatedButton.icon(
                onPressed: _openAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _branchBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Branch'),
              );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    search,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: addButton),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  search,
                  const SizedBox(width: 12),
                  addButton,
                ],
              );
            }),
            const SizedBox(height: 16),
            if (branches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No branches yet.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              _buildTable(branches),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Branch> branches) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(const Color(0xFFF5F7FA)),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Logo')),
            DataColumn(label: Text('Branch')),
            DataColumn(label: Text('Manager')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: branches.asMap().entries.map((entry) {
            final index = entry.key;
            final branch = entry.value;

            return DataRow(cells: [
              DataCell(Text('#${index + 1}')),
              DataCell(
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: branch.logoUrl.isNotEmpty
                      ? NetworkImage(branch.logoUrl)
                      : null,
                  child: branch.logoUrl.isEmpty
                      ? const Icon(Icons.store_outlined,
                      size: 16, color: Colors.grey)
                      : null,
                ),
              ),
              DataCell(Text(branch.name,
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text(branch.manager)),
              DataCell(Text(branch.contact)),
              DataCell(Text(branch.city)),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: branch.status == 'active'
                        ? Colors.green.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    branch.status == 'active' ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: branch.status == 'active'
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined,
                          size: 18, color: Colors.blue),
                      onPressed: () => _viewDetails(branch),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: _branchBlue),
                      onPressed: () => _openEdit(branch),
                    ),
                    IconButton(
                      icon: const Icon(Icons.vpn_key_outlined,
                          size: 18, color: Colors.amber),
                      onPressed: () => _showLoginCredentials(branch),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      onPressed: () => _deleteBranch(branch),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}