# Operator Widget Extension

This folder contains a ready widget implementation for operator tasks + active shift.

## Xcode setup (one-time)

1. Add new target: `File` -> `New` -> `Target` -> `Widget Extension`.
2. Name target `OperatorWidgetExtension`.
3. Replace generated Swift files with:
   - `OperatorWidgetExtensionBundle.swift`
   - `OperatorOverviewWidget.swift`
4. In **Signing & Capabilities** for both app target and widget target:
   - Add `App Groups`
   - Enable: `group.com.padash00.orda.client`
5. Build and add widget on device/simulator.

## Data flow

- App writes snapshot via `OperatorWidgetBridge`:
  - open tasks count
  - top tasks
  - active shift
- Widget reads JSON snapshot from:
  - suite: `group.com.padash00.orda.client`
  - key: `operator.widget.snapshot.v1`
