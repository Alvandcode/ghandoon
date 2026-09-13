-- سوپابیس قنادی قند — v1
-- این فایل را در SQL Editor سوپابیس اجرا کن

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
  category text not null check (category in ('کیک خونگی','کوکی','بیسکوییت','کیک تولد')),
  description text default '',
  ingredients text default '',
  price int default 0,
  unit text default 'عدد',
  image_url text,
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
('کیک خونگی', 'کیک خونگی', 'کیک خونگی تازه با عطر وانیل', 'آرد، تخم‌مرغ، شکر، کره، شیر، وانیل', 280000, 'عدد (1 کیلویی)'),
('کوکی کشمشی', 'کوکی', 'کوکی ترد با کشمش و گردو', 'آرد، کره، شکر قهوه‌ای، کشمش، گردو', 180000, 'بسته نیم‌کیلویی'),
('رولت خامه‌ای', 'بیسکوییت', 'رولت سبک با خامه وانیلی', 'آرد، تخم‌مرغ، شکر، خامه، وانیل', 220000, 'عدد'),
('کیک تولد اختصاصی', 'کیک تولد', 'کیک چندطبقه با دیزاین دلخواه', 'کیک شکلاتی/وانیلی، خامه، میوه فصل', 650000, 'پایه (2 کیلویی)')
on conflict (title) do nothing;

-- Storage buckets (از داشبورد Storage بساز): product-images (public) ، receipts (private)
-- هشدار امنیتی: پالیسی‌های «open all for v1» زیر فقط برای نمونه اولیه/دمو هستند!
-- هر کسی که ANON KEY را داشته باشد می‌تواند همه سفارش‌ها/پیام‌ها را بخواند و بنویسد.
-- برای محصول واقعی، آن‌ها را حذف و نسخه سفت‌وسخت (v2) پایین را فعال کن.
-- RLS را بعدا برای production سفت کن؛ برای شروع:
alter table profiles enable row level security;
alter table products enable row level security;
alter table orders enable row level security;
alter table messages enable row level security;
alter table app_settings enable row level security;

create policy "public read products" on products for select using (true);
-- دمو v1: نوشتن محصول با anon-key (تا پنل/سید بدون service_role کار کند).
-- در production حتما DROP شود و نوشتن فقط با service_role انجام شود.
create policy "open products write v1" on products for all using (true) with check (true);
create policy "open all for v1" on profiles for all using (true) with check (true);
create policy "open all orders v1" on orders for all using (true) with check (true);
create policy "open all msgs v1" on messages for all using (true) with check (true);
create policy "open settings v1" on app_settings for all using (true) with check (true);

-- ============ نسخه سفت‌وسخت پیشنهادی برای production (v2) ============
-- طرز استفاده: اول 5 پالیسی open بالا را DROP کن، بعد این بلوک را اجرا کن.
-- پیش‌نیاز: احراز هویت Supabase Auth فعال باشد و user_id سفارش = auth.uid().
--
-- drop policy if exists "open products write v1" on products;
-- drop policy if exists "open all for v1" on profiles;
-- drop policy if exists "open all orders v1" on orders;
-- drop policy if exists "open all msgs v1" on messages;
-- drop policy if exists "open settings v1" on app_settings;
--
-- -- همه می‌توانند تنظیمات عمومی (شماره کارت/زرین‌پال) را بخوانند، فقط سرویس‌رول بنویسد:
-- create policy "settings read for all" on app_settings
--   for select using (true);
--
-- -- محصولات فعال برای همه قابل خواندن:
-- -- (پالیسی "public read products" بالا کافی است؛ نوشتن فقط با service_role)
--
-- -- سفارش: هر کاربر فقط سفارش خودش (user_id = auth.uid())؛ مدیر با service_role همه را می‌بیند:
-- create policy "orders owner read" on orders
--   for select using (auth.uid() = user_id);
-- create policy "orders owner insert" on orders
--   for insert with check (auth.uid() = user_id);
-- create policy "orders owner update own pending" on orders
--   for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
--
-- -- پیام‌ها: فقط فرستنده/گیرنده:
-- create policy "msgs participant read" on messages
--   for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
-- create policy "msgs sender insert" on messages
--   for insert with check (auth.uid() = sender_id);
--
-- -- Storage: باکت product-images عمومی‌خوانا؛ آپلود فقط service_role (از پنل مدیر با سرویسی‌کی).
-- -- باکت receipts خصوصی: هر کاربر فقط مسیر user_id/ خودش.
-- -- (از داشبورد Storage > Policies اعمال کن)
-- -- storage.objects select: bucket_id = 'product-images' → allow public read
-- -- storage.objects insert/update/delete on 'receipts' → allow where auth.uid()::text = (storage.foldername(name))[1]
