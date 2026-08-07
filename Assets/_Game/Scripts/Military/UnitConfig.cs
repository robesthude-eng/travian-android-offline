using UnityEngine;

namespace TravianOffline.Configs
{
    [CreateAssetMenu(menuName="Travian/UnitConfig")]
    public class UnitConfig : ScriptableObject
    {
        public string id;
        public string displayName;
        public int attack;
        public int defInf;
        public int defCav;
        public int speed; // fields per hour
        public int carry;
        public int cropConsumption;
        public Data.Resources cost;
        public float trainTimeSec;
        public string requiredBuilding; // barracks, stable etc
        public int requiredBuildingLevel;
    }
}
