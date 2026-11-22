import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../data/document_picker.dart';
import '../data/student_api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

AppState get _state => AppState.instance;

void _go(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

// ---------------------------------------------------------------------------
// 4. Requirements (what to prepare)
// ---------------------------------------------------------------------------
class RequirementsScreen extends StatelessWidget {
  const RequirementsScreen({super.key, this.viewOnly = false});

  /// When opened from the Home shortcut there is no "Continue" step.
  final bool viewOnly;

  static const _items = [
    'Student ID',
    'Photocopy of Student ID',
    'Motorcycle registration (OR/CR)',
    'Owner documents (if not yours)',
    'Other school requirements',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PageHeader(
              title: 'Requirements',
              subtitle: 'What to prepare',
              showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SectionLabel('Prepare these before applying'),
                for (final item in [
                  ..._items,
                  if (_state.requiresMotorcyclePhoto) 'Motorcycle photo',
                ])
                  if (_state.isDemo || item != 'Photocopy of Student ID')
                  ListRow(
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            size: 20, color: AppColors.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(item,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!viewOnly)
            BottomActionBar(
              nextLabel: 'Continue',
              onNext: () => _go(context, const OwnershipScreen()),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Ownership
// ---------------------------------------------------------------------------
class OwnershipScreen extends StatefulWidget {
  const OwnershipScreen({super.key});

  @override
  State<OwnershipScreen> createState() => _OwnershipScreenState();
}

class _OwnershipScreenState extends State<OwnershipScreen> {
  late Ownership _selected = _state.ownership;

  Widget _option(Ownership value, String title, String subtitle) {
    final selected = value == _selected;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenLight : Colors.white,
          border: Border.all(
              color: selected ? AppColors.green : AppColors.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.greenDark : AppColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PageHeader(
              title: 'Ownership',
              subtitle: 'Who owns the motorcycle?',
              showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _option(Ownership.owned, 'Owned by me',
                    'The motorcycle is registered under my name'),
                _option(Ownership.notOwned, 'Not owned by me',
                    "e.g. a parent's or relative's motorcycle"),
                const SizedBox(height: 4),
                const Text('You can change this before submitting.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          BottomActionBar(
            nextLabel: 'Next',
            onNext: () {
              if (_selected != _state.ownership) _state.setOwnership(_selected);
              _go(context, const ChecklistScreen());
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6 & 7. Requirements checklist (owned / not owned)
// ---------------------------------------------------------------------------
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final Set<String> _checked = {};

  Map<String, List<String>> get _groups => _state.notOwned
      ? {
          'Your documents': [
            'Student ID',
            if (_state.isDemo) 'Photocopy of Student ID',
          ],
          'Owner documents': [
            "Photocopy of owner's ID",
            'Authorization / consent letter',
          ],
          'Motorcycle': [
            'Motorcycle registration',
            _state.requiresMotorcyclePhoto
                ? 'Motorcycle photo (required)'
                : 'Motorcycle photo, if required',
            'Other school requirements',
          ],
        }
      : {
          'Required': [
            'Student ID',
            if (_state.isDemo) 'Photocopy of Student ID',
            'Motorcycle registration',
            if (_state.requiresMotorcyclePhoto) 'Motorcycle photo',
          ],
          'If needed': [
            if (!_state.requiresMotorcyclePhoto) 'Motorcycle photo',
            'Other school requirements',
          ],
        };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PageHeader(
            title: 'Requirements',
            subtitle: _state.notOwned ? 'Not owned by me' : 'Owned by me',
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final entry in _groups.entries) ...[
                  SectionLabel(entry.key),
                  for (final item in entry.value)
                    InkWell(
                      onTap: () => setState(() => _checked.contains(item)
                          ? _checked.remove(item)
                          : _checked.add(item)),
                      child: ListRow(
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _checked.contains(item),
                                onChanged: (v) => setState(() => v!
                                    ? _checked.add(item)
                                    : _checked.remove(item)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(item,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          BottomActionBar(
            nextLabel: 'Next',
            onNext: () => _go(context, const StudentInfoScreen()),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared layout for the 4 form steps
// ---------------------------------------------------------------------------
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.step,
    required this.child,
    required this.onNext,
    this.nextLabel = 'Next',
    this.busy = false,
  });

  final String title;
  final int step;
  final Widget child;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: Column(
          children: [
            PageHeader(title: title, subtitle: 'Step $step of 4', showBack: !busy),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StepProgress(step: step),
                    const SizedBox(height: 20),
                    AbsorbPointer(absorbing: busy, child: child),
                  ],
                ),
              ),
            ),
            BottomActionBar(nextLabel: nextLabel, onNext: onNext),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Student Info (Step 1)
// ---------------------------------------------------------------------------
class StudentInfoScreen extends StatefulWidget {
  const StudentInfoScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<StudentInfoScreen> createState() => _StudentInfoScreenState();
}

class _StudentInfoScreenState extends State<StudentInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _state.updateDraft();
    if (widget.editing) {
      Navigator.of(context).pop();
    } else {
      _go(context, const VehicleInfoScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Student Info',
      step: 1,
      nextLabel: widget.editing ? 'Save' : 'Next',
      onNext: _next,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            LabeledField(
                label: 'Full name',
                initialValue: _state.fullName,
                readOnly: _state.hasStudentSession,
                onChanged: widget.editing ? null : (v) => _state.fullName = v,
                onSaved: (v) => _state.fullName = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'Student ID no.',
                initialValue: _state.studentId,
                readOnly: _state.hasStudentSession,
                keyboardType: TextInputType.number,
                onChanged: widget.editing ? null : (v) => _state.studentId = v,
                onSaved: (v) => _state.studentId = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'Course',
                hint: 'e.g. BSCS',
                initialValue: _state.course,
                onChanged: widget.editing ? null : (v) => _state.course = v,
                onSaved: (v) => _state.course = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'Year and section',
                hint: 'e.g. 3A',
                initialValue: _state.yearSection,
                onChanged: widget.editing ? null : (v) => _state.yearSection = v,
                onSaved: (v) => _state.yearSection = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'Contact number',
                hint: '09XX XXX XXXX',
                initialValue: _state.contact,
                keyboardType: TextInputType.phone,
                onChanged: widget.editing ? null : (v) => _state.contact = v,
                onSaved: (v) => _state.contact = (v ?? '').trim(),
                validator: requiredValidator),
            if (_state.isDemo) LabeledField(
                label: 'Address',
                initialValue: _state.address,
                onChanged: widget.editing ? null : (v) => _state.address = v,
                onSaved: (v) => _state.address = (v ?? '').trim(),
                validator: requiredValidator),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Vehicle Info (Step 2)
// ---------------------------------------------------------------------------
class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key, this.editing = false});
  final bool editing;

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  void _next() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _state.updateDraft();
    if (widget.editing) {
      Navigator.of(context).pop();
    } else {
      _go(context, const UploadScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Vehicle Info',
      step: 2,
      nextLabel: widget.editing ? 'Save' : 'Next',
      onNext: _next,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            LabeledField(
                label: 'Plate no.',
                hint: 'e.g. ABC 1234',
                initialValue: _state.plateNo,
                onChanged: widget.editing ? null : (v) => _state.plateNo = v,
                onSaved: (v) => _state.plateNo = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'Color',
                initialValue: _state.color,
                onChanged: widget.editing ? null : (v) => _state.color = v,
                onSaved: (v) => _state.color = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'Brand / model',
                hint: 'e.g. Yamaha NMAX',
                initialValue: _state.brandModel,
                onChanged: widget.editing ? null : (v) => _state.brandModel = v,
                onSaved: (v) => _state.brandModel = (v ?? '').trim(),
                validator: requiredValidator),
            LabeledField(
                label: 'OR/CR number',
                initialValue: _state.orCrNo,
                onChanged: widget.editing ? null : (v) => _state.orCrNo = v,
                onSaved: (v) => _state.orCrNo = (v ?? '').trim(),
                validator: requiredValidator),
            if (_state.notOwned)
              LabeledField(
                  label: "Owner's name",
                  initialValue: _state.ownerName,
                  onChanged: widget.editing ? null : (v) => _state.ownerName = v,
                  onSaved: (v) => _state.ownerName = (v ?? '').trim(),
                  validator: requiredValidator),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 10. Upload (Step 3)
// ---------------------------------------------------------------------------
class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key, this.editing = false});
  final bool editing;

  Future<void> _pick(BuildContext context, UploadSlot slot) async {
    if (!_state.isDemo) {
      try {
        final file = await pickDocument();
        if (file == null || !context.mounted) return;
        _state.markUploaded(slot, file.name, bytes: file.bytes);
      } catch (error) {
        if (!context.mounted) return;
        final message = switch (error) {
          StudentApiException(:final message) => message,
          PlatformException(:final message) => message ?? 'Could not read the selected file.',
          _ => 'Could not read the selected file.',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    final name =
        '${slot.label.toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '_')}.jpg';
    _state.markUploaded(slot, name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final ready = _state.requiredUploadsReady;
        return _StepScaffold(
          title: 'Upload',
          step: 3,
          nextLabel: editing ? 'Save' : 'Next',
          onNext: ready
              ? () => editing
                  ? Navigator.of(context).pop()
                  : _go(context, const ReviewScreen())
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload clear photos. Make sure all text is readable. '
                'You can replace a file before submitting.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final slot in _state.uploads)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          slot.uploaded
                              ? Icons.check_circle
                              : Icons.upload_file_outlined,
                          color: slot.uploaded
                              ? AppColors.green
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.label + (slot.required ? ' *' : ''),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              Text(
                                slot.fileName ??
                                    (slot.hint.isEmpty
                                        ? 'Not uploaded'
                                        : slot.hint),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _pick(context, slot),
                          child: Text(slot.uploaded ? 'Replace' : 'Upload',
                              style: const TextStyle(
                                  color: AppColors.greenDark,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ),
              const Text('* Required',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 11. Review (Step 4) + 12. Submit popup
// ---------------------------------------------------------------------------
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  Widget _summary(String label, VoidCallback onEdit, Map<String, String> rows) {
    final entries = rows.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          label,
          trailing: GestureDetector(
            onTap: onEdit,
            child: const Text('Edit',
                style: TextStyle(
                    color: AppColors.greenDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        OutlinedCard(
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                ListRow(
                  divider: i != entries.length - 1,
                  child: Row(
                    children: [
                      Text(entries[i].key,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entries[i].value.isEmpty ? '—' : entries[i].value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSubmit(BuildContext context) async {
    var confirmed = false;
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Submit application?',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Make sure your details are correct. You cannot edit after submitting.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: confirmed,
                onChanged: (v) => setLocal(() => confirmed = v ?? false),
                title: const Text('I confirm all details are correct',
                    style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: confirmed ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submit != true || !context.mounted || _state.submitting) return;
    try {
      await _state.submit();
    } on StudentApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!context.mounted || !_state.hasActiveApplication) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SubmittedScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) => _StepScaffold(
        title: 'Review',
        step: 4,
        busy: _state.submitting,
        nextLabel: _state.submitting ? 'Submitting…' : 'Looks good',
        onNext: _state.requiredUploadsReady && !_state.submitting
            ? () => _confirmSubmit(context)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(
              'Student',
              () => _go(context, const StudentInfoScreen(editing: true)),
              {
                'Name': _state.fullName,
                'ID no.': _state.studentId,
                'Course': '${_state.course} ${_state.yearSection}'.trim(),
                'Contact': _state.contact,
                if (_state.address.isNotEmpty) 'Address': _state.address,
              },
            ),
            _summary(
              'Vehicle',
              () => _go(context, const VehicleInfoScreen(editing: true)),
              {
                'Model': _state.brandModel,
                'Plate': _state.plateNo,
                'Color': _state.color,
                'OR/CR no.': _state.orCrNo,
                'Owner': _state.notOwned ? _state.ownerName : 'Me',
              },
            ),
            _summary(
              'Documents',
              () => _go(context, const UploadScreen(editing: true)),
              {
                for (final slot in _state.uploads)
                  slot.label: slot.fileName ??
                      (slot.required ? 'Missing' : 'Optional'),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 13. Application submitted
// ---------------------------------------------------------------------------
class SubmittedScreen extends StatelessWidget {
  const SubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                    color: AppColors.greenLight, shape: BoxShape.circle),
                child: const Icon(Icons.check,
                    size: 48, color: AppColors.greenDark),
              ),
              const SizedBox(height: 20),
              const Text('Application submitted',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'We will notify you once your application has been reviewed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              OutlinedCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Reference number',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(_state.referenceNo ?? '',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Track application',
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const MainShell(initialTab: 1)),
                  (_) => false,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                  (_) => false,
                ),
                child: const Text('Back to Home',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
