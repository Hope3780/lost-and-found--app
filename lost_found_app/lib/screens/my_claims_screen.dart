import 'package:flutter/material.dart';
import '../models/found_item.dart';
import '../models/lost_item.dart';
import '../services/supabase_service.dart';
import '../widgets/cut_logo_badge.dart';

import '../widgets/fade_slide_in.dart';
import '../widgets/status_chip.dart';
import 'item_detail_screen.dart';
import 'lost_item_detail_screen.dart';

// One row in the "My reports" list (either a found item or a lost report)
class _ReportEntry {
  final String name;
  final String subtitle;
  final String? photoUrl;
  final String status;
  final DateTime when;
  final FoundItem? found;
  final LostItem? lost;

  const _ReportEntry({
    required this.name,
    required this.subtitle,
    required this.photoUrl,
    required this.status,
    required this.when,
    this.found,
    this.lost,
  });
}

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  static const _heading = Color(0xFF5BB0FF);
  static const _cardBlue = Color(0xFFE8EEF7);
  static const _mutedText = Color(0xFFB8C4D4);

  final _service = SupabaseService();
  List<FoundItem> _claims = [];
  List<_ReportEntry> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (claims, myFound, myLost) = await (
        _service.fetchMyClaims(),
        _service.fetchMyFoundReports(),
        // If the lost table can't be read, still show everything else
        _service.fetchMyLostReports().catchError((_) => <LostItem>[]),
      ).wait;

      final reports = <_ReportEntry>[
        for (final f in myFound)
          _ReportEntry(
            name: f.itemName,
            subtitle: '${f.locationFound} • Found',
            photoUrl: f.photoUrl,
            status: f.status,
            when: f.createdAt ?? f.dateFound,
            found: f,
          ),
        for (final l in myLost)
          _ReportEntry(
            name: l.itemName,
                        subtitle: l.listSubtitle,
            photoUrl: l.photoUrl,
            status: l.status,
            when: l.createdAt,
            lost: l,
          ),
      ]..sort((a, b) => b.when.compareTo(a.when));

      if (!mounted) return;
      setState(() {
        _claims = claims;
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load claims failed: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // The reporter may have picked a category on the Report Found screen;
  // it is stored as the first line of the description ("Category: Keys").
  String? _categoryOf(FoundItem item) {
    final firstLine = item.description.split('\n').first.trim();
    const prefix = 'Category: ';
    if (firstLine.startsWith(prefix)) {
      final c = firstLine.substring(prefix.length).trim();
      return c.isEmpty ? null : c;
    }
    return null;
  }

  // Status of a claim, as shown under the item name
  (String, Color) _claimStatus(String status) {
    switch (status) {
      case 'claim_pending':
        return ('Awaiting review', const Color(0xFFB7791F));
      case 'available_for_collection':
        return ('Available for Collection', const Color(0xFF1C6B34));
      case 'returned':
        return ('Collected', const Color(0xFF1C6B34));
      case 'rejected':
        return ('Unsuccessful Report', const Color(0xFFB42318));
      default:
        return (_statusLabel(status), const Color(0xFFB7791F));
    }
  }

  // Status of a report, as shown on the right of the row
  String _statusLabel(String status) {
    switch (status) {
      case 'claim_pending':
        return 'Claim pending';
      case 'under_review':
        return 'Under review';
      case 'verified':
        return 'Verified';
      case 'available_for_collection':
        return 'Available for Collection';
              case 'item_found':
        return 'Item found';
      case 'rejected':
        return 'Unsuccessful Report';
      case 'returned':
        return 'Collected';
      case 'pending':
        return 'Pending';
      default:
        return 'Pending';
    }
  }

  Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          color: _heading,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: _mutedText)),
    );
  }

  Widget _heroWrap(String? tag, Widget child) =>
      tag == null ? child : Hero(tag: tag, child: child);

  Widget _thumb(String? url, {String? heroTag}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: url != null
            ? _heroWrap(
                heroTag,
                Container(
                  color: const Color(0xFFEEF2F7),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                  ),
                ),
              )
            : _thumbPlaceholder(),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: _cardBlue,
      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6B7785)),
    );
  }

  // White card used by both lists
  Widget _card({required VoidCallback onTap, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        elevation: 5,
        shadowColor: const Color(0x66000000),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _claimTile(FoundItem item) {
    final category = _categoryOf(item);
    final subtitle = category != null
        ? '$category • ${item.locationFound}'
        : item.locationFound;
    final (statusText, statusColor) = _claimStatus(item.status);

    return _card(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              item: item,
              heroTag: 'photo-claim-${item.id}',
            ),
          ),
        );
        _load();
      },
      child: Row(
        children: [
          _thumb(item.photoUrl, heroTag: 'photo-claim-${item.id}'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2A37),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7785)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Found • ',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF6B7785))),
                    Flexible(
                      child: Text(
                        statusText,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportTile(_ReportEntry entry) {
    final heroTag = 'photo-report-${entry.found?.id ?? entry.lost!.id}';
    return _card(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => entry.found != null
                ? ItemDetailScreen(item: entry.found!, heroTag: heroTag)
                : LostItemDetailScreen(item: entry.lost!, heroTag: heroTag),
          ),
        );
        _load();
      },
      child: Row(
        children: [
          _thumb(entry.photoUrl, heroTag: heroTag),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2A37),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7785)),
                ),
                const SizedBox(height: 8),
                StatusChip(
                  status: entry.status,
                  label: _statusLabel(entry.status),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: CutLogoBadge.toolbarHeight,
        title: const Text(
          'Claims & Reports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: CutLogoBadge(),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    // ---------- My claims ----------
                    staggerIn(0, _sectionHeading('My claims')),
                    if (_claims.isEmpty)
                      staggerIn(1, _emptyText("You haven't claimed any items yet."))
                    else
                      for (var i = 0; i < _claims.length; i++)
                        staggerIn(i + 1, _claimTile(_claims[i])),

                    const SizedBox(height: 26),

                    // ---------- My reports ----------
                    staggerIn(_claims.length + 2, _sectionHeading('My reports')),
                    if (_reports.isEmpty)
                      staggerIn(_claims.length + 3,
                          _emptyText("You haven't reported anything yet."))
                    else
                      for (var i = 0; i < _reports.length; i++)
                        staggerIn(_claims.length + 3 + i, _reportTile(_reports[i])),

                  ],
                ),
              ),
      ),
    );
  }
}