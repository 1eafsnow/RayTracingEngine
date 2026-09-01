#include <Object/Triangle.h>
#include <World/World.h>

Vertex* Triangle::GetVertex(int idx)
{
    return GetWorld()->GetVertex(vertexIdx[idx]);
}

Normal* Triangle::GetVertexNormal(int idx)
{
    (void)idx;
    return nullptr;
}

Material* Triangle::GetMaterial()
{
    return GetWorld()->GetMaterial(materialIdx);
}

void Triangle::Init()
{
    Vertex* v0 = GetVertex(0);
    Vertex* v1 = GetVertex(1);
    Vertex* v2 = GetVertex(2);
    if (v0 == nullptr || v1 == nullptr || v2 == nullptr)
    {
        normal = Vector3::Zero;
        distance = 0.0f;
        return;
    }

    Vector3 edge1 = v1->worldLocation - v0->worldLocation;
    Vector3 edge2 = v2->worldLocation - v0->worldLocation;
    Vector3 faceNormal = Cross(edge1, edge2);
    if (Dot(faceNormal, faceNormal) <= 1e-16f)
    {
        normal = Vector3::Zero;
        distance = 0.0f;
        return;
    }

    normal = faceNormal.GetNormalized();
    if (vertexNormal)
    {
        Vector3 averageNormal = v0->worldDirection + v1->worldDirection + v2->worldDirection;
        if (Dot(averageNormal, averageNormal) > 1e-16f && Dot(normal, averageNormal) < 0.0f)
        {
            normal = -normal;
        }
    }
    distance = -Dot(v0->worldLocation, normal);
}

void Triangle::Reverse()
{
    normal = -normal;
    Vertex* v0 = GetVertex(0);
    distance = v0 != nullptr ? -Dot(v0->worldLocation, normal) : 0.0f;
}

__device__ Vertex* Triangle::GetVertex(DeviceWorld* world, int idx)
{
    return world->vertices + vertexIdx[idx];
}

__device__ Normal* Triangle::GetNormal(DeviceWorld* world, int idx)
{
    (void)world;
    (void)idx;
    return nullptr;
}

__device__ Material* Triangle::GetMaterial(DeviceWorld* world)
{
    return world->materials + materialIdx;
}

__device__ Vector3 Triangle::GetNormal(DeviceWorld* world, const Vector3& barycentricCoordinate)
{
    if (!vertexNormal)
    {
        return normal;
    }

    const Vertex& v0 = world->vertices[vertexIdx[0]];
    const Vertex& v1 = world->vertices[vertexIdx[1]];
    const Vertex& v2 = world->vertices[vertexIdx[2]];
    Vector3 result = v0.worldDirection * barycentricCoordinate.x + v1.worldDirection * barycentricCoordinate.y + v2.worldDirection * barycentricCoordinate.z;
    const float lengthSquared = Dot(result, result);
    if (lengthSquared <= 1e-16f)
    {
        return normal;
    }
    return result / sqrtf(lengthSquared);
}

__device__ Vector3 Triangle::GetAlbedo(DeviceWorld* world, const Vector3& barycentricCoordinate)
{
    Material* material = world->materials + materialIdx;
    if (material->textureIdx < 0 || material->textureIdx >= world->texturesSize)
    {
        return material->albedo;
    }

    const Vertex& v0 = world->vertices[vertexIdx[0]];
    const Vertex& v1 = world->vertices[vertexIdx[1]];
    const Vertex& v2 = world->vertices[vertexIdx[2]];
    Vector2 uv = v0.textureCoordinate * barycentricCoordinate.x + v1.textureCoordinate * barycentricCoordinate.y + v2.textureCoordinate * barycentricCoordinate.z;
    return world->textures[material->textureIdx].GetColor(world, uv.x, uv.y);
}

__device__ bool Triangle::IncludeDetect(DeviceWorld* world, const Vector3& location, Vector3& coordinate)
{
    Vector3 a = world->vertices[vertexIdx[0]].worldLocation;
    Vector3 b = world->vertices[vertexIdx[1]].worldLocation;
    Vector3 c = world->vertices[vertexIdx[2]].worldLocation;

    Vector3 ab = b - a;
    Vector3 ac = c - a;
    Vector3 ap = location - a;

    float abab = Dot(ab, ab);
    float acac = Dot(ac, ac);
    float abac = Dot(ab, ac);
    float apab = Dot(ap, ab);
    float apac = Dot(ap, ac);
    float denominator = abab * acac - abac * abac;
    if (fabsf(denominator) < 1e-12f)
    {
        return false;
    }

    coordinate.z = (abab * apac - abac * apab) / denominator;
    coordinate.y = (acac * apab - abac * apac) / denominator;
    coordinate.x = 1.0f - coordinate.y - coordinate.z;
    return coordinate.x >= 0.0f && coordinate.y >= 0.0f && coordinate.z >= 0.0f &&
        coordinate.x <= 1.0f && coordinate.y <= 1.0f && coordinate.z <= 1.0f;
}

__device__ bool Triangle::HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult)
{
    Vector3 n = normal;
    float d = distance;
    float in = Dot(ray->direction, n);
    if (fabsf(in) < 1e-7f)
    {
        return false;
    }

    if (in > 0.0f)
    {
        Material* material = world->materials + materialIdx;
        if (!material->backVisible)
        {
            return false;
        }
        n = -n;
        in = -in;
        d = -d;
    }

    float rayDistance = -(Dot(ray->location, n) + d) / in;
    if (rayDistance < MIN_DETECT_DISTANCE || rayDistance > hitResult->distance)
    {
        return false;
    }

    Vector3 location = ray->location + ray->direction * rayDistance;
    Vector3 coordinate;
    if (!IncludeDetect(world, location, coordinate))
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->material = world->materials + materialIdx;
    hitResult->color = GetAlbedo(world, coordinate);
    hitResult->distance = rayDistance;
    hitResult->location = location;
    hitResult->normal = GetNormal(world, coordinate);
    hitResult->objectId = id;
    return true;
}
