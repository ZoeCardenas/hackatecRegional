// input_field.dart
import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final String hintText;
  final IconData? icon;
  final bool showIcon;
  final TextInputType? keyboardType;

  const InputField({
    super.key,
    required this.hintText,
    this.icon,
    this.showIcon = true,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: showIcon && icon != null ? Icon(icon) : null,
      ),
    );
  }
}
