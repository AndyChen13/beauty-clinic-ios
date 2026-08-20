-- ============================================
-- DELETION REQUESTS TABLE (删除审批系统)
-- ============================================

create table deletion_requests (
  id uuid default uuid_generate_v4() primary key,
  requester_id uuid references auth.users(id) not null,
  target_type text not null check (target_type in ('customer', 'store', 'package', 'user')),
  target_id uuid not null,
  target_name text,
  reason text,
  status text default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  processed_by uuid references users(id),
  processed_at timestamptz,
  created_at timestamptz default now()
);

-- Trigger for updated timestamps
create trigger update_deletion_requests_updated_at before update on deletion_requests for each row execute procedure update_updated_at_column();

-- ============================================
-- RLS POLICIES
-- ============================================
alter table deletion_requests enable row level security;

-- Anyone can create deletion requests
create policy "Authenticated users can create deletion requests"
on deletion_requests for insert with check (auth.role() = 'authenticated');

-- Users can view their own requests
create policy "Users can view own deletion requests"
on deletion_requests for select using (requester_id = auth.uid());

-- Admin can view all deletion requests
create policy "Admin can view all deletion requests"
on deletion_requests for select using (get_current_user_role() = 'admin');

-- Admin can update deletion requests (approve/reject)
create policy "Admin can manage deletion requests"
on deletion_requests for all using (get_current_user_role() = 'admin');
