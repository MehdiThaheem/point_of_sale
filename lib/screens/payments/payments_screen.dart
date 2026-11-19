import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/payments.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/payment_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pro_ui.dart';

// A customer or supplier that can be paid / can pay.
class _PartyOpt {
  final String id;
  final String name;
  final double balance;
  const _PartyOpt(this.id, this.name, this.balance);
}

// What the "Record Payment" dialog hands back.
class _PaymentInput {
  final String partyType; // customer / supplier
  final _PartyOpt party;
  final double amount;
  final String note;
  const _PaymentInput(this.partyType, this.party, this.amount, this.note);
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentService _service = PaymentService();

  List<Payment> _payments = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  bool _loaded = false;
  final List<StreamSubscription> _subs = [];

  final TextEditingController _search = TextEditingController();
  String _type = 'All'; // All / Received / Paid

  @override
  void initState() {
    super.initState();
    _subs.add(_service.streamPayments().listen((d) {
      if (!mounted) return;
      setState(() {
        _payments = d;
        _loaded = true;
      });
    }, onError: (_) {}));
    _subs.add(CustomerService().streamCustomers().listen((d) {
      if (!mounted) return;
      setState(() => _customers = d);
    }, onError: (_) {}));
    _subs.add(SupplierService().streamSuppliers().listen((d) {
      if (!mounted) return;
      setState(() => _suppliers = d);
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  // ---------- actions ----------

  Future<void> _record(String? branchId) async {
    final customers = [
      for (final c in _customers)
        if (branchId == null || c.branchId == branchId)
          _PartyOpt(c.id, c.name, c.totalReceivable)
    ];
    final suppliers = [
      for (final s in _suppliers)
        if (branchId == null || s.branchId == branchId)
          _PartyOpt(s.id, s.name, s.totalPayable)
    ];

    final input = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) =>
          _PaymentDialog(customers: customers, suppliers: suppliers),
    );
    if (input == null || !mounted) return;

    try {
      await _service.addPayment(Payment(
        id: '',
        partyType: input.partyType,
        partyId: input.party.id,
        partyName: input.party.name,
        amount: input.amount,
        note: input.note,
      ));
      if (mounted) Pro.snack(context, 'Payment recorded.', color: Pro.green);
    } catch (e) {
      if (mounted) Pro.snack(context, 'Error: $e');
    }
  }

  Future<void> _delete(Payment p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Payment',
      message:
      'Delete this payment for "${p.partyName}"? The party\'s balance will be restored.',
    );
    if (!ok) return;
    try {
      await _service.deletePayment(p);
      if (mounted) Pro.snack(context, 'Payment deleted.', color: Pro.green);
    } catch (e) {
      if (mounted) Pro.snack(context, 'Error: $e');
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    // Payments don't store a branch, so it is taken from the customer or
    // supplier they belong to.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        final custBranch = {for (final c in _customers) c.id: c.branchId};
        final suppBranch = {for (final s in _suppliers) s.id: s.branchId};

        final inBranch = _payments.where((p) {
          if (branchId == null) return true;
          final b = p.partyType == 'supplier'
              ? suppBranch[p.partyId]
              : custBranch[p.partyId];
          return b == branchId;
        }).toList();

        final q = _search.text.trim().toLowerCase();
        final list = inBranch.where((p) {
          final isPaid = p.partyType == 'supplier';
          if (_type == 'Received' && isPaid) return false;
          if (_type == 'Paid' && !isPaid) return false;
          if (q.isNotEmpty &&
              !p.partyName.toLowerCase().contains(q) &&
              !p.note.toLowerCase().contains(q)) {
            return false;
          }
          return true;
        }).toList();

        double received = 0, paid = 0;
        for (final p in inBranch) {
          if (p.partyType == 'supplier') {
            paid += p.amount;
          } else {
            received += p.amount;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProHeader(
              title: 'Payments',
              subtitle: selectedBranchName.value ?? 'All Branches',
              actions: [
                Pro.button(
                    'Record Payment', Icons.add, () => _record(branchId)),
              ],
            ),
            const SizedBox(height: 18),
            ProStatRow([
              ProStat('Total Received', Pro.money(received),
                  Icons.south_west_rounded, Pro.green),
              ProStat('Total Paid', Pro.money(paid), Icons.north_east_rounded,
                  Pro.red),
              ProStat('Net', Pro.money(received - paid),
                  Icons.account_balance_wallet_outlined, Pro.blue),
              ProStat('Entries', '${inBranch.length}',
                  Icons.receipt_long_outlined, Pro.orange),
            ]),
            const SizedBox(height: 18),
            ProCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ProSearch(
                        controller: _search,
                        hint: 'Search party or note...',
                        onChanged: (_) => setState(() {}),
                      ),
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Pro.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _type,
                            items: const [
                              DropdownMenuItem(
                                  value: 'All', child: Text('All Payments')),
                              DropdownMenuItem(
                                  value: 'Received',
                                  child: Text('Received (Customers)')),
                              DropdownMenuItem(
                                  value: 'Paid',
                                  child: Text('Paid (Suppliers)')),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v ?? 'All'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_loaded)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ProTable(
                      minWidth: 860,
                      emptyText: inBranch.isEmpty
                          ? 'No payments recorded yet.'
                          : 'No payments match these filters.',
                      columns: const [
                        ProCol('Sr#', 6, align: Alignment.center),
                        ProCol('Date', 13),
                        ProCol('Party', 22),
                        ProCol('Type', 13, align: Alignment.center),
                        ProCol('Amount', 14, align: Alignment.centerRight),
                        ProCol('Note', 22),
                        ProCol('Action', 10, align: Alignment.center),
                      ],
                      rows: [
                        for (var i = 0; i < list.length; i++)
                          _row(i, list[i]),
                      ],
                      footer: [
                        const SizedBox(),
                        const SizedBox(),
                        Pro.t('Total', bold: true),
                        const SizedBox(),
                        Pro.t(
                            Pro.money(list.fold<double>(
                                0,
                                    (s, p) => p.partyType == 'supplier'
                                    ? s - p.amount
                                    : s + p.amount)),
                            bold: true,
                            align: TextAlign.right),
                        const SizedBox(),
                        const SizedBox(),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _row(int i, Payment p) {
    final received = p.partyType != 'supplier';
    return [
      Pro.t('${i + 1}', align: TextAlign.center),
      Pro.t(Pro.date(p.createdAt?.toDate())),
      Pro.t(p.partyName, bold: true),
      ProChip(received ? 'Received' : 'Paid', received ? Pro.green : Pro.red),
      Pro.t(Pro.money(p.amount),
          bold: true,
          align: TextAlign.right,
          color: received ? Pro.green : Pro.red),
      Pro.t(p.note.isEmpty ? '-' : p.note),
      IconButton(
        tooltip: 'Delete',
        visualDensity: VisualDensity.compact,
        onPressed: () => _delete(p),
        icon: const Icon(Icons.delete_outline, size: 20, color: Pro.red),
      ),
    ];
  }
}

// ==================================================================
// Record Payment dialog - gets plain lists (no streams inside), owns its
// controllers, and just returns what the user entered.
// ==================================================================

class _PaymentDialog extends StatefulWidget {
  final List<_PartyOpt> customers;
  final List<_PartyOpt> suppliers;
  const _PaymentDialog({required this.customers, required this.suppliers});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _type = 'customer'; // customer = receive, supplier = pay
  String? _partyId;
  String? _error;

  bool get _isCustomer => _type == 'customer';
  List<_PartyOpt> get _options => _isCustomer ? widget.customers : widget.suppliers;

  _PartyOpt? get _party {
    for (final p in _options) {
      if (p.id == _partyId) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _amt => double.tryParse(_amount.text.trim()) ?? 0;

  void _submit() {
    final party = _party;
    if (party == null) {
      setState(() => _error = 'Select a ${_isCustomer ? 'customer' : 'supplier'}.');
      return;
    }
    if (_amt <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_amt > party.balance + 0.005) {
      setState(() => _error =
      'Amount is more than the outstanding balance (${Pro.money(party.balance)}).');
      return;
    }
    Navigator.of(context)
        .pop(_PaymentInput(_type, party, _amt, _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final party = _party;
    final options = _options;

    return ProDialog(
      title: 'Record Payment',
      icon: Icons.payments_outlined,
      width: 460,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'customer',
                    label: Text('Receive'),
                    icon: Icon(Icons.south_west_rounded)),
                ButtonSegment(
                    value: 'supplier',
                    label: Text('Pay'),
                    icon: Icon(Icons.north_east_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _partyId = null;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isCustomer
                ? 'Money received from a customer'
                : 'Money paid to a supplier',
            style: const TextStyle(color: Pro.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (options.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Pro.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No ${_isCustomer ? 'customers' : 'suppliers'} found for this branch.',
                style: const TextStyle(color: Pro.orange),
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: party?.id,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _isCustomer ? 'Customer' : 'Supplier',
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final p in options)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name}  (${Pro.money(p.balance)})',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _partyId = v;
                _error = null;
              }),
            ),
          if (party != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Pro.tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_isCustomer ? 'Receivable' : 'Payable'}: ${Pro.money(party.balance)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: party.balance > 0
                        ? () => setState(() {
                      _amount.text = Pro.qty(party.balance);
                      _error = null;
                    })
                        : null,
                    child: const Text('Full amount'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
            decoration: const InputDecoration(
                labelText: 'Amount', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Note (optional)', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Pro.red)),
          ],
        ],
      ),
    );
  }
}