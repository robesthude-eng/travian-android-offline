# UNITY АРХИТЕКТУРА - ОФФЛАЙН -> ОНЛАЙН

## СТЕК
- Unity 2022.3 LTS (URP)
- C# .NET Standard 2.1
- DOTween для анимаций
- UniRx / R3 для реактивности (опционально)
- Newtonsoft.Json для сейвов
- ScriptableObjects для конфигов зданий/юнитов
- Addressables для будущих онлайн-обновлений

## СТРУКТУРА ПРОЕКТА

```
Assets/
├── _Game/
│   ├── Scripts/
│   │   ├── Core/
│   │   │   ├── GameManager.cs
│   │   │   ├── SaveSystem.cs (JSON + PlayerPrefs)
│   │   │   ├── TimeManager.cs (оффлайн дельта)
│   │   │   ├── ConfigManager.cs (загрузка SO -> Runtime)
│   │   ├── Economy/
│   │   │   ├── ResourceManager.cs
│   │   │   ├── ProductionCalculator.cs
│   │   │   ├── BuildingSystem.cs
│   │   │   ├── BuildingQueue.cs
│   │   │   ├── Village.cs
│   │   │   ├── ResourceField.cs
│   │   ├── Military/
│   │   │   ├── UnitConfig.cs (SO)
│   │   │   ├── UnitManager.cs
│   │   │   ├── CombatSimulator.cs
│   │   │   ├── MovementManager.cs
│   │   │   ├── RobberCampSpawner.cs
│   │   │   ├── HeroManager.cs
│   │   ├── Map/
│   │   │   ├── WorldMap.cs (401x401)
│   │   │   ├── MapTile.cs
│   │   │   ├── WorldGenerator.cs
│   │   │   ├── Oasis.cs
│   │   ├── UI/
│   │   │   ├── UIManager.cs
│   │   │   ├── TopBarResources.cs
│   │   │   ├── BottomTabs.cs
│   │   │   ├── VillageCenterView.cs (изометрия)
│   │   │   ├── ResourceFieldView.cs (круглая карта)
│   │   │   ├── BuildMenu.cs
│   │   │   ├── MapView.cs (зум, пан)
│   │   │   ├── ReportsView.cs
│   │   │   ├── MovementListView.cs
│   │   ├── Data/
│   │   │   ├── SaveData.cs (модель сохранения)
│   │   │   ├── PlayerData.cs
│   │   ├── Configs/ (ScriptableObjects)
│   │   │   ├── BuildingConfigSO.cs
│   │   │   ├── TribeConfigSO.cs
│   │   │   ├── UnitConfigSO.cs
│   ├── Prefabs/
│   │   ├── Buildings/ (25 префабов + 3LOD)
│   │   ├── Units/ (иконки)
│   │   ├── UI/
│   │   ├── VFX/
│   ├── Scenes/
│   │   ├── Boot.unity (загрузка сейва)
│   │   ├── Main.unity (основная игра)
│   ├── Art/
│   │   ├── Sprites/
│   │   ├── Models/
│   │   ├── Materials/

```

## КЛЮЧЕВЫЕ КЛАССЫ (Псевдо)

### Village.cs
```
[Serializable]
public class Village {
  public int id;
  public string name; // "Рим I"
  public Vector2Int pos;
  public Tribe tribe;
  public Dictionary<ResType,int> resources;
  public Dictionary<ResType,float> productionPerHour;
  public List<ResourceField> fields; // 18
  public List<BuildingSlot> slots; // 22
  public Dictionary<UnitType,int> troopsAtHome;
  public float culturePoints;
  public int population;
  public bool isCapital;
}
```

### SaveData.cs
```
[Serializable]
public class SaveData {
  public string playerName;
  public Tribe playerTribe;
  public List<Village> villages;
  public List<Movement> movements;
  public HeroData hero;
  public WorldMapData map;
  public DateTime lastSaveTime; // UTC
  public int currentVillageIndex;
  public List<Report> reports;
}
```

### SaveSystem.cs
- `Save()` -> JsonUtility + сжатие Base64 -> File.WriteAllText(Application.persistentDataPath + "/save.json")
- `Load()` -> если файла нет -> создать новую игру
- Автосейв каждые 30 сек + OnApplicationPause + OnApplicationFocus(false)

### TimeManager.cs
- При загрузке считает `TimeSpan offline = DateTime.UtcNow - save.lastSaveTime`
- Вызывает `ResourceManager.ProcessOffline(offline)`
- Запускает корутины для обновления ресурсов каждую секунду визуально (`productionPerHour / 3600` в секунду)

### CombatSimulator.cs
- Статический класс `public static BattleResult Simulate(BattleInput input)`
- Чистая функция, без MonoBehaviour, можно 100% покрыть юнит-тестами
- Возвращает убитых, выживших, лут, damage к стене/зданию

### MovementManager.cs
- Список всех походов
- Update каждую секунду проверяет `if (Time.UtcNow >= movement.arriveTime && !processed)`
- При оффлайне все походы обрабатываются в `ProcessOffline`

### WorldGenerator.cs
- Генерирует карту при новой игре:
```
for (int i=0; i<500; i++) SpawnRobberCamp(randomPos, randomLevel);
for (int i=0; i<200; i++) SpawnOasis(randomPos);
for (int i=0; i<100; i++) SpawnNpcVillage(randomPos);
```
- Использует `System.Random` с сидом от имени игрока, чтобы карта была детерминированной но уникальной.

## UI ПОТОК

1. **Boot Scene:** Лого -> Загрузка SO -> SaveSystem.Load() -> Переход в Main -> TimeManager.ProcessOffline()
2. **Main Scene:** Камера изометрия + Canvas
   - TopBar подписан на `ResourceManager.OnResourceChanged`
   - BottomTabs переключает Views (деактивирует/активирует Go)
   - VillageCenterView: Instantiates зданий по `slots`. Пустой слот = иконка "Построить"
   - ResourceFieldView: 18 кнопок по кругу, центр - деревня. Клик -> BuildMenu для поля.
   - BuildMenu: Показывает требования, стоимость, время. Кнопка "Строить" -> BuildingQueue.Enqueue()
   - MapView: Tilemap или просто ScrollRect с GridLayout. Оптимизация: виртуализация (рисуем только 21x21 тайлов вокруг центра). Зум через Pinch.
   - ReportsView: ListView отчетов о боях.

## АРТ-ИНТЕГРАЦИЯ

- Здания: Isometric Spritesheet или LowPoly 3D (100-500 трисов на здание). Для MVP - спрайты.
- 3 уровня детализации спрайта на здание: Lvl 1-5, 6-14, 15-20 (разные модели)
- Анимация: просто idle + дым (particle) для полей.
- UI: Figma -> Unity UI Toolkit или обычные RectTransform.

## ПРОИЗВОДИТЕЛЬНОСТЬ ДЛЯ ANDROID

- 60 FPS не нужно, достаточно 30 FPS (`Application.targetFrameRate = 30`)
- VSync off
- Атлансы для спрайтов зданий (TexturePacker)
- Пулинг для движений (не спавнить каждый раз)
- Сохранение не в Update, а по событию.

## ПЕРЕХОД В ОНЛАЙН (АРХИТЕКТУРА НА БУДУЩЕЕ)

Делаем с первого дня интерфейсы:

```
interface IGameBackend {
  Task<SaveData> LoadRemote();
  Task SaveRemote(SaveData data);
  Task<List<Movement>> GetMovements();
  Task<BattleResult> ProcessBattleRemote(BattleInput);
}
```

Реализации:
- `OfflineBackend` : работает с локальным JSON (сейчас)
- `FirebaseBackend` : Firestore + Cloud Functions для боевки (потом)
- `MirrorBackend` или `Netcode` : для реального времени (не нужно для Travian, там асинхронно)

Боевка в онлайне должна считаться на сервере (анти-чит). Но клиент может делать превью.

Карта: сейчас локальный `WorldGenerator`, потом станет сервером который отдает чанки `GET /map?x=0&y=0&radius=21`

Авторизация: сейчас нет, потом Firebase Auth + Play Games.

## ЧИТ-МЕНЮ (для тестов)

В настройках 5 тапов по версии -> Debug Panel:
- +10k всех ресов
- Мгновенная постройка (time=0)
- Спавн лагеря 15 lvl рядом
- Открыть все здания
- +100k культуры

## БИЛД

- Keystore для Android
- APK + AAB (Android App Bundle для Google Play)
- Минимальная версия Android 7.0 (API 24)
- Размер: цель <100MB для MVP

## СЛЕДУЮЩИЙ ШАГ

1. Создать Unity проект по этой структуре
2. Сделать ScriptableObjects для всех зданий и юнитов (я уже дал таблицы)
3. Сверстать UI по вайрфреймам (могу сделать HTML прототип)
4. Написать Core: Save + Time + Resources
