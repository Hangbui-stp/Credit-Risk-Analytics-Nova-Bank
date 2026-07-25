-- CREDIT RISK ANALYTICS - NOVA BANK 

SELECT name FROM sys.tables;

/* MÔ TẢ DANH MỤC
   Khách hàng là ai, vay bao nhiêu, tỷ lệ vỡ nợ tổng thể ra sao */

-- Q1: Tổng quan danh mục
SELECT COUNT(*) AS tong_khoan_vay, 
    SUM(loan_status) AS so_vo_no,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct,
    ROUND(AVG(loan_amnt), 0) AS khoan_vay_tb,
    ROUND(AVG(loan_int_rate), 2) AS lai_suat_tb
FROM loans_scored;

-- Q2: Cơ cấu danh mục theo mục đích vay (volume, quy mô, thu nhập)
SELECT loan_intent,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(loan_amnt), 0) AS khoan_vay_tb,
    ROUND(AVG(person_income), 0) AS thu_nhap_tb,
    SUM(loan_amnt) AS tong_du_no
FROM loans_scored
GROUP BY loan_intent
ORDER BY so_khoan_vay DESC;

-- Q3: Phân bố khách theo nhóm tuổi 
SELECT age_band,
    COUNT(*) AS so_khach,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS ty_trong_pct
FROM loans_scored
GROUP BY age_band
ORDER BY age_band;


/* SO SÁNH NHÓM */

-- Q4: Default rate theo hình thức sở hữu nhà
SELECT person_home_ownership,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct
FROM loans_scored
GROUP BY person_home_ownership
ORDER BY ty_le_default_pct DESC;

-- Q5: Default rate + tổn thất theo mục đích vay
SELECT loan_intent,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct,
    SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) AS du_no_default
FROM loans_scored
GROUP BY loan_intent
ORDER BY ty_le_default_pct DESC;

-- Q6: Lịch sử tín dụng — đã từng vỡ nợ (Y/N)
SELECT cb_person_default_on_file AS tung_vo_no,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct
FROM loans_scored
GROUP BY cb_person_default_on_file
ORDER BY ty_le_default_pct DESC;

-- Q7: Default rate theo band thu nhập 
SELECT income_band,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct
FROM loans_scored
GROUP BY income_band
ORDER BY MIN(person_income);

-- Q8: Default rate theo hạng tín dụng 
SELECT loan_grade,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct
FROM loans_scored
GROUP BY loan_grade
ORDER BY loan_grade;


/* PHÂN TÍCH SÂU */

-- Q9: Điểm gãy DTI — bin bằng CASE WHEN quanh ngưỡng 0.40 đã chốt từ EDA
SELECT
    CASE
        WHEN debt_to_income_ratio <= 0.20 THEN '1. <=0.20'
        WHEN debt_to_income_ratio <= 0.30 THEN '2. 0.20-0.30'
        WHEN debt_to_income_ratio <= 0.40 THEN '3. 0.30-0.40'
        WHEN debt_to_income_ratio <= 0.45 THEN '4. 0.40-0.45'
        ELSE                                   '5. >0.45'
    END AS dti_band,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct
FROM loans_scored
GROUP BY
    CASE
        WHEN debt_to_income_ratio <= 0.20 THEN '1. <=0.20'
        WHEN debt_to_income_ratio <= 0.30 THEN '2. 0.20-0.30'
        WHEN debt_to_income_ratio <= 0.40 THEN '3. 0.30-0.40'
        WHEN debt_to_income_ratio <= 0.45 THEN '4. 0.40-0.45'
        ELSE '5. >0.45'
    END
ORDER BY dti_band;

-- Q10: Ma trận rủi ro grade x income band 
WITH cell_stats AS (
    SELECT loan_grade, income_band,
        COUNT(*) AS n,
        AVG(CAST(loan_status AS FLOAT)) AS default_rate
    FROM loans_scored
    GROUP BY loan_grade, income_band
)
SELECT loan_grade, income_band, n,
    ROUND(default_rate * 100, 1) AS ty_le_default_pct
FROM cell_stats
ORDER BY loan_grade, income_band;

-- Q11: So sánh chân dung tài chính: default vs non-default (MEDIAN, không dùng AVG
--      vì income lệch phải — outlier kéo mean, median đại diện khách điển hình)
SELECT DISTINCT loan_status,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY person_income)
        OVER (PARTITION BY loan_status) AS median_thu_nhap,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY loan_amnt)
        OVER (PARTITION BY loan_status) AS median_khoan_vay,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY loan_int_rate)
        OVER (PARTITION BY loan_status) AS median_lai_suat,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY debt_to_income_ratio)
        OVER (PARTITION BY loan_status) AS median_dti
FROM loans_scored;

-- Q12: Xếp hạng state theo default rate 
SELECT state, so_khoan_vay, ty_le_default_pct,
    RANK() OVER (ORDER BY ty_le_default_pct DESC) AS hang_rui_ro
FROM (
    SELECT state, COUNT(*) AS so_khoan_vay,
        ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct
    FROM loans_scored
    GROUP BY state
    HAVING COUNT(*) >= 500
) t
ORDER BY hang_rui_ro;

-- Q13: Chân dung rủi ro cao đa điều kiện (ngưỡng từ EDA) so với phần còn lại
WITH phan_loai AS (
    SELECT *,
        CASE
            WHEN debt_to_income_ratio > 0.40
             AND person_income        < 55000
             AND loan_grade IN ('D','E','F','G')
            THEN '1. Chan dung rui ro cao'
            ELSE '2. Phan con lai'
        END AS nhom
    FROM loans_scored
),
tong_hop AS (
    SELECT nhom, COUNT(*) AS so_khoan_vay,
        AVG(CAST(loan_status AS FLOAT)) AS default_rate,
        SUM(loan_status) AS so_vo_no,
        SUM(loan_amnt) AS tong_du_no
    FROM phan_loai
    GROUP BY nhom
)
SELECT nhom, so_khoan_vay,
    ROUND(default_rate * 100, 1) AS ty_le_default_pct,
    ROUND(so_khoan_vay * 100.0 / SUM(so_khoan_vay) OVER (), 1) AS pct_danh_muc,
    ROUND(so_vo_no * 100.0 / SUM(so_vo_no) OVER (), 1) AS pct_tong_vo_no,
    tong_du_no
FROM tong_hop
ORDER BY nhom;

-- Q14: Kiểm chứng scorecard — default rate theo segment và theo số cờ đỏ
SELECT segment,
    COUNT(*) AS so_khoan_vay,
    ROUND(AVG(CAST(loan_status AS FLOAT)) * 100, 1) AS ty_le_default_pct,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_danh_muc,
    ROUND(SUM(loan_status) * 100.0 / SUM(SUM(loan_status)) OVER (), 1) AS pct_tong_vo_no
FROM loans_scored
GROUP BY segment
ORDER BY ty_le_default_pct;
GO

/* SERVING CHO POWER BI */

-- Q15: View tổng hợp 
CREATE OR ALTER VIEW vw_risk_summary AS
SELECT segment, loan_intent, loan_grade, income_band, country, person_home_ownership,
    COUNT(*) AS so_khoan_vay,
    SUM(loan_status) AS so_vo_no,
    AVG(CAST(loan_status AS FLOAT)) AS default_rate,
    SUM(loan_amnt) AS tong_du_no,
    SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) AS du_no_default
FROM loans_scored
GROUP BY segment, loan_intent, loan_grade, income_band, country, person_home_ownership;
GO

-- View sau tạo:
SELECT TOP 10 * FROM vw_risk_summary ORDER BY so_khoan_vay DESC;

