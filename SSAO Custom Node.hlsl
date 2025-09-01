#include "/Engine/Private/Common.ush"
const static int RAYQUALITY[4] = { 2, 2, 4, 4};
const static int STEPQUALITY[4] = { 4, 8, 12, 24};

#define Total_Slices (RAYQUALITY[AO_QUALITY])
#define Samples_Per_Slice (STEPQUALITY[AO_QUALITY])
float g = 1.220744084605759; //anti banding factor
float3 anti_banding_vector = rcp(float3(g,g*g,g*g*g));
float3 surface_normal = SceneTextureLookup(UV, 8, false).rgb * 2 - 1;
		
float2 occlusion_accumulator = 0.0;
for(int i = 0; i <= Total_Slices * Samples_Per_Slice; i++)
	{
		float3 sample_random = frac(noise + i * anti_banding_vector);
        // get cosine distribution
        float2 random_direction = sample_random.xy;
        random_direction.y = random_direction.y * 2.0f - 1.0f;  // Map to [-1, 1] range
        float3 sphere_direction;
        sincos(6.283185f * random_direction.x, sphere_direction.y, sphere_direction.x); // 2π = 6.283185
        sphere_direction.xy *= sqrt(1.0f - random_direction.y * random_direction.y);
        sphere_direction.z = random_direction.y;
        float3 hemisphere_direction = normalize(surface_normal + sphere_direction); //change for different SSAO
        float hemisphere_height = 0.2 + sample_random.z; // Prevents pole sampling
        
		float3 sample_offset = hemisphere_height *sample_radius * hemisphere_direction;
        float3 sample_view_pos = view_pos + sample_offset;
		float3 sample_screen_pos = GetScreenPos(sample_view_pos);
		float2 perspective_correction = sample_offset.xy / (sample_offset.z * SCREEN_RESOLUTION);
        float3 corrected_screen_position = sample_screen_position + float3(perspective_correction, 0.000001);
		float2 screen_edge_check = saturate(corrected_screen_position.xy * corrected_screen_position.xy - corrected_screen_position.xy);
		if (screen_edge_check.x != -screen_edge_check.y) continue;
        
        // Get depth from depth buffer at sample location
        float sample_depth_buffer_value = GetDepth(corrected_screen_position.xy);
        // Determine if sample contributes to occlusion:
        // - Valid if sample is BEHIND surface (depth > surface depth)
        // - AND within thickness threshold (avoids distant occluders)
		bool is_sample_outside_valid_range = (
            corrected_screen_position.z < sample_depth_buffer_value || 
            corrected_screen_position.z > (sample_depth_buffer_value + 5.0 * depth_thickness / FAR_PLANE_DISTANCE)
        );
        
        // Accumulate occlusion state (1 if invalid sample, 0 if valid occluder)
        occlusion_accumulator += float2(is_sample_outside_valid_range, 1.0);
	}
// Return occlusion ratio (fraction of invalid samples = less occlusion)
return occlusion_accumulator.x / occlusion_accumulator.y;
