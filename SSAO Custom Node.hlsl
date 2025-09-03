#include "/Engine/Private/Common.ush"
const static int RayQuality[4] = { 2, 2, 4, 4};
const static int StepQuality[4] = { 4, 8, 12, 24};

#define TotalSlices (RayQuality[AOQuality])
#define SamplesPerSlice (StepQuality[AOQuality])
float g = 1.220744084605759; //anti banding factor
float3 AntiBandingVector = rcp(float3(g,g*g,g*g*g));
float3 SurfaceNormal = SceneTextureLookup(UV, 8, false).rgb * 2 - 1;
		
float2 OcclusionAccumulator = 0.0;
for(int i = 0; i <= TotalSlices * SamplesPerSlice; i++)
	{
		float3 SampleRandom = frac(noise + i * AntiBandingVector);
        // get cosine distribution
        float2 RandomDirection = SampleRandom.xy;
        RandomDirection.y = RandomDirection.y * 2.0f - 1.0f;  // Map to [-1, 1] range
        float3 SphereDirection;
        sincos(6.283185f * RandomDirection.x, SphereDirection.y, SphereDirection.x); // 2π = 6.283185
        SphereDirection.xy *= sqrt(1.0f - RandomDirection.y * RandomDirection.y);
        SphereDirection.z = RandomDirection.y;
        float3 HemisphereDirection = normalize(SurfaceNormal + SphereDirection); //change for different SSAO
        float HemisphereHeight = 0.2 + SampleRandom.z; // Prevents pole sampling
        
		float3 SampleOffset = HemisphereHeight *sample_radius * HemisphereDirection;
        float3 SampleViewPos = view_pos + SampleOffset;
		float3 SampleScreenPos = GetScreenPos(SampleViewPos);
		float2 PerspectiveCorrection = SampleOffset.xy / (SampleOffset.z * ScreenResolution);
        float3 CorrectedScreenPosition = SampleScreenPos + float3(PerspectiveCorrection, 0.000001);
		float2 ScreenEdgeCheck = saturate(CorrectedScreenPosition.xy * CorrectedScreenPosition.xy - CorrectedScreenPosition.xy);
		if (ScreenEdgeCheck.x != -ScreenEdgeCheck.y) continue;
        
        // Get depth from depth buffer at sample location
        float SampleDepthBufferValue = GetDepth(CorrectedScreenPosition.xy);
        // Determine if sample contributes to occlusion:
        // - Valid if sample is BEHIND surface (depth > surface depth)
        // - AND within thickness threshold (avoids distant occluders)
		bool IsSampleOutsideValidRange = (
            CorrectedScreenPosition.z < SampleDepthBufferValue || 
            CorrectedScreenPosition.z > (SampleDepthBufferValue + 5.0 * DepthThickness / FarPlaneDistance)
        );
        
        // Accumulate occlusion state (1 if invalid sample, 0 if valid occluder)
        OcclusionAccumulator += float2(IsSampleOutsideValidRange, 1.0);
	}
// Return occlusion ratio (fraction of invalid samples = less occlusion)
return OcclusionAccumulator.x / OcclusionAccumulator.y;
