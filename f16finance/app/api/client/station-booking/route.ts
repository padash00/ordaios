import { NextResponse } from 'next/server'

import { getRequestCustomerContext } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

export async function POST(request: Request) {
  try {
    const context = await getRequestCustomerContext(request)
    if ('response' in context) return context.response

    const body = (await request.json().catch(() => null)) as {
      station_id?: string
      stationId?: string
      duration_minutes?: number
      durationMinutes?: number
      start_time?: string
      startTime?: string
      company_id?: string
      companyId?: string
    } | null

    const stationId = String(body?.station_id || body?.stationId || '').trim()
    const durationMinutes = Math.max(15, Math.floor(Number(body?.duration_minutes ?? body?.durationMinutes ?? 60)))
    const startRaw = String(body?.start_time || body?.startTime || '').trim()
    const companyHint = String(body?.company_id || body?.companyId || '').trim()

    if (!stationId) return json({ error: 'station-id-required' }, 400)
    if (!startRaw) return json({ error: 'start-time-required' }, 400)

    const startsAt = new Date(startRaw)
    if (Number.isNaN(startsAt.getTime())) return json({ error: 'start-time-invalid' }, 400)

    const endsAt = new Date(startsAt.getTime() + durationMinutes * 60_000)

    if (!hasAdminSupabaseCredentials()) {
      return json({ error: 'client-api-requires-admin-credentials' }, 503)
    }

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
      (companyHint && rows.find((r) => r.company_id === companyHint)) ||
      rows.find((r) => r.company_id) ||
      rows[0] ||
      null

    if (!pick?.id || !pick.company_id) {
      return json({ error: 'customer-company-not-found' }, 400)
    }

    const { data: station, error: stErr } = await admin
      .from('arena_stations')
      .select('id, name, point_project_id, company_id, is_active')
      .eq('id', stationId)
      .maybeSingle()

    if (stErr) throw stErr
    if (!station || station.is_active === false) {
      return json({ error: 'station-not-found' }, 404)
    }

    const stCompany = station.company_id != null ? String(station.company_id) : ''
    if (stCompany && stCompany !== pick.company_id) {
      return json({ error: 'station-company-mismatch' }, 400)
    }

    const stationName = String((station as any).name || 'Станция')
    const notes = `Онлайн-запись: «${stationName}» (station_id=${stationId}, ${durationMinutes} мин.)`

    const { data: booking, error: insErr } = await context.supabase
      .from('client_bookings')
      .insert({
        customer_id: pick.id,
        company_id: pick.company_id,
        starts_at: startsAt.toISOString(),
        ends_at: endsAt.toISOString(),
        status: 'requested',
        notes,
        source: 'client_app_station',
        created_by: context.user?.id || null,
      })
      .select('id, company_id, customer_id, starts_at, ends_at, status, notes, source, created_at, updated_at')
      .single()

    if (insErr) throw insErr

    return json({ ok: true, booking }, 201)
  } catch (error: any) {
    return json({ error: error?.message || 'client-station-booking-failed' }, 500)
  }
}
