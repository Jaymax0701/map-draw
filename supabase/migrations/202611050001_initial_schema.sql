-- Map Draw foundation schema
-- Apply with Supabase CLI after linking a dedicated Map Draw Supabase project.
-- All project data is scoped by project membership or organisation administration.

create extension if not exists postgis with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','member')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  status text not null default 'active' check (status in ('active','archived')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug),
  unique (id, organization_id)
);

create table if not exists public.project_members (
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('manager','gis_editor','editor','viewer')),
  created_at timestamptz not null default now(),
  primary key (project_id, user_id)
);

create table if not exists public.map_layers (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text not null,
  layer_type text not null check (layer_type in ('point','line','polygon','raster','other')),
  style jsonb not null default '{}'::jsonb,
  is_visible boolean not null default true,
  sort_order integer not null default 0,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.map_features (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  layer_id uuid references public.map_layers(id) on delete set null,
  name text,
  properties jsonb not null default '{}'::jsonb,
  geom extensions.geometry(Geometry, 4326) not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.measurements (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  name text,
  measurement_type text not null check (measurement_type in ('distance','area','perimeter')),
  value numeric not null,
  unit text not null,
  geom extensions.geometry(Geometry, 4326) not null,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  file_name text not null,
  storage_path text not null,
  content_type text,
  file_size bigint,
  category text,
  uploaded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (project_id, storage_path)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'todo' check (status in ('todo','in_progress','blocked','done')),
  assigned_to uuid references auth.users(id) on delete set null,
  due_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id bigint generated always as identity primary key,
  project_id uuid references public.projects(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (project_id is not null or organization_id is not null)
);

create index if not exists projects_org_idx on public.projects(organization_id);
create index if not exists project_members_user_idx on public.project_members(user_id);
create index if not exists map_layers_project_idx on public.map_layers(project_id);
create index if not exists map_features_project_idx on public.map_features(project_id);
create index if not exists map_features_geom_idx on public.map_features using gist(geom);
create index if not exists measurements_project_idx on public.measurements(project_id);
create index if not exists measurements_geom_idx on public.measurements using gist(geom);
create index if not exists documents_project_idx on public.documents(project_id);
create index if not exists tasks_project_idx on public.tasks(project_id);
create index if not exists activity_logs_project_idx on public.activity_logs(project_id, created_at desc);

-- Security-definer helpers avoid recursive RLS checks on membership tables.
create or replace function public.is_org_member(p_org_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = p_org_id and m.user_id = (select auth.uid())
  );
$$;

create or replace function public.has_org_role(p_org_id uuid, p_roles text[])
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = p_org_id
      and m.user_id = (select auth.uid())
      and m.role = any(p_roles)
  );
$$;

create or replace function public.is_project_member(p_project_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.project_members pm
    where pm.project_id = p_project_id and pm.user_id = (select auth.uid())
  );
$$;

create or replace function public.can_access_project(p_project_id uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = p_project_id
      and (
        public.has_org_role(p.organization_id, array['owner','admin']::text[])
        or public.is_project_member(p.id)
      )
  );
$$;

-- Create an organisation and its first owner atomically.
create or replace function public.create_organization(p_name text, p_slug text)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  new_org_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if length(trim(coalesce(p_name, ''))) < 2 then
    raise exception 'Organisation name must contain at least 2 characters';
  end if;
  if p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'Slug must contain lowercase letters, numbers and hyphens';
  end if;

  insert into public.organizations(name, slug, created_by)
  values (trim(p_name), p_slug, auth.uid())
  returning id into new_org_id;

  insert into public.organization_members(organization_id, user_id, role)
  values (new_org_id, auth.uid(), 'owner');

  return new_org_id;
end;
$$;

-- Keep a profile row for every newly registered Auth user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles(id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

grant execute on function public.create_organization(text, text) to authenticated;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid, text[]) to authenticated;
grant execute on function public.is_project_member(uuid) to authenticated;
grant execute on function public.can_access_project(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.map_layers enable row level security;
alter table public.map_features enable row level security;
alter table public.measurements enable row level security;
alter table public.documents enable row level security;
alter table public.tasks enable row level security;
alter table public.activity_logs enable row level security;

create policy "profiles_select_self" on public.profiles
for select to authenticated using (id = (select auth.uid()));
create policy "profiles_update_self" on public.profiles
for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "organizations_select_members" on public.organizations
for select to authenticated using (public.is_org_member(id));
create policy "organizations_update_admins" on public.organizations
for update to authenticated using (public.has_org_role(id, array['owner','admin']::text[]))
with check (public.has_org_role(id, array['owner','admin']::text[]));

create policy "org_members_select_scoped" on public.organization_members
for select to authenticated using (
  user_id = (select auth.uid()) or public.has_org_role(organization_id, array['owner','admin']::text[])
);
create policy "org_members_insert_admins" on public.organization_members
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner','admin']::text[])
);
create policy "org_members_update_admins" on public.organization_members
for update to authenticated using (
  public.has_org_role(organization_id, array['owner','admin']::text[])
) with check (
  public.has_org_role(organization_id, array['owner','admin']::text[])
);
create policy "org_members_delete_admins" on public.organization_members
for delete to authenticated using (
  public.has_org_role(organization_id, array['owner','admin']::text[])
  and role <> 'owner'
);

create policy "projects_select_members" on public.projects
for select to authenticated using (public.can_access_project(id));
create policy "projects_insert_org_admins" on public.projects
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner','admin']::text[])
  and created_by = (select auth.uid())
);
create policy "projects_update_org_admins" on public.projects
for update to authenticated using (
  public.has_org_role(organization_id, array['owner','admin']::text[])
) with check (
  public.has_org_role(organization_id, array['owner','admin']::text[])
);
create policy "projects_delete_org_admins" on public.projects
for delete to authenticated using (
  public.has_org_role(organization_id, array['owner','admin']::text[])
);

create policy "project_members_select_scoped" on public.project_members
for select to authenticated using (
  user_id = (select auth.uid()) or public.can_access_project(project_id)
);
create policy "project_members_insert_managers" on public.project_members
for insert to authenticated with check (
  exists (
    select 1 from public.projects p
    where p.id = project_id
      and (
        public.has_org_role(p.organization_id, array['owner','admin']::text[])
        or exists (
          select 1 from public.project_members pm
          where pm.project_id = p.id and pm.user_id = (select auth.uid()) and pm.role = 'manager'
        )
      )
    )
);
create policy "project_members_delete_managers" on public.project_members
for delete to authenticated using (
  exists (
    select 1 from public.projects p
    where p.id = project_id
      and (
        public.has_org_role(p.organization_id, array['owner','admin']::text[])
        or exists (
          select 1 from public.project_members pm
          where pm.project_id = p.id and pm.user_id = (select auth.uid()) and pm.role = 'manager'
        )
      )
    ) and role <> 'manager'
);

-- Project-scoped data: organisation admins/owners and explicit project members only.
create policy "map_layers_project_access" on public.map_layers
for all to authenticated using (public.can_access_project(project_id))
with check (public.can_access_project(project_id) and created_by = (select auth.uid()));

create policy "map_features_project_access" on public.map_features
for all to authenticated using (public.can_access_project(project_id))
with check (public.can_access_project(project_id) and created_by = (select auth.uid()));

create policy "measurements_project_access" on public.measurements
for all to authenticated using (public.can_access_project(project_id))
with check (public.can_access_project(project_id) and created_by = (select auth.uid()));

create policy "documents_project_access" on public.documents
for all to authenticated using (public.can_access_project(project_id))
with check (public.can_access_project(project_id) and uploaded_by = (select auth.uid()));

create policy "tasks_project_access" on public.tasks
for all to authenticated using (public.can_access_project(project_id))
with check (public.can_access_project(project_id) and created_by = (select auth.uid()));

create policy "activity_logs_select_scoped" on public.activity_logs
for select to authenticated using (
  (project_id is not null and public.can_access_project(project_id))
  or (organization_id is not null and public.is_org_member(organization_id))
);
create policy "activity_logs_insert_scoped" on public.activity_logs
for insert to authenticated with check (
  actor_id = (select auth.uid())
  and (
    (project_id is not null and public.can_access_project(project_id))
    or (organization_id is not null and public.is_org_member(organization_id))
  )
);

-- Private document storage bucket. Object paths must begin with the project UUID.
insert into storage.buckets(id, name, public)
values ('project-documents', 'project-documents', false)
on conflict (id) do nothing;

create policy "project_documents_read" on storage.objects
for select to authenticated using (
  bucket_id = 'project-documents'
  and public.can_access_project(((storage.foldername(name))[1])::uuid)
);
create policy "project_documents_upload" on storage.objects
for insert to authenticated with check (
  bucket_id = 'project-documents'
  and public.can_access_project(((storage.foldername(name))[1])::uuid)
);
create policy "project_documents_delete" on storage.objects
for delete to authenticated using (
  bucket_id = 'project-documents'
  and public.can_access_project(((storage.foldername(name))[1])::uuid)
);
