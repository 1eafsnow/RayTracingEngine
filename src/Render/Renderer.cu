#include <Render/Renderer.h>
#include <algorithm>
#include <cfloat>
#include <cstdint>
#include <cstring>
#include <ctime>
#include <limits>
#include <new>
#include <vector>

__device__ static DeviceWorld DevWorld[1];

namespace
{
constexpr int RenderBlockWidth = 16;
constexpr int RenderBlockHeight = 16;
}

struct BVHBuildPrimitive
{
    int triangleIndex = -1;
    Vector3 boundsMin;
    Vector3 boundsMax;
    Vector3 centroid;
};

static Vector3 BoundsMin(const Vector3& a, const Vector3& b)
{
    return Vector3(a.x < b.x ? a.x : b.x, a.y < b.y ? a.y : b.y, a.z < b.z ? a.z : b.z);
}

static Vector3 BoundsMax(const Vector3& a, const Vector3& b)
{
    return Vector3(a.x > b.x ? a.x : b.x, a.y > b.y ? a.y : b.y, a.z > b.z ? a.z : b.z);
}

static int BuildBVHRecursive(std::vector<BVHBuildPrimitive>& primitives, int begin, int end, std::vector<BVHNode>& nodes, std::vector<int>& triangleIndices)
{
    const int nodeIndex = static_cast<int>(nodes.size());
    nodes.emplace_back();

    const float maxFloat = (std::numeric_limits<float>::max)();
    Vector3 boundsMin(maxFloat, maxFloat, maxFloat);
    Vector3 boundsMax(-maxFloat, -maxFloat, -maxFloat);
    Vector3 centroidMin(maxFloat, maxFloat, maxFloat);
    Vector3 centroidMax(-maxFloat, -maxFloat, -maxFloat);

    for (int i = begin; i < end; i++)
    {
        boundsMin = BoundsMin(boundsMin, primitives[i].boundsMin);
        boundsMax = BoundsMax(boundsMax, primitives[i].boundsMax);
        centroidMin = BoundsMin(centroidMin, primitives[i].centroid);
        centroidMax = BoundsMax(centroidMax, primitives[i].centroid);
    }

    nodes[nodeIndex].boundsMin = boundsMin;
    nodes[nodeIndex].boundsMax = boundsMax;

    const int primitiveCount = end - begin;
    const float extentX = centroidMax.x - centroidMin.x;
    const float extentY = centroidMax.y - centroidMin.y;
    const float extentZ = centroidMax.z - centroidMin.z;

    if (primitiveCount <= 4 || (extentX <= 1e-6f && extentY <= 1e-6f && extentZ <= 1e-6f))
    {
        nodes[nodeIndex].start = static_cast<int>(triangleIndices.size());
        nodes[nodeIndex].count = primitiveCount;
        for (int i = begin; i < end; i++)
        {
            triangleIndices.push_back(primitives[i].triangleIndex);
        }
        return nodeIndex;
    }

    int axis = 0;
    if (extentY > extentX && extentY >= extentZ)
    {
        axis = 1;
    }
    else if (extentZ > extentX && extentZ > extentY)
    {
        axis = 2;
    }

    const int middle = begin + primitiveCount / 2;
    std::nth_element(primitives.begin() + begin, primitives.begin() + middle, primitives.begin() + end,
        [axis](const BVHBuildPrimitive& lhs, const BVHBuildPrimitive& rhs)
        {
            return lhs.centroid[axis] < rhs.centroid[axis];
        });

    nodes[nodeIndex].left = BuildBVHRecursive(primitives, begin, middle, nodes, triangleIndices);
    nodes[nodeIndex].right = BuildBVHRecursive(primitives, middle, end, nodes, triangleIndices);
    return nodeIndex;
}

static void AssignBVHEscapeIndices(std::vector<BVHNode>& nodes, int nodeIndex, int escapeIndex)
{
    BVHNode& node = nodes[nodeIndex];
    node.next = escapeIndex;
    if (node.IsLeaf())
    {
        return;
    }

    AssignBVHEscapeIndices(nodes, node.left, node.right);
    AssignBVHEscapeIndices(nodes, node.right, escapeIndex);
}

static void BuildTriangleBVH(World* world, std::vector<BVHNode>& nodes, std::vector<int>& triangleIndices)
{
    nodes.clear();
    triangleIndices.clear();
    if (world == nullptr || world->triangles.empty())
    {
        return;
    }

    std::vector<BVHBuildPrimitive> primitives;
    primitives.reserve(world->triangles.size());

    for (int i = 0; i < static_cast<int>(world->triangles.size()); i++)
    {
        const Triangle& triangle = world->triangles[i];
        if (triangle.vertexIdx[0] < 0 || triangle.vertexIdx[0] >= static_cast<int>(world->vertices.size()) ||
            triangle.vertexIdx[1] < 0 || triangle.vertexIdx[1] >= static_cast<int>(world->vertices.size()) ||
            triangle.vertexIdx[2] < 0 || triangle.vertexIdx[2] >= static_cast<int>(world->vertices.size()))
        {
            continue;
        }

        const Vector3& a = world->vertices[triangle.vertexIdx[0]].worldLocation;
        const Vector3& b = world->vertices[triangle.vertexIdx[1]].worldLocation;
        const Vector3& c = world->vertices[triangle.vertexIdx[2]].worldLocation;

        BVHBuildPrimitive primitive;
        primitive.triangleIndex = i;
        primitive.boundsMin = BoundsMin(a, BoundsMin(b, c));
        primitive.boundsMax = BoundsMax(a, BoundsMax(b, c));
        primitive.centroid = Vector3((a.x + b.x + c.x) / 3.0f, (a.y + b.y + c.y) / 3.0f, (a.z + b.z + c.z) / 3.0f);
        primitives.push_back(primitive);
    }

    if (primitives.empty())
    {
        return;
    }

    BuildBVHRecursive(primitives, 0, static_cast<int>(primitives.size()), nodes, triangleIndices);
    AssignBVHEscapeIndices(nodes, 0, -1);
    printf("Triangle BVH: %zu triangles, %zu nodes.\n", triangleIndices.size(), nodes.size());
}

__device__ __forceinline__ bool HitAABB(const BVHNode& node, const Ray* ray, float maxDistance)
{
    float tMin = MIN_DETECT_DISTANCE;
    float tMax = maxDistance;

    for (int axis = 0; axis < 3; axis++)
    {
        const float origin = ray->location[axis];
        const float direction = ray->direction[axis];
        const float boundsMin = node.boundsMin[axis];
        const float boundsMax = node.boundsMax[axis];

        if (fabsf(direction) < 1e-8f)
        {
            if (origin < boundsMin || origin > boundsMax)
            {
                return false;
            }
            continue;
        }

        const float invDirection = 1.0f / direction;
        float t0 = (boundsMin - origin) * invDirection;
        float t1 = (boundsMax - origin) * invDirection;
        if (t0 > t1)
        {
            const float temp = t0;
            t0 = t1;
            t1 = temp;
        }

        tMin = Max(tMin, t0);
        tMax = Min(tMax, t1);
        if (tMax < tMin)
        {
            return false;
        }
    }

    return true;
}

__device__ __forceinline__ Vector3 SampleTextureNearest(const Texture& texture, float u, float v)
{
    if (DevWorld->texturePixels == nullptr || texture.width <= 0 || texture.height <= 0 || texture.channels <= 0)
    {
        return Vector3(0.0f, 0.0f, 0.0f);
    }

    u = Clamp(u, 0.0f, 1.0f);
    v = Clamp(v, 0.0f, 1.0f);
    const int x = Min(static_cast<int>(u * texture.width), texture.width - 1);
    const int y = Min(static_cast<int>(v * texture.height), texture.height - 1);
    const int pixelIndex = texture.pixelIdx + (y * texture.width + x) * texture.channels;
    if (pixelIndex < 0 || pixelIndex >= DevWorld->texturePixelsSize)
    {
        return Vector3(0.0f, 0.0f, 0.0f);
    }

    const float r = DevWorld->texturePixels[pixelIndex] / 255.0f;
    const float g = texture.channels > 1 && pixelIndex + 1 < DevWorld->texturePixelsSize ? DevWorld->texturePixels[pixelIndex + 1] / 255.0f : r;
    const float b = texture.channels > 2 && pixelIndex + 2 < DevWorld->texturePixelsSize ? DevWorld->texturePixels[pixelIndex + 2] / 255.0f : r;
    return Vector3(r, g, b);
}

__device__ __forceinline__ Vector3 GetTriangleNormal(const Triangle& triangle, const Vector3& barycentricCoordinate)
{
    if (!triangle.vertexNormal)
    {
        return triangle.normal;
    }

    const Vertex& v0 = DevWorld->vertices[triangle.vertexIdx[0]];
    const Vertex& v1 = DevWorld->vertices[triangle.vertexIdx[1]];
    const Vertex& v2 = DevWorld->vertices[triangle.vertexIdx[2]];
    Vector3 normal = v0.worldDirection * barycentricCoordinate.x + v1.worldDirection * barycentricCoordinate.y + v2.worldDirection * barycentricCoordinate.z;
    const float lengthSquared = Dot(normal, normal);
    if (lengthSquared <= 1e-16f)
    {
        return triangle.normal;
    }
    return normal / sqrtf(lengthSquared);
}

__device__ __forceinline__ Vector3 GetTriangleAlbedo(const Triangle& triangle, const Material& material, const Vector3& barycentricCoordinate)
{
    if (material.textureIdx < 0 || material.textureIdx >= DevWorld->texturesSize)
    {
        return material.albedo;
    }

    const Vertex& v0 = DevWorld->vertices[triangle.vertexIdx[0]];
    const Vertex& v1 = DevWorld->vertices[triangle.vertexIdx[1]];
    const Vertex& v2 = DevWorld->vertices[triangle.vertexIdx[2]];
    const Vector2 uv = v0.textureCoordinate * barycentricCoordinate.x + v1.textureCoordinate * barycentricCoordinate.y + v2.textureCoordinate * barycentricCoordinate.z;
    return SampleTextureNearest(DevWorld->textures[material.textureIdx], uv.x, uv.y);
}

__device__ __forceinline__ bool PointInQuadrilateral(const Quadrilateral& quadrilateral, const Vector3& location)
{
    float referenceSide = 0.0f;
    constexpr float edgeEpsilon = 1e-6f;

    for (int i = 0; i < 4; i++)
    {
        const Vector3& a = DevWorld->vertices[quadrilateral.vertexIdx[i]].worldLocation;
        const Vector3& b = DevWorld->vertices[quadrilateral.vertexIdx[(i + 1) & 3]].worldLocation;
        const float side = Dot(Cross(b - a, location - a), quadrilateral.normal);
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

__device__ __forceinline__ bool HitDetect(Sphere* sphere, Ray* ray, RayHitResult* hitResult)
{
    const Vector3 oc = ray->location - sphere->worldLocation;
    const float a = Dot(ray->direction, ray->direction);
    if (a <= 1e-20f)
    {
        return false;
    }

    const float halfB = Dot(oc, ray->direction);
    const float c = Dot(oc, oc) - sphere->radius * sphere->radius;
    const float discriminant = halfB * halfB - a * c;
    if (discriminant < 0.0f)
    {
        return false;
    }

    const float sqrtD = sqrtf(discriminant);
    float distance = (-halfB - sqrtD) / a;
    if (distance < MIN_DETECT_DISTANCE)
    {
        distance = (-halfB + sqrtD) / a;
    }
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->distance = distance;
    hitResult->location = ray->location + ray->direction * distance;
    const Vector3 normalDelta = hitResult->location - sphere->worldLocation;
    const float radius = fabsf(sphere->radius);
    hitResult->normal = radius > 1e-8f ? normalDelta / radius : normalDelta.GetNormalized();
    hitResult->material = DevWorld->materials + sphere->materialIdx;
    hitResult->color = hitResult->material->albedo;
    hitResult->objectId = sphere->id;
    return true;
}

__device__ __forceinline__ bool HitDetect(Triangle* triangle, Ray* ray, RayHitResult* hitResult)
{
    Material* material = DevWorld->materials + triangle->materialIdx;
    const float facing = Dot(ray->direction, triangle->normal);
    if (fabsf(facing) < 1e-7f || (facing > 0.0f && !material->backVisible))
    {
        return false;
    }

    const Vector3& a = DevWorld->vertices[triangle->vertexIdx[0]].worldLocation;
    const Vector3& b = DevWorld->vertices[triangle->vertexIdx[1]].worldLocation;
    const Vector3& c = DevWorld->vertices[triangle->vertexIdx[2]].worldLocation;
    const Vector3 edge1 = b - a;
    const Vector3 edge2 = c - a;
    const Vector3 p = Cross(ray->direction, edge2);
    const float determinant = Dot(edge1, p);
    if (fabsf(determinant) < 1e-8f)
    {
        return false;
    }

    const float invDeterminant = 1.0f / determinant;
    const Vector3 t = ray->location - a;
    const float u = Dot(t, p) * invDeterminant;
    if (u < 0.0f || u > 1.0f)
    {
        return false;
    }

    const Vector3 q = Cross(t, edge1);
    const float v = Dot(ray->direction, q) * invDeterminant;
    if (v < 0.0f || u + v > 1.0f)
    {
        return false;
    }

    const float distance = Dot(edge2, q) * invDeterminant;
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    const Vector3 coordinate(1.0f - u - v, u, v);
    Vector3 normal = GetTriangleNormal(*triangle, coordinate);
    if (Dot(normal, ray->direction) > 0.0f)
    {
        normal = -normal;
    }

    hitResult->isHit = true;
    hitResult->material = material;
    hitResult->color = GetTriangleAlbedo(*triangle, *material, coordinate);
    hitResult->distance = distance;
    hitResult->location = ray->location + ray->direction * distance;
    hitResult->normal = normal;
    hitResult->objectId = triangle->id;
    return true;
}

__device__ __forceinline__ bool HitDetect(Quadrilateral* quadrilateral, Ray* ray, RayHitResult* hitResult)
{
    Vector3 n = quadrilateral->normal;
    float d = quadrilateral->distance;
    float in = Dot(ray->direction, n);
    if (fabsf(in) < 1e-7f)
    {
        return false;
    }

    Material* material = DevWorld->materials + quadrilateral->materialIdx;
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

    const float distance = -(Dot(ray->location, n) + d) / in;
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    const Vector3 location = ray->location + ray->direction * distance;
    if (!PointInQuadrilateral(*quadrilateral, location))
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->material = material;
    hitResult->color = material->albedo;
    hitResult->distance = distance;
    hitResult->location = location;
    hitResult->normal = n;
    hitResult->objectId = quadrilateral->id;
    return true;
}

__device__ __forceinline__ void WorldHitDetect(Ray* ray, RayHitResult* hitResult)
{
    for (int i = 0; i < DevWorld->spheresSize; i++)
    {
        HitDetect(DevWorld->spheres + i, ray, hitResult);
    }

    if (DevWorld->bvhNodes != nullptr && DevWorld->bvhNodesSize > 0 && DevWorld->bvhTriangleIndices != nullptr)
    {
        int nodeIndex = 0;
        while (nodeIndex >= 0 && nodeIndex < DevWorld->bvhNodesSize)
        {
            const BVHNode& node = DevWorld->bvhNodes[nodeIndex];
            if (!HitAABB(node, ray, hitResult->distance))
            {
                nodeIndex = node.next;
                continue;
            }

            if (node.IsLeaf())
            {
                for (int i = 0; i < node.count; i++)
                {
                    const int triangleIndex = DevWorld->bvhTriangleIndices[node.start + i];
                    HitDetect(DevWorld->triangles + triangleIndex, ray, hitResult);
                }
                nodeIndex = node.next;
            }
            else
            {
                nodeIndex = node.left;
            }
        }
    }
    else
    {
        for (int i = 0; i < DevWorld->trianglesSize; i++)
        {
            HitDetect(DevWorld->triangles + i, ray, hitResult);
        }
    }

    for (int i = 0; i < DevWorld->quadrilateralsSize; i++)
    {
        HitDetect(DevWorld->quadrilaterals + i, ray, hitResult);
    }
    for (int i = 0; i < DevWorld->lightsSize; i++)
    {
        HitDetect(DevWorld->lights + i, ray, hitResult);
    }
}

__device__ __forceinline__ bool EvaluateBRDF(RayHitResult* hitResult, const Vector3& incident, const Vector3& exiting, Vector3* brdf)
{
    if (hitResult->material == nullptr)
    {
        return false;
    }

    const Vector3& normal = hitResult->normal;
    const float NoV = Dot(normal, incident);
    const float NoL = Dot(normal, exiting);
    if (NoV <= 0.0f || NoL <= 0.0f)
    {
        return false;
    }

    const Vector3 halfVectorRaw = incident + exiting;
    const float halfLengthSquared = Dot(halfVectorRaw, halfVectorRaw);
    if (halfLengthSquared <= 1e-12f)
    {
        return false;
    }

    const Vector3 h = halfVectorRaw / sqrtf(halfLengthSquared);
    const float VoH = Max(Dot(incident, h), 0.0f);
    if (VoH <= 0.0f)
    {
        return false;
    }

    const float roughness = Clamp(hitResult->material->roughness, 0.001f, 1.0f);
    const float fresnel = SchlickFresnel(1.0f, hitResult->material->refractionIndex, h, incident);
    const float distribution = NDF_GGX(normal, h, roughness);
    const float geometry = GF_SmithJointGGX(normal, incident, exiting, roughness);

    const Vector3 diffuse = hitResult->color * ((1.0f - fresnel) / PI);
    const float specularScale = fresnel * distribution * geometry / Max(4.0f * NoV * NoL, 1e-8f);
    const Vector3 specular(specularScale, specularScale, specularScale);
    *brdf = diffuse + specular;
    return true;
}

__device__ __forceinline__ bool DirectLightSample(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, Sphere* light, RaySampleResult* sampleResult)
{
    if (light == nullptr || sampleResult == nullptr || light->materialIdx < 0 || light->materialIdx >= DevWorld->materialsSize)
    {
        return false;
    }

    Material* lightMaterial = DevWorld->materials + light->materialIdx;
    if (!lightMaterial->isEmit || lightMaterial->intensity <= 0.0f)
    {
        return false;
    }

    const Vector3 incident = -ray->direction;
    const Vector3 exiting = WeightedSampleSphereLight(state, hitResult->location, light->worldLocation, light->radius);
    const float cosout = Dot(hitResult->normal, exiting);
    if (cosout <= 0.0f)
    {
        return false;
    }

    Ray sampleRay(hitResult->location + hitResult->normal * (MIN_DETECT_DISTANCE * 2.0f), exiting);
    RayHitResult sampleHitResult;
    WorldHitDetect(&sampleRay, &sampleHitResult);
    if (!sampleHitResult.isHit || sampleHitResult.objectId != light->id)
    {
        return false;
    }

    if (!EvaluateBRDF(hitResult, incident, exiting, &sampleResult->brdf))
    {
        return false;
    }

    const float dist = (light->worldLocation - hitResult->location).Length();
    if (dist <= light->radius)
    {
        return false;
    }

    const float sinThetaMax2 = Clamp((light->radius * light->radius) / (dist * dist), 0.0f, 1.0f);
    const float cosThetaMax = sqrtf(Max(0.0f, 1.0f - sinThetaMax2));
    sampleResult->pdf = 1.0f / Max(2.0f * PI * (1.0f - cosThetaMax), 1e-8f);
    sampleResult->cosine = cosout;
    sampleResult->attenuation = 1.0f;
    return true;
}

__device__ __forceinline__ Vector3 EstimateDirectLighting(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult)
{
    Vector3 directRadiance(0.0f, 0.0f, 0.0f);
    for (int i = 0; i < DevWorld->lightsSize; i++)
    {
        Sphere* light = DevWorld->lights + i;
        if (light->materialIdx < 0 || light->materialIdx >= DevWorld->materialsSize)
        {
            continue;
        }

        Material* lightMaterial = DevWorld->materials + light->materialIdx;
        RaySampleResult directSample;
        if (!DirectLightSample(state, ray, hitResult, light, &directSample) || directSample.pdf <= 0.0f)
        {
            continue;
        }

        const Vector3 emitted = lightMaterial->emit * lightMaterial->intensity;
        directRadiance = directRadiance + emitted * directSample.brdf * (directSample.cosine / directSample.pdf);
    }
    return directRadiance;
}

__device__ __forceinline__ bool IndirectLightSampleRandom(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    const Vector3 incident = -ray->direction;
    const Vector3 exiting = WeightedSampleRandom(state, hitResult->normal);
    const float cosout = Dot(hitResult->normal, exiting);
    if (cosout <= 0.0f)
    {
        return false;
    }

    if (!EvaluateBRDF(hitResult, incident, exiting, &sampleResult->brdf))
    {
        return false;
    }

    sampleResult->pdf = 1.0f / (2.0f * PI);
    sampleResult->cosine = cosout;
    sampleResult->attenuation = 1.0f;
    ray->location = hitResult->location + hitResult->normal * (MIN_DETECT_DISTANCE * 2.0f);
    ray->direction = exiting;
    return true;
}

__device__ __forceinline__ bool IndirectLightSampleCosine(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    const Vector3 incident = -ray->direction;
    const Vector3 exiting = WeightedSampleCosine(state, hitResult->normal);
    const float cosout = Dot(hitResult->normal, exiting);
    if (cosout <= 0.0f)
    {
        return false;
    }

    if (!EvaluateBRDF(hitResult, incident, exiting, &sampleResult->brdf))
    {
        return false;
    }

    sampleResult->pdf = cosout / PI;
    sampleResult->cosine = cosout;
    sampleResult->attenuation = 1.0f;
    ray->location = hitResult->location + hitResult->normal * (MIN_DETECT_DISTANCE * 2.0f);
    ray->direction = exiting;
    return sampleResult->pdf > 0.0f;
}

__device__ __forceinline__ bool IndirectLightSampleGGX(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    const Vector3 incident = -ray->direction;
    const float roughness = Clamp(hitResult->material->roughness, 0.001f, 1.0f);
    const Vector3 h = WeightedSampleGGX(state, hitResult->normal, roughness);
    const float VoH = Dot(incident, h);
    if (VoH <= 0.0f)
    {
        return false;
    }

    const Vector3 exiting = Reflect(h, incident);
    const float cosout = Dot(hitResult->normal, exiting);
    if (cosout <= 0.0f)
    {
        return false;
    }

    if (!EvaluateBRDF(hitResult, incident, exiting, &sampleResult->brdf))
    {
        return false;
    }

    const float NoH = Max(Dot(hitResult->normal, h), 0.0f);
    const float distribution = NDF_GGX(hitResult->normal, h, roughness);
    const float halfVectorPdf = distribution * NoH;
    sampleResult->pdf = halfVectorPdf / Max(4.0f * VoH, 1e-8f);
    sampleResult->cosine = cosout;
    sampleResult->attenuation = 1.0f;
    ray->location = hitResult->location + hitResult->normal * (MIN_DETECT_DISTANCE * 2.0f);
    ray->direction = exiting;
    return sampleResult->pdf > 0.0f;
}

__device__ __forceinline__ bool IndirectLightSample(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult, int sampleMode)
{
    switch (static_cast<IndirectSampleMode>(sampleMode))
    {
    case IndirectSampleMode::UniformHemisphere:
        return IndirectLightSampleRandom(state, ray, hitResult, sampleResult);
    case IndirectSampleMode::GGX:
        return IndirectLightSampleGGX(state, ray, hitResult, sampleResult);
    case IndirectSampleMode::CosineHemisphere:
    default:
        return IndirectLightSampleCosine(state, ray, hitResult, sampleResult);
    }
}

__device__ __forceinline__ bool SamplingUsesDirect(int samplingMode)
{
    const SamplingMode mode = static_cast<SamplingMode>(samplingMode);
    return mode == SamplingMode::DirectOnly || mode == SamplingMode::DirectUniformHemisphere || mode == SamplingMode::DirectCosineHemisphere || mode == SamplingMode::DirectGGX;
}

__device__ __forceinline__ bool SamplingUsesIndirect(int samplingMode)
{
    return static_cast<SamplingMode>(samplingMode) != SamplingMode::DirectOnly;
}

__device__ __forceinline__ int ResolveIndirectSampleMode(int samplingMode)
{
    const SamplingMode mode = static_cast<SamplingMode>(samplingMode);
    if (mode == SamplingMode::UniformHemisphere || mode == SamplingMode::DirectUniformHemisphere)
    {
        return static_cast<int>(IndirectSampleMode::UniformHemisphere);
    }
    if (mode == SamplingMode::GGX || mode == SamplingMode::DirectGGX)
    {
        return static_cast<int>(IndirectSampleMode::GGX);
    }
    return static_cast<int>(IndirectSampleMode::CosineHemisphere);
}

__device__ __forceinline__ Vector3 FullPathRayTrace(curandStateXORWOW_t* state, Ray* ray, int sampleDepth, int samplingMode)
{
    Vector3 radiance(0.0f, 0.0f, 0.0f);
    Vector3 throughput(1.0f, 1.0f, 1.0f);
    const int maxDepth = Max(sampleDepth, 1);
    const bool useDirect = SamplingUsesDirect(samplingMode);
    const bool useIndirect = SamplingUsesIndirect(samplingMode);
    const int indirectSampleMode = ResolveIndirectSampleMode(samplingMode);

    for (int i = 0; i < maxDepth; i++)
    {
        RayHitResult hit;
        WorldHitDetect(ray, &hit);
        if (!hit.isHit)
        {
            return radiance;
        }

        if (hit.material != nullptr && hit.material->isEmit)
        {
            if (!useDirect || i == 0)
            {
                radiance = radiance + hit.material->emit * hit.material->intensity * throughput;
            }
            return radiance;
        }

        if (useDirect)
        {
            radiance = radiance + throughput * EstimateDirectLighting(state, ray, &hit);
        }

        if (!useIndirect)
        {
            return radiance;
        }

        RaySampleResult sampleResult;
        if (!IndirectLightSample(state, ray, &hit, &sampleResult, indirectSampleMode) || sampleResult.pdf <= 0.0f)
        {
            return radiance;
        }

        throughput = throughput * sampleResult.brdf * (sampleResult.cosine / sampleResult.pdf);
        ray->depth++;

        if (i >= 3)
        {
            const float survivalProbability = Clamp(Max(throughput.x, Max(throughput.y, throughput.z)), 0.05f, 0.95f);
            if (DevRandOpen(state) > survivalProbability)
            {
                return radiance;
            }
            throughput = throughput / survivalProbability;
        }
    }

    return radiance;
}

__device__ __forceinline__ void StoreToneMappedPixel(uint8_t* pixels, int idx, const Vector3& linearColor)
{
    const Vector3 color = AcesFilm(linearColor);
    pixels[idx * 4 + 0] = static_cast<uint8_t>(Clamp(color.x, 0.0f, 1.0f) * 255.0f);
    pixels[idx * 4 + 1] = static_cast<uint8_t>(Clamp(color.y, 0.0f, 1.0f) * 255.0f);
    pixels[idx * 4 + 2] = static_cast<uint8_t>(Clamp(color.z, 0.0f, 1.0f) * 255.0f);
    pixels[idx * 4 + 3] = 255;
}

__global__ void KernelRayTrace(curandStateXORWOW_t* states, float* radiants, uint8_t* pixels, int sampleCount, int width, int height, int sampleDepth, int samplingMode, int filterKernelSize,
    float cameraFocus, float cameraX, float cameraY, float cameraZ,
    float r00, float r01, float r02, float r10, float r11, float r12, float r20, float r21, float r22,
    float translateX, float scaleX, float translateY, float scaleY)
{
    const int x = blockIdx.x * blockDim.x + threadIdx.x;
    const int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height)
    {
        return;
    }

    const int idx = y * width + x;
    curandStateXORWOW_t* state = states + idx;
    Vector3 camDirection(((x + DevRand(state)) + translateX) * scaleX, ((y + DevRand(state)) + translateY) * scaleY, cameraFocus);
    camDirection.Normalize();

    Vector3 worldDirection(
        r00 * camDirection.x + r01 * camDirection.y + r02 * camDirection.z,
        r10 * camDirection.x + r11 * camDirection.y + r12 * camDirection.z,
        r20 * camDirection.x + r21 * camDirection.y + r22 * camDirection.z);
    worldDirection.Normalize();

    Ray ray(Vector3(cameraX, cameraY, cameraZ), worldDirection);
    const Vector3 color = FullPathRayTrace(state, &ray, sampleDepth, samplingMode);

    float* radiant = radiants + idx * 4;
    const float blend = 1.0f / static_cast<float>(sampleCount + 1);
    radiant[0] += (color.x - radiant[0]) * blend;
    radiant[1] += (color.y - radiant[1]) * blend;
    radiant[2] += (color.z - radiant[2]) * blend;
    radiant[3] = 1.0f;

    if (filterKernelSize <= 1)
    {
        StoreToneMappedPixel(pixels, idx, Vector3(radiant[0], radiant[1], radiant[2]));
    }
}

__global__ void KernelPixel(int kernelSize, const float* src, int width, int height, uint8_t* dst)
{
    const int x = blockIdx.x * blockDim.x + threadIdx.x;
    const int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height)
    {
        return;
    }

    const int idx = y * width + x;
    const int offset = Max(kernelSize, 1) / 2;
    Vector3 color;
    int count = 0;

    for (int yy = Max(0, y - offset); yy <= Min(height - 1, y + offset); yy++)
    {
        for (int xx = Max(0, x - offset); xx <= Min(width - 1, x + offset); xx++)
        {
            const int sourceIdx = (yy * width + xx) * 4;
            color.x += src[sourceIdx + 0];
            color.y += src[sourceIdx + 1];
            color.z += src[sourceIdx + 2];
            count++;
        }
    }

    if (count > 0)
    {
        color = color / static_cast<float>(count);
    }
    StoreToneMappedPixel(dst, idx, color);
}

template <typename T>
static bool CudaAlloc(T** ptr, size_t count, const char* name)
{
    if (ptr == nullptr)
    {
        return false;
    }
    *ptr = nullptr;
    if (count == 0)
    {
        return true;
    }
    if (count > (std::numeric_limits<size_t>::max)() / sizeof(T))
    {
        printf("cudaMalloc %s failed: allocation size overflow.\n", name);
        return false;
    }

    const cudaError_t error = cudaMalloc(reinterpret_cast<void**>(ptr), sizeof(T) * count);
    if (error != cudaSuccess)
    {
        printf("cudaMalloc %s failed with error \"%s\".\n", name, cudaGetErrorString(error));
        *ptr = nullptr;
        return false;
    }
    return true;
}

template <typename T>
static bool CopyVectorToDevice(T* dst, const std::vector<T>& src, const char* name)
{
    if (src.empty())
    {
        return true;
    }
    if (dst == nullptr)
    {
        printf("cudaMemcpy %s failed: destination is null.\n", name);
        return false;
    }

    const cudaError_t error = cudaMemcpy(dst, src.data(), sizeof(T) * src.size(), cudaMemcpyHostToDevice);
    if (error != cudaSuccess)
    {
        printf("cudaMemcpy %s failed with error \"%s\".\n", name, cudaGetErrorString(error));
        return false;
    }
    return true;
}

static bool CudaMemsetChecked(void* ptr, int value, size_t bytes, const char* name)
{
    if (ptr == nullptr || bytes == 0)
    {
        return bytes == 0;
    }

    const cudaError_t error = cudaMemset(ptr, value, bytes);
    if (error != cudaSuccess)
    {
        printf("cudaMemset %s failed with error \"%s\".\n", name, cudaGetErrorString(error));
        return false;
    }
    return true;
}

static bool CheckKernelLaunch(const char* name)
{
    const cudaError_t error = cudaGetLastError();
    if (error != cudaSuccess)
    {
        printf("kernel %s launch failed with error \"%s\".\n", name, cudaGetErrorString(error));
        return false;
    }
    return true;
}

template <typename T>
static void CudaFreeAndNull(T*& ptr)
{
    if (ptr != nullptr)
    {
        cudaFree(ptr);
        ptr = nullptr;
    }
}

static void ReleaseHostPixels(Renderer* renderer)
{
    if (renderer == nullptr || renderer->pixelsData == nullptr)
    {
        if (renderer != nullptr)
        {
            renderer->pixelsDataPinned = false;
        }
        return;
    }

    if (renderer->pixelsDataPinned)
    {
        cudaFreeHost(renderer->pixelsData);
    }
    else
    {
        delete[] renderer->pixelsData;
    }
    renderer->pixelsData = nullptr;
    renderer->pixelsDataPinned = false;
}

static void ReleaseDeviceResources(Renderer* renderer)
{
    if (renderer == nullptr)
    {
        return;
    }

    CudaFreeAndNull(renderer->devRandStates);
    CudaFreeAndNull(renderer->devVertices);
    CudaFreeAndNull(renderer->devSpheres);
    CudaFreeAndNull(renderer->devTriangles);
    CudaFreeAndNull(renderer->devQuadrilaterals);
    CudaFreeAndNull(renderer->devMeshes);
    CudaFreeAndNull(renderer->devLights);
    CudaFreeAndNull(renderer->devMaterials);
    CudaFreeAndNull(renderer->devTextures);
    CudaFreeAndNull(renderer->devTexturePixels);
    CudaFreeAndNull(renderer->devBVHNodes);
    CudaFreeAndNull(renderer->devBVHTriangleIndices);
    CudaFreeAndNull(renderer->devRadiometry);
    CudaFreeAndNull(renderer->devPixels);
    renderer->devWorld = DeviceWorld{};
}

Renderer::~Renderer()
{
    initialized = false;
    UnregisterOpenGLPixelBuffers();
    ReleaseHostPixels(this);
    ReleaseDeviceResources(this);
}

bool Renderer::IsGraphicsInteropEnabled() const
{
    return graphicsInteropEnabled && cudaPixelBufferResource != nullptr && pixelBufferObject != 0;
}

void Renderer::Init()
{
    initialized = false;
    frame = 0;
    frameTime = 0;
    timer = 0;
    UnregisterOpenGLPixelBuffers();
    ReleaseHostPixels(this);
    ReleaseDeviceResources(this);

    World* world = GetWorld();
    Camera* camera = GetCamera();
    if (world == nullptr || camera == nullptr)
    {
        printf("Renderer::Init failed: world or camera is null.\n");
        return;
    }
    if (width <= 0 || height <= 0)
    {
        printf("Renderer::Init failed: invalid resolution %d x %d.\n", width, height);
        return;
    }
    if (devThreadNum <= 0)
    {
        devThreadNum = 256;
    }

    const int64_t pixelCount64 = static_cast<int64_t>(width) * static_cast<int64_t>(height);
    if (pixelCount64 <= 0 || pixelCount64 > static_cast<int64_t>((std::numeric_limits<int>::max)()))
    {
        printf("Renderer::Init failed: resolution is too large.\n");
        return;
    }
    const int pixelCount = static_cast<int>(pixelCount64);
    const size_t pixelBytes = static_cast<size_t>(pixelCount) * 4;

    unsigned int glDeviceCount = 0;
    int glDevices[8]{};
    const cudaError_t glDeviceError = cudaGLGetDevices(&glDeviceCount, glDevices, 8, cudaGLDeviceListCurrentFrame);
    if (glDeviceError == cudaSuccess && glDeviceCount > 0)
    {
        const cudaError_t setDeviceError = cudaSetDevice(glDevices[0]);
        if (setDeviceError != cudaSuccess)
        {
            printf("cudaSetDevice(%d) failed with error \"%s\".\n", glDevices[0], cudaGetErrorString(setDeviceError));
            return;
        }
        printf("CUDA/OpenGL shared device: %d.\n", glDevices[0]);
    }
    else
    {
        cudaGetLastError();
    }

    const float left = camera->focus * -tanf(camera->fovX * PI / 180.0f / 2.0f);
    const float right = camera->focus * tanf(camera->fovX * PI / 180.0f / 2.0f);
    const float top = camera->focus * tanf(camera->fovY * PI / 180.0f / 2.0f);
    const float bottom = camera->focus * -tanf(camera->fovY * PI / 180.0f / 2.0f);

    translateX = -static_cast<float>(width) / 2.0f;
    translateY = -static_cast<float>(height) / 2.0f;
    scaleX = (right - left) / static_cast<float>(width);
    scaleY = (top - bottom) / static_cast<float>(height);

    const cudaError_t hostAllocError = cudaHostAlloc(reinterpret_cast<void**>(&pixelsData), pixelBytes, cudaHostAllocDefault);
    if (hostAllocError == cudaSuccess)
    {
        pixelsDataPinned = true;
        std::memset(pixelsData, 0, pixelBytes);
    }
    else
    {
        cudaGetLastError();
        pixelsDataPinned = false;
        pixelsData = new (std::nothrow) uint8_t[pixelBytes]{};
        if (pixelsData == nullptr)
        {
            printf("Renderer::Init failed: host pixel allocation failed after cudaHostAlloc error \"%s\".\n", cudaGetErrorString(hostAllocError));
            return;
        }
        printf("cudaHostAlloc pixelsData failed with error \"%s\"; using pageable memory fallback.\n", cudaGetErrorString(hostAllocError));
    }

    std::vector<BVHNode> bvhNodes;
    std::vector<int> bvhTriangleIndices;
    BuildTriangleBVH(world, bvhNodes, bvhTriangleIndices);

    const bool allocationsSucceeded =
        CudaAlloc(&devRandStates, static_cast<size_t>(pixelCount), "devRandStates") &&
        CudaAlloc(&devVertices, world->vertices.size(), "devVertices") &&
        CudaAlloc(&devSpheres, world->spheres.size(), "devSpheres") &&
        CudaAlloc(&devTriangles, world->triangles.size(), "devTriangles") &&
        CudaAlloc(&devQuadrilaterals, world->quadrilaterals.size(), "devQuadrilaterals") &&
        CudaAlloc(&devMeshes, world->meshes.size(), "devMeshes") &&
        CudaAlloc(&devLights, world->lights.size(), "devLights") &&
        CudaAlloc(&devMaterials, world->materials.size(), "devMaterials") &&
        CudaAlloc(&devTextures, world->textures.size(), "devTextures") &&
        CudaAlloc(&devTexturePixels, world->texturePixels.size(), "devTexturePixels") &&
        CudaAlloc(&devBVHNodes, bvhNodes.size(), "devBVHNodes") &&
        CudaAlloc(&devBVHTriangleIndices, bvhTriangleIndices.size(), "devBVHTriangleIndices") &&
        CudaAlloc(&devRadiometry, static_cast<size_t>(pixelCount) * 4, "devRadiometry") &&
        CudaAlloc(&devPixels, pixelBytes, "devPixels");
    if (!allocationsSucceeded)
    {
        printf("Renderer::Init failed while allocating CUDA resources.\n");
        ReleaseHostPixels(this);
        ReleaseDeviceResources(this);
        return;
    }

    const dim3 randomBlockDim(static_cast<unsigned int>(devThreadNum), 1, 1);
    const dim3 randomGridDim(static_cast<unsigned int>((pixelCount + devThreadNum - 1) / devThreadNum), 1, 1);
    InitRandStates<<<randomGridDim, randomBlockDim>>>(devRandStates, static_cast<unsigned long long>(time(nullptr)), pixelCount);
    if (!CheckKernelLaunch("InitRandStates"))
    {
        ReleaseHostPixels(this);
        ReleaseDeviceResources(this);
        return;
    }
    const cudaError_t randomSyncError = cudaDeviceSynchronize();
    if (randomSyncError != cudaSuccess)
    {
        printf("Renderer::Init failed while initializing random states with error \"%s\".\n", cudaGetErrorString(randomSyncError));
        ReleaseHostPixels(this);
        ReleaseDeviceResources(this);
        return;
    }

    if (!CudaMemsetChecked(devRadiometry, 0, sizeof(float) * static_cast<size_t>(pixelCount) * 4, "devRadiometry") ||
        !CudaMemsetChecked(devPixels, 0, pixelBytes, "devPixels"))
    {
        ReleaseHostPixels(this);
        ReleaseDeviceResources(this);
        return;
    }

    devWorld.vertices = devVertices;
    devWorld.verticesSize = static_cast<int>(world->vertices.size());
    devWorld.spheres = devSpheres;
    devWorld.spheresSize = static_cast<int>(world->spheres.size());
    devWorld.triangles = devTriangles;
    devWorld.trianglesSize = static_cast<int>(world->triangles.size());
    devWorld.quadrilaterals = devQuadrilaterals;
    devWorld.quadrilateralsSize = static_cast<int>(world->quadrilaterals.size());
    devWorld.meshes = devMeshes;
    devWorld.meshesSize = static_cast<int>(world->meshes.size());
    devWorld.lights = devLights;
    devWorld.lightsSize = static_cast<int>(world->lights.size());
    devWorld.materials = devMaterials;
    devWorld.materialsSize = static_cast<int>(world->materials.size());
    devWorld.textures = devTextures;
    devWorld.texturesSize = static_cast<int>(world->textures.size());
    devWorld.texturePixels = devTexturePixels;
    devWorld.texturePixelsSize = static_cast<int>(world->texturePixels.size());
    devWorld.bvhNodes = devBVHNodes;
    devWorld.bvhNodesSize = static_cast<int>(bvhNodes.size());
    devWorld.bvhTriangleIndices = devBVHTriangleIndices;
    devWorld.bvhTriangleIndicesSize = static_cast<int>(bvhTriangleIndices.size());

    const bool copiesSucceeded =
        CopyVectorToDevice(devVertices, world->vertices, "devVertices") &&
        CopyVectorToDevice(devSpheres, world->spheres, "devSpheres") &&
        CopyVectorToDevice(devTriangles, world->triangles, "devTriangles") &&
        CopyVectorToDevice(devQuadrilaterals, world->quadrilaterals, "devQuadrilaterals") &&
        CopyVectorToDevice(devMeshes, world->meshes, "devMeshes") &&
        CopyVectorToDevice(devLights, world->lights, "devLights") &&
        CopyVectorToDevice(devMaterials, world->materials, "devMaterials") &&
        CopyVectorToDevice(devTextures, world->textures, "devTextures") &&
        CopyVectorToDevice(devTexturePixels, world->texturePixels, "devTexturePixels") &&
        CopyVectorToDevice(devBVHNodes, bvhNodes, "devBVHNodes") &&
        CopyVectorToDevice(devBVHTriangleIndices, bvhTriangleIndices, "devBVHTriangleIndices");
    if (!copiesSucceeded)
    {
        printf("Renderer::Init failed while uploading scene data.\n");
        ReleaseHostPixels(this);
        ReleaseDeviceResources(this);
        return;
    }

    const cudaError_t worldCopyError = cudaMemcpyToSymbol(DevWorld, &devWorld, sizeof(DeviceWorld));
    if (worldCopyError != cudaSuccess)
    {
        printf("cudaMemcpyToSymbol DevWorld failed with error \"%s\".\n", cudaGetErrorString(worldCopyError));
        ReleaseHostPixels(this);
        ReleaseDeviceResources(this);
        return;
    }

    initialized = true;
    timer = GetTime();
}

void Renderer::Tick(float deltaTime)
{
    (void)deltaTime;
    if (!initialized || pixelsData == nullptr || devRandStates == nullptr || devRadiometry == nullptr || devPixels == nullptr)
    {
        return;
    }

    Camera* camera = GetCamera();
    if (camera == nullptr)
    {
        return;
    }

    const int pixelCount = width * height;
    const size_t pixelBytes = static_cast<size_t>(pixelCount) * 4;
    const dim3 blockDim(RenderBlockWidth, RenderBlockHeight, 1);
    const dim3 gridDim(static_cast<unsigned int>((width + RenderBlockWidth - 1) / RenderBlockWidth),
        static_cast<unsigned int>((height + RenderBlockHeight - 1) / RenderBlockHeight), 1);

    const Quaternion cameraQuaternion = camera->worldRotation.Quaternion();
    const Matrix4 cameraMatrix = cameraQuaternion.RotationMatrix();

    uint8_t* outputPixels = devPixels;
    bool interopMapped = false;
    if (IsGraphicsInteropEnabled())
    {
        const cudaError_t mapError = cudaGraphicsMapResources(1, &cudaPixelBufferResource, 0);
        if (mapError == cudaSuccess)
        {
            void* mappedPointer = nullptr;
            size_t mappedBytes = 0;
            const cudaError_t pointerError = cudaGraphicsResourceGetMappedPointer(&mappedPointer, &mappedBytes, cudaPixelBufferResource);
            if (pointerError == cudaSuccess && mappedPointer != nullptr && mappedBytes >= pixelBytes)
            {
                outputPixels = static_cast<uint8_t*>(mappedPointer);
                interopMapped = true;
            }
            else
            {
                printf("cudaGraphicsResourceGetMappedPointer failed with error \"%s\".\n", cudaGetErrorString(pointerError));
                cudaGraphicsUnmapResources(1, &cudaPixelBufferResource, 0);
                graphicsInteropEnabled = false;
            }
        }
        else
        {
            printf("cudaGraphicsMapResources failed with error \"%s\".\n", cudaGetErrorString(mapError));
            graphicsInteropEnabled = false;
        }
    }

    KernelRayTrace<<<gridDim, blockDim>>>(devRandStates, devRadiometry, outputPixels, frame, width, height, sampleDepth, static_cast<int>(samplingMode), filterKernelSize,
        camera->focus, camera->worldLocation.x, camera->worldLocation.y, camera->worldLocation.z,
        cameraMatrix.elements[0], cameraMatrix.elements[1], cameraMatrix.elements[2],
        cameraMatrix.elements[4], cameraMatrix.elements[5], cameraMatrix.elements[6],
        cameraMatrix.elements[8], cameraMatrix.elements[9], cameraMatrix.elements[10],
        translateX, scaleX, translateY, scaleY);
    if (!CheckKernelLaunch("RayTrace"))
    {
        if (interopMapped)
        {
            const cudaError_t unmapError = cudaGraphicsUnmapResources(1, &cudaPixelBufferResource, 0);
            if (unmapError != cudaSuccess)
            {
                graphicsInteropEnabled = false;
            }
        }
        return;
    }

    if (filterKernelSize > 1)
    {
        KernelPixel<<<gridDim, blockDim>>>(filterKernelSize, devRadiometry, width, height, outputPixels);
        if (!CheckKernelLaunch("Pixel"))
        {
            if (interopMapped)
            {
                const cudaError_t unmapError = cudaGraphicsUnmapResources(1, &cudaPixelBufferResource, 0);
                if (unmapError != cudaSuccess)
                {
                    graphicsInteropEnabled = false;
                }
            }
            return;
        }
    }

    if (interopMapped)
    {
        const cudaError_t unmapError = cudaGraphicsUnmapResources(1, &cudaPixelBufferResource, 0);
        if (unmapError != cudaSuccess)
        {
            printf("cudaGraphicsUnmapResources failed with error \"%s\".\n", cudaGetErrorString(unmapError));
            graphicsInteropEnabled = false;
            return;
        }
    }
    else
    {
        const cudaError_t copyError = cudaMemcpy(pixelsData, devPixels, pixelBytes, cudaMemcpyDeviceToHost);
        if (copyError != cudaSuccess)
        {
            printf("cudaMemcpy pixels failed with error \"%s\".\n", cudaGetErrorString(copyError));
            return;
        }
    }

    frame++;
    const int64_t now = GetTime();
    frameTime = now - timer;
    timer = now;
}

void Renderer::Tick2(float deltaTime)
{
    Tick(deltaTime);
}

void Renderer::TestTick(float deltaTime)
{
    (void)deltaTime;
}

void Test()
{
}
