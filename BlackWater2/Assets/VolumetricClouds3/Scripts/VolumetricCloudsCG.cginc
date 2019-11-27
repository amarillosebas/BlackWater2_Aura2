// UNITY_SHADER_NO_UPGRADE

#include "UnityCG.cginc"
#include "Lighting.cginc"

#define   pf1 float
#define   pf2 float2
#define   pf3 float3
#define   pf4 float4
#define pf4x4 float4x4

#define   f1 half
#define   f2 half2
#define   f3 half3
#define   f4 half4
#define f4x4 half4x4


#if UNITY_VERSION < 540
	float4x4 unity_CameraToWorldFallback;
	#define unity_CameraToWorld unity_CameraToWorldFallback
#endif

#if !SHADER_API_OPENGL && !SHADER_API_GLES3 && !SHADER_API_GLES && !SHADER_API_METAL
#define LOOP [loop]
#define UNROLL_LOOP [unroll]
#else
#define LOOP ;
#define UNROLL_LOOP ;
#endif

// TRANSFORMS
f1 _Tiling, _Coverage, _CoverageLow, _CoverageHigh, _SphereHorizonStretch;
sampler2D _PerlinNormalMap, _CoverageMap;
f4 _PerlinNormalMap_ST, _CoverageMap_ST;
f4 _WindDirection, _CloudTransform, _CloudSpherePosition;
f1 _CloudBaseFlatness, _CloudFlatness, _CloudLocalScale;

// TIME
f4 _TimeEditor;
f1 _TimeMult, _TimeMultSecondLayer;

// COLOR AND SHADING
f4 _VisiblePointLights[64], _VisiblePointLightsColor[64];
int _VisibleLightCount;
f4 _BaseColor, _Shading, _ShadowColor;
f4 _SkyLightAttenuation;
f1 _SilverLining, _IndirectOcclusion, _IndirectOcclusionNormalized, _DirectContribution;
f1 _NormalsIntensity, _Normalized, _IndirectContribution, _IndirectSaturation;
f1 _AlphaCut, _DistanceBlend;
f1 _BlendWithShadowmap;

// RAYMARCHER
f4x4 _ToWorldMatrix;
int _MaxSteps;
f1 _StepSize, _StepNearSurface, _StepSkip, _StepParallelMult, _CloudDensity;
f1 _LodBase, _LodOffset, _DrawDistance;
int _ShowStepCount;



f1 _OrthographicPerspective;


sampler2D _SceneGrab;
#ifdef UNITY_DECLARE_DEPTH_TEXTURE
UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
#else
sampler2D _CameraDepthTexture;
#endif

#if !defined(SHADOWMAPSAMPLER_DEFINED)
sampler2D _ShadowMapTexture;
#endif

struct Light
{
	f3 color;
	f3 dir;
};

struct VOUT
{
	pf4 pos : POSITION;
	pf4 clipPos : TEXCOORD0;
	pf3 eyeVec : TEXCOORD1;
	pf3 planePos : TEXCOORD2;
	pf3 ray : TEXCOORD3;
};

static Light light;


#define CloudCenterBounds _CloudTransform.x
#define CloudUpperBounds (CloudCenterBounds + _CloudTransform.y)
#define CloudLowerBounds (CloudCenterBounds - _CloudTransform.y)

#define TAU 6.28318530717958647692




VOUT vertForwardModified (pf4 vertex : POSITION)
{
	VOUT o = (VOUT)0;
	o.pos = mul(UNITY_MATRIX_MVP, vertex);
	#if UNITY_VERSION >= 540
		o.clipPos = UnityObjectToClipPos(vertex);
		o.planePos = mul(unity_ObjectToWorld, vertex);
		o.ray = UnityObjectToViewPos(vertex);
	#else
		o.clipPos = mul(UNITY_MATRIX_MVP, pf4(vertex.xyz, 1.0));
		o.planePos = mul(_Object2World, vertex);
		o.ray = mul(UNITY_MATRIX_V, o.planePos).xyz;
	#endif
	o.ray *= pf3(-1,-1,1);
	o.eyeVec = lerp(o.planePos.xyz - _WorldSpaceCameraPos, UNITY_MATRIX_IT_MV[2].xyz, _OrthographicPerspective * UNITY_MATRIX_P[3][3]);
	
	
	return o;
}





/*\ SPHERE GEOMETRIC FUNCTIONS \*/





// Not really precise but works well enough for now
inline f3 TransformNormalsAroundSphere(f3 normalPlanar, f3 samplePosOnSphere)
{
	f1 dotF = dot(samplePosOnSphere, f3(0, 0, 1));
	f1 dotU = dot(samplePosOnSphere, f3(0, 1, 0));
	f3 fwdDir = normalize(f3(0, 0, 1) * dotU + f3(0, -1, 0) * dotF);
	f3 rightDir = normalize(cross(samplePosOnSphere, fwdDir));
	f1 scalar = clamp(samplePosOnSphere.y*2, -1, 1);
	return normalize(normalPlanar.x * rightDir * scalar + normalPlanar.y * samplePosOnSphere + normalPlanar.z * fwdDir * scalar);
}

inline f2 ComputeSphereUV(f3 deltaFromCenter)
{
	#if _SPHERICAL_MAPPING
	f3 p = normalize(deltaFromCenter);
	return f2(atan2(p.x, p.z)/* / TAU + 0.5*/, acos(p.y)) * 1000;
	#else
	return deltaFromCenter.xz * pow((CloudUpperBounds-abs(deltaFromCenter.y))/CloudUpperBounds, _SphereHorizonStretch);
	#endif
}

inline f3 RaySphereIntersection(f3 spherePos, f1 sphereRadius, f3 rayPos, f3 rayDirection, f1 fromOutside, out bool oob)
{
	f3 rayPosToSpherePos = (spherePos - rayPos);
	f1 sphereDirPerpOffset = dot(rayPosToSpherePos, rayDirection);
	f3 dirPerpToSpherePos = rayDirection * sphereDirPerpOffset;

	f3 centerToPerp = (dirPerpToSpherePos - rayPosToSpherePos);
	f1 centerToPerpMag = length(centerToPerp);
	// Are we still inside the sphere ?
	if (centerToPerpMag < sphereRadius)
	{
		f1 collisionOffset = sqrt(sphereRadius * sphereRadius - centerToPerpMag * centerToPerpMag);
		f3 collisionPoint = spherePos + (centerToPerp + rayDirection * collisionOffset * fromOutside);

		if (dot(collisionPoint - rayPos, rayDirection) > 0)
		{
			oob = false;
			return collisionPoint;
		}
	}
	oob = true;
	return 0;
}

inline f3 RaySphereIntersectionAlwaysFromInside(f3 spherePos, f1 sphereRadius, f3 rayPos, f3 rayDirection)
{

	f3 rayPosToSpherePos = (spherePos - rayPos);
	f1 sphereDirPerpOffset = dot(rayPosToSpherePos, rayDirection);
	f3 dirPerpToSpherePos = rayDirection * sphereDirPerpOffset;

	f3 centerToPerp = (dirPerpToSpherePos - rayPosToSpherePos);
	f1 centerToPerpMag = length(centerToPerp);
	// Are we still inside the sphere ?
	/*if (centerToPerpMag < sphereRadius)
	{*/
		f1 collisionOffset = sqrt(sphereRadius * sphereRadius - centerToPerpMag * centerToPerpMag);
		f3 collisionPoint = spherePos + (centerToPerp + rayDirection * collisionOffset);
		return collisionPoint;
		/*if (dot(collisionPoint - rayPos, rayDirection) > 0)
		{
			return collisionPoint;
		}*/
	//}
	return 0;

	/*
	f3 rayPosToSpherePos = (spherePos - rayPos);
	f1 sphereDirPerpOffset = dot(rayPosToSpherePos, rayDirection);
	f3 dirPerpToSpherePos = rayDirection * sphereDirPerpOffset;

	f3 centerToPerp = (dirPerpToSpherePos - rayPosToSpherePos);
	f1 centerToPerpMag = length(centerToPerp);

	f1 collisionOffset = sqrt(sphereRadius * sphereRadius - centerToPerpMag * centerToPerpMag);
	return spherePos + (centerToPerp + rayDirection * collisionOffset);*/
}

inline f3 IntersectionInSphere(f3 spherePos, f1 sphereRadius, f1 sphereDepth, f3 rayPos, f3 rayDirection, out bool oob)
{
	oob = false;

	// Is inside spheres, try to project along dir to closest border inside
	if (length(spherePos - rayPos) < sphereRadius - sphereDepth)
	{
		return RaySphereIntersection(spherePos, sphereRadius - sphereDepth, rayPos, rayDirection, 1, oob);
	}
	// Is outside spheres, try to project along dir to closest border outside
	else if (length(spherePos - rayPos) > sphereRadius + sphereDepth)
	{
		return RaySphereIntersection(spherePos, sphereRadius + sphereDepth, rayPos, rayDirection, -1, oob);
	}
	else
	{
		// Is between big sphere's surface and small sphere's surface, do nothing
		oob = false;
		return rayPos;
	}
}


// put sample pos on the closest point forward in sphere bounds, doesnt work properly for some reason
inline f3 IsInsideEmptySphere(f3 samplePos, f1 sampleDir)
{
	if(length(samplePos - _CloudSpherePosition) < CloudLowerBounds -0.1)
		return RaySphereIntersectionAlwaysFromInside(_CloudSpherePosition, CloudLowerBounds, samplePos, sampleDir);

	return samplePos;
}





/*\ BOX GEOMETRIC FUNCTIONS \*/





inline f3 IntersectionOnPlane(f3 offsetOrthogonalToPlane, f3 rayDirection, out bool oob)
{
	f1 dotToSurface = dot(normalize(offsetOrthogonalToPlane), rayDirection);
	if(dotToSurface <= 0.0)
	{
		oob = true;
		return f3(0, 0, 0);
	}
	oob = false;
	return rayDirection * length(offsetOrthogonalToPlane) / dotToSurface;
}





/*\ COMMON FUNCTIONS \*/





inline f1 FromVolumeCenterSigned(f3 samplePos)
{
#if _SPHERE_MAPPED
	f3 dirToSphereCenter = normalize(samplePos - _CloudSpherePosition);
	f3 deltaToCloudCenter = samplePos - (_CloudSpherePosition + dirToSphereCenter * CloudCenterBounds);
	f1 deltaLength = length(deltaToCloudCenter);
	f1 dist = deltaLength * sign(dot(deltaToCloudCenter / deltaLength, dirToSphereCenter));
#else
	f1 dist = (samplePos.y - CloudCenterBounds);
#endif
	dist /= _CloudTransform.y;
	#if !_NEW_SHADING
	    dist = dist > 0 ? smoothstep(0, 1, dist) : smoothstep(0, 1, 1+dist)-1;
	#endif
	dist += (1-abs(dist)) * _CloudBaseFlatness;
	dist = sign(dist) * pow(abs(dist), 1 / _CloudFlatness);
	return dist;
}

inline bool IsOutsideCloudBounds(f3 samplePos, f1 sampleDir)
{
#if _SPHERE_MAPPED
	return distance(samplePos, _CloudSpherePosition) > CloudUpperBounds + 0.1;
#else
	return samplePos.y > CloudUpperBounds + 0.01 || samplePos.y < CloudLowerBounds - 0.01;
#endif
}

inline f3 PlaceSamplePosInBounds(f3 samplePos, f3 initDir, out bool oob)
{
#if _SPHERE_MAPPED
	oob = true;
	samplePos = IntersectionInSphere(_CloudSpherePosition, CloudCenterBounds, _CloudTransform.y, samplePos, initDir, oob);
	return samplePos;
#else
	oob = false;
	if(samplePos.y > CloudUpperBounds)
	{
		f3 offsetOrthoToBounds = f3(samplePos.x, CloudUpperBounds, samplePos.z) - samplePos;
		f3 offsetToBounds = IntersectionOnPlane(offsetOrthoToBounds, initDir, oob);

		return samplePos += offsetToBounds;
	}
	if(samplePos.y < CloudLowerBounds)
	{
		f3 offsetOrthoToBounds = f3(samplePos.x, CloudLowerBounds, samplePos.z) - samplePos;
		f3 offsetToBounds = IntersectionOnPlane(offsetOrthoToBounds, initDir, oob);

		return samplePos += offsetToBounds;
	}
	return samplePos;
#endif
}





/*\ VOLUME SAMPLING \*/





inline f1 SampleClouds2DNoise(f2 UV, f1 lod, out f4 cloudTexture, out f4 cloudTexture2, out f1 coverage)
{
	f2 baseAnimation = (_Time.g + _TimeEditor.g) * 0.001 * _WindDirection.xz;
	f2 worldUV = (UV+_CloudTransform.zw)/_Tiling;

	f2 newUV = worldUV - (baseAnimation * _TimeMult);
	
	// offset of half on both axis to avoid most possible overlap between both layers, 
	// if winddir is (.5,.5) or (-.5,-.5) it will still overlap, 
	// in which case we'll have to create a vector that is offset locally from windir instead, this will require
	// using a bunch of costly trig function wich I am not willing to sacrifice performances for.
	f2 newUV2 = worldUV + f2(0.5, 0.5) - (baseAnimation * _TimeMultSecondLayer);

	cloudTexture = tex2Dlod(_PerlinNormalMap, f4(newUV, 0, lod));
	cloudTexture2 = tex2Dlod(_PerlinNormalMap, f4(newUV2, 0, lod));

	coverage = _Coverage;

#if _COVERAGEMAP
	f1 coverageMap = tex2Dlod(_CoverageMap, f4((UV+_CoverageMap_ST.zw)/_CoverageMap_ST.xy, 0, lod)).r;
	coverage += lerp(_CoverageLow, _CoverageHigh, coverageMap);
#endif

	return ((cloudTexture.a - cloudTexture2.a)*_CloudLocalScale + coverage);
}

inline f4 SampleBase(f3 samplePos, f1 lod, out f4 tex1, out f4 tex2, out f1 coverage, out f1 centerDist)
{
	centerDist = FromVolumeCenterSigned(samplePos);
	#if _SPHERE_MAPPED
		f2 UV = ComputeSphereUV(samplePos - _CloudSpherePosition);
	#else
		f2 UV = samplePos.xz;
	#endif

	f4 cloud = SampleClouds2DNoise(UV, lod, tex1, tex2, coverage);
	#if _SPHERE_MAPPED && _SPHERICAL_MAPPING
		f3 dirFromCenter = normalize(samplePos - _CloudSpherePosition);
		cloud.a *= saturate((1.0 - abs(dirFromCenter.y)) / _SphereHorizonStretch);
	#endif
	// Treat the alpha of the texture as height and remap it to cloud density
	cloud.a -= abs(centerDist);
	return cloud;
}

inline f4 SampleClouds(f3 samplePos, f1 lod, out f1 centerDist)
{
	f1 coverage;
	f4 tex1, tex2;
	f4 cloud = SampleBase(samplePos, lod, tex1, tex2, coverage, centerDist);
	#if _NORMALMAP
		// Remap normals from unit to normalized space
		tex1.xyz = tex1.xyz*2-1;
		tex2.xyz = tex2.xyz*2-1;
		cloud.xyz = normalize(  (tex1.xyz*tex1.a - tex2.xyz*tex2.a) + f3(0, 0, saturate(coverage))  );
	#endif
	return cloud;
}

inline f1 SampleShadows(f3 samplePos, f1 lod, out f1 centerDist)
{
	f1 coverage;
	f4 tex1, tex2;
	return SampleBase(samplePos, lod, tex1, tex2, coverage, centerDist).a;
}





/*\ SHADING \*/





// seems to fail on 5.4, get some weird results when walking around
#define SAMPLE_GI(v3, lod) DecodeHDR ( SampleCubeReflection(unity_SpecCube0, v3, lod), unity_SpecCube0_HDR )



inline f3 PointLight(f3 samplePos, f4 light, f3 color)
{
	#if (X_AXIS)
		light.xyz = light.yxz;
	#elif (Z_AXIS)
		light.xyz = light.xzy;
	#endif
	f3 delta = light.xyz - samplePos;
	return (1 - min(distance(light.xyz, samplePos) / light.w, 1) ) * color.rgb;
}

#if _NEW_SHADING
#define SHADE(samplePos, viewDir, cloudSample, density, distanceFromCenter) Shade(samplePos, viewDir, cloudSample, density, distanceFromCenter)
#else
#define SHADE(samplePos, viewDir, cloudSample, density, distanceFromCenter) OldShade(samplePos, viewDir, cloudSample, density, distanceFromCenter)
#endif

inline f3 Shade(f3 samplePos, f3 viewDir, f4 cloudSample, f1 density, f1 distanceFromCenter)
{
	#if _DISABLE_INDIRECT && _DISABLE_DIRECT
	    return _BaseColor;
	#endif
	
	// Most of the constants below are magic numbers, nothing in here is based on a real lighting model
	f3 lightColor = light.color;
	f3 albedo = _BaseColor;
	f1 cappedDensity = min(density, 1);
	f3 final = 0;
	
	#if !_DISABLE_DIRECT
	{
	    f3 directLighting = 0;
        #if _NORMALMAP
            f3 normals = cloudSample.xzy;
            // orient upside down when under middle and reduce to zero near middle to avoid blending artifact
            normals.y = sign(distanceFromCenter) * abs(normals.y) * saturate(abs(distanceFromCenter)*10);
            normals = normalize(normals);
            #if _SPHERE_MAPPED
                normals = TransformNormalsAroundSphere(normals, normalize(samplePos - _CloudSpherePosition));
            #endif
            f1 nl = dot(normals, light.dir);
            nl = saturate(lerp(nl, nl * 0.5 + 0.5, _Normalized)) * _NormalsIntensity;
            directLighting += nl * lightColor;
            
            // Silver lining: non-abs n*v works pretty well weirdly enough
            f1 silverLining = 0;
            //silverLining += saturate(dot(normals, viewDir)) * saturate(dot(light.dir, viewDir));
            silverLining += 1-abs(dot(normals, viewDir));
            silverLining *= 1-cappedDensity;
            silverLining *= 1+saturate(dot(light.dir, viewDir));
            directLighting += silverLining * _SilverLining * lightColor;
        #else
            directLighting += lightColor;
        #endif
        
        // Point light contribution
        #if _HQPOINTLIGHT
            f3 pointLightContrib = 0;
            for(int j = 0; j < _VisibleLightCount; j++)
            {
                pointLightContrib += PointLight(samplePos, _VisiblePointLights[j], _VisiblePointLightsColor[j].rgb);
            }
            directLighting += pointLightContrib * (1-cappedDensity);
        #endif
	
	    final += _DirectContribution * directLighting * albedo;
	}
	#endif
	
	#if !_DISABLE_INDIRECT
	{
	    // Gradient from mid to bottom, [1 ... -_IndirectOcclusion]
        f1 skyOcclusion = lerp(min(distanceFromCenter * _IndirectOcclusion + 1, 1), lerp(1-_IndirectOcclusion, 1, (1+min(distanceFromCenter, 1))*0.5), _IndirectOcclusionNormalized);
        f3 IndirectLighting = lerp(_SkyLightAttenuation.rgb, 1, skyOcclusion);
        #if _COMPLEXLIGHTING_MODE
            f3 upDir;
            #if _SPHERE_MAPPED
                upDir = normalize(samplePos - _CloudSpherePosition);
            #else
                upDir = f3(0, 1, 0);
            #endif
            IndirectLighting *= lerp(1, SAMPLE_GI(upDir, 10), _IndirectSaturation);
        #endif
        final += _IndirectContribution * IndirectLighting * albedo;
	}
	#endif
	
	return lerp(_Shading.rgb, 1, max(final, 0));
}





inline f3 OldShade(f3 samplePos, f3 viewDir, f4 cloudSample, f1 density, f1 distanceFromCenter)
{

	// Most of the constants below are magic numbers, nothing in here is based on a real lighting model

	f1 silverLining = pow(1 - cloudSample.a, 8) * (1 - abs(distanceFromCenter)) / _CloudDensity;
	f3 attenuation = lerp(distanceFromCenter * 0.5 + 0.5, 1.0, _SkyLightAttenuation.rgb);

	#if _NORMALMAP
		f3 normals = normalize(f3(cloudSample.x * _NormalsIntensity, distanceFromCenter, cloudSample.y * _NormalsIntensity));
		#if _SPHERE_MAPPED
			normals = TransformNormalsAroundSphere(normals, normalize(samplePos - _CloudSpherePosition));
		#endif
		f1 nDotL = saturate(dot(normals, light.dir));
		nDotL = lerp(nDotL, nDotL * 0.5 + 0.5, _Normalized);
		nDotL = lerp(0, nDotL, silverLining);
	#else
		f1 nDotL = silverLining;
	#endif

	#if _SPHERE_MAPPED
	f3 upDir = normalize(samplePos - _CloudSpherePosition);
	#else
	f3 upDir = f3(0, 1, 0);
	#endif


	// Atmosphere contributes for a lot of direct lighting
	f3 lightColor = light.color;
	#if _COMPLEXLIGHTING_MODE
		f3 lightIndirect = SAMPLE_GI(light.dir, 0);
		lightColor = lerp(lightColor, lightIndirect, 0.5 * _IndirectContribution);
	#endif

	// Get indirect sky contribution
	#if _COMPLEXLIGHTING_MODE
		f3 IndirectIllumination = lerp(1, SAMPLE_GI(upDir, 10), _IndirectContribution);
	#else
		f3 IndirectIllumination = 1;
	#endif
	IndirectIllumination *= attenuation;

	f1 specular = 0;
	specular += max(dot(viewDir, light.dir), 0.0);
	specular = min(pow(specular, 6) * 16, 16);

	f3 final = 0;
	// Diffuse contribution
	final += nDotL * lightColor * 10;
	// Specular contribution
	final += specular * lightColor * pow(silverLining, 1.5);
	// Indirect contribution
	final += IndirectIllumination;
	final = lerp(_Shading.rgb, _BaseColor.rgb, final);


	// Point light contribution
	#if _HQPOINTLIGHT
		for(int j = 0; j < _VisibleLightCount; j++)
		{
			final += PointLight(samplePos, _VisiblePointLights[j], _VisiblePointLightsColor[j].rgb);
		}
	#endif


	return final;
}


























inline f1 GetLODScale(f1 distanceTravelled)
{
	return _LodBase + sqrt(sqrt(distanceTravelled) * _LodOffset);
}

// Not used, less accurate blending does a better job at hidding low step counts
#define ACCURATE_BLENDING
#define GAMMA 2.2

// argument 1/Front must be zero or a result of a previous BlendFrontToBack
inline f4 BlendFrontToBack(f4 front, f4 back)
{
	#ifdef ACCURATE_BLENDING
	// gamma to linear, prepare premult
	back = f4( pow( back.rgb, GAMMA ) * back.a, back.a);
	#else
	back.rgb *= back.a;
	#endif
	return front + back*(1.0 - front.a);
}

inline f4 ResolveBlending(f4 color)
{
	#ifdef ACCURATE_BLENDING
	// Linear to gamma, fix premult
	return f4( color.a != 0 ? pow( color.rgb/color.a, 1.0/GAMMA ) : color.rgb, color.a );
	#else
	// alpha range balance
	return color.a > 0 ? f4(color.rgb / color.a, color.a) : f4(1.0, 1.0, 1.0, 0);
	#endif
}



#define DEBUG_STEPCOLOR colors.rgba = _ShowStepCount ? lerp(f4(0, 1, 0, 1), f4(1, 0, 0, 1), (steps+1) / _MaxSteps) : colors.rgba;


inline void PushSampleForward(inout f3 samplePos, inout f1 distanceTravelled, f3 dir, f1 signedDist)
{
    #if _NEW_SHADING
    f1 offsetScale = 0;
    #else
    f1 offsetScale = _StepSize;
    #endif
    // negative dist can be used like a very imprecise distance to nearest cloud, use it to skip past empty space faster
    offsetScale += max(-signedDist * _StepSkip, 0.0);
    #if _NEW_SHADING
        float perp;
        #if _SPHERE_MAPPED
            perp = 1-abs(dot(normalize(samplePos - _CloudSpherePosition), dir));
        #else
            perp = 1-abs(dir.y);
        #endif
        
        offsetScale += _StepParallelMult * perp * max(-signedDist, 0.0);
        offsetScale = max(offsetScale, _StepSize);
    #endif
    distanceTravelled += offsetScale;
    samplePos += dir * offsetScale;
}


inline f1 DistanceBlend(f1 dist)
{
    return 1 - saturate(pow(dist / _DrawDistance, 1.0 / _DistanceBlend));
}

inline f4 RaymarchShadow(f3 initPos, f3 planePos, f1 renderedAlpha)
{

	f1 maximumShadowDrawDistance = min(_ProjectionParams.y + _ProjectionParams.z, _DrawDistance);
	if(distance(planePos, initPos) > maximumShadowDrawDistance || renderedAlpha >= .99f)
		return 0.0;
	// Init raymarching data
	f1 maxDepth = _DrawDistance;
	f3 initDir = light.dir;

	f3 samplePos = initPos;
	f4 colors = f4(1.0, 1.0, 1.0, 0.0);
	f1 distanceTravelled = 0.0;


	#if !(_VOLUMETRIC_SSS)
		// hack to force pos at the exact center
		f1 ogWidth = _CloudTransform.y;
		_CloudTransform.y = 0;
	#endif
	// PLACE SAMPLEPOS INSIDE CLOUD BOUNDS
	bool oob;
	samplePos = PlaceSamplePosInBounds(samplePos, initDir, oob);
	#if !(_VOLUMETRIC_SSS)
		_CloudTransform.y = ogWidth;
	#endif
	if(oob)
		return 0.0;
	distanceTravelled = distance(initPos, samplePos);

	f1 distToPlaneCamera = distance(initPos, planePos);
	f1 lodScale = GetLODScale(distToPlaneCamera);
	f1 distBlend = DistanceBlend(distToPlaneCamera);

	f1 opacityMax = 1;
	opacityMax *= distBlend;
	// Save some performance when in front of clouds but fails to blend properly
	//opacityMax = 1-renderedAlpha;


	// START RAYMARCH LOOP

	f1 steps = 0; // Keep track of our number of steps to display it in debug later
	#if _VOLUMETRIC_SSS
	LOOP
	for(steps = 0; steps < _MaxSteps; steps++)
	#else
	UNROLL_LOOP
	for(steps = 0; steps < 1; steps++)
	#endif
	{
		/*
		#if _SPHERE_MAPPED
			samplePos = IsInsideEmptySphere(samplePos, initDir);
		#endif
		*/

		// If current pos is outside of cloud bounds we are done, quit loop
		if(IsOutsideCloudBounds(samplePos, initDir))
			break;

		// If distance travelled is greater than draw distance or scene depth, quit loop
		if(distanceTravelled > maxDepth)
			break;

		f1 distanceFromCenter;
		f1 cloudDistSigned = SampleShadows(samplePos, lodScale, distanceFromCenter);

		f1 density = cloudDistSigned * _CloudDensity * opacityMax;
		if(density > 0.001)
		{
			f3 sampleColor = 1.0;
			colors = BlendFrontToBack(colors, f4(sampleColor, min(density, 1)));

			if(colors.a > 0.999 * opacityMax)
			{
				colors.a = opacityMax;
				break;
			}
		}
        
        PushSampleForward(/*inout*/samplePos, /*inout*/distanceTravelled, initDir, cloudDistSigned);
	}
	colors = ResolveBlending(colors);
	colors.rgb = SAMPLE_GI(f3(0, 1, 0), 10).rgb;
	colors *= _ShadowColor;

	DEBUG_STEPCOLOR;

	return colors;
}


inline f4 RaymarchClouds(f3 initDir, f3 initPos, f1 depth)
{
	// Init raymarching data
	f1 maxDepth = min(depth, _DrawDistance);

	f3 samplePos = initPos;
	f4 colors = 0.0;
	f1 distanceTravelled = 0.0;
	f1 lastHitDistanceTravelled = 10000.0;


	// PLACE SAMPLEPOS INSIDE CLOUD BOUNDS
	bool oob;
	samplePos = PlaceSamplePosInBounds(samplePos, initDir, oob);
	if(oob)
		return f4(1.0, 1.0, 1.0, 0.0);
	distanceTravelled = distance(initPos, samplePos);






	// START RAYMARCH LOOP

	f1 steps; // Keep track of our number of steps to display it in debug later
	LOOP
	for(steps = 0; steps < _MaxSteps; steps++)
	{
		/*
		#if _SPHERE_MAPPED
			samplePos = IsInsideEmptySphere(samplePos, initDir);
		#endif
		*/

		// If current pos is outside of cloud bounds we are done, quit loop
		if(IsOutsideCloudBounds(samplePos, initDir))
			break;

		// If distance travelled is greater than draw distance or scene depth, quit loop
		if(distanceTravelled > maxDepth)
			break;

		f1 lodScale = GetLODScale(distanceTravelled);
		f1 distanceFromCenter;
		f4 cloudSample = SampleClouds(samplePos, lodScale, distanceFromCenter);
		f1 cloudDistSigned = cloudSample.a;

		#if _DISTBLEND_POST
		const f1 opacityMax = 1.0;
		#else
		f1 opacityMax = DistanceBlend(distanceTravelled);
		#endif

		f1 density = cloudDistSigned * _CloudDensity * opacityMax;
		if(density > 0.001)
		{
			lastHitDistanceTravelled = distanceTravelled;
			f3 sampleColor = SHADE(samplePos, initDir, cloudSample, density, distanceFromCenter);
			colors = BlendFrontToBack(colors, f4(sampleColor, min(density, 1)));

			if(colors.a > 0.999 * opacityMax)
			{
				colors.a = opacityMax;
				break;
			}
		}
        
        PushSampleForward(/*inout*/samplePos, /*inout*/distanceTravelled, initDir, cloudDistSigned);
	}

	colors = ResolveBlending(colors);

	#if _DISTBLEND_POST
	colors.a *= DistanceBlend(lastHitDistanceTravelled);
	#endif

	// Low quality point lights
	#if _HQPOINTLIGHT
	#else
		// Point light contribution
		for(int j = 0; j < _VisibleLightCount; j++)
		{
			colors.rgb += PointLight(samplePos, _VisiblePointLights[j], _VisiblePointLightsColor[j].rgb);
		}
	#endif

	DEBUG_STEPCOLOR;

	return colors;
}


f4 fragForwardClouds (VOUT i) : Color
{
	// retrieve static variable
	light = (Light)0;
	light.color = _LightColor0.rgb;
	light.dir = _WorldSpaceLightPos0.xyz;
	
	i.eyeVec = normalize(i.eyeVec);
	i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
	f3 planePos = i.planePos;
	
	f2 screenUV = i.clipPos.xy / i.clipPos.w;
	screenUV.y *= _ProjectionParams.x;
	screenUV = screenUV.xy * 0.5 + 0.5;
	#if defined(UNITY_HALF_TEXEL_OFFSET)
	{
		screenUV += .5 / _ScreenParams.xy;
	}
	#endif

	pf1 bufferDepth01 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV);
	pf3 worldPos;
	#if UNITY_VERSION >= 540
	{
		bufferDepth01 = Linear01Depth(bufferDepth01);
		worldPos = mul(unity_CameraToWorld, pf4(i.ray * bufferDepth01, 1)).xyz; 
	}
	#else
	{
		f2 uvClip = screenUV * 2.0 - 1.0; 
		pf4 viewPos = mul(unity_CameraToWorld, pf4(uvClip, bufferDepth01, 1.0));
		viewPos /= viewPos.w;
		worldPos = viewPos.xyz;
		bufferDepth01 = Linear01Depth(bufferDepth01);
	}
	#endif
	
	// Expand depth to a very high value if depth is on the far clip plane 
	worldPos = bufferDepth01 >= 1 ? normalize(worldPos - _WorldSpaceCameraPos) * 100000000 : worldPos.xyz;
	f1 sceneDist = distance(planePos, worldPos);


	#if (X_AXIS)
	{
		i.eyeVec = i.eyeVec.yxz;
		planePos = planePos.yxz;
		light.dir = light.dir.yxz;
		worldPos.xyz = worldPos.yxz;
	}
	#elif (Z_AXIS)
	{
		i.eyeVec = i.eyeVec.xzy;
		planePos = planePos.xzy;
		light.dir = light.dir.xzy;
		worldPos.xyz = worldPos.xzy;
	}
	#endif

	f4 clouds = 0;
	f4 shadows = 0;
	#if !(_RENDERSHADOWSONLY)
	{
		clouds = RaymarchClouds(i.eyeVec, planePos, sceneDist);
	}
	#endif
	#if (_RENDERSHADOWS)
	{
		f3 sceneColor = tex2D(_SceneGrab, screenUV);
		shadows = RaymarchShadow(worldPos, planePos, clouds.a);
		// Mask out shadows generated on the far clipping plane ;
		shadows.a *= sceneDist > _DrawDistance ? 0 : 1;
		shadows.rgb *= sceneColor;
		#if (_SSSHADOW_MAPBLEND)
		{
			f1 sceneShadow = tex2D(_ShadowMapTexture, screenUV).x;
			f1 grad = saturate(1-pow(1-sceneShadow, 5));
			shadows.a *= grad;
		}
		#endif
	}
	#endif
	f4 final = 0.0;
	final = BlendFrontToBack(final, clouds);
	final = BlendFrontToBack(final, shadows);
	final = ResolveBlending(final);

	if(final.a <= _AlphaCut)
		discard;
	return final;
}
