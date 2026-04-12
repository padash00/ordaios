# Phase 1 Wrap-Up

Текущий статус: **Phase 1 по коду закрыт**.  
Остались только проектные настройки в Xcode для Widget target.

## Done (implemented in code)

- P1 #13: POS/Point polish
  - drill-down quick actions
  - auto-scroll to target form after prefill
  - micro-feedback banner ("поле заполнено")
- P1 #14: Live Activity (активная смена оператора)
  - activity manager
  - auto sync from shifts view model (start/update/end)
- P1 #15: Operator Widget (tasks + shift)
  - widget bridge (shared snapshot)
  - widget UI implementation (`systemMedium`, `systemLarge`)
  - timeline reload trigger from app

## Remaining (Xcode wiring only)

- Add `Widget Extension` target in Xcode (name: `OperatorWidgetExtension`)
- Enable `App Groups` for app target and widget target:
  - `group.com.padash00.orda.client`
- Include files from `OperatorWidgetExtension/` in the widget target

## Smoke Test Checklist

### A) POS/Point quick actions

- Open `POS и Point`
- Tap a KPI tile and use quick action menu
- Verify:
  - selected entity is prefilled in target form
  - list auto-scrolls to target form section
  - success micro-banner appears

### B) Live Activity shift

- Open operator shifts and refresh data
- Ensure at least one active shift exists (`published`/`confirmed`/`pending`)
- Verify:
  - Live Activity appears on lock screen / Dynamic Island
  - changing shifts updates activity content
  - on load error/no active shift activity ends

### C) Widget

- Add widget to Home Screen (`Оператор Orda`)
- Verify:
  - open tasks count is shown
  - top tasks are shown
  - active shift block is shown (or fallback text)
- Refresh operator tasks/shifts inside app and confirm widget updates

## Acceptance Criteria (Phase 1)

- [x] Operator workflow polish in POS/Point complete
- [x] Active shift is surfaced as Live Activity
- [x] Operator overview widget implemented and connected to app data bridge
- [x] Xcode widget target + embed present in repo (`OperatorWidgetExtensionExtension`); App Group — проверить в Signing на своей машине
