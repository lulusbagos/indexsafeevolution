using Microsoft.EntityFrameworkCore;

using Indexsafe.Api.Models;



namespace Indexsafe.Api.Data

{

    public class AppDbContext : DbContext

    {

        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)

        {

        }



        public DbSet<PasswordOverride> PasswordOverrides { get; set; } = null!;

        public DbSet<BbsObservation> BbsObservations { get; set; } = null!;
    public DbSet<HazardReport> HazardReports { get; set; } = null!;

        public DbSet<Inspection> Inspections { get; set; } = null!;

        public DbSet<ActionPlan> ActionPlans { get; set; } = null!;

        public DbSet<SafetyTalk> SafetyTalks { get; set; } = null!;

        public DbSet<P5m> P5ms { get; set; } = null!;

        public DbSet<TimelineLike> TimelineLikes { get; set; } = null!;

        public DbSet<TimelineComment> TimelineComments { get; set; } = null!;

        public DbSet<Notification> Notifications { get; set; } = null!;

        public DbSet<RunningText> RunningTexts { get; set; } = null!;

        public DbSet<WebCampaign> WebCampaigns { get; set; } = null!;

        public DbSet<AppUser> AppUsers { get; set; } = null!;

        public DbSet<MasterArea> MasterAreas { get; set; } = null!;

        public DbSet<MasterBenchmark> Benchmarks { get; set; } = null!;

        public DbSet<Quiz> Quizzes { get; set; } = null!;

        public DbSet<QuizAnswer> QuizAnswers { get; set; } = null!;

        public DbSet<Observation> Observations { get; set; } = null!;

        public DbSet<P2hVehicle> P2hVehicles { get; set; } = null!;

        public DbSet<P2hReport> P2hReports { get; set; } = null!;

        public DbSet<DpaReport> DpaReports { get; set; } = null!;

        public DbSet<DpaDriver> DpaDrivers { get; set; } = null!;

        public DbSet<FciReport> FciReports { get; set; } = null!;

        public DbSet<DciReport> DciReports { get; set; } = null!;

        public DbSet<RciReport> RciReports { get; set; } = null!;

        public DbSet<SpiReport> SpiReports { get; set; } = null!;

        public DbSet<GciReport> GciReports { get; set; } = null!;

        public DbSet<RciMember> RciMembers { get; set; } = null!;

        public DbSet<IncidentNews> IncidentNewsList { get; set; } = null!;

        public DbSet<AttendanceEvent> AttendanceEvents { get; set; } = null!;

        public DbSet<AttendanceRecord> AttendanceRecords { get; set; } = null!;

        public DbSet<UserScanPermission> UserScanPermissions { get; set; } = null!;

        public DbSet<PermitViolation> PermitViolations { get; set; } = null!;

        public DbSet<PermitViolationApprover> PermitViolationApprovers { get; set; } = null!;

        public DbSet<PermitGateLog> PermitGateLogs { get; set; } = null!;

        public DbSet<Coaching> Coachings { get; set; } = null!;

        public DbSet<CoachingParticipant> CoachingParticipants { get; set; } = null!;

        public DbSet<Roster> Rosters { get; set; } = null!;

        public DbSet<Reinduksi> Reinduksis { get; set; } = null!;

        public DbSet<MitraRosterView> MitraRosters { get; set; } = null!;

        public DbSet<MitraDepartmentDropdownView> MitraDepartmentDropdowns { get; set; } = null!;

        public DbSet<SapQualityAssessment> SapQualityAssessments { get; set; } = null!;



        // View entities

        public DbSet<KaryawanView> Karyawans { get; set; } = null!;

        public DbSet<PersonalView> Personals { get; set; } = null!;

        public DbSet<PenggunaView> Penggunas { get; set; } = null!;

        public DbSet<PerusahaanView> Perusahaans { get; set; } = null!;

        public DbSet<PerusahaanHierarchyRelationView> PerusahaanHierarchyRelations { get; set; } = null!;

        public DbSet<DepartemenView> Departemens { get; set; } = null!;

        public DbSet<JabatanView> Jabatans { get; set; } = null!;

        public DbSet<KaryawanJabatanMappingPreviewView> KaryawanJabatanMappings { get; set; } = null!;

        public DbSet<MitraKaryawanAktifView> MitraKaryawanAktifs { get; set; } = null!;



        protected override void OnModelCreating(ModelBuilder modelBuilder)

        {

            base.OnModelCreating(modelBuilder);



            // Table mappings

            modelBuilder.Entity<PasswordOverride>()

                .ToTable("tbl_m_pengguna_sandi")

                .HasKey(p => p.Nrp);



            

            // HazardReport column mappings

            modelBuilder.Entity<BbsObservation>(entity =>
            {
                entity.ToTable("tbl_t_bbs_observation", tb => tb.UseSqlOutputClause(false));
            });

            modelBuilder.Entity<HazardReport>(entity =>

            {

                entity.ToTable("tbl_t_hazard_report", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.FotoTemuan).HasColumnName("foto_temuan");

                entity.Property(e => e.FotoPerbaikan).HasColumnName("foto_perbaikan");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.Temuan).HasColumnName("temuan");

                entity.Property(e => e.KategoriBahaya).HasColumnName("kategori_bahaya");

                entity.Property(e => e.JenisBahaya).HasColumnName("jenis_bahaya");

                entity.Property(e => e.JenisKetidaksesuaian).HasColumnName("jenis_ketidaksesuaian");

                entity.Property(e => e.TingkatResiko).HasColumnName("tingkat_resiko");

                entity.Property(e => e.Perbaikan).HasColumnName("perbaikan");

                entity.Property(e => e.TindakanPerbaikan).HasColumnName("tindakan_perbaikan");

                entity.Property(e => e.Pja).HasColumnName("pja");

                entity.Property(e => e.NikPja).HasColumnName("nik_pja");

                entity.Property(e => e.DepartemenPja).HasColumnName("departemen_pja");

                entity.Property(e => e.StatusTemuan).HasColumnName("status_temuan");

                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            // Inspection column mappings

            modelBuilder.Entity<Inspection>(entity =>

            {

                entity.ToTable("tbl_t_inspection", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.JenisInspeksi).HasColumnName("jenis_inspeksi");

                entity.Property(e => e.Pja).HasColumnName("pja");

                entity.Property(e => e.NikPja).HasColumnName("nik_pja");

                entity.Property(e => e.DepartemenPja).HasColumnName("departemen_pja");

                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.Catatan).HasColumnName("catatan");

                entity.Property(e => e.LampiranJson).HasColumnName("lampiran_json");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

                entity.Property(e => e.Q1_1).HasColumnName("q1_1");

                entity.Property(e => e.Q1_2).HasColumnName("q1_2");

                entity.Property(e => e.Q1_3).HasColumnName("q1_3");

                entity.Property(e => e.Q2_1).HasColumnName("q2_1");

                entity.Property(e => e.Q2_2).HasColumnName("q2_2");

                entity.Property(e => e.Q2_3).HasColumnName("q2_3");

                entity.Property(e => e.Q3_1).HasColumnName("q3_1");

                entity.Property(e => e.Q3_2).HasColumnName("q3_2");

                entity.Property(e => e.Q3_3).HasColumnName("q3_3");

                entity.Property(e => e.Q4_1).HasColumnName("q4_1");

                entity.Property(e => e.Q4_2).HasColumnName("q4_2");

                entity.Property(e => e.Q4_3).HasColumnName("q4_3");

                entity.Property(e => e.Q5_1).HasColumnName("q5_1");

                entity.Property(e => e.Q5_2).HasColumnName("q5_2");

                entity.Property(e => e.Q5_3).HasColumnName("q5_3");

            });



            // ActionPlan column mappings

            modelBuilder.Entity<ActionPlan>(entity =>

            {

                entity.ToTable("tbl_t_action_plan", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.FotoTemuan).HasColumnName("foto_temuan");

                entity.Property(e => e.FotoPerbaikan).HasColumnName("foto_perbaikan");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.ItemSap).HasColumnName("item_sap");

                entity.Property(e => e.KategoriTemuan).HasColumnName("kategori_temuan");

                entity.Property(e => e.DetilTemuan).HasColumnName("detil_temuan");

                entity.Property(e => e.Status).HasColumnName("status");

                entity.Property(e => e.Pja).HasColumnName("pja");

                entity.Property(e => e.NikPja).HasColumnName("nik_pja");

                entity.Property(e => e.DepartemenPja).HasColumnName("departemen_pja");

                entity.Property(e => e.Pic).HasColumnName("pic");

                entity.Property(e => e.NikPic).HasColumnName("nik_pic");

                entity.Property(e => e.DepartemenPic).HasColumnName("departemen_pic");

                entity.Property(e => e.RencanaPerbaikan).HasColumnName("rencana_perbaikan");

                entity.Property(e => e.TanggalRencanaPerbaikan).HasColumnName("tanggal_rencana_perbaikan");

                entity.Property(e => e.Perbaikan).HasColumnName("perbaikan");

                entity.Property(e => e.TanggalPerbaikan).HasColumnName("tanggal_perbaikan");

                entity.Property(e => e.Overdue).HasColumnName("overdue");

                entity.Property(e => e.AlasanOverdue).HasColumnName("alasan_overdue");

                entity.Property(e => e.ReassignedFrom).HasColumnName("reassigned_from");

                entity.Property(e => e.ReassignedTo).HasColumnName("reassigned_to");

                entity.Property(e => e.ReassignNote).HasColumnName("reassign_note");

                
                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            // SafetyTalk column mappings

            modelBuilder.Entity<SafetyTalk>(entity =>

            {

                entity.ToTable("tbl_t_safety_talk", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.FotoDiri).HasColumnName("foto_diri");

                entity.Property(e => e.FotoKegiatan).HasColumnName("foto_kegiatan");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.Judul).HasColumnName("judul");

                entity.Property(e => e.Keterangan).HasColumnName("keterangan");

                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            // P5m column mappings

            modelBuilder.Entity<P5m>(entity =>

            {

                entity.ToTable("tbl_t_p5m", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.FotoKegiatan).HasColumnName("foto_kegiatan");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.Topik).HasColumnName("topik");

                entity.Property(e => e.Judul).HasColumnName("judul");

                entity.Property(e => e.Keterangan).HasColumnName("keterangan");

                entity.Property(e => e.ListPertanyaan).HasColumnName("list_pertanyaan");

                entity.Property(e => e.Jawaban).HasColumnName("jawaban");

                entity.Property(e => e.Catatan).HasColumnName("catatan");

                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            // Observation column mappings

            modelBuilder.Entity<Observation>(entity =>

            {

                entity.ToTable("tbl_t_observation", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.Date).HasColumnName("date");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.KegiatanYangDiamati).HasColumnName("kegiatan_yang_diamati");

                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.PerusahaanYangDiamati).HasColumnName("perusahaan_yang_diamati");

                entity.Property(e => e.DepartemenYangDiamati).HasColumnName("departemen_yang_diamati");

                entity.Property(e => e.DokumenPendukung).HasColumnName("dokumen_pendukung");

                entity.Property(e => e.ResikoKritis).HasColumnName("resiko_kritis");

                entity.Property(e => e.TingkatResiko).HasColumnName("tingkat_resiko");

                entity.Property(e => e.PerihalYangDiamati).HasColumnName("perihal_yang_diamati");

                entity.Property(e => e.HasilObservasi).HasColumnName("hasil_observasi");

                entity.Property(e => e.Keterangan).HasColumnName("keterangan");

                entity.Property(e => e.FotoUrl).HasColumnName("foto_url");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            // Coaching column mappings

            modelBuilder.Entity<Coaching>(entity =>

            {

                entity.ToTable("tbl_t_coaching", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.Foto).HasColumnName("foto");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Area).HasColumnName("area");

                entity.Property(e => e.Lokasi).HasColumnName("lokasi");

                entity.Property(e => e.DetilLokasi).HasColumnName("detil_lokasi");

                entity.Property(e => e.Tema).HasColumnName("tema");

                entity.Property(e => e.Feedback).HasColumnName("feedback");

                entity.Property(e => e.Komitmen).HasColumnName("komitmen");

                entity.Property(e => e.PerusahaanId).HasColumnName("perusahaan_id");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            // CoachingParticipant column mappings

            modelBuilder.Entity<CoachingParticipant>(entity =>

            {

                entity.ToTable("tbl_t_coaching_participant", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.CoachingId).HasColumnName("coaching_id");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Nama).HasColumnName("nama");

            });



            // P2hReport column mappings

            modelBuilder.Entity<P2hReport>(entity =>

            {

                entity.ToTable("tbl_t_p2h_report", tb => tb.UseSqlOutputClause(false));

                entity.Property(e => e.Id).HasColumnName("id");

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Tanggal).HasColumnName("tanggal");

                entity.Property(e => e.Waktu).HasColumnName("waktu");

                entity.Property(e => e.JenisKendaraan).HasColumnName("jenis_kendaraan");

                entity.Property(e => e.NoLambung).HasColumnName("no_lambung");

                entity.Property(e => e.Kilometer).HasColumnName("kilometer");

                entity.Property(e => e.Merek).HasColumnName("merek");

                entity.Property(e => e.SimperKimper).HasColumnName("simper_kimper");

                entity.Property(e => e.FotoSpeedometer).HasColumnName("foto_speedometer");

                entity.Property(e => e.GolA_Json).HasColumnName("gol_a_json");

                entity.Property(e => e.GolB_Json).HasColumnName("gol_b_json");

                entity.Property(e => e.GolC_Json).HasColumnName("gol_c_json");

                entity.Property(e => e.IsDeleted).HasColumnName("is_deleted");

                entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            });



            modelBuilder.Entity<Quiz>()

                .ToTable("table_m_quis");



            modelBuilder.Entity<QuizAnswer>()

                .ToTable("table_m_quis_detail");



            modelBuilder.Entity<P2hVehicle>()

                .ToTable("tbl_m_p2h_vehicle");



            modelBuilder.Entity<DpaReport>()

                .ToTable("tbl_t_dpa_report", tb => tb.UseSqlOutputClause(false));



            modelBuilder.Entity<FciReport>()

                .ToTable("tbl_t_fci_report", tb => tb.UseSqlOutputClause(false));



            modelBuilder.Entity<DciReport>()

                .ToTable("tbl_t_dci_report", tb => tb.UseSqlOutputClause(false));



            modelBuilder.Entity<RciReport>()

                .ToTable("tbl_t_rci_report", tb => tb.UseSqlOutputClause(false))

                .HasMany(r => r.Members)

                .WithOne(m => m.RciReport)

                .HasForeignKey(m => m.RciReportId)

                .OnDelete(DeleteBehavior.Cascade);



            modelBuilder.Entity<RciMember>()

                .ToTable("tbl_t_rci_member", tb => tb.UseSqlOutputClause(false));



            modelBuilder.Entity<DpaDriver>()

                .ToTable("tbl_m_dpa_driver");



            modelBuilder.Entity<DpaDriver>()

                .HasIndex(d => d.DriverNamaNormalized)

                .IsUnique();



            modelBuilder.Entity<TimelineLike>()

                .ToTable("tbl_t_likes");



            modelBuilder.Entity<TimelineComment>()

                .ToTable("tbl_t_comments");



            modelBuilder.Entity<RunningText>()

                .ToTable("tbl_m_running_text");



            modelBuilder.Entity<AppUser>(entity =>

            {

                entity.ToTable("tbl_t_app_user");

                entity.HasKey(e => e.Nik);

                entity.Property(e => e.Nik).HasColumnName("nik");

                entity.Property(e => e.Nama).HasColumnName("nama");

                entity.Property(e => e.Departemen).HasColumnName("departemen");

                entity.Property(e => e.Perusahaan).HasColumnName("perusahaan");

                entity.Property(e => e.IdPerusahaan).HasColumnName("id_perusahaan");

                entity.Property(e => e.KaryawanId).HasColumnName("karyawan_id");

                entity.Property(e => e.LastLogin).HasColumnName("last_login");

                entity.Property(e => e.Role).HasColumnName("role");

            });



            modelBuilder.Entity<MasterArea>()

                .ToTable("tbl_m_area_utama");



            modelBuilder.Entity<IncidentNews>(entity =>

            {

                entity.ToTable("tbl_t_incident_news");

                entity.Property(e => e.IsBanner).HasColumnName("is_banner");

                entity.Property(e => e.IsUpdate).HasColumnName("is_update");

                entity.Property(e => e.BannerUrutan).HasColumnName("banner_urutan");

                entity.Property(e => e.Tags).HasColumnName("tags");

            });



            modelBuilder.Entity<AttendanceEvent>()

                .ToTable("tbl_t_attendance_event");



            modelBuilder.Entity<AttendanceRecord>()

                .ToTable("tbl_t_attendance_record");



            modelBuilder.Entity<AttendanceEvent>()

                .HasIndex(e => e.QrToken)

                .IsUnique();



            modelBuilder.Entity<AttendanceRecord>()

                .HasIndex(r => new { r.AttendanceEventId, r.Nik })

                .IsUnique();



            modelBuilder.Entity<AttendanceRecord>()

                .HasOne(r => r.AttendanceEvent)

                .WithMany(e => e.AttendanceRecords)

                .HasForeignKey(r => r.AttendanceEventId)

                .OnDelete(DeleteBehavior.Cascade);



// Coaching & CoachingParticipant mapped above with columns



            modelBuilder.Entity<Roster>()

                .ToTable("tbl_m_roster")

                .HasKey(r => r.Id);



            modelBuilder.Entity<SapQualityAssessment>()

                .ToTable("tbl_m_penilaian_kualitas_sap");



            modelBuilder.Entity<UserScanPermission>(entity =>

            {

                entity.ToTable("tbl_m_user_scan_permission");

                entity.Property(e => e.CanScanMinePermit).HasColumnName("can_scan_minepermit");

            });



            // View mappings

            modelBuilder.Entity<KaryawanView>()

                .ToView("vw_karyawan")

                .HasKey(k => k.IdKaryawan);



            modelBuilder.Entity<PersonalView>()

                .ToView("vw_personal")

                .HasKey(p => p.IdPersonal);



            modelBuilder.Entity<PenggunaView>()

                .ToView("vw_pengguna")

                .HasKey(p => p.PenggunaId);



            modelBuilder.Entity<PerusahaanView>()

                .ToView("vw_perusahaan")

                .HasKey(p => p.PerusahaanId);



            modelBuilder.Entity<PerusahaanHierarchyRelationView>()

                .ToView("vw_m_hirarki_perusahaan")

                .HasNoKey();



            modelBuilder.Entity<DepartemenView>()

                .ToView("vw_departemen")

                .HasKey(d => d.DepartemenId);



            modelBuilder.Entity<JabatanView>()

                .ToView("vw_jabatan")

                .HasKey(j => j.JabatanId);



            modelBuilder.Entity<KaryawanJabatanMappingPreviewView>()

                .ToView("vw_r_karyawan_jabatan_mapping_preview")

                .HasKey(k => k.KaryawanId);



            modelBuilder.Entity<KaryawanJabatanMappingPreviewView>()

                .Property(k => k.ConfidenceScore)

                .HasPrecision(18, 2);



            modelBuilder.Entity<MitraRosterView>()

                .ToSqlQuery("SELECT karyawan_id, no_nik, hari_onsite, hari_offsite FROM ONE_DB_MITRA.dbo.vw_m_roster")

                .HasKey(r => r.KaryawanId);



            modelBuilder.Entity<MitraDepartmentDropdownView>()

                .ToSqlQuery("SELECT id_perusahaan, kode_perusahaan, nama_perusahaan, id_departemen, kode_departemen, nama_departemen, label_dropdown, perusahaan_status_aktif, departemen_status_aktif, perusahaan_deleted_at, group_label, option_label, sort_order FROM ONE_DB_MITRA.dbo.vw_m_departemen_dropdown")

                .HasNoKey();



            modelBuilder.Entity<MitraKaryawanAktifView>()

                .ToSqlQuery("SELECT id_karyawan, id_personal, no_nik, nama_lengkap, id_perusahaan, nama_perusahaan, id_departemen, nama_departemen, id_jabatan, nama_jabatan, id_posisi, nama_posisi, path_foto, status_aktif_efektif FROM ONE_DB_MITRA.dbo.vw_m_karyawan_aktif")

                .HasKey(k => k.IdKaryawan);



            // Apply snake_case column names mapping

            foreach (var entity in modelBuilder.Model.GetEntityTypes())

            {

                foreach (var property in entity.GetProperties())

                {

                    property.SetColumnName(ConvertToSnakeCase(property.Name));

                }

            }

        }



        private static string ConvertToSnakeCase(string input)

        {

            if (string.IsNullOrEmpty(input)) return input;



            // Special mappings to ensure 100% database schema compliance

            if (input == "NoNik") return "no_nik";

            if (input == "NoKtp") return "no_ktp";

            if (input == "Hp1") return "hp_1";

            if (input == "RJabatanId") return "r_jabatan_id";

            if (input == "CanScanMinePermit") return "can_scan_minepermit";



            var startUnderscore = System.Text.RegularExpressions.Regex.Replace(input, @"([a-z0-9])([A-Z])", "$1_$2");

            return startUnderscore.ToLower();

        }

    }

}



