#!/bin/bash

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTION] [WORD]

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
  $(basename "$0")
  $(basename "$0") -f ESTABLISHED
  $(basename "$0") -C 30.30.238.21
  $(basename "$0") -c
  $(basename "$0") -c STATUS
  $(basename "$0") -c STATUS,PROTO_ID
  $(basename "$0") -c STATUS PROTO_ID -f 6800
  $(basename "$0") -f 6800 -c STATUS PROTO_ID
EOF
}

COLUMNS=("PROTO" "PROTO_ID" "TIME" "STATUS" "ORIG_SRC_IP" "ORIG_DST_IP" "ORIG_SPORT" "ORIG_DPORT" "REPLY_SRC_IP" "REPLY_DST_IP" "REPLY_SPORT" "REPLY_DPORT" "FLAGS" "MARK" "USE")
HEADER="${COLUMNS[*]}"

# Default values
SHOW_HELP=0
DO_COUNT=0
COUNTWORD=""
FILTER=""
COLNAMES_RAW=""
REQCOLS=()
GROUPCOUNT=""

# Parse all args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            SHOW_HELP=1
            shift
            ;;
        -f|--find)
            FILTER="$2"
            shift 2
            ;;
        -C|--COUNTING)
            DO_COUNT=1
            COUNTWORD="$2"
            shift 2
            ;;
        -c|--column)
            shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -*) break ;;
                    *) COLNAMES_RAW+="$1 " ;;
                esac
                shift
            done
            ;;
        -G|--group-count)
            GROUPCOUNT="$2"
            shift 2
            ;;
        *)
            if [[ -z "$FILTER" ]]; then
                FILTER="$1"
            fi
            shift
            ;;
    esac
done

if [[ $SHOW_HELP -eq 1 ]]; then
    show_help
    exit 0
fi

# Handle counting
if [[ $DO_COUNT -eq 1 ]]; then
    conntrack -L | grep "$COUNTWORD" | awk '/^(tcp|udp|icmp)/' | wc -l
    exit 0
fi

# Siapkan filter jika ada
if [[ -n "$FILTER" ]]; then
    DATA=$(conntrack -L | grep "$FILTER")
else
    DATA=$(conntrack -L)
fi

# Siapkan kolom jika ada
if [[ -n "$COLNAMES_RAW" ]]; then
    COLNAMES_RAW=$(echo "$COLNAMES_RAW" | tr ',' ' ')
    read -ra REQCOLS <<< "$COLNAMES_RAW"
    if [ ${#REQCOLS[@]} -eq 0 ] || [ -z "${REQCOLS[0]}" ]; then
        echo "$HEADER"
        exit 0
    fi
    # Validasi semua kolom
    COLIDX=()
    OUTCOLS=()
    for REQ in "${REQCOLS[@]}"; do
        REQ_UP=$(echo "$REQ" | tr '[:lower:]' '[:upper:]')
        FOUND=0
        for i in "${!COLUMNS[@]}"; do
            if [ "${COLUMNS[$i]}" = "$REQ_UP" ]; then
                COLIDX+=( $((i+1)) )
                OUTCOLS+=( "$REQ_UP" )
                FOUND=1
                break
            fi
        done
        if [ $FOUND -eq 0 ]; then
            echo "Error: Kolom '$REQ' tidak valid." >&2
            echo "Kolom yang tersedia: $HEADER" >&2
            exit 1
        fi
    done
    # Print header
    echo "${OUTCOLS[*]}"
    # Print isi kolom
    echo "$DATA" | awk '/^(tcp|udp|icmp)/' | awk -v idxs="${COLIDX[*]}" '
    {
        proto = $1
        proto_id = $2
        time = $3
        status = $4
        orig_src = ""
        orig_dst = ""
        orig_sport = ""
        orig_dport = ""
        reply_src = ""
        reply_dst = ""
        reply_sport = ""
        reply_dport = ""
        flags = ""
        mark = ""
        use = ""
        for (i=5; i<=NF; i++) {
            if ($i ~ /^src=/ && orig_src == "") orig_src = substr($i,5)
            else if ($i ~ /^dst=/ && orig_dst == "") orig_dst = substr($i,5)
            else if ($i ~ /^sport=/ && orig_sport == "") orig_sport = substr($i,7)
            else if ($i ~ /^dport=/ && orig_dport == "") orig_dport = substr($i,7)
            else if ($i ~ /^src=/ && orig_src != "") reply_src = substr($i,5)
            else if ($i ~ /^dst=/ && orig_dst != "") reply_dst = substr($i,5)
            else if ($i ~ /^sport=/ && orig_sport != "") reply_sport = substr($i,7)
            else if ($i ~ /^dport=/ && orig_dport != "") reply_dport = substr($i,7)
            else if ($i ~ /^\[.*\]$/) flags = $i
            else if ($i ~ /^mark=/) mark = substr($i,6)
            else if ($i ~ /^use=/) use = substr($i,5)
        }
        gsub(/\[|\]/, "", flags)
        arr[1]=proto; arr[2]=proto_id; arr[3]=time; arr[4]=status; arr[5]=orig_src; arr[6]=orig_dst;
        arr[7]=orig_sport; arr[8]=orig_dport; arr[9]=reply_src; arr[10]=reply_dst; arr[11]=reply_sport;
        arr[12]=reply_dport; arr[13]=flags; arr[14]=mark; arr[15]=use;
        split(idxs, idxarr, " ")
        out=""
        for (j=1; j<=length(idxarr); j++) {
            out = out (j>1 ? OFS : "") arr[idxarr[j]]
        }
        print out
    }' OFS=" "
    exit 0
fi

# Fitur group-count
if [[ -n "$GROUPCOUNT" ]]; then
    # Validasi kolom
    COLIDX=0
    REQ_UP=$(echo "$GROUPCOUNT" | tr '[:lower:]' '[:upper:]')
    for i in "${!COLUMNS[@]}"; do
        if [ "${COLUMNS[$i]}" = "$REQ_UP" ]; then
            COLIDX=$((i+1))
            break
        fi
    done
    if [ $COLIDX -eq 0 ]; then
        echo "Error: Kolom '$GROUPCOUNT' tidak valid." >&2
        echo "Kolom yang tersedia: $HEADER" >&2
        exit 1
    fi
    echo "$DATA" | awk '/^(tcp|udp|icmp)/' | awk -v idx=$COLIDX '
    {
        proto = $1
        proto_id = $2
        time = $3
        status = $4
        orig_src = ""
        orig_dst = ""
        orig_sport = ""
        orig_dport = ""
        reply_src = ""
        reply_dst = ""
        reply_sport = ""
        reply_dport = ""
        flags = ""
        mark = ""
        use = ""
        for (i=5; i<=NF; i++) {
            if ($i ~ /^src=/ && orig_src == "") orig_src = substr($i,5)
            else if ($i ~ /^dst=/ && orig_dst == "") orig_dst = substr($i,5)
            else if ($i ~ /^sport=/ && orig_sport == "") orig_sport = substr($i,7)
            else if ($i ~ /^dport=/ && orig_dport == "") orig_dport = substr($i,7)
            else if ($i ~ /^src=/ && orig_src != "") reply_src = substr($i,5)
            else if ($i ~ /^dst=/ && orig_dst != "") reply_dst = substr($i,5)
            else if ($i ~ /^sport=/ && orig_sport != "") reply_sport = substr($i,7)
            else if ($i ~ /^dport=/ && orig_dport != "") reply_dport = substr($i,7)
            else if ($i ~ /^\[.*\]$/) flags = $i
            else if ($i ~ /^mark=/) mark = substr($i,6)
            else if ($i ~ /^use=/) use = substr($i,5)
        }
        gsub(/\[|\]/, "", flags)
        arr[1]=proto; arr[2]=proto_id; arr[3]=time; arr[4]=status; arr[5]=orig_src; arr[6]=orig_dst;
        arr[7]=orig_sport; arr[8]=orig_dport; arr[9]=reply_src; arr[10]=reply_dst; arr[11]=reply_sport;
        arr[12]=reply_dport; arr[13]=flags; arr[14]=mark; arr[15]=use;
        print arr[idx]
    }' | sort | uniq -c
    exit 0
fi

# Jika tidak ada -c, tampilkan tabel penuh
# Output tabel (full/filter)
echo "$DATA" | awk '
BEGIN {
    printf "%-5s %-7s %-10s %-13s %-15s %-15s %-7s %-7s %-15s %-15s %-7s %-7s %-10s %-7s %-5s\n", \
        "PROTO", "PROTO_ID", "TIME", "STATUS", "ORIG_SRC_IP", "ORIG_DST_IP", "ORIG_SPORT", "ORIG_DPORT", \
        "REPLY_SRC_IP", "REPLY_DST_IP", "REPLY_SPORT", "REPLY_DPORT", "FLAGS", "MARK", "USE"
}
/^(tcp|udp|icmp)/ {
    proto = $1
    proto_id = $2
    time = $3
    status = $4
    orig_src = ""
    orig_dst = ""
    orig_sport = ""
    orig_dport = ""
    reply_src = ""
    reply_dst = ""
    reply_sport = ""
    reply_dport = ""
    flags = ""
    mark = ""
    use = ""
    for (i=5; i<=NF; i++) {
        if ($i ~ /^src=/ && orig_src == "") orig_src = substr($i,5)
        else if ($i ~ /^dst=/ && orig_dst == "") orig_dst = substr($i,5)
        else if ($i ~ /^sport=/ && orig_sport == "") orig_sport = substr($i,7)
        else if ($i ~ /^dport=/ && orig_dport == "") orig_dport = substr($i,7)
        else if ($i ~ /^src=/ && orig_src != "") reply_src = substr($i,5)
        else if ($i ~ /^dst=/ && orig_dst != "") reply_dst = substr($i,5)
        else if ($i ~ /^sport=/ && orig_sport != "") reply_sport = substr($i,7)
        else if ($i ~ /^dport=/ && orig_dport != "") reply_dport = substr($i,7)
        else if ($i ~ /^\[.*\]$/) flags = $i
        else if ($i ~ /^mark=/) mark = substr($i,6)
        else if ($i ~ /^use=/) use = substr($i,5)
    }
    gsub(/\[|\]/, "", flags)
    printf "%-5s %-7s %-10s %-13s %-15s %-15s %-7s %-7s %-15s %-15s %-7s %-7s %-10s %-7s %-5s\n", \
        proto, proto_id, time, status, orig_src, orig_dst, orig_sport, orig_dport, \
        reply_src, reply_dst, reply_sport, reply_dport, flags, mark, use
}
' | column -t
