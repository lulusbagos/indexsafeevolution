import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static DatabaseService? _instance;
  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  DatabaseService._internal();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    var dbPath = await getDatabasesPath();
    var path = join(dbPath, 'isafe18.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  /// Hapus total database SQLite lokal (isafe18.db) untuk persiapan sinkronisasi ulang
  Future<void> clearDatabase() async {
    try {
      if (_database != null && _database!.isOpen) {
        await _database!.close();
      }
      _database = null;
      var dbPath = await getDatabasesPath();
      var path = join(dbPath, 'isafe18.db');
      await deleteDatabase(path);
      debugPrint('[DatabaseService] Database lokal SQLite isafe18.db berhasil dihapus.');
    } catch (e) {
      debugPrint('[DatabaseService] Error menghapus database lokal: $e');
    }
  }

  _onCreate(Database db, int intVersion) async {
    /* master */
    await db.execute('''
		CREATE TABLE enum_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE enum_bridges (
			`id` INTEGER PRIMARY KEY,
			`flag` TEXT,
			`primary_id` INTEGER,
			`secondary_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE inspection_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`categories` TEXT,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE hazard_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE coaching_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE k3_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE observation_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p2h_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p5m_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE safety_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`ref_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE vehicle_masters (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`name` TEXT,
			`type` TEXT,
			`ellipse_code` TEXT,
			`unit` TEXT,
			`brand` TEXT,
			`company` TEXT,
			`chassis_no` TEXT,
			`engine_no` TEXT,
			`cn_type` TEXT,
			`license_plate` TEXT,
			`year` INTEGER,
			`remark` TEXT,
			`employee_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE employees (
			`id` INTEGER PRIMARY KEY,
			`no_nik` TEXT,
			`nama_lengkap` TEXT,
			`nama_alias` TEXT,
			`tmp_lahir` TEXT,
			`tgl_lahir` TEXT,
			`email_pribadi` TEXT,
			`email_kantor` TEXT,
			`hp` TEXT,
			`depart` TEXT,
			`section` TEXT,
			`posisi` TEXT,
			`foto` TEXT,
			`user_id` INTEGER,
			`company_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    /* transaction */
    await db.execute('''
		CREATE TABLE inspection_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`inspection_id` INTEGER,
			`shift_id` INTEGER,
			`danger_level` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`category` TEXT,
			`inspektor1_id` INTEGER,
			`inspektor2_id` INTEGER,
			`inspektor3_id` INTEGER,
			`inspektor4_id` INTEGER,
			`inspektor5_id` INTEGER,
			`pja_id` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE hazard_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`hazard_id` INTEGER,
			`hazard_type_id` INTEGER,
			`hazard_subtype_id` INTEGER,
			`hazard_danger_id` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`repair` INTEGER,
			`repair_remark` TEXT,
			`repair_image` TEXT,
			`repair_video` TEXT,
			`repair_date` TEXT,
			`repair_time` TEXT,
			`pja_id` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE coaching_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`trainer_id` INTEGER,
			`tema_id` INTEGER,
			`purpose` TEXT,
			`feedback` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE k3_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`inductor_id` INTEGER,
			`nik` TEXT,
			`birth_place` TEXT,
			`birth_date` TEXT,
			`hire_date` TEXT,
			`depart` TEXT,
			`section` TEXT,
			`jabatan` TEXT,
			`level` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`inductor_sign` TEXT,
			`employee_sign` TEXT,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE observation_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`dept_id` INTEGER,
			`doc_id` INTEGER,
			`risk_id` INTEGER,
			`subject` TEXT,
			`activity` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p2h_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`vehicle_id` INTEGER,
			`hm` REAL,
			`km` REAL,
			`no_lambung` TEXT,
			`merek` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`simper` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p5m_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`topic_id` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE safety_trans (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`topic_id` INTEGER,
			`self_image` TEXT,
			`event_image` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    /* detail */
    await db.execute('''
		CREATE TABLE inspection_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`repair` INTEGER,
			`repair_remark` TEXT,
			`repair_image` TEXT,
			`repair_video` TEXT,
			`location_id` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE coaching_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE k3_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE observation_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`point` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p2h_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE p5m_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE safety_details (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`flag` TEXT,
			`level` INTEGER,
			`yesno` INTEGER,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`tran_id` INTEGER,
			`point_id` INTEGER,
			`ref_id` INTEGER,
			`sync_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    /* action */
    await db.execute('''
		CREATE TABLE action_plans (
			`id` INTEGER PRIMARY KEY,
			`code` TEXT,
			`title` TEXT,
			`area_id` INTEGER,
			`location_id` INTEGER,
			`location_detail` TEXT,
			`date` TEXT,
			`time` TEXT,
			`remark` TEXT,
			`image` TEXT,
			`video` TEXT,
			`status` INTEGER,
			`pja_id` INTEGER,
			`pic_id` INTEGER,
			`plan` TEXT,
			`plan_date` TEXT,
			`overdue` INTEGER,
			`reason` TEXT,
			`action` TEXT,
			`action_date` TEXT,
			`action_image` TEXT,
			`action_video` TEXT,
			`table` TEXT,
			`category` TEXT,
			`tran_id` INTEGER,
			`detail_id` INTEGER,
			`company_id` INTEGER,
			`employee_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');

    await db.execute('''
		CREATE TABLE files (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`name` TEXT,
			`type` TEXT,
			`table` TEXT,
			`category` TEXT,
			`point_id` INTEGER,
			`sync_id` INTEGER,
			`tran_id` INTEGER,
			`detail_id` INTEGER,
			`created_at` TEXT,
			`updated_at` TEXT,
			`deleted_at` TEXT
		);
		''');
  }

  Future close() async {
    _database = null;

    final db = await database;
    return db.close();
  }

  Future<List<Map>> rawQuery(String sql) async {
    final db = await database;
    return db.rawQuery(sql);
  }

  Future<List<dynamic>> gets(table, where, order) async {
    final db = await database;
    try {
      if (table == null || where == null || order == null) return [];
      return await db
          .rawQuery("SELECT * FROM $table WHERE $where ORDER BY $order");
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  Future<dynamic> get(table, int id) async {
    final db = await database;
    try {
      if (table == null) return null;
      final result = await db.query(table, where: 'id=?', whereArgs: [id]);
      if (result.isNotEmpty) {
        return result.first;
      }
      return null;
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  Future<int> insert(table, Map<String, dynamic> vals) async {
    final db = await database;
    try {
      return await db.insert(table, vals,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  Future<int> update(table, Map<String, dynamic> vals, int id) async {
    final db = await database;
    try {
      return await db.update(table, vals, where: 'id=?', whereArgs: [id]);
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  Future<int> delete(table, int id) async {
    final db = await database;
    try {
      return await db.delete(table, where: 'id=?', whereArgs: [id]);
    } catch (e) {
      debugPrint(e.toString());
      return 0;
    }
  }

  Future<void> execute(String sql) async {
    final db = await database;
    try {
      return await db.execute(sql);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> saveFiles(String type, int point, int tran, int detail) async {
    final db = await database;
    try {
      return await db
          .execute('''update files set tran_id=$tran, detail_id=$detail
          where type='$type' and point_id=$point and tran_id is null and detail_id is null''');
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> dropFiles(String type) async {
    final db = await database;
    try {
      return await db.execute('''delete from files
          where type='$type' and point_id is not null and tran_id is null and detail_id is null''');
    } catch (e) {
      debugPrint(e.toString());
    }
  }
}
