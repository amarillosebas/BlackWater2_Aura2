using UnityEngine;
using System.Collections.Generic;
using UnityEngine.Rendering;



namespace VolumetricClouds3
{
    [ExecuteInEditMode]
    public class RaymarchedClouds : MonoBehaviour
    {
        [Space(20)]
        public Material materialUsed;

        [Header("Plane")]
        public bool hidePlane = true;
        public float planeOffset = 0.01f;

        [Header("Editor")]
        public bool attachToEditorCam;
        public RaymarchedClouds editorCamScript;

        #if (UNITY_5_4_OR_NEWER)
            [Header("Render Lights")]
            public Light[] pointLights;
            Light[] lastPointLights;
            static Vector4[] emptyCleanupArray = new Vector4[64];
        #endif

        [Header("Split Shadow Rendering")]
        public bool splitShadowRendering;
        public Material materialShadows;
        public bool syncMaterial;
        public float shadowRenderOffset = 0.01f;
        
        [Space(10)]

        public bool activateHandleDrawing = false;
        
        // SerializeField + HideInInspector forces unity to serialize the plane and avoid discarding the reference to
        // it when exiting playmode, this has to be done to avoid leaking planes in editor since unity's hideflags aren't safe
        [SerializeField, HideInInspector] GameObject shadowPlane;
        [SerializeField, HideInInspector] GameObject plane;
        MeshRenderer mRendererShadow;
        MeshRenderer mRendererClouds;
        Camera thisCam;

        static List<RaymarchedClouds> instances = new List<RaymarchedClouds>();














        void Start()
        {
            if (materialUsed != null)
                ValidateRenderPlane();
            else if (materialUsed == null && Application.isPlaying)
                Debug.LogError("Object " + gameObject.name + " has a RaymarchedClouds attached to it but its specified material is null");

            #if (UNITY_EDITOR)
                // does not play well with OnDrawGizmos and PreRenderEvents, we still will have to find remnants before creating a new one.
                #if (UNITY_2017_2_OR_NEWER)
                    UnityEditor.EditorApplication.playModeStateChanged += (a) => Clear();
                    UnityEditor.EditorApplication.pauseStateChanged += (a) => Clear();
                #else
                    UnityEditor.EditorApplication.playmodeStateChanged += Clear;
                #endif
            #endif
        }

        void OnEnable()
        {
            PerformOldVersionCheck();
            instances.Add(this);
            #if (UNITY_5_4_OR_NEWER)
                if (instances.Count >= 1)
                    pointLights = instances[0].pointLights;
                lastPointLights = pointLights;
            #endif
            if (plane)
                plane.SetActive(true);
            if (shadowPlane)
                shadowPlane.SetActive(true);
        }

        void OnDisable()
        {
            instances.Remove(this);
            if (plane)
                plane.SetActive(false);
            if (shadowPlane)
                shadowPlane.SetActive(false);
        }

        void OnDestroy()
        {
            Clear();
        }

        void Clear()
        {
            DestroySafe(plane);
            DestroySafe(shadowPlane);
            DestroySafe(editorCamScript);
        }



        // Fix : Plane invisible on version 5.0 if enabled inside OnPreCull
        void LateUpdate()
        {
            #if (UNITY_5_4_OR_NEWER)

            #else
                if (mRendererClouds && Application.isPlaying)
                    mRendererClouds.enabled = true;
            #endif
        }

        void OnPreCull()
        {
            ValidatePointLights();
            if (materialUsed == null)
                return;
            PrepareRendering();
        }
        void OnPostRender()
        {
            if (hidePlane && !IsEditorCamera())
            {
                if (mRendererClouds)
                    mRendererClouds.enabled = false;
                if (splitShadowRendering && mRendererShadow)
                    mRendererShadow.enabled = false;
            }
        }

        void OnDrawGizmos()
        {
            PerformOldVersionCheck();
            ValidatePointLights();

            if (materialUsed == null)
                return;
            ValidateEditorCam();

            if(enabled)
                PrepareRendering();
        }

        void PrepareRendering()
        {
            ValidateRenderPlane();
            SetupShaderVariables();
        }

        void ValidateRenderPlane()
        {
            if (materialUsed == null)
                return;
            if (thisCam == null)
                thisCam = GetComponent<Camera>();
            LazyValidatePlane(ref plane, ref mRendererClouds, ref materialUsed, "VC2_RaymarchedCloudPlane");
            if (splitShadowRendering)
                ValidateSplitShadow();
            else if (shadowPlane != null)
                DestroySafe(shadowPlane);
            FitPlane(ref plane, ref shadowPlane);
        }

        void PerformOldVersionCheck()
        {
            #if (UNITY_EDITOR)
            if( UnityEditor.EditorPrefs.GetBool( "VC_USING_3_5+", false ) == false )
            {
                UnityEditor.EditorPrefs.SetBool("VC_USING_3_5+", true);
                UnityEditor.EditorUtility.DisplayDialog( "VolumetricClouds3", "If you were using version 3.0 of VolumetricClouds set your materials' 'New Shading' property to false.\nChange it back to true once you have the time to convert your materials to the new system.", "Ok" );
            }
            #endif
        }





















        void SetupShaderVariables()
        {
            // MANAGE LIGHTS
            #if (UNITY_5_4_OR_NEWER)
                if (pointLights != null && pointLights.Length > 0)
                {
                    Light[] visibleLights = ComputeVisibleLightToShader(pointLights, thisCam);
                    mRendererClouds.sharedMaterial.SetInt("_VisibleLightCount", visibleLights.Length);
                    if (visibleLights.Length != 0)
                    {
                        Vector4[] visibleLightTransform = new Vector4[visibleLights.Length];
                        Vector4[] visibleLightColor = new Vector4[visibleLights.Length];
                        for (int i = 0; i < visibleLights.Length; i++)
                        {
                            visibleLightTransform[i] = LightToSphere(visibleLights[i]);
                            visibleLightColor[i] = visibleLights[i].color * visibleLights[i].intensity;
                        }
                        // Setting arrays is broken atm, once it has been called the array size is capped to the first size and it seems to reset only on compile or something like that
                        // so we actually have to call an empty array which will set the maximum and then add the array that we want
                        mRendererClouds.sharedMaterial.SetVectorArray("_VisiblePointLights", emptyCleanupArray);
                        mRendererClouds.sharedMaterial.SetVectorArray("_VisiblePointLightsColor", emptyCleanupArray);

                        mRendererClouds.sharedMaterial.SetVectorArray("_VisiblePointLights", visibleLightTransform);
                        mRendererClouds.sharedMaterial.SetVectorArray("_VisiblePointLightsColor", visibleLightColor);
                    }
                }
                mRendererClouds.enabled = true;
            #endif



            if (splitShadowRendering)
            {
                mRendererShadow.enabled = true;
                if (materialShadows && syncMaterial)
                {
                    materialUsed.DisableKeyword("_RENDERSHADOWS");
                    materialUsed.DisableKeyword("_RENDERSHADOWSONLY");
                    materialUsed.SetInt("_RenderShadowsOnly", 0);
                    materialUsed.SetInt("_SSShadows", 0);

                    materialShadows.CopyPropertiesFromMaterial(materialUsed);
                    materialShadows.SetInt("_RenderShadowsOnly", 1);
                    materialShadows.SetInt("_SSShadows", 1);
                    materialShadows.EnableKeyword("_RENDERSHADOWS");
                    materialShadows.EnableKeyword("_RENDERSHADOWSONLY");
                }
            }
            
            #if UNITY_5_4_OR_NEWER
            #else
            {
                Material material = mRendererClouds.sharedMaterial;
                Matrix4x4 ivp = Matrix4x4.Inverse(GL.GetGPUProjectionMatrix(thisCam.projectionMatrix, false) * thisCam.worldToCameraMatrix);
                material.SetMatrix("unity_CameraToWorldFallback", ivp);
                if (splitShadowRendering && materialShadows)
                    materialShadows.SetMatrix("unity_CameraToWorldFallback", ivp);
            }
            #endif
        }


























        // POINT LIGHTS RELATED FUNCTIONS

        void ValidatePointLights()
        {
            #if (UNITY_5_4_OR_NEWER)
                if (pointLights != lastPointLights)
                {
                    lastPointLights = pointLights;
                    for (int i = 0; i < instances.Count; i++)
                    {
                        instances[i].UpdateLocalLights(pointLights);
                    }
                }
            #endif
        }


        #if (UNITY_5_4_OR_NEWER)
        Vector4 LightToSphere(Light light)
        {
            return new Vector4(light.transform.position.x, light.transform.position.y, light.transform.position.z, light.range);
        }

        Light[] ComputeVisibleLightToShader(Light[] lights, Camera cam)
        {
            List<Light> temp = new List<Light>();
            for (int i = 0; i < lights.Length; i++)
            {
                if (lights[i].type == LightType.Point)
                {
                    if (lights[i].enabled)
                    {
                        Vector3 pos = lights[i].transform.position;
                        float radius = lights[i].range;
                        if (IsPointLightLooselyInsideFrustum(pos, radius, cam))
                            temp.Add(lights[i]);
                    }
                }
                else
                {
                    Debug.LogError("Volumetric Clouds : " + lights[i].type + " is not supported.");
                }
            }
            return temp.ToArray();
        }

        bool IsPointLightLooselyInsideFrustum(Vector3 pos, float radius, Camera cam)
        {
            /*
            // Started writing sphere-view frustum intersection but don't really have time to finish it and it doesn't really matter at this point
            // Must be pre-computed outside method before using it to avoid wasting CPU cycles
            Vector3[] frustumEdge = new Vector3[4];
            Vector3[] frustumNormal = new Vector3[4];
            Vector3 initDir = new Vector3(-1, -1);
            Vector3 offsetDir = new Vector3(1, 1);
            for (int i = 0; i < 4; i++)
            {
                frustumEdge[i] = cam.ViewportPointToRay((Quaternion.AngleAxis(i * 90, cam.transform.forward) * initDir + offsetDir) * 0.5f).direction;
            }

            for (int i = 0; i < 4; i++)
            {
                int a = i != 0 ? i - 1 : 3;
                int b = i;
                int c = i < 3 ? i + 1 : 0;

                frustumNormal[i] = Vector3.Cross(frustumEdge[a] - frustumEdge[b], frustumEdge[c]).normalized;
            }

            for (int i = 0; i < frustumEdge.Length; i++)
            {
                Debug.DrawRay(cam.transform.position, frustumEdge[i] * 100, Color.grey);
                Debug.DrawRay(cam.transform.position, frustumNormal[i] * 1, Color.red);
            }
            */
            Vector3 projectedCameraCenter = cam.transform.position + (pos - cam.transform.position).magnitude * cam.transform.forward;
            Vector3 centerToSphere = (projectedCameraCenter - pos);
            Vector3 closestPointOnSphere = pos + centerToSphere.normalized * Mathf.Min(radius, centerToSphere.magnitude);
            return Vector3.Angle(cam.transform.forward, (closestPointOnSphere - cam.transform.position).normalized) < cam.fieldOfView;
            /*
            Debug.DrawLine(cam.transform.position, projectedCameraCenter);

            if (Vector3.Angle(cam.transform.forward, (closestPointOnSphere - cam.transform.position).normalized) < cam.fieldOfView)
            {
                Debug.DrawLine(pos, closestPointOnSphere, Color.green);
                return true;
            }
            else
            {
                Debug.DrawLine(pos, closestPointOnSphere, Color.red);
                return false;
            }
            */
        }
        public void UpdateLocalLights(Light[] newPointLights)
        {
            pointLights = newPointLights;
            lastPointLights = pointLights;
        }
        #endif



        void ValidateSplitShadow()
        {
            if (materialShadows)
                LazyValidatePlane(ref shadowPlane, ref mRendererShadow, ref materialShadows, "VC2_RaymarchedShadowsPlane");
        }

        void ValidateEditorCam()
        {
            if (editorCamScript == null && attachToEditorCam)
            {
                if (Camera.current.name == "SceneCamera")
                {
                    editorCamScript = Camera.current.gameObject.GetComponent<RaymarchedClouds>();
                    if (editorCamScript == null)
                        editorCamScript = Camera.current.gameObject.AddComponent<RaymarchedClouds>();
                    editorCamScript.materialUsed         = materialUsed;
                    editorCamScript.materialShadows      = materialShadows;
                    editorCamScript.planeOffset          = planeOffset;
                    editorCamScript.splitShadowRendering = splitShadowRendering;
                    // Make scene camera user editable, unity locks properties of their stuff anyway
                    editorCamScript.gameObject.hideFlags &= ~HideFlags.NotEditable;
                }
            }
            else if (editorCamScript != null)
            {
                if (!attachToEditorCam)
                    DestroySafe(editorCamScript);
                else if (editorCamScript.materialUsed != materialUsed)
                    editorCamScript.materialUsed = materialUsed;
            }
        }

        // Uses a quad instead of Graphics.Blit to conform to render queue
        void LazyValidatePlane(ref GameObject planeGO, ref MeshRenderer planeRenderer, ref Material material, string defaultName)
        {
            if (planeGO == null)
            {
                // Work around the absence of hide flags discarding objects on play state changes by searching
                // and discarding all old ones before creating a new one.
                // Resources is the only way to effectively get them when the hideflags
                // is set to hide and the function's -All to get them when they are disabled
                // This is a bit heavy but only procs once per play and is editor only.
                /*#if UNITY_EDITOR
                    Object[] childs = Resources.FindObjectsOfTypeAll(typeof(MeshFilter));
                    for(int i = 0; i < childs.Length; i++)
                    {
                        MeshFilter asMF = (MeshFilter)childs[i];
                        if(asMF.transform.parent != this.transform || asMF.gameObject.name != defaultName)
                            continue;
                        DestroySafe(asMF.gameObject);
                        break;
                    }
                #endif*/
                CreatePlane(ref planeGO, defaultName);
            }
            if (planeRenderer == null)
                planeRenderer = planeGO.GetComponent<MeshRenderer>();
            if (planeRenderer.sharedMaterial != material)
                planeRenderer.sharedMaterial = material;

            if (hidePlane)
                planeGO.hideFlags = HideFlags.HideAndDontSave;
            else if (!hidePlane)
                planeGO.hideFlags = HideFlags.None;
            /*if(hidePlane)
                planeRenderer.enabled = false;*/
        }

        void CreatePlane(ref GameObject planeGO, string defaultName)
        {
            GameObject newPlane = GameObject.CreatePrimitive(PrimitiveType.Quad);
            #if (UNITY_EDITOR)
                // does not play well with OnDrawGizmos and PreRenderEvents, we still will have to find remnants before creating a new one.

                #if (UNITY_2017_2_OR_NEWER)
                    UnityEditor.EditorApplication.playModeStateChanged += (a) => DestroySafe(newPlane);
                    UnityEditor.EditorApplication.pauseStateChanged    += (a) => DestroySafe(newPlane);
                #else
                    UnityEditor.EditorApplication.playmodeStateChanged += () => DestroySafe(newPlane);
                #endif
            #endif
            planeGO = newPlane;
            planeGO.name = defaultName;
            planeGO.SetActive(enabled);
            DestroySafe(planeGO.GetComponent<MeshCollider>());


            MeshRenderer meshRenderer = planeGO.GetComponent<MeshRenderer>();
            #if (UNITY_5_3_OR_NEWER)
                meshRenderer.lightProbeUsage = LightProbeUsage.Off;
            #else
                meshRenderer.useLightProbes = false;
            #endif
            meshRenderer.shadowCastingMode    = ShadowCastingMode.Off;
            meshRenderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
        }

        void FitPlane(ref GameObject planeGO, ref GameObject shadowGO)
        {
            float epsilon = planeOffset;//Mathf.Epsilon;
            float zOffset = thisCam.nearClipPlane + epsilon;
            float frustumHeight = thisCam.orthographic ?
                                      thisCam.orthographicSize * 2f :
                                      Mathf.Tan(thisCam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2f * zOffset;
            float frustumWidth = frustumHeight * thisCam.aspect;

            planeGO.transform.SetParent(thisCam.transform);
            planeGO.transform.localPosition = new Vector3(0.0f, 0.0f, zOffset);
            planeGO.transform.localRotation = Quaternion.identity;
            planeGO.transform.localScale = new Vector3(frustumWidth + frustumWidth * epsilon, frustumHeight + frustumHeight * epsilon, 1.0f);
            if (shadowGO != null)
            {
                shadowGO.transform.SetParent(planeGO.transform.parent);
                shadowGO.transform.localPosition = planeGO.transform.localPosition + Vector3.forward * shadowRenderOffset;
                shadowGO.transform.localRotation = planeGO.transform.localRotation;
                shadowGO.transform.localScale = planeGO.transform.localScale + new Vector3(frustumWidth * shadowRenderOffset, frustumHeight * shadowRenderOffset, 0f);
            }
        }






        public bool IsEditorCamera()
        {
            return this.gameObject.name == "SceneCamera";
        }

        void DestroySafe(Object o)
        {
            if (o == null)
                return;
            if (Application.isPlaying)
                Destroy(o);
            else
                DestroyImmediate(o);
        }
    }

}