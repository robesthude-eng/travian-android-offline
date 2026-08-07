# Travian Android - Unity Project

## Как открыть
1. Unity Hub -> Add -> выбери папку UnityProject
2. Версия Unity 2022.3 LTS (URP)
3. Открыть сцену `Assets/_Game/Scenes/Boot` - там GameManager

## Структура уже готова
- `Assets/_Game/Scripts/Core` - SaveSystem (JSON), TimeManager (оффлайн дельта 72ч кап), GameManager (DontDestroy)
- `Assets/_Game/Scripts/Economy` - ProductionCalculator (таблицы из Travian 4-4-4-6), ResourceManager (тик 1 раз в сек), BuildingSystem (2 очереди как в Travian: поля + центр)
- `Assets/_Game/Scripts/Military` - CombatSimulator (чистая функция, тестируемая), MovementManager (походы туда-обратно, оффлайн обработка)
- `Assets/_Game/Scripts/Map` - WorldGenerator 401x401, 500 лагерей, 200 оазисов
- `Assets/_Game/Scripts/Configs` - BuildingConfigSO, UnitConfig (ScriptableObject)
- `Assets/Art/Buildings` - 100 нарезанных PNG 512x512 transparent (все здания) + LOD1-3
- `Assets/Art/UI` - иконка приложения, фича-графика 1024x500, лоадинг 1080x1920
- `Assets/Art/Buildings/village_center_*` - референсы планировки аутентичной

## Что делать дальше в Unity (пошагово)

### 1. Создай ScriptableObjects конфиги
- ПКМ в Project -> Create -> Travian -> BuildingConfig
- Заполни по таблице из `/docs/Buildings.md` и `/docs/Unity_Configs_JSON.json` - я уже дал JSON готовый, просто перенеси baseCost и time
- Создай 25 SO дляBuildings и 30 для Units (римляне пока хватит 10)

### 2. Собери Village Center (самое важное)
- Создай пустой GO VillageCenter
- Внутрь добавь дочерний GO Wall (круглый спрайт палисада)
- Создай 22 пустых GO Slot_00...Slot_21 расставь по кругу как на `village_center_authentic_travian.png`:
  Наружное кольцо 16 шт radius 135:
  углы 255,270,285,310,330,0,20,40,60,90,120,150,170,190,210,230
  Внутреннее кольцо 5 шт radius 62:
  270 (Главное), 0 (Пункт сбора), 90,180,210
- На каждый слот повесь скрипт BuildingSlotView который показывает иконку из Art/Buildings

### 3. Собери Resource Fields View
- Пустой GO ResourceMap 400x400
- В центре пустой круга Village (пусто)
- 18 дочерних GO Field_00...Field_17, расставь по координатам из `village_mockup_Travian_Authentic.html`:
  Wood top: (22%,10%) (42%,6%) (68%,10%) (86%,24%)
  Clay east: (90%,44%) (82%,68%) (62%,85%) (40%,88%)
  Iron west: (14%,67%) (9%,42%) (24%,22%) (53%,18%)
  Crop scattered: (76%,30%) (80%,50%) (68%,72%) (48%,72%) (28%,58%) (32%,34%)
- На каждый поле спавнь Sprite из `resource_fields_authentic_travian.png` или отдельные иконки

### 4. UI
- Canvas -> TopBar (4 ресурса + население) привяжи к ResourceManager.OnResourcesChanged
- BottomTabs 5 кнопок: Поля, Деревня, Карта, Отчеты, Герой
- BuildMenu - показывает cost, time, требует здания

### 5. Тестовый билд APK
- File -> Build Settings -> Android -> Switch Platform
- Player Settings -> Package Name com.yourname.travianoffline
- Minimum API 24 (Android 7.0)
- Build -> Build And Run на телефон

### 6. Чит-меню для дебага (уже заложено)
В UIManager добавь скрытую кнопку: 5 тапов по версии -> +10k ресов, мгновенная постройка

## Готово для оффлайна
Сохраняшки в `Application.persistentDataPath/save.json`
Время считается даже когда приложение закрыто (TimeManager)

## Дальше онлайн
Замени SaveSystem на FirebaseBackend (интерфейс IGameBackend уже задуман) - код боевки уже на сервере будет.

Если хочешь - могу собрать готовый .unitypackage или выгрузить APK прямо отсюда (через Unity Cloud Build эмуляция).

## Арты уже подставлены
В `Assets/Art/Buildings/cut/` лежат 100 PNG, просто перетащи в SpriteRenderer.

Обложка для Google Play - `google_play_feature_graphic_1024x500.png` и `app_icon_512.png` уже соответствуют требованиям Store.

