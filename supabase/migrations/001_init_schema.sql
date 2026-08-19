# Beauty Clinic iOS - Internal Management System

## Database Schema (Supabase SQL)

Run this in your Supabase SQL Editor to initialize the database.

```sql
-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================
-- USERS TABLE
-- Stores staff/user accounts linked to stores
-- ============================================
create table users (
  id uuid references auth.users(id) primary key,
  phone text not null unique,
  name text not null,
  role text not null default 'staff' check (role in ('admin', 'manager', 'staff')),
  store_id uuid references stores(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- STORES TABLE
-- Clinic branches/locations
-- ============================================
create table stores (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  address text,
  phone text,
  status text default 'active' check (status in ('active', 'pending', 'closed')),
  manager_user_id uuid references users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- CUSTOMERS TABLE
-- Client information for appointments/sales
-- ============================================
create table customers (
  id uuid default uuid_generate_v4() primary key,
  phone text not null unique,
  name text not null,
  gender text check (gender in ('male', 'female', 'other')),
  birthdate date,
  medical_history text, -- Allergies, conditions
  preferences jsonb,    -- JSON: preferred services, notes
  associated_store_id uuid references stores(id),
  last_visit timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- PACKAGES TABLE
-- Beauty service packages (e.g., "HydraFacial Basic")
-- ============================================
create table packages (
  id uuid default uuid_generate_v4() primary key,
  name text not null,
  description text,
  category text not null check (category in ('skin', 'body', 'face', 'hair', 'other')),
  price numeric(10,2) not null,
  duration_minutes integer not null default 60,
  image_url text,
  training_materials jsonb, -- JSON array of storage paths
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================
-- TRANSACTIONS TABLE
-- Appointment/sale records
-- ============================================
create table transactions (
  id uuid default uuid_generate_v4() primary key,
  customer_id uuid not null references customers(id),
  store_id uuid not null references stores(id),
  package_id uuid not null references packages(id),
  staff_user_id uuid references users(id),
  amount numeric(10,2) not null,
  transaction_date timestamptz default now(),
  scheduled_at timestamptz, -- For appointments
  status text default 'pending' check (status in ('pending', 'confirmed', 'completed', 'cancelled', 'refunded')),
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

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

create trigger update_users_updated_at
before update on users
for each row execute procedure update_updated_at_column();

create trigger update_stores_updated_at
before update on stores
for each row execute procedure update_updated_at_column();

create trigger update_customers_updated_at
before update on customers
for each row execute procedure update_updated_at_column();

create trigger update_packages_updated_at
before update on packages
for each row execute procedure update_updated_at_column();

create trigger update_transactions_updated_at
before update on transactions
for each row execute procedure update_updated_at_column();
```

## Row-Level Security (RLS) Policies

Run this in Supabase SQL Editor after creating tables to enable data isolation.

```sql
-- Enable RLS on all tables
alter table users enable row level security;
alter table stores enable row level security;
alter table customers enable row level security;
alter table packages enable row level security;
alter table transactions enable row level security;

-- ============================================
-- USERS POLICIES
-- Staff can read own record; admins see all
-- ============================================
create policy "Users can view own profile"
on users for select using (auth.uid() = id);

create policy "Staff can view users in same store"
on users for select using (
  exists (
    select 1 from users as current_user
    where current_user.id = auth.uid()
      and current_user.store_id = users.store_id
      and current_user.role in ('admin', 'manager')
  )
);

create policy "Admins can manage all users"
on users for all using (
  exists (
    select 1 from users as current_user
    where current_user.id = auth.uid() and current_user.role = 'admin'
  )
);

-- ============================================
-- STORES POLICIES
-- Managers/admins see their store; admins see all
-- ============================================
create policy "Store members can view own store"
on stores for select using (
  exists (
    select 1 from users
    where users.id = auth.uid()
      and (users.store_id = stores.id or users.role = 'admin')
  )
);

create policy "Admins can manage all stores"
on stores for all using (
  exists (
    select 1 from users as current_user
    where current_user.id = auth.uid() and current_user.role = 'admin'
  )
);

-- ============================================
-- CUSTOMERS POLICIES
-- Staff see only customers from their store
-- ============================================
create policy "Staff can view own store's customers"
on customers for select using (
  exists (
    select 1 from users
    where users.id = auth.uid()
      and users.store_id = customers.associated_store_id
  )
);

create policy "Admins can view all customers"
on customers for select using (
  exists (
    select 1 from users as current_user
    where current_user.id = auth.uid() and current_user.role = 'admin'
  )
);

-- ============================================
-- PACKAGES POLICIES
-- All authenticated staff can read packages
-- ============================================
create policy "Authenticated users can view packages"
on packages for select using (auth.role() = 'authenticated');

create policy "Admins can manage all packages"
on packages for all using (
  exists (
    select 1 from users as current_user
    where current_user.id = auth.uid() and current_user.role = 'admin'
  )
);

-- ============================================
-- TRANSACTIONS POLICIES
-- Staff see transactions from their store
-- ============================================
create policy "Staff can view own store's transactions"
on transactions for select using (
  exists (
    select 1 from users
    where users.id = auth.uid()
      and users.store_id = transactions.store_id
  )
);

create policy "Admins can view all transactions"
on transactions for select using (
  exists (
    select 1 from users as current_user
    where current_user.id = auth.uid() and current_user.role = 'admin'
  )
);

-- Allow staff to insert transactions (their store)
create policy "Staff can insert own store's transactions"
on transactions for insert with check (
  exists (
    select 1 from users
    where users.id = auth.uid()
      and users.store_id = transactions.store_id
  )
);
```

## Supabase Storage Buckets

Run these in Supabase Storage SQL (or create manually in Dashboard):

```sql
-- Training materials bucket (images, PDFs)
insert into storage.buckets (id, name, public)
values ('training-materials', 'training-materials', true);

-- Customer images bucket
insert into storage.buckets (id, name, public)
values ('customer-images', 'customer-images', false);
```

## Initial Test Data (Optional)

```sql
-- Insert test store
insert into stores (name, address, phone) values 
('Downtown Clinic', '123 Main St, Shanghai', '021-12345678');

-- Insert admin user (replace with your Supabase user ID)
insert into users (id, phone, name, role, store_id) values
('your-supabase-user-id-here', '+8613900139000', 'Admin User', 'admin', null);
```
