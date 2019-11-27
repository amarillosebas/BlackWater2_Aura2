// expects first normal to be unpacked already
half3 UnpackAndBlendNormals(fixed3 n1, fixed4 n2, fixed4 n3) {
    half3 normal;
    #if defined(UNITY_NO_DXT5nm)
        normal = normalize( n1 + (n2.xyz * 2 - 1) + (n3.xyz * 2 - 1) );
    #else
        normal.xy =  n1.xy;
        normal.xy += (n2.ag * 2 - 1) * _BumpScale.y;
        normal.xy += (n3.ag * 2 - 1) * _BumpScale.z;
        normal.z = sqrt(1.0 - saturate( normal.x * normal.x + normal.y * normal.y));
        normal = normalize(normal);
    #endif
    return normal;
}

half3 WorldNormal(half3 t0, half3 t1, half3 t2, half3 normal) {
    return normalize( half3( dot(t0, normal), dot(t1, normal), dot(t2, normal) ) );
}

float2 rotate2D(float2 v, float a) {
    float s = sin(a);
    float c = cos(a);
    float2x2 m = float2x2(c, -s, s, c);
    return mul(m, v);
}