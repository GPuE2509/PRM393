import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';
import '../models/transaction.dart' as model;

class SearchScreen extends StatefulWidget {
  final int userId;

  const SearchScreen({super.key, required this.userId});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _maxSearchHistory = 12;

  final TextEditingController _searchController = TextEditingController();

  List<model.Transaction> _results = [];
  List<String> _searchHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadSearchHistory();
    await _loadByCategory('');
  }

  String get _historyKey => 'search_history_user_${widget.userId}';

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_historyKey) ?? [];
    if (!mounted) return;
    setState(() {
      _searchHistory = items;
    });
  }

  Future<void> _saveSearchHistory(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final nextHistory = [
      normalized,
      ..._searchHistory.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ];

    if (nextHistory.length > _maxSearchHistory) {
      nextHistory.removeRange(_maxSearchHistory, nextHistory.length);
    }

    await prefs.setStringList(_historyKey, nextHistory);
    if (!mounted) return;
    setState(() {
      _searchHistory = nextHistory;
    });
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (!mounted) return;
    setState(() {
      _searchHistory = [];
    });
  }

  Future<void> _onSearchChanged() async {
    await _loadByCategory(_searchController.text);
  }

  Future<void> _onSubmitted(String value) async {
    await _saveSearchHistory(value);
  }

  Future<void> _loadByCategory(String query) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final items = await DatabaseHelper.instance.searchTransactionsByCategory(
        widget.userId,
        query,
      );

      if (!mounted) return;
      setState(() {
        _results = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,###').format(amount);
  }

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
      default:
        return 'Chủ Nhật';
    }
  }

  String _dateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Map<String, List<model.Transaction>> _groupTransactionsByDay() {
    final groups = <String, List<model.Transaction>>{};
    for (final item in _results) {
      final key = _dateKey(item.date);
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  Widget _buildHistoryPanel() {
    if (_searchHistory.isEmpty || _searchController.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Lịch sử tìm kiếm',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearSearchHistory,
                child: const Text('Xóa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory
                .map(
                  (item) => ActionChip(
                    label: Text(item),
                    onPressed: () {
                      _searchController.text = item;
                      _searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: item.length),
                      );
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    final income = _results
        .where((item) => item.type == model.TransactionType.income)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final expense = _results
        .where((item) => item.type == model.TransactionType.expense)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final net = income - expense;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_results.length} kết quả',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Khoản thu',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${_formatAmount(income)} đ',
                style: const TextStyle(
                  color: Color(0xFF0EA5E9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Khoản chi',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${_formatAmount(expense)} đ',
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${net >= 0 ? '+' : '-'}${_formatAmount(net.abs())} đ',
              style: TextStyle(
                color: net >= 0
                    ? const Color(0xFF0EA5E9)
                  : colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    final colorScheme = Theme.of(context).colorScheme;
    final grouped = _groupTransactionsByDay();
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final items = grouped[key]!;
        final day = items.first.date;

        final dayTotal = items.fold<double>(0, (sum, item) {
          return item.type == model.TransactionType.expense
              ? sum - item.amount
              : sum + item.amount;
        });

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Text(
                      DateFormat('dd').format(day),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _weekdayLabel(day),
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            DateFormat("'tháng' M yyyy").format(day),
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${dayTotal >= 0 ? '+' : '-'}${_formatAmount(dayTotal.abs())}',
                      style: TextStyle(
                        color: dayTotal >= 0
                            ? const Color(0xFF0EA5E9)
                            : colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...items.map(_transactionTile),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: _onSubmitted,
            decoration: InputDecoration(
              hintText: 'Tìm theo danh mục hoặc ghi chú...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(Icons.close),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHistoryPanel(),
                _buildSummary(),
                Expanded(
                  child: _results.isEmpty ? _emptyState() : _buildResultList(),
                ),
              ],
            ),
    );
  }

  Widget _emptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            hasQuery
                ? 'Không tìm thấy category phù hợp'
                : 'Nhập category để tìm giao dịch',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(model.Transaction item) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = item.type == model.TransactionType.expense;
    final amountColor = isExpense
        ? const Color(0xFFEF4444)
        : const Color(0xFF0EA5E9);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: amountColor.withValues(alpha: 0.12),
        child: Icon(Icons.local_bar, color: colorScheme.onSurfaceVariant),
      ),
      title: Text(
        item.category?.isNotEmpty == true ? item.category! : 'Khác',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: item.note.isEmpty
          ? null
          : Text(item.note, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      trailing: Text(
        '${_formatAmount(item.amount)}',
        style: TextStyle(
          color: amountColor,
          fontSize: 24,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
