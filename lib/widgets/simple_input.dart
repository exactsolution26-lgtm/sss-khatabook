import 'package:flutter/material.dart';

class SimpleInput extends StatelessWidget {
  final String hintText;
  final TextInputType keyboardType;
  final TextEditingController controller;

  const SimpleInput({
    super.key,
    required this.hintText,
    required this.keyboardType,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
