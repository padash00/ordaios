import { NextResponse } from 'next/server'

import { fetchPointProductsAsCatalog, companyIdsForOrganization, resolveStorefrontBaseUrl } from '@/lib/server/client-catalog'
import { getRequestAccessContext, getRequestUser } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'
import { resolveDefaultOrganization } from '@/lib/server/tenant-hosts'
import { resolveEffectiveOrganizationId } from '@/lib/server/organizations'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

export async function GET(request: Request) {
  const storefront_url = resolveStorefrontBaseUrl(request)

  try {
    if (!hasAdminSupabaseCredentials()) {
      return json(
        {
          ok: false,
          error: 'client-api-requires-admin-credentials',
          items: [],
          storefront_url,
          guest: true,
        },
        503,
      )
    }

    const admin = createAdminSupabaseClient()
    const user = await getRequestUser(request)

    /** Гость: без сессии — только публичная витрина по дефолтной организации (single-tenant). */
    if (!user) {
      const defaultOrg = await resolveDefaultOrganization()
      const orgId = defaultOrg?.id || null
      let companyIds: string[] = []
      if (orgId) {
        companyIds = await companyIdsForOrganization(admin, orgId)
      }
      const items = await fetchPointProductsAsCatalog(admin, companyIds)
      return json({ ok: true, items, guest: true, storefront_url })
    }

    const ctx = await getRequestAccessContext(request, { allowCustomer: true })
    if ('response' in ctx) return ctx.response

    if (!ctx.isCustomer) {
      return json({ error: 'forbidden', items: [], storefront_url }, 403)
    }

    const linkedCompanies = [
      ...new Set(ctx.linkedCustomers.map((c) => c.company_id).filter((id): id is string => Boolean(id))),
    ]

    let companyIds: string[] = []

    if (linkedCompanies.length) {
      companyIds = linkedCompanies
    } else {
      const browseOrgId =
        ctx.activeOrganization?.id ||
        (await resolveDefaultOrganization())?.id ||
        (await resolveEffectiveOrganizationId({ supabase: admin, activeOrganizationId: null }))
      if (browseOrgId) {
        companyIds = await companyIdsForOrganization(admin, browseOrgId)
      }
    }

    const items = await fetchPointProductsAsCatalog(admin, companyIds)
    return json({ ok: true, items, guest: false, storefront_url })
  } catch (error: any) {
    return json(
      {
        ok: false,
        error: error?.message || 'client-catalog-failed',
        items: [],
        storefront_url,
      },
      500,
    )
  }
}
