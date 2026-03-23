import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'budget_screen.dart';
import 'home_screen.dart';
import 'transaction_book_screen.dart';
import 'add_transaction_screen.dart';

class MainShellScreen extends StatefulWidget {
  final int userId;
  final String username;

  const MainShellScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  int _dataRefreshToken = 0;

  void _onTransactionChanged() {
    setState(() {
      _dataRefreshToken++;
    });
  }

  void _onTapTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(
        userId: widget.userId,
        username: widget.username,
        refreshToken: _dataRefreshToken,
      ),
      TransactionBookScreen(
        key: ValueKey(_dataRefreshToken),
        userId: widget.userId,
        refreshToken: _dataRefreshToken,
        onTransactionChanged: _onTransactionChanged,
      ),
      const BudgetScreen(),
      AccountScreen(userId: widget.userId, username: widget.username),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 8),
        child: SizedBox(
          width: 70,
          height: 70,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF34C759),
            elevation: 2,
            shape: const CircleBorder(),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(userId: widget.userId),
                ),
              );
              if (result == true) {
                _onTransactionChanged();
              }
            },
            child: const Icon(Icons.add, color: Colors.white, size: 42),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: _selectedIndex,
        onTap: _onTapTab,
      ),
      body: IndexedStack(index: _selectedIndex, children: tabs),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavigation({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Tổng quan',
      'Sổ giao dịch',
      '',
      'Ngân sách',
      'Tài khoản',
    ];
    const icons = [
      Icons.home_outlined,
      Icons.account_balance_wallet_outlined,
      Icons.add,
      Icons.content_paste_outlined,
      Icons.person_outline,
    ];

    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDCEAD7))),
      ),
      child: Row(
        children: List.generate(5, (index) {
          if (index == 2) {
            return const Expanded(child: SizedBox());
          }

          final tabIndex = index > 2 ? index - 1 : index;
          final selected = currentIndex == tabIndex;

          return Expanded(
            child: InkWell(
              onTap: () => onTap(tabIndex),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[index],
                      color: selected
                          ? const Color(0xFF34C759)
                          : const Color(0xFF8AA18F),
                      size: 31,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                          ? const Color(0xFF34C759)
                          : const Color(0xFF8AA18F),
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
