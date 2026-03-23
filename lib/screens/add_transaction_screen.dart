import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/transaction.dart' as model;

class AddTransactionScreen extends StatefulWidget {
  final int userId;
  final model.Transaction? transaction;

  const AddTransactionScreen({super.key, required this.userId, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  model.TransactionType _selectedType = model.TransactionType.expense;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  
  // Calculator state
  String _calculatorExpression = '0';
  double _currentAmount = 0;
  bool _hasEvaluatedExpression = false;
  String _displayText = '0';
  bool _isTypeLocked = false;
  
  // Dynamic categories that can be extended
  final List<String> _expenseCategories = [
    'Ăn uống', 'Di chuyển', 'Mua sắm', 'Giải trí', 'Sức khỏe', 
    'Học tập', 'Hóa đơn', 'Nhà ở', 'Khác'
  ];

  final List<String> _incomeCategories = [
    'Lương', 'Thưởng', 'Bán hàng', 'Đầu tư', 'Khác'
  ];
  
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    if (widget.transaction != null) {
      _selectedType = widget.transaction!.type;
      _amountController.text = widget.transaction!.amount.toString();
      _currentAmount = widget.transaction!.amount;
      _calculatorExpression = widget.transaction!.amount.toString();
      _displayText = _formatAmount(_currentAmount);
      _hasEvaluatedExpression = true;
      _isTypeLocked = true;
      _noteController.text = widget.transaction!.note;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
    } else {
      _selectedCategory = _getDefaultCategoryForType(_selectedType);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_selectedDate.isAfter(today)) {
      _selectedDate = today;
    }
  }

  String _getDefaultCategoryForType(model.TransactionType type) {
    switch (type) {
      case model.TransactionType.expense:
        return 'Ăn uống';
      case model.TransactionType.income:
        return 'Lương';
      case model.TransactionType.loan:
        return 'Cho vay';
    }
  }

  void _onTypeChanged(model.TransactionType type) {
    if (_isTypeLocked && _selectedType != type) return;
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      final categories = _currentCategories;
      if (_selectedCategory == null || !categories.contains(_selectedCategory)) {
        _selectedCategory = _getDefaultCategoryForType(type);
      }
    });
  }

  List<String> get _currentCategories {
    switch (_selectedType) {
      case model.TransactionType.expense:
        return _expenseCategories;
      case model.TransactionType.income:
        return _incomeCategories;
      case model.TransactionType.loan:
        return _expenseCategories;
    }
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.##');
    return formatter.format(amount);
  }

  String _toEditableNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  void _lockTypeIfNeeded() {
    if (_isTypeLocked) return;
    _isTypeLocked = true;
  }

  String _formatNumericToken(String token) {
    if (token.isEmpty) return token;

    final isNegative = token.startsWith('-');
    final unsigned = isNegative ? token.substring(1) : token;
    if (unsigned.isEmpty) return token;

    final hasTrailingDot = unsigned.endsWith('.');
    final parts = unsigned.split('.');
    final intPartRaw = parts.first;
    final decimalPart = parts.length > 1 ? parts.sublist(1).join('.') : null;

    final intPart = int.tryParse(intPartRaw);
    if (intPart == null) return token;

    final formattedInt = NumberFormat('#,###').format(intPart);
    final sign = isNegative ? '-' : '';

    if (hasTrailingDot) {
      return '$sign$formattedInt.';
    }
    if (decimalPart != null) {
      return '$sign$formattedInt.$decimalPart';
    }
    return '$sign$formattedInt';
  }

  String _formatExpressionForDisplay(String expr) {
    if (expr.isEmpty) return '0';

    final buffer = StringBuffer();
    final numberBuffer = StringBuffer();

    void flushNumber() {
      if (numberBuffer.isEmpty) return;
      buffer.write(_formatNumericToken(numberBuffer.toString()));
      numberBuffer.clear();
    }

    for (var i = 0; i < expr.length; i++) {
      final ch = expr[i];
      final isNumericChar = RegExp(r'[0-9.]').hasMatch(ch);
      if (isNumericChar) {
        numberBuffer.write(ch);
      } else {
        flushNumber();
        buffer.write(ch);
      }
    }
    flushNumber();

    return buffer.toString();
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (number != 'C') {
        _lockTypeIfNeeded();
      }

      if (number == 'C') {
        _calculatorExpression = '0';
        _currentAmount = 0;
        _hasEvaluatedExpression = false;
      } else if (number == '.') {
        if (_hasEvaluatedExpression) {
          if (_canAppendDot()) {
            _appendToken('.');
          }
          _hasEvaluatedExpression = false;
        } else {
          if (_canAppendDot()) {
            _appendToken('.');
          }
        }
      } else if (number == 'X') {
        _hasEvaluatedExpression = false;
        if (_calculatorExpression.length > 1) {
          _calculatorExpression = _calculatorExpression.substring(0, _calculatorExpression.length - 1);
        } else {
          _calculatorExpression = '0';
        }
      } else if (['+', '-', '×', '÷', 'x'].contains(number)) {
        _hasEvaluatedExpression = false;
        if (_calculatorExpression != '0' && !_isOperatorAtEnd()) {
          _appendToken(number);
        }
      } else if (number == '(' || number == ')') {
        _hasEvaluatedExpression = false;
        if (_calculatorExpression == '0' && number == '(') {
          _calculatorExpression = '(';
        } else {
          _appendToken(number);
        }
      } else if (number == '000') {
        // Add three zeros
        if (_hasEvaluatedExpression) {
          if (_calculatorExpression == '0') {
            _calculatorExpression = '000';
          } else {
            _appendToken('000');
          }
          _hasEvaluatedExpression = false;
        } else {
          _appendToken('000');
        }
      } else {
        // Number input
        if (_hasEvaluatedExpression) {
          if (_calculatorExpression == '0') {
            _calculatorExpression = number;
          } else {
            _appendToken(number);
          }
          _hasEvaluatedExpression = false;
        } else if (_calculatorExpression == '0') {
          _calculatorExpression = number;
        } else {
          _appendToken(number);
        }
      }

      _displayText = _formatExpressionForDisplay(_calculatorExpression);
    });
  }

  void _appendToken(String token) {
    _calculatorExpression = '$_calculatorExpression$token';
  }

  bool _isOperatorAtEnd() {
    if (_calculatorExpression.isEmpty) return false;
    final lastChar = _calculatorExpression[_calculatorExpression.length - 1];
    return ['+', '-', '×', '÷', 'x'].contains(lastChar);
  }

  bool _canAppendDot() {
    if (_calculatorExpression.isEmpty) return true;

    final lastChar = _calculatorExpression[_calculatorExpression.length - 1];
    if (lastChar == ')' || lastChar == '.') return false;

    final lastOpIndex = _calculatorExpression.lastIndexOf(RegExp(r'[+\-×÷x()]'));
    final segment = lastOpIndex >= 0
        ? _calculatorExpression.substring(lastOpIndex + 1)
        : _calculatorExpression;

    return !segment.contains('.');
  }

  void _onEqualsPressed() {
    final expr = _calculatorExpression.trim();

    final validationError = _validateExpression(expr);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    try {
      final result = _evaluateExpressionStrict(expr);
      if (result.isNaN || result.isInfinite) {
        throw const FormatException('Kết quả không hợp lệ');
      }
      if (result < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phép tính ra số âm, vui lòng kiểm tra lại')),
        );
        return;
      }

      setState(() {
        _currentAmount = result;
        _amountController.text = result.toString();
        _displayText = _formatAmount(result);
        _calculatorExpression = _toEditableNumber(result);
        _hasEvaluatedExpression = true;
        _lockTypeIfNeeded();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phép tính không hợp lệ')),
      );
    }
  }

  String? _validateExpression(String expr) {
    if (expr.isEmpty) return 'Vui lòng nhập phép tính';

    int balance = 0;
    for (final ch in expr.split('')) {
      if (ch == '(') balance++;
      if (ch == ')') balance--;
      if (balance < 0) return 'Thiếu dấu ngoặc mở (';
    }
    if (balance != 0) return 'Thiếu dấu ngoặc đóng )';

    final normalized = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('x', '*')
        .replaceAll(' ', '');

    if (RegExp(r'[+\-*/]$').hasMatch(normalized)) {
      return 'Biểu thức kết thúc bằng toán tử';
    }
    if (RegExp(r'^[+*/]').hasMatch(normalized)) {
      return 'Biểu thức bắt đầu bằng toán tử';
    }
    if (RegExp(r'[+\-*/]{2,}').hasMatch(normalized)) {
      return 'Toán tử không hợp lệ';
    }

    // Only allow digits, parentheses, and operators
    if (!RegExp(r'^[0-9+\-*/().]*$').hasMatch(normalized)) {
      return 'Có ký tự không hợp lệ';
    }

    return null;
  }

  double _evaluateExpressionStrict(String expr) {
    final tokens = _tokenize(expr);
    final rpn = _toRpn(tokens);
    return _evalRpn(rpn);
  }

  List<String> _tokenize(String expr) {
    final normalized = expr
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('x', '*')
        .replaceAll(' ', '');

    final tokens = <String>[];
    final buffer = StringBuffer();

    void flushNumber() {
      if (buffer.isNotEmpty) {
        tokens.add(buffer.toString());
        buffer.clear();
      }
    }

    for (int i = 0; i < normalized.length; i++) {
      final ch = normalized[i];
      final isDigit = RegExp(r'\d').hasMatch(ch);
      if (isDigit || ch == '.') {
        buffer.write(ch);
        continue;
      }

      flushNumber();

      if ('()+-*/'.contains(ch)) {
        // unary minus
        if (ch == '-' && (tokens.isEmpty || '()+-*/'.contains(tokens.last) && tokens.last != ')')) {
          buffer.write('-');
          continue;
        }
        tokens.add(ch);
      } else {
        throw const FormatException('Invalid token');
      }
    }
    flushNumber();
    return tokens;
  }

  List<String> _toRpn(List<String> tokens) {
    final out = <String>[];
    final ops = <String>[];

    int precedence(String op) {
      switch (op) {
        case '+':
        case '-':
          return 1;
        case '*':
        case '/':
          return 2;
      }
      return 0;
    }

    bool isOp(String t) => t == '+' || t == '-' || t == '*' || t == '/';

    for (final t in tokens) {
      if (isOp(t)) {
        while (ops.isNotEmpty && isOp(ops.last) && precedence(ops.last) >= precedence(t)) {
          out.add(ops.removeLast());
        }
        ops.add(t);
      } else if (t == '(') {
        ops.add(t);
      } else if (t == ')') {
        while (ops.isNotEmpty && ops.last != '(') {
          out.add(ops.removeLast());
        }
        if (ops.isEmpty || ops.last != '(') {
          throw const FormatException('Mismatched parentheses');
        }
        ops.removeLast();
      } else {
        // number
        out.add(t);
      }
    }

    while (ops.isNotEmpty) {
      final op = ops.removeLast();
      if (op == '(' || op == ')') {
        throw const FormatException('Mismatched parentheses');
      }
      out.add(op);
    }
    return out;
  }

  double _evalRpn(List<String> rpn) {
    final stack = <double>[];

    for (final t in rpn) {
      if (t == '+' || t == '-' || t == '*' || t == '/') {
        if (stack.length < 2) throw const FormatException('Bad expression');
        final b = stack.removeLast();
        final a = stack.removeLast();
        switch (t) {
          case '+':
            stack.add(a + b);
            break;
          case '-':
            stack.add(a - b);
            break;
          case '*':
            stack.add(a * b);
            break;
          case '/':
            if (b == 0) throw const FormatException('Divide by zero');
            stack.add(a / b);
            break;
        }
      } else {
        final v = double.tryParse(t);
        if (v == null) throw const FormatException('Bad number');
        stack.add(v);
      }
    }
    if (stack.length != 1) throw const FormatException('Bad expression');
    return stack.single;
  }

  
  Future<void> _saveTransaction() async {
    if (!_hasEvaluatedExpression) {
      final raw = _calculatorExpression.replaceAll(',', '').trim();
      final isPlainNumber = RegExp(r'^\d+(?:\.\d+)?$').hasMatch(raw);
      if (isPlainNumber) {
        final parsed = double.tryParse(raw) ?? 0;
        if (parsed > 0) {
          _currentAmount = parsed;
          _displayText = _formatAmount(parsed);
          _hasEvaluatedExpression = true;
        }
      }
    }

    final amount = _currentAmount;
    
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }

    if (!_hasEvaluatedExpression) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng bấm = để tính ra số tiền')),
      );
      return;
    }

    final transaction = model.Transaction(
      id: widget.transaction?.id,
      type: _selectedType,
      amount: amount,
      category: _selectedCategory,
      note: _noteController.text,
      date: _selectedDate,
      userId: widget.userId,
    );

    try {
      if (widget.transaction?.id != null) {
        await DatabaseHelper.instance.updateTransaction(transaction);
      } else {
        await DatabaseHelper.instance.insertTransaction(transaction);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF34C759),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Thêm giao dịch',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF34C759),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTypeTab(
                    label: 'Khoản chi',
                    type: model.TransactionType.expense,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeTab(
                    label: 'Khoản thu',
                    type: model.TransactionType.income,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tiền mặt',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_displayText VND',
                                  style: const TextStyle(
                                    color: Color(0xFF34C759),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection('Chọn nhóm', _buildCategorySelector()),
                    const SizedBox(height: 16),
                    _buildCalculator(),
                    const SizedBox(height: 16),
                    _buildSection('Thêm ghi chú', _buildNoteInput()),
                    const SizedBox(height: 16),
                    _buildSection('Chọn ngày', _buildDateSelector()),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Lưu',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required model.TransactionType type,
  }) {
    final isSelected = _selectedType == type;
    final isEnabled = !_isTypeLocked || isSelected;
    return GestureDetector(
      onTap: isEnabled ? () => _onTypeChanged(type) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : (isEnabled
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF34C759)
                : (isEnabled ? Colors.white : Colors.white70),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  hintText: 'Chọn nhóm',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _currentCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    if (value != null) {
                      _lockTypeIfNeeded();
                    }
                  });
                },
              ),
            ),
            IconButton(
              onPressed: () => _showAddCategoryDialog(),
              icon: const Icon(Icons.add),
              tooltip: 'Thêm nhóm mới',
            ),
          ],
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm nhóm mới'),
        content: TextField(
          controller: _newCategoryController,
          decoration: const InputDecoration(
            hintText: 'Nhập tên nhóm...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final newCategory = _newCategoryController.text.trim();
              if (newCategory.isNotEmpty) {
                setState(() {
                      final categories = _currentCategories;
                      if (!categories.contains(newCategory)) {
                        categories.add(newCategory);
                  }
                  _selectedCategory = newCategory;
                  _lockTypeIfNeeded();
                  _newCategoryController.clear();
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      onChanged: (value) {
        if (value.trim().isNotEmpty) {
          setState(() {
            _lockTypeIfNeeded();
          });
        }
      },
      decoration: const InputDecoration(
        hintText: 'Nhập ghi chú...',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      maxLines: 2,
    );
  }

  Widget _buildDateSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: today,
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                DateFormat('EEEE, dd/MM/yyyy').format(_selectedDate),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            if (!_selectedDate.isBefore(today)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể chọn ngày trong tương lai')),
              );
              return;
            }
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          onPressed: () async {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: today,
            );
            if (date != null) {
              setState(() {
                _selectedDate = date;
              });
            }
          },
          icon: const Icon(Icons.calendar_today),
        ),
      ],
    );
  }

  Widget _buildCalculator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildCalcButton('(', () => _onNumberPressed('('), isOperator: true),
              _buildCalcButton(')', () => _onNumberPressed(')'), isOperator: true),
              _buildCalcButton('C', () => _onNumberPressed('C'), isClear: true),
              _buildCalcButton('X', () => _onNumberPressed('X'), isBackspace: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCalcButton('7', () => _onNumberPressed('7')),
              _buildCalcButton('8', () => _onNumberPressed('8')),
              _buildCalcButton('9', () => _onNumberPressed('9')),
              _buildCalcButton('÷', () => _onNumberPressed('÷'), isOperator: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCalcButton('4', () => _onNumberPressed('4')),
              _buildCalcButton('5', () => _onNumberPressed('5')),
              _buildCalcButton('6', () => _onNumberPressed('6')),
              _buildCalcButton('×', () => _onNumberPressed('×'), isOperator: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCalcButton('1', () => _onNumberPressed('1')),
              _buildCalcButton('2', () => _onNumberPressed('2')),
              _buildCalcButton('3', () => _onNumberPressed('3')),
              _buildCalcButton('-', () => _onNumberPressed('-'), isOperator: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCalcButton('000', () => _onNumberPressed('000')),
              _buildCalcButton('0', () => _onNumberPressed('0')),
              _buildCalcButton('.', () => _onNumberPressed('.')),
              _buildCalcButton('+', () => _onNumberPressed('+'), isOperator: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildCalcButton('=', () => _onEqualsPressed(), isInput: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalcButton(String text, VoidCallback onPressed, {bool isOperator = false, bool isClear = false, bool isBackspace = false, bool isInput = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isOperator || isClear || isBackspace || isInput
              ? const Color(0xFF34C759)
              : const Color(0xFFEFF8F1),
            foregroundColor: isOperator || isClear || isBackspace || isInput
              ? Colors.white
              : const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  
  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }
}
