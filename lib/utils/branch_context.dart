import 'package:firebase_auth/firebase_auth.dart';
import '../services/employee_service.dart';
import 'branch_filter.dart';

class BranchInfo {
  final String id;
  final String name;
  const BranchInfo(this.id, this.name);
}

// Works out which branch a new record (e.g. a sale) belongs to:
//  1. the branch picked in the top-bar selector, if one is active
//     (Admin / Manager working "as" a branch), otherwise
//  2. the branch on the logged-in user's own Employee record (Counter
//     Sale staff have no selector, so this is how their sales get a
//     branch), otherwise
//  3. blank (shows up under "All Branches" only).
Future<BranchInfo> resolveCurrentBranch() async {
  final selectedId = selectedBranchId.value;
  if (selectedId != null) {
    return BranchInfo(selectedId, selectedBranchName.value ?? '');
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const BranchInfo('', '');

  final employee = await EmployeeService().streamEmployeeByUid(uid).first;
  return BranchInfo(employee?.branchId ?? '', employee?.branchName ?? '');
}