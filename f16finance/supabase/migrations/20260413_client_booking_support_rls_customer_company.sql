-- Clients are not organization_members, so can_access_company(company_id) was always false
-- for authenticated customers. Allow inserts when the row's company_id matches the
-- customer's own company (same auth user).

create or replace function public.customer_company_matches_row(target_customer_id uuid, target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.customers c
    where c.id = target_customer_id
      and c.auth_user_id = auth.uid()
      and c.is_active = true
      and c.company_id is not null
      and c.company_id = target_company_id
  )
$$;

drop policy if exists client_bookings_customer_insert on public.client_bookings;
create policy client_bookings_customer_insert
on public.client_bookings
for insert
to authenticated
with check (
  public.customer_link_matches_auth(customer_id)
  and company_id is not null
  and (
    public.can_access_company(company_id)
    or public.customer_company_matches_row(customer_id, company_id)
  )
);

drop policy if exists client_support_tickets_customer_insert on public.client_support_tickets;
create policy client_support_tickets_customer_insert
on public.client_support_tickets
for insert
to authenticated
with check (
  public.customer_link_matches_auth(customer_id)
  and company_id is not null
  and (
    public.can_access_company(company_id)
    or public.customer_company_matches_row(customer_id, company_id)
  )
);

drop policy if exists client_notification_outbox_customer_insert on public.client_notification_outbox;
create policy client_notification_outbox_customer_insert
on public.client_notification_outbox
for insert
to authenticated
with check (public.customer_link_matches_auth(customer_id));
