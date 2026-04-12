import { NextResponse } from 'next/server'

import { getRequestCustomerContext } from '@/lib/server/request-auth'
import { createAdminSupabaseClient, hasAdminSupabaseCredentials } from '@/lib/server/supabase'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

export async function GET(request: Request) {
  try {
    const context = await getRequestCustomerContext(request)
    if ('response' in context) return context.response
    const url = new URL(request.url)
    const limitRaw = Number(url.searchParams.get('limit') || 20)
    const limit = Number.isFinite(limitRaw) ? Math.max(1, Math.min(100, Math.floor(limitRaw))) : 20
    const offsetRaw = Number(url.searchParams.get('offset') || 0)
    const offset = Number.isFinite(offsetRaw) ? Math.max(0, Math.floor(offsetRaw)) : 0

    if (!hasAdminSupabaseCredentials()) {
      return json({ error: 'client-api-requires-admin-credentials' }, 503)
    }

    const supabase = createAdminSupabaseClient()

    const [{ data: customerRows, error: customerError }, { data: salesRows, error: salesError }] = await Promise.all([
      supabase
        .from('customers')
        .select('id, loyalty_points, total_spent, visits_count')
        .in('id', context.linkedCustomerIds)
        .eq('is_active', true),
      supabase
        .from('point_sales')
        .select('id, customer_id, sale_date, loyalty_points_earned, loyalty_points_spent, total_amount')
        .in('customer_id', context.linkedCustomerIds)
        .order('sale_date', { ascending: false })
        .range(offset, offset + limit - 1),
    ])

    if (customerError) throw customerError
    if (salesError) throw salesError

    const totals = (customerRows || []).reduce(
      (acc: { customer_id: string | null; points: number; totalSpent: number; visits: number }, row: any) => {
        acc.points += Number(row?.loyalty_points || 0)
        acc.totalSpent += Number(row?.total_spent || 0)
        acc.visits += Number(row?.visits_count || 0)
        return acc
      },
      { customer_id: context.linkedCustomerIds[0] || null, points: 0, totalSpent: 0, visits: 0 },
    )

    const history = salesRows || []
    return json({
      ok: true,
      summary: totals,
      history,
      hasMore: history.length >= limit,
      nextOffset: history.length >= limit ? offset + history.length : null,
    })
  } catch (error: any) {
    return json({ error: error?.message || 'client-points-fetch-failed' }, 500)
  }
}

export async function POST(request: Request) {
  try {
    const context = await getRequestCustomerContext(request)
    if ('response' in context) return context.response

    if (!hasAdminSupabaseCredentials()) {
      return json({ error: 'client-api-requires-admin-credentials' }, 503)
    }

    const body = (await request.json().catch(() => null)) as
      | {
          action?: 'redeemReward'
          rewardId?: string
          rewardTitle?: string
          pointsCost?: number
          minTierKey?: 'silver' | 'gold' | 'platinum' | string
        }
      | null

    if (body?.action !== 'redeemReward') {
      return json({ error: 'unsupported-action' }, 400)
    }

    const rewardId = String(body.rewardId || '').trim()
    const rewardTitle = String(body.rewardTitle || '').trim()
    const pointsCost = Math.max(0, Math.floor(Number(body.pointsCost || 0)))
    const minTierKey = String(body.minTierKey || '').trim().toLowerCase()

    if (!rewardId || !rewardTitle || !pointsCost || !minTierKey) {
      return json({ error: 'redeem-payload-invalid' }, 400)
    }

    const tierMinPoints: Record<string, number> = {
      silver: 0,
      gold: 500,
      platinum: 2000,
    }

    if (!(minTierKey in tierMinPoints)) {
      return json({ error: 'redeem-tier-invalid' }, 400)
    }

    const targetCustomerId = context.linkedCustomerIds[0] || null
    if (!targetCustomerId) return json({ error: 'customer-not-linked' }, 403)

    const supabase = createAdminSupabaseClient()
    const { data: customerRow, error: customerError } = await supabase
      .from('customers')
      .select('id, loyalty_points, total_spent, visits_count, is_active')
      .eq('id', targetCustomerId)
      .maybeSingle()

    if (customerError) throw customerError
    if (!customerRow?.id || customerRow.is_active === false) return json({ error: 'customer-not-found' }, 404)

    const currentPoints = Number(customerRow.loyalty_points || 0)
    if (currentPoints < pointsCost) return json({ error: 'not-enough-points' }, 400)
    if (currentPoints < tierMinPoints[minTierKey]) return json({ error: 'tier-access-denied' }, 403)

    const nextPoints = Math.max(0, currentPoints - pointsCost)
    const nowIso = new Date().toISOString()

    const { error: updateError } = await supabase
      .from('customers')
      .update({ loyalty_points: nextPoints, updated_at: nowIso })
      .eq('id', customerRow.id)

    if (updateError) throw updateError

    const { data: redemptionRow, error: redemptionError } = await supabase
      .from('point_sales')
      .insert({
        customer_id: customerRow.id,
        sale_date: nowIso,
        loyalty_points_earned: 0,
        loyalty_points_spent: pointsCost,
        total_amount: 0,
        source: 'client_app_redeem',
        notes: `reward:${rewardId}:${rewardTitle}`,
      })
      .select('id, customer_id, sale_date, loyalty_points_earned, loyalty_points_spent, total_amount')
      .maybeSingle()

    if (redemptionError) {
      await supabase
        .from('customers')
        .update({ loyalty_points: currentPoints, updated_at: new Date().toISOString() })
        .eq('id', customerRow.id)
      throw redemptionError
    }

    return json({
      ok: true,
      summary: {
        customer_id: customerRow.id,
        points: nextPoints,
        totalSpent: Number(customerRow.total_spent || 0),
        visits: Number(customerRow.visits_count || 0),
      },
      redemption: redemptionRow || null,
    })
  } catch (error: any) {
    return json({ error: error?.message || 'client-points-redeem-failed' }, 500)
  }
}
