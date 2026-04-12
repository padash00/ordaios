import { NextResponse } from 'next/server'

import { createRequestSupabaseClient, getRequestUser } from '@/lib/server/request-auth'

function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status })
}

type Body = {
  deviceToken?: string
  bundleId?: string | null
}

export async function POST(request: Request) {
  try {
    const user = await getRequestUser(request)
    if (!user) {
      return json({ error: 'unauthorized' }, 401)
    }

    const raw = (await request.json().catch(() => null)) as Body | null
    const deviceToken = typeof raw?.deviceToken === 'string' ? raw.deviceToken.trim().replace(/\s+/g, '') : ''
    if (deviceToken.length < 32 || !/^[0-9a-f]+$/i.test(deviceToken)) {
      return json({ error: 'invalid-device-token' }, 400)
    }

    const bundleId =
      typeof raw?.bundleId === 'string' && raw.bundleId.length > 0 ? raw.bundleId.slice(0, 240) : null

    const supabase = createRequestSupabaseClient(request)
    const { error } = await supabase.from('device_push_tokens').upsert(
      {
        user_id: user.id,
        device_token: deviceToken.toLowerCase(),
        platform: 'ios',
        app_bundle_id: bundleId,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,device_token' },
    )

    if (error) {
      return json({ error: error.message || 'push-token-upsert-failed' }, 500)
    }

    return json({ ok: true })
  } catch (error: any) {
    return json({ error: error?.message || 'push-token-failed' }, 500)
  }
}
