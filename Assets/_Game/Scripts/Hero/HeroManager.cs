using System;
using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Hero
{
    public enum HeroAttribute { Strength, Defense, ResourceBonus, Speed }

    [Serializable]
    public class HeroEquipment
    {
        public string slot; // helmet, armor, weapon, boots, horse, shield
        public string itemId;
        public int attackBonus;
        public int defenseBonus;
        public int speedBonus;
        public int resourceBonus;
    }

    public class HeroManager : MonoBehaviour
    {
        public static HeroManager Instance;
        public HeroData hero;
        public List<HeroEquipment> equipment = new List<HeroEquipment>();
        public List<string> inventory = new List<string>(); // itemIds from camps
        public Action OnHeroChanged;

        void Awake(){ Instance=this; }

        public void Init(HeroData data){ hero=data; if(hero.level==0) hero.level=1; }

        public void AddXp(int xp)
        {
            hero.xp+=xp;
            int xpForNext = hero.level*100;
            while(hero.xp>=xpForNext)
            {
                hero.xp-=xpForNext;
                hero.level++;
                Debug.Log($"[Hero] Level up! {hero.level}");
                // give attribute point
                xpForNext=hero.level*100;
            }
            OnHeroChanged?.Invoke();
        }

        public float GetAttackBonus()
        {
            float bonus=0;
            foreach(var eq in equipment) bonus+=eq.attackBonus;
            bonus+=hero.strength*0.5f; // each strength point +0.5%?
            return 1f + bonus/100f;
        }

        public float GetDefenseBonus()
        {
            float bonus=0;
            foreach(var eq in equipment) bonus+=eq.defenseBonus;
            bonus+=hero.defense*0.5f;
            return 1f + bonus/100f;
        }

        public int GetSpeedBonus()
        {
            int speed=0;
            foreach(var eq in equipment) speed+=eq.speedBonus;
            return speed;
        }

        public void Equip(HeroEquipment item)
        {
            // remove existing in slot
            equipment.RemoveAll(e=>e.slot==item.slot);
            equipment.Add(item);
            OnHeroChanged?.Invoke();
        }

        public void AddLoot(string itemId)
        {
            inventory.Add(itemId);
            Debug.Log($"[Hero] Loot {itemId}");
        }

        public void UseAttributePoint(HeroAttribute attr)
        {
            switch(attr)
            {
                case HeroAttribute.Strength: hero.strength++; break;
                case HeroAttribute.Defense: hero.defense++; break;
                case HeroAttribute.ResourceBonus: hero.resourceBonus++; break;
                case HeroAttribute.Speed: /* speed */ break;
            }
            OnHeroChanged?.Invoke();
        }

        public void OnHeroDied()
        {
            hero.isDead=true;
            hero.reviveTime=DateTime.UtcNow.AddHours(1);
            Debug.Log("[Hero] Died, revive in 1h");
        }

        public void Revive()
        {
            if(DateTime.UtcNow>=hero.reviveTime){ hero.isDead=false; }
        }
    }
}
