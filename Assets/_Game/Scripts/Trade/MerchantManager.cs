using System;
using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Trade
{
    [Serializable]
    public class TradeMovement
    {
        public string id;
        public int fromVillageId;
        public int toVillageId;
        public Vector2Int toPos; // for other players later
        public Resources resources;
        public DateTime departTime;
        public DateTime arriveTime;
        public DateTime returnTime;
        public bool isReturning;
        public int merchantCount;
        public float speed; // fields per hour
    }

    public class MerchantManager : MonoBehaviour
    {
        public static MerchantManager Instance;
        public List<TradeMovement> trades = new List<TradeMovement>();
        public float baseMerchantSpeed = 16f; // fields per hour
        public float tradeOfficeBonusPerLevel = 0.05f;

        void Awake(){ Instance=this; }

        public bool SendResources(int fromId, int toId, Resources res, int merchantCount=1)
        {
            var save = GameManager.Instance.save;
            var from = save.villages.Find(v=>v.id==fromId);
            var to = save.villages.Find(v=>v.id==toId);
            if(from==null||to==null) return false;
            if(!from.resources.CanAfford(res)) return false;

            // check merchant capacity
            int capacityPerMerchant = GetMerchantCapacity(from.tribe); // 500 roman etc
            int totalCarry = merchantCount*capacityPerMerchant;
            if(res.Sum()>totalCarry){ Debug.Log("Not enough carry"); return false; }

            // pay
            from.resources = from.resources - res;

            float dist = Vector2Int.Distance(from.position, to.position);
            float speed = baseMerchantSpeed * (1f + GetTradeOfficeLevel(from)*tradeOfficeBonusPerLevel);
            float hours = dist / speed;

            var tm = new TradeMovement{
                id=Guid.NewGuid().ToString(),
                fromVillageId=fromId,
                toVillageId=toId,
                resources=res,
                departTime=DateTime.UtcNow,
                arriveTime=DateTime.UtcNow.AddHours(hours),
                returnTime=DateTime.UtcNow.AddHours(hours*2),
                merchantCount=merchantCount,
                speed=speed,
                isReturning=false
            };
            trades.Add(tm);
            Debug.Log($"[Trade] {fromId}->{toId} {res.Wood}W {res.Clay}C {res.Iron}I {res.Crop}Cr dist {dist:F1} ETA {hours:F2}h");
            return true;
        }

        int GetMerchantCapacity(Tribe t) => t switch { Tribe.Romans=>500, Tribe.Gauls=>750, Tribe.Germans=>400, _=>500 };
        int GetTradeOfficeLevel(Village v)
        {
            var slot = v.buildingSlots.Find(s=>s.buildingId=="tradeOffice");
            return slot?.level??0;
        }

        void Update()
        {
            var now=DateTime.UtcNow;
            for(int i=trades.Count-1;i>=0;i--)
            {
                var tr=trades[i];
                if(!tr.isReturning && now>=tr.arriveTime)
                {
                    // deliver
                    var to = GameManager.Instance.save.villages.Find(v=>v.id==tr.toVillageId);
                    if(to!=null)
                    {
                        to.resources = to.resources + tr.resources;
                        Debug.Log($"[Trade] Delivered to {to.villageName}");
                    }
                    tr.isReturning=true;
                }
                else if(tr.isReturning && now>=tr.returnTime)
                {
                    // merchants back
                    trades.RemoveAt(i);
                    Debug.Log($"[Trade] Merchants returned {tr.id}");
                }
            }
        }

        public List<TradeMovement> GetTradesForVillage(int villageId) => trades.FindAll(t=>t.fromVillageId==villageId || t.toVillageId==villageId);
    }
}
