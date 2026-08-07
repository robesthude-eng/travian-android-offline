using UnityEngine;
using TravianOffline.Data;
using System;

namespace TravianOffline.Economy
{
    public class ResourceManager : MonoBehaviour
    {
        public static ResourceManager Instance;
        public Action<Village> OnResourcesChanged;

        void Awake(){ Instance=this; }

        void Start(){ InvokeRepeating(nameof(TickProduction),1f,1f); }

        void TickProduction()
        {
            var gm = GameManager.Instance;
            if(gm==null) return;
            var v = gm.CurrentVillage;
            var prod = ProductionCalculator.GetVillageProduction(v);
            // per second
            float woodSec = prod.Wood/3600f;
            float claySec = prod.Clay/3600f;
            float ironSec = prod.Iron/3600f;
            float cropSec = (prod.Crop - v.population)/3600f; // net

            v.resources.Wood = Mathf.Min(v.warehouseCapacity, v.resources.Wood + Mathf.RoundToInt(woodSec));
            v.resources.Clay = Mathf.Min(v.warehouseCapacity, v.resources.Clay + Mathf.RoundToInt(claySec));
            v.resources.Iron = Mathf.Min(v.warehouseCapacity, v.resources.Iron + Mathf.RoundToInt(ironSec));
            v.resources.Crop = Mathf.Clamp(v.resources.Crop + Mathf.RoundToInt(cropSec),0,v.granaryCapacity);

            OnResourcesChanged?.Invoke(v);
        }

        public bool CanAfford(Village v, Resources cost) => v.resources.CanAfford(cost);
        public void Pay(Village v, Resources cost) { v.resources = v.resources - cost; OnResourcesChanged?.Invoke(v); }
        public void Add(Village v, Resources gain) { v.resources = v.resources + gain; OnResourcesChanged?.Invoke(v); }
    }
}
