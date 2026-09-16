CREATE table if not exists  "customers" (
  "customers_id" integer PRIMARY KEY NOT NULL,
  "email" varchar UNIQUE NOT NULL,
  "created_at" timestamp
);

CREATE table if not exists  "categories" (
  "categories_id" integer PRIMARY KEY NOT NULL,
  "updated_at" timestamp
);

CREATE table if not exists  "orders" (
  "orders_id" integer PRIMARY KEY NOT NULL,
  "customer_id" integer NOT NULL,
  "order_date" timestamp,
  "order_status_id" integer NOT NULL
);

CREATE table if not exists  "products" (
  "products_id" integer PRIMARY KEY NOT NULL,
  "categories_id" integer NOT NULL,
  "price" numeric NOT NULL
);

CREATE table if not exists  "order_items" (
  "orders_id" integer NOT NULL,
  "products_id" integer NOT NULL,
  "price" decimal NOT NULL
);

CREATE table if not exists  "payments" (
  "payments_id" integer PRIMARY KEY NOT NULL,
  "orders_id" integer NOT NULL,
  "payment_date" timestamp,
  "amount" numeric NOT NULL,
  "status" varchar
);

CREATE table if not exists  "order_status" (
  "order_status_id" integer PRIMARY KEY NOT NULL,
  "status_name" varchar,
  "updated_status" timestamp
);

ALTER TABLE "orders" ADD FOREIGN KEY ("customer_id") REFERENCES "customers" ("customers_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "products" ADD FOREIGN KEY ("categories_id") REFERENCES "categories" ("categories_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "order_items" ADD FOREIGN KEY ("orders_id") REFERENCES "orders" ("orders_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "order_items" ADD FOREIGN KEY ("products_id") REFERENCES "products" ("products_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "payments" ADD FOREIGN KEY ("orders_id") REFERENCES "orders" ("orders_id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "orders" ADD FOREIGN KEY ("order_status_id") REFERENCES "order_status" ("order_status_id") DEFERRABLE INITIALLY IMMEDIATE;
