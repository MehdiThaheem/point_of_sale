import 'package:flutter/foundation.dart';

// Simple app-wide state for the "Branch" selector shown in the top bar.
// null id/name means "All Branches" (no filter).
// Screens that want to react to branch changes can wrap relevant
// widgets in a ValueListenableBuilder listening to selectedBranchId.
final ValueNotifier<String?> selectedBranchId = ValueNotifier<String?>(null);
final ValueNotifier<String?> selectedBranchName = ValueNotifier<String?>(null);

// True while a Manager is logged in: the branch is fixed to the Manager's
// own branch and cannot be switched (every branch picker in the app is a
// no-op / disabled while this is true).
final ValueNotifier<bool> branchLocked = ValueNotifier<bool>(false);

void setSelectedBranch(String? id, String? name) {
  if (branchLocked.value) return; // a Manager can't leave their branch
  selectedBranchId.value = id;
  selectedBranchName.value = name;
}

/// Pins the whole app to one branch (used for Manager logins).
void lockToBranch(String id, String name) {
  selectedBranchId.value = id;
  selectedBranchName.value = name;
  branchLocked.value = true;
}

/// Releases the lock and goes back to "All Branches" (used on logout).
void unlockBranch() {
  branchLocked.value = false;
  selectedBranchId.value = null;
  selectedBranchName.value = null;
}