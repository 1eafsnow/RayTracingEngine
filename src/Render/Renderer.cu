#include <Render/Renderer.h>
#include <algorithm>
#include <cfloat>
#include <ctime>
#include <limits>
#include <vector>

__device__ static DeviceWorld DevWorld[1];

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

        Vector3 a = world->vertices[triangle.vertexIdx[0]].worldLocation;
        Vector3 b = world->vertices[triangle.vertexIdx[1]].worldLocation;
        Vector3 c = world->vertices[triangle.vertexIdx[2]].worldLocation;

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

__device__ bool HitAABB(const BVHNode& node, const Ray* ray, float maxDistance)
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

__device__ bool HitDetect(Sphere* sphere, Ray* ray, RayHitResult* hitResult)
{
    Vector3 oc = ray->location - sphere->worldLocation;
    float a = Dot(ray->direction, ray->direction);
    float b = 2.0f * Dot(oc, ray->direction);
    float c = Dot(oc, oc) - sphere->radius * sphere->radius;
    float discriminant = b * b - 4.0f * a * c;
    if (discriminant < 0.0f)
    {
        return false;
    }

    float sqrtD = sqrtf(discriminant);
    float denominator = 2.0f * a;
    float distance = (-b - sqrtD) / denominator;
    if (distance < MIN_DETECT_DISTANCE)
    {
        distance = (-b + sqrtD) / denominator;
    }
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->distance = distance;
    hitResult->location = ray->location + ray->direction * distance;
    hitResult->normal = sphere->GetNormal(DevWorld, hitResult->location);
    hitResult->material = sphere->GetMaterial(DevWorld);
    hitResult->color = hitResult->material->albedo;
    hitResult->objectId = sphere->id;
    return true;
}

__device__ bool HitDetect(Triangle* triangle, Ray* ray, RayHitResult* hitResult)
{
    Material* material = triangle->GetMaterial(DevWorld);
    const float facing = Dot(ray->direction, triangle->normal);
    if (fabsf(facing) < 1e-7f || (facing > 0.0f && !material->backVisible))
    {
        return false;
    }

    Vector3 a = DevWorld->vertices[triangle->vertexIdx[0]].worldLocation;
    Vector3 b = DevWorld->vertices[triangle->vertexIdx[1]].worldLocation;
    Vector3 c = DevWorld->vertices[triangle->vertexIdx[2]].worldLocation;
    Vector3 edge1 = b - a;
    Vector3 edge2 = c - a;
    Vector3 p = Cross(ray->direction, edge2);
    float determinant = Dot(edge1, p);
    if (fabsf(determinant) < 1e-8f)
    {
        return false;
    }

    float invDeterminant = 1.0f / determinant;
    Vector3 t = ray->location - a;
    float u = Dot(t, p) * invDeterminant;
    if (u < 0.0f || u > 1.0f)
    {
        return false;
    }

    Vector3 q = Cross(t, edge1);
    float v = Dot(ray->direction, q) * invDeterminant;
    if (v < 0.0f || u + v > 1.0f)
    {
        return false;
    }

    float distance = Dot(edge2, q) * invDeterminant;
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    Vector3 coordinate(1.0f - u - v, u, v);
    hitResult->isHit = true;
    hitResult->material = material;
    hitResult->color = triangle->GetAlbedo(DevWorld, coordinate);
    hitResult->distance = distance;
    hitResult->location = ray->location + ray->direction * distance;
    hitResult->normal = triangle->GetNormal(DevWorld, coordinate).GetNormalized();
    hitResult->objectId = triangle->id;
    return true;
}

__device__ bool HitDetect(Quadrilateral* quadrilateral, Ray* ray, RayHitResult* hitResult)
{
    Vector3 n = quadrilateral->normal;
    float d = quadrilateral->distance;
    float in = Dot(ray->direction, n);

    if (fabsf(in) < 1e-7f)
    {
        return false;
    }
    if (in > 0.0f)
    {
        if (!quadrilateral->GetMaterial(DevWorld)->backVisible)
        {
            return false;
        }
        n = -n;
        in = -in;
        d = -d;
    }

    float distance = -(Dot(ray->location, n) + d) / in;
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    Vector3 location = ray->location + ray->direction * distance;
    if (!quadrilateral->IncludeDetect(DevWorld, location))
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->material = quadrilateral->GetMaterial(DevWorld);
    hitResult->color = hitResult->material->albedo;
    hitResult->distance = distance;
    hitResult->location = location;
    hitResult->normal = n;
    hitResult->objectId = quadrilateral->id;
    return true;
}

__device__ void WorldHitDetect(Ray* ray, RayHitResult* hitResult)
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

__device__ bool EvaluateBRDF(RayHitResult* hitResult, const Vector3& incident, const Vector3& exiting, Vector3* brdf)
{
    Vector3 normal = hitResult->normal.GetNormalized();
    float NoV = Dot(normal, incident);
    float NoL = Dot(normal, exiting);
    if (NoV <= 0.0f || NoL <= 0.0f || hitResult->material == nullptr)
    {
        return false;
    }

    Vector3 halfVectorRaw = incident + exiting;
    float halfLengthSquared = Dot(halfVectorRaw, halfVectorRaw);
    if (halfLengthSquared <= 1e-12f)
    {
        return false;
    }

    Vector3 h = halfVectorRaw / sqrtf(halfLengthSquared);
    float VoH = Max(Dot(incident, h), 0.0f);
    if (VoH <= 0.0f)
    {
        return false;
    }

    float roughness = Clamp(hitResult->material->roughness, 0.001f, 1.0f);
    float fresnel = SchlickFresnel(1.0f, hitResult->material->refractionIndex, h, incident);
    float distribution = NDF_GGX(normal, h, roughness);
    float geometry = GF_SmithJointGGX(normal, incident, exiting, roughness);

    Vector3 diffuse = hitResult->color * ((1.0f - fresnel) / PI);
    float specularScale = fresnel * distribution * geometry / Max(4.0f * NoV * NoL, 1e-8f);
    Vector3 specular(specularScale, specularScale, specularScale);
    *brdf = diffuse + specular;
    return true;
}

__device__ bool DirectLightSample(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, Sphere* light, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    Vector3 exiting = WeightedSampleSphereLight(state, hitResult->location, light->worldLocation, light->radius);
    float cosout = Dot(hitResult->normal, exiting);
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

    float dist = (light->worldLocation - hitResult->location).Length();
    if (dist <= light->radius)
    {
        return false;
    }

    float sinThetaMax2 = Clamp((light->radius * light->radius) / (dist * dist), 0.0f, 1.0f);
    float cosThetaMax = sqrtf(Max(0.0f, 1.0f - sinThetaMax2));
    sampleResult->pdf = 1.0f / Max(2.0f * PI * (1.0f - cosThetaMax), 1e-8f);
    sampleResult->cosine = cosout;
    sampleResult->attenuation = 1.0f;
    return true;
}

__device__ bool IndirectLightSampleRandom(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    Vector3 exiting = WeightedSampleRandom(state, hitResult->normal);
    float cosout = Dot(hitResult->normal, exiting);
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

__device__ bool IndirectLightSampleCosine(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    Vector3 exiting = WeightedSampleCosine(state, hitResult->normal);
    float cosout = Dot(hitResult->normal, exiting);
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

__device__ bool IndirectLightSampleGGX(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    float roughness = Clamp(hitResult->material->roughness, 0.001f, 1.0f);
    Vector3 h = WeightedSampleGGX(state, hitResult->normal, roughness);
    float VoH = Dot(incident, h);
    if (VoH <= 0.0f)
    {
        return false;
    }

    Vector3 exiting = Reflect(h, incident);
    float cosout = Dot(hitResult->normal, exiting);
    if (cosout <= 0.0f)
    {
        return false;
    }

    if (!EvaluateBRDF(hitResult, incident, exiting, &sampleResult->brdf))
    {
        return false;
    }

    float NoH = Max(Dot(hitResult->normal, h), 0.0f);
    float distribution = NDF_GGX(hitResult->normal, h, roughness);
    float halfVectorPdf = distribution * NoH;
    sampleResult->pdf = halfVectorPdf / Max(4.0f * VoH, 1e-8f);
    sampleResult->cosine = cosout;
    sampleResult->attenuation = 1.0f;
    ray->location = hitResult->location + hitResult->normal * (MIN_DETECT_DISTANCE * 2.0f);
    ray->direction = exiting;
    return sampleResult->pdf > 0.0f;
}

__device__ bool IndirectLightSample(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult, int sampleMode)
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

__device__ Vector3 FullPathRayTrace(curandStateXORWOW_t* state, Ray* ray, int sampleDepth, int sampleMode)
{
    Vector3 throughput(1.0f, 1.0f, 1.0f);
    int maxDepth = Max(sampleDepth, 1);

    for (int i = 0; i < maxDepth; i++)
    {
        RayHitResult hit;
        WorldHitDetect(ray, &hit);
        if (!hit.isHit)
        {
            return Vector3(0.0f, 0.0f, 0.0f);
        }
        if (hit.material != nullptr && hit.material->isEmit)
        {
            return hit.material->emit * hit.material->intensity * throughput;
        }

        RaySampleResult sampleResult;
        if (!IndirectLightSample(state, ray, &hit, &sampleResult, sampleMode) || sampleResult.pdf <= 0.0f)
        {
            return Vector3(0.0f, 0.0f, 0.0f);
        }

        throughput = throughput * sampleResult.brdf * (sampleResult.cosine / sampleResult.pdf);
        ray->depth++;

        if (i >= 3)
        {
            float survivalProbability = Clamp(Max(throughput.x, Max(throughput.y, throughput.z)), 0.05f, 0.95f);
            if (DevRandOpen(state) > survivalProbability)
            {
                return Vector3(0.0f, 0.0f, 0.0f);
            }
            throughput = throughput / survivalProbability;
        }
    }

    return Vector3(0.0f, 0.0f, 0.0f);
}

__device__ void StoreToneMappedPixel(uint8_t* pixels, int idx, const Vector3& linearColor)
{
    Vector3 color = AcesFilm(linearColor);
    pixels[idx * 4 + 0] = static_cast<uint8_t>(Clamp(color.x, 0.0f, 1.0f) * 255.0f);
    pixels[idx * 4 + 1] = static_cast<uint8_t>(Clamp(color.y, 0.0f, 1.0f) * 255.0f);
    pixels[idx * 4 + 2] = static_cast<uint8_t>(Clamp(color.z, 0.0f, 1.0f) * 255.0f);
    pixels[idx * 4 + 3] = 255;
}

__global__ void KernelRayTrace(curandStateXORWOW_t* states, float* radiants, uint8_t* pixels, int sampleCount, int width, int height, int sampleDepth, int sampleMode, int filterKernelSize, float cameraFocus, float cameraX, float cameraY, float cameraZ, float cameraYaw, float cameraPitch, float cameraRoll, float translateX, float scaleX, float translateY, float scaleY)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    int pixelCount = width * height;
    if (idx >= pixelCount)
    {
        return;
    }

    int x = idx % width;
    int y = idx / width;
    Vector3 camDirection(((x + DevRand(states + idx)) + translateX) * scaleX, ((y + DevRand(states + idx)) + translateY) * scaleY, cameraFocus);
    camDirection.Normalize();

    Rotator cameraRotation(cameraYaw, cameraPitch, cameraRoll);
    Ray ray(Vector3(cameraX, cameraY, cameraZ), cameraRotation.Rotate(camDirection));
    Vector3 color = FullPathRayTrace(states + idx, &ray, sampleDepth, sampleMode);

    float* radiant = radiants + idx * 4;
    float c1 = static_cast<float>(sampleCount) / static_cast<float>(sampleCount + 1);
    float c2 = 1.0f / static_cast<float>(sampleCount + 1);
    radiant[0] = c1 * radiant[0] + c2 * color.x;
    radiant[1] = c1 * radiant[1] + c2 * color.y;
    radiant[2] = c1 * radiant[2] + c2 * color.z;
    radiant[3] = 1.0f;

    if (filterKernelSize <= 1)
    {
        StoreToneMappedPixel(pixels, idx, Vector3(radiant[0], radiant[1], radiant[2]));
    }
}

__global__ void KernelPixel(int kernelSize, float* src, int width, int height, uint8_t* dst)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    int pixelCount = width * height;
    if (idx >= pixelCount)
    {
        return;
    }

    int x = idx % width;
    int y = idx / width;
    int offset = Max(kernelSize, 1) / 2;
    Vector3 color;
    int count = 0;

    for (int yy = Max(0, y - offset); yy <= Min(height - 1, y + offset); yy++)
    {
        for (int xx = Max(0, x - offset); xx <= Min(width - 1, x + offset); xx++)
        {
            int sourceIdx = (yy * width + xx) * 4;
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
    if (count == 0)
    {
        *ptr = nullptr;
        return true;
    }

    cudaError_t error = cudaMalloc(reinterpret_cast<void**>(ptr), sizeof(T) * count);
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

    cudaError_t error = cudaMemcpy(dst, src.data(), sizeof(T) * src.size(), cudaMemcpyHostToDevice);
    if (error != cudaSuccess)
    {
        printf("cudaMemcpy %s failed with error \"%s\".\n", name, cudaGetErrorString(error));
        return false;
    }
    return true;
}

static bool CheckKernelLaunch(const char* name)
{
    cudaError_t error = cudaGetLastError();
    if (error != cudaSuccess)
    {
        printf("kernel %s launch failed with error \"%s\".\n", name, cudaGetErrorString(error));
        return false;
    }
    return true;
}

Renderer::~Renderer()
{
    delete[] pixelsData;
    pixelsData = nullptr;

    cudaFree(devRandStates);
    cudaFree(devVertices);
    cudaFree(devSpheres);
    cudaFree(devTriangles);
    cudaFree(devQuadrilaterals);
    cudaFree(devMeshes);
    cudaFree(devLights);
    cudaFree(devMaterials);
    cudaFree(devTextures);
    cudaFree(devTexturePixels);
    cudaFree(devBVHNodes);
    cudaFree(devBVHTriangleIndices);
    cudaFree(devRadiometry);
    cudaFree(devPixels);
}

void Renderer::Init()
{
    if (width <= 0 || height <= 0)
    {
        printf("Renderer::Init failed: invalid resolution %d x %d.\n", width, height);
        return;
    }
    if (devThreadNum <= 0)
    {
        devThreadNum = 256;
    }

    const int pixelCount = width * height;
    dim3 blockDim(devThreadNum, 1);
    dim3 gridDim((pixelCount + devThreadNum - 1) / devThreadNum, 1);

    float left = GetCamera()->focus * -tanf(GetCamera()->fovX * PI / 180.0f / 2.0f);
    float right = GetCamera()->focus * tanf(GetCamera()->fovX * PI / 180.0f / 2.0f);
    float top = GetCamera()->focus * tanf(GetCamera()->fovY * PI / 180.0f / 2.0f);
    float bottom = GetCamera()->focus * -tanf(GetCamera()->fovY * PI / 180.0f / 2.0f);

    translateX = -static_cast<float>(width) / 2.0f;
    translateY = -static_cast<float>(height) / 2.0f;
    scaleX = (right - left) / static_cast<float>(width);
    scaleY = (top - bottom) / static_cast<float>(height);

    pixelsData = new uint8_t[static_cast<size_t>(pixelCount) * 4]{};

    std::vector<BVHNode> bvhNodes;
    std::vector<int> bvhTriangleIndices;
    BuildTriangleBVH(GetWorld(), bvhNodes, bvhTriangleIndices);

    CudaAlloc(&devRandStates, pixelCount, "devRandStates");
    CudaAlloc(&devVertices, GetWorld()->vertices.size(), "devVertices");
    CudaAlloc(&devSpheres, GetWorld()->spheres.size(), "devSpheres");
    CudaAlloc(&devTriangles, GetWorld()->triangles.size(), "devTriangles");
    CudaAlloc(&devQuadrilaterals, GetWorld()->quadrilaterals.size(), "devQuadrilaterals");
    CudaAlloc(&devMeshes, GetWorld()->meshes.size(), "devMeshes");
    CudaAlloc(&devLights, GetWorld()->lights.size(), "devLights");
    CudaAlloc(&devMaterials, GetWorld()->materials.size(), "devMaterials");
    CudaAlloc(&devTextures, GetWorld()->textures.size(), "devTextures");
    CudaAlloc(&devTexturePixels, GetWorld()->texturePixels.size(), "devTexturePixels");
    CudaAlloc(&devBVHNodes, bvhNodes.size(), "devBVHNodes");
    CudaAlloc(&devBVHTriangleIndices, bvhTriangleIndices.size(), "devBVHTriangleIndices");
    CudaAlloc(&devRadiometry, static_cast<size_t>(pixelCount) * 4, "devRadiometry");
    CudaAlloc(&devPixels, static_cast<size_t>(pixelCount) * 4, "devPixels");

    InitRandStates<<<gridDim, blockDim>>>(devRandStates, static_cast<unsigned long long>(time(nullptr)), pixelCount);
    if (!CheckKernelLaunch("InitRandStates") || cudaDeviceSynchronize() != cudaSuccess)
    {
        printf("Renderer::Init failed while initializing random states.\n");
        return;
    }

    cudaMemset(devRadiometry, 0, sizeof(float) * static_cast<size_t>(pixelCount) * 4);
    cudaMemset(devPixels, 0, sizeof(uint8_t) * static_cast<size_t>(pixelCount) * 4);

    devWorld.vertices = devVertices;
    devWorld.verticesSize = static_cast<int>(GetWorld()->vertices.size());
    devWorld.spheres = devSpheres;
    devWorld.spheresSize = static_cast<int>(GetWorld()->spheres.size());
    devWorld.triangles = devTriangles;
    devWorld.trianglesSize = static_cast<int>(GetWorld()->triangles.size());
    devWorld.quadrilaterals = devQuadrilaterals;
    devWorld.quadrilateralsSize = static_cast<int>(GetWorld()->quadrilaterals.size());
    devWorld.meshes = devMeshes;
    devWorld.meshesSize = static_cast<int>(GetWorld()->meshes.size());
    devWorld.lights = devLights;
    devWorld.lightsSize = static_cast<int>(GetWorld()->lights.size());
    devWorld.materials = devMaterials;
    devWorld.materialsSize = static_cast<int>(GetWorld()->materials.size());
    devWorld.textures = devTextures;
    devWorld.texturesSize = static_cast<int>(GetWorld()->textures.size());
    devWorld.texturePixels = devTexturePixels;
    devWorld.texturePixelsSize = static_cast<int>(GetWorld()->texturePixels.size());
    devWorld.bvhNodes = devBVHNodes;
    devWorld.bvhNodesSize = static_cast<int>(bvhNodes.size());
    devWorld.bvhTriangleIndices = devBVHTriangleIndices;
    devWorld.bvhTriangleIndicesSize = static_cast<int>(bvhTriangleIndices.size());

    CopyVectorToDevice(devVertices, GetWorld()->vertices, "devVertices");
    CopyVectorToDevice(devSpheres, GetWorld()->spheres, "devSpheres");
    CopyVectorToDevice(devTriangles, GetWorld()->triangles, "devTriangles");
    CopyVectorToDevice(devQuadrilaterals, GetWorld()->quadrilaterals, "devQuadrilaterals");
    CopyVectorToDevice(devMeshes, GetWorld()->meshes, "devMeshes");
    CopyVectorToDevice(devLights, GetWorld()->lights, "devLights");
    CopyVectorToDevice(devMaterials, GetWorld()->materials, "devMaterials");
    CopyVectorToDevice(devTextures, GetWorld()->textures, "devTextures");
    CopyVectorToDevice(devTexturePixels, GetWorld()->texturePixels, "devTexturePixels");
    CopyVectorToDevice(devBVHNodes, bvhNodes, "devBVHNodes");
    CopyVectorToDevice(devBVHTriangleIndices, bvhTriangleIndices, "devBVHTriangleIndices");

    if (cudaError_t error = cudaMemcpyToSymbol(DevWorld, &devWorld, sizeof(DeviceWorld)))
    {
        printf("cudaMemcpyToSymbol DevWorld failed with error \"%s\".\n", cudaGetErrorString(error));
        return;
    }

    frame = 0;
    timer = GetTime();
}

void Renderer::Tick(float deltaTime)
{
    (void)deltaTime;
    if (pixelsData == nullptr || devRandStates == nullptr || devRadiometry == nullptr || devPixels == nullptr)
    {
        return;
    }

    const int pixelCount = width * height;
    dim3 blockDim(devThreadNum, 1);
    dim3 gridDim((pixelCount + devThreadNum - 1) / devThreadNum, 1);
    Camera* camera = GetCamera();

    KernelRayTrace<<<gridDim, blockDim>>>(devRandStates, devRadiometry, devPixels, frame, width, height, sampleDepth, static_cast<int>(indirectSampleMode), filterKernelSize,
        camera->focus, camera->worldLocation.x, camera->worldLocation.y, camera->worldLocation.z,
        camera->worldRotation.yaw, camera->worldRotation.pitch, camera->worldRotation.roll,
        translateX, scaleX, translateY, scaleY);
    if (!CheckKernelLaunch("RayTrace"))
    {
        return;
    }

    if (filterKernelSize > 1)
    {
        KernelPixel<<<gridDim, blockDim>>>(filterKernelSize, devRadiometry, width, height, devPixels);
        if (!CheckKernelLaunch("Pixel"))
        {
            return;
        }
    }

    if (cudaError_t error = cudaMemcpy(pixelsData, devPixels, sizeof(uint8_t) * static_cast<size_t>(pixelCount) * 4, cudaMemcpyDeviceToHost))
    {
        printf("cudaMemcpy pixels failed with error \"%s\".\n", cudaGetErrorString(error));
        return;
    }

    frame++;
    int64_t now = GetTime();
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