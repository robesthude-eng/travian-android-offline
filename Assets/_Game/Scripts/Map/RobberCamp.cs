using System.Collections.Generic;
using UnityEngine;

namespace TravianOffline.Map
{
    [System.Serializable]
    public class RobberCampData
    {
        public int id;
        public Vector2Int pos;
        public int level=1; // 1-15
        public int health=100;
        public Dictionary<string,int> natureTroops; // rat:5 etc
        public Data.Resources reward;
        public int xpReward;
        public string lootItemId; // equipment
        public System.DateTime spawnTime;
        public System.DateTime respawnTime;
    }

    public class RobberCamp : MonoBehaviour
    {
        public RobberCampData data;
        public void Setup(RobberCampData d){ data=d; UpdateVisual(); }
        void UpdateVisual()
        {
            // swap sprite by level: lvl1 small tents, lvl5 fort, lvl10 castle
        }
        void OnMouseDown()
        {
            Debug.Log($"Camp {data.id} lvl {data.level} at {data.pos} clicked");
            // open attack dialog via UIManager
        }
    }

    public class RobberCampSpawner : MonoBehaviour
    {
        public List<RobberCampData> activeCamps = new List<RobberCampData>();
        public int maxCamps=500;
        public float respawnHours=8f;

        public void GenerateCamps(Vector2Int center, int radius=30, int count=15)
        {
            // generate around player
            activeCamps.Clear();
            for(int i=0;i<count;i++)
            {
                var pos = center + new Vector2Int(Random.Range(-radius,radius), Random.Range(-radius,radius));
                int lvl = Random.Range(1,6); // early game 1-5, later 1-15
                var camp = new RobberCampData{
                    id=i,
                    pos=pos,
                    level=lvl,
                    natureTroops=GenerateNatureTroops(lvl),
                    reward=new Data.Resources{ Wood=lvl*300, Clay=lvl*300, Iron=lvl*300, Crop=lvl*150 },
                    xpReward=lvl*50,
                    lootItemId = lvl>=3 ? "helmet_0"+lvl : null,
                    spawnTime=System.DateTime.UtcNow
                };
                activeCamps.Add(camp);
            }
        }

        Dictionary<string,int> GenerateNatureTroops(int lvl)
        {
            var dict = new Dictionary<string,int>();
            if(lvl<=2){ dict["rat"]=5+lvl*5; }
            else if(lvl<=4){ dict["rat"]=10; dict["spider"]=5+lvl*2; }
            else if(lvl<=7){ dict["snake"]=10+lvl*3; dict["wildBeast"]=5+lvl; }
            else { dict["robber"]=10+lvl*2; dict["robberChief"]=1; }
            return dict;
        }

        void Update()
        {
            // check respawn
            var now=System.DateTime.UtcNow;
            for(int i=activeCamps.Count-1;i>=0;i--)
            {
                if(activeCamps[i].health<=0 && now>=activeCamps[i].respawnTime)
                {
                    activeCamps[i].health=100;
                    activeCamps[i].natureTroops=GenerateNatureTroops(activeCamps[i].level);
                }
            }
        }
    }
}
