using UnityEngine;
using TravianOffline.Data;

namespace TravianOffline.Economy
{
    public class ResourceField : MonoBehaviour
    {
        public int fieldIndex;
        public ResType type;
        public int level;

        public void Setup(ResourceFieldData data)
        {
            fieldIndex=data.index;
            type=data.type;
            level=data.level;
            UpdateVisual();
        }

        void UpdateVisual()
        {
            // swap sprite based on level: LOD1-3 from cut assets
            // here load from Resources or Addressables
        }

        void OnMouseDown()
        {
            Debug.Log($"Field {fieldIndex} {type} lvl {level} clicked");
            // UIManager.Instance.ShowBuildMenu for field
        }
    }
}
