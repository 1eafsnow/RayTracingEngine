#pragma once
#include <Math/Math.h>

class Material
{
public:
	int id;
	bool isEmit = false;
	bool backVisible = false;
	Vector3 emit;
	float intensity;
	Vector3 albedo;
	float transparency;
	float roughness;
	float refractionIndex;
	int textureIdx = -1;
};
