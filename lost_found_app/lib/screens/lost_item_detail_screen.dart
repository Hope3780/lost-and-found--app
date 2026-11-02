import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lost_item.dart';
import '../services/supabase_service.dart';
import '../widgets/cut_logo_badge.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/status_timeline.dart';
import '../widgets/success_check.dart';
import 'photo_viewer_screen.dart';

class LostItemDetailScreen extends StatefulWidget {
  final LostItem item;

  /// Same tag as the thumbnail on the previous screen, so the photo flies in.
  final String? heroTag;

  const LostItemDetailScreen({super.key, required this.item, this.heroTag});

  @override
  State<LostItemDetailScreen> createState() => _LostItemDetailScreenState();
}

class _LostItemDetailScreenState extends State<LostItemDetailScreen> {
  static const _indigo = Color(0xFF3B2FE0);
  static const _labelColor = Color(0xFFB8C4D4);
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  final _service = SupabaseService();
  bool _claiming = false;
  bool _justClaimed = false;
  late final Stream<LostItem> _itemStream;

  @override
  void initState() {
    super.initState();
    // Live view of this one row, so admin changes show up immediately
    _itemStream = Supabase.instance.client
        .from('lost_items')
        .stream(primaryKey: ['id'])
        .eq('id', widget.item.id)
        .map((rows) =>
            rows.isEmpty ? widget.item : LostItem.fromMap(rows.first));
  }

  // The photo flies in from the list thumbnail (Hero), so it skips the
  // fade-in; without a hero tag it fades in like everything else.
  Widget _heroWrap(Widget child) =>
      widget.heroTag == null ? child : Hero(tag: widget.heroTag!, child: child);

  Widget _photoReveal(Widget child) =>
      widget.heroTag != null ? child : staggerIn(0, child);

  String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _claim() async {
    setState(() => _claiming = true);
    try {
      await _service.claimLostItem(widget.item.id);
      if (!mounted) return;
      setState(() => _justClaimed = true);
      await showSuccessCheck(
        context,
        title: 'Claim submitted',
        subtitle: 'Protection Services will review it.',
      );
    } catch (e) {
      debugPrint('Claim lost item failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not submit your claim. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  // Message shown at the bottom (text, colour, icon)
  (String, Color, IconData) _statusInfo(String status, bool isOwner) {
    switch (status) {
      case 'under_review':
        return (
          'Protection Services is looking for this item.',
          const Color(0xFF64B5F6),
          Icons.search
        );
      case 'item_found':
        return isOwner
            ? (
                'Good news — this item has been found!',
                const Color(0xFF66BB6A),
                Icons.celebration_outlined
              )
            : (
                'This item has been found and is waiting for its owner.',
                const Color(0xFF66BB6A),
                Icons.check_circle_outline
              );
      case 'claim_pending':
        return (
          'Claim submitted. Protection Services will review it — follow it under Claims & Reports.',
          const Color(0xFFE5A823),
          Icons.hourglass_top_rounded
        );
      case 'available_for_collection':
        return (
          'Ready for collection at Protection Services.',
          const Color(0xFF66BB6A),
          Icons.inventory_2_outlined
        );
      case 'returned':
        return (
          'Collected — this item has been returned.',
          const Color(0xFF66BB6A),
          Icons.check_circle_outline
        );
      case 'rejected':
        return (
          'This report was unsuccessful.',
          const Color(0xFFEF5350),
          Icons.cancel_outlined
        );
      default:
        return isOwner
            ? (
                'Reported. Protection Services will match it against items handed in.',
                const Color(0xFFE5A823),
                Icons.hourglass_top_rounded
              )
            : (
                'Reported lost. If you have found this, hand it in at Protection Services.',
                _labelColor,
                Icons.info_outline
              );
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: _labelColor, fontSize: 15)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LostItem>(
      stream: _itemStream,
      initialData: widget.item,
      builder: (context, snapshot) {
        final item = snapshot.data ?? widget.item;
        final isOwner = item.reportedBy != null &&
            item.reportedBy == _service.currentUser?.id;

        // After a successful claim, show the pending message straight away
        final status = (_justClaimed && item.status == 'item_found')
            ? 'claim_pending'
            : item.status;
        final canClaim = isOwner && status == 'item_found';
        final hasNote = item.staffNote != null && item.staffNote!.isNotEmpty;
        final (statusText, statusColor, statusIcon) =
            _statusInfo(status, isOwner);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: CutLogoBadge.toolbarHeight,
            title: const Text('Item details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 20), child: CutLogoBadge()),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (item.photoUrl != null)
                            _photoReveal(Center(
                              child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: GestureDetector(
                                onTap: () => openPhotoViewer(
                                  context,
                                  url: item.photoUrl!,
                                  heroTag: widget.heroTag,
                                ),
                                child: _heroWrap(ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: ColoredBox(
                                  color: const Color(0xFFF1F4F9),
                                  child: ConstrainedBox(
                                    // The box takes the picture's own shape;
                                    // only very tall photos are capped.
                                    constraints:
                                        const BoxConstraints(maxHeight: 480),
                                    child: Image.network(
                                      item.photoUrl!,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      loadingBuilder: (context, child, progress) =>
                                          progress == null
                                              ? child
                                              : const SizedBox(
                                                  height: 180,
                                                  child: Center(
                                                    child: CircularProgressIndicator(
                                                      color: Color(0xFF3B2FE0),
                                                    ),
                                                  ),
                                                ),
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(
                                        height: 160,
                                        child: Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Color(0xFF8A97A6),
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )),
                              ),
                            )))),
                          const SizedBox(height: 22),
                          staggerIn(1, Text(
                            item.itemName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          )),
                          const SizedBox(height: 14),
                          staggerIn(2, _row('Type', 'Lost')),
                          staggerIn(3, _row('Category', item.category)),
                                                      if (item.locationLost != null &&
                              item.locationLost!.trim().isNotEmpty)
                            staggerIn(4, _row('Location', item.locationLost!)),
                          staggerIn(5, _row('Date Reported', _formatDate(item.createdAt))),
                          const SizedBox(height: 18),
                          staggerIn(
                            6,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Progress',
                                    style: TextStyle(
                                        color: _labelColor, fontSize: 15)),
                                const SizedBox(height: 12),
                                StatusTimeline(
                                  steps: StatusTimeline.lostSteps,
                                  current: StatusTimeline.lostIndex(status),
                                  rejected: status == 'rejected',
                                  currentColor: statusColor,
                                  delay: const Duration(milliseconds: 950),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          staggerIn(
                            7,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Description',
                                    style: TextStyle(
                                        color: _labelColor, fontSize: 15)),
                                const SizedBox(height: 6),
                                Text(
                                  item.description.isEmpty ? '—' : item.description,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          if (hasNote) ...[
                            const SizedBox(height: 18),
                            const Text('Note from Protection Services',
                                style: TextStyle(
                                    color: _labelColor, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(
                              item.staffNote!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Status message (above the button, if there is one)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                  // Claim button: owner only, once the item has been found
                  if (canClaim) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _claiming ? null : _claim,
                        child: _claiming
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'This is mine',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],

                  
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
