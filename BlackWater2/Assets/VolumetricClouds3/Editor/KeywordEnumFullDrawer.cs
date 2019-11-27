using UnityEditor;
using UnityEngine;


namespace VolumetricClouds3
{
    public class KeywordEnumFullDrawer : MaterialPropertyDrawer
    {
        string[] options;

        KeywordEnumFullDrawer( params string[] options )
        {
            this.options = options;
        }

        public KeywordEnumFullDrawer( string options1, string options2 )
            : this( new[] { options1, options2 } ){}

        public KeywordEnumFullDrawer( string options1, string options2, string options3 )
            : this( new[] { options1, options2, options3 } ){}

        public KeywordEnumFullDrawer( string options1, string options2, string options3, string options4 )
            : this( new[] { options1, options2, options3, options4 } ){}

        public KeywordEnumFullDrawer( string options1, string options2, string options3, string options4, string options5 )
            : this( new[] { options1, options2, options3, options4, options5 } ){}

        public KeywordEnumFullDrawer( string options1, string options2, string options3, string options4, string options5, string options6 )
            : this( new[] { options1, options2, options3, options4, options5, options6 } ){}

        public KeywordEnumFullDrawer( string options1, string options2, string options3, string options4, string options5, string options6, string options7 )
            : this( new[] { options1, options2, options3, options4, options5, options6, options7 } ){}

        public KeywordEnumFullDrawer( string options1, string options2, string options3, string options4, string options5, string options6, string options7, string options8 )
            : this( new[] { options1, options2, options3, options4, options5, options6, options7, options8 } ){}
        
        public KeywordEnumFullDrawer( string options1, string options2, string options3, string options4, string options5, string options6, string options7, string options8, string options9 )
            : this( new[] { options1, options2, options3, options4, options5, options6, options7, options8, options9 } ){}

        public override void OnGUI( Rect position, MaterialProperty prop, string label, MaterialEditor editor )
        {
            if( prop.type == MaterialProperty.PropType.Float )
            {
                if( options.Length < 2 )
                {
                    Debug.LogError( "Missing some option strings for " + prop.displayName + " we need at least 2" );
                    return;
                }
                if( prop.floatValue > options.Length - 1 )
                    prop.floatValue = options.Length - 1;
                else if( prop.floatValue < 0 )
                    prop.floatValue = 0;
                prop.floatValue = EditorGUI.Popup( position, label, (int)prop.floatValue, options );


                foreach( var objectMaterial in prop.targets )
                {
                    Material mat = objectMaterial as Material;
                    foreach( string option in options )
                    {
                        mat.DisableKeyword( option );
                    }
                    mat.EnableKeyword( options[ (int)prop.floatValue ] );
                }
            }
            else
            {
                Debug.LogError( "Enums must be float/int, change property : " + label + " to int" );
            }
        }
    }
}