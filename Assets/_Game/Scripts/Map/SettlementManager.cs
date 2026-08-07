using System;
using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Map
{
    public class SettlementManager : MonoBehaviour
    {
        public static SettlementManager Instance;
        public int settlersNeeded = 3;
        public Resources settlerCostPerUnit = new Resources{ Wood=5800, Clay=4400, Iron=4600, Crop=5200 };

        void Awake(){ Instance=this; }

        public bool CanFoundVillage(int fromVillageId, out string reason)
        {
            var save = GameManager.Instance.save;
            var from = save.villages.Find(v=>v.id==fromVillageId);
            if(from==null){ reason="Деревня не найдена"; return false; }

            // Check culture points
            int neededCp = GetCpNeededForNextVillage(save.villages.Count);
            if(from.culturePoints < neededCp){ reason=$"Нужно {neededCp} культуры, а у тебя {from.culturePoints:F0}"; return false; }

            // Check residence/palace slot
            var residence = from.buildingSlots.Find(s=>s.buildingId=="residence" || s.buildingId=="palace");
            if(residence==null || residence.level<10){ reason="Нужна Резиденция 10 ур."; return false; }

            int freeSlots = GetFreeExpansionSlots(from);
            if(freeSlots<=0){ reason="Нет свободного слота расширения (построй Резиденцию 10/20)"; return false; }

            // Check settlers
            int settlerCount = from.troops.ContainsKey("settler") || from.troops.ContainsKey("roman_10_Settler") || from.troops.ContainsKey("gaul_10_Settler") || from.troops.ContainsKey("german_10_Settler") ?
                (from.troops.TryGetValue("settler", out var c)?c:0) + (from.troops.TryGetValue("roman_10_Settler", out var c2)?c2:0) + (from.troops.TryGetValue("gaul_10_Settler", out var c3)?c3:0) + (from.troops.TryGetValue("german_10_Settler", out var c4)?c4:0) : 0;

            // simplified check troops dict has settler key
            int totalSettlers = 0;
            foreach(var kv in from.troops) if(kv.Key.ToLower().Contains("settler")) totalSettlers+=kv.Value;

            if(totalSettlers < settlersNeeded){ reason=$"Нужно {settlersNeeded} поселенца, а у тебя {totalSettlers}"; return false; }

            // Check resources for settlers? Already paid when training, but need 750 each res for new village
            Resources foundCost = new Resources{ Wood=750, Clay=750, Iron=750, Crop=750 };
            // settlers carry it

            reason="Можно основывать!";
            return true;
        }

        int GetCpNeededForNextVillage(int currentCount)
        {
            // Travian CP table
            return currentCount switch { 1=>500, 2=>2000, 3=>7000, 4=>18000, _=>40000 };
        }

        int GetFreeExpansionSlots(Village v)
        {
            var res = v.buildingSlots.Find(s=>s.buildingId=="residence");
            var pal = v.buildingSlots.Find(s=>s.buildingId=="palace");
            int total=0;
            if(res!=null){
                if(res.level>=10) total+=1;
                if(res.level>=20) total+=1;
            }
            if(pal!=null){
                if(pal.level>=10) total+=1;
                if(pal.level>=15) total+=1;
                if(pal.level>=20) total+=1;
            }
            // used slots = villages founded from this village - we need to track, simplified: villages.Count-1 used?
            int used = 0; // TODO track per village
            return total - used;
        }

        public void FoundVillage(int fromVillageId, Vector2Int pos)
        {
            if(!CanFoundVillage(fromVillageId, out var reason)){ Debug.LogWarning($"Cannot found: {reason}"); return; }

            var save = GameManager.Instance.save;
            var from = save.villages.Find(v=>v.id==fromVillageId);

            // Remove 3 settlers
            int removed=0;
            var keys = new List<string>(from.troops.Keys);
            foreach(var k in keys){
                if(k.ToLower().Contains("settler") && from.troops[k]>0 && removed<3){
                    int take = Math.Min(from.troops[k], 3-removed);
                    from.troops[k]-=take;
                    removed+=take;
                }
            }

            // Create new village
            var newVill = new Village{
                id=save.villages.Count,
                villageName=$"Рим {save.villages.Count+1}",
                position=pos,
                tribe=from.tribe,
                isCapital=false,
                resources=new Resources{ Wood=750, Clay=750, Iron=750, Crop=750 },
                productionPerHour=new Resources{ Wood=15, Clay=15, Iron=15, Crop=15 },
                warehouseCapacity=800, granaryCapacity=800
            };
            // 18 fields all level 0
            ResType[] types = new ResType[]{ResType.Wood,ResType.Wood,ResType.Wood,ResType.Wood, ResType.Clay,ResType.Clay,ResType.Clay,ResType.Clay, ResType.Iron,ResType.Iron,ResType.Iron,ResType.Iron, ResType.Crop,ResType.Crop,ResType.Crop,ResType.Crop,ResType.Crop,ResType.Crop};
            for(int i=0;i<18;i++) newVill.fields.Add(new ResourceFieldData{ index=i, type=types[i], level=0 });
            for(int i=0;i<22;i++) newVill.buildingSlots.Add(new BuildingSlotData{ slotId=i, buildingId="", level=0 });
            newVill.buildingSlots[0].buildingId="mainBuilding"; newVill.buildingSlots[0].level=1;
            newVill.buildingSlots[1].buildingId="rallyPoint"; newVill.buildingSlots[1].level=1;
            newVill.buildingSlots[2].buildingId="warehouse"; newVill.buildingSlots[2].level=1;
            newVill.buildingSlots[3].buildingId="granary"; newVill.buildingSlots[3].level=1;

            save.villages.Add(newVill);
            from.culturePoints -= GetCpNeededForNextVillage(save.villages.Count-2); // simplified subtract

            Debug.Log($"[Settlement] Founded new village {newVill.villageName} at {pos} from {from.villageName}");
            GameManager.Instance.save.reports.Add($"Основана новая деревня {newVill.villageName} в {pos}!");

            // Save
            Core.SaveSystem.Save(save);
        }
    }
}
