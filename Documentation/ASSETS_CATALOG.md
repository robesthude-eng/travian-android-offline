# ASSETS КАТАЛОГ - Нарезано и готово

## Здания - 25 шт x 3 LOD = 100 PNG
Папка: `/art/buildings/cut/` - все 512x512 transparent

### Список:
- 01_Main_Building - Главное Здание (север, ворота)
- 02_Warehouse - Склад
- 03_Granary - Амбар
- 04_Barracks - Казарма (красная крыша, щиты)
- 05_Stable - Конюшня (лошадь)
- 06_Blacksmith_Workshop - Мастерская
- 07_Marketplace - Рынок (полоски)
- 08_Residence - Резиденция
- 09_TownHall_Palace - Ратуша/Дворец
- 10_City_Wall - Стена города
- 11_Sawmill - Лесопилка (пила)
- 12_Brickyard - Кирпичный
- 13_Iron_Foundry - Литейный
- 14_Grain_Mill - Мельница водяная
- 15_Bakery - Пекарня
- 16_Embassy - Посольство (зеленый купол)
- 17_Smithy_Armoury - Кузница
- 18_Armoury_Blacksmith - Фабрика доспехов
- 19_Rally_Point - Пункт Сбора (флаг)
- 20_Hero_Mansion - Двор героя
- 21_Watchtower - Башня
- 22_Cranny_Trapper - Тайник/Западня
- 23_Granary_Pit - Яма
- 24_Treasury - Сокровищница
- 25_Construction_Site - Стройплощадка

LOD:
- LOD1_1-5_Thatch - солома, 1-5 уровень
- LOD2_6-15_Wood - дерево, 6-15 уровень
- LOD3_16-20_Stone - камень, 16-20 уровень

Для MVP можно использовать один LOD, для красоты - 3.

## UI Ассеты
- `ui/app_icon_512.png` - Иконка приложения 512x512, шлем римский с лаврами, золотой обод, красный фон - готово для Google Play
- `ui/google_play_feature_graphic_1024x500.png` - Обложка (Feature Graphic) 1024x500, деревня на закате, легионы идут, место слева под текст "TRAVIAN ANDROID"
- `ui/loading_screen_cover_1080x1920.png` - Вертикальный лоадинг 1080x1920
- `ui/promo_icon_set_resources.png` - Иконки 4 ресурсов

## Деревни
- `village_center_authentic_travian.png` - пустая деревня 22 слота пронумеровано (база для Unity)
- `village_center_filled_buildings.png` - фулл деревня застроенная (мид-лейт)
- `village_center_starter_stage.png` - старт 5 зданий + молотки на пустых местах (туториал)
- `resource_fields_authentic_travian.png` - 18 полей 4-4-4-6 классика

## Где подставлено
1. `docs/village_mockup_Travian_Authentic.html` - пустая планировка аутентичная
2. `docs/village_filled_mockup.html` - подставленные кассеты-ассеты, 3 пресета (старт/мид/лейт) - кликай

## Как в Unity подставить
В сцене VillageView 22 Empty GameObjects Slot_01...Slot_22 расставленных по кругу как на картинке.
Скрипт:
```csharp
public List<Transform> slots; // 22
public List<GameObject> buildingPrefabs; // 25

void Spawn(int slotId, string buildingName, int lvl){
  var prefab = buildingPrefabs.First(b=>b.name.Contains(buildingName));
  var lod = lvl <=5 ? "_LOD1" : lvl <=15 ? "_LOD2" : "_LOD3";
  // ищем спрайт
  Instantiate(prefab, slots[slotId].position, Quaternion.identity);
}
```
