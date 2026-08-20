import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Six-box confirmation-code input used on "Подтвердите почту"
/// (states: неактивные поля -> ввод кода -> неверный код).
///
/// Backspace on an empty box steps back and clears the previous one. That is
/// wired through each box's own [FocusNode.onKeyEvent] rather than a wrapping
/// KeyboardListener, so no extra focus nodes are created per rebuild.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  /// Turns the boxes red and clears them once, on the transition into error.
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  /// Guards against the re-entrant onChanged that firing setText causes while
  /// spreading a pasted code across the boxes.
  bool _distributing = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(
      widget.length,
      (index) => FocusNode(onKeyEvent: (node, event) => _onKeyEvent(index, event)),
    );
  }

  @override
  void didUpdateWidget(OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear exactly once, when the parent flips into the error state — not on
    // every rebuild while the flag stays true, which would fight the user's
    // typing.
    if (widget.hasError && !oldWidget.hasError) {
      _clearAll();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _clearAll() {
    _distributing = true;
    for (final c in _controllers) {
      c.clear();
    }
    _distributing = false;
    if (widget.enabled) _focusNodes.first.requestFocus();
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return KeyEventResult.ignored;
    if (_controllers[index].text.isNotEmpty || index == 0) return KeyEventResult.ignored;

    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    widget.onChanged?.call(_code);
    return KeyEventResult.handled;
  }

  void _onDigitChanged(int index, String value) {
    if (_distributing) return;

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    // A pasted or autofilled code lands entirely in one box — spread it.
    if (digits.length > 1) {
      _distributing = true;
      var cursor = index;
      for (final digit in digits.split('')) {
        if (cursor >= widget.length) break;
        _controllers[cursor].text = digit;
        cursor++;
      }
      _distributing = false;
      _focusNodes[(cursor - 1).clamp(0, widget.length - 1)].requestFocus();
    } else if (digits != value) {
      // Stripped a non-digit — put the sanitised value back.
      _distributing = true;
      _controllers[index].text = digits;
      _distributing = false;
    }

    if (_controllers[index].text.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    final code = _code;
    widget.onChanged?.call(code);

    if (code.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError ? AppColors.danger : AppColors.fieldIdle;
    final focusedColor = widget.hasError ? AppColors.danger : AppColors.fieldActive;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 48,
          height: 56,
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            enabled: widget.enabled,
            autofocus: widget.autofocus && index == 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: focusedColor, width: 1.5),
              ),
            ),
            onChanged: (value) => _onDigitChanged(index, value),
          ),
        );
      }),
    );
  }
}
