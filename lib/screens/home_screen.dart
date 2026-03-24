import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/transaction.dart' as model;
import '../models/budget.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int refreshToken;
  final VoidCallback? onNavigateToTransactionBook;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.username,
    this.refreshToken = 0,
    this.onNavigateToTransactionBook,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNarrow(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 390;
  }

  double _totalExpense = 0;
  double _totalIncome = 0;
  double _balance = 0;
  double _currentMonthExpense = 0;
  double _currentMonthIncome = 0;
  double _averagePreviousThreeMonthsExpense = 0;
  List<_CategoryComparison> _categoryComparisons = [];
  List<_MonthlyTrendPoint> _expenseTrend = [];
  List<_MonthlyTrendPoint> _incomeTrend = [];
  Map<String, double> _weeklyTopSpending = {};
  Map<String, double> _monthlyTopSpending = {};
  List<model.Transaction> _recentTransactions = [];
  bool _isTopSpendingWeekly = false;
  bool _isWeeklyReport = false;
  int _reportPage = 0;
  double _currentWeekExpense = 0;
  double _previousWeekExpense = 0;
  double _previousMonthExpense = 0;
  List<_TrendPoint> _weekTrend = [];
  List<_TrendPoint> _monthTrend = [];
  bool _isBalanceVisible = true;
  bool _isLoading = true;
  List<_BudgetNotification> _notifications = [];

  String _formatNumber(double number) {
    return NumberFormat('#,###').format(number);
  }

  @override
  void initState() {
    super.initState();
    _loadTransactionData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadTransactionData();
    }
  }

  Future<void> _loadTransactionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(microseconds: 1));
      final previousThreeStart = DateTime(now.year, now.month - 3, 1);
      final previousThreeEnd = monthStart.subtract(
        const Duration(microseconds: 1),
      );
      final trendStart = DateTime(now.year, now.month - 5, 1);
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final weekEnd = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 7,
      ).subtract(const Duration(microseconds: 1));
      final previousWeekStart = weekStart.subtract(const Duration(days: 7));
      final previousWeekEnd = weekStart.subtract(
        const Duration(microseconds: 1),
      );
      final previousMonthStart = DateTime(now.year, now.month - 1, 1);
      final previousMonthEnd = monthStart.subtract(
        const Duration(microseconds: 1),
      );

      final stats = await Future.wait<dynamic>([
        DatabaseHelper.instance.getTotalByUserAndType(
          widget.userId,
          model.TransactionType.expense,
        ),
        DatabaseHelper.instance.getTotalByUserAndType(
          widget.userId,
          model.TransactionType.income,
        ),
        DatabaseHelper.instance.getTotalByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          monthStart,
          monthEnd,
        ),
        DatabaseHelper.instance.getTotalByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.income,
          monthStart,
          monthEnd,
        ),
        DatabaseHelper.instance.getTotalByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          previousThreeStart,
          previousThreeEnd,
        ),
        DatabaseHelper.instance.getCategoryTotalsByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          monthStart,
          monthEnd,
        ),
        DatabaseHelper.instance.getCategoryTotalsByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          previousThreeStart,
          previousThreeEnd,
        ),
        DatabaseHelper.instance.getMonthlyTotalsByUserAndType(
          widget.userId,
          model.TransactionType.expense,
          trendStart,
          monthStart,
        ),
        DatabaseHelper.instance.getMonthlyTotalsByUserAndType(
          widget.userId,
          model.TransactionType.income,
          trendStart,
          monthStart,
        ),
        DatabaseHelper.instance.getCategoryTotalsByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          weekStart,
          weekEnd,
        ),
        DatabaseHelper.instance.getTransactionsByUser(widget.userId),
        DatabaseHelper.instance.getTotalByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          weekStart,
          weekEnd,
        ),
        DatabaseHelper.instance.getTotalByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          previousWeekStart,
          previousWeekEnd,
        ),
        DatabaseHelper.instance.getTotalByUserAndTypeInRange(
          widget.userId,
          model.TransactionType.expense,
          previousMonthStart,
          previousMonthEnd,
        ),
      ]);

      final totalExpense = stats[0] as double;
      final totalIncome = stats[1] as double;
      final monthExpense = stats[2] as double;
      final monthIncome = stats[3] as double;
      final previousThreeExpenseTotal = stats[4] as double;
      final categoryCurrent = stats[5] as Map<String, double>;
      final categoryPrevious = stats[6] as Map<String, double>;
      final expenseByMonth = stats[7] as Map<String, double>;
      final incomeByMonth = stats[8] as Map<String, double>;
      final categoryWeek = stats[9] as Map<String, double>;
      final allTransactions = stats[10] as List<model.Transaction>;
      final currentWeekExpense = stats[11] as double;
      final previousWeekExpense = stats[12] as double;
      final previousMonthExpense = stats[13] as double;
      final recentTransactions = allTransactions.take(5).toList();

      final weekTrend = _buildTrendPoints(
        allTransactions,
        weekStart,
        weekEnd,
        DateFormat('E'),
      );
      final monthTrend = _buildTrendPoints(
        allTransactions,
        monthStart,
        monthEnd,
        DateFormat('dd/MM'),
      );

      // Check for budget overruns
      final budgets = await DatabaseHelper.instance.getBudgetsByUser(
        widget.userId,
      );
      final notifications = <_BudgetNotification>[];

      for (final budget in budgets) {
        final now = DateTime.now();
        if (budget.endDate.isBefore(now)) continue;

        final spent = await DatabaseHelper.instance.getExpenseTotalInRangeForBudget(
          userId: widget.userId,
          startDate: budget.startDate,
          endDate: budget.endDate,
          category: budget.category,
        );

        if (spent > budget.amount) {
          notifications.add(_BudgetNotification(
            category: budget.category ?? 'Tổng chi tiêu',
            budgetAmount: budget.amount,
            spentAmount: spent,
            startDate: budget.startDate,
            endDate: budget.endDate,
          ));
        }
      }

      setState(() {
        _totalExpense = totalExpense;
        _totalIncome = totalIncome;
        _currentMonthExpense = monthExpense;
        _currentMonthIncome = monthIncome;
        _averagePreviousThreeMonthsExpense = previousThreeExpenseTotal / 3;
        _categoryComparisons = _buildCategoryComparisons(
          categoryCurrent,
          categoryPrevious,
        );
        _expenseTrend = _toTrendPoints(expenseByMonth);
        _incomeTrend = _toTrendPoints(incomeByMonth);
        _weeklyTopSpending = categoryWeek;
        _monthlyTopSpending = categoryCurrent;
        _recentTransactions = recentTransactions;
        _currentWeekExpense = currentWeekExpense;
        _previousWeekExpense = previousWeekExpense;
        _previousMonthExpense = previousMonthExpense;
        _weekTrend = weekTrend;
        _monthTrend = monthTrend;
        _balance = _totalIncome - _totalExpense;
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<_CategoryComparison> _buildCategoryComparisons(
    Map<String, double> current,
    Map<String, double> previousThreeMonths,
  ) {
    final categories = <String>{...current.keys, ...previousThreeMonths.keys};
    final comparisons = categories
        .map(
          (category) => _CategoryComparison(
            category: category,
            currentMonth: current[category] ?? 0,
            previousThreeMonthAverage: (previousThreeMonths[category] ?? 0) / 3,
          ),
        )
        .toList();

    comparisons.sort((a, b) {
      final aPeak = a.currentMonth > a.previousThreeMonthAverage
          ? a.currentMonth
          : a.previousThreeMonthAverage;
      final bPeak = b.currentMonth > b.previousThreeMonthAverage
          ? b.currentMonth
          : b.previousThreeMonthAverage;
      return bPeak.compareTo(aPeak);
    });

    return comparisons.take(5).toList();
  }

  List<_MonthlyTrendPoint> _toTrendPoints(Map<String, double> totals) {
    return totals.entries
        .map(
          (entry) =>
              _MonthlyTrendPoint(monthKey: entry.key, amount: entry.value),
        )
        .toList();
  }

  String _formatMonthLabel(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;
    return '${parts[1]}/${parts[0].substring(2)}';
  }

  int _monthlyChangePercent() {
    if (_averagePreviousThreeMonthsExpense <= 0) {
      return _currentMonthExpense > 0 ? 100 : 0;
    }
    return (((_currentMonthExpense - _averagePreviousThreeMonthsExpense) /
                _averagePreviousThreeMonthsExpense) *
            100)
        .round();
  }

  Widget _sectionTitle(String title, String actionText) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2D7D46),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            actionText,
            style: const TextStyle(
              color: Color(0xFF28C75C),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _walletCard(BuildContext context) {
    final isNarrow = _isNarrow(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDCEAD7)),
      ),
      child: Column(
        children: [
          _sectionTitle('Ví của tôi', 'Xem tất cả'),
          const Divider(color: Color(0xFFDCEAD7), height: 16),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF8F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF34C759),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Tiền mặt',
                  style: TextStyle(
                    color: const Color(0xFF1F2937),
                    fontSize: isNarrow ? 20 : 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  '${NumberFormat('#,###').format(_balance)} đ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF2D7D46),
                    fontSize: isNarrow ? 18 : 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthlyReportCard(BuildContext context) {
    final isNarrow = _isNarrow(context);
    final monthlyTotal = _currentMonthExpense + _currentMonthIncome;
    final expenseFlex = monthlyTotal <= 0
        ? 1
        : ((_currentMonthExpense / monthlyTotal) * 100).round().clamp(1, 99)
              as int;
    final incomeFlex = monthlyTotal <= 0 ? 1 : 100 - expenseFlex;
    final changePercent = _monthlyChangePercent();
    final isSpendingUp = changePercent > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDCEAD7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Tổng đã chi',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_formatNumber(_currentMonthExpense)} đ',
                          maxLines: 1,
                          style: TextStyle(
                            color: Color(0xFF2D7D46),
                            fontSize: isNarrow ? 24 : 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Tổng thu',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_formatNumber(_currentMonthIncome)} đ',
                          maxLines: 1,
                          style: TextStyle(
                            color: Color(0xFF34C759),
                            fontSize: isNarrow ? 24 : 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: expenseFlex,
                child: Divider(color: Color(0xFF34C759), thickness: 3),
              ),
              Expanded(
                flex: incomeFlex,
                child: Divider(color: Color(0xFF8AA18F), thickness: 3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isSpendingUp ? Icons.trending_up : Icons.trending_down,
                color: isSpendingUp
                    ? const Color(0xFFB42318)
                    : const Color(0xFF2D7D46),
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Chi tiêu tháng này ${isSpendingUp ? 'cao hơn' : 'thấp hơn'} ${changePercent.abs()}% so với trung bình 3 tháng trước',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _categoryComparisonPanel(),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Icon(Icons.circle, color: Color(0xFF34C759), size: 16),
              Text(
                'Tháng này',
                style: TextStyle(
                  color: const Color(0xFF6B7280),
                  fontSize: isNarrow ? 14 : 16,
                ),
              ),
              SizedBox(width: isNarrow ? 2 : 20),
              const Icon(Icons.circle, color: Color(0xFF8AA18F), size: 16),
              Text(
                'Trung bình 3 tháng trước',
                style: TextStyle(
                  color: const Color(0xFF6B7280),
                  fontSize: isNarrow ? 14 : 16,
                ),
              ),
              const SizedBox(width: 2),
              const CircleAvatar(
                radius: 11,
                backgroundColor: Color(0xFF34C759),
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Báo cáo xu hướng 6 tháng',
            style: TextStyle(
              color: const Color(0xFF28C75C),
              fontSize: isNarrow ? 28 : 34,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _trendChart(isNarrow),
        ],
      ),
    );
  }

  Widget _categoryComparisonPanel() {
    if (_categoryComparisons.isEmpty) {
      return Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDCEAD7)),
        ),
        child: const Center(
          child: Text(
            'Nhập giao dịch chi tiêu để xem thống kê danh mục',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    double peak = 0;
    for (final item in _categoryComparisons) {
      if (item.currentMonth > peak) peak = item.currentMonth;
      if (item.previousThreeMonthAverage > peak)
        peak = item.previousThreeMonthAverage;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCEAD7)),
      ),
      child: Column(
        children: _categoryComparisons
            .map((item) => _categoryComparisonRow(item, peak == 0 ? 1 : peak))
            .toList(),
      ),
    );
  }

  Widget _categoryComparisonRow(_CategoryComparison item, double peak) {
    final currentRatio = (item.currentMonth / peak).clamp(0.0, 1.0);
    final averageRatio = (item.previousThreeMonthAverage / peak).clamp(
      0.0,
      1.0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${_formatNumber(item.currentMonth)} đ',
                style: const TextStyle(
                  color: Color(0xFF34C759),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: averageRatio,
              backgroundColor: const Color(0xFFE9EEF0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8AA18F)),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: currentRatio,
              backgroundColor: const Color(0xFFE9EEF0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF34C759)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendChart(bool isNarrow) {
    if (_expenseTrend.isEmpty || _incomeTrend.isEmpty) {
      return const Text(
        'Chưa có dữ liệu xu hướng',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
      );
    }

    double peak = 0;
    for (var i = 0; i < _expenseTrend.length; i++) {
      if (_expenseTrend[i].amount > peak) peak = _expenseTrend[i].amount;
      if (_incomeTrend[i].amount > peak) peak = _incomeTrend[i].amount;
    }
    final safePeak = peak == 0 ? 1 : peak;

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_expenseTrend.length, (index) {
              final expenseHeight =
                  ((_expenseTrend[index].amount / safePeak) * 96).clamp(
                    2.0,
                    96.0,
                  );
              final incomeHeight =
                  ((_incomeTrend[index].amount / safePeak) * 96).clamp(
                    2.0,
                    96.0,
                  );

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              height: expenseHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Container(
                              height: incomeHeight,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8AA18F),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatMonthLabel(_expenseTrend[index].monthKey),
                        style: TextStyle(
                          color: const Color(0xFF6B7280),
                          fontSize: isNarrow ? 10 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, color: Color(0xFF34C759), size: 12),
            SizedBox(width: 6),
            Text(
              'Chi tiêu',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            SizedBox(width: 16),
            Icon(Icons.circle, color: Color(0xFF8AA18F), size: 12),
            SizedBox(width: 6),
            Text(
              'Thu nhập',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _premiumBanner(BuildContext context) {
    final isNarrow = _isNarrow(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF77D88F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Khai thác tối đa\nMoneyLover với Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '-50%',
            style: TextStyle(
              color: const Color(0xFFEFF8F1),
              fontSize: isNarrow ? 50 : 68,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  List<_TrendPoint> _buildTrendPoints(
    List<model.Transaction> transactions,
    DateTime start,
    DateTime end,
    DateFormat labelFormat,
  ) {
    final map = <String, double>{};
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!cursor.isAfter(last)) {
      final key = DateFormat('yyyy-MM-dd').format(cursor);
      map[key] = 0;
      cursor = cursor.add(const Duration(days: 1));
    }

    for (final tx in transactions) {
      if (tx.type != model.TransactionType.expense) continue;
      if (tx.date.isBefore(start) || tx.date.isAfter(end)) continue;
      final key = DateFormat('yyyy-MM-dd').format(tx.date);
      map[key] = (map[key] ?? 0) + tx.amount;
    }

    return map.entries
        .map(
          (entry) => _TrendPoint(
            label: labelFormat.format(DateTime.parse(entry.key)),
            amount: entry.value,
          ),
        )
        .toList();
  }

  double get _currentPeriodExpense =>
      _isWeeklyReport ? _currentWeekExpense : _currentMonthExpense;

  double get _previousPeriodExpense =>
      _isWeeklyReport ? _previousWeekExpense : _previousMonthExpense;

  int get _reportChangePercent {
    final previous = _previousPeriodExpense;
    if (previous <= 0) return _currentPeriodExpense > 0 ? 100 : 0;
    return (((_currentPeriodExpense - previous) / previous) * 100).round();
  }

  List<_TrendPoint> get _activeTrend =>
      _isWeeklyReport ? _weekTrend : _monthTrend;

  Widget _reportSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF17181D) : Colors.white;
    final altSurface = isDark
        ? const Color(0xFF232632)
        : const Color(0xFFF3F4F6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2F3442) : const Color(0xFFDCEAD7),
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: altSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _periodToggle(
                    label: 'Tuần',
                    selected: _isWeeklyReport,
                    onTap: () {
                      setState(() {
                        _isWeeklyReport = true;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _periodToggle(
                    label: 'Tháng',
                    selected: !_isWeeklyReport,
                    onTap: () {
                      setState(() {
                        _isWeeklyReport = false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _reportPage == 0 ? _spendingReportPage() : _trendReportPage(),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _reportPage = (_reportPage - 1) < 0 ? 1 : (_reportPage - 1);
                  });
                },
                icon: const Icon(Icons.chevron_left, color: Color(0xFF22C55E)),
              ),
              Expanded(
                child: Text(
                  _reportPage == 0 ? 'Báo cáo chi tiêu' : 'Báo cáo xu hướng',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF22C55E),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _reportPage = (_reportPage + 1) % 2;
                  });
                },
                icon: const Icon(Icons.chevron_right, color: Color(0xFF22C55E)),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _reportPage == index
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spendingReportPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final chipBackground = isDark
        ? const Color(0xFF2E313D)
        : const Color(0xFFE5E7EB);

    final changePercent = _reportChangePercent;
    final isUp = changePercent > 0;
    final maxValue = _currentPeriodExpense > _previousPeriodExpense
        ? _currentPeriodExpense
        : _previousPeriodExpense;
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final previousRatio = (_previousPeriodExpense / safeMax).clamp(0.0, 1.0);
    final currentRatio = (_currentPeriodExpense / safeMax).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_formatNumber(_currentPeriodExpense)} đ',
          style: TextStyle(
            color: primaryText,
            fontSize: 48,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'Tổng chi ${_isWeeklyReport ? 'tuần này' : 'tháng này'}',
              style: TextStyle(color: secondaryText, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: chipBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                isUp ? '+' : '-',
                style: TextStyle(
                  color: isUp
                      ? const Color(0xFFFF5B61)
                      : const Color(0xFFFAC515),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${changePercent.abs()}%',
              style: const TextStyle(
                color: Color(0xFFFAC515),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 120 * previousRatio,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isWeeklyReport ? 'Tuần trước' : 'Tháng trước',
                      style: TextStyle(color: secondaryText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 120 * currentRatio,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B61),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isWeeklyReport ? 'Tuần này' : 'Tháng này',
                      style: TextStyle(color: secondaryText, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trendReportPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    final points = _activeTrend;
    final hasData = points.any((p) => p.amount > 0);
    final peak = points.fold<double>(
      0,
      (max, p) => p.amount > max ? p.amount : max,
    );
    final safePeak = peak <= 0 ? 1.0 : peak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isWeeklyReport
                    ? 'Xu hướng chi tiêu tuần'
                    : 'Xu hướng chi tiêu tháng',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${_formatNumber(peak)} đ',
              style: const TextStyle(color: Color(0xFFFF5B61)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: hasData
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: points.map((p) {
                    final h = ((p.amount / safePeak) * 120).clamp(2.0, 120.0);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5B61),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              : const Center(
                  child: Text(
                    'Chưa có dữ liệu xu hướng',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (points.isNotEmpty)
              Text(
                points.first.label,
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
            const Spacer(),
            if (points.isNotEmpty)
              Text(
                points.last.label,
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }

  Map<String, double> get _activeTopSpending {
    return _isTopSpendingWeekly ? _weeklyTopSpending : _monthlyTopSpending;
  }

  IconData _categoryIcon(String? category) {
    final name = (category ?? '').toLowerCase();
    if (name.contains('ăn') || name.contains('uong')) return Icons.local_bar;
    if (name.contains('xe') || name.contains('di chuyển')) return Icons.build;
    if (name.contains('mua')) return Icons.shopping_bag;
    if (name.contains('giải trí')) return Icons.movie;
    return Icons.wallet;
  }

  Widget _topSpendingSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF17181D) : Colors.white;
    final altSurface = isDark
        ? const Color(0xFF232632)
        : const Color(0xFFF3F4F6);
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    final entries = _activeTopSpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTotal = entries.fold<double>(0, (sum, item) => sum + item.value);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2F3442) : const Color(0xFFDCEAD7),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Chi tiêu nhiều nhất',
            style: TextStyle(
              color: primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: altSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _periodToggle(
                    label: 'Tuần',
                    selected: _isTopSpendingWeekly,
                    onTap: () {
                      setState(() {
                        _isTopSpendingWeekly = true;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _periodToggle(
                    label: 'Tháng',
                    selected: !_isTopSpendingWeekly,
                    onTap: () {
                      setState(() {
                        _isTopSpendingWeekly = false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Chưa có khoản chi',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...entries.take(3).map((entry) {
              final ratio = topTotal <= 0
                  ? 0.0
                  : (entry.value / topTotal).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1F4A60),
                      child: Icon(
                        _categoryIcon(entry.key),
                        color: const Color(0xFFD1D5DB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_formatNumber(entry.value)} đ',
                            style: TextStyle(color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFFFF5B61),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _periodToggle({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF343845) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF1F2937))
                : const Color(0xFF9CA3AF),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _recentTransactionsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF17181D) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2F3442) : const Color(0xFFDCEAD7),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Giao dịch gần đây',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onNavigateToTransactionBook,
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(color: Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
          if (_recentTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Chưa có giao dịch',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ..._recentTransactions.map((tx) {
              final isExpense = tx.type == model.TransactionType.expense;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1F4A60),
                      child: Icon(
                        _categoryIcon(tx.category),
                        color: const Color(0xFFD1D5DB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.category?.isNotEmpty == true
                                ? tx.category!
                                : 'Khác',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            DateFormat("dd 'tháng' M yyyy").format(tx.date),
                            style: TextStyle(color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatNumber(tx.amount),
                      style: TextStyle(
                        color: isExpense
                            ? const Color(0xFFFF5B61)
                            : const Color(0xFF22A6F2),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF17181D) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFB42318), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thông báo vượt ngân sách',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: secondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final overAmount = notification.spentAmount -
                        notification.budgetAmount;
                    final overPercent = ((overAmount /
                                notification.budgetAmount) *
                            100)
                        .round();

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB42318).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFB42318).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.category,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Ngân sách: ${_formatNumber(notification.budgetAmount)} đ',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Đã chi: ${_formatNumber(notification.spentAmount)} đ',
                                  style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB42318),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Vượt ${_formatNumber(overAmount)} đ ($overPercent%)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = _isNarrow(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isBalanceVisible
                                ? '${NumberFormat('#,###').format(_balance)} đ'
                                : '•••••• đ',
                            style: TextStyle(
                              color: const Color(0xFF2D7D46),
                              fontSize: isNarrow ? 36 : 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isBalanceVisible = !_isBalanceVisible;
                          });
                        },
                        icon: Icon(
                          _isBalanceVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF2D7D46),
                          size: isNarrow ? 28 : 32,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(userId: widget.userId),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.search,
                    color: const Color(0xFF2D7D46),
                    size: isNarrow ? 32 : 38,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_notifications.isNotEmpty) {
                          _showNotificationsBottomSheet(context);
                        }
                      },
                      icon: Icon(
                        Icons.notifications_none,
                        color: const Color(0xFF2D7D46),
                        size: isNarrow ? 32 : 38,
                      ),
                    ),
                    if (_notifications.isNotEmpty)
                      Positioned(
                        right: 5,
                        top: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFB42318),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_notifications.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  'Tổng số dư',
                  style: TextStyle(
                    color: const Color(0xFF6B7280),
                    fontSize: isNarrow ? 16 : 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF34C759),
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('Báo cáo tháng này', 'Xem báo cáo'),
            _reportSection(),
            const SizedBox(height: 18),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _topSpendingSection(),
              const SizedBox(height: 18),
              _recentTransactionsSection(),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryComparison {
  final String category;
  final double currentMonth;
  final double previousThreeMonthAverage;

  const _CategoryComparison({
    required this.category,
    required this.currentMonth,
    required this.previousThreeMonthAverage,
  });
}

class _MonthlyTrendPoint {
  final String monthKey;
  final double amount;

  const _MonthlyTrendPoint({required this.monthKey, required this.amount});
}

class _TrendPoint {
  final String label;
  final double amount;

  const _TrendPoint({required this.label, required this.amount});
}

class _BudgetNotification {
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final DateTime startDate;
  final DateTime endDate;

  const _BudgetNotification({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.startDate,
    required this.endDate,
  });
}
