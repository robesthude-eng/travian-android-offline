using System.IO;
using UnityEngine;
using TravianOffline.Data;
using System;

namespace TravianOffline.Core
{
    public static class SaveSystem
    {
        static string SavePath => Path.Combine(Application.persistentDataPath, "save.json");

        public static void Save(SaveData data)
        {
            try
            {
                data.lastSaveTimeUtc = DateTime.UtcNow;
                string json = JsonUtility.ToJson(data, true);
                // Use wrapper for lists? JsonUtility doesn't support dict, we use Newtonsoft if needed. For MVP use JsonUtility limited, but write.
                File.WriteAllText(SavePath, json);
                PlayerPrefs.SetString("lastSavePath", SavePath);
                Debug.Log($"[Save] Saved to {SavePath} at {data.lastSaveTimeUtc}");
            }
            catch(Exception e){ Debug.LogError($"Save failed: {e}"); }
        }

        public static SaveData Load()
        {
            try
            {
                if (!File.Exists(SavePath))
                {
                    Debug.Log("[Save] No save, creating new");
                    return CreateNewGame();
                }
                string json = File.ReadAllText(SavePath);
                var data = JsonUtility.FromJson<SaveData>(json);
                Debug.Log($"[Save] Loaded villages:{data.villages.Count} last:{data.lastSaveTimeUtc}");
                return data;
            }
            catch(Exception e)
            {
                Debug.LogError($"Load failed: {e}, creating new");
                return CreateNewGame();
            }
        }

        static SaveData CreateNewGame()
        {
            var sd = new SaveData();
            // create first village at 0,0 with 4-4-4-6
            var v = new Village{ id=0, position=Vector2Int.zero, isCapital=true, villageName="Рим I"};
            // 18 fields
            ResType[] types = new ResType[]{ResType.Wood,ResType.Wood,ResType.Wood,ResType.Wood, ResType.Clay,ResType.Clay,ResType.Clay,ResType.Clay, ResType.Iron,ResType.Iron,ResType.Iron,ResType.Iron, ResType.Crop,ResType.Crop,ResType.Crop,ResType.Crop,ResType.Crop,ResType.Crop};
            for(int i=0;i<18;i++) v.fields.Add(new ResourceFieldData{ index=i, type=types[i], level= i<4?1:0 });
            // 22 slots: 0 main, 1 rally, 2-21 free, 22 wall
            for(int i=0;i<22;i++) v.buildingSlots.Add(new BuildingSlotData{ slotId=i, buildingId="", level=0});
            v.buildingSlots[0].buildingId="mainBuilding"; v.buildingSlots[0].level=1;
            v.buildingSlots[1].buildingId="rallyPoint"; v.buildingSlots[1].level=1;
            v.buildingSlots[2].buildingId="warehouse"; v.buildingSlots[2].level=1;
            v.buildingSlots[3].buildingId="granary"; v.buildingSlots[3].level=1;
            v.resources = new Resources{ Wood=750, Clay=750, Iron=750, Crop=750 };
            v.productionPerHour = new Resources{ Wood=35, Clay=35, Iron=35, Crop=70 };
            v.warehouseCapacity = 1000; v.granaryCapacity = 1000;
            sd.villages.Add(v);
            sd.lastSaveTimeUtc = DateTime.UtcNow;
            Save(sd);
            return sd;
        }

        public static void DeleteSave()
        {
            if(File.Exists(SavePath)) File.Delete(SavePath);
            PlayerPrefs.DeleteAll();
        }
    }
}
