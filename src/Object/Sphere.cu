#include <Object/Sphere.h>
#include <World/World.h>

Material* Sphere::GetMaterial()
{
	return GetWorld()->GetMaterial(materialIdx);
}

void Sphere::SetWorldLocation(Vector3 location)
{
	worldLocation = location;
}

void Sphere::SetRadius(float radius)
{
	this->radius = radius;
}

Vector3 Sphere::GetNormal(DeviceWorld* world, Vector3 location)
{
	return (location - worldLocation).GetNormalized();
}

Material* Sphere::GetMaterial(DeviceWorld* world)
{
	return world->materials + materialIdx;
}

bool Sphere::HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult)
{
	Vector3 oc = ray->location - worldLocation;
	float a = Dot(ray->direction, ray->direction);
	float b = 2.0f * Dot(oc, ray->direction);
	float c = Dot(oc, oc) - radius * radius;
	float d = b * b - 4.0f * a * c;
	if (d < 0.0f)
	{
		return false;
	}

	float sqrtD = sqrt(d);
	float distance = (-b - sqrtD) / (2.0f * a);
	if (distance < MIN_DETECT_DISTANCE)
	{
		distance = (-b + sqrtD) / (2.0f * a);
	}

	if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
	{
		return false;
	}

	hitResult->isHit = true;
	hitResult->distance = distance;
	hitResult->location = ray->location + ray->direction * hitResult->distance;
	hitResult->normal = GetNormal(world, hitResult->location);
	hitResult->material = world->materials + materialIdx;
	hitResult->color = hitResult->material->albedo;
	hitResult->objectId = id;
	return true;
}