import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/transaction.dart' as model;
import 'add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final int userId;
  final int refreshToken;
  final VoidCallback? onTransactionChanged;

  const TransactionListScreen({
    super.key,
    required this.userId,
    this.refreshToken = 0,
    this.onTransactionChanged,
  });

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<model.Transaction> _transactions = [];
  List<model.Transaction> _filteredTransactions = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  final Set<int> _selectedTransactions = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant TransactionListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final transactions = await DatabaseHelper.instance.getTransactionsByUser(widget.userId);
      setState(() {
        _transactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredTransactions = _transactions.where((transaction) {
        // Search filter
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            (transaction.category?.toLowerCase().contains(searchQuery) ?? false) ||
            transaction.note.toLowerCase().contains(searchQuery);

        // Date filter
        final matchesDate = (_startDate == null && _endDate == null) ||
            (_startDate != null && _endDate != null &&
                transaction.date.isAfter(_startDate!.subtract(Duration(days: 1))) &&
                transaction.date.isBefore(_endDate!.add(Duration(days: 1))));

        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc theo ngày'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Khoảng thời gian'),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setDialogState(() {
                            _startDate = date;
                          });
                        }
                      },
                      child: Text(
                        _startDate != null 
                            ? DateFormat('dd/MM/yyyy').format(_startDate!)
                            : 'Từ ngày',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setDialogState(() {
                            _endDate = date;
                          });
                        }
                      },
                      child: Text(
                        _endDate != null 
                            ? DateFormat('dd/MM/yyyy').format(_endDate!)
                            : 'Đến ngày',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setDialogState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                },
                child: const Text('Xóa bộ lọc'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _applyFilters();
            },
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedTransactions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tất cả'),
        content: Text(
          'Bạn có chắc chắn muốn xóa ${_selectedTransactions.length} giao dịch đã chọn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Xóa tất cả',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final id in _selectedTransactions) {
          await DatabaseHelper.instance.deleteTransaction(id);
        }
        setState(() {
          _selectedTransactions.clear();
          _isSelectionMode = false;
        });
        await _loadTransactions();
        widget.onTransactionChanged?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa tất cả giao dịch')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi xóa giao dịch: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5F8D),
        elevation: 0,
        title: const Text(
          'Sổ giao dịch',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSelectionMode ? Icons.checklist_rtl : Icons.checklist,
              color: Colors.white,
            ),
            tooltip: _isSelectionMode ? 'Tắt chọn nhiều' : 'Chọn nhiều',
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) {
                  _selectedTransactions.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            tooltip: 'Xóa đã chọn',
            onPressed: (_isSelectionMode && _selectedTransactions.isNotEmpty)
                ? _deleteSelectedTransactions
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo danh mục hoặc ghi chú...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_startDate != null || _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue[50],
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang áp dụng bộ lọc',
                      style: TextStyle(color: Colors.blue[800]),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                        _searchController.clear();
                      });
                      _applyFilters();
                    },
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có giao dịch nào',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _filteredTransactions[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddTransactionScreen(userId: widget.userId),
            ),
          );
          if (result == true) {
            await _loadTransactions();
            widget.onTransactionChanged?.call();
          }
        },
        backgroundColor: const Color(0xFF2C5F8D),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTransactionCard(model.Transaction transaction) {
    final isExpense = transaction.type == model.TransactionType.expense;
    final amountColor = isExpense ? Colors.red : Colors.green;
    final formattedAmount = NumberFormat('#,##0.##').format(transaction.amount);
    final signedAmount = '${isExpense ? '-' : '+'}$formattedAmount VND';
    final isSelected = _selectedTransactions.contains(transaction.id!);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.1),
          child: Icon(
            isExpense ? Icons.remove : Icons.add,
            color: amountColor,
          ),
        ),
        title: Text(
          transaction.category ?? 'Không có nhóm',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.note.isNotEmpty)
              Text(
                transaction.note,
                style: TextStyle(color: Colors.grey[600]),
              ),
            Text(
              signedAmount,
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(transaction.date),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: _isSelectionMode 
          ? Checkbox(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedTransactions.add(transaction.id!);
                  } else {
                    _selectedTransactions.remove(transaction.id!);
                  }
                });
              },
            )
          : IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xóa giao dịch'),
                    content: const Text('Bạn có chắc chắn muốn xóa giao dịch này?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('OK', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await DatabaseHelper.instance.deleteTransaction(transaction.id!);
                    await _loadTransactions();
                    widget.onTransactionChanged?.call();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã xóa giao dịch')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi xóa giao dịch: $e')),
                      );
                    }
                  }
                }
              },
            ),
        onTap: () async {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedTransactions.remove(transaction.id!);
              } else {
                _selectedTransactions.add(transaction.id!);
              }
            });
          } else {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddTransactionScreen(
                  userId: widget.userId,
                  transaction: transaction,
                ),
              ),
            );
            if (result == true) {
              await _loadTransactions();
              widget.onTransactionChanged?.call();
            }
          }
        },
      ),
    );
  }

  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
