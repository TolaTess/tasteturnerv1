// lib/widgets/safe_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart'; // Add this import for TextInputFormatter

class SafeTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final int? maxLines;
  final int? minLines;
  final bool? enabled;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final EdgeInsets scrollPadding;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;

  const SafeTextField({
    Key? key,
    this.controller,
    this.decoration,
    this.style,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.enabled,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofocus = false,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.validator,
    this.autovalidateMode,
  }) : super(key: key);

  @override
  _SafeTextFieldState createState() => _SafeTextFieldState();
}

class _SafeTextFieldState extends State<SafeTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      cursorColor: kAccent,
      controller: widget.controller,
      decoration: widget.decoration,
      style: widget.style,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      keyboardType: widget.keyboardType,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      autofocus: widget.autofocus,
      scrollPadding: widget.scrollPadding,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      enableInteractiveSelection: true,
      textAlign: TextAlign.left,
      textAlignVertical: TextAlignVertical.center,
      showCursor: true,
      autocorrect: false,
      toolbarOptions: const ToolbarOptions(
        copy: true,
        cut: true,
        paste: true,
        selectAll: true,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }
}

// lib/widgets/safe_text_field.dart
// Add this class alongside SafeTextField

class SafeTextFormField extends FormField<String> {
  final TextEditingController? controller;

  SafeTextFormField({
    Key? key,
    this.controller,
    InputDecoration? decoration,
    TextStyle? style,
    bool obscureText = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    FocusNode? focusNode,
    bool autofocus = false,
    FormFieldValidator<String>? validator,
    FormFieldSetter<String>? onSaved,
    String? initialValue,
    int? maxLines,
    bool enabled = true,
  }) : super(
          key: key,
          initialValue: controller?.text ?? initialValue ?? '',
          validator: validator,
          onSaved: onSaved,
          builder: (FormFieldState<String> field) {
            final _SafeTextFormFieldState state =
                field as _SafeTextFormFieldState;

            return SafeTextField(
              controller: state._effectiveController,
              decoration: decoration?.copyWith(
                errorText: field.errorText,
              ),
              style: style,
              obscureText: obscureText,
              readOnly: readOnly,
              keyboardType: keyboardType,
              onChanged: (value) {
                field.didChange(value);
                if (onChanged != null) {
                  onChanged(value);
                }
              },
              onTap: onTap,
              focusNode: focusNode,
              autofocus: autofocus,
              maxLines: maxLines,
              enabled: enabled,
            );
          },
        );

  @override
  FormFieldState<String> createState() => _SafeTextFormFieldState();
}

class _SafeTextFormFieldState extends FormFieldState<String> {
  TextEditingController? _controller;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!;

  @override
  SafeTextFormField get widget => super.widget as SafeTextFormField;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    if (widget.controller == null) {
      _controller?.text = widget.initialValue ?? '';
    }
    setState(() {});
  }
}

class SafeDropdownFormField extends FormField<String> {
  final TextEditingController? controller;
  final VoidCallback? onTap;

  SafeDropdownFormField({
    Key? key,
    this.controller,
    this.onTap,
    InputDecoration? decoration,
    TextStyle? style,
    FormFieldValidator<String>? validator,
    FormFieldSetter<String>? onSaved,
    String? initialValue,
    bool enabled = true,
  }) : super(
          key: key,
          initialValue: controller?.text ?? initialValue ?? '',
          validator: validator,
          onSaved: onSaved,
          builder: (FormFieldState<String> field) {
            final _SafeDropdownFormFieldState state =
                field as _SafeDropdownFormFieldState;

            return SafeTextField(
              controller: state._effectiveController,
              decoration: decoration?.copyWith(
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              style: style,
              readOnly: true,
              onTap: onTap,
              enabled: enabled,
            );
          },
        );

  @override
  FormFieldState<String> createState() => _SafeDropdownFormFieldState();
}

class _SafeDropdownFormFieldState extends FormFieldState<String> {
  TextEditingController? _controller;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!;

  @override
  SafeDropdownFormField get widget => super.widget as SafeDropdownFormField;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController(text: widget.initialValue);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void reset() {
    super.reset();
    if (widget.controller == null) {
      _controller?.text = widget.initialValue ?? '';
    }
    setState(() {});
  }
}
