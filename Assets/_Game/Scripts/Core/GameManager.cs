using UnityEngine;
using TravianOffline.Data;
using TravianOffline.Core;

namespace TravianOffline
{
    public class GameManager : MonoBehaviour
    {
        public static GameManager Instance;
        public SaveData save;
        float autoSaveTimer = 30f;

        void Awake()
        {
            if(Instance!=null){ Destroy(gameObject); return; }
            Instance=this;
            DontDestroyOnLoad(gameObject);
            Application.targetFrameRate=30;

            save = SaveSystem.Load();
            FindObjectOfType<TimeManager>()?.Init(save);
        }

        void Update()
        {
            autoSaveTimer -= Time.deltaTime;
            if(autoSaveTimer<=0)
            {
                SaveSystem.Save(save);
                autoSaveTimer=30f;
            }
        }

        void OnApplicationPause(bool pause){ if(pause) SaveSystem.Save(save); }
        void OnApplicationFocus(bool focus){ if(!focus) SaveSystem.Save(save); }
        void OnApplicationQuit(){ SaveSystem.Save(save); }

        public Village CurrentVillage => save.villages[save.currentVillageIndex];
    }
}
