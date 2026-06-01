#!/bin/bash

CD_FILE="cd_data.txt"          # ID|Tên CD|Tác giả|Thể loại|Năm|Giá|Số lượng
DETAIL_FILE="cd_detail.txt"    # ID|Bài hát 1;Bài hát 2;...
INVOICE_FILE="invoices.txt"    # InvoiceID|Ngày|TênKH|ID_CD|Tên CD|SL|Đơn giá|Thành tiền

# Khởi tạo file nếu chưa tồn tại
[ ! -f "$CD_FILE" ]      && touch "$CD_FILE"
[ ! -f "$DETAIL_FILE" ]  && touch "$DETAIL_FILE"
[ ! -f "$INVOICE_FILE" ] && touch "$INVOICE_FILE"

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
    if [ -n "$existing" ]; then
        bai_hien=$(echo "$existing" | cut -d'|' -f2 | tr ';' '\n')
        echo -e "${YELLOW}Danh sách bài hát hiện tại:${NC}"
        echo "$bai_hien" | nl -w2 -s'. '
        echo
        read -rp "Bạn muốn GHI ĐÈ danh sách này? (y/n): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { msg_info "Đã hủy."; pause; return; }
        sed -i "/^${id}|/d" "$DETAIL_FILE"
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
    danh_sach=$(IFS=';'; echo "${bai_hat_list[*]}")
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
menu() {
    clear
    double_line
    echo -e "${BOLD}${MAGENTA}      ĐĨA NHẠC - QUẢN LÝ KHO  ${NC}"
    double_line
    echo -e "  ${BOLD}${GREEN}a.${NC} Thêm CD mới"
    echo -e "  ${BOLD}${GREEN}b.${NC} Thêm thông tin chi tiết CD"
    echo -e "  ${BOLD}${GREEN}c.${NC} Hiển thị CD ngắn gọn"
    echo -e "  ${BOLD}${GREEN}d.${NC} Hiển thị CD đầy đủ"
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
