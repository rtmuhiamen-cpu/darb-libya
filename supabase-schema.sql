-- Optional production starting schema. Review and test RLS before public launch.
create extension if not exists pgcrypto;
create table if not exists public.traffic_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  report_type text not null check (report_type in ('congestion','accident','road_closed','flooding','broken_vehicle')),
  location geography(point, 4326) not null,
  note text check (char_length(note) <= 180),
  status text not null default 'pending' check (status in ('pending','confirmed','rejected','expired')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '2 hours',
  verified_at timestamptz,
  source text not null default 'user'
);
create index if not exists traffic_reports_location_idx on public.traffic_reports using gist(location);
create index if not exists traffic_reports_status_expires_idx on public.traffic_reports(status, expires_at desc);
alter table public.traffic_reports enable row level security;
-- Authenticated users can submit reports attributed to themselves; moderation should be server-side.
create policy "authenticated users submit reports" on public.traffic_reports
 for insert to authenticated with check (auth.uid() = user_id and status = 'pending');
-- Do not enable public reads until an RPC/view only exposes safe, confirmed, unexpired reports.
