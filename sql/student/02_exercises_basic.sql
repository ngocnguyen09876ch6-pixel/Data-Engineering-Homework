------------------------- Q6-Q10: bắt đầu ở dòng 144
------------------------- Q11-Q155: bắt đầu ở dòng 180
CREATE SCHEMA IF NOT EXISTS core;
SET search_path TO core, public;

-- Bảng categories
CREATE TABLE IF NOT EXISTS categories (
    category_id   serial PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng order_status (bảng danh mục trạng thái đơn hàng)
CREATE TABLE IF NOT EXISTS order_status (
    status_id   SERIAL PRIMARY KEY,
    status_code VARCHAR(20) UNIQUE NOT NULL,
    status_name VARCHAR(50) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id       SERIAL PRIMARY KEY,
    full_name         VARCHAR(150) NOT NULL,
    email             VARCHAR(200) UNIQUE NOT NULL,
    phone             VARCHAR(30),
    city              VARCHAR(100),
    customer_segment  VARCHAR(30) NOT NULL,
    status            VARCHAR(20) NOT NULL CHECK (status IN ('active', 'inactive')),
    source_system     VARCHAR(50) NOT NULL DEFAULT 'unknown',
    ingested_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng products
CREATE TABLE IF NOT EXISTS products (
    product_id     SERIAL PRIMARY KEY,
    category_id    INT NOT NULL REFERENCES categories(category_id),
    product_name   VARCHAR(200) NOT NULL,
    unit_price     NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
    cost_price     NUMERIC(14,2) NOT NULL CHECK (cost_price >= 0),
    status         VARCHAR(20) NOT NULL CHECK (status IN ('active', 'inactive', 'discontinued')),
    source_system  VARCHAR(50) NOT NULL DEFAULT 'unknown',
    ingested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng orders
CREATE TABLE IF NOT EXISTS orders (
    order_id       SERIAL PRIMARY KEY,
    customer_id    INT NOT NULL REFERENCES customers(customer_id),
    order_date     TIMESTAMPTZ NOT NULL,
    total_amount   NUMERIC(14,2) NOT NULL CHECK (total_amount >= 0),
    status_id      INT NOT NULL REFERENCES order_status(status_id),
    channel        VARCHAR(20) NOT NULL CHECK (channel IN ('web', 'mobile_app', 'social')),
    source_system  VARCHAR(50) NOT NULL DEFAULT 'unknown',
    ingested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng order_items
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id    SERIAL PRIMARY KEY,
    order_id         INT NOT NULL REFERENCES core.orders(order_id),
    product_id       INT NOT NULL REFERENCES core.products(product_id),
    quantity         INTEGER NOT NULL CHECK (quantity > 0),
    unit_price       NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
    discount_amount  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    source_system    VARCHAR(50) NOT NULL DEFAULT 'unknown',
    ingested_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (discount_amount <= unit_price * quantity)
);

-- Bảng payments
CREATE TABLE IF NOT EXISTS payments (
    payment_id      SERIAL PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES core.orders(order_id),
    payment_date    TIMESTAMPTZ NOT NULL,
    amount          NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    payment_method  VARCHAR(30) NOT NULL CHECK (payment_method IN ('cash', 'bank_transfer', 'card', 'e_wallet')),
    payment_status  VARCHAR(20) NOT NULL CHECK (payment_status IN ('pending', 'success', 'failed', 'refunded')),
    source_system   VARCHAR(50) NOT NULL DEFAULT 'unknown',
    ingested_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed data cho bảng danh mục order_status
INSERT INTO core.order_status (status_code, status_name) VALUES
    ('pending',   'Chờ xử lý'),
    ('confirmed', 'Đã xác nhận'),
    ('shipped',   'Đang giao'),
    ('completed', 'Hoàn tất'),
    ('cancelled', 'Đã hủy')
ON CONFLICT (status_code) DO NOTHING;

-- Indexes cho FK và query performance
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status_id);
CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(order_date);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
-- CHECK #1: order_date không được ở tương lai
ALTER TABLE core.orders ADD CONSTRAINT chk_order_date 
    CHECK (order_date <= NOW());
 LIMIT 10
-- CHECK #2: giá vốn không được lớn hơn giá bán (quy tắc nghiệp vụ)
ALTER TABLE core.products ADD CONSTRAINT chk_cost_lte_price
    CHECK (cost_price <= unit_price);
 LIMIT 10
--Q1 lấy tất cả dữ liệu từ bảng order lọc ra tất cả order có giá trị trên 100
select *
from orders 
where total_amount > 100
 LIMIT 10
--Q2 lấy tất cả giá trị bảng trái custumer join vs bảng orders qua custumer_id để giữ lại tất cả khách hàng và liệt kê những ai chưa mua gì 
select* from customers  
left join orders  using (customer_id)
where order_id is null
 LIMIT 10
--Q3 dùng order by để sắp xếp đưa những hóa đơn có giá trị to nhất lên trên cùng và tối đa 10 người (limt 10)
select* from orders 
order by total_amount desc 
limit 10;

--Q4 chỉ chọn custumer_id để xem số khách hàng có đơn hàng khác nhau
select
count(DISTINCT customer_id)
from orders 
 LIMIT 10
-- Q5: 5 đơn hàng mới nhất
SELECT * 
FROM orders 
ORDER BY order_date DESC 
LIMIT 5;

------------------------- Q6-Q10:
select 
EXTRACT(MONTH FROM order_date) AS thang,
SUM(total_amount) as tong_doang_thu
from orders
group by
EXTRACT(MONTH FROM order_date);

select 
customer_id,
AVG(total_amount) as trung_binh_gia
from orders
group by 
customer_id;

select 
status_id,
count(status_id) as so_luong_don
from orders 
group by 
status_id;


select
category_name,
SUM(quantity * order_items.unit_price - discount_amount) as gia_theo_danh_muc
FROM order_items 
JOIN products USING (product_id)
JOIN categories USING (category_id)
group by 
category_name
having sum(quantity * order_items.unit_price - discount_amount) > 1000;


------------------------ Q11-Q15:

select full_name, email, order_id, order_date
from orders 
JOIN customers using (customer_id)

select  product_name, products.unit_price, order_id, quantity
from order_items 
join products using (product_id)

select  *
from payments 
left join order_items using(order_id)
where quantity is null

select *
from order_items
left join payments using(order_id)
where amount is null

select product_name, order_id 
from products 
left join order_items using(product_id)
where order_id is null 

select order_id, SUM(quantity * order_items.unit_price) as tong_tien_hang , total_amount 
from orders 
join order_items using(order_id)
group by 
order_id,
total_amount;





