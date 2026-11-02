class LostItem {
  final String id;
  final String itemName;
  final String category;
  final String description;
  final String? photoUrl;
  final String? locationLost;
  final String status; // logged, pending, under_review, item_found, claim_pending, available_for_collection, returned, rejected
  final String? staffNote;
  final String? reportedBy;
  final String? updatedByEmail;
  final DateTime createdAt;

  LostItem({
    required this.id,
    required this.itemName,
    required this.category,
    required this.description,
    this.photoUrl,
    this.locationLost,
    required this.status,
    this.staffNote,
    this.reportedBy,
    this.updatedByEmail,
    required this.createdAt,
  });

  // Second line in the lists: "Library • Lost" (falls back to the category
  // for older reports that have no location)
  String get listSubtitle {
    final loc = locationLost?.trim() ?? '';
    return loc.isNotEmpty ? '$loc • Lost' : '$category • Lost';
  }

  factory LostItem.fromMap(Map<String, dynamic> map) {
    return LostItem(
      id: map['id'] as String,
      itemName: map['item_name'] as String,
      category: map['category'] as String? ?? 'Other',
      description: map['description'] as String? ?? '',
      photoUrl: map['photo_url'] as String?,
      locationLost: map['location_lost'] as String?,
      status: map['status'] as String? ?? 'logged',
      staffNote: map['staff_note'] as String?,
      reportedBy: map['reported_by'] as String?,
      updatedByEmail: map['updated_by_email'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }
}