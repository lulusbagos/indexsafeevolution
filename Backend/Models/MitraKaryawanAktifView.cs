using System;
using System.ComponentModel.DataAnnotations;

namespace Indexsafe.Api.Models
{
    public class MitraKaryawanAktifView
    {
        [Key]
        public int IdKaryawan { get; set; }
        public int IdPersonal { get; set; }
        public string NoNik { get; set; } = string.Empty;
        public string? NamaLengkap { get; set; }
        public int? IdPerusahaan { get; set; }
        public string? NamaPerusahaan { get; set; }
        public int? IdDepartemen { get; set; }
        public string? NamaDepartemen { get; set; }
        public int? IdJabatan { get; set; }
        public string? NamaJabatan { get; set; }
        public int? IdPosisi { get; set; }
        public string? NamaPosisi { get; set; }
        public string? PathFoto { get; set; }
        public bool StatusAktifEfektif { get; set; }
    }
}
