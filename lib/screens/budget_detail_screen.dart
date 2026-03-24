import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/budget.dart' as budget_model;
import 'add_budget_screen.dart';

class BudgetDetailScreen extends StatefulWidget {
  final int userId;
  final budget_model.Budget budget;

  const BudgetDetailScreen({
    super.key,
    required this.userId,
    required this.budget,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  late budget_model.Budget _budget;
  double _spent = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _budget = widget.budget;
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final spent = await DatabaseHelper.instance
          .getExpenseTotalInRangeForBudget(
            userId: widget.userId,
            startDate: _budget.startDate,
            endDate: _budget.endDate,
            category: _budget.category,
          );

      if (!mounted) return;
      setState(() {
        _spent = spent;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải chi tiết ngân sách: $e')));
    }
  }

  Future<void> _editBudget() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddBudgetScreen(userId: widget.userId, budget: _budget),
      ),
    );

    if (changed == true) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteBudget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa ngân sách'),
        content: const Text('Bạn có chắc chắn muốn xóa ngân sách này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (_budget.id == null) return;

    await DatabaseHelper.instance.deleteBudget(_budget.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String _formatMoney(double value) {
    return NumberFormat('#,###').format(value);
  }

  bool get _isEnded {
    final today = DateTime.now();
    final nowDate = DateTime(today.year, today.month, today.day);
    final end = DateTime(
      _budget.endDate.year,
      _budget.endDate.month,
      _budget.endDate.day,
    );
    return end.isBefore(nowDate);
  }

  bool get _isNotStarted {
    final today = DateTime.now();
    final nowDate = DateTime(today.year, today.month, today.day);
    final start = DateTime(
      _budget.startDate.year,
      _budget.startDate.month,
      _budget.startDate.day,
    );
    return start.isAfter(nowDate);
  }

  int _daysBetween(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  int _daysElapsed(DateTime start, DateTime end) {
    final today = DateTime.now();
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    final t = DateTime(today.year, today.month, today.day);

    if (t.isBefore(s)) return 0;
    if (t.isAfter(e)) return _daysBetween(s, e);
    return t.difference(s).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = colorScheme.surfaceContainerHigh;
    final mutedText = colorScheme.onSurfaceVariant;
    final primaryText = colorScheme.onSurface;
    final totalDays = _daysBetween(_budget.startDate, _budget.endDate);
    final elapsedDays = _daysElapsed(_budget.startDate, _budget.endDate);
    final remaining = (_budget.amount - _spent)
        .clamp(0.0, double.infinity)
        .toDouble();
    final dailyBudget = totalDays > 0 ? _budget.amount / totalDays : 0.0;
    final actualDaily = elapsedDays > 0 ? _spent / elapsedDays : 0.0;
    final predicted = actualDaily * totalDays;
    final ratio = _budget.amount <= 0
        ? 0.0
        : (_spent / _budget.amount).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        title: const Text(
          'Xem ngân sách',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!_isEnded) ...[
            IconButton(
              onPressed: _editBudget,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Sửa',
            ),
            IconButton(
              onPressed: _deleteBudget,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Xóa',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _budget.category ?? 'Tổng cộng',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatMoney(_budget.amount),
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Đã chi\n${_formatMoney(_spent)}',
                          style: TextStyle(
                            color: mutedText,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Còn lại\n${_formatMoney(remaining)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 12,
                      backgroundColor: cardColor,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${DateFormat('dd/MM').format(_budget.startDate)} - ${DateFormat('dd/MM').format(_budget.endDate)}',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isNotStarted)
                    Text(
                      'Chưa bắt đầu',
                      style: TextStyle(color: mutedText, fontSize: 18),
                    )
                  else
                    Text(
                      'Còn ${(_budget.endDate.difference(DateTime.now()).inDays + 1).clamp(0, 9999)} ngày',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 18,
                      ),
                    ),
                  const SizedBox(height: 24),
                  _statRow('Nên chi hàng ngày', _formatMoney(dailyBudget)),
                  _statRow('Dự kiến chi tiêu', _formatMoney(predicted)),
                  _statRow(
                    'Thực tế chi tiêu hàng ngày',
                    _formatMoney(actualDaily),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statRow(String title, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 18,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
