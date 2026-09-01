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
    (void)lInterval;
    (void)rInterval;
    float r = static_cast<float>(rand()) / static_cast<float>(RAND_MAX);
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

__device__ float DevRand(curandStateXORWOW_t* state)
{
    return curand_uniform(state);
}

__device__ float DevRandClose(curandStateXORWOW_t* state)
{
    return DevRand(state);
}

__device__ float DevRandOpen(curandStateXORWOW_t* state)
{
    return DevRand(state);
}

__host__ __device__ int Max(const int& a, const int& b)
{
    return (a > b) ? a : b;
}

__host__ __device__ int Min(const int& a, const int& b)
{
    return (a < b) ? a : b;
}

__host__ __device__ float Max(const float& a, const float& b)
{
    return (a > b) ? a : b;
}

__host__ __device__ float Min(const float& a, const float& b)
{
    return (a < b) ? a : b;
}

__host__ __device__ float Clamp(const float& x, const float& min, const float& max)
{
    if (x < min)
    {
        return min;
    }
    if (x > max)
    {
        return max;
    }
    return x;
}

__host__ __device__ void Normalize(Vector3& v)
{
    float lengthSquared = v.x * v.x + v.y * v.y + v.z * v.z;
    if (lengthSquared <= 1e-20f)
    {
        v = Vector3(0.0f, 0.0f, 0.0f);
        return;
    }

    float invLength = 1.0f / sqrtf(lengthSquared);
    v.x *= invLength;
    v.y *= invLength;
    v.z *= invLength;
}

__host__ __device__ float Dot(const Vector2& v1, const Vector2& v2)
{
    return v1.x * v2.x + v1.y * v2.y;
}

__host__ __device__ float Dot(const Vector3& v1, const Vector3& v2)
{
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

__host__ __device__ Vector3 Cross(const Vector3& v1, const Vector3& v2)
{
    return Vector3(v1.y * v2.z - v1.z * v2.y, v1.z * v2.x - v1.x * v2.z, v1.x * v2.y - v1.y * v2.x);
}

__host__ __device__ Quaternion Cross(const Quaternion& q1, const Quaternion& q2)
{
    Vector3 q1u(q1.x, q1.y, q1.z);
    Vector3 q2u(q2.x, q2.y, q2.z);
    Vector3 u = q2u * q1.w + q1u * q2.w + Cross(q1u, q2u);
    float w = q1.w * q2.w - Dot(q1u, q2u);
    return Quaternion(u, w);
}

__host__ __device__ Vector3 Matmul(const Matrix3& m, const Vector3& v)
{
    return Vector3(m.elements[0] * v.x + m.elements[1] * v.y + m.elements[2] * v.z,
        m.elements[3] * v.x + m.elements[4] * v.y + m.elements[5] * v.z,
        m.elements[6] * v.x + m.elements[7] * v.y + m.elements[8] * v.z);
}

__host__ __device__ Vector4 Matmul(const Matrix4& m, const Vector4& v)
{
    return Vector4(m.elements[0] * v.x + m.elements[1] * v.y + m.elements[2] * v.z + m.elements[3] * v.w,
        m.elements[4] * v.x + m.elements[5] * v.y + m.elements[6] * v.z + m.elements[7] * v.w,
        m.elements[8] * v.x + m.elements[9] * v.y + m.elements[10] * v.z + m.elements[11] * v.w,
        m.elements[12] * v.x + m.elements[13] * v.y + m.elements[14] * v.z + m.elements[15] * v.w);
}

__host__ __device__ Vector3 Matmul(const Matrix4& m, const Vector3& v)
{
    float w = m.elements[12] * v.x + m.elements[13] * v.y + m.elements[14] * v.z + m.elements[15];
    return Vector3(m.elements[0] * v.x + m.elements[1] * v.y + m.elements[2] * v.z + m.elements[3],
        m.elements[4] * v.x + m.elements[5] * v.y + m.elements[6] * v.z + m.elements[7],
        m.elements[8] * v.x + m.elements[9] * v.y + m.elements[10] * v.z + m.elements[11]) / w;
}

__host__ __device__ Matrix3 Matmul(Matrix3 l, Matrix3 r)
{
    Matrix3 result;
    for (int i = 0; i < 3; i++)
    {
        for (int j = 0; j < 3; j++)
        {
            for (int k = 0; k < 3; k++)
            {
                result[i][j] += l[i][k] * r[k][j];
            }
        }
    }
    return result;
}

__host__ __device__ Matrix4 Matmul(Matrix4 l, Matrix4 r)
{
    Matrix4 result;
    for (int i = 0; i < 4; i++)
    {
        for (int j = 0; j < 4; j++)
        {
            for (int k = 0; k < 4; k++)
            {
                result[i][j] += l[i][k] * r[k][j];
            }
        }
    }
    return result;
}

__host__ __device__ Matrix4 RotateMatrixToTransform(Matrix3& m)
{
    return Matrix4(m[0][0], m[0][1], m[0][2], 0,
        m[1][0], m[1][1], m[1][2], 0,
        m[2][0], m[2][1], m[2][2], 0,
        0, 0, 0, 1);
}

__host__ __device__ Matrix3 TransformToRotateMatrix(Matrix4& m)
{
    return Matrix3(m[0][0], m[0][1], m[0][2],
        m[1][0], m[1][1], m[1][2],
        m[2][0], m[2][1], m[2][2]);
}

__host__ __device__ float Angle(Vector3& v1, Vector3& v2)
{
    float denominator = v1.Length() * v2.Length();
    if (denominator <= 1e-20f)
    {
        return 0.0f;
    }
    return acosf(Clamp(Dot(v1, v2) / denominator, -1.0f, 1.0f));
}

__host__ __device__ float Angle(Vector2& v1, Vector2& v2)
{
    float denominator = v1.Length() * v2.Length();
    if (denominator <= 1e-20f)
    {
        return 0.0f;
    }
    return acosf(Clamp(Dot(v1, v2) / denominator, -1.0f, 1.0f));
}

__device__ Vector3 Reflect(Vector3 n, Vector3 i)
{
    return (n * (2.0f * Dot(n, i)) - i).GetNormalized();
}

__device__ Vector3 WeightedSampleRandom(curandStateXORWOW_t* state, const Vector3& normal)
{
    Vector3 w = normal.GetNormalized();
    Vector3 vup = fabsf(w.x) > 0.9f ? Vector3(0.0f, 1.0f, 0.0f) : Vector3(1.0f, 0.0f, 0.0f);
    Vector3 v = Cross(vup, w).GetNormalized();
    Vector3 u = Cross(w, v).GetNormalized();

    float z = DevRandOpen(state);
    float phi = 2.0f * PI * DevRandClose(state);
    float radial = sqrtf(Max(0.0f, 1.0f - z * z));
    float x = radial * cosf(phi);
    float y = radial * sinf(phi);

    return (u * x + v * y + w * z).GetNormalized();
}

__device__ Vector3 WeightedSampleCosine(curandStateXORWOW_t* state, const Vector3& normal)
{
    Vector3 w = normal.GetNormalized();
    Vector3 vup = fabsf(w.x) > 0.9f ? Vector3(0.0f, 1.0f, 0.0f) : Vector3(1.0f, 0.0f, 0.0f);
    Vector3 v = Cross(vup, w).GetNormalized();
    Vector3 u = Cross(w, v).GetNormalized();

    float r1 = DevRandOpen(state);
    float r2 = DevRandOpen(state);
    float radial = sqrtf(r1);
    float phi = 2.0f * PI * r2;
    float x = radial * cosf(phi);
    float y = radial * sinf(phi);
    float z = sqrtf(Max(0.0f, 1.0f - r1));

    return (u * x + v * y + w * z).GetNormalized();
}

__device__ Vector3 WeightedSampleGGX(curandStateXORWOW_t* state, const Vector3& normal, const float& roughness)
{
    Vector3 w = normal.GetNormalized();
    Vector3 vup = fabsf(w.x) > 0.9f ? Vector3(0.0f, 1.0f, 0.0f) : Vector3(1.0f, 0.0f, 0.0f);
    Vector3 v = Cross(vup, w).GetNormalized();
    Vector3 u = Cross(w, v).GetNormalized();

    float alpha = Max(roughness, 0.001f);
    float alpha2 = alpha * alpha;
    float r = Min(DevRandOpen(state), 0.999999f);
    float phi = 2.0f * PI * DevRandClose(state);
    float cosTheta = sqrtf((1.0f - r) / (1.0f + (alpha2 - 1.0f) * r));
    float sinTheta = sqrtf(Max(0.0f, 1.0f - cosTheta * cosTheta));
    float x = sinTheta * cosf(phi);
    float y = sinTheta * sinf(phi);
    float z = cosTheta;

    return (u * x + v * y + w * z).GetNormalized();
}

__device__ Vector3 WeightedSampleSphereLight(curandStateXORWOW_t* state, const Vector3& location, const Vector3& lightLocation, const float& lightRadius)
{
    Vector3 toLight = lightLocation - location;
    float dist = toLight.Length();
    if (dist <= lightRadius || dist <= 1e-6f)
    {
        return toLight.GetNormalized();
    }

    Vector3 w = toLight / dist;
    Vector3 vup = fabsf(w.x) > 0.9f ? Vector3(0.0f, 1.0f, 0.0f) : Vector3(1.0f, 0.0f, 0.0f);
    Vector3 v = Cross(vup, w).GetNormalized();
    Vector3 u = Cross(w, v).GetNormalized();

    float sinThetaMax2 = Clamp((lightRadius * lightRadius) / (dist * dist), 0.0f, 1.0f);
    float cosThetaMax = sqrtf(Max(0.0f, 1.0f - sinThetaMax2));
    float r = DevRandClose(state);
    float cosTheta = 1.0f - r * (1.0f - cosThetaMax);
    float sinTheta = sqrtf(Max(0.0f, 1.0f - cosTheta * cosTheta));
    float phi = 2.0f * PI * DevRandClose(state);

    float x = sinTheta * cosf(phi);
    float y = sinTheta * sinf(phi);
    float z = cosTheta;
    return (u * x + v * y + w * z).GetNormalized();
}

__device__ float SchlickFresnel(const float& n1, const float& n2, const Vector3& n, const Vector3& i)
{
    float denominator = n1 + n2;
    if (fabsf(denominator) <= 1e-6f)
    {
        return 1.0f;
    }

    float dn = (n1 - n2) / denominator;
    float r0 = dn * dn;
    float cosine = Clamp(Dot(i, n), 0.0f, 1.0f);
    float c = 1.0f - cosine;
    float c2 = c * c;
    float c5 = c2 * c2 * c;
    return Clamp(r0 + (1.0f - r0) * c5, 0.0f, 1.0f);
}

__device__ float NDF_GGX(const Vector3& n, const Vector3& h, const float& roughness)
{
    float NoH = Max(Dot(n, h), 0.0f);
    if (NoH <= 0.0f)
    {
        return 0.0f;
    }

    float alpha = Max(roughness, 0.001f);
    float alpha2 = alpha * alpha;
    float denominator = NoH * NoH * (alpha2 - 1.0f) + 1.0f;
    return alpha2 / Max(PI * denominator * denominator, 1e-8f);
}

__device__ float GF_SchlickGGX(const Vector3& n, const Vector3& i, const Vector3& r, const float& roughness)
{
    float NoV = Max(Dot(n, i), 0.0f);
    float NoL = Max(Dot(n, r), 0.0f);
    if (NoV <= 0.0f || NoL <= 0.0f)
    {
        return 0.0f;
    }

    float alpha = Max(roughness, 0.001f);
    float k = ((alpha + 1.0f) * (alpha + 1.0f)) / 8.0f;
    float g1V = NoV / Max(NoV * (1.0f - k) + k, 1e-8f);
    float g1L = NoL / Max(NoL * (1.0f - k) + k, 1e-8f);
    return g1V * g1L;
}

__device__ float GF_SmithJointGGX(const Vector3& n, const Vector3& i, const Vector3& r, const float& roughness)
{
    float NoV = Max(Dot(n, i), 0.0f);
    float NoL = Max(Dot(n, r), 0.0f);
    if (NoV <= 0.0f || NoL <= 0.0f)
    {
        return 0.0f;
    }

    float alpha = Max(roughness, 0.001f);
    float alpha2 = alpha * alpha;
    float lambdaV = NoL * sqrtf(Max(NoV * NoV * (1.0f - alpha2) + alpha2, 0.0f));
    float lambdaL = NoV * sqrtf(Max(NoL * NoL * (1.0f - alpha2) + alpha2, 0.0f));
    return (2.0f * NoV * NoL) / Max(lambdaV + lambdaL, 1e-8f);
}

__device__ Vector3 AcesFilm(Vector3 color)
{
    color.x = Max(color.x, 0.0f);
    color.y = Max(color.y, 0.0f);
    color.z = Max(color.z, 0.0f);

    const float a = 2.51f;
    const float b = 0.03f;
    const float c = 2.43f;
    const float d = 0.59f;
    const float e = 0.14f;

    float x = Clamp((color.x * (a * color.x + b)) / (color.x * (c * color.x + d) + e), 0.0f, 1.0f);
    float y = Clamp((color.y * (a * color.y + b)) / (color.y * (c * color.y + d) + e), 0.0f, 1.0f);
    float z = Clamp((color.z * (a * color.z + b)) / (color.z * (c * color.z + d) + e), 0.0f, 1.0f);
    return Vector3(x, y, z);
}