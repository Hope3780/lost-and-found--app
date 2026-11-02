import 'dart:async';
import 'package:flutter/material.dart';
import '../models/found_item.dart';
import '../models/lost_item.dart';
import '../services/supabase_service.dart';
import '../widgets/app_background.dart';
import '../widgets/cut_logo_badge.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/status_chip.dart';
import 'item_detail_screen.dart';
import 'lost_item_detail_screen.dart';
import 'my_claims_screen.dart';
import 'report_item_screen.dart';
import 'report_lost_screen.dart';

// One row in the Recent Reports list (either a found item or a lost report)
class _Entry {
  final String name;
  final String subtitle;
  final String? photoUrl;
  final String status;
  final DateTime when;
  final FoundItem? found;
  final LostItem? lost;

  // Used by the search filters (found items have no category)
  final String? category;
  final String location;

  const _Entry({
    required this.name,
    required this.subtitle,
    required this.photoUrl,
    required this.status,
    required this.when,
    this.category,
    this.location = '',
    this.found,
    this.lost,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _cardBlue = Color(0xFFE8EEF7);
  static const _textBlue = Color(0xFF17396A);
  static const _mutedText = Color(0xFFB8C4D4);

  final _service = SupabaseService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  List<_Entry> _entries = [];
  bool _loading = true;

  // True after tapping "See all reports" (otherwise only the 5 newest show)
  final _searchFocus = FocusNode();

  // ---------- "Search by" dropdown ----------
  // null = search by item name (the default, shown as "Name" in the menu). Otherwise the text typed in
  // the search bar is matched against that field instead.
  static const _searchByOptions = ['Name', 'Category', 'Location', 'Status'];
  String? _searchBy;

  // Same five stages as the progress tracker, so typing "review" or
  // "collect" finds what people see in each report.
  String _statusText(String status) {
    switch (status) {
      case 'under_review':
      case 'verified':
      case 'item_found':
      case 'claim_pending':
        return 'Under review';
      case 'available_for_collection':
        return 'Available for Collection';
      case 'returned':
        return 'Collected';
      case 'rejected':
        return 'Unsuccessful Report';
      default:
        return 'Pending';
    }
  }

  // The reports that match the search text for the chosen "search by" field
  List<_Entry> get _filtered {
    final text = _searchController.text.trim().toLowerCase();
    if (_searchBy == null || text.isEmpty) return _entries;
    return _entries.where((e) {
      switch (_searchBy) {
        case 'Category':
          return (e.category ?? '').toLowerCase().contains(text);
        case 'Location':
          return e.location.toLowerCase().contains(text);
        default:
          return _statusText(e.status).toLowerCase().contains(text);
      }
    }).toList();
  }

  // True while the opening "show" is playing; afterwards new list items
  // (e.g. search results) animate in faster.
  bool _intro = true;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(const Duration(seconds: 3), () => _intro = false);
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _reload();
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppBackground.setFooterHidden(this, false));
    super.dispose();
  }

    // Loads found items + everyone's lost reports, newest first
  Future<void> _reload() async {
    final query = _searchController.text.trim();
    // Only name searches are sent to the server
    final term = (query.isEmpty || _searchBy != null) ? null : query;
    final requestId = ++_requestId;

    try {
      final (found, lost) = await (
        _service.fetchAvailableItems(searchTerm: term),
        // If the lost table can't be read, still show the found items
        _service
            .fetchAllLostReports(searchTerm: term)
            .catchError((_) => <LostItem>[]),
      ).wait;

      final entries = <_Entry>[
        for (final f in found)
          _Entry(
            name: f.itemName,
            subtitle: '${f.locationFound} • Found',
            photoUrl: f.photoUrl,
            status: f.status,
            when: f.createdAt ?? f.dateFound,
            location: f.locationFound,
            found: f,
          ),
        for (final l in lost)
          _Entry(
            name: l.itemName,
                        subtitle: l.listSubtitle,
            photoUrl: l.photoUrl,
            status: l.status,
            when: l.createdAt,
            category: l.category,
            location: l.locationLost ?? '',
            lost: l,
          ),
      ]..sort((a, b) => b.when.compareTo(a.when));

      // Ignore stale responses (e.g. from an earlier keystroke)
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _loading = false);
    }
  }

  // Recent Reports: collected items are left out (they still show under
  // "See all reports" and in search), then the 5 newest of the rest.
  List<_Entry> get _recent => _entries
      .where((e) => e.status != 'returned')
      .take(5)
      .toList();

  // Tapping the search bar (or typing in it) lists every report, collected
  // ones included. Otherwise only the recent ones are shown.
  bool get _listAll => _searching || _searchFocus.hasFocus;

  bool get _searching => _searchController.text.trim().isNotEmpty;

  String get _heading {
    final count = (_loading && _entries.isEmpty) ? '' : ' (${_filtered.length})';
    if (_searching) return 'Search results$count';
    if (_listAll) return 'All Reports$count';
    return 'Recent Reports';
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    FocusScope.of(context).unfocus();
    _reload();
    setState(() {});
  }

  void _onSearchChanged(String value) {
    setState(() {}); // update the clear (X) button straight away
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  Future<void> _signOut() async {
    await _service.signOut();
    // AuthGate listens to auth changes and shows the welcome screen automatically
  }

  Future<void> _openReportFound() async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReportItemScreen()),
    );
    if (shouldRefresh == true) _reload();
  }

  Future<void> _openReportLost() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ReportLostScreen()),
    );
    if (submitted == true) _reload();
  }

  // First name for the greeting
  String get _firstName {
    final user = _service.currentUser;
    final meta = user?.userMetadata;
    final fullName = (meta?['full_name'] ?? meta?['name']) as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(' ').first;
    }
    final local = (user?.email ?? '').split('@').first;
    final first = local.split(RegExp(r'[._-]')).first;
    if (first.isEmpty || RegExp(r'^\d').hasMatch(first)) return 'there';
    return first[0].toUpperCase() + first.substring(1);
  }

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

  // Small filter icon inside the search bar. Tapping it opens the list of
  // what to search by (Name is the default).
  Widget _searchByMenu() {
    final active = _searchBy != null;
    final current = _searchBy ?? 'Name';
    return PopupMenuButton<String>(
      tooltip: 'Search by',
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 48),
      icon: Icon(
        Icons.tune_rounded,
        color: active ? const Color(0xFF2F6FED) : const Color(0xFF3A4A5C),
      ),
      onSelected: (v) {
        // "Name" is the default, stored as null
        setState(() => _searchBy = (v == 'Name') ? null : v);
        _reload(); // name search goes to the server, the rest is local
      },
      itemBuilder: (context) => [
        for (final o in _searchByOptions)
          PopupMenuItem<String>(
            value: o,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    o,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          current == o ? FontWeight.w700 : FontWeight.w500,
                      color: const Color(0xFF1F2A37),
                    ),
                  ),
                ),
                if (current == o)
                  const Icon(Icons.check, size: 18, color: Color(0xFF2F6FED)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // No footer on the home page. It is hidden only while this page is the
    // one showing, so pages opened from here still get it.
    final showing = ModalRoute.of(context)?.isCurrent ?? true;
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppBackground.setFooterHidden(this, showing));

    // The 5 newest uncollected reports, or everything while the search bar is in use
    final shown = _listAll ? _filtered : _recent;
    final base = Theme.of(context);
    return Theme(
      // Built-in device fonts only (nothing is downloaded): Trebuchet MS
      // where the device has it, otherwise the normal system font.
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: 'Trebuchet MS',
          fontFamilyFallback: const ['Segoe UI', 'Roboto', 'Arial'],
        ),
      ),
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Top bar ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'CUT LOST & FOUND',
                    style: TextStyle(
                      color: Color(0xFFCFD8E3),
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'Sign out',
                    onPressed: _signOut,
                  ),
                  const SizedBox(width: 4),
                  const CutLogoBadge(),
                ],
              ),
            ),

            // ---------- Scrollable content ----------
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  children: [
                    // While the search bar is in use only the list of reports
                    // shows: no greeting, report cards or links.
                    if (!_listAll) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      duration: const Duration(milliseconds: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                              children: [
                                const TextSpan(text: 'Hello, '),
                                TextSpan(
                                  text: _firstName,
                                  style: const TextStyle(
                                    color: Color(0xFF5BB0FF),
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const TextSpan(text: ' 👋'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5BB0FF), Color(0xFF2F6FED)],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ],

                    // Search bar (keyed so it keeps focus when the rest hides)
                    FadeSlideIn(
                      key: const ValueKey('search-bar'),
                      delay: const Duration(milliseconds: 250),
                      child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      cursorColor: _textBlue,
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF1F2A37)),
                      decoration: InputDecoration(
                        prefixIcon: _searchByMenu(),
                        hintText: _searchBy == null
                            ? 'Search lost or found items'
                            : 'Search by ${_searchBy!.toLowerCase()}',
                        hintStyle: const TextStyle(color: Color(0xFF6B7785)),
                        suffixIcon: _listAll
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    color: Color(0xFF3A4A5C)),
                                tooltip: 'Clear search',
                                onPressed: _clearSearch,
                              )
                            : const Icon(Icons.search,
                                color: Color(0xFF3A4A5C)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    ),

                    if (!_listAll) ...[
                    // My reports & claims
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 350),
                      child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const MyClaimsScreen()),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('My reports & claims',
                                style: TextStyle(fontSize: 14)),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 8),

                    // Report cards
                    Row(
                      children: [
                        _reportCard(
                          icon: Icons.add,
                          iconColor: const Color(0xFFB42318),
                          label: 'Report Lost',
                          subtitle: 'Tell us what went missing',
                          watermark: Icons.search_rounded,
                          delay: const Duration(milliseconds: 500),
                          onTap: _openReportLost,
                        ),
                        const SizedBox(width: 14),
                        _reportCard(
                          icon: Icons.check,
                          iconColor: const Color(0xFF1C6B34),
                          label: 'Report Found',
                          subtitle: 'Hand in what you found',
                          watermark: Icons.inventory_2_rounded,
                          delay: const Duration(milliseconds: 680),
                          onTap: _openReportFound,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    ],
                    if (_listAll) const SizedBox(height: 16),

                    FadeSlideIn(
                      delay: const Duration(milliseconds: 850),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5BB0FF),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _heading,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_loading && _entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    else if (_listAll && shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text('No items found.',
                              style: TextStyle(color: _mutedText)),
                        ),
                      )
                    else
                      for (var i = 0; i < shown.length; i++)
                        FadeSlideIn(
                          key: ValueKey(
                              shown[i].found?.id ?? shown[i].lost!.id),
                          // Extra reports from the search bar appear at once
                          duration: _listAll
                              ? const Duration(milliseconds: 220)
                              : const Duration(milliseconds: 650),
                          delay: _listAll
                              ? Duration.zero
                              : Duration(
                                  milliseconds: (_intro ? 950 : 0) +
                                      (i < 8 ? i : 8) * (_intro ? 100 : 50),
                                ),
                          child: _itemTile(shown[i]),
                        ),

                    // Room for the footer drawn by the global background
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // "Report Lost / Report Found" card
  Widget _reportCard({
    required IconData icon,
    required IconData watermark,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Duration delay = Duration.zero,
  }) {
    return Expanded(
      child: FadeSlideIn(
        delay: delay,
        duration: const Duration(milliseconds: 800),
        slideY: 40,
        scaleFrom: 0.8,
        curve: Curves.easeOutBack,
        child: _ReportCard(
          icon: icon,
          watermark: watermark,
          accent: iconColor,
          label: label,
          subtitle: subtitle,
          onTap: onTap,
        ),
      ),
    );
  }

  // White row in the Recent Reports list
  Widget _itemTile(_Entry entry) {
    final heroTag = 'photo-home-${entry.found?.id ?? entry.lost!.id}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        elevation: 5,
        shadowColor: const Color(0x66000000),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => entry.found != null
                    ? ItemDetailScreen(item: entry.found!, heroTag: heroTag)
                    : LostItemDetailScreen(
                        item: entry.lost!, heroTag: heroTag),
              ),
            );
            _reload();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Green = found item, red = lost item
                Container(
                  width: 4,
                  height: 60,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: entry.found != null
                        ? const Color(0xFF2E9E5B)
                        : const Color(0xFFD64545),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: entry.photoUrl != null
                        ? Hero(
                            tag: heroTag,
                            child: Container(
                              color: const Color(0xFFEEF2F7),
                              child: Image.network(
                                entry.photoUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _thumbPlaceholder(),
                              ),
                            ),
                          )
                        : _thumbPlaceholder(),
                  ),
                ),
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
                          fontSize: 13,
                          color: Color(0xFF6B7785),
                        ),
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
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: _cardBlue,
      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF6B7785)),
    );
  }
}

// Report Lost / Report Found card: soft gradient, accent glow, a faint
// watermark icon, and a little squash when pressed.
class _ReportCard extends StatefulWidget {
  final IconData icon;
  final IconData watermark;
  final Color accent;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.watermark,
    required this.accent,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: Container(
        height: 152,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFD9E4F4)],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            const BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Stack(
                children: [
                  Positioned(
                    right: -16,
                    bottom: -18,
                    child: Icon(
                      widget.watermark,
                      size: 104,
                      color: accent.withValues(alpha: 0.10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.14),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(widget.icon, color: accent, size: 22),
                        ),
                        const Spacer(),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF14202E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xFF5B6877),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}