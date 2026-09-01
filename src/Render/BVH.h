#pragma once
#include <Math/Vector.h>

struct BVHNode
{
    Vector3 boundsMin;
    Vector3 boundsMax;
    int left = -1;
    int right = -1;
    int next = -1;
    int start = 0;
    int count = 0;

    __host__ __device__ bool IsLeaf() const
    {
        return count > 0;
    }
};