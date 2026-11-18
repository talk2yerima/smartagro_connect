import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/payment_providers.dart';
import '../../core/utils/money_format.dart';
import '../../data/services/payments_api.dart';
import '../../shared/widgets/gradient_button.dart';

/// Where a farmer's sales money goes. Their bank account becomes a Paystack
/// subaccount: every sale is split at Paystack and paid into their bank,
/// minus SmartAgro's fee. The bank confirms the account name before saving.
class GetPaidScreen extends ConsumerStatefulWidget {
  const GetPaidScreen({super.key});

  @override
  ConsumerState<GetPaidScreen> createState() => _GetPaidScreenState();
}

class _GetPaidScreenState extends ConsumerState<GetPaidScreen> {
  final _account = TextEditingController();

  List<Bank>? _banks;
  int _feePercent = 5;
  String? _loadError;

  Bank? _bank;
  String? _resolvedName;
  bool _checking = false;
  bool _saving = false;
  String? _error;
  bool _editing = false;
  int _checkId = 0;

  PaymentsApi get _api => ref.read(paymentsApiProvider);

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _account.addListener(_maybeCheck);
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() => _loadError = null);
    try {
      final r = await _api.listBanks();
      if (!mounted) return;
      setState(() {
        _banks = r.banks;
        _feePercent = r.feePercent;
      });
    } on PaymentException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError =
            "Couldn't load the list of banks. Check your connection.");
      }
    }
  }

  /// Checks the account with the bank as soon as it's complete.
  void _maybeCheck() {
    final number = _account.text;
    if (_resolvedName != null || _error != null) {
      setState(() {
        _resolvedName = null;
        _error = null;
      });
    }
    if (number.length == 10 && _bank != null) _check();
  }

  Future<void> _check() async {
    final bank = _bank;
    final number = _account.text;
    if (bank == null || number.length != 10) return;
    final id = ++_checkId;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final name = await _api.resolveBankAccount(
          accountNumber: number, bankCode: bank.code);
      if (!mounted || id != _checkId) return;
      setState(() => _resolvedName = name);
    } on PaymentException catch (e) {
      if (mounted && id == _checkId) setState(() => _error = e.message);
    } finally {
      if (mounted && id == _checkId) setState(() => _checking = false);
    }
  }

  Future<void> _save() async {
    final bank = _bank;
    if (bank == null || _resolvedName == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.savePayoutAccount(accountNumber: _account.text, bank: bank);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _account.clear();
        _bank = null;
        _resolvedName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Bank account saved. You'll be paid for your sales.")));
    } on PaymentException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickBank() async {
    final banks = _banks;
    if (banks == null) return;
    final picked = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BankPicker(banks: banks),
    );
    if (picked != null && mounted) {
      setState(() => _bank = picked);
      _maybeCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final current = ref.watch(myPayoutAccountProvider);
    final account = current.valueOrNull;
    final showForm = account == null || _editing;

    return Scaffold(
      appBar: AppBar(title: const Text('Get paid')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Where your sales money goes', style: text.titleLarge),
            const SizedBox(height: 12),
            _FeeExplainer(feePercent: _feePercent, isDark: isDark),
            const SizedBox(height: 20),
            if (current.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (account != null && !_editing) ...[
              _SavedAccount(account: account, isDark: isDark),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Change bank account'),
              ),
            ],
            if (showForm && !current.isLoading) ...[
              if (account == null)
                Text(
                  'Add the bank account you want buyers\' payments sent to. '
                  'Buyers can only pay for your listings once this is set.',
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.subText(isDark)),
                ),
              const SizedBox(height: 16),
              if (_loadError != null)
                _ErrorBox(message: _loadError!, onRetry: _loadBanks)
              else ...[
                _BankField(
                  bank: _bank,
                  loading: _banks == null,
                  onTap: _pickBank,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _account,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Account number',
                    hintText: '10 digits',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                if (_checking)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Checking with your bank…'),
                    ]),
                  ),
                if (_resolvedName != null)
                  _ResolvedName(name: _resolvedName!, isDark: isDark),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  _ErrorBox(message: _error!),
                ],
                const SizedBox(height: 20),
                PrimaryGradientButton(
                  label: _saving
                      ? 'Saving…'
                      : _resolvedName == null
                          ? 'Save bank account'
                          : 'Yes, this is my account. Save',
                  icon: Icons.account_balance_outlined,
                  onPressed: _resolvedName == null || _saving ? null : _save,
                ),
                if (_editing)
                  TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('Cancel'),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FeeExplainer extends StatelessWidget {
  const _FeeExplainer({required this.feePercent, required this.isDark});

  final int feePercent;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const example = 10000;
    final youGet = example - (example * feePercent / 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.lightGreen : AppColors.deepGreen)
            .withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When a buyer pays ${formatNgn(example)}, you get '
            '${formatNgn(youGet)}.',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'SmartAgro keeps $feePercent% and pays the card or transfer '
            'charge from it. Paystack sends your share straight to your bank, '
            'usually the next working day.',
            style: TextStyle(color: AppColors.subText(isDark), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SavedAccount extends StatelessWidget {
  const _SavedAccount({required this.account, required this.isDark});

  final PayoutAccount account;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border_(isDark)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_rounded,
              size: 32,
              color: isDark ? AppColors.lightGreen : AppColors.deepGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.accountName,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${account.bankName} · ${account.accountNumberMasked}',
                    style: TextStyle(color: AppColors.subText(isDark))),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.emerald),
        ],
      ),
    );
  }
}

class _BankField extends StatelessWidget {
  const _BankField({
    required this.bank,
    required this.loading,
    required this.onTap,
  });

  final Bank? bank;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Bank',
          prefixIcon: const Icon(Icons.account_balance_outlined),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : const Icon(Icons.expand_more_rounded),
        ),
        child: Text(
          bank?.name ?? (loading ? 'Loading banks…' : 'Choose your bank'),
        ),
      ),
    );
  }
}

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.banks});

  final List<Bank> banks;

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final shown = q.isEmpty
        ? widget.banks
        : widget.banks.where((b) => b.name.toLowerCase().contains(q)).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search banks (e.g. Opay, Zenith)',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No bank matches that name.'))
                : ListView.builder(
                    controller: controller,
                    itemCount: shown.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(shown[i].name),
                      onTap: () => Navigator.pop(context, shown[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResolvedName extends StatelessWidget {
  const _ResolvedName({required this.name, required this.isDark});

  final String name;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emerald.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.emerald),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account name from your bank',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.subText(isDark))),
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
