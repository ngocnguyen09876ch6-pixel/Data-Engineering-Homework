
-- PHẦN 1.1: SALES DATA MART DESIGN
-- GRAIN: 1 row per order_item (Một dòng đại diện cho một mục hàng trong đơn)
-- LÝ DO: Để giữ được độ chi tiết tối đa. Cho phép đo lường doanh thu (revenue), 
-- số lượng (quantity) chi tiết đến cấp độ sản phẩm (product) và danh mục (category).
CREATE SCHEMA IF NOT EXISTS mart;

-- DIMENSION: dim_date
-- Lấy từ đâu: Không lấy từ hệ thống gốc. Được sinh tự động bằng code (generate_series).
-- Map thế nào: Chuyển ngày YYYY-MM-DD thành số nguyên YYYYMMDD làm date_key.

CREATE TABLE IF NOT EXISTS mart.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    day_of_month SMALLINT NOT NULL,
    month_num SMALLINT NOT NULL,
    year_num SMALLINT NOT NULL
);


-- DIMENSION: dim_customer
-- Lấy từ đâu: Bảng core.customers
-- Map thế nào: Ánh xạ mã định danh (customer_id) sang Khóa kỹ thuật (customer_sk).
-- Các thông tin nhân khẩu học được bê nguyên sang.

CREATE TABLE IF NOT EXISTS mart.dim_customer (
    customer_sk BIGSERIAL PRIMARY KEY,
    customer_id VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(50),
    phone_number VARCHAR(30),
    segment VARCHAR(30),
    city VARCHAR(50),
    status VARCHAR(30)
);


-- DIMENSION: dim_product
-- Lấy từ đâu: Kết hợp (JOIN) từ core.products và core.categories.
-- Map thế nào: Phi chuẩn hóa (Denormalize) - Nhồi luôn category_name vào bảng.
-- Tạo khóa kỹ thuật product_sk thay cho product_id.

CREATE TABLE IF NOT EXISTS mart.dim_product(
    product_sk BIGSERIAL PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE NOT NULL,
    category_id VARCHAR(50),
    product_name VARCHAR(100),
    category_name VARCHAR(100)
);


-- DIMENSION: dim_order_status & dim_payment_method
-- Lấy từ đâu: Trích xuất các trạng thái (DISTINCT) từ core.orders và core.payments.
-- Map thế nào: Đóng gói các chuỗi text dài ('completed', 'cash') thành khóa số nhỏ (SMALLINT).

CREATE TABLE IF NOT EXISTS mart.dim_order_status (
    order_status_sk SMALLSERIAL PRIMARY KEY,
    order_status VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS mart.dim_payment_method (
    payment_method_sk SMALLSERIAL PRIMARY KEY,
    payment_method VARCHAR(30) UNIQUE NOT NULL
);


-- FACT TABLE: fact_sales
-- Lấy từ đâu: Bảng core.order_items (làm gốc để giữ grain), join với orders và payments.
-- Map thế nào: 
-- + Lookup lấy 5 khóa ngoại (_sk) từ 5 bảng Dimension.
-- + Tính toán gross_amount = quantity * unit_price.
-- + Tính toán net_amount = gross_amount - discount_amount.
-- + Giữ lại order_id làm Degenerate Dimension để hỗ trợ đếm số đơn hàng.

CREATE TABLE IF NOT EXISTS mart.fact_sales (
    sales_key BIGSERIAL PRIMARY KEY,
    order_item_id VARCHAR(16) NOT NULL UNIQUE,
    order_id VARCHAR(12) NOT NULL,
    customer_sk BIGINT REFERENCES mart.dim_customer(customer_sk),
    product_sk BIGINT REFERENCES mart.dim_product(product_sk),
    date_key INTEGER REFERENCES mart.dim_date(date_key),
    order_status_sk SMALLINT REFERENCES mart.dim_order_status(order_status_sk),
    payment_method_sk SMALLINT REFERENCES mart.dim_payment_method(payment_method_sk),
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    discount_amount NUMERIC(14,2) NOT NULL,
    gross_amount NUMERIC(14,2) NOT NULL,
    net_amount NUMERIC(14,2) NOT NULL
);

--------------------- LOAD ----------------------------------------------------------------------------------------------

insert into mart.dim_customer( customer_id, full_name, phone_number, segment, city, status)
select customer_id,full_name,phone,customer_segment,city,status from core.customers;

INSERT INTO mart.dim_product (product_id, category_id, product_name, category_name)
SELECT 
product_id,
category_id,
product_name,
category_name
FROM core.products 
JOIN core.categories using (category_id);

insert into mart.dim_order_status (order_status)
select distinct status 
from core.orders;

insert into mart.dim_payment_method  (payment_method)
select distinct payment_method 
from core.payments ;

INSERT INTO mart.dim_date (date_key, full_date, day_of_month, month_num, year_num)
SELECT 
    -- 1. Biến ngày 2025-01-01 thành số nguyên 20250101 để làm khóa chính
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
       -- 2. Giữ nguyên định dạng ngày chuẩn
    d::DATE AS full_date,
        -- 3. Dùng hàm EXTRACT để "bóc" lấy ngày, tháng, năm từ biến d
    EXTRACT(DAY FROM d)::SMALLINT AS day_of_month,
    EXTRACT(MONTH FROM d)::SMALLINT AS month_num,
    EXTRACT(YEAR FROM d)::SMALLINT AS year_num
FROM GENERATE_SERIES(
    '2025-01-01'::DATE, -- Ngày bắt đầu
    '2027-12-31'::DATE, -- Ngày kết thúc
    '1 day'             -- Bước nhảy là 1 ngày
) AS d
ON CONFLICT (date_key) DO NOTHING; 

INSERT INTO mart.fact_sales (
    order_item_id, order_id, 
    customer_sk, product_sk, date_key, order_status_sk, payment_method_sk, 
    quantity, unit_price, discount_amount, gross_amount, net_amount
)
SELECT 
    oi.order_item_id,
    o.order_id,
    dc.customer_sk,
    dp.product_sk,
    dd.date_key,  
    dos.order_status_sk , 
    dpm.payment_method_sk, 
    oi.quantity,
    oi.unit_price,
    0 AS discount_amount, 
    (oi.quantity * oi.unit_price)::NUMERIC(14,2) AS gross_amount, 
    ( oi.quantity * oi.unit_price - 0  )::NUMERIC(14,2) AS net_amount 
FROM core.order_items oi
JOIN core.orders o ON oi.order_id = o.order_id
JOIN core.payments p ON o.order_id = p.order_id
JOIN mart.dim_customer dc ON o.customer_id = dc.customer_id
JOIN mart.dim_product dp ON oi.product_id = dp.product_id
JOIN mart.dim_date dd ON TO_CHAR(o.order_date, 'YYYYMMDD')::INT = dd.date_key
JOIN mart.dim_order_status dos ON o.status = dos.order_status
JOIN mart.dim_payment_method dpm ON p.payment_method = dpm.payment_method;

SELECT COUNT(*) FROM mart.fact_sales;