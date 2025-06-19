## Manual Usage

```bash
Usage: conntrack.sh [OPTION] [WORD]

Fitur:
  -h, --help                  Tampilkan bantuan ini.
  -f, --find WORD             Tampilkan tabel hanya baris yang mengandung WORD.
  -c, --column [NAMES...]     Tampilkan nama kolom saja, atau isi satu/lebih kolom tertentu jika NAMES diberikan (pisahkan dengan spasi atau koma).
  -C, --COUNTING WORD         Hitung jumlah baris yang mengandung WORD.
  -G, --group-count NAME      Hitung jumlah kemunculan setiap nilai unik pada kolom NAME.

Catatan:
- Semua opsi bisa dikombinasikan, urutan bebas (misal: -c COL1 COL2 -f WORD).
- WORD/NAMES sebaiknya berupa status koneksi (ESTABLISHED, TIME_WAIT, dst), IP, port, atau nama kolom yang valid.
- Tidak bisa digunakan untuk nama kolom yang tidak ada.
- Jika tidak ada opsi, akan menampilkan seluruh tabel.

Contoh penggunaan:
  conntrack.sh
  conntrack.sh -f ESTABLISHED
  conntrack.sh -C 30.50.239.21
  conntrack.sh -c
  conntrack.sh -c STATUS
  conntrack.sh -c STATUS,PROTO_ID
  conntrack.sh -c STATUS PROTO_ID -f 6800
  conntrack.sh -f 6800 -c STATUS PROTO_ID
```
