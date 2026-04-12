# P0 Module Spec (Contract Lock)

Status: locked from in-repo source of truth only (`f16finance`, `contracts.json`, `screen_to_api_map.json`, `web_routes_catalog.json`).

## 1) Dashboard

- module: `dashboard`
- web routes:
  - `/dashboard`
  - `/analysis`
- api endpoints:
  - `GET /api/auth/session-role`
  - `GET /api/admin/dashboard`
- read flows:
  - load role context
  - load dashboard KPI payload
- write flows:
  - no direct write in contract for `/api/admin/dashboard`
  - analysis actions are route-level in web catalog, not locked as explicit API in current contracts
- roles:
  - `super_admin` (hard)
  - `staff_owner|staff_manager` route presence in web catalog, but dashboard API role gate in contracts is super-admin only
- required UI states:
  - `loading`, `empty`, `error_ru`, `success`
- errors/validation:
  - `401 unauthorized`
  - `403 forbidden`
  - `500 error_extended`

## 2) Finance (Incomes + Expenses)

- module: `finance`
- web routes:
  - `/income`
  - `/expenses`
- api endpoints:
  - `GET /api/admin/incomes`
  - `POST /api/admin/incomes`
  - `GET /api/admin/expenses`
  - `POST /api/admin/expenses`
- read flows:
  - list incomes/expenses
  - apply filters (`date_from`, `date_to`, `company_id`, `category`)
  - sort by date desc (contracted)
- write flows:
  - create income
  - create expense
- roles:
  - `super_admin`
  - `staff_owner`
  - `staff_manager`
  - blocked writes for `staff_marketer|staff_other|operator|customer`
- required UI states:
  - `loading`, `empty`, `error_ru`, `success`, `forbidden_ru`
  - filter/sort/pagination presentation
- errors/validation:
  - `400 validation/domain`
  - `403 forbidden`
  - `500 server`

## 3) Inventory + Store

- module: `inventory-store`
- web routes:
  - `/store`
  - `/store/overview`
  - `/store/requests`
  - `/inventory/*` (legacy route family)
- api endpoints:
  - `GET /api/admin/store/overview`
  - `GET /api/admin/inventory/requests`
  - `POST /api/admin/inventory/requests` (decide request)
  - `GET /api/admin/store/receipts`
  - `POST /api/admin/store/receipts`
  - `GET /api/admin/store/writeoffs`
  - `POST /api/admin/store/writeoffs`
  - `GET /api/admin/store/revisions`
  - `POST /api/admin/store/revisions`
  - `GET /api/admin/store/movements`
  - `GET /api/admin/store/analytics`
- read flows:
  - overview + requests + receipts/writeoffs/revisions/movements/analytics
- write flows:
  - decide inventory request
  - create receipt/writeoff/revision
- roles:
  - `super_admin`
  - `staff_owner`
  - `staff_manager`
- required UI states:
  - `loading`, `empty`, `error_ru`, `success`, `forbidden_ru`
  - filter/sort where mapped
- errors/validation:
  - `400 invalid-action/validation`
  - `403 forbidden`
  - `500 server`

## 4) POS + Point

- module: `pos-point`
- web routes:
  - `/pos`
  - `/point-*`
- api endpoints (POS side):
  - `GET /api/pos/bootstrap`
  - `POST /api/pos/sale`
  - `GET /api/pos/return`
  - `POST /api/pos/return`
- api endpoints (Point side):
  - `GET /api/point/bootstrap`
  - `POST /api/point/shift-report`
  - `POST /api/point/inventory-sales`
  - `POST /api/point/inventory-returns`
  - `POST /api/point/inventory-requests`
  - `GET /api/point/debts`
  - `POST /api/point/debts`
  - `GET /api/point/products`
  - `POST /api/point/products`
- read flows:
  - POS bootstrap and return lookup
  - Point bootstrap, debts list, products list
- write flows:
  - POS sale + return
  - Point shift report + inventory sales + inventory returns + inventory requests + debts + products
- roles:
  - POS: `super_admin|staff_owner|staff_manager`
  - Point: `point_device_session` (contract authority)
- required UI states:
  - `loading`, `empty`, `error_ru`, `success`, `validation_ru`, `forbidden_ru`
- errors/validation:
  - `400 validation/domain`
  - `401 unauthorized` (point token/session)
  - `403 forbidden/feature-gate`
  - `500 server`

## 5) Operator

- module: `operator`
- web routes:
  - `/operator`
  - `/operator/tasks`
  - `/operator/shifts`
  - `/operator/profile`
- api endpoints:
  - `GET /api/operator/tasks`
  - `POST /api/operator/tasks` (`respondTask|addComment`)
  - `GET /api/operator/shifts`
  - `POST /api/operator/shifts` (`confirmWeek|reportIssue`)
- read flows:
  - load own tasks and shifts
- write flows:
  - respond task
  - add comment
  - confirm week
  - report issue
- roles:
  - `operator` only
- required UI states:
  - `loading`, `empty`, `error_ru`, `success`, `forbidden_ru`
- errors/validation:
  - `400 validation`
  - `404 entity-not-found`
  - `401 unauthorized`

## Global constraints for P0

- RU-only user-facing text
- no invented endpoints
- no placeholder/json-dump UI
- envelope-safe decoding required for:
  - `raw`
  - `{ data: ... }`
  - `{ ok: true, data: ... }`
  - domain envelopes
- role gating in UI plus backend 403 fallback
