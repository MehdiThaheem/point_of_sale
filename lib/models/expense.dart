import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String id;
  final String branchId;
  final String branchName;
  final String expenseHeadId;
  final String expenseHeadName;
  final String expenseAccountId;
  final String expenseAccountName;
  final String cashBankAccount; // e.g. "Cash in Hand", "Bank Account"
  final double amount;
  final String description;
  final Timestamp? date;
  final Timestamp? createdAt;

  Expense({
    required this.id,
    this.branchId = '',
    this.branchName = '',
    this.expenseHeadId = '',
    this.expenseHeadName = '',
    this.expenseAccountId = '',
    this.expenseAccountName = '',
    this.cashBankAccount = 'Cash in Hand',
    required this.amount,
    this.description = '',
    this.date,
    this.createdAt,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      expenseHeadId: map['expenseHeadId'] ?? '',
      expenseHeadName: map['expenseHeadName'] ?? '',
      expenseAccountId: map['expenseAccountId'] ?? '',
      expenseAccountName: map['expenseAccountName'] ?? '',
      cashBankAccount: map['cashBankAccount'] ?? 'Cash in Hand',
      amount: (map['amount'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      date: map['date'],
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchId': branchId,
      'branchName': branchName,
      'expenseHeadId': expenseHeadId,
      'expenseHeadName': expenseHeadName,
      'expenseAccountId': expenseAccountId,
      'expenseAccountName': expenseAccountName,
      'cashBankAccount': cashBankAccount,
      'amount': amount,
      'description': description,
      'date': date ?? FieldValue.serverTimestamp(),
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}