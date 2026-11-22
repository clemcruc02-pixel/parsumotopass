import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/document_picker.dart';
import '../data/student_api.dart';
import 'auth_screens.dart';
import 'status_screens.dart' show eventTime;

class StaffWorkspace extends StatefulWidget {
  const StaffWorkspace({super.key});

  @override
  State<StaffWorkspace> createState() => _StaffWorkspaceState();
}

class _StaffWorkspaceState extends State<StaffWorkspace> {
  final _state = AppState.instance;
  late Future<Map<String, dynamic>> _queue = _state.staffRequest(
    'GET',
    'applications',
  );

  void _refresh() {
    setState(() => _queue = _state.staffRequest('GET', 'applications'));
  }

  Future<void> _requirements() async {
    try {
      final current = await _state.staffRequest('GET', 'requirements');
      if (!mounted) return;
      var requirePhoto = current['photoRequired'] == true;
      final value = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Document requirements'),
            content: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require a motorcycle photo on new requests'),
              value: requirePhoto,
              onChanged: (value) => update(() => requirePhoto = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, requirePhoto),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || value == null) return;
      await _state.staffRequest(
        'POST',
        'requirements',
        body: {'photoRequired': value},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document requirements saved.')),
        );
      }
    } on StudentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _state.signOut();
    } on StudentApiException {
      // The local session has already been cleared.
    }
    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permit office'),
        actions: [
          if (_state.staffPermissions.contains('manage'))
            IconButton(
              tooltip: 'Document requirements',
              onPressed: _requirements,
              icon: const Icon(Icons.checklist),
            ),
          if (_state.staffPermissions.contains('manage'))
            IconButton(
              tooltip: 'Manage staff grants',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const _StaffGrants()),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          if (_state.staffPermissions.contains('manage'))
            IconButton(
              tooltip: 'Pickup settings',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const _PickupSettings()),
              ),
              icon: const Icon(Icons.settings),
            ),
          IconButton(
            tooltip: 'Refresh queue',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _queue,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Text(
                error is StudentApiException
                    ? error.message
                    : 'Could not load the queue.',
              ),
            );
          }
          final records = (snapshot.data!['applications'] as List)
              .cast<Map<String, dynamic>>();
          if (records.isEmpty) {
            return const Center(child: Text('No applications to review'));
          }
          return ListView(
            children: [
              for (final record in records)
                ListTile(
                  title: Text(record['reference'] as String),
                  subtitle: Text(_status(record['status'] as String)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => _StaffApplication(initial: record),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

String _status(String status) => switch (status) {
  'documentsReceived' => 'Documents received',
  'underReview' => 'Under review',
  'readyForRelease' => 'Ready for pickup',
  'needsCorrection' => 'Needs correction',
  _ => '${status[0].toUpperCase()}${status.substring(1)}',
};

class _StaffApplication extends StatefulWidget {
  const _StaffApplication({required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<_StaffApplication> createState() => _StaffApplicationState();
}

class _StaffApplicationState extends State<_StaffApplication> {
  late Map<String, dynamic> _record = widget.initial;
  bool _busy = false;
  String? _error;
  bool _identityConfirmed = false;
  String _reason = '';
  final _opened = <String>{};

  Future<void> _openDocument(String slot, String filename) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await AppState.instance.staffDocument(
        _record['reference'] as String,
        slot,
      );
      if (!mounted) return;
      if (filename.toLowerCase().endsWith('.pdf')) {
        if (!await showPdf(context, bytes)) return;
      } else {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(slot),
            content: InteractiveViewer(child: Image.memory(bytes)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      if (mounted) setState(() => _opened.add(slot));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the document.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AppState.instance.staffRequest(
        'GET',
        'applications/${_record['reference']}',
      );
      if (!mounted) return;
      setState(() {
        _record = result['application'] as Map<String, dynamic>;
        _opened.clear();
        _identityConfirmed = false;
      });
    } on StudentApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(String action, Map<String, dynamic> changes) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AppState.instance.staffRequest(
        'POST',
        'applications/${_record['reference']}/$action',
        body: {'revision': _record['revision'], ...changes},
      );
      if (mounted) {
        setState(() => _record = result['application'] as Map<String, dynamic>);
      }
    } on StudentApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _record['status'] as String;
    final grants = AppState.instance.staffPermissions;
    final documents = (_record['documents'] as Map<String, dynamic>? ?? {});
    final verified = (_record['verifiedDocuments'] as List? ?? []);
    final history = (_record['history'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final pickup = _record['pickup'] as Map<String, dynamic>?;
    final details = (_record['details'] as Map<String, dynamic>? ?? {});
    final (next, permission, label) = switch (status) {
      'submitted' => ('documentsReceived', 'review', 'Mark documents received'),
      'documentsReceived' => ('underReview', 'review', 'Start review'),
      'underReview' => ('approved', 'decide', 'Approve'),
      'approved' => ('readyForRelease', 'release', 'Mark ready for pickup'),
      'readyForRelease' => ('released', 'release', 'Record pickup'),
      _ => ('', '', ''),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_record['reference'] as String),
        actions: [
          IconButton(
            tooltip: 'Refresh application',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(_status(status)),
            subtitle: Text('Student ID ${_record['studentId']}'),
          ),
          if (_record['possibleDuplicate'] == true)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Another active request uses this plate'),
            ),
          for (final field in details.entries)
            ListTile(
              title: Text(field.key),
              subtitle: Text(field.value.toString()),
            ),
          if (documents.isNotEmpty)
            const ListTile(title: Text('Submitted documents')),
          for (final document in documents.entries)
            ListTile(
              title: Text(document.key),
              subtitle: Text(document.value as String),
              onTap: _busy
                  ? null
                  : () => _openDocument(document.key, document.value as String),
              leading: const Icon(Icons.description_outlined),

              trailing: verified.contains(document.key)
                  ? const Icon(
                      Icons.check_circle_outline,
                      semanticLabel: 'Verified',
                    )
                  : status == 'underReview' && grants.contains('review')
                  ? TextButton(
                      onPressed: _busy || !_opened.contains(document.key)
                          ? null
                          : () => _change('verify', {'slot': document.key}),
                      child: const Text('Mark verified'),
                    )
                  : null,
            ),
          if (pickup != null)
            ListTile(
              title: Text(pickup['location'] as String),
              subtitle: Text(pickup['hours'] as String),
            ),
          if (status == 'readyForRelease' && grants.contains('release'))
            CheckboxListTile(
              title: const Text('Student ID and reference confirmed in person'),
              value: _identityConfirmed,
              onChanged: _busy
                  ? null
                  : (value) =>
                        setState(() => _identityConfirmed = value == true),
            ),
          if (grants.contains(permission))
            FilledButton(
              onPressed: _busy || (next == 'released' && !_identityConfirmed)
                  ? null
                  : () => _change('transition', {
                      'status': next,
                      'identityConfirmed': _identityConfirmed,
                    }),
              child: Text(label),
            ),
          if (status == 'underReview' &&
              (grants.contains('decide') || grants.contains('review'))) ...[
            TextField(
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Student-visible reason',
              ),
              onChanged: (value) => setState(() => _reason = value.trim()),
            ),
            if (grants.contains('review'))
              OutlinedButton(
                onPressed: _busy || _reason.isEmpty
                    ? null
                    : () => _change('transition', {
                        'status': 'needsCorrection',
                        'reason': _reason,
                      }),
                child: const Text('Request correction'),
              ),
            if (grants.contains('decide'))
              OutlinedButton(
                onPressed: _busy || _reason.isEmpty
                    ? null
                    : () => _change('transition', {
                        'status': 'rejected',
                        'reason': _reason,
                      }),
                child: const Text('Reject'),
              ),
          ],
          if (_error case final error?)
            Padding(padding: const EdgeInsets.all(12), child: Text(error)),
          if (history.isNotEmpty)
            const ListTile(title: Text('Application history')),
          for (final event in history)
            ListTile(
              title: Text(_status(event['status'] as String)),
              subtitle: Text(
                [
                  eventTime(context, event['recorded_at'] as String),
                  if (event['actor'] case final String actor)
                    'Recorded by $actor',
                  if (event['reason'] case final String reason) reason,
                ].join('\n'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaffGrants extends StatefulWidget {
  const _StaffGrants();

  @override
  State<_StaffGrants> createState() => _StaffGrantsState();
}

class _StaffGrantsState extends State<_StaffGrants> {
  final _state = AppState.instance;
  late Future<Map<String, dynamic>> _accounts = _state.staffRequest(
    'GET',
    'accounts',
  );

  Future<void> _change(String account, String grant, bool enabled) async {
    try {
      final updated = await _state.staffRequest(
        'POST',
        'accounts',
        body: {'account': account, 'grant': grant, 'enabled': enabled},
      );
      if (mounted) setState(() => _accounts = Future.value(updated));
    } on StudentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Staff grants')),
    body: FutureBuilder(
      future: _accounts,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Could not load staff accounts.'));
        }
        final accounts = (snapshot.data!['accounts'] as List)
            .cast<Map<String, dynamic>>();
        return ListView(
          children: [
            for (final account in accounts) ...[
              ListTile(title: Text(account['name'] as String)),
              for (final (grant, label) in [
                ('review', 'Review documents'),
                ('decide', 'Approve or reject'),
                ('release', 'Prepare and record pickup'),
              ])
                SwitchListTile(
                  title: Text(label),
                  value: (account['permissions'] as List).contains(grant),
                  onChanged: account['id'] == _state.studentId
                      ? null
                      : (enabled) =>
                            _change(account['id'] as String, grant, enabled),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _PickupSettings extends StatefulWidget {
  const _PickupSettings();

  @override
  State<_PickupSettings> createState() => _PickupSettingsState();
}

class _PickupSettingsState extends State<_PickupSettings> {
  final _form = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _hours = TextEditingController();
  late final _settings = _load();
  bool _saving = false;
  String? _error;

  Future<void> _load() async {
    final data = await AppState.instance.staffRequest('GET', 'pickup');
    if (!mounted) return;
    _location.text = data['location'] as String? ?? '';
    _hours.text = data['hours'] as String? ?? '';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppState.instance.staffRequest(
        'POST',
        'pickup',
        body: {'location': _location.text, 'hours': _hours.text},
      );
      if (mounted) Navigator.of(context).pop();
    } on StudentApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _location.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pickup settings')),
    body: FutureBuilder(
      future: _settings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.error case final StudentApiException error) {
          return Center(child: Text(error.message));
        }
        return Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final (label, controller) in [
                ('Location', _location),
                ('Office hours', _hours),
              ])
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(labelText: label),
                  maxLength: 200,
                  enabled: !_saving,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter ${label.toLowerCase()}'
                      : null,
                ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save pickup settings'),
              ),
              if (_error case final error?) Text(error),
            ],
          ),
        );
      },
    ),
  );
}
