using System;
using System.Collections.Generic;
using UnityEngine;

namespace TravianOffline.Data
{
    [Serializable]
    public class ResourceFieldData
    {
        public ResType type;
        public int level = 0;
        public int index; // 0-17
    }

    [Serializable]
    public class BuildingSlotData
    {
        public int slotId; // 1-22, 0=main fixed, 1=rally, wall special
        public string buildingId; // e.g. "warehouse"
        public int level = 0;
        public bool isEmpty => string.IsNullOrEmpty(buildingId) || level==0;
    }

    [Serializable]
    public class Village
    {
        public int id;
        public string villageName = "Рим I";
        public Vector2Int position;
        public Tribe tribe = Tribe.Romans;
        public bool isCapital = true;

        public Resources resources;
        public Resources productionPerHour;
        public int warehouseCapacity = 800;
        public int granaryCapacity = 800;
        public int population = 0;
        public float culturePoints = 0;

        public List<ResourceFieldData> fields = new List<ResourceFieldData>(); // 18
        public List<BuildingSlotData> buildingSlots = new List<BuildingSlotData>(); // 22 inc wall

        // troops at home
        public Dictionary<string,int> troops = new Dictionary<string,int>();

        public int GetNetCrop()
        {
            int consumption = population;
            foreach(var kv in troops) consumption += kv.Value * 1; // simplified, real cropEat from config
            return productionPerHour.Crop - consumption;
        }
    }

    [Serializable]
    public class HeroData
    {
        public int level = 1;
        public int xp = 0;
        public int strength = 0; // attack bonus
        public int defense = 0;
        public int resourceBonus = 0;
        public bool isDead = false;
        public DateTime reviveTime;
    }

    [Serializable]
    public class Movement
    {
        public string id;
        public int fromVillageId;
        public Vector2Int toPos;
        public Dictionary<string,int> troops;
        public bool withHero;
        public string type; // raid, attack, scout, settle
        public DateTime arriveTime;
        public DateTime returnTime;
        public bool isReturning = false;
        public Resources loot;
    }

    [Serializable]
    public class SaveData
    {
        public string playerName = "Шеф";
        public Tribe playerTribe = Tribe.Romans;
        public List<Village> villages = new List<Village>();
        public List<Movement> movements = new List<Movement>();
        public HeroData hero = new HeroData();
        public DateTime lastSaveTimeUtc;
        public int currentVillageIndex = 0;
        public List<string> reports = new List<string>();
    }
}
