#!/bin/bash

CD_FILE="cd_data.txt"          # ID|Tên CD|Tác giả|Thể loại|Năm|Giá|Số lượng
DETAIL_FILE="cd_detail.txt"    # ID|Bài hát 1;Bài hát 2;...
INVOICE_FILE="invoices.txt"    # InvoiceID|Ngày|TênKH|ID_CD|Tên CD|SL|Đơn giá|Thành tiền

# Khởi tạo file nếu chưa tồn tại
[ ! -f "$CD_FILE" ]      && touch "$CD_FILE"
[ ! -f "$DETAIL_FILE" ]  && touch "$DETAIL_FILE"
[ ! -f "$INVOICE_FILE" ] && touch "$INVOICE_FILE"

# Giao diện và thông báo
line() { printf '%0.s─' {1..60}; echo; }
double_line() { printf '%0.s═' {1..60}; echo; }

# thêm tí màu sắc 
#==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

msg_ok() { echo -e "${GREEN} $1${NC}"; }
msg_err() { echo -e "${RED} $1${NC}"; }
msg_info() { echo -e "${CYAN} $1${NC}"; }
msg_warn() { echo -e "${YELLOW} $1${NC}"; }
#===========================================

# Sinh id tự động
sinh_id_cd() {
    if [ ! -s "$CD_FILE" ]; then
        echo "CD001"
    else
        last=$(awk -F'|' '{print $1}' "$CD_FILE" | grep -oP '\d+' | sort -n | tail -1)
        printf "CD%03d" $((last + 1))
    fi
}

# Pause
pause() { echo; read -rp "$(echo -e "${YELLOW}Nhấn [Enter] để tiếp tục...${NC}")"; }

# ============================================================
# a. THÊM CD

them_cd() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        THÊM ĐĨA CD MỚI${NC}"
    double_line

    read -rp "Tên CD           : " ten_cd
    if [ -z "$ten_cd" ]; then msg_err "Tên CD không được để trống!"; pause; return; fi

    read -rp "Tác giả / Ca sĩ  : " tac_gia
    read -rp "Thể loại          : " the_loai
    read -rp "Năm phát hành     : " nam
    while true; do
        read -rp "Giá bán (VNĐ)    : " gia
        [[ "$gia" =~ ^[0-9]+$ ]] && break
        msg_err "Giá phải là số nguyên dương!"
    done
    while true; do
        read -rp "Số lượng tồn kho : " so_luong
        [[ "$so_luong" =~ ^[0-9]+$ ]] && break
        msg_err "Số lượng phải là số nguyên dương."
    done

    id=$(sinh_id_cd)
    echo "${id}|${ten_cd}|${tac_gia}|${the_loai}|${nam}|${gia}|${so_luong}" >> "$CD_FILE"

    echo
    msg_ok "Đã thêm CD thành công! Mã CD: ${BOLD}${id}${NC}"
    pause
}

# ============================================================
# b. THÊM THÔNG TIN CHI TIẾT CD (danh sách bài hát)

them_chi_tiet_cd() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        THÊM THÔNG TIN CHI TIẾT CD${NC}"
    double_line

    read -rp "Nhập mã CD (VD: CD001): " id
    id=$(echo "$id" | tr '[:lower:]' '[:upper:]')

    dong=$(grep "^${id}|" "$CD_FILE")
    if [ -z "$dong" ]; then
        msg_err "Không tìm thấy CD có mã '${id}'!"
        pause; return
    fi

    ten_cd=$(echo "$dong" | cut -d'|' -f2)
    echo -e "${CYAN}CD: ${BOLD}${ten_cd}${NC}"
    line

    # Kiểm tra đã có chi tiết chưa
    existing=$(grep "^${id}|" "$DETAIL_FILE")
    existing_songs=""
    if [ -n "$existing" ]; then
        existing_songs=$(echo "$existing" | cut -d'|' -f2)
        bai_hien=$(echo "$existing_songs" | tr ';' '\n')
        echo -e "${YELLOW}Danh sách bài hát hiện tại:${NC}"
        echo "$bai_hien" | nl -w2 -s'. '
        echo
        read -rp "Bạn muốn thêm tiếp vào danh sách này không? (y/n): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { msg_info "Đã hủy."; pause; return; }
    fi

    echo -e "Nhập tên từng bài hát (gõ ${RED}XONG${NC} để kết thúc):"
    bai_hat_list=()
    stt=1
    while true; do
        read -rp "  Bài $stt: " bai
        [ "$bai" = "XONG" ] || [ "$bai" = "xong" ] && break
        [ -z "$bai" ] && continue
        bai_hat_list+=("$bai")
        ((stt++))
    done

    if [ ${#bai_hat_list[@]} -eq 0 ]; then
        msg_warn "Không có bài hát nào được thêm."; pause; return
    fi

    # Lưu: ID|bài1;bài2;bài3
    danh_sach_moi=$(IFS=';'; echo "${bai_hat_list[*]}")
    if [ -n "$existing_songs" ]; then
        danh_sach="${existing_songs};${danh_sach_moi}"
        sed -i "/^${id}|/d" "$DETAIL_FILE"
    else
        danh_sach="$danh_sach_moi"
    fi
    echo "${id}|${danh_sach}" >> "$DETAIL_FILE"

    echo
    msg_ok "Đã lưu ${#bai_hat_list[@]} bài hát cho CD ${id}!"
    pause
}

#==============================================================
# c. HIỂN THỊ THÔNG TIN CD NGẮN GỌN

hien_thi_ngan() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        DANH SÁCH ĐĨA CD (TÓM TẮT)${NC}"
    double_line

    if [ ! -s "$CD_FILE" ]; then
        msg_warn "Chưa có dữ liệu CD nào."
        pause; return
    fi

    printf "${BOLD}%-8s %-25s %-20s %-15s %12s %6s${NC}\n" \
        "Mã CD" "Tên CD" "Tác giả" "Thể loại" "Giá (VNĐ)" "SL"
    line
    while IFS='|' read -r id ten tac_gia the_loai nam gia sl; do
        printf "%-8s %-25s %-20s %-15s %12s %6s\n" \
            "$id" "${ten:0:24}" "${tac_gia:0:19}" "${the_loai:0:14}" \
            "$(printf "%'.0f" "$gia")" "$sl"
    done < "$CD_FILE"
    line
    total=$(wc -l < "$CD_FILE")
    echo -e "${CYAN}Tổng số: ${BOLD}${total}${NC} đĩa CD"
    pause
}

# ============================================================
# d. HIỂN THỊ THÔNG TIN CD ĐẦY ĐỦ

hien_thi_day_du() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        THÔNG TIN ĐĨA CD ĐẦY ĐỦ${NC}"
    double_line

    if [ ! -s "$CD_FILE" ]; then
        msg_warn "Chưa có dữ liệu CD nào."; pause; return
    fi

    while IFS='|' read -r id ten tac_gia the_loai nam gia sl; do
        echo -e "${BOLD}${YELLOW}▶ Mã CD      :${NC} ${id}"
        echo -e "  ${BOLD}Tên CD     :${NC} ${ten}"
        echo -e "  ${BOLD}Tác giả    :${NC} ${tac_gia}"
        echo -e "  ${BOLD}Thể loại   :${NC} ${the_loai}"
        echo -e "  ${BOLD}Năm SX     :${NC} ${nam}"
        echo -e "  ${BOLD}Giá bán    :${NC} $(printf "%'.0f" "$gia") VNĐ"
        echo -e "  ${BOLD}Tồn kho    :${NC} ${sl} đĩa"

        # Danh sách bài hát
        detail=$(grep "^${id}|" "$DETAIL_FILE")
        if [ -n "$detail" ]; then
            echo -e "  ${BOLD}Bài hát    :${NC}"
            echo "$detail" | cut -d'|' -f2 | tr ';' '\n' | \
                nl -w4 -s'. ' | sed 's/^/    /'
        else
            echo -e "  ${BOLD}Bài hát    :${NC} ${YELLOW}(Chưa có thông tin)${NC}"
        fi
        line
    done < "$CD_FILE"
    pause
}

# ============================================================
# e. TÌM KIẾM CD THEO THỂ LOẠI

tim_cd_the_loai() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        TÌM KIẾM CD THEO THỂ LOẠI${NC}"
    double_line

    if [ ! -s "$CD_FILE" ]; then
        msg_warn "Chưa có dữ liệu CD nào."
        pause
        return
    fi

    read -rp "Nhập thể loại cần tìm: " the_loai_tim
    if [ -z "$the_loai_tim" ]; then
        msg_err "Thể loại không được để trống!"
        pause
        return
    fi

    the_loai_tim_lc=$(echo "$the_loai_tim" | tr '[:upper:]' '[:lower:]')
    found=0

    clear
    double_line
    echo -e "${BOLD}${BLUE}        KẾT QUẢ TÌM KIẾM THEO THỂ LOẠI${NC}"
    double_line
    printf "${BOLD}%-8s %-25s %-20s %-15s %12s %6s${NC}\n" \
        "Mã CD" "Tên CD" "Tác giả" "Thể loại" "Giá (VNĐ)" "SL"
    line

    while IFS='|' read -r id ten tac_gia the_loai nam gia sl; do
        the_loai_line=$(echo "$the_loai" | tr '[:upper:]' '[:lower:]')
        if printf '%s\n' "$the_loai_line" | grep -Fq -- "$the_loai_tim_lc"; then
            printf "%-8s %-25s %-20s %-15s %12s %6s\n" \
                "$id" "${ten:0:24}" "${tac_gia:0:19}" "${the_loai:0:14}" \
                "$(printf "%'.0f" "$gia")" "$sl"
            found=1
        fi
    done < "$CD_FILE"

    line
    if [ "$found" -eq 0 ]; then
        msg_warn "Không tìm thấy CD nào có thể loại '${the_loai_tim}'."
    else
        msg_ok "Đã hoàn thành tìm kiếm theo thể loại."
    fi
    pause
}

# ============================================================
# f. TIM KIEM CD THEO TAC GIA

tim_cd_the_tac_gia() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        TIM KIEM CD THEO TAC GIA${NC}"
    double_line

    if [ ! -s "$CD_FILE" ]; then
        msg_warn "Chua co du lieu CD nao."
        pause
        return
    fi

    read -rp "Nhap tac gia can tim: " tac_gia_tim
    if [ -z "$tac_gia_tim" ]; then
        msg_err "Tac gia khong duoc de trong!"
        pause
        return
    fi

    tac_gia_tim_lc=$(echo "$tac_gia_tim" | tr '[:upper:]' '[:lower:]')
    found=0

    clear
    double_line
    echo -e "${BOLD}${BLUE}        KET QUA TIM KIEM THEO TAC GIA${NC}"
    double_line
    printf "${BOLD}%-8s %-25s %-20s %-15s %12s %6s${NC}\n" \
        "Ma CD" "Ten CD" "Tac gia" "The loai" "Gia (VND)" "SL"
    line

    while IFS='|' read -r id ten tac_gia the_loai nam gia sl; do
        tac_gia_line=$(echo "$tac_gia" | tr '[:upper:]' '[:lower:]')
        if printf '%s\n' "$tac_gia_line" | grep -Fq -- "$tac_gia_tim_lc"; then
            printf "%-8s %-25s %-20s %-15s %12s %6s\n" \
                "$id" "${ten:0:24}" "${tac_gia:0:19}" "${the_loai:0:14}" \
                "$(printf "%'.0f" "$gia")" "$sl"
            found=1
        fi
    done < "$CD_FILE"

    line
    if [ "$found" -eq 0 ]; then
        msg_warn "Khong tim thay CD nao co tac gia '${tac_gia_tim}'."
    else
        msg_ok "Da hoan thanh tim kiem theo tac gia."
    fi
    pause
}

# ============================================================
# g. TIM KIEM CD THEO TEN BAI HAT

tim_cd_theo_bai_hat() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        TIM KIEM CD THEO TEN BAI HAT${NC}"
    double_line

    if [ ! -s "$CD_FILE" ]; then
        msg_warn "Chua co du lieu CD nao."
        pause
        return
    fi

    if [ ! -s "$DETAIL_FILE" ]; then
        msg_warn "Chua co du lieu bai hat chi tiet nao."
        pause
        return
    fi

    read -rp "Nhap ten bai hat can tim: " bai_hat_tim
    if [ -z "$bai_hat_tim" ]; then
        msg_err "Ten bai hat khong duoc de trong!"
        pause
        return
    fi

    bai_hat_tim_lc=$(echo "$bai_hat_tim" | tr '[:upper:]' '[:lower:]')
    found=0

    clear
    double_line
    echo -e "${BOLD}${BLUE}        KET QUA TIM KIEM THEO TEN BAI HAT${NC}"
    double_line

    while IFS='|' read -r id ten tac_gia the_loai nam gia sl; do
        detail=$(grep "^${id}|" "$DETAIL_FILE")
        [ -z "$detail" ] && continue

        bai_hat_list=$(echo "$detail" | cut -d'|' -f2)
        match_list=()

        IFS=';' read -r -a songs <<< "$bai_hat_list"
        for song in "${songs[@]}"; do
            song_lc=$(echo "$song" | tr '[:upper:]' '[:lower:]')
            case "$song_lc" in
                *"$bai_hat_tim_lc"*) match_list+=("$song") ;;
            esac
        done

        if [ ${#match_list[@]} -gt 0 ]; then
            echo -e "${BOLD}${YELLOW}▶ Mã CD      :${NC} ${id}"
            echo -e "  ${BOLD}Tên CD     :${NC} ${ten}"
            echo -e "  ${BOLD}Tác giả    :${NC} ${tac_gia}"
            echo -e "  ${BOLD}Thể loại   :${NC} ${the_loai}"
            echo -e "  ${BOLD}Bài hát khớp:${NC}"
            printf '%s\n' "${match_list[@]}" | nl -w4 -s'. ' | sed 's/^/    /'
            line
            found=1
        fi
    done < "$CD_FILE"

    if [ "$found" -eq 0 ]; then
        msg_warn "Khong tim thay CD nao chua bai hat '${bai_hat_tim}'."
    else
        msg_ok "Da hoan thanh tim kiem theo ten bai hat."
    fi
    pause
}

# ============================================================
# h. BAN CD

sinh_id_hoa_don() {
    if [ ! -s "$INVOICE_FILE" ]; then
        echo "HD001"
    else
        # Chi lay cac dong du lieu goc co dang HDxxx|...
        last=$(awk -F'|' '/^HD[0-9]+\|/ {print $1}' "$INVOICE_FILE" | grep -oE '[0-9]+' | sort -n | tail -1)
        [ -z "$last" ] && last=0
        printf "HD%03d" $((last + 1))
    fi
}

cap_nhat_so_luong_cd() {
    local ma_cd="$1"
    local so_luong_moi="$2"
    local tmp_file="${CD_FILE}.tmp.$$"

    awk -F'|' -v OFS='|' -v id="$ma_cd" -v sl="$so_luong_moi" '
        $1 == id {$7 = sl}
        {print}
    ' "$CD_FILE" > "$tmp_file" && mv "$tmp_file" "$CD_FILE"
}

ban_cd() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        BAN CD${NC}"
    double_line

    if [ ! -s "$CD_FILE" ]; then
        msg_warn "Chua co du lieu CD nao."
        pause
        return
    fi

    read -rp "Nhap ma CD can ban: " id
    id=$(echo "$id" | tr '[:lower:]' '[:upper:]')

    dong=$(grep "^${id}|" "$CD_FILE")
    if [ -z "$dong" ]; then
        msg_err "Khong tim thay CD co ma '${id}'!"
        pause
        return
    fi

    ten_cd=$(echo "$dong" | cut -d'|' -f2)
    gia_ban=$(echo "$dong" | cut -d'|' -f6)
    ton_kho=$(echo "$dong" | cut -d'|' -f7)

    echo -e "${CYAN}CD: ${BOLD}${ten_cd}${NC}"
    echo -e "Gia ban: $(printf "%'.0f" "$gia_ban") VNĐ"
    echo -e "Ton kho hien tai: ${ton_kho}"

    while true; do
        read -rp "Nhap so luong can ban: " so_luong_ban
        [[ "$so_luong_ban" =~ ^[0-9]+$ ]] && [ "$so_luong_ban" -gt 0 ] && break
        msg_err "So luong phai la so nguyen duong!"
    done

    if [ "$so_luong_ban" -gt "$ton_kho" ]; then
        msg_err "So luong ban vuot qua ton kho hien tai!"
        pause
        return
    fi

    read -rp "Nhap ten khach hang: " ten_kh
    if [ -z "$ten_kh" ]; then
        msg_err "Ten khach hang khong duoc de trong!"
        pause
        return
    fi

    thanh_tien=$((gia_ban * so_luong_ban))
    ton_kho_moi=$((ton_kho - so_luong_ban))
    ma_hd=$(sinh_id_hoa_don)
    ngay_ban=$(date +"%d/%m/%Y")

    cap_nhat_so_luong_cd "$id" "$ton_kho_moi"
    echo "${ma_hd}|${ngay_ban}|${ten_kh}|${id}|${ten_cd}|${so_luong_ban}|${gia_ban}|${thanh_tien}" >> "$INVOICE_FILE"

    echo
    msg_ok "Da ban thanh cong ${so_luong_ban} dia CD ${id}. Ma hoa don: ${ma_hd}"
    pause
}

# ============================================================
# i. IN HOA DON BAN HANG

in_hoa_don_ban_hang() {
    clear
    double_line
    echo -e "${BOLD}${BLUE}        IN HOA DON BAN HANG${NC}"
    double_line

    if [ ! -s "$INVOICE_FILE" ]; then
        msg_warn "Chua co hoa don nao."
        pause
        return
    fi

    invoice_id="$1"
    if [ -z "$invoice_id" ]; then
        read -rp "Nhập mã hóa dơn cần in : " invoice_id
    fi

    if [ -z "$invoice_id" ]; then
        invoice_id=$(awk -F'|' 'NF{last=$1} END{print last}' "$INVOICE_FILE")
    fi

    dong=$(grep "^${invoice_id}|" "$INVOICE_FILE")
    if [ -z "$dong" ]; then
        msg_err "Không tìm thấy hóa đơn '${invoice_id}'."
        pause
        return
    fi

    IFS='|' read -r ma_hd ngay ten_kh id_cd ten_cd sl don_gia thanh_tien <<< "$dong"
    clear
    double_line
    echo -e "${BOLD}${BLUE}               HOA DON BAN HANG${NC}"
    double_line
    echo -e "Ma hoa don  : ${BOLD}${ma_hd}${NC}"
    echo -e "Ngay lap    : ${ngay}"
    echo -e "Khach hang  : ${ten_kh}"
    echo -e "Ma CD       : ${id_cd}"
    echo -e "Ten CD      : ${ten_cd}"
    echo -e "So luong    : ${sl}"
    echo -e "Don gia     : $(printf "%'.0f" "$don_gia") VNĐ"
    echo -e "Thanh tien  : $(printf "%'.0f" "$thanh_tien") VNĐ"
    line

    # Luu phan hoa don da in vao invoices.txt de lam kho luu tru
    {
        echo "============================================================"
        echo "HOA DON BAN HANG: ${ma_hd}"
        echo "Ngay lap    : ${ngay}"
        echo "Khach hang  : ${ten_kh}"
        echo "Ma CD       : ${id_cd}"
        echo "Ten CD      : ${ten_cd}"
        echo "So luong    : ${sl}"
        echo "Don gia     : $(printf "%'.0f" "$don_gia") VNĐ"
        echo "Thanh tien  : $(printf "%'.0f" "$thanh_tien") VNĐ"
        echo "============================================================"
        echo
    } >> "$INVOICE_FILE"

    msg_ok "Da ghi hoa don vao file invoices.txt."
    pause
}

# ============================================================
menu() {
    clear
    double_line
    echo -e "${BOLD}${MAGENTA}      ĐĨA NHẠC - QUẢN LÝ KHO  ${NC}"
    double_line
    echo -e "  ${BOLD}${GREEN}a.${NC} Thêm CD mới"
    echo -e "  ${BOLD}${GREEN}b.${NC} Thêm thông tin chi tiết CD"
    echo -e "  ${BOLD}${GREEN}c.${NC} Hiển thị CD ngắn gọn"
    echo -e "  ${BOLD}${GREEN}d.${NC} Hiển thị CD đầy đủ"
    echo -e "  ${BOLD}${GREEN}e.${NC} Tìm kiếm CD theo thể loại"
    echo -e "  ${BOLD}${GREEN}f.${NC} Tìm kiếm CD theo tác giả"
    echo -e "  ${BOLD}${GREEN}g.${NC} Tìm kiếm CD theo tên bài hát"
    echo -e "  ${BOLD}${GREEN}h.${NC} Bán CD"
    echo -e "  ${BOLD}${GREEN}i.${NC} In hóa đơn bán hàng"
    echo -e "  ${BOLD}${RED}j.${NC} Thoát chương trình"
    double_line
    read -rp "$(echo -e "${BOLD}Chọn chức năng [a-j]: ${NC}")" choice
}

# vòng lặp
# ============================================================
while true; do
    menu
    case "$choice" in
        a|A) them_cd ;;
        b|B) them_chi_tiet_cd ;;
        c|C) hien_thi_ngan ;;
        d|D) hien_thi_day_du ;;
        e|E) tim_cd_the_loai ;;
        f|F) tim_cd_the_tac_gia ;;
        g|G) tim_cd_theo_bai_hat ;;
        h|H) ban_cd ;;
        i|I) in_hoa_don_ban_hang ;;
        j|J)
            clear
            double_line
            echo -e "${BOLD}${MAGENTA}  Cảm ơn đã sử dụng. ${NC}"
            double_line
            exit 0
            ;;
        *) msg_err "Lựa chọn không hợp lệ."; sleep 1 ;;
    esac
done
