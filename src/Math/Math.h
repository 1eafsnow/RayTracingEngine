#pragma once
#include <stdio.h>
#include <string>
#include <iostream>
#include <random>

#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <curand_kernel.h>

#define PI 3.1415926535

#include <Math/Vector.h>
#include <Math/Rotator.h>
#include <Math/Matrix.h>
#include <Math/Quaternion.h>
#include <Math/Filter.h>

__host__ float Random();

__host__ float RandomLeftOpen();

__host__ float RandomRightOpen();

__host__ float RandomOpen();

__host__ float Random(const float& min, const float& max, const bool& lInterval, const bool& rInterval);

__global__ void InitRandStates(curandStateXORWOW_t* states, unsigned long long seed);

__device__ float DevRand(curandStateXORWOW_t* state);

__device__ float DevRandClose(curandStateXORWOW_t* state);

__device__ float DevRandOpen(curandStateXORWOW_t* state);

__host__ __device__ int Max(const int& a, const int& b);

__host__ __device__ int Min(const int& a, const int& b);

__host__ __device__ float Max(const float& a, const float& b);

__host__ __device__ float Min(const float& a, const float& b);

__host__ __device__ float Clamp(const float& x, const float& min, const float& max);

__host__ __device__ void Normalize(Vector3& v);

__host__ __device__ float Dot(const Vector2& v1, const Vector2& v2);

__host__ __device__ float Dot(const Vector3& v1, const Vector3& v2);

__host__ __device__ Vector3 Cross(const Vector3& v1, const Vector3& v2);

__host__ __device__ Quaternion Cross(const Quaternion& q1, const Quaternion& q2);

__host__ __device__ Vector3 Matmul(const Matrix3& m, const Vector3& v);

__host__ __device__ Vector4 Matmul(const Matrix4& m, const Vector4& v);

__host__ __device__ Vector3 Matmul(const Matrix4& m, const Vector3& v);

__host__ __device__ Matrix3 Matmul(Matrix3 l, Matrix3 r);

__host__ __device__ Matrix4 Matmul(Matrix4 l, Matrix4 r);

__host__ __device__ Matrix4 RotateMatrixToTransform(Matrix3& m);

__host__ __device__ Matrix3 TransformToRotateMatrix(Matrix4& m);

__host__ __device__ float Angle(Vector2& v1, Vector2& v2);

__host__ __device__ float Angle(Vector3& v1, Vector3& v2);

__device__ Vector3 Reflect(Vector3 n, Vector3 i);

__device__ Vector3 WeightedSampleRandom(curandStateXORWOW_t* state, const Vector3& normal);

__device__ Vector3 WeightedSampleCosine(curandStateXORWOW_t* state, const Vector3& normal);

__device__ Vector3 WeightedSampleGGX(curandStateXORWOW_t* state, const Vector3& normal, const float& roughness);

__device__ Vector3 WeightedSampleSphereLight(curandStateXORWOW_t* state, const Vector3& location, const Vector3& lightLocation, const float& lightRadius);

__device__ float SchlickFresnel(const float& n1, const float& n2, const Vector3& n, const Vector3& i);

__device__ float NDF_GGX(const Vector3& n, const Vector3& h, const float& a);

__device__ float GF_SchlickGGX(const Vector3& n, const Vector3& i, const Vector3& r, const float& roughness);

__device__ float GF_SmithJointGGX(const Vector3& n, const Vector3& i, const Vector3& r, const float& roughness);

__device__ Vector3 AcesFilm(Vector3 color);