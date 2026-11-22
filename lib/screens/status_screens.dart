import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'apply_screens.dart';

String statusTitle(AppStatus s) => switch (s) {
      AppStatus.submitted => 'Submitted',
      AppStatus.documentsReceived => 'Documents received',
      AppStatus.underReview => 'Under review',
      AppStatus.approved => 'Approved',
      AppStatus.readyForRelease => 'Ready for release',
      AppStatus.rejected => 'Rejected',
      AppStatus.released => 'Released',
      AppStatus.needsCorrection => 'Needs correction',
    };

const _pendingText = {
  AppStatus.submitted: 'Application received',
  AppStatus.documentsReceived: 'Checked by the office',
  AppStatus.underReview: 'Now being evaluated',
  AppStatus.approved: 'Waiting for decision',
  AppStatus.readyForRelease: 'Pick up your sticker',
};

// ---------------------------------------------------------------------------
// 14. Tracking (shown inside the "My Application" tab)
// ---------------------------------------------------------------------------
class TrackingView extends StatelessWidget {
  const TrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final current = state.status;
        return Column(
          children: [
            PageHeader(
              title: 'Tracking',
              subtitle: state.referenceNo,
              actions: [
                AlertBell(
                  hasDot: state.alerts.isNotEmpty,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AlertsScreen())),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  if (!state.isDemo) ...[
                    Text(statusTitle(current),
                        style: Theme.of(context).textTheme.headlineSmall),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const _ApplicationRecords()),
                      ),
                      child: const Text('Past applications'),
                    ),
                    if (current == AppStatus.readyForRelease ||
                        current == AppStatus.released)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ReleaseScreen()),
                        ),
                        child: Text(current == AppStatus.released
                            ? 'View pickup history'
                            : 'View pickup details'),
                      ),
                    const ListTile(title: Text('Application history')),
                    for (final event in state.alerts)
                      ListTile(
                        title: Text(event.title),
                        subtitle: Text('${event.message}\n${eventTime(context, event.time)}'),
                      ),
                  ],
                  if (state.isDemo)
                    for (final s in _pendingText.keys)
                    _TimelineStep(
                      title: statusTitle(s),
                      subtitle: _pendingText[s]!,
                      done: s.index < current.index ||
                          current == AppStatus.readyForRelease,
                      active: s == current &&
                          current != AppStatus.readyForRelease,
                      isLast: s == AppStatus.readyForRelease,
                      trailing: s == AppStatus.readyForRelease
                          ? GestureDetector(
                              onTap: current == AppStatus.readyForRelease
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const ReleaseScreen()))
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('View pickup details ›',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: current ==
                                                AppStatus.readyForRelease
                                            ? AppColors.greenDark
                                            : AppColors.inactive)),
                              ),
                            )
                          : null,
                    ),
                  const SizedBox(height: 24),
                  if (state.canStartAnotherApplication)
                    FilledButton(
                      onPressed: () {
                        state.beginAnotherApplication();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RequirementsScreen()),
                        );
                      },
                      child: const Text('New application'),
                    ),
                  if (state.canCorrectApplication)
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RequirementsScreen()),
                      ),
                      child: const Text('Correct and resubmit'),
                    ),
                  if (!state.isDemo)
                    const _RefreshUpdates(),
                  // Prototype-only control so the later screens can be previewed.
                  if (state.isDemo && current != AppStatus.readyForRelease)
                    Center(
                      child: TextButton.icon(
                        onPressed: state.advanceStatus,
                        icon: const Icon(Icons.fast_forward,
                            size: 16, color: AppColors.muted),
                        label: const Text('Simulate next status (demo)',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApplicationRecords extends StatefulWidget {
  const _ApplicationRecords();

  @override
  State<_ApplicationRecords> createState() => _ApplicationRecordsState();
}

class _ApplicationRecordsState extends State<_ApplicationRecords> {
  late final _records = AppState.instance.applicationHistory();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Past applications')),
    body: FutureBuilder(
      future: _records,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Could not load your application history.'));
        }
        return ListView(
          children: [
            for (final record in snapshot.data!)
              ListTile(
                title: Text(record['reference'] as String),
                subtitle: Text(statusTitle(AppStatus.values.byName(record['status'] as String))),
                trailing: Text(eventTime(context, record['submittedAt'] as String)),
              ),
          ],
        );
      },
    ),
  );
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.active,
    required this.isLast,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool done;
  final bool active;
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget dot;
    if (done) {
      dot = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
            color: AppColors.green, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: 14, color: AppColors.text),
      );
    } else if (active) {
      dot = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.green, width: 3),
        ),
      );
    } else {
      dot = Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
            color: AppColors.inactive, shape: BoxShape.circle),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                dot,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done ? AppColors.green : AppColors.inactive,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: done || active
                              ? AppColors.text
                              : AppColors.muted)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  ?trailing,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 15. Alerts
// ---------------------------------------------------------------------------
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => Column(
          children: [
            const PageHeader(
                title: 'Alerts', subtitle: 'Latest updates', showBack: true),
            if (!state.isDemo) const _RefreshUpdates(),
            Expanded(
              child: state.alerts.isEmpty
                  ? const Center(
                      child: Text('No updates yet',
                          style: TextStyle(color: AppColors.muted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final a = state.alerts[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppColors.greenLight
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notifications,
                                  size: 20, color: AppColors.muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    Text(a.message,
                                        style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text(eventTime(context, a.time),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 16. Release
// ---------------------------------------------------------------------------
class ReleaseScreen extends StatelessWidget {
  const ReleaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => _content(context, state),
    );
  }

  Widget _content(BuildContext context, AppState state) {
    final ref = state.referenceNo ?? '';
    final released = state.status == AppStatus.released;
    final location = state.pickup?['location'] as String?;
    final hours = state.pickup?['hours'] as String?;
    const dashed = Divider(height: 1, color: AppColors.border);
    return Scaffold(
      body: Column(
        children: [
          PageHeader(
              title: released ? 'Pickup history' : 'Pickup details',
              subtitle: ref, showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: AppColors.greenLight,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(released ? 'Sticker picked up' : 'Ready for pickup',
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            if (location != null) Text(location),
                            if (state.isDemo) const Text('Canteen'),
                          ],
                        ),
                      ),
                      if (hours != null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(hours),
                        ),
                      if (released && state.alerts.isNotEmpty)
                        ListTile(
                          title: const Text('Recorded on'),
                          subtitle: Text(eventTime(context, state.alerts.first.time)),
                        ),
                      if (!released && !state.isDemo && location == null)
                        const ListTile(title: Text('Contact the permit office for pickup instructions.')),
                      dashed,
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!released) const Text('Bring',
                                style: TextStyle(color: AppColors.muted)),
                            if (!released) const Text('Student ID',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            Text('Ref. $ref'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Show reference',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Text('Reference number',
                          textAlign: TextAlign.center),
                      content: Text(ref,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String eventTime(BuildContext context, String value) {
  final time = DateTime.tryParse(value)?.toLocal();
  if (time == null) return value;
  final labels = MaterialLocalizations.of(context);
  return '${labels.formatShortDate(time)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
}

class _RefreshUpdates extends StatelessWidget {
  const _RefreshUpdates();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Column(
      children: [
        if (state.refreshError case final error?)
          Padding(padding: const EdgeInsets.all(8), child: Text(error)),
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: Text(state.refreshing ? 'Refreshing...' : 'Refresh updates'),
          onPressed: state.refreshing ? null : state.refreshApplication,
        ),
      ],
    );
  }
}
