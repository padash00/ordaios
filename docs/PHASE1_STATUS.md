# Фаза 1 — Статус выполнения

## F1.1 — Widget Xcode Target ✅ ПОДКЛЮЧЁН (по `project.pbxproj`)

В репозитории зафиксировано:

- Target **`OperatorWidgetExtensionExtension`** (`com.apple.product-type.app-extension`), продукт `OperatorWidgetExtensionExtension.appex`
- В основном приложении **`Orda Control`**: фаза **Embed Foundation Extensions** встраивает appex; есть **target dependency** на виджет
- Папка **`OperatorWidgetExtension/`** привязана к виджету через **File System Synchronized** (исходники виджета не смешаны с таргетом приложения)
- `OperatorWidgetExtension/Info.plist`: **`NSExtensionPointIdentifier` = `com.apple.widgetkit-extension`**
- `WidgetKit` + `SwiftUI` в **Frameworks** виджета

**App Groups** в git не видны (нет закоммиченных `.entitlements`) — capability обычно живёт в Xcode/подписи. Если на устройстве виджет читает данные из `group.com.padash00.orda.client`, всё ок.

Историческая инструкция «как подключать с нуля»:

### Шаг 1 — Создать Widget Extension Target
```
Xcode → File → New → Target
→ Выбрать: Widget Extension
→ Product Name: OperatorWidgetExtension
→ Bundle Identifier: com.padash00.orda.widget
→ Include Configuration App Intent: НЕТ (снять галку)
→ Finish
```

### Шаг 2 — Удалить автосгенерированные файлы
```
Xcode создаст новые пустые файлы виджета.
Удалить их (Move to Trash):
- OperatorWidgetExtension.swift (автосгенерированный)
- OperatorWidgetExtensionBundle.swift (автосгенерированный)
```

### Шаг 3 — Добавить существующие файлы в target
```
В Project Navigator найти папку OperatorWidgetExtension/.
Выбрать оба файла:
- OperatorOverviewWidget.swift
- OperatorWidgetExtensionBundle.swift

Для каждого файла:
File Inspector (правая панель) → Target Membership
→ Поставить галку: OperatorWidgetExtension
→ СНЯТЬ галку: Orda Control (основной app)
```

### Шаг 4 — App Groups (КРИТИЧНО)
```
В Project Navigator → Orda Control проект → Targets

1. Выбрать target: Orda Control (основной)
   → Signing & Capabilities → + Capability → App Groups
   → + → group.com.padash00.orda.client

2. Выбрать target: OperatorWidgetExtension
   → Signing & Capabilities → + Capability → App Groups
   → + → group.com.padash00.orda.client (тот же!)

Оба target должны использовать ОДИНАКОВЫЙ App Group ID.
```

### Шаг 5 — Build Settings виджета
```
Target: OperatorWidgetExtension → Build Settings
→ iOS Deployment Target: 16.0
→ Swift Language Version: 5
```

### Шаг 6 — Проверить
```
Product → Build (⌘B)
Должно собраться без ошибок.

Запустить на симуляторе → Home Screen → долгое нажатие
→ + → найти "Orda Оператор"
→ Small / Medium / Large варианты
```

### Шаг 7 — Info.plist виджета
```
OperatorWidgetExtension/Info.plist должен содержать:
NSExtension → NSExtensionPointIdentifier = com.apple.widgetkit-extension
(Xcode добавит автоматически при создании target)
```

---

## F1.2 — Smoke Test ✅ ЧЕКЛИСТ

Пройти каждую роль после подключения виджета:

### Admin / Manager
- [ ] Вход → Admin shell открывается
- [ ] Доходы: добавить → появился в списке
- [ ] Расходы: добавить → появился
- [ ] Зарплата: неделя ← → навигация работает
- [ ] PDF зарплаты: генерируется, Share Sheet открывается
- [ ] Задача: создать → назначить оператору
- [ ] Аналитика: tap по дню → drill-down открывается
- [ ] Point Devices: просмотр, токен копируется

### Operator
- [ ] Вход → Operator shell
- [ ] Дашборд: имя, роль, статистика
- [ ] Задачи: загружаются
- [ ] Задача: ответить + комментарий
- [ ] Задача: добавить фото через PhotosPicker
- [ ] Смены: загружаются
- [ ] Зарплата: текущая неделя, график
- [ ] QR вход: сканер открывается (реальное устройство)
- [ ] Live Activity: при активной смене появляется в Dynamic Island
- [ ] Calendar: задача с due_date → событие в Календаре iOS

### Client
- [ ] Вход → Client shell
- [ ] Баллы: баланс отображается
- [ ] Tier: прогресс-бар показывает уровень
- [ ] QR карта: содержит customer_id (не текст "loyalty:Npts")
- [ ] Бронь: создать → в списке появилась
- [ ] Тикет: отправить → статус "отправлено"
- [ ] Pull-to-refresh работает на всех экранах

### Widget (после подключения target)
- [ ] Small виджет: показывает смену / задачи
- [ ] Medium виджет: смена слева + задачи справа
- [ ] Large виджет: полный список
- [ ] Обновляется после открытия приложения

---

## F1.3 — QR клиента ✅ УЖЕ ГОТОВО

Проверено: `LoyaltyQRSheet` использует `customer_id:\(customerId)`.
`PointsViewModel.primaryCustomerId` берёт ID из истории транзакций.

---

## F1.4 — Keychain ✅ УЖЕ ГОТОВО

Проверено: `SessionStore` использует `KeychainStorage(service: "com.orda.client")`.
Токены хранятся в Keychain, не в UserDefaults.

---

## Итог Фазы 1

| Задача | Статус |
|--------|--------|
| F1.1 Widget Target | ✅ Target + embed в app (см. выше; App Group проверить в Signing) |
| F1.2 Smoke Test | ⬜ После подключения виджета |
| F1.3 QR Fix | ✅ Готово |
| F1.4 Keychain | ✅ Готово |
| Widget UI улучшен | ✅ Small/Medium/Large с нормальным дизайном |

**F1.1 в проекте выполнен → остаётся F1.2 (smoke) и подтверждение App Group на своей машине → затем можно считать Фазу 1 полностью закрытой → Переход к Фазе 2.**
