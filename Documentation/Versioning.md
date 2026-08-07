# Версионирование APK

## Проблема: Ни один АПК не собрался
Причина из логов GitHub Actions:
1. `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD` пустые — секреты не заданы
2. `ProjectSettings/ProjectVersion.txt` не найден — мы не создали полный Unity проект, только Assets
3. Параметр `androidAppBundle` устарел

## Что починили
1. Создал `ProjectSettings/ProjectVersion.txt` с версией 2022.3.20f1
2. Починил workflow `build-android.yml` — убрал deprecated `androidAppBundle`, добавил `androidVersionCode: ${{ github.run_number }}` и `unityVersion: 2022.3.20f1`
3. Создал второй workflow `build-android-simple.yml` — собирает простой APK на Kotlin WebView без Unity лицензии. Он берет HTML `Game_v1_ThreeWindows_Polished.html` и упаковывает в APK. Версия = 1.0.<run_number>

## Как теперь собирается APK с версией

### Simple APK (без Unity лицензии, работает сразу)
- Workflow: `Build Simple APK (WebView - No Unity License needed)`
- Триггер: push в main с изменениями в AndroidSimple/**, Documentation/**, Assets/WebGLMockup/**
- Версия: `versionCode = github.run_number`, `versionName = 1.0.<run_number>`
- Пример: первый билд = v1, второй пуш = v2, и т.д.
- Артефакт: `Travian-Simple-APK-v<run_number>` содержит `app-debug.apk`

### Unity APK (нужна лицензия)
- Workflow: `Build Android APK (Travian Offline - Unity - Needs License)`
- Требует секреты в GitHub: Settings -> Secrets -> Actions:
  - `UNITY_LICENSE` — получи командой: `npx --yes unity-license-activate` или вручную через https://license.unity3d.com/manual (см https://game.ci/docs/github/activation)
  - `UNITY_EMAIL` — твой Unity ID email
  - `UNITY_PASSWORD` — пароль Unity ID
- Версия: `androidVersionCode = run_number`, `versioning: Semantic` → 1.0.<run_number>
- Артефакт: `Travian-Unity-APK-v<run_number>`

## Как установить APK
1. Скачай артефакт из Actions -> выбери последний successful run -> Artifacts -> скачай zip
2. Распакуй, внутри `app-debug.apk`
3. На телефоне разреши установку из неизвестных источников
4. Установи, иконка римский шлем

## 2-я деревня поселенцами
Реализовано в `SettlementManager.cs`:
- Нужно: Культура 500 для 2-й деревни, Резиденция 10 lvl, 3 поселенца (обучаются в Резиденции, стоимость 5800W 4400C 4600I 5200Cr каждый)
- Проверка: `CanFoundVillage()` — слоты расширения (Residence 10 и 20 дает 2 слота, Palace 10/15/20 дает 3)
- Основание: `FoundVillage(fromId, pos)` — забирает 3 поселенца, создает новую Village с 18 полями lvl0, складом/амбаром lvl1, стартовыми 750 ресов
- Карта: свободное место (проверка 10 полей от других деревень) → кнопка "Основать деревню"
- HTML мок: скоро добавлю в Game_v3_Settlement.html

