#pragma once
#include <Math/Math.h>
#include <Render/Ray.h>
#include <Object/Vertex.h>
#include <Material/Material.h>

class DeviceWorld;

class Quadrilateral
{
public:
    int id;
    int vertexIdx[4];
    int normalIdx[4];
    bool vertexNormal;
    Vector3 normal;
    float distance;
    int materialIdx;

    Vertex* GetVertex(int idx);
    Normal* GetVertexNormal(int idx);
    Material* GetMaterial();

    void Init();

    __device__ Material* GetMaterial(DeviceWorld* world);
    __device__ Vector3 GetAlbedo(DeviceWorld* world, const Vector3& barycentricCoordinate);
    __device__ bool IncludeDetect(DeviceWorld* world, const Vector3& location);
    __device__ bool HitDetect(DeviceWorld* world, Ray* ray, RayHitResult* hitResult);
};
