Shader "Z/Water" {
    Properties {
        _WaterTex ("水", 2D) = "black" {} 
        _WaveTex ("浪", 2D) = "black" {} 
        _BumpTex ("法线", 2D) = "bump" {} 
        _GTex ("水渐变", 2D) = "white" {}
        _NoiseTex ("浪躁波", 2D) = "white" {}
        _WaterSpeed ("水速度", float) = 0.74
        _WaveSpeed ("浪速度", float) = -12.64
        _WaveRange ("浪大小", float) = 0.3 
        _NoiseRange ("水噪波", float) = 6.43
        _WaveDelta ("浪差", float) = 2.43
        _Refract ("折射率", float) = 0.07
        _Specular ("高光", float) = 1.86
        _Gloss ("光泽度", float) = 0.71
        _SpecColor ("高光颜色", color) = (1, 1, 1, 1)
        _Range ("Range", vector) = (0.13, 1.53, 0.37, 0.78)
    }

    SubShader {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 200

        // 捕捉对象之后的屏幕内容放到_GrabTexture纹理中
        GrabPass{}
        zwrite off
        
        Pass
        {
            Tags { "LightMode" = "ForwardBase"}
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag 

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _GTex;
    
            sampler2D _WaterTex;
            float4 _WaterTex_ST;
            sampler2D _BumpTex;
            sampler2D _CameraDepthTexture;
            sampler2D _GrabTexture;
            half4 _GrabTexture_TexelSize;
            
            sampler2D _NoiseTex;
            float4 _NoiseTex_ST;
            sampler2D _WaveTex;
    
            float4 _Range;
    
            half _WaterSpeed;
            
            half _WaveSpeed;
            fixed _WaveDelta;
            half _WaveRange;
            fixed _Refract;
            half _Specular;
            fixed _Gloss;
    
            half _NoiseRange;
    
            float4 _WaterTex_TexelSize;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };
    
            struct v2f {
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
                SHADOW_COORDS(4)
                float4 proj : TEXCOORD5;
            };
    
            v2f vert (a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
             
                o.uv.xy = v.texcoord.xy * _WaterTex_ST.xy + _WaterTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
                
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
                
                TRANSFER_SHADOW(o);
 
                o.proj = ComputeScreenPos(o.pos);
                COMPUTE_EYEDEPTH(o.proj.z);

                return o;
            }
    
            fixed4 frag (v2f i) : SV_Target {
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                float2 uv = i.proj.xy/i.proj.w;

            #if UNITY_UV_STARTS_AT_TOP
                if(_WaterTex_TexelSize.y<0)
                    uv.y = 1 - uv.y;
            #endif

                float2 uv_WaterTex = i.uv.xy;
                float2 uv_NoiseTex = i.uv.zw;
                fixed4 water = (tex2D(_WaterTex, uv_WaterTex + float2(_WaterSpeed*_Time.x,0))+tex2D(_WaterTex, float2(1-uv_WaterTex.y,uv_WaterTex.x) + float2(_WaterSpeed*_Time.x,0)))/2;
                float4 offsetColor = (tex2D(_BumpTex, uv_WaterTex + float2(_WaterSpeed*_Time.x,0))+tex2D(_BumpTex, float2(1-uv_WaterTex.y,uv_WaterTex.x) + float2(_WaterSpeed*_Time.x,0)))/2;
                half2 offset = UnpackNormal(offsetColor).xy * _Refract;
                half m_depth = LinearEyeDepth(tex2Dproj (_CameraDepthTexture, UNITY_PROJ_COORD(i.proj)).r);
                half deltaDepth = m_depth - i.proj.z;
                clip (deltaDepth);
    
                fixed4 noiseColor = tex2D(_NoiseTex, uv_NoiseTex);
    
                half4 bott = tex2D(_GrabTexture, uv+offset);
                fixed4 waterColor = tex2D(_GTex, float2(min(_Range.y, deltaDepth)/_Range.y,1));
                
                fixed4 waveColor = tex2D(_WaveTex, float2(1-min(_Range.z, deltaDepth)/_Range.z+_WaveRange*sin(_Time.x*_WaveSpeed+noiseColor.r*_NoiseRange),1)+offset);
                waveColor.rgb *= (1-(sin(_Time.x*_WaveSpeed+noiseColor.r*_NoiseRange)+1)/2)*noiseColor.r;
                fixed4 waveColor2 = tex2D(_WaveTex, float2(1-min(_Range.z, deltaDepth)/_Range.z+_WaveRange*sin(_Time.x*_WaveSpeed+_WaveDelta+noiseColor.r*_NoiseRange),1)+offset);
                waveColor2.rgb *= (1-(sin(_Time.x*_WaveSpeed+_WaveDelta+noiseColor.r*_NoiseRange)+1)/2)*noiseColor.r;
                
                half water_A = 1-min(_Range.z, deltaDepth)/_Range.z;
                half water_B = min(_Range.w, deltaDepth)/_Range.w;
                float4 bumpColor = (tex2D(_BumpTex, uv_WaterTex+offset + float2(_WaterSpeed*_Time.x,0))+tex2D(_BumpTex, float2(1-uv_WaterTex.y,uv_WaterTex.x)+offset + float2(_WaterSpeed*_Time.x,0)))/2;
    
                fixed3 Normal = UnpackNormal(bumpColor).xyz;
                Normal = normalize(half3(dot(i.TtoW0.xyz, Normal), dot(i.TtoW1.xyz, Normal), dot(i.TtoW2.xyz, Normal)));

                fixed3 albedo = bott.rgb * (1 - water_B) + waterColor.rgb * water_B;
                albedo = albedo * (1 - water.a*water_A) + water.rgb * water.a*water_A;
                albedo += (waveColor.rgb+waveColor2.rgb) * water_A; 
                
                fixed alpha = min(_Range.x, deltaDepth)/_Range.x;

                half3 halfVector = normalize(lightDir + viewDir);
                float diffFactor = max(0, dot(lightDir, Normal)) * 0.8 + 0.2;
                float nh = max(0, dot(halfVector, Normal));
                float spec = pow(nh, _Specular * 128.0) * _Gloss;

                UNITY_LIGHT_ATTENUATION(atten, IN, worldPos);

                fixed4 c;
                c.rgb = (albedo * _LightColor0.rgb * diffFactor + _SpecColor.rgb * spec * _LightColor0.rgb) * (atten);
                c.a = alpha + spec * _SpecColor.a;
                return c;
            }
            ENDCG
        }
    } 
    FallBack "Diffuse"
}
