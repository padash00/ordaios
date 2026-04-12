# Клиентский каталог, превью зала и витрина

## `GET /api/client/catalog`

- **Без авторизации (гость):** отдаёт активные позиции из `point_products` для всех `companies`, привязанных к **дефолтной организации** (`DEFAULT_ORGANIZATION_SLUG`, см. `lib/server/tenant-hosts.ts`). Подходит для публичной витрины в single-tenant.
- **С авторизацией, контур клиента** (`getRequestAccessContext` с `allowCustomer: true`, `isCustomer`): товары по всем `company_id` из связанных строк `customers`; если профиля клиента ещё нет (подтверждённый email, «просмотр»), используется активная/дефолтная организация и её компании.

Ответ (JSON):

```json
{
  "ok": true,
  "items": [
    {
      "id": "uuid",
      "name": "…",
      "price": 1500,
      "category_name": "Товары",
      "image_url": null,
      "description": "Артикул: …"
    }
  ],
  "guest": true,
  "storefront_url": "https://example.com"
}
```

Поле **`storefront_url`** (приоритет):

1. `ORDA_STOREFRONT_URL`
2. `NEXT_PUBLIC_STOREFRONT_URL`
3. `NEXT_PUBLIC_SITE_URL`
4. Иначе origin запроса (`https://host`)

На сервере для выборки товаров нужен **service role** (`hasAdminSupabaseCredentials()`), иначе HTTP **503** с `error: client-api-requires-admin-credentials`.

## Официальный URL витрины (документация для продукта)

Задайте явный URL в окружении Vercel / Supabase Edge / `.env`:

- **`ORDA_STOREFRONT_URL`** — предпочтительно для серверных ответов.
- **`NEXT_PUBLIC_STOREFRONT_URL`** или **`NEXT_PUBLIC_SITE_URL`** — если уже используются для сайта.

В iOS: ключ **`STOREFRONT_URL`** в Info.plist / xcconfig (см. `AppConfig.storefrontURL`) — резерв, если в JSON нет `storefront_url` или каталог пуст.

## Превью станций по всем клубам профиля

### `GET /api/client/venue-preview`

Требует **`getRequestCustomerContext`** (есть хотя бы один связанный `customers` в аккаунте).

Возвращает:

- **`venues`**: массив `{ company_id, label, stations[] }` — по одному блоку на каждую уникальную компанию в профиле.
- **`stations`**: плоский список всех станций по всем клубам.
- **`storefront_url`**: как у каталога.

### `GET /api/client/stations?venue_preview=1`

Тот же состав **`venues`** + **`stations`** + `venue_preview: true`, без отдельного пути (удобно, если клиент уже дергает `/stations`).

Одиночный режим (без `venue_preview`) — как раньше: одна выбранная компания и `?company_id=`.

## Миграция RLS: `client_support_tickets`

Файл: `supabase/migrations/20260413_client_booking_support_rls_customer_company.sql`.

**Проверить, что применена на Supabase:**

```bash
cd f16finance
npx supabase db push
```

Или в **SQL Editor** выполнить содержимое файла миграции вручную.

После применения политика `INSERT` для клиентов допускает строку, если `customers.company_id` совпадает с вставляемым `company_id` (а не только `can_access_company` через `organization_members`).
