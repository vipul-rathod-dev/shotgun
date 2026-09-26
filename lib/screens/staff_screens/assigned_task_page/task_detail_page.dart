import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskDetailPage extends StatefulWidget {
  final String taskPath;

  const TaskDetailPage({
    super.key,
    required this.taskPath,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage>
    with SingleTickerProviderStateMixin {
  late final DocumentReference<Map<String, dynamic>> taskRef;
  late final ScrollController stepperScrollController;

  bool _isProcessingAction = false;

  static const Color _primary = Color(0xFF3F51B5);
  static const Color _background = Color(0xFFF6F7FB);
  static const Color _textPrimary = Color(0xFF343741);
  static const Color _border = Color(0xFFE4E7EC);

  @override
  void initState() {
    super.initState();

    taskRef = FirebaseFirestore.instance.doc(widget.taskPath);
    stepperScrollController = ScrollController();
  }

  @override
  void dispose() {
    stepperScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: Text(
          'Task Details',
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _textPrimary),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: taskRef.snapshots(),
        builder: (context, taskSnap) {
          if (taskSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!taskSnap.hasData || !taskSnap.data!.exists) {
            return _emptyState(
              icon: Icons.assignment_late_outlined,
              title: 'Task not found',
              subtitle: 'The requested task no longer exists.',
            );
          }

          final task = taskSnap.data!.data()!;
          final orderType =
              (task['orderType'] ?? '').toString().toLowerCase();
          final stages = _getStages(orderType);

          final segments = widget.taskPath.split('/');
          if (segments.length < 6) {
            return _emptyState(
              icon: Icons.link_off_rounded,
              title: 'Invalid task path',
              subtitle: 'The task reference is not a valid Firestore path.',
            );
          }

          final companyId = segments[1];
          final orderId = segments[3];

          final orderRef = FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('orders')
              .doc(orderId);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: orderRef.snapshots(),
            builder: (context, orderSnap) {
              final hasOrder =
                  orderSnap.hasData && (orderSnap.data?.exists ?? false);

              final orderStatus = hasOrder
                  ? (orderSnap.data!.data()?['orderStatus'] ?? 'Unknown')
                      .toString()
                  : 'Unknown';

              return _buildTaskDetail(
                context,
                task,
                stages,
                orderStatus,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskDetail(
    BuildContext context,
    Map<String, dynamic> task,
    List<String> stages,
    String orderStatus,
  ) {
    final taskStatus = (task['status'] ?? 'Unknown').toString();
    final completedCount = taskStatus.toLowerCase() == 'completed'
        ? stages.length
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 900 ? 40.0 : 16.0;

        return SingleChildScrollView(
          controller: stepperScrollController,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(
                    task: task,
                    taskStatus: taskStatus,
                    orderStatus: orderStatus,
                    stages: stages,
                  ),
                  const SizedBox(height: 18),
                  _buildDescriptionCard(task),
                  const SizedBox(height: 18),
                  _buildProgressCard(
                    taskStatus: taskStatus,
                    stages: stages,
                    completedCount: completedCount,
                  ),
                  const SizedBox(height: 18),
                  _buildActivityCard(stages),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard({
    required Map<String, dynamic> task,
    required String taskStatus,
    required String orderStatus,
    required List<String> stages,
  }) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: _primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (task['taskTitle'] ?? 'Untitled Task').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (task['orderType'] ?? 'Order').toString().toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusBadge(
                icon: Icons.task_alt_rounded,
                label: 'Task: $taskStatus',
                status: taskStatus,
              ),
              _statusBadge(
                icon: Icons.local_shipping_outlined,
                label: 'Order: $orderStatus',
                status: orderStatus,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(Map<String, dynamic> task) {
    final description =
        (task['description'] ?? 'No description provided.').toString();

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.notes_rounded,
            title: 'Description',
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String taskStatus,
    required List<String> stages,
    required int completedCount,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: taskRef.collection('history').snapshots(),
      builder: (context, snap) {
        final history = snap.data?.docs ?? [];

        int completed = 0;
        int active = 0;

        for (final stage in stages) {
          final entry = _findHistoryDocById(
            history,
            _safeId(stage),
          );

          final status = entry?.data()['status'];
          if (status == 'Completed') {
            completed++;
          } else if (status == 'Started') {
            active++;
          }
        }

        final progress = stages.isEmpty ? 0.0 : completed / stages.length;

        return _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _sectionTitle(
                      icon: Icons.insights_rounded,
                      title: 'Task Progress',
                    ),
                  ),
                  Text(
                    '$completed/${stages.length}',
                    style: GoogleFonts.poppins(
                      color: _primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _smallMetric(
                    icon: Icons.check_circle_outline,
                    label: '$completed completed',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 14),
                  _smallMetric(
                    icon: Icons.play_circle_outline,
                    label: '$active active',
                    color: Colors.orange,
                  ),
                  const Spacer(),
                  Text(
                    taskStatus,
                    style: GoogleFonts.poppins(
                      color: Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityCard(List<String> stages) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: taskRef.collection('history').snapshots(),
      builder: (context, snap) {
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> history =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snap.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        )..sort((a, b) {
            final aTs = _timestampToDate(a.data()['startTimestamp']);
            final bTs = _timestampToDate(b.data()['startTimestamp']);

            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;

            return aTs.compareTo(bTs);
          });

        return _surfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _sectionTitle(
                        icon: Icons.route_rounded,
                        title: 'Activity Timeline',
                      ),
                    ),
                    Text(
                      '${stages.length} activities',
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  children: List.generate(stages.length, (index) {
                    return _buildActivityItem(
                      stage: stages[index],
                      index: index,
                      stages: stages,
                      history: history,
                      isLast: index == stages.length - 1,
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem({
    required String stage,
    required int index,
    required List<String> stages,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> history,
    required bool isLast,
  }) {
    final safeId = _safeId(stage);
    final entry = _findHistoryDocById(history, safeId);
    final data = entry?.data();

    final status = (data?['status'] ?? 'Pending').toString();
    final isStarted = status == 'Started';
    final isCompleted = status == 'Completed';

    final previousCompleted = index == 0 ||
        _stageIsCompleted(
          history,
          stages[index - 1],
        );

    // Reset is available only for an activity that has actually been
    // started or completed. A Pending activity must not show Reset.
    //
    // History documents intentionally remain in Firestore after reset so
    // the workflow hierarchy is preserved, therefore checking `entry != null`
    // here would incorrectly show Reset on pending activities.
    final resetEnabled = isStarted || isCompleted;

    DateTime? timestamp;
    if (isCompleted) {
      timestamp = _timestampToDate(data?['completeTimestamp']);
    } else if (isStarted) {
      timestamp = _timestampToDate(data?['startTimestamp']);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Column(
            children: [
              _timelineIcon(
                stage: stage,
                isStarted: isStarted,
                isCompleted: isCompleted,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 105,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isCompleted
                      ? Colors.green.withOpacity(.45)
                      : Colors.grey.shade300,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withOpacity(.035)
                  : isStarted
                      ? Colors.orange.withOpacity(.045)
                      : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted
                    ? Colors.green.withOpacity(.20)
                    : isStarted
                        ? Colors.orange.withOpacity(.22)
                        : _border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        stage,
                        style: GoogleFonts.poppins(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _activityStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      timestamp != null
                          ? Icons.schedule_rounded
                          : Icons.hourglass_empty_rounded,
                      size: 14,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        timestamp != null
                            ? _formatDateTime(timestamp)
                            : 'Waiting for previous activity',
                        style: GoogleFonts.poppins(
                          color: Colors.black45,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isStarted && !isCompleted)
                      FilledButton.icon(
                        onPressed: previousCompleted && !_isProcessingAction
                            ? () => _onStartPressed(stage)
                            : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start'),
                        style: _primaryButtonStyle(),
                      ),
                    if (isStarted && !isCompleted)
                      FilledButton.icon(
                        onPressed: !_isProcessingAction
                            ? () => _onCompletePressed(stage)
                            : null,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Complete'),
                        style: _completeButtonStyle(),
                      ),
                    if (resetEnabled)
                      OutlinedButton.icon(
                        onPressed: !_isProcessingAction
                            ? () => _confirmResetActivity(
                                  stage: stage,
                                  index: index,
                                  stages: stages,
                                )
                            : null,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: Text(
                          index == stages.length - 1
                              ? 'Reset'
                              : 'Reset from here',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(
                            color: Colors.red.shade200,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!previousCompleted && !isStarted && !isCompleted) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: Colors.black38,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Complete the previous activity first.',
                          style: GoogleFonts.poppins(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmResetActivity({
    required String stage,
    required int index,
    required List<String> stages,
  }) async {
    final laterCount = stages.length - index - 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Reset activity?',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            laterCount == 0
                ? 'Reset "$stage" to its original pending state? Its start and completion timestamps will also be cleared.'
                : 'Reset "$stage" and the $laterCount activity${laterCount == 1 ? '' : 'ies'} after it? All nested activity statuses and timestamps will be reset.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _onResetActivity(
      stage: stage,
      index: index,
      stages: stages,
    );
  }

  Future<void> _onStartPressed(String stage) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      await _startProcess(stage);
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _onCompletePressed(String stage) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      await _completeProcess(stage);
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _onResetActivity({
    required String stage,
    required int index,
    required List<String> stages,
  }) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      await _resetActivity(
        stage: stage,
        index: index,
        stages: stages,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            index == stages.length - 1
                ? '$stage has been reset.'
                : '$stage and all following activities have been reset.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to reset activity: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  // START PROCESS
  //
  // Existing Firestore paths and status behaviour are preserved.
  // The first start additionally stores the original task/order status so
  // reset can restore the exact pre-process values.
  Future<void> _startProcess(String stage) async {
    final segments = widget.taskPath.split('/');
    final companyId = segments[1];
    final orderId = segments[3];

    final safeId = _safeId(stage);
    final historyDoc = taskRef.collection('history').doc(safeId);

    final orderRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId);

    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() ?? {};

    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data() ?? {};

    final orderType =
        (taskData['orderType'] ?? 'stock').toString().toLowerCase();

    final stages = _getStages(orderType);
    final isFirst =
        stage.trim().toLowerCase() == stages.first.trim().toLowerCase();

    final batch = FirebaseFirestore.instance.batch();

    batch.set(
      historyDoc,
      {
        'process': stage,
        'status': 'Started',
        'startTimestamp': FieldValue.serverTimestamp(),
        'completeTimestamp': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    if (isFirst) {
      final originalTaskStatus =
          (taskData['statusBeforeProcess'] ??
                  taskData['status'] ??
                  'Pending')
              .toString();

      final originalOrderStatus =
          (orderData['orderStatusBeforeProcess'] ??
                  orderData['orderStatus'] ??
                  'Received')
              .toString();

      final taskUpdate = <String, dynamic>{
        'status': 'In Progress',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final orderUpdate = <String, dynamic>{
        'orderStatus': stage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Capture the original values only once. This prevents a later
      // restart of the workflow from overwriting the true baseline.
      if (!taskData.containsKey('statusBeforeProcess')) {
        taskUpdate['statusBeforeProcess'] = originalTaskStatus;
      }

      if (!orderData.containsKey('orderStatusBeforeProcess')) {
        orderUpdate['orderStatusBeforeProcess'] = originalOrderStatus;
      }

      batch.update(taskRef, taskUpdate);
      batch.update(orderRef, orderUpdate);
    } else {
      batch.update(orderRef, {
        'orderStatus': stage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // COMPLETE PROCESS
  Future<void> _completeProcess(String stage) async {
    final segments = widget.taskPath.split('/');
    final companyId = segments[1];
    final orderId = segments[3];

    final safeId = _safeId(stage);
    final historyDoc = taskRef.collection('history').doc(safeId);

    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() ?? {};

    final orderType =
        (taskData['orderType'] ?? 'stock').toString().toLowerCase();

    final stages = _getStages(orderType);
    final isLast =
        stage.trim().toLowerCase() == stages.last.trim().toLowerCase();

    // RAW PROCESS VALIDATION
    if (stage.trim().toLowerCase() == 'raw process') {
      final orderRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('orders')
          .doc(orderId);

      final orderSnap = await orderRef.get();
      final orderData = orderSnap.data() ?? {};
      final rawUsed = orderData['rawUsed'];

      if (rawUsed == null || rawUsed is! Map || rawUsed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot complete Raw Process. No raw material usage found.',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final batch = FirebaseFirestore.instance.batch();

    batch.update(historyDoc, {
      'status': 'Completed',
      'completeTimestamp': FieldValue.serverTimestamp(),
    });

    final orderRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId);

    if (isLast) {
      batch.update(taskRef, {
        'status': 'Completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(orderRef, {
        'orderStatus': 'Completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final finalDoc = taskRef.collection('history').doc('task_completed');

      batch.set(
        finalDoc,
        {
          'process': 'Task Completed',
          'status': 'Completed',
          'timestamp': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  // RESET ACTIVITY
  //
  // Resetting an activity also resets every activity after it because those
  // activities depend on the selected activity being completed first.
  //
  // The history documents remain in Firestore, but their workflow state and
  // timestamps are returned to Pending/empty. This means the same document
  // IDs and Firestore hierarchy are preserved.
  Future<void> _resetActivity({
    required String stage,
    required int index,
    required List<String> stages,
  }) async {
    final segments = widget.taskPath.split('/');
    final companyId = segments[1];
    final orderId = segments[3];

    final orderRef = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId);

    final taskSnap = await taskRef.get();
    final taskData = taskSnap.data() ?? {};

    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data() ?? {};

    final batch = FirebaseFirestore.instance.batch();

    // Reset the selected activity and every dependent activity.
    for (int i = index; i < stages.length; i++) {
      final stageName = stages[i];
      final historyDoc =
          taskRef.collection('history').doc(_safeId(stageName));

      batch.set(
        historyDoc,
        {
          'process': stageName,
          'status': 'Pending',
          'startTimestamp': FieldValue.delete(),
          'completeTimestamp': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    }

    // The synthetic completion history entry must never remain completed
    // after any activity is reset.
    final taskCompletedDoc =
        taskRef.collection('history').doc('task_completed');

    batch.delete(taskCompletedDoc);

    // Find the last activity that is still completed before the reset point.
    int previousCompletedIndex = -1;

    if (index > 0) {
      final historySnap = await taskRef.collection('history').get();
      final historyById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
        for (final doc in historySnap.docs) doc.id: doc,
      };

      for (int i = index - 1; i >= 0; i--) {
        final doc = historyById[_safeId(stages[i])];

        if (doc?.data()['status'] == 'Completed') {
          previousCompletedIndex = i;
          break;
        }
      }
    }

    if (previousCompletedIndex >= 0) {
      // Some earlier workflow activity is still completed.
      final previousStage = stages[previousCompletedIndex];

      batch.update(taskRef, {
        'status': 'In Progress',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(orderRef, {
        'orderStatus': previousStage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // No activity remains completed. Restore the exact values captured
      // before the first process was started.
      final originalTaskStatus =
          (taskData['statusBeforeProcess'] ?? 'Pending').toString();

      final originalOrderStatus =
          (orderData['orderStatusBeforeProcess'] ?? 'Received').toString();

      batch.update(taskRef, {
        'status': originalTaskStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(orderRef, {
        'orderStatus': originalOrderStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _findHistoryDocById(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> history,
    String safeId,
  ) {
    for (final h in history) {
      if (h.id == safeId) return h;
    }

    return null;
  }

  bool _stageIsCompleted(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> history,
    String stage,
  ) {
    final entry = _findHistoryDocById(history, _safeId(stage));
    return entry?.data()['status'] == 'Completed';
  }

  String _safeId(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();

    String two(int n) => n.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  List<String> _getStages(String orderType) {
    if (orderType == 'stock') {
      return [
        'Packing Process',
        'Shipping Process',
      ];
    }

    return [
      'Raw Process',
      'Color Process',
      'Fitting Process',
      'Demo Process',
      'Packing Process',
      'Shipping Process',
    ];
  }

  IconData _iconForStage(String stage) {
    final s = stage.toLowerCase();

    if (s.contains('raw')) return Icons.layers_rounded;
    if (s.contains('color')) return Icons.color_lens_rounded;
    if (s.contains('fitting')) return Icons.handyman_rounded;
    if (s.contains('demo')) return Icons.screen_share_rounded;
    if (s.contains('packing')) return Icons.inventory_2_rounded;
    if (s.contains('shipping')) return Icons.local_shipping_rounded;

    return Icons.task_rounded;
  }

  Widget _timelineIcon({
    required String stage,
    required bool isStarted,
    required bool isCompleted,
  }) {
    final Color color;
    final IconData icon;

    if (isCompleted) {
      color = Colors.green;
      icon = Icons.check_rounded;
    } else if (isStarted) {
      color = Colors.orange;
      icon = Icons.play_arrow_rounded;
    } else {
      color = Colors.grey.shade400;
      icon = _iconForStage(stage);
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(.25),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 21,
      ),
    );
  }

  Widget _activityStatusBadge(String status) {
    final lower = status.toLowerCase();

    Color color = Colors.grey;
    if (lower == 'started') color = Colors.orange;
    if (lower == 'completed') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusBadge({
    required IconData icon,
    required String label,
    required String status,
  }) {
    final lower = status.toLowerCase();

    Color color = _primary;
    if (lower.contains('completed')) {
      color = Colors.green;
    } else if (lower.contains('progress')) {
      color = Colors.orange;
    } else if (lower.contains('shipping')) {
      color = Colors.deepOrange;
    } else if (lower.contains('packing')) {
      color = Colors.teal;
    } else if (lower.contains('raw')) {
      color = Colors.brown;
    } else if (lower.contains('color')) {
      color = Colors.purple;
    } else if (lower.contains('fitting')) {
      color = Colors.indigo;
    } else if (lower.contains('demo')) {
      color = Colors.cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallMetric({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _primary.withOpacity(.09),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: _primary,
            size: 17,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: _textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _surfaceCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  ButtonStyle _completeButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: Colors.green.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      textStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

