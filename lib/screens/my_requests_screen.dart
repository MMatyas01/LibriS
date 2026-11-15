import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllAsSeen());
  }

  Future<void> _markAllAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('book_requests')
          .where('userId', isEqualTo: user.uid)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      bool hasChanges = false;

      for (final doc in snap.docs) {
        final data = doc.data();
        final reviewed = data['reviewedAt'] as Timestamp?;
        final seen = data['seenByUserAt'] as Timestamp?;
        if (reviewed == null) continue;
        if (seen != null && seen.compareTo(reviewed) >= 0) continue;

        batch.update(doc.reference, {
          'seenByUserAt': FieldValue.serverTimestamp(),
        });
        hasChanges = true;
      }

      if (hasChanges) await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verticalGap = MediaQuery.sizeOf(context).height * 0.02;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Requests', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: _userId == null
            ? const Center(child: Text('Please sign in.'))
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('book_requests')
                    .where('userId', isEqualTo: _userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load your requests.'),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "You haven't requested any books yet.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['createdAt'] as Timestamp?;
                      final bTime = bData['createdAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => SizedBox(height: verticalGap),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _RequestCard(data: data);
                    },
                  );
                },
              ),
      ),
    );
  }
}

// ============================================================================
// Egy kérés kártyája – elbírált esetén koppintható
// ============================================================================

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RequestCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (data['status'] as String?) ?? 'pending';
    final adminNote = data['adminNote'] as String?;
    final reviewedAt = data['reviewedAt'] as Timestamp?;
    final isReviewed = reviewedAt != null;

    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['proposedTitle'] as String?) ?? 'Untitled',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (data['proposedAuthor'] as String?) ?? 'Unknown author',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(status: status),
            ],
          ),
          if (isReviewed) ...[
            const SizedBox(height: 12),
            Text(
              'Reviewed ${_formatDate(reviewedAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
          if (adminNote != null && adminNote.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.message_outlined,
                    size: 16,
                    color: AppColors.forest,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      adminNote,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isReviewed) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View details ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  color: AppColors.forest,
                  size: 14,
                ),
              ],
            ),
          ],
        ],
      ),
    );

    // Csak elbírált kérésnél koppintható – pending alatt nem
    if (!isReviewed) return cardContent;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetailsDialog(context),
      child: cardContent,
    );
  }

  void _showDetailsDialog(BuildContext context) {
    final theme = Theme.of(context);
    final status = (data['status'] as String?) ?? 'pending';
    final adminNote = data['adminNote'] as String?;
    final reviewedAt = data['reviewedAt'] as Timestamp?;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Request details',
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Book title',
                    (data['proposedTitle'] as String?) ?? '—'),
                _detailRow('Author',
                    (data['proposedAuthor'] as String?) ?? '—'),
                if (data['isbn'] != null)
                  _detailRow('ISBN', data['isbn'] as String),
                if (data['publicationYear'] != null)
                  _detailRow('Publication year',
                      '${data['publicationYear']}'),
                if (data['publisher'] != null)
                  _detailRow('Publisher', data['publisher'] as String),
                if (data['imageUrl'] != null)
                  _detailRow('Cover image URL', data['imageUrl'] as String),
                const Divider(height: 24),
                Row(
                  children: [
                    Text(
                      'Status',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusBadge(status: status),
                  ],
                ),
                if (reviewedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Reviewed ${_formatDate(reviewedAt)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (adminNote != null && adminNote.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sage.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADMIN NOTE',
                          style: TextStyle(
                            color: AppColors.forest,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adminNote,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.charcoal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp ts) {
    final dt = ts.toDate();
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _configFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _BadgeConfig _configFor(String status) {
    switch (status) {
      case 'approved':
        return _BadgeConfig('Approved', AppColors.forest);
      case 'rejected':
        return _BadgeConfig('Rejected', AppColors.error);
      case 'cancelled':
        return _BadgeConfig('Cancelled', AppColors.secondary);
      case 'pending':
      default:
        return _BadgeConfig('Pending', AppColors.terracotta);
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color color;
  _BadgeConfig(this.label, this.color);
}

// ============================================================================
// Drop-in widget a Profile screenre
// ============================================================================

class MyRequestsTile extends StatefulWidget {
  const MyRequestsTile({super.key});

  @override
  State<MyRequestsTile> createState() => _MyRequestsTileState();
}

class _MyRequestsTileState extends State<MyRequestsTile> {
  late final Stream<int> _unseenCountStream;

  @override
  void initState() {
    super.initState();
    _unseenCountStream = _unseenReviewedCount();
  }

  Stream<int> _unseenReviewedCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('book_requests')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data();
        final reviewed = data['reviewedAt'] as Timestamp?;
        final seen = data['seenByUserAt'] as Timestamp?;
        if (reviewed == null) return false;
        if (seen == null) return true;
        return seen.compareTo(reviewed) < 0;
      }).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.inbox_outlined, color: AppColors.charcoal),
      title: const Text('My Requests'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<int>(
            stream: _unseenCountStream,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.secondary),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
        );
      },
    );
  }
}