import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:api_client/api_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../config/theme.dart';

// Default fallbacks if the server response is missing the fields. Real
// values come from /wallet (`minWithdrawalInPence` / `withdrawalFeeInPence`).
const int _defaultMinWithdrawalPence = 1000;
const int _defaultWithdrawalFeePence = 0;

/// Barber wallet — pending + available balances, transactions, withdrawal
/// flow. Withdrawals are manual: a request goes to admin who processes
/// the actual bank transfer offline.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Wallet? _wallet;
  Map<String, String?>? _bank;
  DateTime? _nextAutoPayoutAt;
  int _minWithdrawalPence = _defaultMinWithdrawalPence;
  int _withdrawalFeePence = _defaultWithdrawalFeePence;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final walletFuture = api.getWallet();
      final bankFuture = api.getBankAccount();
      final walletResult = await walletFuture;
      final bank = await bankFuture;
      if (!mounted) return;
      setState(() {
        _wallet = walletResult.wallet;
        _nextAutoPayoutAt = walletResult.nextAutoPayoutAt;
        _minWithdrawalPence = walletResult.minWithdrawalInPence;
        _withdrawalFeePence = walletResult.withdrawalFeeInPence;
        _bank = bank;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load wallet.';
      });
    }
  }

  String _formatPayoutDate(DateTime utc) {
    final local = utc.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dow = days[(local.weekday - 1) % 7];
    return '$dow ${local.day} ${months[local.month - 1]}';
  }

  bool get _hasBankDetails =>
      _bank?['bankAccountName']?.isNotEmpty == true &&
      _bank?['bankSortCode']?.isNotEmpty == true &&
      _bank?['bankAccountNumber']?.isNotEmpty == true;

  WithdrawalRequest? get _activeWithdrawal {
    final list = _wallet?.withdrawalRequests ?? const [];
    for (final w in list) {
      if (w.status == 'REQUESTED' || w.status == 'PROCESSING') return w;
    }
    return null;
  }

  Future<void> _openBankSheet() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _BankDetailsSheet(initial: _bank),
    );
    if (changed == true) await _load();
  }

  Future<void> _openWithdrawSheet() async {
    // Capture messenger before any awaits so we don't reuse `context` after
    // the widget could have unmounted.
    final messenger = ScaffoldMessenger.of(context);

    if (!_hasBankDetails) {
      await _openBankSheet();
      if (!mounted || !_hasBankDetails) return;
    }
    if (_activeWithdrawal != null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('You already have a withdrawal in progress.'),
      ));
      return;
    }
    final available = _wallet?.availableInPence ?? 0;
    if (available < _minWithdrawalPence) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Minimum withdrawal is £${(_minWithdrawalPence / 100).toStringAsFixed(2)}.',
        ),
      ));
      return;
    }
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _WithdrawSheet(
        availableInPence: available,
        feeInPence: _withdrawalFeePence,
        minInPence: _minWithdrawalPence,
        bank: _bank!,
      ),
    );
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Bank details',
            onPressed: _loading ? null : _openBankSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : _body(),
      ),
    );
  }

  Widget _body() {
    final wallet = _wallet;
    final available = wallet?.availableInPounds ?? 0;
    final pending = wallet?.pendingInPounds ?? 0;
    final transactions = wallet?.transactions ?? [];
    final active = _activeWithdrawal;
    final nextPayout = _nextAutoPayoutAt;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BalanceCard(
          title: 'Available',
          amount: available,
          subtitle: 'Ready to withdraw',
          primary: true,
        ),
        const SizedBox(height: 12),
        _BalanceCard(
          title: 'Pending',
          amount: pending,
          subtitle: 'Releases 24h after each service started',
          primary: false,
        ),
        if (nextPayout != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded, size: 14,
                  color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Next auto-payout: ${_formatPayoutDate(nextPayout)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        if (active != null)
          _ActiveWithdrawalBanner(withdrawal: active)
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: available > 0 ? _openWithdrawSheet : null,
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: Text(_hasBankDetails ? 'Withdraw' : 'Add bank details to withdraw'),
            ),
          ),

        const SizedBox(height: 24),
        const Text(
          'Recent activity',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No transactions yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...transactions.map((t) => _TransactionTile(tx: t)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final bool primary;

  const _BalanceCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.primary : AppColors.surface;
    final fg = primary ? Colors.white : AppColors.textPrimary;
    final sub = primary ? Colors.white70 : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: primary ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sub,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '£${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: sub)),
        ],
      ),
    );
  }
}

class _ActiveWithdrawalBanner extends StatelessWidget {
  final WithdrawalRequest withdrawal;
  const _ActiveWithdrawalBanner({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final amount = withdrawal.netInPounds.toStringAsFixed(2);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '£$amount withdrawal in progress',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "We'll send it to your bank within 2 business days.",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, bool negative, String label) = _visuals(tx.type);
    final sign = negative ? '-' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (tx.description != null && tx.description!.isNotEmpty)
                  Text(
                    tx.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '$sign£${tx.amountInPounds.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: negative ? AppColors.error : AppColors.earnings,
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, bool negative, String label) _visuals(String type) {
    switch (type) {
      case 'PENDING_CREDIT':
        return (Icons.schedule_rounded, AppColors.warning, false, 'Pending credit');
      case 'EARNING':
        return (Icons.arrow_downward_rounded, AppColors.earnings, false, 'Earning');
      case 'PLATFORM_FEE':
        return (Icons.percent_rounded, AppColors.textSecondary, true, 'Platform fee');
      case 'INSTANT_WITHDRAWAL':
        return (Icons.account_balance_rounded, AppColors.primary, true, 'Withdrawal');
      case 'WITHDRAWAL_FEE':
        return (Icons.receipt_rounded, AppColors.textSecondary, true, 'Withdrawal fee');
      case 'WITHDRAWAL_REVERSAL':
        return (Icons.undo_rounded, AppColors.earnings, false, 'Withdrawal reversed');
      case 'REFUND_REVERSAL':
        return (Icons.undo_rounded, AppColors.error, true, 'Refund');
      case 'PAYOUT':
        return (Icons.payments_rounded, AppColors.primary, true, 'Payout');
      default:
        return (Icons.swap_horiz_rounded, AppColors.textSecondary, false, type);
    }
  }
}

// ─── Bank details sheet ───

class _BankDetailsSheet extends StatefulWidget {
  final Map<String, String?>? initial;
  const _BankDetailsSheet({required this.initial});

  @override
  State<_BankDetailsSheet> createState() => _BankDetailsSheetState();
}

class _BankDetailsSheetState extends State<_BankDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?['bankAccountName'] ?? '',
  );
  late final _sortController = TextEditingController(
    text: _formatSortCode(widget.initial?['bankSortCode'] ?? ''),
  );
  late final _accountController = TextEditingController(
    text: widget.initial?['bankAccountNumber'] ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _sortController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  String _formatSortCode(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length != 6) return raw;
    return '${d.substring(0, 2)}-${d.substring(2, 4)}-${d.substring(4, 6)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      await api.updateBankAccount(
        bankAccountName: _nameController.text.trim(),
        bankSortCode: _sortController.text.replaceAll(RegExp(r'\D'), ''),
        bankAccountNumber: _accountController.text.replaceAll(RegExp(r'\s'), ''),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg = (data is Map && data['error'] is Map &&
              (data['error'] as Map)['message'] is String)
          ? (data['error'] as Map)['message'] as String
          : 'Could not save. Try again.';
      setState(() {
        _saving = false;
        _error = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom is the keyboard; padding.bottom is the gesture/nav
    // bar. Without summing both, sheet buttons get covered on gesture-bar
    // devices.
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPad),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bank details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              "Withdrawals are paid to this account. Must be a UK current account in your name.",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account holder name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _sortController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Sort code',
                      hintText: '20-00-00',
                    ),
                    validator: (v) {
                      final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (d.length != 6) return 'Must be 6 digits';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _accountController,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Account number',
                      hintText: '12345678',
                    ),
                    validator: (v) {
                      final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (d.length != 8) return 'Must be 8 digits';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Withdraw sheet ───

class _WithdrawSheet extends StatefulWidget {
  final int availableInPence;
  final int feeInPence;
  final int minInPence;
  final Map<String, String?> bank;
  const _WithdrawSheet({
    required this.availableInPence,
    required this.feeInPence,
    required this.minInPence,
    required this.bank,
  });

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  late final _amountController = TextEditingController(
    text: (widget.availableInPence / 100).toStringAsFixed(2),
  );
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Net amount that lands in the bank for the currently-typed gross
  /// amount. Returns null if the gross is unparseable so callers can
  /// gracefully render a placeholder.
  int? get _grossPence {
    final pounds = double.tryParse(_amountController.text.trim());
    if (pounds == null || pounds <= 0) return null;
    return (pounds * 100).round();
  }

  Future<void> _submit() async {
    final pence = _grossPence;
    if (pence == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (pence < widget.minInPence) {
      setState(() => _error =
          'Minimum withdrawal is £${(widget.minInPence / 100).toStringAsFixed(2)}.');
      return;
    }
    if (pence > widget.availableInPence) {
      setState(() => _error = 'That is more than your available balance.');
      return;
    }
    if (pence - widget.feeInPence <= 0) {
      setState(() => _error =
          'Amount must be greater than the £${(widget.feeInPence / 100).toStringAsFixed(2)} fee.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final api = context.read<ApiClient>();
    try {
      await api.withdrawFunds(pence);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final msg = (data is Map && data['error'] is Map &&
              (data['error'] as Map)['message'] is String)
          ? (data['error'] as Map)['message'] as String
          : 'Could not submit. Try again.';
      setState(() {
        _submitting = false;
        _error = msg;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // viewInsets.bottom is the keyboard; padding.bottom is the gesture/nav
    // bar. Without summing both, sheet buttons get covered on gesture-bar
    // devices.
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom;
    final name = widget.bank['bankAccountName'] ?? '';
    final sort = widget.bank['bankSortCode'] ?? '';
    final acct = widget.bank['bankAccountNumber'] ?? '';
    final sortDisplay = sort.length == 6
        ? '${sort.substring(0, 2)}-${sort.substring(2, 4)}-${sort.substring(4, 6)}'
        : sort;
    final acctDisplay = acct.length >= 4
        ? '••••${acct.substring(acct.length - 4)}'
        : acct;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Withdraw',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Available: £${(widget.availableInPence / 100).toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '£ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          if (widget.feeInPence > 0) _FeeBreakdown(
            grossInPence: _grossPence,
            feeInPence: widget.feeInPence,
          ),

          const SizedBox(height: 16),

          // Bank destination summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SENDING TO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$sortDisplay · $acctDisplay',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            "We'll send it to your bank within 2 business days. You can't cancel once requested.",
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Request withdrawal'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-row gross / fee / net summary shown inside the withdraw sheet.
/// Hidden when the platform isn't charging a fee (current free auto-payout
/// path is unaffected — only the manual instant withdraw uses this).
class _FeeBreakdown extends StatelessWidget {
  final int? grossInPence;
  final int feeInPence;
  const _FeeBreakdown({required this.grossInPence, required this.feeInPence});

  @override
  Widget build(BuildContext context) {
    final gross = grossInPence;
    final net = gross == null ? null : gross - feeInPence;

    String fmt(int? pence) =>
        pence == null ? '—' : '£${(pence / 100).toStringAsFixed(2)}';

    Widget row(String label, String value, {bool emphasised = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: emphasised
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: emphasised
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          row('Withdrawal amount', fmt(gross)),
          row('Instant fee', '− ${fmt(feeInPence)}'),
          const Divider(height: 12),
          row("You'll receive", fmt(net), emphasised: true),
        ],
      ),
    );
  }
}
