import { NextResponse } from 'next/server'

import { buildVenuePreviewForCustomers } from '@/lib/server/client-venues'
import { resolveStorefrontBaseUrl } from '@/lib/server/client-catalog'
import { getRequestCustomerContext } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

/**
 * Станции по всем клубам (customers.company_id) в профиле — для превью зала / мульти-точки.
 * Требует связанного клиента (`getRequestCustomerContext`); без профиля — пустой список и `storefront_url`.
 */
export async function GET(request: Request) {
  const storefront_url = resolveStorefrontBaseUrl(request)

  try {
    if (!hasAdminSupabaseCredentials()) {
      return json(
        {
          ok: false,
          error: 'client-api-requires-admin-credentials',
          venues: [],
          stations: [],
          storefront_url,
        },
        503,
      )
    }

    const context = await getRequestCustomerContext(request)
    if ('response' in context) return context.response

    const admin = createAdminSupabaseClient()

    const { data: customerRows, error: custErr } = await admin
      .from('customers')
      .select('id, name, company_id, preferred_point_project_id')
      .in('id', context.linkedCustomerIds)
      .eq('is_active', true)

    if (custErr) throw custErr

    const rows = (customerRows || []) as {
      id: string
      name: string | null
      company_id: string | null
      preferred_point_project_id: string | null
    }[]

    const { venues, mergedStations } = await buildVenuePreviewForCustomers(admin, rows)

    return json({
      ok: true,
      venues,
      /** Плоский список всех станций по всем клубам (удобно для одной сетки). */
      stations: mergedStations,
      storefront_url,
    })
  } catch (error: any) {
    return json({ error: error?.message || 'venue-preview-failed', venues: [], stations: [], storefront_url }, 500)
  }
}
