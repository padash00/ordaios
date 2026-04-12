import { NextResponse } from 'next/server'

import { buildVenuePreviewForCustomers, fetchStationsForProject, resolveProjectIdForCompany } from '@/lib/server/client-venues'
import { getRequestCustomerContext } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

export async function GET(request: Request) {
  try {
    const context = await getRequestCustomerContext(request)
    if ('response' in context) return context.response

    if (!hasAdminSupabaseCredentials()) {
      return json({ error: 'client-api-requires-admin-credentials' }, 503)
    }

    const url = new URL(request.url)
    const companyParam = String(url.searchParams.get('company_id') || url.searchParams.get('companyId') || '').trim()
    const venuePreview = url.searchParams.get('venue_preview') === '1' || url.searchParams.get('venuePreview') === '1'

    const admin = createAdminSupabaseClient()

    const { data: customerRows, error: custErr } = await admin
      .from('customers')
      .select('id, company_id, preferred_point_project_id, name')
      .in('id', context.linkedCustomerIds)
      .eq('is_active', true)

    if (custErr) throw custErr
    const rows = (customerRows || []) as {
      id: string
      company_id: string | null
      preferred_point_project_id: string | null
      name: string | null
    }[]

    if (venuePreview) {
      const { venues, mergedStations } = await buildVenuePreviewForCustomers(admin, rows)
      return json({ ok: true, stations: mergedStations, venues, venue_preview: true })
    }

    const pick =
      rows.find((r) => r.company_id && r.company_id === companyParam) ||
      rows.find((r) => r.company_id) ||
      rows[0] ||
      null

    if (!pick?.company_id) {
      return json({ ok: true, stations: [] })
    }

    const companyId = pick.company_id
    const projectId = await resolveProjectIdForCompany(admin, companyId, pick.preferred_point_project_id || null)

    if (!projectId) {
      return json({ ok: true, stations: [] })
    }

    const out = await fetchStationsForProject(admin, companyId, projectId)
    return json({ ok: true, stations: out })
  } catch (error: any) {
    return json({ error: error?.message || 'client-stations-fetch-failed' }, 500)
  }
}
