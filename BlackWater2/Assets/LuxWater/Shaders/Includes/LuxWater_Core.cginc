// ------------------------------------------------------------------
//  Inputs

    float   _LuxWater_Extrusion;
    float   _OrthoDepthCorrection;
    
//  Basic Properties
    sampler2D _MainTex;
    float4  _MainTex_TexelSize;
    half    _Glossiness;
    half    _InvFade;

//  Reflections
    half    _ReflectionBumpScale;
    half    _ReflectionGlossiness;

//  Lighting
    half    _WaterIOR;
    half    _FresnelPower;
    fixed4  _Lux_UnderWaterAmbientSkyLight;
    fixed   _ReflectionStrength;
    fixed4  _UnderWaterReflCol;

//  Translucency
    half    _ScatteringPower;
    half3   _TranslucencyColor;

//  Planar reflections
    #if defined(GEOM_TYPE_MESH)
        sampler2D _LuxWater_ReflectionTex;
        half _LuxWater_ReflectionTexMip;
        float4 _LuxWater_ReflectionTex_TexelSize;
    #endif

//  Water Volume
    float _WaterSurfaceYPos;

//  Underwater Fog
    fixed4  _Color;
    half3   _DepthAtten;
    half    _Density;
    half    _FinalFogDensity;
    half    _FogAbsorptionCancellation;

//  Absorption
    half    _AbsorptionHeight;
    half    _AbsorptionMaxHeight;
    float   _AbsorptionDepth;
    fixed   _AbsorptionColorStrength;
    fixed   _AbsorptionStrength;

//  Normals
    sampler2D _BumpMap;
    half    _Refraction;
    float3  _FarBumpSampleParams;
    float4  _BumpTiling;
    float4  _BumpScale;
    float4  _FinalBumpSpeed01;
    float2  _FinalBumpSpeed23;

//  Foam
    fixed4  _FoamColor;
    half    _FoamScale;
    float   _FoamSpeed;
    half    _FoamParallax;
    half    _FoamSoftIntersectionFactor;
    float   _FoamTiling;
    float   _FoamNormalScale;
    half    _FoamCaps;

//  Caustics
    sampler2D _CausticTex;
    #if defined(GEOM_TYPE_LEAF)
        sampler2D _CameraGBufferTexture2; //Deferred Normals
    #endif
    half    _CausticsScale;
    half    _CausticsSpeed;
    half    _CausticsTiling;
    half    _CausticsSelfDistortion;

    sampler2D _GrabTexture;
    float4  _GrabTexture_TexelSize;      
    
    UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
    float4  _CameraDepthTexture_TexelSize;

//  Water Projectors
    sampler2D _LuxWater_FoamOverlay;
    sampler2D _LuxWater_NormalOverlay;

//  Gerstner Waves
    float3 _GerstnerVertexIntensity;
    float _GerstnerNormalIntensity;
    uniform float4 _GAmplitude;
    uniform float4 _GFinalFrequency;
    uniform float4 _GSteepness;
    uniform float4 _GFinalSpeed;
    uniform float4 _GDirectionAB;
    uniform float4 _GDirectionCD;


// ------------------------------------------------------------------


    struct appdata_water {
        float4 vertex : POSITION;
        float4 tangent : TANGENT;
        float3 normal : NORMAL;
        float4 texcoord : TEXCOORD0;
        fixed4 color : COLOR;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct v2f {
        #if UNITY_VERSION >= 201711
            UNITY_POSITION(pos);
        #else
            float4 pos : SV_POSITION;
        #endif

        half4 tspace0 : TEXCOORD0;
        half4 tspace1 : TEXCOORD1;
        half4 tspace2 : TEXCOORD2;

        float4 BumpUVs : TEXCOORD3;
        float4 BumpSmallAndFoamUVs : TEXCOORD4;

        float4 grabUV : TEXCOORD5;
        float4 ViewRay_WaterYpos : TEXCOORD6;

        float4 color : COLOR;

    //  Actually needed...
        UNITY_SHADOW_COORDS(7)

        float4 projectorScreenPos : TEXCOORD8;

        //float angle : TEXCOORD9;

        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };



    #include "Includes/LuxWater_Utils.cginc"
    #include "Includes/LuxWater_GerstnerWaves.cginc"


    // GPU Pro 2, Page 317: https://books.google.de/books?id=zfPRBQAAQBAJ&pg=PA318&lpg=PA318&dq=water+fresnel+term&source=bl&ots=WHdSW0OQvx&sig=l6jFIIrZ7GuQ7ysb5jOS8ZiJHtU&hl=de&sa=X&ved=0ahUKEwjrloKAkO7aAhVMC8AKHf7BBfk4ChDoAQgwMAI#v=onepage&q=water%20fresnel%20term&f=false
    // https://www.scratchapixel.com/lessons/3d-basic-rendering/introduction-to-shading/reflection-refraction-fresnel

    inline half3 LuxFresnelLerpUnderwater( half3 F90, half cosA) {
        half3 F0 = 0.02037;
        half n1 = 1.000293;   // Air
        half n2 = _WaterIOR;  // 1.333333; // Water at rooom temperatur...
        half eta = (n2 / n1);
        half k = eta * eta * (1.0 - cosA * cosA);
    //  As we do not have any real internal reflections
    //  k = saturate(k);
        if (k > 1.0 ) {     // Total internal Reflection
            return 1.0;
        }
        cosA = sqrt(1.0 - k);
        return lerp(F0, F90, Pow5(1.0 - cosA));
    }

    inline half3 LuxFresnelLerp (half3 F0, half3 F90, half cosA) {
        //half t = Pow5 (1 - cosA);   // ala Schlick interpoliation
        half t = pow(1 - cosA, _FresnelPower); 
        return lerp (F0, F90, t);
    }


// ------------------------------------------------------------------
// Vertex shader

    v2f vert (appdata_water v) {
        UNITY_SETUP_INSTANCE_ID(v);
        v2f o;
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_TRANSFER_INSTANCE_ID(v, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    //  Calculate wpos up front as we need it anyway and it allows us to optimize other calculations
        float4 worldPos = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.0));

    //  In case we use water projector and gerstnerwaves we need the undistored screenUVs
        #if defined(USINGWATERPROJECTORS) || defined(_GERSTNERDISPLACEMENT)
            float4 hposOrig = mul(UNITY_MATRIX_VP, worldPos);
            o.projectorScreenPos = ComputeScreenPos(hposOrig);
        #endif

    //  Calculate ClipPos (optimized)
        o.pos = mul(UNITY_MATRIX_VP, worldPos);

        #if defined(EFFECT_BUMP)
        //  uv
            float2 BaseUVs = v.texcoord.xy * _BumpTiling.ww;
        #else
        //  world space texure mapping
            float2 BaseUVs = worldPos.xz * _BumpTiling.ww;

//v.tangent.xyz = cross(v.normal, float3(0,0,1));
//v.tangent.w = -1;

        #endif

        o.BumpUVs.xy = BaseUVs * _BumpTiling.x + _Time.xx * _FinalBumpSpeed01.xy;
        o.BumpUVs.zw = BaseUVs * _BumpTiling.y + _Time.xx * _FinalBumpSpeed01.zw;
        o.BumpSmallAndFoamUVs.xy = BaseUVs * _BumpTiling.z + _Time.xx * _FinalBumpSpeed23.xy;


    //  Gerstner Displacement
        #if defined(_GERSTNERDISPLACEMENT)
            half3 vtxForAni = worldPos.xzz;
            half3 nrml;
            half3 offsets;
            Gerstner (
                offsets, nrml, v.vertex.xyz, vtxForAni,        // offsets, nrml will be written
                _GAmplitude,                                   // amplitude
                _GFinalFrequency,                              // frequency
                _GSteepness,                                   // steepness
                _GFinalSpeed,                                  // speed
                _GDirectionAB,                                 // direction # 1, 2
                _GDirectionCD                                  // direction # 3, 4
            );

            v.normal = nrml;
            
        //  version 1.01: power 3 skipped, new factor
            float foam = offsets.y /* * offsets.y * offsets.y */ + (abs(offsets.x) + abs(offsets.z)) * 0.1875; // * 0.125;
        //  version 1.01: smoothstep added
            v.color.a = smoothstep(0.0, 1.0, saturate(foam));
            
            worldPos.xyz += offsets * v.color.r;

        #endif

    //  Projector Displacment
        #if defined(USINGWATERPROJECTORS)
            if(_LuxWater_Extrusion > 0) {
                float2 projectionUVs = o.projectorScreenPos.xy / o.projectorScreenPos.w;
                fixed4 projectedNormal = tex2Dlod(_LuxWater_NormalOverlay, float4(projectionUVs, 0, 0));
                worldPos.xyz += v.normal * (projectedNormal.b) * _LuxWater_Extrusion;
            }
        #endif

    //  Calculate new ClipPos (optimized)
        #if defined(USINGWATERPROJECTORS) || defined(_GERSTNERDISPLACEMENT)
            o.pos = mul(UNITY_MATRIX_VP, worldPos);
        #endif

    //  Normals
        half3 worldNormal = UnityObjectToWorldNormal(v.normal);
        #if defined(EFFECT_BUMP)
            half3 worldTangent = UnityObjectToWorldNormal(v.tangent.xyz);
        #else
    //  In case we use world projection we must NOT rotate the tangent.
            half3 worldTangent = v.tangent.xyz;
        #endif
        half3 worldBinormal = cross(worldTangent, worldNormal);
        o.tspace0 = half4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
        o.tspace1 = half4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
        o.tspace2 = half4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

    //  Grab UVs
        o.grabUV = ComputeGrabScreenPos(o.pos);

    //  Calculate ViewRay by transforming WorldPos to ViewPos (optimized)
        o.ViewRay_WaterYpos.xyz = mul(UNITY_MATRIX_V, worldPos).xyz * float3(-1, -1, 1);
    //  Store wpos.y of watersurface
        o.ViewRay_WaterYpos.w = worldPos.y;
        o.color = v.color;

    //  ViewAngle used to correct depth calculations for orthographic cameras
        float3 viewDir = mul((float3x3)unity_CameraToWorld, float3(0,0,1));
        // 0 at steep angles, 1 when looking from above
        o.color.b = dot(normalize(viewDir), float3(0,-1,0));

        //UNITY_TRANSFER_SHADOW(o, v.texcoord.xy);
        return o;
    }

//  ------------------------------------------------------------------
//  Fragment shader

    half4 frag(v2f i, float facing : VFACE) : SV_Target {

        //#define surfaceEyeDepth i.grabUV.w

    //  Perspective Projection
        float surfaceEyeDepth = i.grabUV.w;
    //  Orthographic Projection 
        surfaceEyeDepth = lerp(surfaceEyeDepth, LinearEyeDepth(i.grabUV.z), unity_OrthoParams.w);
        float orthoCorrection = lerp(1, _ProjectionParams.z, unity_OrthoParams.w);
    //  orthoDepthCorrection is fully empirical - but quite stable even in the scene view
        float orthoDepthCorrection = lerp(1, 1 + (_OrthoDepthCorrection + _ZBufferParams.z * i.grabUV.z ) * i.color.b, unity_OrthoParams.w);

        float3 worldPos = float3(i.tspace0.w, i.tspace1.w, i.tspace2.w);
        float3 worldViewDir = -normalize (worldPos - _WorldSpaceCameraPos.xyz);
        fixed3 worldNormalFace = fixed3(i.tspace0.z, i.tspace1.z, i.tspace2.z);

        half Smoothness = _Glossiness;
        half3 Specular = _SpecColor;
        half Translucency = 1;
        half Caustics = 0;
        half4 Foam = _FoamColor;
        Foam.a = 0;
        half ReflectionSmoothness = _ReflectionGlossiness;

        half4 c = fixed4(1,0,0,1);

    //  -----------------------------------------------------------------------
    //  Water Projectors: Get screen UVs and vignette   
        #if defined(USINGWATERPROJECTORS) 
            float2 projectionUVs;
            #if defined(_GERSTNERDISPLACEMENT)
                projectionUVs = i.projectorScreenPos.xy / i.projectorScreenPos.w;

                float2 strength = abs(projectionUVs - 0.5); // 0 - 0.5 range
                strength = saturate ((float2(0.5, 0.5) - strength) * 2);
                float vignette = min(strength.x, strength.y);
                vignette = saturate(vignette * 4); // sharpen
            #else
                projectionUVs = i.grabUV.xy / i.grabUV.w;
            #endif
        #endif

    //  -----------------------------------------------------------------------   
    //  Init backside rendering
        #if UNITY_VFACE_FLIPPED
            facing = -facing;
        #endif
        #if UNITY_VFACE_AFFECTED_BY_PROJECTION
            facing *= _ProjectionParams.x; // take possible upside down rendering into account
        #endif
        bool backside = (facing < 0) ? true : false;

    //  -----------------------------------------------------------------------
    //  Animate and blend normals

    //  Sample and blend far and 1st detail normal
        fixed4 farSample = tex2D(_BumpMap, i.BumpUVs.xy * _FarBumpSampleParams.x + _Time.x * _FinalBumpSpeed01.xy * _FarBumpSampleParams.x);
    //  Scale farSample
        farSample = lerp(fixed4(0, 0.5, 0, 0.5), farSample, saturate(_FarBumpSampleParams.z));
        fixed4 normalSample = tex2D(_BumpMap, i.BumpUVs.xy + (farSample.ag * 2.0 - 1.0 ) * 0.05 );
        normalSample = lerp( normalSample, farSample, saturate(surfaceEyeDepth * _FarBumpSampleParams.y) );

        half3 refractNormal;
        #if defined(UNITY_NO_DXT5nm)
            refractNormal = (normalSample.rgb * 2 - 1) * _BumpScale.x;
        #else
            refractNormal = (normalSample.agg * 2 - 1) * _BumpScale.x;
        #endif
    //  refracted 2nd detail normal sample
        fixed4 normalSampleSmall = tex2D(_BumpMap, i.BumpUVs.zw + refractNormal.xy * 0.05 );
    //  3rd detail normal sample
        fixed4 normalSampleSmallest = tex2D(_BumpMap, i.BumpSmallAndFoamUVs.xy);
        fixed3 tangentNormal = UnpackAndBlendNormals (refractNormal, normalSampleSmall, normalSampleSmallest);

    //  -----------------------------------------------------------------------
    //  Normal Projectors
        #if defined (USINGWATERPROJECTORS)

            fixed4 projectedNormal = tex2D(_LuxWater_NormalOverlay, projectionUVs);
            // Using regular ARGB rt
            // fixed3 pNormal = projectedNormal.rgb * 2 - 1;
            // Using ARGBHalf and additibve blending
            fixed3 pNormal = projectedNormal.rgb;
            pNormal.b = sqrt(1 - saturate(dot(pNormal.xy, pNormal.xy)));
            // pNormal.xy *= -1; // proper tangent space - moved to normal projector shader
            pNormal = lerp( half3(0,0,1), pNormal, projectedNormal.a
                #if defined(_GERSTNERDISPLACEMENT)
                    * vignette
                #endif
            );
            tangentNormal = normalize(half3(tangentNormal.xy + pNormal.xy, tangentNormal.z * pNormal.z));
        #endif

    //  Final normal
        tangentNormal *= facing;
        fixed3 worldNormal = WorldNormal(i.tspace0.xyz, i.tspace1.xyz, i.tspace2.xyz, tangentNormal);

    //  -----------------------------------------------------------------------
    //  Edgeblendfactor - in view space  
    //  This does not work on metal if we are using deferred rendering and enable ZWrite... - > force DepthNormalTexture?
        
        #if defined(SHADER_API_METAL) && defined(LUXWATERMETALDEFERRED)
            half origDepth = tex2Dproj(_Lux_GrabbedDepth, UNITY_PROJ_COORD(i.grabUV)).r;
        #else
            half origDepth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.grabUV));
        #endif

        float sceneDepth = LinearEyeDepth(origDepth);
        float viewDepth = sceneDepth - surfaceEyeDepth;

        viewDepth = viewDepth * orthoCorrection * orthoDepthCorrection;
        
        float edgeBlendFactor = saturate (_InvFade * viewDepth);
        float origEdgeBlendFactor = edgeBlendFactor;

    //  -----------------------------------------------------------------------
    //  Refraction - calculate distorted grab UVs   
    //  Calculate fade factor for refraction according to depth
        float perspectiveFadeFactor = i.grabUV.z; // Works on metal and dx11 but not opengl
        #if defined(UNITY_REVERSED_Z)           
            perspectiveFadeFactor = 1.0 - perspectiveFadeFactor;
        #else
            #if defined (SHADER_API_GLCORE)
                perspectiveFadeFactor = 1.0 - perspectiveFadeFactor * _ProjectionParams.w;
            #endif
        #endif
    //  Somehow handle orthographic projection
        perspectiveFadeFactor = (unity_OrthoParams.w) ? orthoDepthCorrection * 0.1 : perspectiveFadeFactor;

        float2 offsetFactor = _GrabTexture_TexelSize.xy * _Refraction * perspectiveFadeFactor * edgeBlendFactor;
        float2 offset = worldNormal.xz * offsetFactor;
        float4 distortedGrabUVs = i.grabUV;
        distortedGrabUVs.xy += offset;

    //  Snap distortedGrabUVs to pixels as otherwise the depth texture lookup will return
    //  a false depth which leads to a 1 pixel error (caused by fog and absorption) at high depth and color discontinuities (e.g. ship above ground).
        float2 snappedDistortedGrabUVs = distortedGrabUVs.xy / distortedGrabUVs.w;
        #if defined(GEOM_TYPE_BRANCH)
        //  Casting to int and float actually looks better than using round
        //  snappedDistortedGrabUVs =  (float2)((int2)(snappedDistortedGrabUVs * _GrabTexture_TexelSize.zw + float2(1, 1))) - float2(0.5, 0.5); 
        //  snappedDistortedGrabUVs *= _GrabTexture_TexelSize.xy;

    //  As proposed by bgolus:
            snappedDistortedGrabUVs = (floor(snappedDistortedGrabUVs * _GrabTexture_TexelSize.zw) + 0.5) / _GrabTexture_TexelSize.zw;
        #endif

    //  -----------------------------------------------------------------------
    //  Do not grab pixels from foreground 
        #if defined(SHADER_API_METAL) && defined(LUXWATERMETALDEFERRED)
            float refractedRawDepth = tex2Dlod(_Lux_GrabbedDepth, float4(snappedDistortedGrabUVs, 0, 0) ).r;
        #else
            float refractedRawDepth = SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, float4(snappedDistortedGrabUVs, 0, 0));
        #endif        
        float refractedSceneEyeDepth = LinearEyeDepth(refractedRawDepth);
        if ( refractedSceneEyeDepth < surfaceEyeDepth) {
            distortedGrabUVs = i.grabUV;
            refractedRawDepth = origDepth;
            snappedDistortedGrabUVs = i.grabUV / i.grabUV.w;
        }
    //  Get final scene 01 and eye depth
        refractedSceneEyeDepth = LinearEyeDepth(refractedRawDepth);
        float refractedScene01Depth = Linear01Depth (refractedRawDepth);
        viewDepth = refractedSceneEyeDepth - surfaceEyeDepth;

        viewDepth = viewDepth * orthoCorrection * orthoDepthCorrection;

    //  Adjust edgeBlendFactor according to the final refracted depth sample
        edgeBlendFactor = saturate (_InvFade * viewDepth); //  * orthoDepthCorrection );

    //  -----------------------------------------------------------------------
    //  Fog and Absorption

    //  Reconstruct world position of refracted pixel
        float3 ray = i.ViewRay_WaterYpos.xyz;
        ray = ray * (_ProjectionParams.z / ray.z); // in ortho ray.z is 0.0. look at: https://github.com/keijiro/DepthInverseProjection/blob/master/Assets/InverseProjection/Resources/InverseProjection.shader

    //  This is only an estimation as the view vector is not correct
        float4 vpos = float4(ray * refractedScene01Depth, 1);
        float3 wpos = mul (unity_CameraToWorld, vpos).xyz;
 
        #if defined(USINGWATERVOLUME)
            #define waterYPos _WaterSurfaceYPos
        #else
            #define waterYPos i.ViewRay_WaterYpos.w
        #endif


    //  for foam / caustics in forward
        float4 vposUnrefracted = float4(ray * Linear01Depth(origDepth), 1);
        float3 wposUnrefracted = mul(unity_CameraToWorld, vposUnrefracted).xyz;

    //  Calculate Depth Attenuation based on world position and water y
        float depthAtten = saturate( (waterYPos - wpos.y - _DepthAtten.x) / (_DepthAtten.y) );
        depthAtten = saturate( 1.0 - exp( -depthAtten * 8.0) )  * saturate(_DepthAtten.z);

        viewDepth = (backside) ? surfaceEyeDepth : viewDepth;

    //  Calculate Attenuation along viewDirection
        float viewAtten = saturate( 1.0 - exp( -viewDepth * _Density) );

    //  Store final fog density
        half FogDensity = saturate( max(depthAtten, viewAtten));

    //  Absorption  
        float3 ColorAbsorption = float3(0.45f, 0.029f, 0.018f);
        
    //  Calculate Depth Attenuation
        float depthBelowSurface = saturate( (waterYPos - wpos.y)  / _AbsorptionMaxHeight);
        depthBelowSurface = exp2(-depthBelowSurface * depthBelowSurface * _AbsorptionHeight);

    //  Calculate Attenuation along viewDirection
        float d = exp( -viewDepth * _AbsorptionDepth );
    //  Combine and apply strength
        d = lerp (1, saturate( d * depthBelowSurface), _AbsorptionStrength );

    //  Cancel absorption by fog
        d = saturate(d + FogDensity * _FogAbsorptionCancellation);

    //  Add color absorption
        ColorAbsorption = lerp( d, -ColorAbsorption, _AbsorptionColorStrength * (1.0 - d));    
        ColorAbsorption = saturate(ColorAbsorption   );

    //  -----------------------------------------------------------------------
    //  Front face rendering only
        
        #if defined(SHADER_D3D11) || defined(SHADER_XBOXONE) || defined(SHADER_VULKAN) || defined(SHADER_API_GLCORE) || defined(SHADER_API_METAL)
            UNITY_BRANCH
            if (facing > 0.0f) {
        #endif

                //  -----------------------------------------------------------------------
                //  Caustics
                    #if defined(GEOM_TYPE_FROND)
                        float CausticsTime = _Time.x * _CausticsSpeed;

                        #if defined(GEOM_TYPE_LEAF)
                            half3 gNormal = tex2Dproj(_CameraGBufferTexture2, UNITY_PROJ_COORD(distortedGrabUVs)).rgb;
                            gNormal = gNormal * 2 - 1;
                        #else
                            half3 gNormal = normalize(cross(ddx(wposUnrefracted), ddy(wposUnrefracted))); // this produces gaps
                            //half3 gNormal = normalize(cross(ddx(wpos), ddy(wpos))); // This of course would be correct but shows up crazy discontinueties.
                            gNormal.y = -gNormal.y;
                        #endif

                        float2 cTexUV = wpos.xz * _CausticsTiling       + offset;
                        float2 mainDir = _FinalBumpSpeed01.xy;
                    //  Make caustics distort themselves by adding gb
                        fixed4 causticsSample = tex2D(_CausticTex, cTexUV + CausticsTime.xx * mainDir);
                        causticsSample += tex2D(_CausticTex, cTexUV * 0.78 + float2(-CausticsTime, -CausticsTime * 0.87) * mainDir + causticsSample.gb * _CausticsSelfDistortion );
                        causticsSample += tex2D(_CausticTex, cTexUV * 1.13 + float2(CausticsTime, 0.36) * mainDir - causticsSample.gb * _CausticsSelfDistortion );

                        //causticsSample = tex2D(_CausticTex, cTexUV + CausticsTime.xx * mainDir);
                        //fixed4 causticsSample1 = tex2D(_CausticTex, cTexUV * 0.78 + float2(-CausticsTime, -CausticsTime * 0.87) * mainDir + causticsSample.gb*0.2 );
                        //causticsSample = tex2D(_CausticTex, cTexUV + CausticsTime.xx * mainDir + float2(causticsSample.g, causticsSample1.b) * 0.1);

                        Caustics = causticsSample.r * saturate( (gNormal.y - 0.125) * 2);
                        Caustics *= _CausticsScale * edgeBlendFactor * edgeBlendFactor; 
                    #endif

            #if defined(SHADER_D3D11) || defined(SHADER_XBOXONE) || defined(SHADER_VULKAN) || defined(SHADER_API_GLCORE) || defined(SHADER_API_METAL)
                }
            #endif
    //  End of front face rendering only
    //  -----------------------------------------------------------------------


    //  -----------------------------------------------------------------------
    //  Foam
        #if defined(GEOM_TYPE_BRANCH_DETAIL)
            const half FoamSoftIntersectionFactor = .75;

            float height = _FoamParallax * worldNormal.z;
        
        //  Compute parallax offset based on texture mapping
            #if defined(EFFECT_BUMP)
                float3 tangentSpaceViewDir = i.tspace0.xyz * worldViewDir.x + i.tspace1.xyz * worldViewDir.y + i.tspace2.xyz * worldViewDir.z;
                float2 parallaxOffset = normalize(tangentSpaceViewDir.xy) * height;
            #else
                float2 parallaxOffset = worldViewDir.xz * height;
            #endif

        //  float2 foamUVS = IN.worldPos.xz * _FoamTiling + _Time.xx * _FinalBumpSpeed01.xy * _FoamSpeed + worldNormal.xz*0.05 + parallaxOffset;
        //  We want the distortion from the Gerstner waves, so we have to use IN.BumpUVs
            float2 foamUVS = i.BumpUVs.xy * _FoamTiling + _Time.xx * _FoamSpeed * _FinalBumpSpeed01.xy  + parallaxOffset;
            half4 rawFoamSample = tex2D(_MainTex, foamUVS );
            half FoamSample = 1; //(rawFoamSample.a * _FoamScale);

            half FoamThreshold = tangentNormal.z * 2 - 1;

        //  SceneDepth looks totally boring...
            //half FoamSoftIntersection = saturate( _FoamSoftIntersectionFactor * (min(sceneDepth,refractedSceneEyeDepth) - surfaceEyeDepth ) );
            half FoamSoftIntersection = saturate( _FoamSoftIntersectionFactor * viewDepth); // (refractedSceneEyeDepth - surfaceEyeDepth ) ); 

            //  This introduces ghosting:
            //  FoamSoftIntersection = min(FoamSoftIntersection, saturate( _FoamSoftIntersectionFactor *   (waterYPos - wposUnrefracted.y) ) );
            //  This does not really help:
            //  FoamSoftIntersection = min(FoamSoftIntersection, saturate( _FoamSoftIntersectionFactor *   (waterYPos - wpos.y) ) );

        //  Get shoreline foam mask
            float shorelineFoam = saturate(-FoamSoftIntersection * (1 + FoamThreshold.x) + 1 );
            shorelineFoam = shorelineFoam * saturate(FoamSoftIntersection - FoamSoftIntersection * FoamSoftIntersection );
            FoamSample *= shorelineFoam;

        //  Get foam caps
            half underWaterFoam = 0;
            #if defined(_GERSTNERDISPLACEMENT)
                float foamCaps = i.color.a;
                foamCaps = saturate(foamCaps * _FoamCaps);
                foamCaps *= foamCaps;
                FoamSample += foamCaps;
                half4 underwaterFoamSample = tex2D(_MainTex, foamUVS * 0.637 );
                underWaterFoam = smoothstep(0.0, 0.75, foamCaps * 1.5 * underwaterFoamSample.a);
            #endif

        //  Mask foam by the water's normals
            FoamSample *= saturate(0.6 + (tangentNormal.x * tangentNormal.z) * 2.0);

            FoamSample = saturate(FoamSample * _FoamScale);
            FoamSample = FoamSample * smoothstep( 0.8 - rawFoamSample.a, 1.6 - rawFoamSample.a, FoamSample) * _FoamScale;

        //  Add Foam Projectors
            #if defined (USINGWATERPROJECTORS)
                fixed4 projectedFoam = tex2D(_LuxWater_FoamOverlay, projectionUVs);
            //  This way we get "regular" foam
                FoamSample = saturate(FoamSample + projectedFoam.r  
                #if defined(_GERSTNERDISPLACEMENT)
                    * vignette
                #endif
                * smoothstep( 0.8 - rawFoamSample.a, 1.6 - rawFoamSample.a, projectedFoam.r));
            #endif

            Foam.a = saturate(FoamSample * _FoamColor.a);
            Foam.rgb = _FoamColor.rgb;

            half backsideFoamScale = (backside) ? 0.25 : 1;
            
            half3 FoamNormal = UnpackScaleNormal(rawFoamSample.rgbr, Foam.a * _FoamNormalScale * backsideFoamScale);
            FoamNormal.z *= facing;
        //  TODO: Why do i have to flip the normals here? Was a bug.
            // FoamNormal.xy *= -1;

        //  Add simple Foam Projectors
            #if defined (USINGWATERPROJECTORS)
                //Foam.rgb = lerp(o.Foam.rgb, half3(1,0,0), saturate(projectedFoam.g + (1 - o.Foam.a ) * 64 * projectedFoam.g    ) );
                Foam.a = saturate(Foam.a + projectedFoam.g
                    #if defined(_GERSTNERDISPLACEMENT)
                        * vignette
                    #endif
                );
            #endif

        //  Tweak all other outputs
            Translucency *= (1.0 - Foam.a);
            tangentNormal = lerp(tangentNormal, FoamNormal, Foam.a);
            Smoothness = lerp(Smoothness, 0.1, Foam.a);
            ReflectionSmoothness = lerp(ReflectionSmoothness, 0.1, Foam.a);
            Caustics *= (1.0 - Foam.a);

        //  Add underwater foam to foam mask
            #if defined(_GERSTNERDISPLACEMENT)
                Foam.a = saturate(Foam.a + underWaterFoam);
            #endif

        //  Recalculate worldNormal
            worldNormal = WorldNormal(i.tspace0.xyz, i.tspace1.xyz, i.tspace2.xyz, tangentNormal);

        #endif

    //  Calculate ReflectionNormal
        fixed3 ReflectionNormal = lerp( worldNormalFace * facing, worldNormal, _ReflectionBumpScale);

    //  -----------------------------------------------------------------------
    //  Reflections

        half3 Reflections;

    //  Planar reflections
        #if defined (GEOM_TYPE_MESH)
            #if defined (UNITY_PASS_FORWARDBASE)
                float2 reflOffset = ReflectionNormal.xz * offsetFactor;
                float2 refluv = (i.grabUV.xy / i.grabUV.w) + reflOffset;
                Reflections = tex2D(_LuxWater_ReflectionTex, refluv.xy);
            #else
                Reflections = 0;
            #endif
        #endif


    //  -----------------------------------------------------------------------
    //  Set missing data for BRDF
        
        #if defined (UNITY_PASS_FORWARDBASE)
            half3 Refraction = tex2Dlod(_GrabTexture, float4(snappedDistortedGrabUVs,0,0) ).rgb;
        #else
            half3 Refraction = 0;
        #endif

        half Occlusion = 1;
        half3 OrigRefraction = Refraction;
    


    //  -----------------------------------------------------------------------
    //  Init Lighting
        
    //  World LightDir
        #ifndef USING_DIRECTIONAL_LIGHT
            fixed3 lightDir = normalize(UnityWorldSpaceLightDir( worldPos ));
        #else
            fixed3 lightDir = _WorldSpaceLightPos0.xyz;
        #endif
    //  Light Attenuation and color
        UNITY_LIGHT_ATTENUATION(atten, i, worldPos);
        half3 lightColor = _LightColor0.rgb * atten;


    //  GI lighting (ambient sh and reflections)
        #if defined (UNITY_PASS_FORWARDBASE)
            UnityGI gi;
            UnityGIInput giInput;
            UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);

            giInput.worldPos = worldPos;
            giInput.worldViewDir = worldViewDir;
            //giInput.ambient.rgb = 0.0;

            giInput.probeHDR[0] = unity_SpecCube0_HDR;
            giInput.probeHDR[1] = unity_SpecCube1_HDR;
            #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
                giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
            #endif
            #ifdef UNITY_SPECCUBE_BOX_PROJECTION
                giInput.boxMax[0] = unity_SpecCube0_BoxMax;
                giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
                giInput.boxMax[1] = unity_SpecCube1_BoxMax;
                giInput.boxMin[1] = unity_SpecCube1_BoxMin;
                giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
            #endif
        //  Planar reflections
            #if defined (GEOM_TYPE_MESH)
                gi = UnityGlobalIllumination(giInput, Occlusion, worldNormal);
                gi.indirect.specular = Reflections;
        //  Cubemap reflections
            #else
                Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(ReflectionSmoothness, worldViewDir, ReflectionNormal, Specular);
                gi = UnityGlobalIllumination(giInput, Occlusion, worldNormal, g);
            #endif
        #endif

    //  -----------------------------------------------------------------------
    //  Direct and indirect Lighting

        half oneMinusReflectivity = 1 - SpecularStrength(Specular);

        half perceptualRoughness = SmoothnessToPerceptualRoughness (Smoothness);
        half3 halfDir = Unity_SafeNormalize (lightDir + worldViewDir);
        half nv = abs(dot(worldNormal, worldViewDir));
        half nl = saturate(dot(worldNormal, lightDir));
        half nh = saturate(dot(worldNormal, halfDir));
        half lv = saturate(dot(lightDir, worldViewDir));
        half lh = saturate(dot(lightDir, halfDir));

        half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
        half V = SmithJointGGXVisibilityTerm (nl, nv, roughness);
        half D = GGXTerm (nh, roughness);
        half specularTerm = V*D * UNITY_PI;
        specularTerm = max(0, specularTerm * nl);

        half grazingTerm = saturate(Smoothness + (1 - oneMinusReflectivity));

    //  Calculate ambient fresnel
        half surfaceReduction;
        #ifdef UNITY_COLORSPACE_GAMMA
            surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
        #else
            surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
        #endif

        half3 aFresnel;

        UNITY_BRANCH
        if(backside) {
            aFresnel = LuxFresnelLerpUnderwater (grazingTerm, nv);
        }
        else {
            aFresnel = LuxFresnelLerp (Specular, grazingTerm, nv);
        }

        half3 specularLighting = specularTerm * lightColor * FresnelTerm (Specular, lh);

    //  Add reflections
        #if defined (UNITY_PASS_FORWARDBASE)
           specularLighting += surfaceReduction * gi.indirect.specular * aFresnel * _ReflectionStrength * ( (backside) ? (_UnderWaterReflCol.rgb) : 1.0);
        #endif

        Refraction *= 1 - aFresnel;


    //  Diffuse lighting for underwater fog
        half diffuse_nl = saturate(dot(half3(0,1,0), lightDir));
        #if defined (UNITY_PASS_FORWARDBASE)
            //gi.indirect.diffuse is not equal _Lux_AmbientSkyLight   
            half3 diffuseUnderwaterLighting = lightColor * diffuse_nl;
            float viewScatter = 1.0 - saturate( dot(lightDir, worldViewDir ) + 1.75 );
            diffuseUnderwaterLighting *= 1 + viewScatter * 2;
            #if defined(USINGWATERVOLUME)
                diffuseUnderwaterLighting = _Color * (diffuseUnderwaterLighting + _Lux_UnderWaterAmbientSkyLight);
            #else
                diffuseUnderwaterLighting = _Color * (diffuseUnderwaterLighting + gi.indirect.diffuse);
            #endif
        #else
            half3 diffuseUnderwaterLighting = _Color * (lightColor * diffuse_nl );
        #endif

    //  Add caustics
        Refraction.rgb += Caustics * lightColor * diffuse_nl * saturate(ColorAbsorption); // Why did i choose "* diffuse_nl" here?
        if (backside) {
            Refraction.rgb *= 1 - aFresnel;
            Refraction.rgb *= 1 - Foam.a;
        }

    //  Add underwater fog
        Refraction.rgb = lerp(Refraction.rgb, diffuseUnderwaterLighting, FogDensity);
    
    //  Apply absorption – important: absorption might be negative!
        Refraction.rgb *= saturate(ColorAbsorption);

    //  Add translucent lighting
        half3 lightScattering = 0;
        //  https://colinbarrebrisebois.com/2012/04/09/approximating-translucency-revisited-with-simplified-spherical-gaussian/
        half3 transLightDir = lightDir - worldNormal * 0.1;
        half transDot = dot( -transLightDir, worldViewDir);
        transDot = exp2(saturate(transDot) * _ScatteringPower - _ScatteringPower);
    //  Using abs to get some translucency when rendering underwater
        transDot *= saturate( (1.0 - abs(worldNormal.y)) * 2);
        lightScattering = transDot * lightColor * Translucency;

    //  Cancel lightScattering by fog
        if (backside) {
            lightScattering *= (1 - FogDensity * FogDensity * FogDensity);
        }
        Refraction += saturate(lightScattering * _TranslucencyColor * 10);
    
    //  Diffuse lighting at the surface = foam
        #if defined (GEOM_TYPE_BRANCH_DETAIL)
            // As it is just foam here, we skip DisneyDiffuse and use Lambert (NdotL) – roughly 74fps instead of 72? (+3%)
            // half diffuseTerm = DisneyDiffuse(nv, nl, lh, perceptualRoughness) * nl;
            half3 diffuseLighting = Foam.rgb /** Foam.a */ * (
                #if defined (UNITY_PASS_FORWARDBASE)
                    gi.indirect.diffuse + 
                #endif
                //lightColor * diffuseTerm 
                lightColor * nl
            );

            UNITY_BRANCH
            if(backside) {
            //  Add underwater fog
                diffuseLighting = lerp(diffuseLighting, diffuseUnderwaterLighting, FogDensity);
            //  Apply absorption – important: absorption might be neagtive!
                diffuseLighting.rgb *= saturate(ColorAbsorption);
            }
        //  Blend between water and foam
            Refraction = lerp(Refraction, diffuseLighting, Foam.a);
        #endif

    //  Cancel reflections by fog
        if (backside) {
            specularLighting *= (1 - FogDensity);
        }

        c.rgb = Refraction + specularLighting;

    

    //  Needed by custom fog
        float ClipSpaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.grabUV.z);

        //  Custom fog
        #if !defined (UNITY_PASS_FORWARDADD)
            if (!backside) {
                float unityFogFactor = 1;
        #if defined(FOG_LINEAR)
                unityFogFactor = (ClipSpaceDepth) * unity_FogParams.z + unity_FogParams.w;
        #elif defined(FOG_EXP)
                unityFogFactor = unity_FogParams.y * (ClipSpaceDepth);
                unityFogFactor = exp2(-unityFogFactor);
        #elif defined(FOG_EXP2)
                unityFogFactor = unity_FogParams.x * (ClipSpaceDepth);
                unityFogFactor = exp2(-unityFogFactor * unityFogFactor);
        #endif
                c.rgb = lerp(unity_FogColor.rgb, c.rgb, saturate(unityFogFactor));
            }
        #endif

    //  Smooth water edges
        c.rgb = lerp(OrigRefraction, c.rgb, edgeBlendFactor);

        return half4(c.rgb, 1);
    }