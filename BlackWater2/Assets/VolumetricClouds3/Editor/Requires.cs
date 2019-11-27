using UnityEditor;
using UnityEngine;


namespace VolumetricClouds3
{
    public class Requires : MaterialPropertyDrawer
    {
        const     float   epsilon = 0.01f;
        protected int[]   propertyName;
        protected float[] valueEquals;

        protected float depth
        {
            get { return propertyName.Length; }
        }

        public Requires( string propertyNameParams )
        {
            propertyName = new[] { Shader.PropertyToID( propertyNameParams ) };
            valueEquals  = new[] { 1f };
        }

        public Requires( string propertyNameParams, float valueEqualsParam )
        {
            propertyName = new[] { Shader.PropertyToID( propertyNameParams ) };
            valueEquals  = new[] { valueEqualsParam };
        }

        public Requires( string p1, float v1, string p2, float v2 )
        {
            propertyName = new[] { Shader.PropertyToID( p1 ), Shader.PropertyToID( p2 ) };
            valueEquals  = new[] { v1, v2 };
        }

        protected bool Show( Material mat )
        {
            for( int i = 0; i < propertyName.Length; i++ )
            {
                float comp = valueEquals[ i ];
                bool  inv  = comp < 0.5f;
                float prop = mat.GetFloat( propertyName[ i ] );
                if( inv == false && Mathf.Abs( prop - Mathf.Abs( comp ) ) > epsilon )
                    return false;
                if( inv && Mathf.Abs( prop - Mathf.Abs( comp ) ) < epsilon )
                    return false;
            }
            return true;
        }

        public override void OnGUI( Rect position, MaterialProperty prop, string label, MaterialEditor editor )
        {
            position.x += 10 * depth;

            Rect bgColor = position;
            bgColor.y -= 2;
            bgColor.x -= 5;
            Material mat = prop.targets[ 0 ] as Material;
            if( Show( mat ) )
            {
                bgColor.height += 2;
                EditorGUI.DrawRect( bgColor, new Color( 0.0f, 0.0f, 0.0f, 0.15f ) );
                position.height -= 2;

                position.width -= 10;
                DrawField( position, prop, editor, label );
            }
            else
            {
                bgColor.height = 1;
                EditorGUI.DrawRect( bgColor, new Color( 0.0f, 0.0f, 0.0f, 0.15f ) );
            }
        }

        protected virtual void DrawField( Rect position, MaterialProperty prop, MaterialEditor editor, string label )
        {
            editor.DefaultShaderProperty( position, prop, label );
        }

        public override float GetPropertyHeight( MaterialProperty prop, string label, MaterialEditor editor )
        {
            return Show( prop.targets[ 0 ] as Material ) ? base.GetPropertyHeight( prop, label, editor ) : 0;
        }
    }
}