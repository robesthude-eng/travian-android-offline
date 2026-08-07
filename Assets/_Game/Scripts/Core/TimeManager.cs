using System;
using TravianOffline.Data;
using TravianOffline.Economy;
using UnityEngine;

namespace TravianOffline.Core
{
    public class TimeManager : MonoBehaviour
    {
        public static TimeManager Instance;
        SaveData save;

        void Awake(){ Instance=this; }

        public void Init(SaveData data)
        {
            save = data;
            ProcessOfflineTime();
        }

        void ProcessOfflineTime()
        {
            if(save==null) return;
            var now = DateTime.UtcNow;
            var offline = now - save.lastSaveTimeUtc;
            if(offline.TotalSeconds < 5) return; // just saved

            // clamp max 72h anti-cheat + negative check
            if(offline.TotalHours < 0) { Debug.LogWarning("Time travel detected, ignoring"); offline = TimeSpan.Zero; }
            if(offline.TotalHours > 72) offline = TimeSpan.FromHours(72);

            Debug.Log($"[Time] Offline {offline.TotalHours:F2}h");

            foreach(var village in save.villages)
            {
                // resources
                double hours = offline.TotalHours;
                var prod = ProductionCalculator.GetVillageProduction(village);
                foreach(ResType rt in Enum.GetValues(typeof(ResType)))
                {
                    int produced = (int)(prod.Get(rt) * hours);
                    int current = village.resources.Get(rt);
                    int cap = (rt==ResType.Crop) ? village.granaryCapacity : village.warehouseCapacity;
                    int newVal = Mathf.Min(cap, current + produced);
                    village.resources.Set(rt, newVal);
                }
                // starvation
                if(village.resources.Crop==0 && village.GetNetCrop()<0)
                {
                    int steps = (int)(offline.TotalMinutes/10);
                    Debug.Log($"[Time] Starvation {village.villageName} steps {steps}");
                    // simplified: reduce population or kill troops
                }
            }
            // movements
            foreach(var m in save.movements)
            {
                if(now >= m.arriveTime && !m.isReturning)
                {
                    Debug.Log($"[Time] Movement arrived {m.id} at {m.toPos}");
                    // here call CombatSimulator if needed
                    m.isReturning = true;
                    m.returnTime = m.arriveTime + (m.arriveTime - (save.lastSaveTimeUtc)); // approx travel back
                    // for MVP we just set returning
                }
                if(m.isReturning && now >= m.returnTime)
                {
                    // return troops - logic in MovementManager
                }
            }
        }
    }
}
