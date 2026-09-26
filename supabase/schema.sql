-- سوپابیس قنادی قند — v2.2 (رفع انسداد ذخیره محصول + ساخت باکت عکس)
-- این فایل را در SQL Editor سوپابیس اجرا کن؛ کل فایل را یکجا Run کن.
-- اجرای چندباره امن است (همه‌جا if exists / on conflict دارد).
--
-- ⚠️ ترتیب بخش‌ها مهم است — اول ستون‌ها و محدودیت‌ها، بعد داده، بعد پالیسی‌ها.
--    (نسخه قبلی ستون main_categories را بعداً اضافه می‌کرد ولی قبلش آن را
--     می‌نوشت؛ چون کل فایل یک تراکنش است، خطای 42703 همه‌چیز را برمی‌گرداند
--     و عملاً هیچ تغییری روی دیتابیس اعمال نمی‌شد.)
--
-- 🔓 تصمیم (گزینه A): دسترسی کلاینت‌ها باز نگه داشته می‌شود تا سفارش/چت/تنظیمات
--    بین دو گوشی همگام بماند. ریسک شناخته‌شده: هر کسی با کلید anon داخل اپ
--    فنیاً می‌تواند سفارش‌ها را ببیند یا شماره کارت را عوض کند — شماره کارت را
--    دوره‌ای چک کن. امنیت واقعی بعد از مهاجرت به Supabase Auth است
--    (بلوک v3 انتهای فایل؛ آن موقع این پالیسی‌های باز را ببند).

-- ============ 1) جدول‌ها (برای دیتابیس خالی/جدید) ============

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

-- ============ 2) مهاجرت ستون‌ها و محدودیت‌ها — قبل از هر داده‌ای ============
-- اپ جدید این ستون‌ها را می‌خواند/می‌نویسد؛ روی دیتابیس قدیمی باید قبل از
-- هر insert/update اضافه شوند تا خطای 42703 کل اجرا را برنگرداند.

alter table orders add column if not exists customer_username text default '';
alter table orders add column if not exists product_title text default '';
alter table orders add column if not exists tracking_code text;
alter table orders add column if not exists fulfillment text default 'delivery';
alter table orders add column if not exists delivery_fee int default 0;
alter table orders add column if not exists items_summary text default '';
alter table orders add column if not exists cake_options text default '';
alter table profiles add column if not exists fcm_token text default '';
-- چهار شاخه اصلی سفارش در صفحه خانه (JSON array مثل ["دسر","شیرینی","کیک","شکلات"])
alter table app_settings add column if not exists main_categories text default '';
-- عکس صفحه توضیحات محصول
alter table products add column if not exists detail_image_url text;
-- دسته دیگر به ۴ مقدار قدیمی قفل نیست؛ عنوان از تنظیمات مدیر می‌آید.
-- این محدودیت علت اصلی خطای «ذخیره محصول ناموفق» (23514) روی دیتابیس قدیمی است.
alter table products drop constraint if exists products_category_check;

-- ============ 3) داده‌ها ============

insert into app_settings (id) values (1) on conflict (id) do nothing;

-- ایندکس یکتایی عنوان (پیش‌نیاز on conflict پایین)؛ اگر عنوان تکراری قدیمی
-- پیدا شد، خطا ندهد چون کل اجرا برمی‌گردد — فقط اعلام می‌شود.
do $$
begin
  create unique index if not exists products_title_unique on products(title);
exception when others then
  raise notice 'products_title_unique رد شد: %', sqlerrm;
end $$;

-- سید اولیه محصولات (idempotent). اگر به هر دلیلی شکست خورد کل مهاجرت
-- نباید متوقف شود.
do $$
begin
  insert into products (title, category, description, ingredients, price, unit) values
  ('کیک خونگی', 'کیک', 'کیک خونگی تازه با عطر وانیل', 'آرد، تخم‌مرغ، شکر، کره، شیر، وانیل', 280000, 'عدد (1 کیلویی)'),
  ('کوکی کشمشی', 'شیرینی', 'کوکی ترد با کشمش و گردو', 'آرد، کره، شکر قهوه‌ای، کشمش، گردو', 180000, 'بسته نیم‌کیلویی'),
  ('رولت خامه‌ای', 'شیرینی', 'رولت سبک با خامه وانیلی', 'آرد، تخم‌مرغ، شکر، خامه، وانیل', 220000, 'عدد'),
  ('کیک تولد اختصاصی', 'کیک', 'کیک چندطبقه با دیزاین دلخواه', 'کیک شکلاتی/وانیلی، خامه، میوه فصل', 650000, 'پایه (2 کیلویی)')
  on conflict (title) do nothing;
exception when others then
  raise notice 'seed products رد شد: %', sqlerrm;
end $$;

-- دسته‌های اصلی پیش‌فرض (فقط وقتی خالی است؛ اجرای چندباره دستی مدیر را بازنویسی نمی‌کند)
update app_settings
set main_categories = '["دسر","شیرینی","کیک","شکلات"]'
where id = 1 and (main_categories is null or main_categories = '');

-- ============ 4) RLS ============

alter table profiles enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table messages enable row level security;
alter table app_settings enable row level security;

-- products: خواندن عمومی؛ نوشتن برای پنل مدیر.
-- (تنها استثنا روی تولید — بیشتر در CONTRIBUTING.md)
drop policy if exists "open products write v1" on products;
drop policy if exists "public read products" on products;
create policy "public read products" on products for select using (true);
drop policy if exists "admin products write" on products;
create policy "admin products write" on products
  for all
  using (true)
  with check (true);

-- بقیه جدول‌ها: دسترسی باز کلاینت (گزینه A — وضعیت موجود دیتابیس).
-- نام‌های قدیمی موجود روی سرور (مثل "orders demo all") دست نمی‌خورند و همین
-- رفتار را دارند؛ اینجا نام رایج هر دو نسخه ساخته می‌شود تا دیتابیس جدید هم
-- مثل قدیمی کار کند. RLS فعال است ولی پالیسی‌ها اجازه دسترسی می‌دهند.
drop policy if exists "open all for v1" on profiles;
create policy "open all for v1" on profiles
  for all using (true) with check (true);

drop policy if exists "open all orders v1" on orders;
create policy "open all orders v1" on orders
  for all using (true) with check (true);

drop policy if exists "open all msgs v1" on messages;
create policy "open all msgs v1" on messages
  for all using (true) with check (true);

drop policy if exists "open settings v1" on app_settings;
create policy "open settings v1" on app_settings
  for all using (true) with check (true);

-- ============ 5) Storage: باکت product-images ============
-- آپلود عکس محصول از پنل مدیر بدون این باکت با خطای 400 شکست می‌خورد.
-- اگر به هر دلیلی (حق دسترسی نقش postgres) ساخته نشد، کل مهاجرت متوقف نشود؛
-- خطا به‌صورت notice اعلام می‌شود.
do $$
begin
  insert into storage.buckets (id, name, public)
    values ('product-images', 'product-images', true)
    on conflict (id) do update set public = excluded.public;
exception when others then
  raise notice 'ساخت باکت product-images رد شد: %', sqlerrm;
end $$;

do $$
begin
  drop policy if exists "product images public read" on storage.objects;
  create policy "product images public read" on storage.objects
    for select using (bucket_id = 'product-images');
exception when others then
  raise notice 'پالیسی خواندن عکس رد شد: %', sqlerrm;
end $$;

do $$
begin
  drop policy if exists "product images upload" on storage.objects;
  create policy "product images upload" on storage.objects
    for insert to authenticated, anon
    with check (bucket_id = 'product-images');
exception when others then
  raise notice 'پالیسی آپلود عکس رد شد: %', sqlerrm;
end $$;

do $$
begin
  drop policy if exists "product images delete" on storage.objects;
  create policy "product images delete" on storage.objects
    for delete to authenticated, anon
    using (bucket_id = 'product-images');
exception when others then
  raise notice 'پالیسی حذف عکس رد شد: %', sqlerrm;
end $$;

-- ============ v3 — بعد از مهاجرت به Supabase Auth این بلوک را فعال کن ============
-- پیش‌نیاز: ورود/ثبت‌نام با supabase.auth و user_id سفارش = auth.uid().
--
-- آن موقع:
--   1) پالیسی‌های باز بالا (open all ...) را drop کن.
--   2) نوشتن app_settings را فقط service_role بگذار (تغییر کارت از داشبورد).
--   3) پالیسی نوشتن products را به ادمین واقعی محدود کن.
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
