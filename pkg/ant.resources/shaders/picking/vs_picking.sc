#include "common/inputs.sh"

$input a_position INPUT_INDICES INPUT_WEIGHT

/*
 * Copyright 2011-2018 Branimir Karadzic. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include <bgfx_shader.sh>
#include "common/curve_world.sh"
#include "common/transform.sh"

#if CURVE_WORLD
uniform mat4 u_viewcamera_viewmat;
uniform mat4 u_viewcamera_inv_viewmat;
#endif //CURVE_WORLD

void main()
{
#ifdef CS_SKINNING
    vec3 posWS = mul(u_model[0], vec4(a_position, 1.0)).xyz;
#else //!CS_SKINNING
    vec3 posWS = mul(get_world_matrix(), vec4(a_position, 1.0)).xyz;
#endif //CS_SKINNING

#if CURVE_WORLD
	posWS = curve_world_offset(posWS, u_viewcamera_viewmat, u_viewcamera_inv_viewmat);
#endif //CURVE_WORLD

	gl_Position   = mul(u_viewProj, vec4(posWS, 1.0));
}
