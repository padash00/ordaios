import 'server-only'

export type StationOut = {
  id: string
  number: number
  name: string | null
  status: string
  session_minutes_left: number | null
  company_id: string | null
  grid_x: number | null
  grid_y: number | null
}

function mapStationRows(
  stations: any[] | null,
  sessions: any[] | null,
  fallbackCompanyId: string,
): StationOut[] {
  const now = Date.now()
  const activeByStation = new Map<string, { ends: number }>()
  for (const s of sessions || []) {
    const sid = String((s as any).station_id || '')
    if (!sid) continue
    const endsAt = new Date(String((s as any).ends_at || '')).getTime()
    if (Number.isNaN(endsAt)) continue
    activeByStation.set(sid, { ends: endsAt })
  }

  return (stations || []).map((st: any) => {
    const id = String(st.id || '')
    const sess = activeByStation.get(id)
    const busy = Boolean(sess && sess.ends > now)
    const minutesLeft = busy && sess ? Math.max(0, Math.ceil((sess.ends - now) / 60_000)) : null
    return {
      id,
      number: Number.isFinite(Number(st.order_index)) ? Number(st.order_index) : 0,
      name: st.name != null ? String(st.name) : null,
      status: busy ? 'busy' : 'free',
      session_minutes_left: minutesLeft,
      company_id: st.company_id != null ? String(st.company_id) : fallbackCompanyId,
      grid_x: st.grid_x != null ? Number(st.grid_x) : null,
      grid_y: st.grid_y != null ? Number(st.grid_y) : null,
    }
  })
}

export async function resolveProjectIdForCompany(admin: any, companyId: string, preferredProjectId: string | null) {
  if (preferredProjectId) return preferredProjectId
  const { data: stProbe } = await admin
    .from('arena_stations')
    .select('point_project_id')
    .eq('is_active', true)
    .or(`company_id.eq.${companyId},company_id.is.null`)
    .limit(1)
    .maybeSingle()
  return (stProbe as any)?.point_project_id ? String((stProbe as any).point_project_id) : null
}

export async function fetchStationsForProject(admin: any, companyId: string, projectId: string): Promise<StationOut[]> {
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
  return mapStationRows(stations, sessions, companyId)
}

export type CustomerStationContext = {
  id: string
  company_id: string | null
  preferred_point_project_id: string | null
  name?: string | null
}

function venueLabel(row: CustomerStationContext, companyId: string) {
  const n = row.name?.trim()
  if (n) return n
  return `Клуб · ${companyId.slice(0, 8)}…`
}

export async function buildVenuePreviewForCustomers(admin: any, rows: CustomerStationContext[]) {
  const venues: { company_id: string; label: string; stations: StationOut[] }[] = []
  const seenCompany = new Set<string>()

  for (const row of rows) {
    const companyId = row.company_id ? String(row.company_id) : ''
    if (!companyId || seenCompany.has(companyId)) continue
    seenCompany.add(companyId)

    const projectId = await resolveProjectIdForCompany(admin, companyId, row.preferred_point_project_id || null)
    if (!projectId) {
      venues.push({
        company_id: companyId,
        label: venueLabel(row, companyId),
        stations: [],
      })
      continue
    }

    const stations = await fetchStationsForProject(admin, companyId, projectId)
    venues.push({
      company_id: companyId,
      label: venueLabel(row, companyId),
      stations,
    })
  }

  const merged = venues.flatMap((v) => v.stations)
  return { venues, mergedStations: merged }
}
