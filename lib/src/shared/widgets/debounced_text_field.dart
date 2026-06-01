import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DebouncedTextField extends StatefulWidget {
  const DebouncedTextField({
    super.key,
    this.controller,
    required this.onChanged,
    this.delay = const Duration(milliseconds: 250),
    this.decoration,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
  });

  final TextEditingController? controller;
  final ValueChanged<String> onChanged;
  final Duration delay;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? minLines;
  final int? maxLines;

  @override
  State<DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<DebouncedTextField> {
  Timer? _timer;
  TextEditingController? _controller;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant DebouncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _detachController(oldWidget.controller);
    _attachController(widget.controller);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _detachController(_controller);
    super.dispose();
  }

  void _attachController(TextEditingController? controller) {
    _controller = controller;
    controller?.addListener(_handleControllerChange);
  }

  void _detachController(TextEditingController? controller) {
    controller?.removeListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    final text = _controller?.text;
    if (text != '') return;
    _timer?.cancel();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      decoration: widget.decoration,
      onChanged: (value) {
        _timer?.cancel();
        _timer = Timer(widget.delay, () => widget.onChanged(value));
      },
    );
  }
}
