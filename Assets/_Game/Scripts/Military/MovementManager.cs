using System;
using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Military
{
    public class MovementManager : MonoBehaviour
    {
        public static MovementManager Instance;
        void Awake(){ Instance=this; }

        public Movement SendTroops(int fromVillageId, Vector2Int toPos, Dictionary<string,int> troops, string type="raid")
        {
            var save = GameManager.Instance.save;
            var from = save.villages.Find(v=>v.id==fromVillageId);
            float dist = Vector2Int.Distance(from.position, toPos);
            int slowestSpeed = 16; // get from unit configs, min
            float hours = dist / slowestSpeed;
            var now = DateTime.UtcNow;

            var m = new Movement{
                id=Guid.NewGuid().ToString(),
                fromVillageId=fromVillageId,
                toPos=toPos,
                troops=new Dictionary<string,int>(troops),
                type=type,
                arriveTime=now.AddHours(hours),
                returnTime=now.AddHours(hours*2),
                isReturning=false
            };
            save.movements.Add(m);
            Debug.Log($"[Move] {type} from {fromVillageId} to {toPos} dist {dist:F1} in {hours:F2}h");
            return m;
        }

        void Update()
        {
            var save = GameManager.Instance?.save;
            if(save==null) return;
            var now = DateTime.UtcNow;
            for(int i=save.movements.Count-1;i>=0;i--)
            {
                var m=save.movements[i];
                if(!m.isReturning && now>=m.arriveTime)
                {
                    ProcessArrival(m);
                    m.isReturning=true;
                }
                else if(m.isReturning && now>=m.returnTime)
                {
                    ProcessReturn(m);
                    save.movements.RemoveAt(i);
                }
            }
        }

        void ProcessArrival(Movement m)
        {
            Debug.Log($"[Move] Arrival {m.id} at {m.toPos}");
            // if target is robber camp, do battle
            // for MVP just give loot
            if(m.type=="raid")
            {
                m.loot = new Resources{ Wood=UnityEngine.Random.Range(100,500), Clay=UnityEngine.Random.Range(100,500), Iron=UnityEngine.Random.Range(100,500), Crop=UnityEngine.Random.Range(100,300) };
                GameManager.Instance.save.reports.Add($"Набег на {m.toPos} принес {m.loot.Wood} дерева, {m.loot.Clay} глины");
            }
        }

        void ProcessReturn(Movement m)
        {
            var vill = GameManager.Instance.save.villages.Find(v=>v.id==m.fromVillageId);
            if(vill!=null)
            {
                // return troops
                foreach(var kv in m.troops)
                {
                    if(vill.troops.ContainsKey(kv.Key)) vill.troops[kv.Key]+=kv.Value;
                    else vill.troops[kv.Key]=kv.Value;
                }
                // add loot
                vill.resources = vill.resources + m.loot;
                Debug.Log($"[Move] Returned {m.id} loot {m.loot.Wood}");
            }
        }
    }
}
