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
    //int vertexIdx = sphere->vertexIdx * 3;
    //Vector3 worldLocation(DevVertices[vertexIdx], DevVertices[vertexIdx + 1], DevVertices[vertexIdx + 2]);
    return (location - worldLocation).GetNormalized();
}

Material* Sphere::GetMaterial(DeviceWorld* world)
{
    return world->materials + materialIdx;
}

bool Sphere::HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult)
{
    //int vertexIdx = sphere->vertexIdx * 3;
    //Vector3 vertexLocation(DevVertices[vertexIdx], DevVertices[vertexIdx + 1], DevVertices[vertexIdx + 2]);
    Vector3 oc = ray->location - worldLocation;
    float a = Dot(ray->direction, ray->direction);
    float b = 2.0 * Dot(oc, ray->direction);
    float c = Dot(oc, oc) - radius * radius;
    float d = b * b - 4 * a * c;
    if (d < 0)
    {
        return false;
    }
    float distance = (-b - sqrt(d)) / (2 * a);

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
    /*
    if (Dot(ray.direction, GetNormal(result.location)) > -1e-6)
    {
        result.isHit = false;
    }
    */
    return true;
}