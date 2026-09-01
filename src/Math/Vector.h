#pragma once
#include <stdio.h>
#include <string>
#include <iostream>

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

template <typename T>
class _Matrix3;
template <typename T>
class _Matrix4;
template <typename T>
class _Rotator;

template <typename T>
class _Vector2
{
public:
    T x;
    T y;

    static const _Vector2 Zero;

    __host__ __device__ _Vector2 operator+(const _Vector2& v) { return _Vector2(x + v.x, y + v.y); }
    __host__ __device__ _Vector2 operator-(const _Vector2& v) const { return _Vector2(x - v.x, y - v.y); }
    __host__ __device__ _Vector2 operator*(const _Vector2& v) { return _Vector2(x * v.x, y * v.y); }
    __host__ __device__ _Vector2 operator/(const _Vector2& v) { return _Vector2(x / v.x, y / v.y); }
    __host__ __device__ _Vector2 operator*(const float& s) { return _Vector2(x * s, y * s); }
    __host__ __device__ _Vector2 operator*(const float& s) const { return _Vector2(x * s, y * s); }
    __host__ __device__ _Vector2 operator/(const float& s) { return _Vector2<T>(x / s, y / s); }
    __host__ __device__ _Vector2 operator-() { return _Vector2(-x, -y); }
    __host__ __device__ void operator=(const _Vector2& v) { memcpy(this, &v, sizeof(_Vector2)); }
    __host__ __device__ bool operator==(const _Vector2& v) { return x == v.x && y == v.y; }
    __host__ __device__ bool operator!=(const _Vector2& v) { return !(*this == v); }
    __host__ __device__ T& operator[](const int& i) { return (&x)[i]; }
    __host__ __device__ const T& operator[](const int& i) const { return (&x)[i]; }

    __host__ __device__ _Vector2(T x = 0, T y = 0) : x(x), y(y) {}
    __host__ __device__ _Vector2(const _Vector2& v) : x(v.x), y(v.y) {}
    __host__ __device__ float Length() const { return sqrtf(static_cast<float>(x * x + y * y)); }
    __host__ __device__ void Normalize()
    {
        float l = Length();
        if (l <= 1e-10f)
        {
            x = 0;
            y = 0;
            return;
        }
        x /= l;
        y /= l;
    }
    __host__ __device__ _Vector2 GetNormalized() const
    {
        float l = Length();
        if (l <= 1e-10f)
        {
            return _Vector2(0, 0);
        }
        return _Vector2(x / l, y / l);
    }
    __host__ __device__ void Print() { printf("(x: %f, y: %f)\n", x, y); }
};

template <typename T>
class _Vector3
{
public:
    T x;
    T y;
    T z;

    static const _Vector3 Zero;
    static const _Vector3 AxisX;
    static const _Vector3 AxisY;
    static const _Vector3 AxisZ;

    __host__ __device__ _Vector3 operator+(const _Vector3& v) { return _Vector3(x + v.x, y + v.y, z + v.z); }
    __host__ __device__ _Vector3 operator-(const _Vector3& v) const { return _Vector3(x - v.x, y - v.y, z - v.z); }
    __host__ __device__ _Vector3 operator*(const _Vector3& v) { return _Vector3(x * v.x, y * v.y, z * v.z); }
    __host__ __device__ _Vector3 operator/(const _Vector3& v) { return _Vector3(x / v.x, y / v.y, z / v.z); }
    __host__ __device__ _Vector3 operator*(const float& s) { return _Vector3(x * s, y * s, z * s); }
    __host__ __device__ _Vector3 operator*(const float& s) const { return _Vector3(x * s, y * s, z * s); }
    __host__ __device__ _Vector3 operator/(const float& s) { return _Vector3<T>(x / s, y / s, z / s); }
    __host__ __device__ _Vector3 operator-() { return _Vector3(-x, -y, -z); }
    __host__ __device__ void operator=(const _Vector3& v) { memcpy(this, &v, sizeof(_Vector3)); }
    __host__ __device__ bool operator==(const _Vector3& v) { return x == v.x && y == v.y && z == v.z; }
    __host__ __device__ bool operator!=(const _Vector3& v) { return !(*this == v); }
    __host__ __device__ T& operator[](const int& i) { return (&x)[i]; }
    __host__ __device__ const T& operator[](const int& i) const { return (&x)[i]; }

    __host__ __device__ _Vector3(T x = 0, T y = 0, T z = 0) : x(x), y(y), z(z) {}
    __host__ __device__ _Vector3(const _Vector3& v) : x(v.x), y(v.y), z(v.z) {}
    __host__ __device__ float Length() const { return sqrtf(static_cast<float>(x * x + y * y + z * z)); }
    __host__ __device__ void Normalize()
    {
        float l = Length();
        if (l <= 1e-10f)
        {
            x = 0;
            y = 0;
            z = 0;
            return;
        }
        x /= l;
        y /= l;
        z /= l;
    }
    __host__ __device__ _Vector3 GetNormalized() const
    {
        float l = Length();
        if (l <= 1e-10f)
        {
            return _Vector3(0, 0, 0);
        }
        return _Vector3(x / l, y / l, z / l);
    }
    __host__ __device__ _Rotator<T> Rotation()
    {
        _Rotator<T> r;
        r.yaw = atan2(y, x) / PI * 180.0f;
        r.pitch = atan2(z, sqrt(x * x + y * y)) / PI * 180.0f;
        r.roll = 0.0f;
        return r;
    }
    __host__ __device__ void Print() { printf("(x: %f, y: %f, z: %f)\n", x, y, z); }
};

template <typename T>
class _Vector4
{
public:
    T x;
    T y;
    T z;
    T w;

    static const _Vector4 Zero;

    __host__ __device__ _Vector4 operator+(const _Vector4& v) { return _Vector4(x + v.x, y + v.y, z + v.z, w + v.w); }
    __host__ __device__ _Vector4 operator-(const _Vector4& v) { return _Vector4(x - v.x, y - v.y, z - v.z, w - v.w); }
    __host__ __device__ _Vector4 operator*(const _Vector4& v) { return _Vector4(x * v.x, y * v.y, z * v.z, w * v.w); }
    __host__ __device__ _Vector4 operator/(const _Vector4& v) { return _Vector4(x / v.x, y / v.y, z / v.z, w / v.w); }
    __host__ __device__ _Vector4 operator*(const float& s) { return _Vector4(x * s, y * s, z * s, w * s); }
    __host__ __device__ _Vector4 operator/(const float& s) { return _Vector4(x / s, y / s, z / s, w / s); }
    __host__ __device__ _Vector4 operator-() { return _Vector4(-x, -y, -z, -w); }
    __host__ __device__ void operator=(const _Vector4& v) { memcpy(this, &v, sizeof(_Vector4)); }
    __host__ __device__ bool operator==(const _Vector4& v) { return x == v.x && y == v.y && z == v.z && w == v.w; }
    __host__ __device__ bool operator!=(const _Vector4& v) { return !(*this == v); }
    __host__ __device__ T& operator[](const int& i) { return (&x)[i]; }
    __host__ __device__ const T& operator[](const int& i) const { return (&x)[i]; }

    __host__ __device__ _Vector4(T x = 0, T y = 0, T z = 0, T w = 0) : x(x), y(y), z(z), w(w) {}
    __host__ __device__ float Length() const { return sqrtf(static_cast<float>(x * x + y * y + z * z + w * w)); }
    __host__ __device__ void Normalize()
    {
        float l = Length();
        if (l <= 1e-10f)
        {
            x = 0;
            y = 0;
            z = 0;
            w = 0;
            return;
        }
        x /= l;
        y /= l;
        z /= l;
        w /= l;
    }
    __host__ __device__ _Vector4 GetNormalized() const
    {
        float l = Length();
        if (l <= 1e-10f)
        {
            return _Vector4(0, 0, 0, 0);
        }
        return _Vector4(x / l, y / l, z / l, w / l);
    }
    __host__ __device__ void Print() { printf("(x: %f, y: %f, z: %f, w: %f)\n", x, y, z, w); }
};

using Vector2I = _Vector2<int>;
using Vector3I = _Vector3<int>;
using Vector4I = _Vector4<int>;
using Vector2F = _Vector2<float>;
using Vector3F = _Vector3<float>;
using Vector4F = _Vector4<float>;
using Vector2 = Vector2F;
using Vector3 = Vector3F;
using Vector4 = Vector4F;

const Vector2I Vector2I::Zero(0, 0);
const Vector3I Vector3I::Zero(0, 0, 0);
const Vector4I Vector4I::Zero(0, 0, 0, 0);
const Vector2F Vector2F::Zero(0.0f, 0.0f);
const Vector3F Vector3F::Zero(0.0f, 0.0f, 0.0f);
const Vector4F Vector4F::Zero(0.0f, 0.0f, 0.0f, 0.0f);
const Vector3F Vector3F::AxisX(1.0f, 0.0f, 0.0f);
const Vector3F Vector3F::AxisY(0.0f, 1.0f, 0.0f);
const Vector3F Vector3F::AxisZ(0.0f, 0.0f, 1.0f);

std::ostream& operator<<(std::ostream& os, const Vector3& v);
std::ostream& operator<<(std::ostream& os, const Vector4& v);