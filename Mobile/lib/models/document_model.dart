class DocumentFolderModel {
  final int id;
  final int? parentId;
  final String name;
  final String category;
  final String? department;
  final String? company;
  final String color;
  final String icon;
  final String? createdByName;
  final DateTime createdAt;
  final int filesCount;

  DocumentFolderModel({
    required this.id,
    this.parentId,
    required this.name,
    this.category = 'Drive',
    this.department,
    this.company,
    this.color = '#3B82F6',
    this.icon = 'folder',
    this.createdByName,
    required this.createdAt,
    this.filesCount = 0,
  });

  factory DocumentFolderModel.fromJson(Map<String, dynamic> json) {
    return DocumentFolderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      parentId: json['parentId'] is int ? json['parentId'] : (json['parent_id'] is int ? json['parent_id'] : null),
      name: json['name']?.toString() ?? 'Folder Tanpa Nama',
      category: json['category']?.toString() ?? 'Drive',
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      color: json['color']?.toString() ?? '#3B82F6',
      icon: json['icon']?.toString() ?? 'folder',
      createdByName: json['createdByName']?.toString() ?? json['created_by_name']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      filesCount: json['filesCount'] is int
          ? json['filesCount']
          : (json['files_count'] is int ? json['files_count'] : int.tryParse(json['filesCount']?.toString() ?? '0') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'name': name,
      'category': category,
      'department': department,
      'company': company,
      'color': color,
      'icon': icon,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'filesCount': filesCount,
    };
  }
}

class DocumentItemModel {
  final int id;
  final int? folderId;
  final String? docNumber;
  final String title;
  final String? description;
  final String category; // Drive, Pengajuan, SOP, Perizinan, Kebijakan
  final String fileType; // pdf, docx, xlsx, image
  final String? fileUrl;
  final String? fileName;
  final int fileSize;
  final String version;
  final String? department;
  final String? company;
  final String? uploaderNik;
  final String? uploaderName;
  final String approvalStatus; // Draft, Submitted, UnderReview, Approved, Rejected
  final String? approverNik;
  final String? approverName;
  final String? approvalNotes;
  final DateTime? approvedAt;
  final bool isConfidential;
  final int downloadsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocumentItemModel({
    required this.id,
    this.folderId,
    this.docNumber,
    required this.title,
    this.description,
    this.category = 'Drive',
    this.fileType = 'pdf',
    this.fileUrl,
    this.fileName,
    this.fileSize = 0,
    this.version = 'v1.0',
    this.department,
    this.company,
    this.uploaderNik,
    this.uploaderName,
    this.approvalStatus = 'Approved',
    this.approverNik,
    this.approverName,
    this.approvalNotes,
    this.approvedAt,
    this.isConfidential = false,
    this.downloadsCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DocumentItemModel.fromJson(Map<String, dynamic> json) {
    return DocumentItemModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      folderId: json['folderId'] is int ? json['folderId'] : (json['folder_id'] is int ? json['folder_id'] : null),
      docNumber: json['docNumber']?.toString() ?? json['doc_number']?.toString(),
      title: json['title']?.toString() ?? 'Dokumen Tanpa Judul',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'Drive',
      fileType: (json['fileType']?.toString() ?? json['file_type']?.toString() ?? 'pdf').toLowerCase(),
      fileUrl: json['fileUrl']?.toString() ?? json['file_url']?.toString(),
      fileName: json['fileName']?.toString() ?? json['file_name']?.toString(),
      fileSize: json['fileSize'] is int
          ? json['fileSize']
          : (json['file_size'] is int ? json['file_size'] : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0),
      version: json['version']?.toString() ?? 'v1.0',
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      uploaderNik: json['uploaderNik']?.toString() ?? json['uploader_nik']?.toString(),
      uploaderName: json['uploaderName']?.toString() ?? json['uploader_name']?.toString(),
      approvalStatus: json['approvalStatus']?.toString() ?? json['approval_status']?.toString() ?? 'Approved',
      approverNik: json['approverNik']?.toString() ?? json['approver_nik']?.toString(),
      approverName: json['approverName']?.toString() ?? json['approver_name']?.toString(),
      approvalNotes: json['approvalNotes']?.toString() ?? json['approval_notes']?.toString(),
      approvedAt: json['approvedAt'] != null
          ? DateTime.tryParse(json['approvedAt'].toString())
          : (json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null),
      isConfidential: json['isConfidential'] == true || json['is_confidential'] == true || json['is_confidential'] == 1,
      downloadsCount: json['downloadsCount'] is int
          ? json['downloadsCount']
          : (json['downloads_count'] is int ? json['downloads_count'] : 0),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : (json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folderId': folderId,
      'docNumber': docNumber,
      'title': title,
      'description': description,
      'category': category,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'version': version,
      'department': department,
      'company': company,
      'uploaderNik': uploaderNik,
      'uploaderName': uploaderName,
      'approvalStatus': approvalStatus,
      'approverNik': approverNik,
      'approverName': approverName,
      'approvalNotes': approvalNotes,
      'approvedAt': approvedAt?.toIso8601String(),
      'isConfidential': isConfidential,
      'downloadsCount': downloadsCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get formattedSize {
    if (fileSize <= 0) return '1.2 MB';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
