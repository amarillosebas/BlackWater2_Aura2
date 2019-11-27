using UnityEngine;
using UnityEditor;

namespace VolumetricClouds3
{
    public class VCloudShaderGUI : ShaderGUI
    {
        public override void OnGUI( MaterialEditor materialEditor, MaterialProperty[] properties )
        {
            bool newShading = ( materialEditor.target as Material ).IsKeywordEnabled( "_NEW_SHADING" );
            if( false == newShading )
                EditorGUILayout.HelpBox( "Old shading system is deprecated, you can still use it but the material's UI is not designed to support it.", MessageType.Warning );
                
            if( GUILayout.Button( "Help" ) )
                Application.OpenURL( "https://docs.google.com/document/d/1v5DkaaTHGBSQQgPoV12UG1r1hSpAPY6V9VLIi_0CkKU/edit?usp=sharing" );

            base.OnGUI( materialEditor, properties );

            Material m = (Material)materialEditor.target;
            m.renderQueue = m.GetInt( "_RenderQueue" );
        }
    }

    [ CustomEditor( typeof(RaymarchedClouds) ) ]
    public class SceneGUIRotateInspector : Editor
    {
        void OnSceneGUI()
        {
            RaymarchedClouds targetCS = (RaymarchedClouds)target;
            if( Event.current.alt || targetCS.activateHandleDrawing == false )
                return;

            Material m = targetCS.materialUsed;
            if( m == null )
                return;

            Handles.color = Color.black;
            // Transform
            Vector4 transform = m.GetVector( "_CloudTransform" );
            // pos
            Vector3 newCloudPos = Handles.DoPositionHandle( new Vector3( -transform.z, transform.x, -transform.w ), Quaternion.identity );
            // size
            float handleSize = HandleUtility.GetHandleSize( newCloudPos );
            float newSize    = Handles.ScaleSlider( transform.y, newCloudPos, -Vector3.up, Quaternion.identity, handleSize * 1.5f, 0f );

            Vector4 remap = new Vector4( newCloudPos.y, newSize, -newCloudPos.x, -newCloudPos.z );
            if( remap != transform )
            {
                Undo.RecordObject( m, "Modified VCloud material" );
                m.SetVector( "_CloudTransform", remap );
            }

            // Wind
            Vector4 windDirection    = m.GetVector( "_WindDirection" );
            Vector3 windReference    = windDirection;
            Vector3 newWindDirection = Handles.RotationHandle( Quaternion.LookRotation( windDirection.normalized ), newCloudPos ) * Vector3.forward;
            newWindDirection.y = 0f;
            if( windReference != newWindDirection )
            {
                Undo.RecordObject( m, "Modified VCloud material" );
                m.SetVector( "_WindDirection", new Vector4( newWindDirection.x, newWindDirection.y, newWindDirection.z, windDirection.w ) );
            }


            // non-interactable
            Handles.Label( newCloudPos, "Cloud Position" );
            Vector3 windArrowPos = newCloudPos  + Vector3.up       * handleSize;
            Vector3 windArrowEnd = windArrowPos + newWindDirection * handleSize;
            #if UNITY_5_5_OR_NEWER
            Handles.ArrowHandleCap( 125445, windArrowPos, Quaternion.LookRotation( newWindDirection ), handleSize, EventType.Repaint );
            #else
            Handles.ArrowCap(125445, windArrowPos, Quaternion.LookRotation(newWindDirection), handleSize);
            #endif
            Handles.Label( windArrowEnd, "Wind Direction" );


            int sphere = m.GetInt( "_SphereMapped" );
            if( sphere > 0 )
            {
                Vector4 spherePos   = m.GetVector( "_CloudSpherePosition" );
                Vector3 spherePosV3 = spherePos;
                Vector3 newPos      = Handles.DoPositionHandle( spherePos, Quaternion.identity );
                Handles.Label( newPos, "Cloud Position" );
                if( spherePosV3 != newPos )
                {
                    Undo.RecordObject( m, "Modified VCloud material" );
                    m.SetVector( "_CloudSpherePosition", new Vector4( newPos.x, newPos.y, newPos.z, spherePos.w ) );
                }
            }
        }
    }
}
