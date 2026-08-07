using UnityEngine;
using TMPro;
using TravianOffline.Data;

namespace TravianOffline.UI
{
    public class UIManager : MonoBehaviour
    {
        public TextMeshProUGUI woodTxt, clayTxt, ironTxt, cropTxt, popTxt;
        public GameObject resourceView, villageView, mapView;

        void Start()
        {
            Economy.ResourceManager.Instance.OnResourcesChanged += UpdateTopBar;
            UpdateTopBar(GameManager.Instance.CurrentVillage);
        }

        void UpdateTopBar(Village v)
        {
            if(woodTxt) woodTxt.text = v.resources.Wood.ToString();
            if(clayTxt) clayTxt.text = v.resources.Clay.ToString();
            if(ironTxt) ironTxt.text = v.resources.Iron.ToString();
            if(cropTxt) cropTxt.text = $"{v.resources.Crop}/{v.granaryCapacity}";
            if(popTxt) popTxt.text = $"{v.population}";
        }

        public void ShowResourceView(){ resourceView.SetActive(true); villageView.SetActive(false); mapView.SetActive(false); }
        public void ShowVillageView(){ resourceView.SetActive(false); villageView.SetActive(true); mapView.SetActive(false); }
        public void ShowMapView(){ resourceView.SetActive(false); villageView.SetActive(false); mapView.SetActive(true); }

        public void OnBuildButtonClicked(int slotId)
        {
            Debug.Log($"Build clicked slot {slotId}");
            // open build menu
        }
    }
}
