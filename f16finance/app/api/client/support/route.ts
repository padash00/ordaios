import { NextResponse } from 'next/server'

import { getRequestCustomerContext } from '@/lib/server/request-auth'

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

    const { data, error } = await context.supabase
      .from('client_support_tickets')
      .select('id, customer_id, company_id, subject, message, status, priority, created_at, updated_at, resolved_at')
      .in('customer_id', context.linkedCustomerIds)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (error) throw error

    const rows = data || []
    return json({
      ok: true,
      requests: rows,
      hasMore: rows.length >= limit,
      nextOffset: rows.length >= limit ? offset + rows.length : null,
    })
  } catch (error: any) {
    return json({ error: error?.message || 'client-support-fetch-failed' }, 500)
  }
}

export async function POST(request: Request) {
  try {
    const context = await getRequestCustomerContext(request)
    if ('response' in context) return context.response

    const body = (await request.json().catch(() => null)) as { message?: string; companyId?: string; company_id?: string } | null
    const message = String(body?.message || '').trim()
    const companyHint = String(body?.companyId || body?.company_id || '').trim()

    if (!message) return json({ error: 'message-required' }, 400)
    if (message.length > 2000) return json({ error: 'message-too-long' }, 400)

    if (!context.linkedCustomerIds.length) {
      return json({ error: 'customer-not-linked' }, 403)
    }

    let targetCustomerId: string | null = null
    if (companyHint) {
      const { data: matchRows, error: matchErr } = await context.supabase
        .from('customers')
        .select('id, company_id')
        .in('id', context.linkedCustomerIds)
        .eq('company_id', companyHint)
        .eq('is_active', true)
        .limit(1)
      if (matchErr) throw matchErr
      const hit = (matchRows || [])[0] as { id: string } | undefined
      if (!hit?.id) {
        return json({ error: 'company-not-in-profile' }, 400)
      }
      targetCustomerId = hit.id
    } else {
      targetCustomerId = context.linkedCustomerIds[0] || null
    }

    const { data: customerRow, error: customerError } = await context.supabase
      .from('customers')
      .select('id, company_id')
      .eq('id', targetCustomerId || '')
      .maybeSingle()

    if (customerError) throw customerError
    if (!customerRow?.company_id) {
      return json({ error: 'customer-company-not-found' }, 400)
    }

    const { data: ticket, error: ticketError } = await context.supabase
      .from('client_support_tickets')
      .insert({
        customer_id: targetCustomerId,
        company_id: customerRow.company_id,
        message,
        status: 'new',
        priority: 'normal',
        created_by: context.user?.id || null,
      })
      .select('id, customer_id, company_id, message, status, priority, created_at')
      .single()

    if (ticketError) throw ticketError

    const { error: outboxError } = await context.supabase.from('client_notification_outbox').insert({
      customer_id: targetCustomerId,
      ticket_id: ticket.id,
      channel: 'in_app',
      status: 'pending',
      payload: {
        kind: 'client_support_created',
        ticketId: ticket.id,
      },
    })
    if (outboxError) throw outboxError

    return json({ ok: true, ticket })
  } catch (error: any) {
    return json({ error: error?.message || 'client-support-send-failed' }, 500)
  }
}
