using UnityEditor;
using UnityEngine;


namespace VolumetricClouds3
{
    public class ToggleKeyword : MaterialPropertyDrawer
    {
        string keywordToggle;

        public ToggleKeyword( string keywordToggleParam )
        {
            keywordToggle = keywordToggleParam;
        }

        public override void OnGUI( Rect position, MaterialProperty prop, string label, MaterialEditor editor )
        {
            bool b = prop.floatValue > 0.5f;
            b = EditorGUI.Toggle( position, label, b );
            prop.floatValue = b ? 1f : 0f;

            foreach( Object matObj in prop.targets )
            {
                Material mat = matObj as Material;
                if( b )
                    mat.EnableKeyword( keywordToggle );
                else
                    mat.DisableKeyword( keywordToggle );
            }
        }
    }
}