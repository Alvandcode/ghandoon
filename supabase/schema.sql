-- سوپابیس قنادی قند — v2.1 (امن‌شده + نوشتن محصول از پنل مدیر)
-- این فایل را در SQL Editor سوپابیس اجرا کن (اجرای چندباره امن است؛ سید تکراری نمی‌سازد)
--
-- ⚠️ امنیت — چه چیزی عوض شد:
-- نسخه‌های قبلی پالیسی‌های «open for all» داشتند که با anon key داخل APK هر کسی
-- می‌توانست همه سفارش‌ها/پیام‌ها را بخواند و حتی شماره کارت را عوض کند.
-- حالا:
--   * پالیسی‌های باز قبلی به‌صورت idempotent DROP می‌شوند.
--   * products: خواندن عمومی + نوشتن برای پنل مدیر (بدون Supabase Auth هنوز
--     اپ نمی‌تواند با service_role کار کند؛ بدون این پالیسی «افزودن محصول»
--     داخل اپ همیشه permission denied می‌دهد).
--   * app_settings: فقط خواندن عمومی؛ نوشتن فقط service_role
--     (تغییر شماره کارت/زرین‌پال فقط از داشبورد سوپابیس انجام شود، نه از اپ).
--   * profiles / orders / messages: فعلاً هیچ پالیسی کلاینتی ندارند (فقط service_role)
--     چون احراز هویت هنوز لوکال است. بعد از مهاجرت به Supabase Auth، بلوک v3 پایین را فعال کن.
--   * بعد از مهاجرت واقعی به Supabase Auth، پالیسی نوشتن products را به
--     role ادمین محدود کن (اینجا موقتاً باز است تا پنل داخل اپ کار کند).

create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  phone text,
  full_name text,
  role text default 'user' check (role in ('user','admin')),
  created_at timestamptz default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  description text default '',
  ingredients text default '',
  price int default 0,
  unit text default 'عدد',
  image_url text,
  detail_image_url text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete set null,
  product_id uuid references products(id) on delete set null,
  qty int default 1,
  persons int default 1,
  full_name text not null,
  phone text not null,
  address text not null,
  delivery_date text not null,
  note text default '',
  status text default 'pending' check (status in ('pending','awaiting_payment','receipt_sent','approved','ready','delivered','cancelled')),
  total_price int default 0,
  card_number text default '',
  zarinpal_link text default '',
  receipt_url text,
  admin_note text default '',
  created_at timestamptz default now()
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references orders(id) on delete cascade,
  sender_id uuid references profiles(id) on delete set null,
  receiver_id uuid references profiles(id) on delete set null,
  text text not null,
  created_at timestamptz default now()
);

create table if not exists app_settings (
  id int primary key default 1 check (id = 1),
  card_number text default '6037-9911-1234-5678',
  card_owner text default 'قنادی قند',
  zarinpal_link text default '',
  support_phone text default '09130000000',
  updated_at timestamptz default now()
);

insert into app_settings (id) values (1) on conflict (id) do nothing;

-- سید اولیه محصولات (idempotent: اجرای چندباره، ردیف تکراری نمی‌سازد)
-- نیاز به یکتایی title دارد تا on conflict کار کند
create unique index if not exists products_title_unique on products(title);
insert into products (title, category, description, ingredients, price, unit) values
('کیک خونگی', 'کیک', 'کیک خونگی تازه با عطر وانیل', 'آرد، تخم‌مرغ، شکر، کره، شیر، وانیل', 280000, 'عدد (1 کیلویی)'),
('کوکی کشمشی', 'شیرینی', 'کوکی ترد با کشمش و گردو', 'آرد، کره، شکر قهوه‌ای، کشمش، گردو', 180000, 'بسته نیم‌کیلویی'),
('رولت خامه‌ای', 'شیرینی', 'رولت سبک با خامه وانیلی', 'آرد، تخم‌مرغ، شکر، خامه، وانیل', 220000, 'عدد'),
('کیک تولد اختصاصی', 'کیک', 'کیک چندطبقه با دیزاین دلخواه', 'کیک شکلاتی/وانیلی، خامه، میوه فصل', 650000, 'پایه (2 کیلویی)')
on conflict (title) do nothing;

-- دسته‌های اصلی پیش‌فرض (فقط وقتی خالی است؛ اجرای چندباره دستی مدیر را بازنویسی نمی‌کند)
update app_settings
set main_categories = '["دسر","شیرینی","کیک","شکلات"]'
where id = 1 and (main_categories is null or main_categories = '');

-- ============ RLS ============

alter table profiles enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table messages enable row level security;
alter table app_settings enable row level security;

-- حذف پالیسی‌های باز نسخه‌های قبلی (اجرای چندباره امن است)
drop policy if exists "open products write v1" on products;
drop policy if exists "open all for v1" on profiles;
drop policy if exists "open all orders v1" on orders;
drop policy if exists "open all msgs v1" on messages;
drop policy if exists "open settings v1" on app_settings;

-- products: خواندن عمومی؛ نوشتن برای پنل مدیر (بدون Auth هنوز service_role در اپ ممکن نیست)
drop policy if exists "public read products" on products;
create policy "public read products" on products for select using (true);
drop policy if exists "admin products write" on products;
create policy "admin products write" on products
  for all
  using (true)
  with check (true);

-- app_settings: خواندن عمومی (شماره کارت/زرین‌پال برای نمایش لازم است)؛ نوشتن فقط service_role
drop policy if exists "settings read for all" on app_settings;
create policy "settings read for all" on app_settings for select using (true);

-- profiles / orders / messages: تا مهاجرت به Supabase Auth هیچ پالیسی کلاینتی ندارند.
-- RLS فعال با صفر پالیسی یعنی anon/authenticated هیچ دسترسی‌ای ندارند؛
-- فقط service_role بایپس می‌کند. اپ فعلاً سفارش/چت را لوکال نگه می‌دارد.

-- ============ v2.1 — ستون‌های چنددستگاهی شدن سفارش (اجرای چندباره امن) ============
-- اپ جدید این ستون‌ها را می‌خواند/می‌نویسد؛ اگر سرور قدیمی باشد، مپر اپ
-- با fallback کار می‌کند ولی مدیر و مشتری همدیگر را نمی‌بینند تا این اجرا شود.
alter table orders add column if not exists customer_username text default '';
alter table orders add column if not exists product_title text default '';
alter table orders add column if not exists tracking_code text;
create unique index if not exists orders_tracking_unique on orders(tracking_code);
-- v2.2 — سبد چندمحصولی / کیک‌ساز / تحویل و پیک (اجرای چندباره امن)
alter table orders add column if not exists fulfillment text default 'delivery';
alter table orders add column if not exists delivery_fee int default 0;
alter table orders add column if not exists items_summary text default '';
alter table orders add column if not exists cake_options text default '';
-- v2.3 — توکن پوش هر دستگاه (ثبت فقط از Edge Function با service_role؛
-- کلاینت حق نوشتن مستقیم profiles را ندارد و RLS بسته می‌ماند)
alter table profiles add column if not exists fcm_token text default '';

-- ============ v2.4 — سلسله‌مراتب دسته‌ها + عکس توضیحات (اجرای چندباره امن) ============
-- چهار شاخه اصلی سفارش در صفحه خانه (JSON array مثل ["دسر","شیرینی","کیک","شکلات"])
alter table app_settings add column if not exists main_categories text default '';
-- عکس صفحه توضیحات محصول (قبلاً در create نبود ولی اپ می‌نویسد)
alter table products add column if not exists detail_image_url text;
-- دسته دیگر به ۴ مقدار قدیمی قفل نیست؛ عنوان از تنظیمات مدیر می‌آید
alter table products drop constraint if exists products_category_check;

-- Storage: باکت product-images (عمومی‌خوان) + حق آپلود برای پنل مدیر.
-- اجرای چندباره امن است. اگر باکت از داشبورد ساخته شده باشد on conflict می‌پرد.
-- receipts همچنان از داشبورد جدا ساخته می‌شود (خصوصی، بعد از Auth).
insert into storage.buckets (id, name, public)
  values ('product-images', 'product-images', true)
  on conflict (id) do update set public = excluded.public;

drop policy if exists "product images public read" on storage.objects;
create policy "product images public read" on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists "product images upload" on storage.objects;
create policy "product images upload" on storage.objects
  for insert to authenticated, anon
  with check (bucket_id = 'product-images');

drop policy if exists "product images delete" on storage.objects;
create policy "product images delete" on storage.objects
  for delete to authenticated, anon
  using (bucket_id = 'product-images');

-- ============ v3 — بعد از مهاجرت به Supabase Auth این بلوک را فعال کن ============
-- پیش‌نیاز: ورود/ثبت‌نام با supabase.auth و user_id سفارش = auth.uid().
--
-- create policy "profiles self read upsert" on profiles
--   for all using (auth.uid() = id) with check (auth.uid() = id);
--
-- create policy "orders owner read" on orders
--   for select using (auth.uid() = user_id);
-- create policy "orders owner insert" on orders
--   for insert with check (auth.uid() = user_id);
-- create policy "orders owner update own" on orders
--   for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
--
-- create policy "msgs participant read" on messages
--   for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
-- create policy "msgs sender insert" on messages
--   for insert with check (auth.uid() = sender_id);
--
-- Storage باکت receipts (خصوصی): هر کاربر فقط پوشه‌ی خودش:
--   storage.objects select/insert where bucket_id='receipts'
--     and auth.uid()::text = (storage.foldername(name))[1]
