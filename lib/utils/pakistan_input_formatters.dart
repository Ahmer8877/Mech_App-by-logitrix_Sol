import 'package:flutter/services.dart';

class PakistanPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('92') && digits.length > 10
        ? '0${digits.substring(2)}'
        : digits;
    final limited = normalized.length > 11
        ? normalized.substring(0, 11)
        : normalized;
    if (limited.isNotEmpty && !limited.startsWith('0')) return oldValue;
    return TextEditingValue(
      text: limited,
      selection: TextSelection.collapsed(offset: limited.length),
    );
  }
}

class PakistanCnicFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 13 ? digits.substring(0, 13) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 5 || i == 12) buffer.write('-');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String normalizePakistanPhone(String value) {
  var digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('92')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length != 10 || !digits.startsWith('3')) return '';
  return '+92$digits';
}

String normalizePakistanCnic(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 13) return '';
  return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
}

String displayPakistanPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('92') && digits.length == 12) {
    return '0${digits.substring(2)}';
  }
  if (digits.length == 11 && digits.startsWith('03')) return digits;
  return value;
}
