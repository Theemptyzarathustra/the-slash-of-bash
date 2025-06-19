#!/bin/bash

# Ambil jumlah objek misplaced dari output ceph -s
misplaced_objects=$(ceph -s | grep -oP '\d+/\d+ objects misplaced' | awk -F'/' '{print $1}')

# Ambil kecepatan recovery dalam objek per detik dari output ceph -s
recovery_objects_per_sec=$(ceph -s | grep -oP 'recovery: \K\d+(?= objects/s)')

# Jika recovery_objects_per_sec tidak ditemukan, coba ambil dari baris lain
if [[ -z "$recovery_objects_per_sec" ]]; then
  recovery_objects_per_sec=$(ceph -s | grep -oP '\d+ objects/s' | awk '{print $1}')
fi

# Periksa apakah nilai yang diperlukan ada
if [[ -z "$misplaced_objects" || -z "$recovery_objects_per_sec" ]]; then
  echo "Tidak dapat menemukan informasi yang diperlukan dari output ceph -s."
  exit 1
fi

# Hitung waktu recovery dalam detik
recovery_time_sec=$((misplaced_objects / recovery_objects_per_sec))

# Konversi waktu dalam detik menjadi jam, menit, dan detik
recovery_time_hours=$((recovery_time_sec / 3600))
recovery_time_sec=$((recovery_time_sec % 3600))
recovery_time_minutes=$((recovery_time_sec / 60))
recovery_time_seconds=$((recovery_time_sec % 60))

# Cetak hasil
echo "Perkiraan waktu recovery untuk $misplaced_objects objek misplaced:"
echo "$recovery_time_hours jam $recovery_time_minutes menit $recovery_time_seconds detik"
