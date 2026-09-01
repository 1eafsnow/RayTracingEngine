#pragma once
#include <Math/Math.h>

#define MIN_DETECT_DISTANCE 0.001f
#define MAX_DETECT_DISTANCE 1000.0f

class Ray
{
public:
    Vector3 location;
    Vector3 direction;
    int depth;

    __host__ __device__ Ray(const Vector3& location = Vector3(0.0f, 0.0f, 0.0f), const Vector3& direction = Vector3(0.0f, 0.0f, 0.0f))
        : location(location), direction(direction), depth(0)
    {
    }
};

struct RaySampleResult
{
    Vector3 brdf = Vector3(0.0f, 0.0f, 0.0f);
    float pdf = 0.0f;
    float cosine = 0.0f;
    float attenuation = 1.0f;
};

struct RayHitResult
{
    bool isHit = false;
    float distance = FLT_MAX;
    Vector3 location = Vector3(0.0f, 0.0f, 0.0f);
    Vector3 normal = Vector3(0.0f, 0.0f, 0.0f);
    class Material* material = nullptr;
    Vector3 color = Vector3(0.0f, 0.0f, 0.0f);
    int objectId = -1;
};
