import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/budget.dart' as budget_model;

class AddBudgetScreen extends StatefulWidget {
  final int userId;
  final budget_model.Budget? budget;

  const AddBudgetScreen({super.key, required this.userId, this.budget});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final TextEditingController _amountController = TextEditingController();

  final List<String> _categories = const [
    'Tất cả các nhóm',
    'Ăn uống',
    'Di chuyển',
    'Mua sắm',
    'Giải trí',
    'Sức khỏe',
    'Học tập',
    'Hóa đơn',
    'Nhà ở',
    'Khác',
  ];

  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedCategory = 'Tất cả các nhóm';
  bool _repeatMonthly = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      final current = widget.budget!;
      _selectedCategory = current.category ?? 'Tất cả các nhóm';
      _amountController.text = current.amount.toStringAsFixed(
        current.amount % 1 == 0 ? 0 : 2,
      );
      _startDate = current.startDate;
      _endDate = current.endDate;
      _repeatMonthly = current.repeatMonthly;
    } else {
      final now = DateTime.now();
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    }
  }

  String _formatMoney(double value) {
    return NumberFormat('#,###').format(value);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _endDate = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            23,
            59,
            59,
          );
        }
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _saveBudget() async {
    final rawAmount = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền ngân sách hợp lệ')),
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày kết thúc phải sau ngày bắt đầu')),
      );
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDateOnly = DateTime(_endDate.year, _endDate.month, _endDate.day);
    if (endDateOnly.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể lưu ngân sách có ngày kết thúc trong quá khứ',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final budget = budget_model.Budget(
        id: widget.budget?.id,
        userId: widget.userId,
        category: _selectedCategory == 'Tất cả các nhóm'
            ? null
            : _selectedCategory,
        amount: amount,
        startDate: _startDate,
        endDate: _endDate,
        repeatMonthly: _repeatMonthly,
        createdAt: widget.budget?.createdAt ?? DateTime.now(),
      );

      if (widget.budget == null) {
        await DatabaseHelper.instance.insertBudget(budget);
      } else {
        await DatabaseHelper.instance.updateBudget(budget);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể lưu ngân sách: $e')));
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _panel({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF17181D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2F3442) : const Color(0xFFDCEAD7),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final inputBg = isDark ? const Color(0xFF20222A) : const Color(0xFFF3F4F6);
    final primaryText = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryText = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: primaryText,
        elevation: 0,
        title: Text(
          widget.budget == null ? 'Thêm ngân sách' : 'Sửa ngân sách',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn nhóm',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: isDark ? const Color(0xFF17181D) : Colors.white,
                      style: TextStyle(color: primaryText),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Số tiền (VND)',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      onChanged: (_) {
                        setState(() {});
                      },
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(Icons.calendar_month, color: secondaryText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Thời gian (${DateFormat('dd/MM').format(_startDate)} - ${DateFormat('dd/MM').format(_endDate)})',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryText,
                              side: const BorderSide(color: Color(0xFF4B5563)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_startDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(isStart: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryText,
                              side: const BorderSide(color: Color(0xFF4B5563)),
                              minimumSize: const Size(0, 44),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_endDate),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _panel(
                child: CheckboxListTile(
                  value: _repeatMonthly,
                  onChanged: (value) {
                    setState(() {
                      _repeatMonthly = value ?? false;
                    });
                  },
                  side: const BorderSide(color: Color(0xFF9CA3AF)),
                  checkColor: Colors.black,
                  activeColor: const Color(0xFF22C55E),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Lặp lại ngân sách này',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Ngân sách được tự động lặp lại ở kỳ hạn tiếp theo.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveBudget,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    minimumSize: const Size(0, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Lưu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (_amountController.text.trim().isNotEmpty)
                Text(
                  'Tương đương ${_formatMoney(double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0)} đ',
                  style: const TextStyle(color: Color(0xFF9CA3AF)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
