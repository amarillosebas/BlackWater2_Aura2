using UnityEditor;
using UnityEngine;


namespace VolumetricClouds3
{
    public class ToggleAndRequires : Requires
    {
        string keywordToggle;

        public ToggleAndRequires( string keywordToggleParam, string propertyNameParams ) : base( propertyNameParams )
        {
            keywordToggle = keywordToggleParam;
        }

        public ToggleAndRequires( string keywordToggleParam, string propertyNameParams, float valueEqualsParam ) : base( propertyNameParams, valueEqualsParam )
        {
            keywordToggle = keywordToggleParam;
        }

        public ToggleAndRequires( string keywordToggleParam, string p1, float v1, string p2, float v2 ) : base( p1, v1, p2, v2 )
        {
            keywordToggle = keywordToggleParam;
        }

        protected override void DrawField( Rect position, MaterialProperty prop, MaterialEditor editor, string label )
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