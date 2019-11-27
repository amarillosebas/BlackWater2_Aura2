// Regular "Particles/Alpha Blended" - without regular but underwater fog

Shader "Lux Water/Particles/UnderwaterParticles Alpha Blended" {
Properties {
    _TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
    _MainTex ("Particle Texture", 2D) = "white" {}
    _InvFade ("Soft Particles Factor", Range(0.01,3.0)) = 1.0
}

Category {
    Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
    Blend SrcAlpha OneMinusSrcAlpha
    ColorMask RGB
    Cull Off Lighting Off ZWrite Off

    SubShader {
        Pass {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_particles

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            fixed4 _TintColor;

            fixed3 _Lux_UnderWaterFogColor;
            float _Lux_UnderWaterFogDensity;
            float _Lux_UnderWaterAbsorptionDepth;
            float _Lux_UnderWaterFogAbsorptionCancellation;
            float _Lux_UnderWaterAbsorptionColorStrength;

            struct appdata_t {
                float4 vertex : POSITION;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                //#ifdef SOFTPARTICLES_ON
                	float4 projPos : TEXCOORD2;
                //#endif
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _MainTex_ST;

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                //#ifdef SOFTPARTICLES_ON
                	o.projPos = ComputeScreenPos (o.vertex);
                	COMPUTE_EYEDEPTH(o.projPos.z);
                //#endif
                o.color = v.color * _TintColor;
                o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
                return o;
            }

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float _InvFade;

            fixed4 frag (v2f i) : SV_Target
            {
                #ifdef SOFTPARTICLES_ON
	                float sceneZ = LinearEyeDepth (SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
	                float partZ = i.projPos.z;
	                float fade = saturate (_InvFade * (sceneZ-partZ));
	                i.color.a *= fade;
                #endif

                fixed4 col = 2.0f * i.color * tex2D(_MainTex, i.texcoord);


            //	Underwater fog
            	float fogDensity = (1.0 - saturate( exp( -i.projPos.z * _Lux_UnderWaterFogDensity ) ) );
                col.rgb = lerp(col.rgb, _Lux_UnderWaterFogColor, fogDensity);
            //	Absorption
            	float3 ColorAbsortion = float3(0.45f, 0.029f, 0.018f);
            //	Calculate Attenuation along viewDirection
				float d = exp2( -i.projPos.z * _Lux_UnderWaterAbsorptionDepth);
			//	Cancel absorption by fog 
				d = saturate(d + fogDensity * _Lux_UnderWaterFogAbsorptionCancellation);
				ColorAbsortion = lerp( d, -ColorAbsortion, _Lux_UnderWaterAbsorptionColorStrength * (1.0 - d));
				ColorAbsortion = saturate(ColorAbsortion);	
			//	Apply absorption
				col.rgb *= ColorAbsortion;

                return col;
            }
            ENDCG
        }
    }
}
}
