-- ============================================
-- SERVICE RECORDS TABLE (服务记录系统)
-- ============================================

create table service_records (
  id uuid default uuid_generate_v4() primary key,
  customer_id uuid references customers(id) not null,
  transaction_id uuid references transactions(id),
  service_date timestamptz default now(),
  operator_id uuid references users(id),
  operator_name text,
  operator_phone text,
  body_part text,
  photos jsonb default '[]',
  customer_feedback text,
  extra_payment numeric(10,2) default 0,
  extra_payment_note text,
  sessions_used integer default 1,
  remaining_sessions integer,
  created_at timestamptz default now()
);

-- Trigger for updated timestamps
create trigger update_service_records_updated_at before update on service_records for each row execute procedure update_updated_at_column();

-- ============================================
-- EXTEND CUSTOMERS TABLE
-- ============================================

alter table customers add column if not exists outstanding_amount numeric(10,2) default 0;
alter table customers add column if not exists conversion_probability integer default 50 check (conversion_probability between 0 and 100);

-- ============================================
-- RLS POLICIES
-- ============================================
alter table service_records enable row level security;

create policy "Admin can view all service records"
on service_records for select using (get_current_user_role() = 'admin');

create policy "Staff can view own store service records"
on service_records for select using (
  exists (
    select 1 from customers
    where customers.id = service_records.customer_id
    and customers.associated_store_id = get_current_user_store_id()
  )
  or get_current_user_role() = 'admin'
);

create policy "Staff can insert service records for own store"
on service_records for insert with check (
  exists (
    select 1 from customers
    where customers.id = service_records.customer_id
    and customers.associated_store_id = get_current_user_store_id()
  )
  or get_current_user_role() = 'admin'
);

create policy "Admin can manage all service records"
on service_records for all using (get_current_user_role() = 'admin');
