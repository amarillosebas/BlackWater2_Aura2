using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace LuxWater {

	public class LuxWater_WaterVolume : MonoBehaviour {

		public Mesh WaterVolumeMesh;
		public bool UsesTessellation = false;
		private LuxWater_UnderWaterRendering waterrendermanager;
		private bool readyToGo = false;

		void OnEnable () {
			if (WaterVolumeMesh == null) {
				Debug.Log("No WaterVolumeMesh assigned.");
				return;
			}
		//	Register with LuxWater_UnderWaterRendering singleton – using invoke just in order to get around script execution order problems
			Invoke("Register", 0.0f);

		//	Config water material so it uses fixed watersurface position and _Lux_Time
			var waterMat = GetComponent<Renderer>().sharedMaterial;
			waterMat.EnableKeyword("USINGWATERVOLUME");
			waterMat.SetFloat("_WaterSurfaceYPos", this.transform.position.y);
		}

		void OnDisable () {
			if (waterrendermanager) {
				waterrendermanager.DeRegisterWaterVolume(this);
			}
			readyToGo = false;

			GetComponent<Renderer>().sharedMaterial.DisableKeyword("USINGWATERVOLUME");
		}

		void Register() {
			waterrendermanager = LuxWater_UnderWaterRendering.instance;
			waterrendermanager.RegisterWaterVolume(this);
			readyToGo = true;
		}


	// 	Handle collision between water volume and camera
		private void OnTriggerEnter(Collider other) {
	        var trigger = other.GetComponent<LuxWater_WaterVolumeTrigger>();
	        if (trigger != null && waterrendermanager != null && readyToGo) {
	        	if (trigger.active == true)
	        		waterrendermanager.EnteredWaterVolume(this);
	        }
	    }

	    private void OnTriggerStay(Collider other) {
	        var trigger = other.GetComponent<LuxWater_WaterVolumeTrigger>();
	        if (trigger != null && waterrendermanager != null && readyToGo) {
	        	if (trigger.active == true)
	        		waterrendermanager.EnteredWaterVolume(this);
	        }
	    }

	    private void OnTriggerExit(Collider other) {
	        var trigger = other.GetComponent<LuxWater_WaterVolumeTrigger>();
	        if (trigger != null && waterrendermanager != null && readyToGo) {
	        	if (trigger.active == true)
	        		waterrendermanager.LeftWaterVolume(this);
	        }
	    }

	/*
		void OnWillRenderObject () {
			//Debug.Log("Render " + Shader.GetGlobalVector("unity_SHBr"));

			UnityEngine.Rendering.SphericalHarmonicsL2 sh2 = RenderSettings.ambientProbe;
			//LightProbes.GetInterpolatedProbe(transform.position, null, out sh2);
			Vector3[] directions = new Vector3[] {
	            new Vector3(0.0f, 1.0f, 0.0f),
	            new Vector3(0.0f, -1.0f, 0.0f)
	        };
	        Color[] results = new Color[2];

	        sh2.Evaluate(directions, results);

	        //Debug.Log("Up " + results[0]);

	        Camera.main.depthTextureMode |= DepthTextureMode.Depth;
		}
	*/
		
	}
}
