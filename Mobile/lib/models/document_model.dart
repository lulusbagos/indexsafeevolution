class DocumentFolderModel {
  final int id;
  final int? parentId;
  final String name;
  final String path;
  final String color;
  final bool isBold;
  final int subfolderCount;
  final int fileCount;
  final String? createdAt;
  final String? createdBy;

  DocumentFolderModel({
    required this.id,
    this.parentId,
    required this.name,
    this.path = '',
    this.color = '#0284C7',
    this.isBold = false,
    this.subfolderCount = 0,
    this.fileCount = 0,
    this.createdAt,
    this.createdBy,
  });

  factory DocumentFolderModel.fromJson(Map<String, dynamic> json) {
    return DocumentFolderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      parentId: json['parentId'] is int ? json['parentId'] : (json['parent_id'] is int ? json['parent_id'] : null),
      name: json['name']?.toString() ?? 'Folder',
      path: json['path']?.toString() ?? json['path_key']?.toString() ?? '',
      color: json['color']?.toString() ?? '#0284C7',
      isBold: json['isBold'] == true || json['is_bold'] == true || json['is_bold'] == 1,
      subfolderCount: json['subfolderCount'] is int
          ? json['subfolderCount']
          : (json['subfolder_count'] is int ? json['subfolder_count'] : 0),
      fileCount: json['fileCount'] is int
          ? json['fileCount']
          : (json['file_count'] is int
              ? json['file_count']
              : (json['filesCount'] is int ? json['filesCount'] : 0)),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'name': name,
      'path': path,
      'color': color,
      'isBold': isBold,
      'subfolderCount': subfolderCount,
      'fileCount': fileCount,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}

class DocumentItemModel {
  final int id;
  final int? folderId;
  final String? folderName;
  final String? folderPath;
  final String title;
  final String fileName;
  final String filePath;
  final String fileUrl;
  final String fileType; // pdf, docx, xlsx, etc.
  final int fileSize;
  final String formattedSize;
  final bool isReadOnly;
  final bool isBold;
  final String? expiredAt;
  final String? createdAt;
  final String? createdBy;
  String? localPath;
  bool isDownloaded;

  DocumentItemModel({
    required this.id,
    this.folderId,
    this.folderName,
    this.folderPath,
    required this.title,
    this.fileName = '',
    this.filePath = '',
    this.fileUrl = '',
    this.fileType = 'pdf',
    this.fileSize = 0,
    this.formattedSize = '0 KB',
    this.isReadOnly = false,
    this.isBold = false,
    this.expiredAt,
    this.createdAt,
    this.createdBy,
    this.localPath,
    this.isDownloaded = false,
  });

  factory DocumentItemModel.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? json['nama_dokumen']?.toString() ?? 'Dokumen';
    final filePath = json['filePath']?.toString() ?? json['file_path']?.toString() ?? '';
    final rawType = (json['fileType']?.toString() ?? json['file_type']?.toString() ?? '').toLowerCase();
    String ext = rawType;
    if (ext.isEmpty) {
      if (title.contains('.')) {
        ext = title.split('.').last.toLowerCase();
      } else if (filePath.contains('.')) {
        ext = filePath.split('.').last.toLowerCase();
      } else {
        ext = 'pdf';
      }
    }

    final rawSize = json['fileSize'] is int
        ? json['fileSize']
        : (json['size_bytes'] is int ? json['size_bytes'] : int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0);

    String fmtSize = json['formattedSize']?.toString() ?? '';
    if (fmtSize.isEmpty) {
      if (rawSize <= 0) {
        fmtSize = '0 KB';
      } else if (rawSize < 1024 * 1024) {
        fmtSize = '${(rawSize / 1024).toStringAsFixed(1)} KB';
      } else {
        fmtSize = '${(rawSize / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    return DocumentItemModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      folderId: json['folderId'] is int ? json['folderId'] : (json['folder_id'] is int ? json['folder_id'] : null),
      folderName: json['folderName']?.toString() ?? json['nama_folder']?.toString(),
      folderPath: json['folderPath']?.toString() ?? json['path_key']?.toString(),
      title: title,
      fileName: json['fileName']?.toString() ?? json['nama_file_stored']?.toString() ?? title,
      filePath: filePath,
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileType: ext,
      fileSize: rawSize,
      formattedSize: fmtSize,
      isReadOnly: json['isReadOnly'] == true || json['is_read_only'] == true,
      isBold: json['isBold'] == true || json['is_bold'] == true,
      expiredAt: json['expiredAt']?.toString() ?? json['expired_at']?.toString(),
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      createdBy: json['createdBy']?.toString() ?? json['created_by']?.toString(),
      localPath: json['localPath']?.toString(),
      isDownloaded: json['isDownloaded'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folderId': folderId,
      'folderName': folderName,
      'folderPath': folderPath,
      'title': title,
      'fileName': fileName,
      'filePath': filePath,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'formattedSize': formattedSize,
      'isReadOnly': isReadOnly,
      'isBold': isBold,
      'expiredAt': expiredAt,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'localPath': localPath,
      'isDownloaded': isDownloaded,
    };
  }
}
