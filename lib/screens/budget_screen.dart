import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/budget.dart' as budget_model;
import '../models/transaction.dart' as model;
import 'add_budget_screen.dart';
import 'budget_detail_screen.dart';

class BudgetScreen extends StatefulWidget {
  final int userId;
  final int refreshToken;

  const BudgetScreen({super.key, required this.userId, this.refreshToken = 0});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<_BudgetPeriodGroup> _periodGroups = [];
  String? _selectedPeriodKey;
  final Map<String, int?> _selectedBudgetIdByPeriod = {};
  final Map<String, Map<String, double>> _spentByCategoryByPeriod = {};
  List<_BudgetCardData> _endedBudgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  @override
  void didUpdateWidget(covariant BudgetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadBudgetData();
    }
  }

  Future<void> _loadBudgetData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final budgets = await DatabaseHelper.instance.getBudgetsByUser(
        widget.userId,
      );

      if (budgets.isEmpty) {
        if (!mounted) return;
        setState(() {
          _periodGroups = [];
          _selectedPeriodKey = null;
          _endedBudgets = [];
          _isLoading = false;
        });
        return;
      }

      final grouped = <String, List<_BudgetCardData>>{};
      final rangeMap = <String, ({DateTime start, DateTime end})>{};

      for (final budget in budgets) {
        final spent = await DatabaseHelper.instance
            .getExpenseTotalInRangeForBudget(
              userId: widget.userId,
              startDate: budget.startDate,
              endDate: budget.endDate,
              category: budget.category,
            );

        final key = _rangeKey(budget.startDate, budget.endDate);
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(_BudgetCardData(budget: budget, spent: spent));
        rangeMap[key] = (start: budget.startDate, end: budget.endDate);
      }

      final groups = grouped.entries.map((entry) {
        final range = rangeMap[entry.key]!;
        final items = entry.value
          ..sort((a, b) => b.budget.amount.compareTo(a.budget.amount));
        return _BudgetPeriodGroup(
          key: entry.key,
          startDate: range.start,
          endDate: range.end,
          items: items,
        );
      }).toList()..sort((a, b) => b.startDate.compareTo(a.startDate));

      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);

      final activeGroups = groups.where((group) {
        final end = DateTime(
          group.endDate.year,
          group.endDate.month,
          group.endDate.day,
        );
        return !end.isBefore(todayOnly);
      }).toList();

      final endedItems =
          groups
              .where((group) {
                final end = DateTime(
                  group.endDate.year,
                  group.endDate.month,
                  group.endDate.day,
                );
                return end.isBefore(todayOnly);
              })
              .expand((group) => group.items)
              .toList()
            ..sort((a, b) => b.budget.endDate.compareTo(a.budget.endDate));

      final now = DateTime.now();
      final activeKey = activeGroups
          .where((group) => _isWithinRange(now, group.startDate, group.endDate))
          .map((group) => group.key)
          .cast<String?>()
          .firstOrNull;

      String? nextSelected = _selectedPeriodKey;
      final keyExists = activeGroups.any((group) => group.key == nextSelected);
      if (!keyExists) {
        nextSelected = activeGroups.isNotEmpty
            ? (activeKey ?? activeGroups.first.key)
            : null;
      }

      final nextSelectedBudgetIdByPeriod = <String, int?>{};
      for (final group in activeGroups) {
        final existingId = _selectedBudgetIdByPeriod[group.key];
        if (existingId != null &&
            group.items.any((item) => item.budget.id == existingId)) {
          nextSelectedBudgetIdByPeriod[group.key] = existingId;
          continue;
        }

        final allGroupItem = group.items.firstWhere(
          (item) => item.isAllGroups,
          orElse: () => group.items.first,
        );
        nextSelectedBudgetIdByPeriod[group.key] = allGroupItem.budget.id;
      }

      final spentByCategoryByPeriod = <String, Map<String, double>>{};
      for (final group in activeGroups) {
        final totals = await DatabaseHelper.instance
            .getCategoryTotalsByUserAndTypeInRange(
              widget.userId,
              model.TransactionType.expense,
              group.startDate,
              group.endDate,
            );
        spentByCategoryByPeriod[group.key] = totals;
      }

      if (!mounted) return;
      setState(() {
        _periodGroups = activeGroups;
        _selectedPeriodKey = nextSelected;
        _selectedBudgetIdByPeriod
          ..clear()
          ..addAll(nextSelectedBudgetIdByPeriod);
        _spentByCategoryByPeriod
          ..clear()
          ..addAll(spentByCategoryByPeriod);
        _endedBudgets = endedItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải ngân sách: $e')));
    }
  }

  Future<void> _goToAddBudget() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddBudgetScreen(userId: widget.userId)),
    );

    if (created == true) {
      await _loadBudgetData();
    }
  }

  Future<void> _openBudgetDetail(_BudgetCardData item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            BudgetDetailScreen(userId: widget.userId, budget: item.budget),
      ),
    );
    if (changed == true) {
      await _loadBudgetData();
    }
  }

  Future<void> _showEndedBudgets() async {
    if (_endedBudgets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ngân sách đã kết thúc')),
      );
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<_BudgetCardData>(
      context: context,
      backgroundColor: colorScheme.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (context) {
        final sheetColorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ngân sách đã kết thúc',
                  style: TextStyle(
                    color: sheetColorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _endedBudgets.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Color(0xFF2D313B), height: 1),
                    itemBuilder: (context, index) {
                      final item = _endedBudgets[index];
                      return ListTile(
                        onTap: () => Navigator.of(context).pop(item),
                        title: Text(
                          item.budget.category ?? 'Tổng cộng',
                          style: TextStyle(
                            color: sheetColorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '${DateFormat('dd/MM/yyyy').format(item.budget.startDate)} - ${DateFormat('dd/MM/yyyy').format(item.budget.endDate)}',
                          style: TextStyle(
                            color: sheetColorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: sheetColorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      if (!mounted) return;
      await _openBudgetDetail(selected);
    }
  }

  String _rangeKey(DateTime start, DateTime end) {
    return '${DateFormat('yyyy-MM-dd').format(start)}_${DateFormat('yyyy-MM-dd').format(end)}';
  }

  bool _isWithinRange(DateTime value, DateTime start, DateTime end) {
    final v = DateTime(value.year, value.month, value.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !v.isBefore(s) && !v.isAfter(e);
  }

  int _daysLeft(DateTime endDate) {
    final today = DateTime.now();
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final diff = end.difference(today);
    if (diff.isNegative) return 0;
    return diff.inDays + 1;
  }

  bool _isFutureStart(DateTime startDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return start.isAfter(today);
  }

  String _formatMoney(double value) {
    return NumberFormat('#,###').format(value);
  }

  String _formatCompact(double value) {
    final abs = value.abs();
    if (abs >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)} M';
    }
    if (abs >= 1000) {
      return '${(value / 1000).toStringAsFixed(abs >= 100000 ? 0 : 1)} K';
    }
    return _formatMoney(value);
  }

  _BudgetPeriodGroup? get _selectedGroup {
    if (_periodGroups.isEmpty || _selectedPeriodKey == null) return null;
    for (final group in _periodGroups) {
      if (group.key == _selectedPeriodKey) return group;
    }
    return _periodGroups.first;
  }

  _BudgetCardData? _selectedBudgetItem(_BudgetPeriodGroup group) {
    final selectedId = _selectedBudgetIdByPeriod[group.key];
    if (selectedId != null) {
      for (final item in group.items) {
        if (item.budget.id == selectedId) return item;
      }
    }
    return group.items.isNotEmpty ? group.items.first : null;
  }

  String _budgetName(_BudgetCardData item) {
    return item.isAllGroups
        ? 'Tất cả các nhóm'
        : (item.budget.category ?? 'Khác');
  }

  String _tabTitle(_BudgetPeriodGroup group) {
    if (_isWithinRange(DateTime.now(), group.startDate, group.endDate)) {
      return 'Tháng này';
    }
    return '${DateFormat('dd/MM').format(group.startDate)} - ${DateFormat('dd/MM').format(group.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'Ngân sách đang áp dụng',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _showEndedBudgets,
            icon: const Icon(Icons.more_horiz),
            tooltip: 'Xem ngân sách đã kết thúc',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _periodGroups.isEmpty
          ? _emptyBudget()
          : _budgetSummary(),
    );
  }

  Widget _emptyBudget() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasEnded = _endedBudgets.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.savings_outlined,
              size: 72,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 14),
            Text(
              hasEnded
                  ? 'Không còn ngân sách đang áp dụng'
                  : 'Chưa có ngân sách nào',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasEnded
                  ? 'Nhấn dấu ... để xem các ngân sách đã kết thúc, hoặc tạo ngân sách mới.'
                  : 'Tạo ngân sách để theo dõi tổng ngân sách, tổng chi và thời gian còn lại.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _goToAddBudget,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                minimumSize: const Size(240, 54),
              ),
              child: const Text('Tạo ngân sách'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    final group = _selectedGroup;
    if (group == null) {
      return _emptyBudget();
    }

    final selectedItem = _selectedBudgetItem(group);
    if (selectedItem == null) {
      return _emptyBudget();
    }

    final selectedBudget = selectedItem.budget;

    final totalBudget = selectedBudget.amount;
    final totalSpent = selectedItem.spent;
    final ratio = totalBudget <= 0 ? 0.0 : (totalSpent / totalBudget);
    final clampedRatio = ratio.clamp(0.0, 1.0).toDouble();
    final percent = (ratio * 100).clamp(0, 999).toStringAsFixed(1);
    final overSpent = totalSpent > totalBudget;
    final overSpentAmount = (totalSpent - totalBudget)
        .clamp(0.0, double.infinity)
        .toDouble();
    final isNotStarted = _isFutureStart(selectedBudget.startDate);
    final daysLeft = _daysLeft(selectedBudget.endDate);
    final remaining = (totalBudget - totalSpent).clamp(0.0, double.infinity);
    final screenWidth = MediaQuery.of(context).size.width;
    final amountFontSize = screenWidth < 390 ? 44.0 : 54.0;
    final metricValueFontSize = screenWidth < 390 ? 18.0 : 26.0;
    final metricLabelFontSize = screenWidth < 390 ? 12.0 : 15.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 130),
      child: Column(
        children: [
          if (_periodGroups.length > 1) _periodTabs(),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF374151),
                        child: Icon(
                          Icons.public,
                          size: 17,
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _budgetName(selectedItem),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openBudgetDetail(selectedItem),
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF9CA3AF),
                        ),
                        tooltip: 'Xem chi tiết ngân sách',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 340,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        CustomPaint(
                          size: Size(screenWidth - 56, 260),
                          painter: _HalfArcPainter(
                            progress: clampedRatio,
                            color: overSpent
                                ? const Color(0xFFFF5B61)
                                : const Color(0xFF22C55E),
                          ),
                        ),
                        Positioned(
                          top: 178,
                          child: SizedBox(
                            width: screenWidth - 72,
                            child: Column(
                              children: [
                                Text(
                                  isNotStarted
                                      ? 'Chưa bắt đầu'
                                      : overSpent
                                      ? 'Bội chi'
                                      : 'Số tiền bạn có thể chi',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatMoney(
                                      isNotStarted
                                          ? totalBudget
                                          : (overSpent
                                                ? overSpentAmount
                                                : remaining),
                                    ),
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: (isNotStarted || overSpent)
                                          ? const Color(0xFFFF5B61)
                                          : const Color(0xFF22C55E),
                                      fontSize: amountFontSize,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$percent% tổng chi / tổng ngân sách',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _metricItem(
                          value: _formatCompact(totalBudget),
                          label: 'Tổng ngân sách',
                          valueFontSize: metricValueFontSize,
                          labelFontSize: metricLabelFontSize,
                        ),
                      ),
                      const SizedBox(
                        height: 58,
                        child: VerticalDivider(
                          color: Color(0xFF2D313B),
                          width: 22,
                        ),
                      ),
                      Expanded(
                        child: _metricItem(
                          value: _formatCompact(totalSpent),
                          label: 'Tổng đã chi',
                          valueFontSize: metricValueFontSize,
                          labelFontSize: metricLabelFontSize,
                        ),
                      ),
                      const SizedBox(
                        height: 58,
                        child: VerticalDivider(
                          color: Color(0xFF2D313B),
                          width: 22,
                        ),
                      ),
                      Expanded(
                        child: _metricItem(
                          value: isNotStarted
                              ? 'Chưa bắt đầu'
                              : '$daysLeft ngày',
                          label: 'Đến cuối kỳ',
                          valueFontSize: metricValueFontSize,
                          labelFontSize: metricLabelFontSize,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _goToAddBudget,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      minimumSize: const Size(240, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Tạo Ngân sách',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Áp dụng từ ${DateFormat('dd/MM/yyyy').format(selectedBudget.startDate)} đến ${DateFormat('dd/MM/yyyy').format(selectedBudget.endDate)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _spentByCategorySection(group),
        ],
      ),
    );
  }

  Widget _spentByCategorySection(_BudgetPeriodGroup group) {
    final colorScheme = Theme.of(context).colorScheme;
    final totals = _spentByCategoryByPeriod[group.key] ?? const {};
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalSpent = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Khoản đã chi theo nhóm',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Chưa có khoản chi trong kỳ này',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...entries.map((entry) {
            final ratio = totalSpent <= 0
                ? 0.0
                : (entry.value / totalSpent).clamp(0.0, 1.0);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF1F4A60),
                          child: Icon(
                            _categoryIcon(entry.key),
                            color: const Color(0xFFD1D5DB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMoney(entry.value),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          '${(ratio * 100).toStringAsFixed(1)}% tổng chi',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: const Color(0xFF2A2D38),
                        color: const Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _periodTabs() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBackground = isDark
        ? const Color(0xFF1F2129)
        : colorScheme.surfaceContainerHighest;
    final unselectedLabel = isDark ? Colors.white : Colors.black;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _periodGroups.map((group) {
            final selected = group.key == _selectedPeriodKey;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                label: Text(_tabTitle(group)),
                onSelected: (_) {
                  setState(() {
                    _selectedPeriodKey = group.key;
                  });
                },
                selectedColor: const Color(0xFF22C55E),
                backgroundColor: chipBackground,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF343845),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.black : unselectedLabel,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _categoryIcon(String? category) {
    final name = (category ?? '').toLowerCase();
    if (name.contains('ăn') || name.contains('uong')) return Icons.local_bar;
    if (name.contains('xe') || name.contains('di chuyển')) return Icons.build;
    if (name.contains('mua')) return Icons.shopping_bag;
    if (name.contains('sức khỏe')) return Icons.favorite;
    return Icons.wallet;
  }

  Widget _metricItem({
    required String value,
    required String label,
    required double valueFontSize,
    required double labelFontSize,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: labelFontSize,
          ),
        ),
      ],
    );
  }
}

class _HalfArcPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HalfArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 14.0;
    final centerY = size.height * 0.72;
    final radius = math.min(size.width / 2, centerY) - strokeWidth / 2;
    final center = Offset(size.width / 2, centerY);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF343845);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;

    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);
    canvas.drawArc(rect, math.pi, math.pi * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _HalfArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _BudgetCardData {
  final budget_model.Budget budget;
  final double spent;

  _BudgetCardData({required this.budget, required this.spent});

  bool get isAllGroups =>
      budget.category == null || budget.category!.trim().isEmpty;
}

class _BudgetPeriodGroup {
  final String key;
  final DateTime startDate;
  final DateTime endDate;
  final List<_BudgetCardData> items;

  _BudgetPeriodGroup({
    required this.key,
    required this.startDate,
    required this.endDate,
    required this.items,
  });

  double get totalBudget =>
      items.fold(0.0, (sum, item) => sum + item.budget.amount);

  double get totalSpent => items.fold(0.0, (sum, item) => sum + item.spent);
}
