Shader "Z/Water2"
{
    Properties
    {
        _WaterColor ("WaterColor", Color) = (1.5, 0.4, 0.36, 1) 
        [Space(20)]
        _NormalTex ("NormalTex", 2D) = "bump" {}
        _NormalScale("NormalScale",Range(0,2)) = 1
        _OneTilingOffset("OneTilingOffset",Vector) = (3.00, 3.00, -4.00, 4.00)
        _TowTilingOffset("TowTilingOffset",Vector) = (6.00, 6.00, -3.00, -3.00)
        [Space(20)]
        _CubemapMap ("CubemapMap", 2D) = "_Skybox" {}
        _ReflDistortion("ReflDistortion",Range(0,1)) = 1
        _ReflIntensity("ReflIntensity",Range(0,1)) = 0.585 
        [Space(20)]
        _RefrDistortion("RefrDistortion", Range(0, 0.5)) = 0.25   
        [Space(20)]
        _SpecularStrength("SpecularStrength ", Range(0, 1)) = 1
        [Space(20)]
        _Transparency("WaterTransparency", Range(0, 5)) = 1.0
    }
    SubShader
    {
        Tags{ "RenderType" = "Opaque"  "Queue" = "Geometry+1" }
        GrabPass{}
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            sampler2D _GrabTexture;
            half4 _WaterColor;
            sampler2D _NormalTex;
            half _NormalScale;
            float4 _OneTilingOffset;
            float4 _TowTilingOffset;
            sampler2D _CubemapMap;
            float _ReflDistortion;
            float _ReflIntensity;
            half _RefrDistortion;
            float _SpecularStrength;
            half _Transparency;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float4 worldPos : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 normal : TEXCOORD3;
                half3 tangentWS : TEXCOORD5;
                half3 bitangentWS : TEXCOORD6;
                float4 color : COLOR;
            };

            half3 NormalScale(half3 n,half nScale)
            {
                half3 normal;
                normal.xy = n.xy * nScale;
                normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy)));
                return normal;
            }

            half Fresnel(half3 n,half3 v,half bias,half scale,half power)
            {
                return bias + scale * saturate(pow(1 - dot(n,v),power));
            }

            half Specular(half3 n,half3 v,half3 l)
            {
                half3 H = normalize(v + l);
                half LoH = saturate(dot(l, H));
                half LoH2 = LoH * LoH;
                half NoH = saturate(dot(n, H));
                half NoH2 = NoH * NoH;
                half d = 1.0001f - 0.99993896485 * NoH2;
                half spec = 6.10352e-5f/(d*d * max(0.1f, LoH2) * 2.03125) - 6.10352e-5f;
                spec = clamp(spec, 0, 100.0);
                return spec;
            }

            half Depth(half4 color,half3 v)
            {
                return color.x / max(0.2, v.y);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = v.uv.xy * _OneTilingOffset.xy + _Time.y * _OneTilingOffset.zw * 0.005;
                o.uv.zw = v.uv.xy * _TowTilingOffset.xy + _Time.y * _TowTilingOffset.zw * 0.005;
                o.worldPos = mul(unity_ObjectToWorld,v.vertex);
                o.screenPos = ComputeScreenPos(o.pos);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.tangentWS = UnityObjectToWorldNormal(v.tangent);
                o.bitangentWS = cross(o.normal, o.tangentWS) * v.tangent.w;
                o.color = v.color;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 uv = i.uv;
                fixed4 worldPos = i.worldPos;
                float4 screenPos = i.screenPos;
                fixed3 normal = normalize(i.normal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                fixed3 worldViewDir = normalize(_WorldSpaceCameraPos - worldPos);
                fixed4 lightColor = _LightColor0;
                float lightIntencity = saturate(Luminance(_LightColor0));

                fixed3 normal_1 = UnpackNormal(tex2D(_NormalTex, i.uv.xy));
                fixed3 normal_2 = UnpackNormal(tex2D(_NormalTex, i.uv.zw));
                fixed3 waterNormal = normal_1 + normal_2;
                waterNormal = BlendNormals(normal_1,normal_2);
                waterNormal = NormalScale(waterNormal,_NormalScale);
                waterNormal = waterNormal.x * i.tangentWS + waterNormal.y * i.bitangentWS + waterNormal.z * i.normal;
                waterNormal = normalize(waterNormal);

                float depth = Depth(i.color,worldViewDir);
                half3 waterColor = saturate(exp2(-_Transparency * depth * (1 - _WaterColor)));
                depth = saturate(exp2(-_Transparency * depth));
                half fresnel = Fresnel(waterNormal,worldViewDir,0.05,0.95,5) * _ReflIntensity;
                half3 spec = Specular(waterNormal,worldViewDir,worldLightDir);
                spec = spec * lightColor * lightIntencity * _SpecularStrength;
                float3 planeNormal = lerp(float3(0,1,0),waterNormal,_ReflDistortion);
                float3 reflDir = normalize(reflect(-worldViewDir, normalize(planeNormal)));
                float a = atan(reflDir.x / reflDir.z) * 0.5 + 0.5;
                half4 refl = tex2D(_CubemapMap, float2(a, reflDir.y * 0.5 + 0.5));
                screenPos.xy -= waterNormal.xz * (1 - depth) * _RefrDistortion;
                half4 refr = tex2Dproj(_GrabTexture,UNITY_PROJ_COORD(screenPos));
                refr.xyz *= lerp(waterColor,1,depth);
                half3 col = lerp(refr, refl, fresnel) + spec;
                return half4(col,1);
            }

            ENDCG
        }
    }
}