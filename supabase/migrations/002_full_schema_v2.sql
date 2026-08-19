-- ============================================
-- BEAUTY CLINIC iOS APP - DATABASE SCHEMA v2
-- ============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================
-- PHASE 1: CREATE ALL TABLES (no foreign keys for cyclic deps)
-- ============================================

-- USERS TABLE (managed by Supabase Auth)
create table users (
  id uuid references auth.users(id) primary key,
  email text unique,
  phone text,
  name text not null,
  role text not null default 'staff' check (role in ('admin', 'manager', 'staff')),
  store_id uuid,  -- FK added below after stores exists
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- STORES TABLE
create table stores (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  address text,
  phone text,
  status text default 'active' check (status in ('active', 'pending', 'closed')),
  manager_id uuid,  -- FK added below after users exists
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- CUSTOMERS TABLE
create table customers (
  id uuid default uuid_generate_v4() primary key,
  phone text not null,
  name text not null,
  gender text check (gender in ('male', 'female', 'other')),
  birthdate date,
  medical_history text,
  preferences jsonb,
  photo_url text,
  associated_store_id uuid references stores(id),
  created_by uuid references users(id),
  last_visit timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- PACKAGES / SERVICES TABLE
create table packages (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  description text,
  category text not null check (category in ('skin', 'body', 'face', 'hair', 'other', 'training')),
  price numeric(10,2) not null,
  duration_minutes integer not null default 60,
  total_sessions integer default 1,
  image_url text,
  training_materials jsonb,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- TRANSACTIONS TABLE (成交记录)
create table transactions (
  id uuid default uuid_generate_v4() primary key,
  customer_id uuid not null references customers(id),
  store_id uuid not null references stores(id),
  package_id uuid not null references packages(id),
  staff_user_id uuid references users(id),
  amount numeric(10,2) not null,
  total_sessions integer default 1,
  completed_sessions integer default 0,
  transaction_date timestamptz default now(),
  first_delivery_date timestamptz,
  estimated_completion_date timestamptz,
  status text default 'pending' check (status in ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'refunded')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- DELIVERIES TABLE (交付记录)
create table deliveries (
  id uuid default uuid_generate_v4() primary key,
  transaction_id uuid not null references transactions(id),
  customer_id uuid not null references customers(id),
  store_id uuid not null references stores(id),
  staff_user_id uuid references users(id),
  session_number integer not null,
  delivery_date timestamptz default now(),
  notes text,
  photos jsonb,
  created_at timestamptz default now()
);

-- TRAINING MATERIALS TABLE
create table training_materials (
  id uuid default uuid_generate_v4() primary key,
  package_id uuid references packages(id),
  title text not null,
  version text not null default '1.0',
  file_url text not null,
  file_type text check (file_type in ('pdf', 'ppt', 'pptx', 'video', 'image')),
  description text,
  uploaded_by uuid references users(id),
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- CUSTOMER PHOTOS TABLE
create table customer_photos (
  id uuid default uuid_generate_v4() primary key,
  customer_id uuid not null references customers(id),
  photo_url text not null,
  photo_type text default 'profile' check (photo_type in ('profile', 'before', 'after', 'progress')),
  notes text,
  uploaded_by uuid references users(id),
  created_at timestamptz default now()
);

-- ============================================
-- PHASE 2: ADD FOREIGN KEYS FOR CYCLIC DEPS
-- ============================================

-- users.store_id -> stores.id
alter table users add constraint fk_user_store
  foreign key (store_id) references stores(id);

-- stores.manager_id -> users.id
alter table stores add constraint fk_store_manager
  foreign key (manager_id) references users(id);

-- ============================================
-- TRIGGER: UPDATE timestamps
-- ============================================
create or replace function update_updated_at_column()
returns trigger as $$
begin
   NEW.updated_at = now();
   return NEW;
end;
$$ language 'plpgsql';

create trigger update_users_updated_at before update on users for each row execute procedure update_updated_at_column();
create trigger update_stores_updated_at before update on stores for each row execute procedure update_updated_at_column();
create trigger update_customers_updated_at before update on customers for each row execute procedure update_updated_at_column();
create trigger update_packages_updated_at before update on packages for each row execute procedure update_updated_at_column();
create trigger update_transactions_updated_at before update on transactions for each row execute procedure update_updated_at_column();
create trigger update_training_materials_updated_at before update on training_materials for each row execute procedure update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS
alter table users enable row level security;
alter table stores enable row level security;
alter table customers enable row level security;
alter table packages enable row level security;
alter table transactions enable row level security;
alter table deliveries enable row level security;
alter table training_materials enable row level security;
alter table customer_photos enable row level security;

-- Helper function: get current user's role
create or replace function get_current_user_role()
returns text as $$
begin
  return (select role from users where id = auth.uid());
end;
$$ language plpgsql security definer;

-- Helper function: get current user's store_id
create or replace function get_current_user_store_id()
returns uuid as $$
begin
  return (select store_id from users where id = auth.uid());
end;
$$ language plpgsql security definer;

-- ============================================
-- USERS POLICIES
-- ============================================
create policy "Users can view own profile"
on users for select using (auth.uid() = id);

create policy "Admin can view all users"
on users for select using (get_current_user_role() = 'admin');

create policy "Manager can view same store users"
on users for select using (
  get_current_user_role() = 'manager'
  and store_id = get_current_user_store_id()
);

create policy "Admin can manage all users"
on users for all using (get_current_user_role() = 'admin');

-- ============================================
-- STORES POLICIES
-- ============================================
create policy "Admin can view all stores"
on stores for select using (get_current_user_role() = 'admin');

create policy "Staff can view own store"
on stores for select using (
  id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

create policy "Admin can manage all stores"
on stores for all using (get_current_user_role() = 'admin');

-- ============================================
-- CUSTOMERS POLICIES
-- ============================================
create policy "Admin can view all customers"
on customers for select using (get_current_user_role() = 'admin');

create policy "Staff can view own store customers"
on customers for select using (
  associated_store_id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

create policy "Staff can insert customers for own store"
on customers for insert with check (
  associated_store_id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

create policy "Admin can manage all customers"
on customers for all using (get_current_user_role() = 'admin');

-- ============================================
-- PACKAGES POLICIES
-- ============================================
create policy "All authenticated users can view active packages"
on packages for select using (is_active = true or get_current_user_role() = 'admin');

create policy "Admin can manage all packages"
on packages for all using (get_current_user_role() = 'admin');

-- ============================================
-- TRANSACTIONS POLICIES
-- ============================================
create policy "Admin can view all transactions"
on transactions for select using (get_current_user_role() = 'admin');

create policy "Staff can view own store transactions"
on transactions for select using (
  store_id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

create policy "Staff can insert transactions for own store"
on transactions for insert with check (
  store_id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

create policy "Admin can manage all transactions"
on transactions for all using (get_current_user_role() = 'admin');

-- ============================================
-- DELIVERIES POLICIES
-- ============================================
create policy "Admin can view all deliveries"
on deliveries for select using (get_current_user_role() = 'admin');

create policy "Staff can view own store deliveries"
on deliveries for select using (
  store_id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

create policy "Staff can insert deliveries for own store"
on deliveries for insert with check (
  store_id = get_current_user_store_id()
  or get_current_user_role() = 'admin'
);

-- ============================================
-- TRAINING MATERIALS POLICIES
-- ============================================
create policy "All authenticated users can view training materials"
on training_materials for select using (is_active = true);

create policy "Admin can manage training materials"
on training_materials for all using (get_current_user_role() = 'admin');

-- ============================================
-- CUSTOMER PHOTOS POLICIES
-- ============================================
create policy "Admin can view all customer photos"
on customer_photos for select using (get_current_user_role() = 'admin');

create policy "Staff can view own store customer photos"
on customer_photos for select using (
  exists (
    select 1 from customers
    where customers.id = customer_photos.customer_id
    and customers.associated_store_id = get_current_user_store_id()
  )
  or get_current_user_role() = 'admin'
);

-- ============================================
-- STORAGE BUCKETS
-- ============================================
-- Customer photos bucket
insert into storage.buckets (id, name, public)
values ('customer-photos', 'customer-photos', false)
on conflict do nothing;

-- Package images bucket
insert into storage.buckets (id, name, public)
values ('package-images', 'package-images', true)
on conflict do nothing;

-- Training materials bucket
insert into storage.buckets (id, name, public)
values ('training-materials', 'training-materials', true)
on conflict do nothing;

-- ============================================
-- STORAGE RLS POLICIES
-- ============================================
create policy "Authenticated users can upload customer photos"
on storage.objects for insert with check (
  bucket_id = 'customer-photos' and auth.role() = 'authenticated'
);

create policy "Authenticated users can upload package images"
on storage.objects for insert with check (
  bucket_id = 'package-images' and auth.role() = 'authenticated'
);

create policy "Authenticated users can upload training materials"
on storage.objects for insert with check (
  bucket_id = 'training-materials' and auth.role() = 'authenticated'
);

create policy "Authenticated users can read storage"
on storage.objects for select using (
  auth.role() = 'authenticated'
);
