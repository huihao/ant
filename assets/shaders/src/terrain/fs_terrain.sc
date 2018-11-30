// terrain shader sample
$input v_position, v_texcoord0,v_normal ,v_texcoord1


#include "../common/common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

// only Int1,Vec4,Mat3,Mat4 supported 
uniform vec4 s_lightDirection;
uniform vec4 s_lightIntensity;
uniform vec4 s_lightColor;

// define in uniforms.sh 
//uniform vec4 ambient_mode;        // ambient_mode.x 
							        //  = 0  ratio factor of main light,color use main light color 
								    //       ambient_mode.y = factor in this case 
								    //  = 1  classic ambient mode, use skycolor 
								    //  = 2  gradient, interpolate with { skycolor,midcolor,groundcolor } 
//uniform vec4 ambient_skycolor;    // classic ambient color ,gradient skycolor 
//uniform vec4 ambient_midcolor;
//uniform vec4 ambient_groundcolor;

uniform int s_showMode;             // debug output normal,fog  

SAMPLER2D(s_baseTexture,0);
SAMPLER2D(s_maskTexture,1);

void main()
{
    vec3  lightDirection = normalize(s_lightDirection);
	float ntol = max(0,dot(v_normal, lightDirection));
	float lightIntensity = ntol*s_lightIntensity[0];
    vec4  lightColor = s_lightColor* lightIntensity;
		  lightColor.a =  1.0;  //1.2

	vec4  textureColor = texture2D(s_baseTexture,v_texcoord0);
	vec4  maskColor    = vec4(1,1,1, texture2D(s_maskTexture,v_texcoord1).r);
						 //vec4(0.8,0.8,0.8,texture2D(s_maskTexture,v_texcoord1).r);
	textureColor.a     =  1.4;    //1.2

	vec4  diffuseColor = vec4(1.0,1.0,1.0,1.0);
	//vec4  skyColor = vec4(0.5,0.7,0.7,1.0);
	vec4  skyColor = s_lightColor;
	vec4  groundColor = vec4(0.3,0.3,0.3,1.0);
	vec4  horzColor = vec4(0.25,0.25,0.25,1.0);
    vec3  lightDirection = vec3(0,60,30);
	lightDirection = normalize(lightDirection);
	
	float lightIntensity = saturate(dot(v_normal, lightDirection))*(1.0+s_lightIntensity[0]);
	if(lightIntensity<0.8)
	   lightIntensity=0.8;
    vec4  color = saturate(diffuseColor * lightIntensity);

	vec4 mask = vec4(v_position.y/20.0, v_position.y/20.0, v_position.y/20.0 , 1.0);
	//if(maskColor.r<=0.2)
	//	discard;
	if( s_showMode == 1) {
		vec4 color = vec4(v_normal,1.0); //*mask;
		gl_FragColor = color;
		return ;
	}

	float ambientMode = ambient_mode.x;
	vec4  ambientColor = calc_ambient_color(ambientMode,v_normal.xyz);
		  ambientColor.a = 0.0;      				 		// notice
		  ambientColor = ambientColor*textureColor;  		//*0.25;   // divide four pass 
	vec4  diffuseColor = lightColor*textureColor*maskColor;
	gl_FragColor = saturate( (ambientColor + diffuseColor ) );
}
