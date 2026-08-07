using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;
using TravianOffline.Configs;

namespace TravianOffline.Economy
{
    [System.Serializable]
    public class BuildQueueItem
    {
        public int villageId;
        public int slotId; // -1 for resource field
        public int fieldIndex; // for resource fields
        public string buildingId;
        public int targetLevel;
        public float finishTime; // Time.realtimeSinceStartup
    }

    public class BuildingSystem : MonoBehaviour
    {
        public List<BuildQueueItem> queue = new List<BuildQueueItem>();
        Queue<BuildQueueItem> fieldQueue = new Queue<BuildQueueItem>();
        Queue<BuildQueueItem> centerQueue = new Queue<BuildQueueItem>();

        public bool EnqueueBuild(int villageId, int slotId, int fieldIdx, string buildingId, int targetLvl, float buildTimeSec)
        {
            // 2 queues: fields and center as in Travian
            bool isField = fieldIdx>=0;
            if(isField && fieldQueue.Count>=1) { Debug.Log("Field queue full"); return false; }
            if(!isField && centerQueue.Count>=1) { Debug.Log("Center queue full"); return false; }

            var item = new BuildQueueItem{ villageId=villageId, slotId=slotId, fieldIndex=fieldIdx, buildingId=buildingId, targetLevel=targetLvl, finishTime=Time.realtimeSinceStartup+buildTimeSec };
            queue.Add(item);
            if(isField) fieldQueue.Enqueue(item); else centerQueue.Enqueue(item);
            Debug.Log($"[Build] Enqueued {buildingId} lvl {targetLvl} in {buildTimeSec}s");
            return true;
        }

        void Update()
        {
            float now = Time.realtimeSinceStartup;
            // check finishes
            for(int i=queue.Count-1;i>=0;i--)
            {
                var it = queue[i];
                if(now >= it.finishTime)
                {
                    FinishBuild(it);
                    queue.RemoveAt(i);
                }
            }
        }

        void FinishBuild(BuildQueueItem it)
        {
            var gm = GameManager.Instance;
            var village = gm.save.villages.Find(v=>v.id==it.villageId);
            if(village==null) return;

            if(it.fieldIndex>=0)
            {
                village.fields[it.fieldIndex].level = it.targetLevel;
                fieldQueue.Dequeue();
                Debug.Log($"[Build] Field {it.fieldIndex} -> lvl {it.targetLevel}");
            }
            else
            {
                var slot = village.buildingSlots.Find(s=>s.slotId==it.slotId);
                if(slot!=null){ slot.buildingId=it.buildingId; slot.level=it.targetLevel; }
                centerQueue.Dequeue();
                Debug.Log($"[Build] Slot {it.slotId} {it.buildingId} -> lvl {it.targetLevel}");
            }
            // recalc pop, production, caps
            RecalcVillage(village);
        }

        void RecalcVillage(Village v)
        {
            // population = sum building pop + field pop (simplified 1 per level)
            int pop=0;
            foreach(var f in v.fields) pop+=f.level/2;
            foreach(var s in v.buildingSlots) pop+=s.level;
            v.population=pop;

            v.productionPerHour = ProductionCalculator.GetVillageProduction(v);

            // warehouse cap from building level
            var wh = v.buildingSlots.Find(s=>s.buildingId=="warehouse");
            var gr = v.buildingSlots.Find(s=>s.buildingId=="granary");
            int whLvl = wh?.level??1;
            int grLvl = gr?.level??1;
            v.warehouseCapacity = Mathf.RoundToInt(800 * Mathf.Pow(1.28f, whLvl));
            v.granaryCapacity = Mathf.RoundToInt(800 * Mathf.Pow(1.28f, grLvl));
        }
    }
}
