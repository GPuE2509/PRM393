import 'package:flutter/material.dart';

class TransactionBookScreen extends StatelessWidget {
  const TransactionBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Sổ giao dịch',
        style: TextStyle(
          color: Color(0xFFEDEEF1),
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
