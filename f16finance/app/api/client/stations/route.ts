import { NextResponse } from 'next/server'

import { getRequestCustomerContext } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

type StationOut = {
  id: string
  number: number
  name: string | null
  status: string
  session_minutes_left: number | null
  company_id: string | null
  grid_x: number | null
  grid_y: number | null
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

    const admin = createAdminSupabaseClient()

    const { data: customerRows, error: custErr } = await admin
      .from('customers')
      .select('id, company_id, preferred_point_project_id')
      .in('id', context.linkedCustomerIds)
      .eq('is_active', true)

    if (custErr) throw custErr
    const rows = (customerRows || []) as {
      id: string
      company_id: string | null
      preferred_point_project_id: string | null
    }[]

    const pick =
      rows.find((r) => r.company_id && r.company_id === companyParam) ||
      rows.find((r) => r.company_id) ||
      rows[0] ||
      null

    if (!pick?.company_id) {
      return json({ ok: true, stations: [] as StationOut[] })
    }

    let projectId = pick.preferred_point_project_id || null

    if (!projectId) {
      const { data: stProbe } = await admin
        .from('arena_stations')
        .select('point_project_id')
        .eq('is_active', true)
        .or(`company_id.eq.${pick.company_id},company_id.is.null`)
        .limit(1)
        .maybeSingle()
      projectId = (stProbe as any)?.point_project_id || null
    }

    if (!projectId) {
      return json({ ok: true, stations: [] as StationOut[] })
    }

    const companyId = pick.company_id

    const [{ data: stations, error: stError }, { data: sessions, error: sessError }] = await Promise.all([
      admin
        .from('arena_stations')
        .select('id, name, order_index, company_id, grid_x, grid_y')
        .eq('point_project_id', projectId)
        .eq('is_active', true)
        .or(`company_id.eq.${companyId},company_id.is.null`)
        .order('order_index')
        .order('name'),
      admin
        .from('arena_sessions')
        .select('id, station_id, ends_at, status')
        .eq('point_project_id', projectId)
        .eq('status', 'active'),
    ])

    if (stError) throw stError
    if (sessError) throw sessError

    const now = Date.now()
    const activeByStation = new Map<string, { ends: number }>()
    for (const s of sessions || []) {
      const sid = String((s as any).station_id || '')
      if (!sid) continue
      const endsAt = new Date(String((s as any).ends_at || '')).getTime()
      if (Number.isNaN(endsAt)) continue
      activeByStation.set(sid, { ends: endsAt })
    }

    const out: StationOut[] = (stations || []).map((st: any) => {
      const id = String(st.id || '')
      const sess = activeByStation.get(id)
      const busy = Boolean(sess && sess.ends > now)
      const minutesLeft =
        busy && sess ? Math.max(0, Math.ceil((sess.ends - now) / 60_000)) : null
      return {
        id,
        number: Number.isFinite(Number(st.order_index)) ? Number(st.order_index) : 0,
        name: st.name != null ? String(st.name) : null,
        status: busy ? 'busy' : 'free',
        session_minutes_left: minutesLeft,
        company_id: st.company_id != null ? String(st.company_id) : companyId,
        grid_x: st.grid_x != null ? Number(st.grid_x) : null,
        grid_y: st.grid_y != null ? Number(st.grid_y) : null,
      }
    })

    return json({ ok: true, stations: out })
  } catch (error: any) {
    return json({ error: error?.message || 'client-stations-fetch-failed' }, 500)
  }
}
