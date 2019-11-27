using UnityEditor;
using UnityEngine;

namespace VolumetricClouds3
{
    public class ModulatedKeyword : MaterialPropertyDrawer
    {
        string keyword;
        float  triggerValue;


        public ModulatedKeyword( string keywordParam, float triggerValueParam )
        {
            keyword      = keywordParam;
            triggerValue = triggerValueParam;
        }

        public override void OnGUI( Rect position, MaterialProperty prop, string label, MaterialEditor editor )
        {
            editor.DefaultShaderProperty( position, prop, label );
            if( prop.type == MaterialProperty.PropType.Float )
            {
                bool enable = Mathf.Abs( prop.floatValue - triggerValue ) < 0.01f;

                foreach( var objectMaterial in prop.targets )
                {
                    Material mat = objectMaterial as Material;
                    if( enable )
                        mat.EnableKeyword( keyword );
                    else
                        mat.DisableKeyword( keyword );
                }
            }
            else
            {
                Debug.LogError( "Enums must be float/int, change property : " + label + " to int" );
            }
        }
    }
}