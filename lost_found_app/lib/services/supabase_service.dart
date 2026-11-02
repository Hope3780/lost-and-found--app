import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/found_item.dart';
import '../models/lost_item.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ---------- AUTH ----------

  Future<AuthResponse> signUp(
    String email,
    String password, {
    String? fullName,
    String? phone,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      // Stored on the user account (user metadata)
      data: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
      },
    );
  }

  Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  // Supabase returns at most 1000 rows per request, so keep asking for the
  // next page until every row has been fetched.
  Future<List<Map<String, dynamic>>> _fetchAll(
    String table, {
    String? searchTerm,
  }) async {
    const pageSize = 1000;
    final rows = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      var query = _client.from(table).select();
      if (searchTerm != null && searchTerm.isNotEmpty) {
        query = query.ilike('item_name', '%$searchTerm%');
      }

      final data = await query
          .order('created_at', ascending: false)
          .order('id')
          .range(from, from + pageSize - 1);

      final batch = (data as List).cast<Map<String, dynamic>>();
      rows.addAll(batch);
      if (batch.length < pageSize) break;
      from += pageSize;
    }
    return rows;
  }

  // ---------- FOUND ITEMS ----------

  Future<List<FoundItem>> fetchAvailableItems({String? searchTerm}) async {
    final rows = await _fetchAll('found_items', searchTerm: searchTerm);
    return rows.map((row) => FoundItem.fromMap(row)).toList();
  }

  // Items this student reported as found.
  Future<List<FoundItem>> fetchMyFoundReports() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('found_items')
        .select()
        .eq('logged_by', userId)
        .order('created_at', ascending: false);

    return (data as List).map((row) => FoundItem.fromMap(row)).toList();
  }

  Future<List<FoundItem>> fetchMyClaims() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('found_items')
        .select()
        .eq('claimed_by', userId)
        .order('created_at', ascending: false);

    return (data as List).map((row) => FoundItem.fromMap(row)).toList();
  }

  Future<void> claimItem(String itemId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _client.from('found_items').update({
      'status': 'claim_pending',
      'claimed_by': userId,
    }).eq('id', itemId);
  }

  // ---------- PHOTOS ----------

  // Works out the real image type from the file's first bytes. The name or
  // path the picker reports can't be trusted (on web it is a blob: address
  // with no extension), so the bytes decide.
  ({String ext, String mime}) _detectImageType(
      Uint8List b, String fallbackExt) {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return (ext: 'jpg', mime: 'image/jpeg');
    }
    if (b.length > 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return (ext: 'png', mime: 'image/png');
    }
    if (b.length > 3 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
      return (ext: 'gif', mime: 'image/gif');
    }
    if (b.length > 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return (ext: 'webp', mime: 'image/webp');
    }

    // Unknown format: use the passed-in extension only if it looks sane
    final clean = fallbackExt.toLowerCase();
    if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(clean)) {
      return (ext: clean, mime: 'image/$clean');
    }
    return (ext: 'jpg', mime: 'image/jpeg');
  }

  // Uploads photo bytes to the 'item-photos' bucket and returns its public URL.
  // Works on web, Android, and iOS since it never touches the filesystem.
  Future<String> uploadItemPhoto(Uint8List imageBytes, String fileExt) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final type = _detectImageType(imageBytes, fileExt);
    final fileName =
        '${userId}_${DateTime.now().millisecondsSinceEpoch}.${type.ext}';

    await _client.storage.from('item-photos').uploadBinary(
          fileName,
          imageBytes,
          fileOptions: FileOptions(contentType: type.mime),
        );

    return _client.storage.from('item-photos').getPublicUrl(fileName);
  }

  // Student reports an item they found.
  Future<void> reportFoundItem({
    required String itemName,
    required String description,
    required String locationFound,
    String? photoUrl,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _client.from('found_items').insert({
      'item_name': itemName,
      'description': description,
      'location_found': locationFound,
      'date_found': DateTime.now().toIso8601String().split('T').first,
      'status': 'logged',
      'logged_by': userId,
      'photo_url': photoUrl,
    });
  }

  // ---------- LOST ITEMS ----------

    // Student reports an item they lost (saved to the 'lost_items' table).
  Future<void> reportLostItem({
    required String itemName,
    required String category,
    required String description,
    required String locationLost,
    String? photoUrl,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await _client.from('lost_items').insert({
      'item_name': itemName,
      'category': category,
      'description': description.isEmpty ? null : description,
      'location_lost': locationLost,
      'photo_url': photoUrl,
      'status': 'logged',
      'reported_by': userId,
    });
  }

  // The signed-in student's own lost reports.
  Future<List<LostItem>> fetchMyLostReports({String? searchTerm}) async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    var query = _client.from('lost_items').select().eq('reported_by', userId);

    if (searchTerm != null && searchTerm.isNotEmpty) {
      query = query.ilike('item_name', '%$searchTerm%');
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((row) => LostItem.fromMap(row)).toList();
  }

  // Every student's lost reports (the Recent Reports list on the home screen).
  Future<List<LostItem>> fetchAllLostReports({String? searchTerm}) async {
    final rows = await _fetchAll('lost_items', searchTerm: searchTerm);
    return rows.map((row) => LostItem.fromMap(row)).toList();
  }

  // The owner of a lost report claims it once Protection Services marks it "item_found".
  Future<void> claimLostItem(String itemId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final updated = await _client
        .from('lost_items')
        .update({'status': 'claim_pending'})
        .eq('id', itemId)
        .eq('reported_by', userId)
        .eq('status', 'item_found')
        .select();

    // Nothing updated = not the owner, or the status changed in the meantime
    if (updated.isEmpty) {
      throw Exception('This item can no longer be claimed.');
    }
  }
}