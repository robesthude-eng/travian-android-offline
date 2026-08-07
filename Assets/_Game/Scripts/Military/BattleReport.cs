using System;
using System.Collections.Generic;
using UnityEngine;

namespace TravianOffline.Military
{
    [Serializable]
    public class BattleReport
    {
        public string id;
        public DateTime time;
        public bool isAttacker;
        public Vector2Int from;
        public Vector2Int to;
        public bool won;
        public Dictionary<string,int> attackerTroopsBefore;
        public Dictionary<string,int> attackerSurvivors;
        public Dictionary<string,int> defenderTroopsBefore;
        public Dictionary<string,int> defenderSurvivors;
        public Data.Resources loot;
        public int wallDamage;
        public int buildingDamage;
        public string buildingHit;
        public int heroXpGained;
        public string lootItem;
    }

    public class BattleReportManager : MonoBehaviour
    {
        public static BattleReportManager Instance;
        public List<BattleReport> reports = new List<BattleReport>();
        public int maxReports=100;
        public Action<BattleReport> OnNewReport;

        void Awake(){ Instance=this; }

        public void AddReport(BattleReport r)
        {
            reports.Insert(0,r);
            if(reports.Count>maxReports) reports.RemoveAt(reports.Count-1);
            OnNewReport?.Invoke(r);
            // save
            var gm = GameManager.Instance;
            if(gm!=null) gm.save.reports.Add($"[{r.time:HH:mm}] {(r.won? "Победа":"Поражение")} {(r.isAttacker?"атака":"защита")} {r.to} лут {r.loot.Wood}");
        }

        public List<BattleReport> GetReportsForVillage(int villageId)
        {
            var v = GameManager.Instance.save.villages.Find(x=>x.id==villageId);
            if(v==null) return reports;
            return reports.FindAll(r=> r.from==v.position || r.to==v.position);
        }
    }
}
