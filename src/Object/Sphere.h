#pragma once
#include <Math/Math.h>
#include <Render/Ray.h>
#include <Object/Vertex.h>
#include <Material/Material.h>

class DeviceWorld;

class Sphere
{
public:
	int id;
	Vector3 worldLocation;
	float radius;	
	int materialIdx;
	
	Material* GetMaterial();

	void SetWorldLocation(Vector3 location);
	void SetRadius(float radius);

	__device__ Vector3 GetNormal(DeviceWorld* world, Vector3 location);
	__device__ Material* GetMaterial(DeviceWorld* world);
	__device__ bool HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult);
};