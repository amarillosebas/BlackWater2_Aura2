using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace LuxWater {

	[RequireComponent(typeof(Camera))]
	public class LuxWater_UnderWaterRendering : MonoBehaviour {


		public static LuxWater_UnderWaterRendering instance;

		[Space(8)]
		public Transform Sun;

		[Space(8)]
        [System.NonSerialized]
        public int activeWaterVolume = -1;
		[System.NonSerialized]
		public float WaterSurfacePos = 0.0f;

		[Space(8)]
		[System.NonSerialized]
		public List<LuxWater_WaterVolume> RegisteredWaterVolumes = new List<LuxWater_WaterVolume>();
		private List<Mesh> WaterMeshes = new List<Mesh>();
		private List<Transform> WaterTransforms = new List<Transform>();
		private List<Material> WaterMaterials = new List<Material>();

		private RenderTexture UnderWaterMask;

		[Space(2)]
		[Header("Managed transparent Materials")]
		[Space(4)]
		public List<Material> m_aboveWatersurface = new List<Material>();
		public List<Material> m_belowWatersurface = new List<Material>();
		
		[Space(2)]
		[Header("Debug")]
		[Space(4)]
		public bool enableDebug = false;
		[Space(8)]

		private Material mat;
		private Material blurMaterial;
		private Material blitMaterial;
		
		private Camera cam;
		private Transform camTransform;
		private Matrix4x4 frustumCornersArray = Matrix4x4.identity;

		private SphericalHarmonicsL2 ambientProbe;
		private Vector3[] directions = new Vector3[] { new Vector3(0.0f, 1.0f, 0.0f) };
		private Color[] AmbientLightingSamples = new Color[1];


	// Metal Support
	// We have to manually grab the depth texture
		private CommandBuffer cb_DepthGrab;
		private CommandBuffer cb_AfterFinalPass;
		
		//public RenderTexture GrabbedScreen;
		private bool DoUnderWaterRendering = false;
		private Matrix4x4 camProj;
		private Vector3[] frustumCorners = new Vector3[4];


		private int UnderWaterMaskPID;
		private int Lux_FrustumCornersWSPID;
		private int Lux_CameraWSPID;

		private int GerstnerEnabledPID;
		private int LuxWaterMask_GerstnerVertexIntensityPID;
			private int GerstnerVertexIntensityPID;
		private int LuxWaterMask_GAmplitudePID;
			private int GAmplitudePID;
		private int LuxWaterMask_GFinalFrequencyPID;
			private int GFinalFrequencyPID;
		private int LuxWaterMask_GSteepnessPID;
			private int GSteepnessPID;
		private int LuxWaterMask_GFinalSpeedPID;
			private int GFinalSpeedPID;
		private int LuxWaterMask_GDirectionABPID;
			private int GDirectionABPID;
		private int LuxWaterMask_GDirectionCDPID;
			private int GDirectionCDPID;

		private int Lux_UnderWaterAmbientSkyLightPID;

		private int Lux_UnderWaterSunColorPID;
		private int Lux_UnderWaterSunDirPID;

		private int Lux_EdgeLengthPID;
		private int Lux_PhongPID;
		private int Lux_WaterMeshScalePID;

		private int Lux_CausticsEnabledPID;
		private int Lux_CausticModePID;
		private int Lux_UnderWaterFogColorPID;
		private int Lux_UnderWaterFogDensityPID;
		private int Lux_UnderWaterFogAbsorptionCancellationPID;
		private int Lux_UnderWaterAbsorptionHeightPID;
		private int Lux_UnderWaterAbsorptionMaxHeightPID;

        private bool islinear = false;

		// Use this for initialization
		void OnEnable () {
			if(instance != null) {
				Destroy(this);
			}
			else {
				instance = this;
			}
			mat = new Material(Shader.Find("Lux Water/WaterMask"));
			blurMaterial = new Material(Shader.Find("Lux Water/BlurEffectConeTap")); //Ceto/BlurEffectConeTap"));
			blitMaterial = new Material(Shader.Find("Lux Water/UnderWaterPost"));
		//	Metal support – make sure the canera actually renders a depth texture
			cam = GetComponent<Camera>();
			cam.depthTextureMode |= DepthTextureMode.Depth;

			camTransform = this.transform;

			UnderWaterMaskPID = Shader.PropertyToID("_UnderWaterMask");
			Lux_FrustumCornersWSPID = Shader.PropertyToID("_Lux_FrustumCornersWS");
			Lux_CameraWSPID = Shader.PropertyToID("_Lux_CameraWS");

			GerstnerEnabledPID = Shader.PropertyToID("_GerstnerEnabled");

			LuxWaterMask_GerstnerVertexIntensityPID = Shader.PropertyToID("_LuxWaterMask_GerstnerVertexIntensity");
				GerstnerVertexIntensityPID = Shader.PropertyToID("_GerstnerVertexIntensity");
			LuxWaterMask_GAmplitudePID = Shader.PropertyToID("_LuxWaterMask_GAmplitude");
				GAmplitudePID = Shader.PropertyToID("_GAmplitude");
			LuxWaterMask_GFinalFrequencyPID = Shader.PropertyToID("_LuxWaterMask_GFinalFrequency");
				GFinalFrequencyPID = Shader.PropertyToID("_GFinalFrequency");
			LuxWaterMask_GSteepnessPID = Shader.PropertyToID("_LuxWaterMask_GSteepness");
				GSteepnessPID = Shader.PropertyToID("_GSteepness");
			LuxWaterMask_GFinalSpeedPID = Shader.PropertyToID("_LuxWaterMask_GFinalSpeed");
				GFinalSpeedPID = Shader.PropertyToID("_GFinalSpeed");
			LuxWaterMask_GDirectionABPID = Shader.PropertyToID("_LuxWaterMask_GDirectionAB");
				GDirectionABPID = Shader.PropertyToID("_GDirectionAB");
			LuxWaterMask_GDirectionCDPID = Shader.PropertyToID("_LuxWaterMask_GDirectionCD");
				GDirectionCDPID = Shader.PropertyToID("_GDirectionCD");

			Lux_UnderWaterAmbientSkyLightPID = Shader.PropertyToID("_Lux_UnderWaterAmbientSkyLight");

			Lux_UnderWaterSunColorPID = Shader.PropertyToID("_Lux_UnderWaterSunColor");
			Lux_UnderWaterSunDirPID = Shader.PropertyToID("_Lux_UnderWaterSunDir");

			Lux_EdgeLengthPID = Shader.PropertyToID("_LuxWater_EdgeLength");
			Lux_PhongPID = Shader.PropertyToID("_LuxWater_Phong");
			Lux_WaterMeshScalePID = Shader.PropertyToID("_LuxWater_MeshScale");

			Lux_CausticsEnabledPID = Shader.PropertyToID("_CausticsEnabled");
			Lux_CausticModePID = Shader.PropertyToID("_CausticMode");
			Lux_UnderWaterFogColorPID = Shader.PropertyToID("_Lux_UnderWaterFogColor");
			Lux_UnderWaterFogDensityPID = Shader.PropertyToID("_Lux_UnderWaterFogDensity");
			Lux_UnderWaterFogAbsorptionCancellationPID = Shader.PropertyToID("_Lux_UnderWaterFogAbsorptionCancellation");
			Lux_UnderWaterAbsorptionHeightPID = Shader.PropertyToID("_Lux_UnderWaterAbsorptionHeight");
		    Lux_UnderWaterAbsorptionMaxHeightPID = Shader.PropertyToID("_Lux_UnderWaterAbsorptionMaxHeight");

            islinear = (QualitySettings.desiredColorSpace == ColorSpace.Linear) ? true : false;

		}


		void OnDisable () {
			instance = null;
			if(UnderWaterMask != null) {
				UnderWaterMask = null;
			}
			if(mat)
				DestroyImmediate(mat);
			if(blurMaterial)
				DestroyImmediate(blurMaterial);
			if(blitMaterial)
				DestroyImmediate(blitMaterial);
		}

		public void RegisterWaterVolume(LuxWater_WaterVolume item) {
			RegisteredWaterVolumes.Add(item);
			WaterMeshes.Add(item.WaterVolumeMesh);
			WaterMaterials.Add(item.transform.GetComponent<Renderer>().sharedMaterial);
			WaterTransforms.Add(item.transform);
		}

		public void DeRegisterWaterVolume(LuxWater_WaterVolume item) {
			int index = RegisteredWaterVolumes.IndexOf(item);

			if (activeWaterVolume == index) {
				activeWaterVolume = -1;
			}

			RegisteredWaterVolumes.RemoveAt(index);
			WaterMeshes.RemoveAt(index);
			WaterMaterials.RemoveAt(index);
			WaterTransforms.RemoveAt(index);
		}

		public void EnteredWaterVolume (LuxWater_WaterVolume item) {
			DoUnderWaterRendering = true;
			int index = RegisteredWaterVolumes.IndexOf(item);
			if(index != activeWaterVolume) {
				activeWaterVolume = index;
				WaterSurfacePos = WaterTransforms[activeWaterVolume].position.y;
			//	Update Transparents
				for (int i = 0; i < m_aboveWatersurface.Count; i++) {
					m_aboveWatersurface[i].renderQueue = 2998;
				}
				for (int i = 0; i < m_belowWatersurface.Count; i++) {
					m_belowWatersurface[i].renderQueue = 3001;
				}
			}
		}

		public void LeftWaterVolume (LuxWater_WaterVolume item) {
			DoUnderWaterRendering = false;
			int index = RegisteredWaterVolumes.IndexOf(item);
			if (activeWaterVolume == index) {
				activeWaterVolume = -1;
			//	Update Transparents
				for (int i = 0; i < m_aboveWatersurface.Count; i++) {
					m_aboveWatersurface[i].renderQueue = 3000;
				}
				for (int i = 0; i < m_belowWatersurface.Count; i++) {
					m_belowWatersurface[i].renderQueue = 2998;
				}
			}
		}


		void OnPreCull () {
			
		//	Make sure we do not get the scene camera...
			cam = GetComponent<Camera>();
			cam.depthTextureMode |= DepthTextureMode.Depth;
			camTransform = cam.transform;

		//	As we need _Time when drawing the Underwatermask (Gerstner Waves) we have to use a custom _Lux_Time as _Time will not be updated OnPreCull
			Shader.SetGlobalFloat("_Lux_Time", Time.timeSinceLevelLoad); // .time

			/*
		//	Check if the CommandBuffer already exists
			if (cb_DepthGrab == null) {
				//var commandBuffers = cam.GetCommandBuffers(CameraEvent.BeforeForwardAlpha);
				var commandBuffers = cam.GetCommandBuffers(CameraEvent.AfterSkybox); //AfterImageEffectsOpaque); // this is where deferred fog gets rendered
				for(int i = 0; i < commandBuffers.Length; i++) {
					if(commandBuffers[i].name == "Lux Water Grab Depth") {
						cb_DepthGrab = commandBuffers[i];
						break;
					}
				}
			}
			if (cb_DepthGrab == null) {
				cb_DepthGrab = new CommandBuffer();
				cb_DepthGrab.name = "Lux Water Grab Depth";
				cam.AddCommandBuffer(CameraEvent.AfterSkybox, cb_DepthGrab);
			}
			cb_DepthGrab.Clear();
			int depthGrabID = Shader.PropertyToID("_Lux_GrabbedDepth");
			cb_DepthGrab.GetTemporaryRT(depthGrabID, -1, -1, 0, FilterMode.Point, RenderTextureFormat.DefaultHDR, RenderTextureReadWrite.Linear);
			cb_DepthGrab.Blit(BuiltinRenderTextureType.CameraTarget, depthGrabID);
			*/

		//	Setup UnderWaterMask and SetRenderTarget upfront to prevent spikes.
			if (!UnderWaterMask) {
				UnderWaterMask = new RenderTexture(cam.pixelWidth, cam.pixelHeight, 24, RenderTextureFormat.ARGB32,  RenderTextureReadWrite.Linear);
			}
			else if (UnderWaterMask.width != cam.pixelWidth) {
				UnderWaterMask = new RenderTexture(cam.pixelWidth, cam.pixelHeight, 24, RenderTextureFormat.ARGB32,  RenderTextureReadWrite.Linear);
			}
			Graphics.SetRenderTarget(UnderWaterMask);
			
		//	Set frustum corners – which are needed to reconstruct the world position in the underwater post shader.
		//	As this spikes as hell when a volume gets active we simply do it all the time.
	        UnityEngine.Profiling.Profiler.BeginSample("Set up Frustum Corners");
		        cam.CalculateFrustumCorners(new Rect(0, 0, 1, 1), cam.farClipPlane, cam.stereoActiveEye, frustumCorners);
		        var bottomLeft = camTransform.TransformVector(frustumCorners[0]);
		        var topLeft = camTransform.TransformVector(frustumCorners[1]);
		        var topRight = camTransform.TransformVector(frustumCorners[2]);
		        var bottomRight = camTransform.TransformVector(frustumCorners[3]);

		        frustumCornersArray.SetRow(0, bottomLeft);
		        frustumCornersArray.SetRow(1, bottomRight);
		        frustumCornersArray.SetRow(2, topLeft);
		        frustumCornersArray.SetRow(3, topRight);

		        Shader.SetGlobalMatrix(Lux_FrustumCornersWSPID, frustumCornersArray);
		        Shader.SetGlobalVector(Lux_CameraWSPID, camTransform.position);
	        UnityEngine.Profiling.Profiler.EndSample();

		
		//	Render UnderWaterMask
			if(DoUnderWaterRendering && activeWaterVolume > -1) {

			//	Tell all shaders that underwater rendering is active (like e.g. fog shaders)
				Shader.EnableKeyword("LUXWATERENABLED");

				UnityEngine.Profiling.Profiler.BeginSample("Set up Gerstner");
				//	Gerstner Waves
					if (WaterMaterials[activeWaterVolume].GetFloat(GerstnerEnabledPID) == 1.0f) {
						mat.EnableKeyword("GERSTNERENABLED");
						mat.SetVector(LuxWaterMask_GerstnerVertexIntensityPID, WaterMaterials[activeWaterVolume].GetVector(GerstnerVertexIntensityPID) );
						mat.SetVector(LuxWaterMask_GAmplitudePID, WaterMaterials[activeWaterVolume].GetVector(GAmplitudePID) );
						mat.SetVector(LuxWaterMask_GFinalFrequencyPID, WaterMaterials[activeWaterVolume].GetVector(GFinalFrequencyPID) );
						mat.SetVector(LuxWaterMask_GSteepnessPID, WaterMaterials[activeWaterVolume].GetVector(GSteepnessPID) );
						mat.SetVector(LuxWaterMask_GFinalSpeedPID, WaterMaterials[activeWaterVolume].GetVector(GFinalSpeedPID) );
						mat.SetVector(LuxWaterMask_GDirectionABPID, WaterMaterials[activeWaterVolume].GetVector(GDirectionABPID) );
						mat.SetVector(LuxWaterMask_GDirectionCDPID, WaterMaterials[activeWaterVolume].GetVector(GDirectionCDPID) );
					}
					else {
						mat.DisableKeyword("GERSTNERENABLED");
					}
				UnityEngine.Profiling.Profiler.EndSample();

			//	Draw UnderWaterMask

				//Graphics.SetRenderTarget(UnderWaterMask); // As this spikes when a volumes gets activated it has been taken out of the if.
				GL.Clear(true, true, Color.black, 1);
				camProj = cam.projectionMatrix;
				GL.LoadProjectionMatrix(camProj);

				mat.SetPass(0);
				Graphics.DrawMeshNow( WaterMeshes[activeWaterVolume], WaterTransforms[activeWaterVolume].localToWorldMatrix, 0); // submesh 0 = Water box volume
				
				bool useTessellation = WaterMaterials[activeWaterVolume].HasProperty(Lux_EdgeLengthPID);

				if (useTessellation) {
					mat.SetFloat(Lux_EdgeLengthPID, WaterMaterials[activeWaterVolume].GetFloat(Lux_EdgeLengthPID));
					mat.SetFloat(Lux_PhongPID, WaterMaterials[activeWaterVolume].GetFloat(Lux_PhongPID));
					
					var scale = WaterTransforms[activeWaterVolume].lossyScale;
					var maxScale = (float)Math.Max(scale.x, Math.Max(scale.y, scale.z));
					mat.SetFloat(Lux_WaterMeshScalePID, 1.0f / maxScale);
					
					mat.SetPass(3);
				}
				else {
					mat.SetPass(1);
				}
				Graphics.DrawMeshNow( WaterMeshes[activeWaterVolume], WaterTransforms[activeWaterVolume].localToWorldMatrix, 1); // submesh 1 = Water surface from above
				
				if (useTessellation) {
					mat.SetPass(4);
				}
				else {
					mat.SetPass(2);
				}
				Graphics.DrawMeshNow( WaterMeshes[activeWaterVolume], WaterTransforms[activeWaterVolume].localToWorldMatrix, 1); // submesh 1 = Water surface from below
				Shader.SetGlobalTexture(UnderWaterMaskPID, UnderWaterMask);
			}

			else {
				Shader.DisableKeyword("LUXWATERENABLED");
			}

		//	Set ambient lighting.
	        ambientProbe = RenderSettings.ambientProbe;
	        ambientProbe.Evaluate(directions, AmbientLightingSamples);
            if (islinear)
	            Shader.SetGlobalColor(Lux_UnderWaterAmbientSkyLightPID, (AmbientLightingSamples[0] * RenderSettings.ambientIntensity).linear);
            else
                Shader.SetGlobalColor(Lux_UnderWaterAmbientSkyLightPID, AmbientLightingSamples[0] * RenderSettings.ambientIntensity);
        }

		[ImageEffectOpaque]
		void OnRenderImage(RenderTexture src, RenderTexture dest) {
			if(Sun) {
				Vector3 SunDir = -Sun.forward;
                var SunLight = Sun.GetComponent<Light>();
                Color SunColor = SunLight.color * SunLight.intensity;
                if (islinear) {
                    SunColor = SunColor.linear;
                }
				Shader.SetGlobalColor(Lux_UnderWaterSunColorPID, (SunColor) * Mathf.Clamp01( Vector3.Dot(SunDir, Vector3.up) )  );
				Shader.SetGlobalVector(Lux_UnderWaterSunDirPID, -SunDir );
			}

			if(DoUnderWaterRendering && activeWaterVolume > -1) {

				if (WaterMaterials[activeWaterVolume].GetFloat(Lux_CausticsEnabledPID) == 1) {
					blitMaterial.EnableKeyword("GEOM_TYPE_FROND");
					if (WaterMaterials[activeWaterVolume].GetFloat(Lux_CausticModePID) == 1) {
						blitMaterial.EnableKeyword("GEOM_TYPE_LEAF");
					}
					else {
						blitMaterial.DisableKeyword("GEOM_TYPE_LEAF");
					}
				}
				else {
					blitMaterial.DisableKeyword("GEOM_TYPE_FROND");
				}

                if (islinear)
				    Shader.SetGlobalColor(Lux_UnderWaterFogColorPID, WaterMaterials[activeWaterVolume].GetColor("_Color").linear );
                else
                    Shader.SetGlobalColor(Lux_UnderWaterFogColorPID, WaterMaterials[activeWaterVolume].GetColor("_Color"));

                Shader.SetGlobalFloat(Lux_UnderWaterFogDensityPID, WaterMaterials[activeWaterVolume].GetFloat("_Density") );
				Shader.SetGlobalFloat(Lux_UnderWaterFogAbsorptionCancellationPID, WaterMaterials[activeWaterVolume].GetFloat("_FogAbsorptionCancellation") );

				Shader.SetGlobalFloat(Lux_UnderWaterAbsorptionHeightPID, WaterMaterials[activeWaterVolume].GetFloat("_AbsorptionHeight") );
				Shader.SetGlobalFloat(Lux_UnderWaterAbsorptionMaxHeightPID, WaterMaterials[activeWaterVolume].GetFloat("_AbsorptionMaxHeight") );

				Shader.SetGlobalFloat("_Lux_UnderWaterAbsorptionDepth", WaterMaterials[activeWaterVolume].GetFloat("_AbsorptionDepth") );
				Shader.SetGlobalFloat("_Lux_UnderWaterAbsorptionColorStrength", WaterMaterials[activeWaterVolume].GetFloat("_AbsorptionColorStrength") );
				Shader.SetGlobalFloat("_Lux_UnderWaterAbsorptionStrength", WaterMaterials[activeWaterVolume].GetFloat("_AbsorptionStrength") );

				Shader.SetGlobalTexture("_Lux_UnderWaterCaustics", WaterMaterials[activeWaterVolume].GetTexture("_CausticTex") );
                Shader.SetGlobalFloat("_Lux_UnderWaterCausticsTiling", WaterMaterials[activeWaterVolume].GetFloat("_CausticsTiling"));
                Shader.SetGlobalFloat("_Lux_UnderWaterCausticsScale", WaterMaterials[activeWaterVolume].GetFloat("_CausticsScale") );
				Shader.SetGlobalFloat("_Lux_UnderWaterCausticsSpeed", WaterMaterials[activeWaterVolume].GetFloat("_CausticsSpeed") );
				Shader.SetGlobalFloat("_Lux_UnderWaterCausticsTiling", WaterMaterials[activeWaterVolume].GetFloat("_CausticsTiling") );
				Shader.SetGlobalFloat("_Lux_UnderWaterCausticsSelfDistortion", WaterMaterials[activeWaterVolume].GetFloat("_CausticsSelfDistortion") );
				Shader.SetGlobalVector("_Lux_UnderWaterFinalBumpSpeed01", WaterMaterials[activeWaterVolume].GetVector("_FinalBumpSpeed01") );

				blitMaterial.SetFloat("_Lux_UnderWaterWaterSurfacePos", WaterSurfacePos);
				blitMaterial.SetVector("_Lux_UnderWaterFogDepthAtten", WaterMaterials[activeWaterVolume].GetVector("_DepthAtten"));

			//	Copy Screen into RT and calculate fog and color attenuation
				RenderTexture UnderwaterTex = RenderTexture.GetTemporary(src.width, src.height, 0, RenderTextureFormat.DefaultHDR); //, RenderTextureReadWrite.Linear);
				Graphics.Blit(src, UnderwaterTex, blitMaterial, 0);
				Shader.SetGlobalTexture("_UnderWaterTex", UnderwaterTex);

            //	Combine source texture and UnderwaterTex based on the Underwatermask in UnderwaterTex.a
                Graphics.Blit(src, dest, blitMaterial, 1);
				RenderTexture.ReleaseTemporary(UnderwaterTex);
			}

		//	We have to blit in any case - otherwise the screen will be black.
			else {
				Graphics.Blit(src, dest);
			}
		}


		#if UNITY_EDITOR
			void OnDrawGizmos() {
				if (enableDebug) {
					if(cam == null || UnderWaterMask == null || activeWaterVolume == -1)
						return;

			      	int textureDrawWidth = (int)(cam.aspect * 128.0f);
			        GL.PushMatrix();
			        GL.LoadPixelMatrix(0, Screen.width, Screen.height, 0);
			        Graphics.DrawTexture(new Rect(0, 0, textureDrawWidth, 128), UnderWaterMask);
			        GL.PopMatrix();
			    }
			}

            void OnGUI() {
                if(enableDebug) {
                    var Alignement = GUI.skin.label.alignment;
                    GUI.skin.label.alignment = TextAnchor.MiddleLeft;
                    if (activeWaterVolume == -1) {
                    	GUI.Label(new Rect(10, 0, 160, 40), "Active water volume: none" );	
                    }
                    else {
                    	GUI.Label(new Rect(10, 0, 300, 40), "Active water volume: " + RegisteredWaterVolumes[activeWaterVolume].transform.gameObject.name ); //+ activeWaterVolume.ToString() );
                    }
                    GUI.skin.label.alignment = Alignement;
                }
            }
		#endif

	}
}
