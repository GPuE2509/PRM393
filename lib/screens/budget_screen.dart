import 'package:flutter/material.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Ngân sách',
        style: TextStyle(
          color: Color(0xFF34C759),
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
