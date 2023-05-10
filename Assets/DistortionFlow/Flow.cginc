#if !defined(FLOW_INCLUDED)
#define FLOW_INCLUDED

float2 FlowUVFixed (float2 uv, float time) {
	return uv + time;
}

float2 FlowUV (float2 uv, float2 flowVector, float time) {
    //使用动画时间的小数部分避免uv过渡扭曲
    float progress = frac(time);
	return uv - flowVector * progress;
}

float3 FlowUVW (float2 uv, float2 flowVector, float time) {
	float progress = frac(time);
	float3 uvw;
	uvw.xy = uv - flowVector * progress;
	uvw.z = 1 - abs(1 - 2 * progress);
	return uvw;
}

#endif