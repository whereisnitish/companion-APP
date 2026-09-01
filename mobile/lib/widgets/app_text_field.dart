import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A quiet input: no filled grey box, no floating label acrobatics. A label
/// above, a hairline field, and the border warms to the brand colour on focus.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofocus = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool autofocus;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _isFocused = false;
  late bool _obscured = widget.obscureText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final bool hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    final Color borderColor = hasError
        ? colors.danger
        : _isFocused
            ? colors.primary
            : colors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.label != null) ...<Widget>[
          Text(widget.label!, style: type.label.copyWith(color: colors.inkMuted)),
          const SizedBox(height: AppSpacing.sm),
        ],
        AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: widget.enabled ? colors.surface : colors.surfaceSunken,
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: borderColor, width: _isFocused || hasError ? 1.5 : 1),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: widget.maxLines > 1 ? AppSpacing.md : 0,
          ),
          child: Row(
            crossAxisAlignment:
                widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.prefixIcon != null) ...<Widget>[
                Padding(
                  padding: EdgeInsets.only(top: widget.maxLines > 1 ? 2 : 0),
                  child: Icon(
                    widget.prefixIcon,
                    size: 19,
                    color: _isFocused ? colors.primary : colors.inkFaint,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  obscureText: _obscured,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  maxLines: _obscured ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  maxLength: widget.maxLength,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: colors.primary,
                  cursorWidth: 1.6,
                  cursorRadius: const Radius.circular(2),
                  style: type.body.copyWith(color: colors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: type.body.copyWith(color: colors.inkFaint),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: widget.maxLines > 1 ? 2 : AppSpacing.lg,
                    ),
                  ),
                ),
              ),
              if (widget.obscureText)
                GestureDetector(
                  onTap: () => setState(() => _obscured = !_obscured),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 19,
                      color: colors.inkFaint,
                    ),
                  ),
                )
              else if (widget.suffix != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                widget.suffix!,
              ],
            ],
          ),
        ),
        AnimatedSize(
          duration: AppMotion.fast,
          alignment: Alignment.topLeft,
          child: hasError || widget.helper != null
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
                  child: Text(
                    hasError ? widget.errorText! : widget.helper!,
                    style: type.caption.copyWith(
                      color: hasError ? colors.danger : colors.inkFaint,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
