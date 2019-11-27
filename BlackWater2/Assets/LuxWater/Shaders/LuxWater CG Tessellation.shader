Shader "Lux Water/WaterSurface Tessellation" {

	Properties {
		
		[Enum(Off,0,On,1)]_ZWrite 		("ZWrite", Float) = 1.0
		[Enum(UnityEngine.Rendering.CullMode)] _Culling ("Culling", Float) = 0

		[Space(5)]
		_OrthoDepthCorrection 			("Orthographic Depth Correction", Float) = 0

		[Space(5)]
		[Toggle(EFFECT_BUMP)]
		_UVSpaceMappingEnabled			("UV Space Texture Mapping", Float) = 0

		[Space(5)]
		[Toggle(USINGWATERVOLUME)]		
		_UsesWaterVolume				("Uses Water Volume", Float) = 0
		_WaterSurfaceYPos				("    Water Surface Position (Y)", Float) = 0
		
		[Header(Basic Properties)]
		_Glossiness 					("    Smoothness", Range(0,1)) = 0.92
		_SpecColor						("    Specular", Color) = (0.15,0.15,0.15)
		[Space(5)]
		_InvFade 						("    Edge Blend Factor", Range(0.001, 6)) = 1


		[Header(Reflections)]
		[Toggle(GEOM_TYPE_MESH)]
		_PlanarEnabled 					("    Enable Planar Reflections", Float) = 0
		[HideInInspector]_LuxWater_ReflectionTex("ReflectionTex", 2D) = "gray" {}
		[Space(5)]
		_FresnelPower					("    Fresnel Power", Range(1,5)) = 5
		_ReflectionStrength 			("    Strength", Range(0,1)) = 1
		_ReflectionGlossiness 			("    Smoothness", Range(0,1)) = 1
		_ReflectionBumpScale 			("    Bump Scale", Range(0,1)) = 0.3
		[Space(5)]
		_WaterIOR 						("    Underwater IOR", Range(1.1,1.4)) = 1.3333
		_UnderWaterReflCol 				("    Underwater Reflection Tint", Color) = (1,1,1,0)


		[Header(Underwater Fog)]
		_Color 							("    Fog Color", Color) = (1,1,1,1)
		[LuxWaterVectorThreeDrawer]
		_DepthAtten						("    - Depth: Fade Start (X) Fade Range (Y) Density (Z)", Vector) = (0, 32, 1, 0)
		
		[PowerSlider(3.0)] _Density 	("    - View Depth", Range(0.0,4)) = 0.1
		_FogAbsorptionCancellation 		("    Absorption Cancellation", Range(0.0,1)) = 1	

		[Header(Light Absorption)]
		[Space(4)]
		_AbsorptionStrength				("    Strength", Range(0,1)) = 1
		_AbsorptionHeight				("    - Depth", Range(0.0,8)) = 1
		_AbsorptionMaxHeight			("    - Max Depth", Float) = 60
		_AbsorptionDepth 				("    - View Depth", Range(0,0.4)) = 0.07
		_AbsorptionColorStrength		("    Color Absorption", Range(0,1)) = 0.5
		
		[Header(Translucent Lighting)]
		_TranslucencyColor				("    Translucency Color", color) = (0.1,0.2,0.3,0)
		_ScatteringPower				("    Scattering Power", Range(0.1, 10.0)) = 5

		[Header(Normals)]
		[NoScaleOffset] _BumpMap 		("    Normal Map", 2D) = "bump" {}

		[Header(    Far Normal)]
		[LuxWaterVectorThreeDrawer]
		_FarBumpSampleParams 			("    Tiling (X) Fade (Y) Scale (Z, 0-1)", Vector) = (0.25, 0.01, 1, 0)

		[Header(    Detail Normals)]
		[LuxWaterVectorThreeDrawer]
		_BumpScale   					("    Scale", Vector) = (1, 0.5, 0.25, 0)
		[LuxWaterVectorFourGFDrawer]
		_BumpTiling	 					("    Tiling", Vector) = (1, 0.5, 0.478, 0.1)
		[LuxWaterVectorFourGFDrawer]
		_BumpSpeed 	 					("    Speed", Vector) = (1.7, 1.0, 0, 1.0)
		[LuxWaterVectorFourGFDrawer]
		_BumpRotation	 				("    Rotation", Vector) = (0, 8.0, 32.0, 0)

	//	Combined Speed and Rotation Values
		[HideInInspector]_FinalBumpSpeed01("    Final BumpSpeed01", Vector) = (0, 0, 0, 0)
		[HideInInspector]_FinalBumpSpeed23("    Final BumpSpeed23", Vector) = (0, 0, 0, 0)
		[Space(5)]
		_Refraction  					("    Refraction", Range(0,1024)) = 512

		[Header(Foam)]
		[Toggle(GEOM_TYPE_BRANCH_DETAIL)] _FoamEnabled ("    Enable Foam", Float) = 1
		[ShowIf(GEOM_TYPE_BRANCH_DETAIL)]
		[NoScaleOffset]_MainTex 		("    Normal (RGB) Mask (A)", 2D) = "white" {}
		_FoamTiling 					("    Tiling", Float) = .1
		[Space(5)]
		_FoamColor						("    Color (RGB) Opacity (A)", color) = (0.7, 0.7, 0.7, 0.8)
		_FoamScale 						("    Scale", Range(0, 40)) = 20
		_FoamSpeed 	 					("    Speed", Float) = 0.9
		_FoamParallax 					("    Parallax", Range(0.0, 1)) = .35
		_FoamNormalScale 				("    Normal Scale", Float) = 1
		_FoamSoftIntersectionFactor		("    Edge Blend Factor", Range(0.0, 3)) = 1

		[Header(Caustics)]
		[Toggle(GEOM_TYPE_FROND)]
		_CausticsEnabled 				("    Enable Caustics", Float) = 1
		[Toggle(GEOM_TYPE_LEAF)]
		_CausticMode 					("    Normals from GBuffer", Float) = 1
		[NoScaleOffset] _CausticTex 	("    Caustics (R) Noise (GB)", 2D) = "black" {}
		_CausticsTiling 				("    Tiling", Float) = .1
		[Space(5)]
		_CausticsScale 					("    Scale", Range(0, 8)) = 2
		_CausticsSpeed 	 				("    Speed", Float) = 0.9
		_CausticsSelfDistortion 		("    Distortion", Float) = 0.2

		[Header(Advanced Options)]
		[Toggle(GEOM_TYPE_BRANCH)]
		_PixelSnap						("    Enable Pixel Snapping", Float) = 0
		
		[Header(Gerstner Waves)]
		[Toggle(_GERSTNERDISPLACEMENT)]
		_GerstnerEnabled 				("    Enable Gerstner Waves", Float) = 0
				
		[Space(5)]
		[LuxWaterVectorFourDrawer]
		_GAmplitude 					("    Amplitude", Vector) = (0.3 ,0.35, 0.25, 0.25)
		[Space(24)]
		
		[LuxWaterVectorFourDrawer]
		_GFrequency 					("    Frequency", Vector) = (1.3, 1.35, 1.25, 1.25)
		[LuxWaterGFDrawer]
		_GGlobalFrequency	 			("        Global Factor", Float) = 1.0
		[HideInInspector]
		_GFinalFrequency 				("    Final Frequency", Vector) = (1.3, 1.35, 1.25, 1.25)
		
		[LuxWaterVectorFourDrawer]
		_GSteepness 					("    Steepness", Vector) = (1.0, 1.0, 1.0, 1.0)
		[Space(24)]

		[LuxWaterVectorFourDrawer]
		_GSpeed 						("    Speed", Vector) = (1.2, 1.375, 1.1, 1.5)
		[LuxWaterGFDrawer]_GGlobalSpeed ("        Global Factor", Float) = 1.0
		[HideInInspector]_GFinalSpeed	("    Final Speed", Vector) = (1.2, 1.375, 1.1, 1.5)

		[LuxWaterVectorFourDrawer]
		_GRotation	 					("    Rotation", Vector) = (0, 8.0, 32.0, 0)
		[LuxWaterGFDrawer]
		_GGlobalRotation	 			("        Global Factor", Float) = 0
		[HideInInspector]_GDirectionAB 	("    	  Direction AB", Vector) = (0.3 ,0.85, 0.85, 0.25)
		[HideInInspector]_GDirectionCD 	("        Direction CD", Vector) = (0.1 ,0.9, 0.5, 0.5)

		[Space(5)]
		[LuxWaterVectorThreeDrawer]
		_GerstnerVertexIntensity 		("    Final Displacement", Vector) = (1.0,1.0,1.0,0.0)

		[Space(5)]
		_GerstnerNormalIntensity 		("    Normal Scale", Range(0,1)) = 0.05
		//_GerstnerVerticalIntensity 		("    Vertical Displacement", Range(0,1)) = 0.05
		_FoamCaps 						("    Foam Caps", Range(0,4)) = 0.5


		[Header(Tessellation)]
		_LuxWater_EdgeLength 			("    Edge Length", Range(4, 100)) = 50
		_LuxWater_Extrusion 			("    Extrusion", Float) = 0.1
		_LuxWater_Phong 				("    Phong Strengh", Range(0,1)) = 0.5

	}
	

	SubShader {

		Tags {"Queue"="Transparent-1" "RenderType"="Transparent" "ForceNoShadowCasting" = "True"}		

		LOD 200

		GrabPass{ "_GrabTexture" }


		// ------------------------------------------------------------------
        //  Base forward pass (directional light)
		Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            ZWrite [_ZWrite]
			ZTest LEqual
			Cull [_Culling]
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma target 4.6
			#pragma multi_compile_fwdbase
			#ifndef UNITY_PASS_FORWARDBASE
				#define UNITY_PASS_FORWARDBASE
			#endif

		//	Fog Mode
			// #define FOG_LINEAR
			// #define FOG_EXP
			#define FOG_EXP2

		//	Metal deffered support
			//#define LUXWATERMETALDEFERRED

		//	Water projector support
			#pragma multi_compile __ USINGWATERPROJECTORS
		//	Water volume support
			#pragma multi_compile __ USINGWATERVOLUME
		//	In order to safe keywords we use speedtree's keywords
		//	Planar reflections
			#pragma multi_compile __ GEOM_TYPE_MESH
		//	Foam
			#pragma shader_feature GEOM_TYPE_BRANCH_DETAIL
		//	Caustics
			#pragma shader_feature GEOM_TYPE_FROND
		//	Caustic Normal Mode
			#pragma shader_feature GEOM_TYPE_LEAF
		//	Gerstner Waves
			#pragma shader_feature _GERSTNERDISPLACEMENT
		//	Snapping
			#pragma shader_feature GEOM_TYPE_BRANCH
		//	Texture Mapping
			#pragma shader_feature EFFECT_BUMP

			#pragma hull hs_surf
	            #pragma domain ds_surf
	            #pragma vertex tessvert
            
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardBRDF.cginc"
            #include "AutoLight.cginc"
            #include "Includes/LuxWater_Core.cginc"
            #include "Includes/LuxWater_Tess.cginc"
            ENDCG

        }

		// ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }

            ZWrite Off
			ZTest LEqual
			Cull [_Culling]
			Blend SrcAlpha One

			CGPROGRAM
			#pragma target 4.6
			#pragma multi_compile_fwdadd

		//	Metal deffered support
			//#define LUXWATERMETALDEFERRED

		//	Water projector support
			#pragma multi_compile __ USINGWATERPROJECTORS
		//	Water volume support
			#pragma multi_compile __ USINGWATERVOLUME
		//	In order to safe keywords we use speedtree's keywords
		//	Planar reflections - not needed in Forward Add Pass
			//#pragma multi_compile __ GEOM_TYPE_MESH
		//	Foam
			#pragma shader_feature GEOM_TYPE_BRANCH_DETAIL
		//	Caustics
			#pragma shader_feature GEOM_TYPE_FROND
		//	Caustic Normal Mode
			#pragma shader_feature GEOM_TYPE_LEAF
		//	Gerstner Waves
			#pragma shader_feature _GERSTNERDISPLACEMENT
		//	Snapping
			#pragma shader_feature GEOM_TYPE_BRANCH
		//	Texture Mapping
			#pragma shader_feature EFFECT_BUMP

			//#pragma vertex vert

			#pragma hull hs_surf
	            #pragma domain ds_surf
	            #pragma vertex tessvert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityStandardUtils.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardBRDF.cginc"
            #include "AutoLight.cginc"
            #include "Includes/LuxWater_Core.cginc"
            #include "Includes/LuxWater_Tess.cginc"
            ENDCG

        }

	}
	CustomEditor "LuxWaterMaterialEditor"
	Fallback "Lux Water/WaterSurface"
}
