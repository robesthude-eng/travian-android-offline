using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;
using TravianOffline.Configs;

namespace TravianOffline.Military
{
    public class TrainQueueItem
    {
        public string unitId;
        public int count;
        public float finishTime;
        public int villageId;
        public string buildingId; // barracks, stable, workshop
    }

    public class UnitTrainingSystem : MonoBehaviour
    {
        public static UnitTrainingSystem Instance;
        List<TrainQueueItem> queue = new List<TrainQueueItem>();
        Dictionary<string, UnitConfig> unitConfigs = new Dictionary<string, UnitConfig>();

        void Awake(){ Instance=this; }

        public void RegisterConfig(UnitConfig cfg){ unitConfigs[cfg.id]=cfg; }

        public bool Enqueue(string unitId, int count, int villageId)
        {
            if(!unitConfigs.ContainsKey(unitId)){ Debug.LogWarning($"Unit {unitId} not found"); return false; }
            var cfg = unitConfigs[unitId];
            var village = GameManager.Instance.save.villages.Find(v=>v.id==villageId);
            if(village==null) return false;

            // check resources
            Resources totalCost = new Resources{
                Wood=cfg.cost.Wood*count,
                Clay=cfg.cost.Clay*count,
                Iron=cfg.cost.Iron*count,
                Crop=cfg.cost.Crop*count
            };
            if(!village.resources.CanAfford(totalCost)){ Debug.Log("Not enough resources"); return false; }

            // pay
            village.resources = village.resources - totalCost;

            // calc time with building bonus
            var bSlot = village.buildingSlots.Find(s=>s.buildingId==cfg.requiredBuilding);
            int bLvl = bSlot?.level??1;
            float time = cfg.trainTimeSec * count * Mathf.Pow(0.9f, bLvl-1);

            var item = new TrainQueueItem{
                unitId=unitId, count=count, villageId=villageId, buildingId=cfg.requiredBuilding,
                finishTime=Time.realtimeSinceStartup+time
            };
            queue.Add(item);
            Debug.Log($"[Train] {count}x {unitId} in {time}s at village {villageId}");
            return true;
        }

        void Update()
        {
            float now = Time.realtimeSinceStartup;
            for(int i=queue.Count-1;i>=0;i--)
            {
                if(now>=queue[i].finishTime)
                {
                    Finish(queue[i]);
                    queue.RemoveAt(i);
                }
            }
        }

        void Finish(TrainQueueItem item)
        {
            var village = GameManager.Instance.save.villages.Find(v=>v.id==item.villageId);
            if(village==null) return;
            if(village.troops.ContainsKey(item.unitId)) village.troops[item.unitId]+=item.count;
            else village.troops[item.unitId]=item.count;
            Debug.Log($"[Train] Finished {item.count}x {item.unitId} in village {village.villageName}");
            GameManager.Instance.save.reports.Add($"Обучено {item.count}x {item.unitId} в {village.villageName}");
        }

        public List<TrainQueueItem> GetQueueForVillage(int villageId, string buildingId)
        {
            return queue.FindAll(q=>q.villageId==villageId && q.buildingId==buildingId);
        }
    }
}
