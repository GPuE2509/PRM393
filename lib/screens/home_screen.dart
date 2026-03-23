import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../models/transaction.dart' as model;

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int refreshToken;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.username,
    this.refreshToken = 0,
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
  bool _isLoading = true;

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
      final totalExpense = await DatabaseHelper.instance.getTotalByUserAndType(widget.userId, model.TransactionType.expense);
      final totalIncome = await DatabaseHelper.instance.getTotalByUserAndType(widget.userId, model.TransactionType.income);
      
      setState(() {
        _totalExpense = totalExpense;
        _totalIncome = totalIncome;
        _balance = _totalIncome - _totalExpense;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
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
                    Text(
                      _formatNumber(_totalExpense),
                      style: TextStyle(
                        color: Color(0xFF2D7D46),
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
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
                    Text(
                      _formatNumber(_totalIncome),
                      style: TextStyle(
                        color: Color(0xFF34C759),
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: Divider(color: Color(0xFF34C759), thickness: 2),
              ),
              Expanded(
                child: Divider(color: Color(0xFFDCEAD7), thickness: 2),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFDCEAD7),
                style: BorderStyle.solid,
              ),
            ),
            child: const Center(
              child: Text(
                'Nhập giao dịch để xem báo cáo',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
          Row(
            children: [
              Icon(
                Icons.chevron_left,
                color: const Color(0xFF28C75C),
                size: isNarrow ? 30 : 36,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Báo cáo xu hướng',
                    style: TextStyle(
                      color: const Color(0xFF28C75C),
                      fontSize: isNarrow ? 34 : 48,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFF28C75C),
                size: isNarrow ? 30 : 36,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF34C759), size: 12),
                SizedBox(width: 12),
                Icon(Icons.circle, color: Color(0xFF8AA18F), size: 12),
              ],
            ),
          ),
        ],
      ),
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
                            '${NumberFormat('#,###').format(_balance)} đ',
                            style: TextStyle(
                              color: const Color(0xFF2D7D46),
                              fontSize: isNarrow ? 46 : 54,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.remove_red_eye_outlined,
                          color: const Color(0xFF2D7D46),
                          size: isNarrow ? 28 : 32,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
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
                      onPressed: () {},
                      icon: Icon(
                        Icons.notifications_none,
                        color: const Color(0xFF2D7D46),
                        size: isNarrow ? 32 : 38,
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34C759),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '7',
                            style: TextStyle(
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
                    fontSize: isNarrow ? 20 : 24,
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
            _walletCard(context),
            const SizedBox(height: 22),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _sectionTitle('Báo cáo tháng này', 'Xem báo cáo'),
            _monthlyReportCard(context),
            const SizedBox(height: 24),
            _premiumBanner(context),
          ],
        ),
      ),
    );
  }
}
