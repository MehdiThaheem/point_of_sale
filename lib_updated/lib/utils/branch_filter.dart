import 'package:flutter/foundation.dart';

// Simple app-wide state for the "Branch" selector shown in the top bar.
// null id/name means "All Branches" (no filter).
// Screens that want to react to branch changes can wrap relevant
// widgets in a ValueListenableBuilder listening to selectedBranchId.
final ValueNotifier<String?> selectedBranchId = ValueNotifier<String?>(null);
final ValueNotifier<String?> selectedBranchName = ValueNotifier<String?>(null);

void setSelectedBranch(String? id, String? name) {
  selectedBranchId.value = id;
  selectedBranchName.value = name;
}