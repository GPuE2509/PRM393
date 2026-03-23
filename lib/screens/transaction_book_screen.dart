import 'package:flutter/material.dart';

import 'transaction_list_screen.dart';

class TransactionBookScreen extends StatelessWidget {
  final int userId;
  final int refreshToken;
  final VoidCallback? onTransactionChanged;
  
  const TransactionBookScreen({
    super.key,
    required this.userId,
    this.refreshToken = 0,
    this.onTransactionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TransactionListScreen(
      userId: userId,
      refreshToken: refreshToken,
      onTransactionChanged: onTransactionChanged,
    );
  }
}
