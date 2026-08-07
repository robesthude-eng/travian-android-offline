using TravianOffline.Data;
using UnityEngine;

namespace TravianOffline.Economy
{
    public static class ProductionCalculator
    {
        // Simplified table from GDD
        static int[] prodTable = {0,5,12,22,35,55,85,120,165,220,300,390,500,630,780,960,1160,1380,1620,1880,2160};
        static int[] cropTable = {0,5,14,26,42,65,100,145,200,270,370,480,620,790,980,1210,1470,1750,2060,2390,2750};

        public static int GetFieldProduction(ResType type, int level)
        {
            level = Mathf.Clamp(level,0,20);
            if(type==ResType.Crop) return cropTable[level];
            return prodTable[level];
        }

        public static Resources GetVillageProduction(Village v)
        {
            Resources r = new Resources();
            foreach(var f in v.fields)
            {
                int p = GetFieldProduction(f.type, f.level);
                switch(f.type)
                {
                    case ResType.Wood: r.Wood+=p; break;
                    case ResType.Clay: r.Clay+=p; break;
                    case ResType.Iron: r.Iron+=p; break;
                    case ResType.Crop: r.Crop+=p; break;
                }
            }
            // bonuses
            float woodBonus = HasBuilding(v,"sawmill") ? 1.25f : 1f;
            float clayBonus = HasBuilding(v,"brickyard") ? 1.25f : 1f;
            float ironBonus = HasBuilding(v,"ironFoundry") ? 1.25f : 1f;
            float cropBonus = 1f;
            if(HasBuilding(v,"grainMill")) cropBonus+=0.25f;
            if(HasBuilding(v,"bakery")) cropBonus+=0.5f;

            r.Wood = Mathf.RoundToInt(r.Wood*woodBonus);
            r.Clay = Mathf.RoundToInt(r.Clay*clayBonus);
            r.Iron = Mathf.RoundToInt(r.Iron*ironBonus);
            r.Crop = Mathf.RoundToInt(r.Crop*cropBonus);

            // oasis bonus later +25%

            return r;
        }

        static bool HasBuilding(Village v, string id)
        {
            foreach(var s in v.buildingSlots) if(s.buildingId==id && s.level>=1) return true;
            return false;
        }
    }
}
