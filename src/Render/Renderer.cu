#include <Render/Renderer.h>
#include <assert.h>

__device__ static DeviceWorld DevWorld[1];

__device__ bool HitDetect(Sphere* sphere, Ray* ray, RayHitResult* hitResult)
{
    //int vertexIdx = sphere->vertexIdx * 3;
	//Vector3 vertexLocation(DevVertices[vertexIdx], DevVertices[vertexIdx + 1], DevVertices[vertexIdx + 2]);    
    Vector3 oc = ray->location - sphere->worldLocation;
    float a = Dot(ray->direction, ray->direction);
    float b = 2.0 * Dot(oc, ray->direction);
    float c = Dot(oc, oc) - sphere->radius * sphere->radius;
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
    hitResult->normal = sphere->GetNormal(DevWorld, hitResult->location);
    hitResult->material = sphere->GetMaterial(DevWorld);
    hitResult->color = hitResult->material->albedo;
	hitResult->objectId = sphere->id;
    /*
    if (Dot(ray.direction, GetNormal(result.location)) > -1e-6)
    {
        result.isHit = false;
    }
    */
    return true;
}

__device__ bool HitDetect(Triangle* triangle, Ray* ray, RayHitResult* hitResult)
{    
    Vector3 n = triangle->normal;
    float d = triangle->distance;
    float in = Dot(ray->direction, n);

    if (in == 0.0)
    {
        return false;
    }
    if (in > 0.0)
    {
        if (triangle->GetMaterial(DevWorld)->backVisible)
        {
            n = -n;
            in = -in;
            d = -d;
        }
        else
        {
            return false;
        }
    }

    float l = Dot(ray->location, n) + d;
    float distance = -l / in;
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
    hitResult->normal = triangle->GetNormal(DevWorld, coordinate);

    return true;
}

__device__ bool HitDetect(Quadrilateral* quadrilateral, Ray* ray, RayHitResult* hitResult)
{
    Vector3 n = quadrilateral->normal;
    float d = quadrilateral->distance;
    float in = Dot(ray->direction, n);

    if (in == 0.0)
    {
        return false;
    }
    if (in > 0.0)
    {
        if (quadrilateral->GetMaterial(DevWorld)->backVisible)
        {
            n = -n;
            in = -in;
            d = -d;
        }
        else
        {
            return false;
        }
    }

    float l = Dot(ray->location, n) + d;
    float distance = -l / in;
    if (distance < MIN_DETECT_DISTANCE || distance > hitResult->distance)
    {
        return false;
    }

    Vector3 location = ray->location + ray->direction * distance;
    Vector3 coordinate;

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

    return true;
}

__device__ bool HitDetect(Mesh* mesh, Ray* ray, RayHitResult* hitResult)
{
    for (int i = mesh->tFacesIdx; i < mesh->tFacesIdx + mesh->tFacesSize; i++)
    {
        HitDetect(DevWorld->triangles + i, ray, hitResult);
    }

    for (int i = mesh->qFacesIdx; i < mesh->qFacesIdx + mesh->qFacesSize; i++)
    {
        HitDetect(DevWorld->quadrilaterals + i, ray, hitResult);
    }
}

__device__ void WorldHitDetect(Ray* ray, RayHitResult* hitResult)
{
    for (int i = 0; i < DevWorld->spheresSize; i++)
    {
        //(DevWorld->spheres + i)->HitDetect(DevWorld, ray, hitResult);
        HitDetect(DevWorld->spheres + i, ray, hitResult);
    }

    for (int i = 0; i < DevWorld->trianglesSize; i++)
    {
        //(DevWorld->triangles + i)->HitDetect(DevWorld, ray, hitResult);
        HitDetect(DevWorld->triangles + i, ray, hitResult);
    }
    
    for (int i = 0; i < DevWorld->quadrilateralsSize; i++)
    {
        //(DevWorld->quadrilaterals + i)->HitDetect(DevWorld, ray, hitResult);
        HitDetect(DevWorld->quadrilaterals + i, ray, hitResult);
    }

    for (int i = 0; i < DevWorld->meshesSize; i++)
    {
        //(DevWorld->quadrilaterals + i)->HitDetect(DevWorld, ray, hitResult);
        HitDetect(DevWorld->meshes + i, ray, hitResult);
    }
    
    for (int i = 0; i < DevWorld->lightsSize; i++)
    {
        //(DevWorld->lights + i)->HitDetect(DevWorld, ray, hitResult);
        HitDetect(DevWorld->lights + i, ray, hitResult);
    }
}

__device__ bool DirectLightSample(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, Sphere* light, RaySampleResult* sampleResult)
{            
    //int vertexIdx = light->vertexIdx * 3;
    //Vector3 worldLocation(DevVertices[vertexIdx], DevVertices[vertexIdx + 1], DevVertices[vertexIdx + 2]);
    Vector3 incident = -ray->direction;
    /*
    if (Dot(incident, normal) < 0)
    {
        normal = -normal;
    }
    */
    
    Vector3 exiting = WeightedSampleSphereLight(state, hitResult->location, light->worldLocation, light->radius);
    //Vector3 exiting = (worldLocation - hitResult->location).GetNormalized();
    if (Dot(hitResult->normal, exiting) < 0)
    {
        return false;
    }
    
    Ray sampleRay(hitResult->location, exiting);
    RayHitResult sampleHitResult;
    WorldHitDetect(&sampleRay, &sampleHitResult);
    
    if (sampleHitResult.objectId != light->id)
    {
        return false;
    }
    
    float cosin = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    
    Vector3 h = (incident + exiting).GetNormalized();
    
    float f = SchlickFresnel(1.0, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, hitResult->material->roughness);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, hitResult->material->roughness);
    
    sampleResult->brdf = hitResult->color * (1 / PI) + Vector3(1, 1, 1) * ((f * d * g) / (4 * cosin * cosout));

    float dist = (light->worldLocation - hitResult->location).Length();
    float cosa = sqrt(1 - pow(light->radius / dist, 2));
    Vector3 v1 = (light->worldLocation - hitResult->location).GetNormalized();
    Vector3 v2 = (sampleHitResult.location - hitResult->location).GetNormalized();
    sampleResult->pdf = 1 / (2 * PI * (1 - cosa)) * Dot(v1, v2) / (sampleHitResult.location - hitResult->location).Length();
    sampleResult->cosine = cosout;
    float attenuation = 1;
    float hitDist = hitResult->distance / 20;
    sampleResult->attenuation = hitDist > 1 ? hitDist * hitDist : 1.0;
    return true;
}

__device__ Vector3 GetDirectLightColor(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult)
{
    Vector3 color;
    for (int i = 0; i < DevWorld->lightsSize; i++)
    {
        RaySampleResult sampleResult;

        if (DirectLightSample(state, ray, hitResult, DevWorld->lights + i, &sampleResult))
        {
            Material* material = (DevWorld->lights + i)->GetMaterial(DevWorld);
            color = color + material->emit * material->intensity * sampleResult.brdf * sampleResult.cosine / sampleResult.pdf / sampleResult.attenuation;
        }
    }
    return color;
}

__device__ bool IndirectLightSampleRandom(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    /*
    if (Dot(incident, normal) < 0)
    {
        normal = -normal;
    }
    */

    Vector3 exiting;
    Vector3 h;
    exiting = WeightedSampleRandom(state, hitResult->normal);
    h = ((incident + exiting) / 2).GetNormalized();
    if (Dot(hitResult->normal, exiting) <= 0.0)
    {
        return false;
    }
    float cosine = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    float a = hitResult->material->roughness;
    float f = SchlickFresnel(1.0, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, a);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, a);
    sampleResult->brdf = hitResult->color * (1 / PI) + Vector3(1, 1, 1) * ((f * d * g) / (4 * cosine * cosout));
    sampleResult->pdf = 1 / (2 * PI);
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 10;
    sampleResult->attenuation = hitDist > 1 ? hitDist * hitDist : 1.0;

    ray->location = hitResult->location;
    ray->direction = exiting;

    return true;
}

__device__ bool IndirectLightSampleCosine(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    /*
    if (Dot(incident, normal) < 0)
    {
        normal = -normal;
    }
    */

    Vector3 exiting;
    Vector3 h;
    exiting = WeightedSampleCosine(state, hitResult->normal);
    h = ((incident + exiting) / 2).GetNormalized();
    if (Dot(hitResult->normal, exiting) <= 0.0)
    {
        return false;
    }
    float cosine = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    float a = hitResult->material->roughness;
    float f = SchlickFresnel(1.0, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, a);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, a);
    sampleResult->brdf = hitResult->color * (1 / PI) + Vector3(1, 1, 1) * ((f * d * g) / (4 * cosine * cosout));
    sampleResult->pdf = cosout / PI;
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 10;
    sampleResult->attenuation = hitDist > 1 ? hitDist * hitDist : 1.0;

    ray->location = hitResult->location;
    ray->direction = exiting;

    return true;
}

__device__ bool IndirectLightSampleGGX(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult, RaySampleResult* sampleResult)
{
    Vector3 incident = -ray->direction;
    /*
    if (Dot(incident, normal) < 0)
    {
        normal = -normal;
    }
    */

    Vector3 exiting;
    Vector3 h;
    float a = hitResult->material->roughness;
    h = WeightedSampleGGX(state, hitResult->normal, a);
    exiting = Reflect(h, incident);
    if (Dot(hitResult->normal, exiting) <= 0.0)
    {
        return false;
    }
    float cosine = Dot(incident, hitResult->normal);
    float cosout = Dot(exiting, hitResult->normal);
    float f = SchlickFresnel(1.0, hitResult->material->refractionIndex, h, incident);
    float d = NDF_GGX(hitResult->normal, h, a);
    float g = GF_SchlickGGX(hitResult->normal, incident, exiting, a);
    sampleResult->brdf = hitResult->color * (1 / PI) + Vector3(1, 1, 1) * ((f * d * g) / (4 * cosine * cosout));
    sampleResult->pdf = d * Dot(hitResult->normal, h);
    sampleResult->cosine = cosout;
    float hitDist = hitResult->distance / 10;
    sampleResult->attenuation = hitDist > 1 ? hitDist * hitDist : 1.0;

    ray->location = hitResult->location;
    ray->direction = exiting;

    return true;
}

__device__ Vector3 DirectLightRayTrace(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult)
{   
    if (ray->depth == 2)
    {
        return Vector3(0, 0, 0);
    }

    ray->depth++;
    
    RayHitResult hit;

    WorldHitDetect(ray, &hit);

    if (!hit.isHit)
    {
        return Vector3(0, 0, 0);
    }
    if (hit.material->isEmit)
    {
        return Vector3(0, 0, 0);
    }
    Vector3 color;
    
    for (int i = 0; i < DevWorld->lightsSize; i++)
    {
        RaySampleResult dirSampleResult;

        if (DirectLightSample(state, ray, &hit, DevWorld->lights + i, &dirSampleResult))
        {
            color = color + (DevWorld->lights + i)->GetMaterial(DevWorld)->emit * (DevWorld->lights + i)->GetMaterial(DevWorld)->intensity * dirSampleResult.brdf * dirSampleResult.cosine / dirSampleResult.pdf / dirSampleResult.attenuation;
        }
    }    
    
    RaySampleResult indirSampleResult;
    if (IndirectLightSampleGGX(state, ray, &hit, &indirSampleResult))
    {                
        color = color + DirectLightRayTrace(state, ray, &hit) * indirSampleResult.brdf * indirSampleResult.cosine / indirSampleResult.pdf / indirSampleResult.attenuation;
    }
    
    return color;
}

__device__ Vector3 FullPathRayTrace(curandStateXORWOW_t* state, Ray* ray, RayHitResult* hitResult)
{
    Vector3 attenuation(1, 1, 1);

    for (int i = 0; i < 16; i++)
    {
        RayHitResult hit;
        WorldHitDetect(ray, &hit);

        if (!hit.isHit)
        {
            return Vector3(0, 0, 0);
        }

        if (hit.material->isEmit)
        {
            return hit.material->emit * hit.material->intensity * attenuation;
        }

        RaySampleResult indirSampleResult;
        if (!IndirectLightSampleRandom(state, ray, &hit, &indirSampleResult))
        {
            return Vector3(0, 0, 0);
        }
        
        ray->depth++;
        attenuation = attenuation * indirSampleResult.brdf * indirSampleResult.cosine / indirSampleResult.pdf / indirSampleResult.attenuation;
    }

    return Vector3(0, 0, 0);
}

__global__ void KernelRayTrace(curandStateXORWOW_t* states, Ray* rays, RayHitResult* hitResults, float* radiants, int sampleCount)
{    	
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    curandStateXORWOW_t* state = states + idx;
    Ray* ray = rays + idx;
    RayHitResult* hitResult = hitResults + idx;
    float* radiant = radiants + idx * 4;
    
    Vector3 color = FullPathRayTrace(state, ray, hitResult);

    float c1 = (float)sampleCount / (sampleCount + 1);
    float c2 = (float)1 / (sampleCount + 1);

    *(radiant + 0) = c1 * (*(radiant + 0)) + c2 * color.x;
    *(radiant + 1) = c1 * (*(radiant + 1)) + c2 * color.y;
    *(radiant + 2) = c1 * (*(radiant + 2)) + c2 * color.z;

    return;
}

__global__ void KernelInitRay(curandStateXORWOW_t* states, Ray* rays, Camera* camera, float translateX, float scaleX, float translateY, float scaleY)
{    
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
	int x = idx % 1280;
    int y = idx / 1280;

    Vector3 camDirection(((x + DevRand(states + idx)) + translateX) * scaleX, ((y + DevRand(states + idx)) + translateY) * scaleY, camera->focus);
    camDirection.Normalize();
    
    rays[idx] = Ray(camera->worldLocation, camera->worldRotation.Rotate(camDirection));	
}

__global__ void KernelInitHitResult(RayHitResult* hitResults)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    RayHitResult* hitResult = hitResults + idx;

    hitResult->isHit = false;
    hitResult->distance = FLT_MAX;
}

__global__ void KernelRayHitDetect(Ray* rays, Sphere* sphere, RayHitResult* hitResults)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    Ray* ray = rays + idx;
    RayHitResult* hitResult = hitResults + idx;

    HitDetect(sphere, ray, hitResult);
}

__global__ void KernelRaySample(curandStateXORWOW_t* states, Ray* rays, RayHitResult* hitResults, uint8_t* pixels)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    curandStateXORWOW_t* state = states + idx;
    Ray* ray = rays + idx;
    RayHitResult* hitResult = hitResults + idx;
    uint8_t* pixel = pixels + idx * 4;

    RaySampleResult dirSampleResult;
    Vector3 color;
    if (DirectLightSample(state, ray, hitResult, DevWorld->lights, &dirSampleResult))
    {
        color = (DevWorld->lights)->GetMaterial(DevWorld)->emit * (DevWorld->lights)->GetMaterial(DevWorld)->intensity * dirSampleResult.brdf * dirSampleResult.cosine / dirSampleResult.pdf / dirSampleResult.attenuation;
    }

    *(pixel + 0) = color.x * 255;
    *(pixel + 1) = color.y * 255;
    *(pixel + 2) = color.z * 255;
    *(pixel + 3) = 255;
}

__global__ void KernelPixel(int kernelSize, float* src, int width, int height, uint8_t* dst)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
	int x = idx % width;
	int y = idx / width;

	int kSize = kernelSize * kernelSize;
	int offset = kernelSize / 2;

	if (x < offset || x >= width - offset || y < offset || y >= height - offset)
	{
		return;
	}
	
    Vector3 c(0, 0, 0);
	for (int i = x - offset; i <= x + offset; i++)
	{
		for (int j = y - offset; j <= y + offset; j++)
		{
			c.x += src[width * j * 4 + i * 4 + 0] / kSize;
            c.y += src[width * j * 4 + i * 4 + 1] / kSize;
            c.z += src[width * j * 4 + i * 4 + 2] / kSize;
		}
	}
    c = AcesFilm(c);
    dst[idx * 4 + 0] = c.x * 255;
    dst[idx * 4 + 1] = c.y * 255;
    dst[idx * 4 + 2] = c.z * 255;
    dst[idx * 4 + 3] = 255;
}

__device__ void DevTest()
{    
    
}

__global__ void KernelTest()
{
    
}

void Renderer::Init()
{    
    dim3 gridDim(width * height / devThreadNum, 1);
    dim3 blockDim(devThreadNum, 1);

    float left = GetCamera()->focus * -tan(GetCamera()->fovX * PI / 180 / 2);
    float right = GetCamera()->focus * tan(GetCamera()->fovX * PI / 180 / 2);
    float top = GetCamera()->focus * tan(GetCamera()->fovY * PI / 180 / 2);
    float bottom = GetCamera()->focus * -tan(GetCamera()->fovY * PI / 180 / 2);

    translateX = -width / 2;
    translateY = -height / 2;
    scaleX = (right - left) / width;
    scaleY = (top - bottom) / height;    

    pixelsData = new uint8_t[width * height * 4];
	
    if (cudaError_t cudaerr = cudaMalloc(&devRandStates, sizeof(curandStateXORWOW_t) * width * height))
        printf("cudaMalloc devRandStates failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    
    InitRandStates<<<gridDim, blockDim>>>(devRandStates, time(nullptr));
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel InitRandStates launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devCamera, sizeof(Camera)))
		printf("cudaMalloc devCamera failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devVertices, sizeof(Vertex) * GetWorld()->vertices.size()))
        printf("cudaMalloc devVertices failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devSpheres, sizeof(Sphere) * GetWorld()->spheres.size()))
		printf("cudaMalloc devSpheres failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    
    if (cudaError_t cudaerr = cudaMalloc(&devTriangles, sizeof(Triangle) * GetWorld()->triangles.size()))
        printf("cudaMalloc devTriangles failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devQuadrilaterals, sizeof(Quadrilateral) * GetWorld()->quadrilaterals.size()))
        printf("cudaMalloc devQuadrilaterals failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devMeshes, sizeof(Mesh) * GetWorld()->meshes.size()))
        printf("cudaMalloc *devMeshes failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devLights, sizeof(Sphere) * GetWorld()->lights.size()))
		printf("cudaMalloc devLights failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devMaterials, sizeof(Material) * GetWorld()->materials.size()))
        printf("cudaMalloc devMaterials failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devTextures, sizeof(Texture) * GetWorld()->textures.size()))
        printf("cudaMalloc devTextures failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devTexturePixels, sizeof(uint8_t) * GetWorld()->texturePixels.size()))
        printf("cudaMalloc devTexturePixels failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devRays, sizeof(Ray) * width * height))
		printf("cudaMalloc devRays failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devHitResults, sizeof(RayHitResult) * width * height))
        printf("cudaMalloc devHitResults failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devRadiometry, sizeof(float) * width * height * 4))
		printf("cudaMalloc devPixels failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMalloc(&devPixels, sizeof(uint8_t) * width * height * 4))
        printf("cudaMalloc devPixelCaches failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    devWorld.vertices = devVertices;
    devWorld.verticesSize = GetWorld()->vertices.size();
    devWorld.spheres = devSpheres;
    devWorld.spheresSize = GetWorld()->spheres.size();
    devWorld.triangles = devTriangles;
    devWorld.trianglesSize = GetWorld()->triangles.size();
    devWorld.quadrilaterals = devQuadrilaterals;
    devWorld.quadrilateralsSize = GetWorld()->quadrilaterals.size();
    devWorld.meshes = devMeshes;
    devWorld.meshesSize = GetWorld()->meshes.size();
    devWorld.lights = devLights;
    devWorld.lightsSize = GetWorld()->lights.size();
    devWorld.materials = devMaterials;
    devWorld.materialsSize = GetWorld()->materials.size();
    devWorld.textures = devTextures;
    devWorld.texturesSize = GetWorld()->textures.size();
    devWorld.texturePixels = devTexturePixels;
    devWorld.texturePixelsSize = GetWorld()->texturePixels.size();

    std::cout << "verticesSize: " << devWorld.verticesSize << std::endl;
	std::cout << "spheresSize: " << devWorld.spheresSize << std::endl;
	std::cout << "trianglesSize: " << devWorld.trianglesSize << std::endl;
	std::cout << "quadrilateralsSize: " << devWorld.quadrilateralsSize << std::endl;
	std::cout << "meshesSize: " << devWorld.meshesSize << std::endl;
	std::cout << "lightsSize: " << devWorld.lightsSize << std::endl;
    std::cout << "materialsSize: " << devWorld.materialsSize << std::endl;
    std::cout << "texturesSize: " << devWorld.texturesSize << std::endl;
    std::cout << "texturePixelsSize: " << devWorld.texturePixelsSize << std::endl;

    if (cudaError_t cudaerr = cudaMemcpyToSymbol(DevWorld, &devWorld, sizeof(DeviceWorld)))
        printf("cudaMemcpy DevWorld failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devVertices, GetWorld()->vertices.data(), sizeof(Vertex) * GetWorld()->vertices.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devVertices failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devSpheres, GetWorld()->spheres.data(), sizeof(Sphere) * GetWorld()->spheres.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devSpheres failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devTriangles, GetWorld()->triangles.data(), sizeof(Triangle) * GetWorld()->triangles.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devTriangles failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devQuadrilaterals, GetWorld()->quadrilaterals.data(), sizeof(Quadrilateral) * GetWorld()->quadrilaterals.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devQuadrilaterals failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devMeshes, GetWorld()->meshes.data(), sizeof(Mesh) * GetWorld()->meshes.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devMeshes failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devLights, GetWorld()->lights.data(), sizeof(Sphere) * GetWorld()->lights.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devLights failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devMaterials, GetWorld()->materials.data(), sizeof(Material) * GetWorld()->materials.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devMaterials failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devTextures, GetWorld()->textures.data(), sizeof(Texture) * GetWorld()->textures.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devTextures failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devTexturePixels, GetWorld()->texturePixels.data(), sizeof(uint8_t) * GetWorld()->texturePixels.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devTexturePixels failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devCamera, GetCamera(), sizeof(Camera), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devCamera failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
}

void Renderer::Tick(float deltaTime)
{
    dim3 gridDim(width * height / devThreadNum, 1);
    dim3 blockDim(devThreadNum, 1);

    KernelInitRay<<<gridDim, blockDim>>>(devRandStates, devRays, devCamera, translateX, scaleX, translateY, scaleY);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel InitRay launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    
    KernelRayTrace<<<gridDim, blockDim>>>(devRandStates, devRays, devHitResults, devRadiometry, frame);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel RayTrace launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    
    KernelPixel<<<gridDim, blockDim>>>(filterKernelSize, devRadiometry, width, height, devPixels);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel MeanFilter launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    
    if (cudaError_t cudaerr = cudaMemcpy(pixelsData, devPixels, sizeof(uint8_t) * width * height * 4, cudaMemcpyKind::cudaMemcpyDeviceToHost))
        printf("cudaMemcpy pixels failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
	
    frame++;
    int64_t time = GetTime();
    frameTime = time - timer;
    timer = time;
}

void Renderer::Tick2(float deltaTime)
{
    /*
    if (cudaError_t cudaerr = cudaMemcpyToSymbol(DevWorld, &devWorld, sizeof(DeviceWorld)))
        printf("cudaMemcpy DevWorld failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devVertices, GetWorld()->vertices.data(), sizeof(Vertex) * GetWorld()->vertices.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devVertices failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devSpheres, GetWorld()->spheres.data(), sizeof(Sphere) * GetWorld()->spheres.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devSpheres failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devTriangles, GetWorld()->triangles.data(), sizeof(Triangle) * GetWorld()->triangles.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devTriangles failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devQuadrilaterals, GetWorld()->quadrilaterals.data(), sizeof(Quadrilateral) * GetWorld()->quadrilaterals.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devQuadrilaterals failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devFaces, GetWorld()->faces.data(), sizeof(Triangle) * GetWorld()->faces.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devFaces failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devMeshes, GetWorld()->meshes.data(), sizeof(Mesh) * GetWorld()->meshes.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devMeshes failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devLights, GetWorld()->lights.data(), sizeof(Sphere) * GetWorld()->lights.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devLights failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devMaterials, GetWorld()->materials.data(), sizeof(Material) * GetWorld()->materials.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devMaterials failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devTextures, GetWorld()->textures.data(), sizeof(Texture) * GetWorld()->textures.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devTextures failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devTexturePixels, GetWorld()->texturePixels.data(), sizeof(uint8_t) * GetWorld()->texturePixels.size(), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devTexturePixels failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(devCamera, GetCamera(), sizeof(Camera), cudaMemcpyKind::cudaMemcpyHostToDevice))
        printf("cudaMemcpy devCamera failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    dim3 gridDim(width * height / devThreadNum, 1);
    dim3 blockDim(devThreadNum, 1);

    KernelInitRay<<<gridDim, blockDim>>>(devRandStates, devRays, devCamera, translateX, scaleX, translateY, scaleY);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel InitRay launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    KernelInitHitResult<<<gridDim, blockDim>>>(devHitResults);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel InitHitResult launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    for (auto& sphere : GetWorld()->spheres)
    {
        if (cudaError_t cudaerr = cudaMemcpy(devSpheres, &sphere, sizeof(Sphere), cudaMemcpyKind::cudaMemcpyHostToDevice))
            printf("cudaMemcpy devSpheres failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

        KernelRayHitDetect<<<gridDim, blockDim>>>(devRays, devSpheres, devHitResults);
        if (cudaError_t cudaerr = cudaDeviceSynchronize())
            printf("kernel RayHitDetect launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    }

    KernelRaySample<<<gridDim, blockDim>>>(devRandStates, devRays, devHitResults, devPixelsData);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel RayHitDetect launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    if (cudaError_t cudaerr = cudaMemcpy(pixelsData, devPixels, sizeof(uint8_t) * width * height * 4, cudaMemcpyKind::cudaMemcpyDeviceToHost))
        printf("cudaMemcpy pixels failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    frame++;
    int64_t time = GetTime();
    frameTime = time - timer;
    timer = time;
    */
}

void Renderer::TestTick(float deltaTime)
{
    
}

__global__ void SampleTest(curandStateXORWOW_t* randStates, Vector3F normal, Vector3F* directions)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    curandStateXORWOW_t* state = randStates + idx;
    Vector3F* direction = directions + idx;
    *direction = WeightedSampleCosine(state, normal);
}

void Test()
{
    int sampleSize = 10000;
    curandStateXORWOW_t* devRandStates = nullptr;
    if (cudaError_t cudaerr = cudaMalloc(&devRandStates, sizeof(curandStateXORWOW_t) * sampleSize))
        printf("cudaMalloc devRandStates failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    InitRandStates<<<sampleSize, 1>>> (devRandStates, time(nullptr));
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel InitRandStates launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    Vector3F* devDirections;
    if (cudaError_t cudaerr = cudaMalloc(&devDirections, sizeof(Vector3F) * sampleSize))
        printf("cudaMalloc devRays failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    Vector3F normal(0.0, 0.0, 1.0);
    SampleTest<<<sampleSize, 1>>> (devRandStates, normal, devDirections);
    if (cudaError_t cudaerr = cudaDeviceSynchronize())
        printf("kernel SampleTest launch failed with error \"%s\".\n", cudaGetErrorString(cudaerr));

    Vector3F* directions = new Vector3F[sampleSize];
    if (cudaError_t cudaerr = cudaMemcpy(directions, devDirections, sizeof(Vector3F) * sampleSize, cudaMemcpyKind::cudaMemcpyDeviceToHost))
        printf("cudaMemcpy directions failed with error \"%s\".\n", cudaGetErrorString(cudaerr));
    
    float delta = PI / 2 / 10;
    int count[10] = { 0 };

    for (int i = 0; i < sampleSize; i++)
    {
        float cos = Dot(normal, directions[i]);
        float angle = acos(cos);

        int n = angle / delta;
        count[n] += 1;
    }

    int total = 0;
    for (int i = 0; i < 10; i++)
    {
        total += count[i];
        std::cout << count[i] << std::endl;
    }
    std::cout << "count: " << total << std::endl;
    
    /*
    float delta = 1.0 / 10;
    int count[10] = { 0 };

    for (int i = 0; i < sampleSize; i++)
    {
        Vector2F v(directions[i].x, directions[i].y);
        float r = v.Length();
        int n = r / delta;
        count[n] += 1;
    }

    int total = 0;
    for (int i = 0; i < 10; i++)
    {
        total += count[i];
        std::cout << count[i] << std::endl;
    }
    std::cout << "count: " << total << std::endl;
    */
    delete[] directions;
}