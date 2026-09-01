#include <Object/Quadrilateral.h>
#include <World/World.h>

Vertex* Quadrilateral::GetVertex(int idx)
{
    return &GetWorld()->vertices[vertexIdx[idx]];
}

Material* Quadrilateral::GetMaterial()
{
    return &GetWorld()->materials[materialIdx];
}

void Quadrilateral::Init()
{
    Vector3 v1 = GetVertex(1)->worldLocation - GetVertex(0)->worldLocation;
    Vector3 v2 = GetVertex(2)->worldLocation - GetVertex(0)->worldLocation;
    Vector3 v3 = GetVertex(3)->worldLocation - GetVertex(0)->worldLocation;

    const float angle1 = Angle(v1, v2);
    const float angle2 = Angle(v2, v3);
    const float angle3 = Angle(v1, v3);
    const float reorderEpsilon = 1e-5f;

    if (fabsf((angle1 + angle3) - angle2) <= reorderEpsilon)
    {
        int temp = vertexIdx[1];
        vertexIdx[1] = vertexIdx[2];
        vertexIdx[2] = temp;
    }
    else if (fabsf((angle2 + angle3) - angle1) <= reorderEpsilon)
    {
        int temp = vertexIdx[2];
        vertexIdx[2] = vertexIdx[3];
        vertexIdx[3] = temp;
    }

    v1 = GetVertex(1)->worldLocation - GetVertex(0)->worldLocation;
    v2 = GetVertex(2)->worldLocation - GetVertex(0)->worldLocation;
    Vector3 faceNormal = Cross(v1, v2);
    if (Dot(faceNormal, faceNormal) <= 1e-16f)
    {
        normal = Vector3::Zero;
        distance = 0.0f;
        return;
    }

    normal = faceNormal.GetNormalized();
    if (vertexNormal)
    {
        Vector3 averageNormal = GetVertex(0)->worldDirection + GetVertex(1)->worldDirection + GetVertex(2)->worldDirection + GetVertex(3)->worldDirection;
        if (Dot(averageNormal, averageNormal) > 1e-16f && Dot(normal, averageNormal) < 0.0f)
        {
            normal = -normal;
        }
    }

    distance = -Dot(GetVertex(0)->worldLocation, normal);
}

__device__ Material* Quadrilateral::GetMaterial(DeviceWorld* world)
{
    return world->materials + materialIdx;
}

__device__ Vector3 Quadrilateral::GetAlbedo(DeviceWorld* world, const Vector3& barycentricCoordinate)
{
    (void)barycentricCoordinate;
    return (world->materials + materialIdx)->albedo;
}

__device__ bool Quadrilateral::IncludeDetect(DeviceWorld* world, const Vector3& location)
{
    float referenceSide = 0.0f;
    constexpr float edgeEpsilon = 1e-6f;

    for (int i = 0; i < 4; i++)
    {
        const Vector3& a = world->vertices[vertexIdx[i]].worldLocation;
        const Vector3& b = world->vertices[vertexIdx[(i + 1) & 3]].worldLocation;
        const float side = Dot(Cross(b - a, location - a), normal);
        if (fabsf(side) <= edgeEpsilon)
        {
            continue;
        }
        if (referenceSide == 0.0f)
        {
            referenceSide = side;
            continue;
        }
        if (referenceSide * side < 0.0f)
        {
            return false;
        }
    }
    return true;
}

__device__ bool Quadrilateral::HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult)
{
    Vector3 n = normal;
    float d = distance;
    float in = Dot(ray->direction, n);
    if (fabsf(in) < 1e-7f)
    {
        return false;
    }

    Material* material = world->materials + materialIdx;
    if (in > 0.0f)
    {
        if (!material->backVisible)
        {
            return false;
        }
        n = -n;
        in = -in;
        d = -d;
    }

    const float rayDistance = -(Dot(ray->location, n) + d) / in;
    if (rayDistance < MIN_DETECT_DISTANCE || rayDistance > hitResult->distance)
    {
        return false;
    }

    const Vector3 location = ray->location + ray->direction * rayDistance;
    if (!IncludeDetect(world, location))
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->normal = n;
    hitResult->location = location;
    hitResult->distance = rayDistance;
    hitResult->material = material;
    hitResult->color = material->albedo;
    hitResult->objectId = id;
    return true;
}
