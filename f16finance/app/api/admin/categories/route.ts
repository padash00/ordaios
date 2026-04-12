import { NextResponse } from 'next/server'

import { writeSystemErrorLogSafe } from '@/lib/server/audit'
import { createRequestSupabaseClient, getRequestAccessContext } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'

/**
 * Legacy alias for the mobile app (`/api/admin/categories`).
 * Backed by `expense_categories` (same as `/api/admin/expense-categories`).
 */

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

function getSupabase(req: Request) {
  return hasAdminSupabaseCredentials() ? createAdminSupabaseClient() : createRequestSupabaseClient(req)
}

function mapRow(row: { id: string; name: string; accounting_group?: string | null; monthly_budget?: number | null }) {
  return {
    id: row.id,
    name: row.name,
    type: row.accounting_group || 'expense',
    color: null as string | null,
    parent_id: null as string | null,
  }
}

export async function GET(req: Request) {
  try {
    const access = await getRequestAccessContext(req)
    if ('response' in access) return access.response

    const supabase = getSupabase(req)
    const result = await supabase
      .from('expense_categories')
      .select('id, name, accounting_group, monthly_budget')
      .order('name')
    if (result.error) throw result.error
    const rows = (result.data || []) as any[]
    return json({ data: rows.map(mapRow) })
  } catch (error: any) {
    await writeSystemErrorLogSafe({ scope: 'server', area: 'api/admin/categories GET', message: error?.message || 'error' })
    return json({ error: error?.message || 'Ошибка сервера' }, 500)
  }
}

type Body =
  | {
      action: 'createCategory'
      payload: { name: string; type: string; color?: string | null; parent_id?: string | null }
    }
  | {
      action: 'deleteCategory'
      categoryId: string
    }

export async function POST(req: Request) {
  try {
    const access = await getRequestAccessContext(req)
    if ('response' in access) return access.response
    if (!access.isSuperAdmin && access.staffRole !== 'owner') {
      return json({ error: 'forbidden' }, 403)
    }

    const body = (await req.json().catch(() => null)) as Body | null
    if (!body?.action) return json({ error: 'Неверный формат запроса' }, 400)

    const supabase = getSupabase(req)

    if (body.action === 'createCategory') {
      const name = String(body.payload?.name || '').trim()
      if (!name) return json({ error: 'Название категории обязательно' }, 400)
      const accountingGroup = String(body.payload?.type || 'operating').trim() || 'operating'

      const { data, error } = await supabase
        .from('expense_categories')
        .insert([
          {
            name,
            accounting_group: accountingGroup,
            monthly_budget: 0,
          },
        ])
        .select('id, name, accounting_group, monthly_budget')
        .single()
      if (error) throw error
      return json({ ok: true, data: mapRow(data as any) })
    }

    if (body.action === 'deleteCategory') {
      const id = String(body.categoryId || '').trim()
      if (!id) return json({ error: 'categoryId обязателен' }, 400)
      const { error } = await supabase.from('expense_categories').delete().eq('id', id)
      if (error) throw error
      return json({ ok: true })
    }

    return json({ error: 'Неизвестное действие' }, 400)
  } catch (error: any) {
    await writeSystemErrorLogSafe({ scope: 'server', area: 'api/admin/categories POST', message: error?.message || 'error' })
    return json({ error: error?.message || 'Ошибка сервера' }, 500)
  }
}
