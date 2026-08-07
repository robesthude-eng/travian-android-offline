using System;

namespace TravianOffline.Data
{
    public enum ResType { Wood, Clay, Iron, Crop }
    public enum Tribe { Romans, Gauls, Germans }

    [Serializable]
    public struct Resources
    {
        public int Wood;
        public int Clay;
        public int Iron;
        public int Crop;

        public int Get(ResType t) => t switch
        {
            ResType.Wood => Wood,
            ResType.Clay => Clay,
            ResType.Iron => Iron,
            ResType.Crop => Crop,
            _ => 0
        };
        public void Set(ResType t, int v)
        {
            switch(t){ case ResType.Wood: Wood=v; break; case ResType.Clay: Clay=v; break; case ResType.Iron: Iron=v; break; case ResType.Crop: Crop=v; break; }
        }
        public static Resources operator +(Resources a, Resources b) => new Resources{Wood=a.Wood+b.Wood, Clay=a.Clay+b.Clay, Iron=a.Iron+b.Iron, Crop=a.Crop+b.Crop};
        public static Resources operator -(Resources a, Resources b) => new Resources{Wood=a.Wood-b.Wood, Clay=a.Clay-b.Clay, Iron=a.Iron-b.Iron, Crop=a.Crop-b.Crop};
        public bool CanAfford(Resources cost) => Wood>=cost.Wood && Clay>=cost.Clay && Iron>=cost.Iron && Crop>=cost.Crop;
        public int Sum() => Wood+Clay+Iron+Crop;
    }
}
