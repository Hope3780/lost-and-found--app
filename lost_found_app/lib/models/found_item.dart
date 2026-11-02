class FoundItem {
  final String id;
  final String itemName;
  final String description;
  final String? photoUrl;
  final String locationFound;
  final DateTime dateFound;
  final String status; // logged, pending, under_review, verified, available_for_collection, rejected, claim_pending, returned
  final String? claimedBy;
  final String? loggedBy;
  final String? staffNote;
  final DateTime? createdAt;

  FoundItem({
    required this.id,
    required this.itemName,
    required this.description,
    this.photoUrl,
    required this.locationFound,
    required this.dateFound,
    required this.status,
    this.claimedBy,
    this.loggedBy,
    this.staffNote,
    this.createdAt,
  });

  factory FoundItem.fromMap(Map<String, dynamic> map) {
    return FoundItem(
      id: map['id'] as String,
      itemName: map['item_name'] as String,
      description: map['description'] as String? ?? '',
      photoUrl: map['photo_url'] as String?,
      locationFound: map['location_found'] as String? ?? '',
      dateFound: DateTime.parse(map['date_found'] as String),
      status: map['status'] as String,
      claimedBy: map['claimed_by'] as String?,
      loggedBy: map['logged_by'] as String?,
      staffNote: map['staff_note'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}