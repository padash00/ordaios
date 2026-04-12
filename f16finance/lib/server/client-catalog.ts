import 'server-only'

/** Публичная витрина для гостей и подсказки в приложении (приоритет сверху вниз). */
export function resolveStorefrontBaseUrl(request: Request): string {
  const fromEnv =
    process.env.ORDA_STOREFRONT_URL?.trim() ||
    process.env.NEXT_PUBLIC_STOREFRONT_URL?.trim() ||
    process.env.NEXT_PUBLIC_SITE_URL?.trim() ||
    ''
  if (fromEnv) return fromEnv.replace(/\/$/, '')
  try {
    const u = new URL(request.url)
    return `${u.protocol}//${u.host}`.replace(/\/$/, '')
  } catch {
    return ''
  }
}

export type ClientCatalogRow = {
  id: string
  name: string
  price: number
  category_name: string | null
  image_url: string | null
  description: string | null
}

export async function companyIdsForOrganization(admin: any, organizationId: string): Promise<string[]> {
  const { data, error } = await admin.from('companies').select('id').eq('organization_id', organizationId)
  if (error) throw error
  return ((data || []) as { id: string }[]).map((r) => String(r.id)).filter(Boolean)
}

export async function fetchPointProductsAsCatalog(admin: any, companyIds: string[]): Promise<ClientCatalogRow[]> {
  if (!companyIds.length) return []
  const { data, error } = await admin
    .from('point_products')
    .select('id, company_id, name, barcode, price')
    .in('company_id', companyIds)
    .eq('is_active', true)
    .order('name', { ascending: true })

  if (error) throw error

  return (data || []).map((row: any) => ({
    id: String(row.id || ''),
    name: String(row.name || '').trim() || 'Товар',
    price: Math.max(0, Number(row.price || 0)),
    category_name: 'Товары',
    image_url: null,
    description: row.barcode ? `Артикул: ${String(row.barcode)}` : null,
  }))
}
