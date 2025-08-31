const static int RAYQUALITY[4] = { 2, 2, 4, 4};
const static int STEPQUALITY[4] = { 4, 8, 12, 24};

#define Total_Slices (RAYQUALITY[AO_QUALITY])
#define Samples_Per_Slice (STEPQUALITY[AO_QUALITY])
float g = 1.220744084605759; //anti banding factor
float3 anti_banding_vector = rcp(float3(g,g*g,g*g*g));
float3 normal = SceneTextureLookup(UV, 8, false).rgb * 2 - 1;
		
float2 acc = 0.0;
for(int i = 0; i <= Total_Slices * Samples_Per_Slice; i++)
	{
		float3 sample_vector = frac(noise + i * anti_banding_vector);
        float hemisphereHeight = 0.2 + sample_vector.z; // Prevents pole sampling
		float3 sample_offset = hemisphereHeight *radius * (GetCosVec(normal, sample_vector.xy, SSAO_TYPE));
        float3 sample_view_pos = view_pos + sample_offset;
		float3 sample_screen_pos = GetScreenPos(sample_view_pos) + float3(1.0*(vec.xy) / (vec.z*RES), 0.000001);
		float2 perspectiveCorrection = sample_offset.xy / (sample_offset.z * SCREEN_RESOLUTION);
        float3 correctedScreenPosition = sampleScreenPosition + float3(perspectiveCorrection, 0.000001);
		float2 screenEdgeCheck = saturate(correctedScreenPosition.xy * correctedScreenPosition.xy - correctedScreenPosition.xy);
		if (screenEdgeCheck.x != -screenEdgeCheck.y) continue;
        
        // Get depth from depth buffer at sample location
        float sampleDepthBufferValue = GetDepth(correctedScreenPosition.xy);
        // Determine if sample contributes to occlusion:
        // - Valid if sample is BEHIND surface (depth > surface depth)
        // - AND within thickness threshold (avoids distant occluders)
		bool isSampleOutsideValidRange = (
            correctedScreenPosition.z < sampleDepthBufferValue || 
            correctedScreenPosition.z > (sampleDepthBufferValue + 5.0 * depthThickness / FAR_PLANE_DISTANCE)
        );
        
        // Accumulate occlusion state (1 if invalid sample, 0 if valid occluder)
        occlusionAccumulator += float2(isSampleOutsideValidRange, 1.0);
	}
// Return occlusion ratio (fraction of invalid samples = less occlusion)
return occlusionAccumulator.x / occlusionAccumulator.y;
