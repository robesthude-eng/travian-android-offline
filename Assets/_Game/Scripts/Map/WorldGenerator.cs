using UnityEngine;
using System.Collections.Generic;

namespace TravianOffline.Map
{
    public class WorldGenerator : MonoBehaviour
    {
        public int mapSize = 401; // -200..200
        public List<Vector2Int> robberCamps = new List<Vector2Int>();
        public List<Vector2Int> oases = new List<Vector2Int>();
        public List<Vector2Int> npcVillages = new List<Vector2Int>();

        public void Generate(int seed=0)
        {
            Random.InitState(seed);
            robberCamps.Clear();
            for(int i=0;i<500;i++)
            {
                var pos = new Vector2Int(Random.Range(-200,200), Random.Range(-200,200));
                if(pos.magnitude<15) continue; // no near spawn
                robberCamps.Add(pos);
            }
            oases.Clear();
            for(int i=0;i<200;i++) oases.Add(new Vector2Int(Random.Range(-200,200), Random.Range(-200,200)));
            npcVillages.Clear();
            for(int i=0;i<100;i++) npcVillages.Add(new Vector2Int(Random.Range(-200,200), Random.Range(-200,200)));

            Debug.Log($"[World] Generated {robberCamps.Count} camps, {oases.Count} oases");
        }

        public Vector2Int GetFreeSettlePos(Vector2Int near, int minDist=10)
        {
            for(int attempt=0;attempt<100;attempt++)
            {
                var pos = near + new Vector2Int(Random.Range(-30,30), Random.Range(-30,30));
                if(Mathf.Abs(pos.x)>200 || Mathf.Abs(pos.y)>200) continue;
                bool occupied=false;
                foreach(var c in robberCamps) if(Vector2Int.Distance(c,pos)<minDist) occupied=true;
                if(!occupied) return pos;
            }
            return near + Vector2Int.one*15;
        }
    }
}
