using System.Collections.Generic;
using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Military
{
    public struct BattleInput
    {
        public Dictionary<string,int> attackers; // unitId -> count
        public Dictionary<string,int> defenders;
        public int wallLevel;
        public float wallFactor; // 0.05 rome
        public int smithLevel;
        public int armourLevel;
    }

    public struct BattleResult
    {
        public bool attackerWon;
        public Dictionary<string,int> attackerSurvivors;
        public Dictionary<string,int> defenderSurvivors;
        public int wallDamage;
        public Resources loot;
    }

    public static class CombatSimulator
    {
        // Simplified Travian formula for MVP, pure function for unit tests
        public static BattleResult Simulate(BattleInput input, System.Func<string, Configs.UnitConfig> getConfig)
        {
            float atk = 0, defInf = 0, defCav = 0;

            foreach(var kv in input.attackers)
            {
                var cfg = getConfig(kv.Key);
                if(cfg==null) continue;
                atk += kv.Value * cfg.attack * (1f + input.smithLevel*0.015f);
            }
            foreach(var kv in input.defenders)
            {
                var cfg = getConfig(kv.Key);
                if(cfg==null) continue;
                defInf += kv.Value * cfg.defInf * (1f + input.armourLevel*0.015f);
                defCav += kv.Value * cfg.defCav * (1f + input.armourLevel*0.015f);
            }

            float wallBonus = 1f + input.wallLevel * input.wallFactor;
            defInf *= wallBonus;
            defCav *= wallBonus;

            float totalDef = (defInf+defCav)*0.5f;
            float ratio = (totalDef<=0) ? 999f : atk/totalDef;
            float rand = Random.Range(0.9f,1.1f);
            ratio *= rand;

            var res = new BattleResult();
            res.attackerSurvivors = new Dictionary<string,int>();
            res.defenderSurvivors = new Dictionary<string,int>();

            if(ratio>1f) // attacker won
            {
                res.attackerWon=true;
                float attackerLossPct = 1f/ratio;
                foreach(var kv in input.attackers)
                {
                    int lost = Mathf.RoundToInt(kv.Value * attackerLossPct);
                    res.attackerSurvivors[kv.Key] = Mathf.Max(0, kv.Value - lost);
                }
                // defender loses all
                foreach(var kv in input.defenders) res.defenderSurvivors[kv.Key]=0;
                res.wallDamage = Mathf.Clamp(Mathf.RoundToInt(res.attackerSurvivors.Count*0.2f),0,3);
            }
            else
            {
                res.attackerWon=false;
                float defenderLossPct = ratio;
                foreach(var kv in input.attackers) res.attackerSurvivors[kv.Key]=0;
                foreach(var kv in input.defenders)
                {
                    int lost = Mathf.RoundToInt(kv.Value * defenderLossPct);
                    res.defenderSurvivors[kv.Key]=Mathf.Max(0, kv.Value - lost);
                }
                res.wallDamage = 0;
            }

            // loot calc if attacker won and raid
            int totalCarry=0;
            foreach(var kv in res.attackerSurvivors)
            {
                var cfg=getConfig(kv.Key);
                totalCarry+= kv.Value * cfg.carry;
            }
            res.loot = new Resources{ Wood=0, Clay=0, Iron=0, Crop=0 }; // filled in MovementManager

            return res;
        }
    }
}
