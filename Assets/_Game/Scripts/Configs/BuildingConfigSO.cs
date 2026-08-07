using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Configs
{
    [CreateAssetMenu(menuName="Travian/BuildingConfig")]
    public class BuildingConfigSO : ScriptableObject
    {
        public string id;
        public string displayName;
        public int maxLevel = 20;
        public Resources baseCost;
        public float baseTimeSec = 100f;
        public int populationPerLevel = 1;
        public Sprite icon;
        public Sprite[] lodSprites; // 0=1-5, 1=6-15, 2=16-20
        public string[] requiresBuildingIds;
        public int[] requiresLevels;

        public Resources GetCostForLevel(int lvl) => new Resources{
            Wood=Mathf.RoundToInt(baseCost.Wood*Mathf.Pow(1.28f,lvl-1)),
            Clay=Mathf.RoundToInt(baseCost.Clay*Mathf.Pow(1.28f,lvl-1)),
            Iron=Mathf.RoundToInt(baseCost.Iron*Mathf.Pow(1.28f,lvl-1)),
            Crop=Mathf.RoundToInt(baseCost.Crop*Mathf.Pow(1.28f,lvl-1))
        };

        public float GetTimeForLevel(int lvl, int mainBuildingLvl)
        {
            float t = baseTimeSec * Mathf.Pow(1.3f, lvl-1) / (1f + mainBuildingLvl*0.05f);
            return Mathf.Max(30f,t);
        }
    }
}
