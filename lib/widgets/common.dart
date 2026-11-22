import 'package:flutter/material.dart';

import '../theme.dart';

/// Gray page header with big title, subtitle and optional back / actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.header,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack)
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.chevron_left, color: Colors.white, size: 30),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Bell icon with a small dot, used in headers.
class AlertBell extends StatelessWidget {
  const AlertBell({super.key, required this.onTap, this.hasDot = true});
  final VoidCallback onTap;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white, size: 26),
          if (hasDot)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          disabledBackgroundColor: AppColors.inactive,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Two-part bottom bar: gray "Back" on the left, green action on the right.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.nextLabel,
    required this.onNext,
    this.backLabel = 'Back',
    this.onBack,
  });

  final String nextLabel;
  final VoidCallback? onNext;
  final String backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget part(String label, Color color, VoidCallback? onTap) => Expanded(
          child: Material(
            color: onTap == null ? AppColors.inactive : color,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 60 + bottom,
                padding: EdgeInsets.only(bottom: bottom),
                alignment: Alignment.center,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );

    return Row(
      children: [
        part(backLabel, AppColors.header,
            onBack ?? () => Navigator.of(context).maybePop()),
        const SizedBox(width: 2),
        part(nextLabel, AppColors.green, onNext),
      ],
    );
  }
}

/// "Step x of 4" progress segments.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, this.total = 4});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        total,
        (i) => Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: i < step ? AppColors.green : AppColors.inactive,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: 0.5)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Label above an underline text field, as in the Figma forms.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.hint = 'Enter here',
    this.initialValue,
    this.onChanged,
    this.obscure = false,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final String hint;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          TextFormField(
            initialValue: initialValue,
            onChanged: onChanged,
            obscureText: obscure,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

String? requiredValidator(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

/// Bordered card used for summaries.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

/// Simple bulleted / checklist row with divider underneath.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.child, this.divider = true});
  final Widget child;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: child,
    );
  }
}
