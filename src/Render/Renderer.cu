#include <Render/Renderer.h>
#include <cfloat>
#include <ctime>

__device__ static DeviceWorld DevWorld[1];

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
    Vector3 n = triangle->normal;
    float d = triangle->distance;
    float in = Dot(ray->direction, n);

    if (fabsf(in) < 1e-7f)
    {
        return false;
    }
    if (in > 0.0f)
    {
        if (!triangle->GetMaterial(DevWorld)->backVisible)
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
    Vector3 coordinate;
    if (!triangle->IncludeDetect(DevWorld, location, coordinate))
    {
        return false;
    }

    hitResult->isHit = true;
    hitResult->material = triangle->GetMaterial(DevWorld);
    hitResult->color = triangle->GetAlbedo(DevWorld, coordinate);
    hitResult->distance = distance;
    hitResult->location = location;
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

__device__ bool HitDetect(Mesh* mesh, Ray* ray, RayHitResult* hitResult)
{
    float oldDistance = hitResult->distance;
    for (int i = mesh->tFacesIdx; i < mesh->tFacesIdx + mesh->tFacesSize; i++)
    {
        HitDetect(DevWorld->triangles + i, ray, hitResult);
    }
    for (int i = mesh->qFacesIdx; i < mesh->qFacesIdx + mesh->qFacesSize; i++)
    {
        HitDetect(DevWorld->quadrilaterals + i, ray, hitResult);
    }
    return hitResult->distance < oldDistance;
}

__device__ void WorldHitDetect(Ray* ray, RayHitResult* hitResult)
{
    for (int i = 0; i < DevWorld->spheresSize; i++)
    {
        HitDetect(DevWorld->spheres + i, ray, hitResult);
    }
    for (int i = 0; i < DevWorld->trianglesSize; i++)
    {
        HitDetect(DevWorld->triangles + i, ray, hitResult);
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

__device__ bool DirectLightSample(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, Sphere* light, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    Vector3 exiting = WeightedSampleSphereLight(state, hitResult->location, light->worldLocation, light->radius);
    if (Dot(hitResult->normal, exiting) < 0.0f)
    {
        return false;
    }

    Ray sampleRay(hitResult->location, exiting);
    RayHitResult sampleHitResult;
    WorldHitDetect(&sampleRay, &sampleHitResult);
    if (!sampleHitResult.isHit || sampleHitResult.objectId != light->id)
    {
        return false;
    }

    float cosin = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    if (cosin <= 0.0f || cosout <= 0.0f)
    {
        return false;
    }

    Vector3 h = (incident + exiting).GetNormalized();
    float f = SchlickFresnel(1.0f, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, hitResult->material->roughness);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, hitResult->material->roughness);
    sampleResult->brdf = hitResult->color * (1.0f / PI) + Vector3(1.0f, 1.0f, 1.0f) * ((f * d * g) / (4.0f * cosin * cosout));

    float dist = (light->worldLocation - hitResult->location).Length();
    if (dist <= light->radius)
    {
        return false;
    }
    float cosa = sqrtf(Max(0.0f, 1.0f - (light->radius * light->radius) / (dist * dist)));
    Vector3 v1 = (light->worldLocation - hitResult->location).GetNormalized();
    Vector3 delta = sampleHitResult.location - hitResult->location;
    float sampleDistance = delta.Length();
    if (sampleDistance <= 0.0f)
    {
        return false;
    }
    Vector3 v2 = delta / sampleDistance;
    sampleResult->pdf = 1.0f / (2.0f * PI * (1.0f - cosa)) * Dot(v1, v2) / sampleDistance;
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 20.0f;
    sampleResult->attenuation = hitDist > 1.0f ? hitDist * hitDist : 1.0f;
    return sampleResult->pdf > 0.0f;
}

__device__ bool IndirectLightSampleRandom(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    Vector3 exiting = WeightedSampleRandom(state, hitResult->normal);
    if (Dot(hitResult->normal, exiting) <= 0.0f)
    {
        return false;
    }

    Vector3 h = (incident + exiting).GetNormalized();
    float cosine = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    if (cosine <= 0.0f || cosout <= 0.0f)
    {
        return false;
    }

    float a = hitResult->material->roughness;
    float f = SchlickFresnel(1.0f, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, a);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, a);
    sampleResult->brdf = hitResult->color * (1.0f / PI) + Vector3(1.0f, 1.0f, 1.0f) * ((f * d * g) / (4.0f * cosine * cosout));
    sampleResult->pdf = 1.0f / (2.0f * PI);
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 10.0f;
    sampleResult->attenuation = hitDist > 1.0f ? hitDist * hitDist : 1.0f;

    ray->location = hitResult->location;
    ray->direction = exiting;
    return true;
}

__device__ bool IndirectLightSampleCosine(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    Vector3 exiting = WeightedSampleCosine(state, hitResult->normal);
    if (Dot(hitResult->normal, exiting) <= 0.0f)
    {
        return false;
    }

    Vector3 h = (incident + exiting).GetNormalized();
    float cosine = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    if (cosine <= 0.0f || cosout <= 0.0f)
    {
        return false;
    }

    float a = hitResult->material->roughness;
    float f = SchlickFresnel(1.0f, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, a);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, a);
    sampleResult->brdf = hitResult->color * (1.0f / PI) + Vector3(1.0f, 1.0f, 1.0f) * ((f * d * g) / (4.0f * cosine * cosout));
    sampleResult->pdf = cosout / PI;
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 10.0f;
    sampleResult->attenuation = hitDist > 1.0f ? hitDist * hitDist : 1.0f;

    ray->location = hitResult->location;
    ray->direction = exiting;
    return true;
}

__device__ bool IndirectLightSampleGGX(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    float a = hitResult->material->roughness;
    Vector3 h = WeightedSampleGGX(state, hitResult->normal, a);
    Vector3 exiting = Reflect(h, incident);
    if (Dot(hitResult->normal, exiting) <= 0.0f)
    {
        return false;
    }

    float cosine = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    if (cosine <= 0.0f || cosout <= 0.0f)
    {
        return false;
    }

    float f = SchlickFresnel(1.0f, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, a);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, a);
    sampleResult->brdf = hitResult->color * (1.0f / PI) + Vector3(1.0f, 1.0f, 1.0f) * ((f * d * g) / (4.0f * cosine * cosout));
    sampleResult->pdf = d * Dot(hitResult->normal, h);
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 10.0f;
    sampleResult->attenuation = hitDist > 1.0f ? hitDist * hitDist : 1.0f;

    ray->location = hitResult->location;
    ray->direction = exiting;
    return sampleResult->pdf > 0.0f;
}

__device__ Vector3 FullPathRayTrace(curandStateXORWOW_t* state, Ray* ray)
{
    Vector3 attenuation(1.0f, 1.0f, 1.0f);

    for (int i = 0; i < 16; i++)
    {
        RayHitResult hit;
        WorldHitDetect(ray, &hit);
        if (!hit.isHit)
        {
            //edit
            return Vector3(0.0f, 0.0f, 0.0f);
        }
        if (hit.material != nullptr && hit.material->isEmit)
        {
            return hit.material->emit * hit.material->intensity * attenuation;
        }

        RaySampleResult sampleResult;
        if (!IndirectLightSampleRandom(state, ray, &hit, &sampleResult) || sampleResult.pdf <= 0.0f)
        {
            return Vector3(0.0f, 0.0f, 0.0f);
        }

        ray->depth++;
        attenuation = attenuation * sampleResult.brdf * sampleResult.cosine / sampleResult.pdf / sampleResult.attenuation;
    }

    return Vector3(0.0f, 0.0f, 0.0f);
}

__global__ void KernelRayTrace(curandStateXORWOW_t* states, Ray* rays, float* radiants, int sampleCount, int pixelCount)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    if (idx >= pixelCount)
    {
        return;
    }

    Vector3 color = FullPathRayTrace(states + idx, rays + idx);
    float* radiant = radiants + idx * 4;
    float c1 = static_cast<float>(sampleCount) / static_cast<float>(sampleCount + 1);
    float c2 = 1.0f / static_cast<float>(sampleCount + 1);
    radiant[0] = c1 * radiant[0] + c2 * color.x;
    radiant[1] = c1 * radiant[1] + c2 * color.y;
    radiant[2] = c1 * radiant[2] + c2 * color.z;
    radiant[3] = 1.0f;
}

__global__ void KernelInitRay(curandStateXORWOW_t* states, Ray* rays, Camera* camera, int width, int pixelCount, float translateX, float scaleX, float translateY, float scaleY)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    if (idx >= pixelCount)
    {
        return;
    }

    int x = idx % width;
    int y = idx / width;
    Vector3 camDirection(((x + DevRand(states + idx)) + translateX) * scaleX, ((y + DevRand(states + idx)) + translateY) * scaleY, camera->focus);
    camDirection.Normalize();
    rays[idx] = Ray(camera->worldLocation, camera->worldRotation.Rotate(camDirection));
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
    color = AcesFilm(color);
    dst[idx * 4 + 0] = static_cast<uint8_t>(Clamp(color.x, 0.0f, 1.0f) * 255.0f);
    dst[idx * 4 + 1] = static_cast<uint8_t>(Clamp(color.y, 0.0f, 1.0f) * 255.0f);
    dst[idx * 4 + 2] = static_cast<uint8_t>(Clamp(color.z, 0.0f, 1.0f) * 255.0f);
    dst[idx * 4 + 3] = 255;
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

Renderer::~Renderer()
{
    delete[] pixelsData;
    pixelsData = nullptr;

    cudaFree(devRandStates);
    cudaFree(devCamera);
    cudaFree(devVertices);
    cudaFree(devSpheres);
    cudaFree(devTriangles);
    cudaFree(devQuadrilaterals);
    cudaFree(devMeshes);
    cudaFree(devLights);
    cudaFree(devMaterials);
    cudaFree(devTextures);
    cudaFree(devTexturePixels);
    cudaFree(devRays);
    cudaFree(devHitResults);
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

    CudaAlloc(&devRandStates, pixelCount, "devRandStates");
    CudaAlloc(&devCamera, 1, "devCamera");
    CudaAlloc(&devVertices, GetWorld()->vertices.size(), "devVertices");
    CudaAlloc(&devSpheres, GetWorld()->spheres.size(), "devSpheres");
    CudaAlloc(&devTriangles, GetWorld()->triangles.size(), "devTriangles");
    CudaAlloc(&devQuadrilaterals, GetWorld()->quadrilaterals.size(), "devQuadrilaterals");
    CudaAlloc(&devMeshes, GetWorld()->meshes.size(), "devMeshes");
    CudaAlloc(&devLights, GetWorld()->lights.size(), "devLights");
    CudaAlloc(&devMaterials, GetWorld()->materials.size(), "devMaterials");
    CudaAlloc(&devTextures, GetWorld()->textures.size(), "devTextures");
    CudaAlloc(&devTexturePixels, GetWorld()->texturePixels.size(), "devTexturePixels");
    CudaAlloc(&devRays, pixelCount, "devRays");
    CudaAlloc(&devHitResults, pixelCount, "devHitResults");
    CudaAlloc(&devRadiometry, static_cast<size_t>(pixelCount) * 4, "devRadiometry");
    CudaAlloc(&devPixels, static_cast<size_t>(pixelCount) * 4, "devPixels");

    InitRandStates<<<gridDim, blockDim>>>(devRandStates, static_cast<unsigned long long>(time(nullptr)));
    if (cudaError_t error = cudaDeviceSynchronize())
    {
        printf("kernel InitRandStates failed with error \"%s\".\n", cudaGetErrorString(error));
    }

    if (devRadiometry != nullptr)
    {
        cudaMemset(devRadiometry, 0, sizeof(float) * static_cast<size_t>(pixelCount) * 4);
    }
    if (devPixels != nullptr)
    {
        cudaMemset(devPixels, 0, sizeof(uint8_t) * static_cast<size_t>(pixelCount) * 4);
    }

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

    cudaMemcpyToSymbol(DevWorld, &devWorld, sizeof(DeviceWorld));
    CopyVectorToDevice(devVertices, GetWorld()->vertices, "devVertices");
    CopyVectorToDevice(devSpheres, GetWorld()->spheres, "devSpheres");
    CopyVectorToDevice(devTriangles, GetWorld()->triangles, "devTriangles");
    CopyVectorToDevice(devQuadrilaterals, GetWorld()->quadrilaterals, "devQuadrilaterals");
    CopyVectorToDevice(devMeshes, GetWorld()->meshes, "devMeshes");
    CopyVectorToDevice(devLights, GetWorld()->lights, "devLights");
    CopyVectorToDevice(devMaterials, GetWorld()->materials, "devMaterials");
    CopyVectorToDevice(devTextures, GetWorld()->textures, "devTextures");
    CopyVectorToDevice(devTexturePixels, GetWorld()->texturePixels, "devTexturePixels");
    cudaMemcpy(devCamera, GetCamera(), sizeof(Camera), cudaMemcpyHostToDevice);

    frame = 0;
    timer = GetTime();
}

void Renderer::Tick(float deltaTime)
{
    (void)deltaTime;
    if (pixelsData == nullptr || devRays == nullptr || devRadiometry == nullptr || devPixels == nullptr)
    {
        return;
    }

    const int pixelCount = width * height;
    dim3 blockDim(devThreadNum, 1);
    dim3 gridDim((pixelCount + devThreadNum - 1) / devThreadNum, 1);

    cudaMemcpy(devCamera, GetCamera(), sizeof(Camera), cudaMemcpyHostToDevice);

    KernelInitRay<<<gridDim, blockDim>>>(devRandStates, devRays, devCamera, width, pixelCount, translateX, scaleX, translateY, scaleY);
    if (cudaError_t error = cudaDeviceSynchronize())
    {
        printf("kernel InitRay failed with error \"%s\".\n", cudaGetErrorString(error));
        return;
    }

    KernelRayTrace<<<gridDim, blockDim>>>(devRandStates, devRays, devRadiometry, frame, pixelCount);
    if (cudaError_t error = cudaDeviceSynchronize())
    {
        printf("kernel RayTrace failed with error \"%s\".\n", cudaGetErrorString(error));
        return;
    }

    KernelPixel<<<gridDim, blockDim>>>(filterKernelSize, devRadiometry, width, height, devPixels);
    if (cudaError_t error = cudaDeviceSynchronize())
    {
        printf("kernel Pixel failed with error \"%s\".\n", cudaGetErrorString(error));
        return;
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
