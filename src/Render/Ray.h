#pragma once
#include <Math/Math.h>

#define MIN_DETECT_DISTANCE 0.001
#define MAX_DETECT_DISTANCE 1000

class Ray
{
public:
	Vector3 location;
	Vector3 direction;
	int depth;
	
	__host__ __device__ Ray(Vector3 location = Vector3(0, 0, 0), Vector3 direction = Vector3(0, 0, 0));
};

struct RaySampleResult
{
	Vector3 brdf;
	float pdf;
	float cosine;
	float attenuation;
};

struct RayHitResult
{
	bool isHit = false;
	float distance = FLT_MAX;
	Vector3 location;
	Vector3 normal;
	class Material* material;
	Vector3 color;
	int objectId;
};