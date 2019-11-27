using UnityEngine;
using UnityEngine.Events;
#if UNITY_EDITOR
using UnityEditor;
#endif








namespace VolumetricClouds3
{
    public class CloudsEvent : MonoBehaviour
    {
        public Material cloudMaterial;

        [Header("Event")]
        public float eventThreshold = 0.5f;

        public CloudEvent[] events = new CloudEvent[1];

        [Header("Debug")]
        public bool showDebugCubes = true;
        public int debugCubeCount = 20;
        public float debugCubeSize = 1.0f;
        public bool showEventTrigger = false;

        [System.Serializable]
        public class CloudEvent
        {
            public string eventName = "EventName";
            public Transform monitoredTransform;
            public bool IsInside;
            public UnityEvent OnEnter;
            public UnityEvent OnExit;
        }

        class MaterialInfo
        {
            public bool _Spherical;
            public Vector3 _CloudSpherePosition;
            public float _SphereHorizonStretch;
            public Vector4 _WindDirection;
            public Vector4 _CloudTransform;
            public float _Tiling;
            public float _TimeMult;
            public float _TimeMultSecondLayer;
            public float _Alpha;
            public float density;
            //float _OpacityGain = cloudMaterial.GetFloat("_OpacityGain");
            public Vector4 _Time;
            public Texture2D _PerlinNormalMap;
        }
        MaterialInfo matInfo = new MaterialInfo();

        void Update ()
        {
            UpdateMaterialInfo();
            CheckEvent();
        }

        void CheckEvent()
        {
            foreach (CloudEvent e in events)
            {
                if (e.monitoredTransform == null)
                {
                    Debug.LogError(e.eventName + " doesn't have a transform to monitor, fill in the transform or delete the event");
                    continue;
                }

                float sample = SampleClouds(e.monitoredTransform.position);
                // Is inside and goes outside
                if (e.IsInside && sample < eventThreshold)
                {
                    e.OnExit.Invoke();
                    e.IsInside = false;
                }
                // Is outside and goes inside
                else if (e.IsInside == false && sample > eventThreshold)
                {
                    e.OnEnter.Invoke();
                    e.IsInside = true;
                }
            }
        }
    #if UNITY_EDITOR
        void OnDrawGizmos()
        {
            if(showDebugCubes == false)
                return;
            UpdateMaterialInfo();
            int iterations = debugCubeCount;
            Vector3 initialPos = transform.position - new Vector3(iterations/2f, 0, iterations/2f) * debugCubeSize;
            for (int i = 0; i < iterations; i++)
            {
                for (int j = 0; j < iterations; j++)
                {
                    Vector3 samplePos = initialPos + new Vector3(i, 0, j) * debugCubeSize;
                    Color c = showEventTrigger ? SampleClouds(samplePos) > eventThreshold ? Color.white : Color.black : Color.white * SampleClouds(samplePos);
                    c.a = 1.0f;
                    Gizmos.color = c;
                    Gizmos.DrawCube(samplePos, Vector3.one*debugCubeSize);
                }
            }
        }
    #endif

        float CloudCenterBounds()
        {
            return matInfo._CloudTransform.x;
        }
        float CloudUpperBounds()
        {
            return CloudCenterBounds() + matInfo._CloudTransform.y;
        }

        float SampleClouds(Vector3 samplePos)
        {
            Vector2 UV;
            float dist;
            if (matInfo._Spherical)
            {
                Vector3 deltaFromCenter = samplePos - matInfo._CloudSpherePosition;
                UV = new Vector2(deltaFromCenter.x, deltaFromCenter.z) * Mathf.Pow((CloudUpperBounds() - Mathf.Abs(deltaFromCenter.y)) / CloudUpperBounds(), matInfo._SphereHorizonStretch);
                dist = Vector3.Distance(samplePos, matInfo._CloudSpherePosition + Vector3.Normalize(samplePos - matInfo._CloudSpherePosition) * CloudCenterBounds()) / matInfo._CloudTransform.y;
            }
            else
            {
                UV = new Vector2(samplePos.x, samplePos.z);
                dist = Mathf.Abs(CloudCenterBounds(matInfo._CloudTransform) - samplePos.y) / matInfo._CloudTransform.y;
            }

            float sampleHeight = 1.0f - Mathf.Clamp01(dist);

            Vector2 baseAnimation = (matInfo._Time.y /*+ _TimeEditor.g*/) * 0.001f * new Vector2(matInfo._WindDirection.x, matInfo._WindDirection.z);
            Vector2 worldUV = (UV + new Vector2(matInfo._CloudTransform.z, matInfo._CloudTransform.w)) / matInfo._Tiling;

            Vector2 newUV = worldUV + (baseAnimation * matInfo._TimeMult);
            Vector2 newUV2 = worldUV + (baseAnimation * matInfo._TimeMultSecondLayer) + new Vector2(0.0f, 0.5f);

            float cloudTexture = matInfo._PerlinNormalMap.GetPixelBilinear(newUV.x, newUV.y).a;//tex2Dlod(_PerlinNormalMap, fixed4(newUV, 0, lod)).a;
            float cloudTexture2 = matInfo._PerlinNormalMap.GetPixelBilinear(newUV2.x, newUV2.y).a;//tex2Dlod(_PerlinNormalMap, fixed4(newUV2, 0, lod)).a;


            float baseCloud = ((cloudTexture + matInfo.density) * sampleHeight) - cloudTexture2;
            baseCloud = Mathf.Clamp01(baseCloud * matInfo._Alpha);

            return baseCloud;

            /*
            float opacityGain = _OpacityGain * Mathf.Abs(baseCloud - dist);
            return opacityGain;*/
        }

        float CloudCenterBounds(Vector4 _CloudTransform)
        {
            return _CloudTransform.x;
        }

        void UpdateMaterialInfo()
        {
            if (matInfo == null)
            {
                Debug.LogError("Cloud Material is null, fill in the field with a proper material and reactivate the script");
                this.enabled = false;
            }
            matInfo._Spherical = cloudMaterial.GetInt("_SphereMapped") == 1;
            matInfo._CloudSpherePosition = cloudMaterial.GetVector("_CloudSpherePosition");
            matInfo._SphereHorizonStretch = cloudMaterial.GetFloat("_SphereHorizonStretch");
            matInfo._WindDirection = cloudMaterial.GetVector("_WindDirection");
            matInfo._CloudTransform = cloudMaterial.GetVector("_CloudTransform");
            matInfo._Tiling = cloudMaterial.GetFloat("_Tiling");
            matInfo._TimeMult = cloudMaterial.GetFloat("_TimeMult");
            matInfo._TimeMultSecondLayer = cloudMaterial.GetFloat("_TimeMultSecondLayer");
            matInfo._Alpha = cloudMaterial.GetFloat("_Alpha");
            matInfo.density = cloudMaterial.GetFloat("_Density");
            //float _OpacityGain = cloudMaterial.GetFloat("_OpacityGain");


            float time;
    #if UNITY_EDITOR
            if (Camera.current != null && Camera.current.name == "SceneCamera")
                time = (float) EditorApplication.timeSinceStartup;
            else
    #endif
                time = Time.time;


            matInfo._Time = new Vector4(time / 20.0f, time, time * 2, time * 3);
            matInfo._PerlinNormalMap = (Texture2D)cloudMaterial.GetTexture("_PerlinNormalMap");
        }




    #if UNITY_EDITOR
        void OnValidate()
        {
            Texture2D _PerlinNormalMap = (Texture2D)cloudMaterial.GetTexture("_PerlinNormalMap");
            if(_PerlinNormalMap != null)
                CheckTextureImporterFormat(_PerlinNormalMap);
        }
    #endif



    #if UNITY_EDITOR
        static void CheckTextureImporterFormat(Texture2D texture)
        {
            if (texture == null)
                return;

            string assetPath = AssetDatabase.GetAssetPath(texture);
            var tImporter = AssetImporter.GetAtPath(assetPath) as TextureImporter;
            if (tImporter != null)
            {
                if (tImporter.isReadable != true)
                    Debug.LogError("Texture un-readable, make the texture Read/Write Enabled by changing the texture import settings.");
            }
        }
    #endif
    }
}