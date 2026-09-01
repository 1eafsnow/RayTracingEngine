#include <Math/Math.h>

__host__ float Random()
{
    return static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
}

__host__ float RandomLeftOpen()
{
    return static_cast<float>(rand() + 1) / static_cast<float>(RAND_MAX + 1);
}

__host__ float RandomRightOpen()
{
    return static_cast<float>(rand()) / static_cast<float>(RAND_MAX + 1);
}

__host__ float RandomOpen()
{
    return static_cast<float>(rand() + 1) / static_cast<float>(RAND_MAX + 2);
}

__host__ float Random(const float& min, const float& max, const bool& lInterval, const bool& rInterval)
{
    float r = 0.0f;
    if (lInterval && rInterval)
    {
        r = Random();
    }
    else if (!lInterval && rInterval)
    {
        r = RandomLeftOpen();
    }
    else if (lInterval && !rInterval)
    {
        r = RandomRightOpen();
    }
    else
    {
        r = RandomOpen();
    }
    return min + r * (max - min);
}

__global__ void InitRandStates(curandStateXORWOW_t* states, unsigned long long seed, int stateCount)
{
    int idx = blockDim.x * blockIdx.x + threadIdx.x;
    if (idx >= stateCount)
    {
        return;
    }
    curand_init(seed, idx, 0, states + idx);
}
