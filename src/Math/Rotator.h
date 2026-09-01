#pragma once
#include <stdio.h>
#include <string>
#include <iostream>

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

template <typename T>
class _Matrix3;

template <typename T>
class _Quaternion;

template <typename T>
class _Rotator
{
public:
    T yaw;
    T pitch;
    T roll;

    static const _Rotator Zero;

    __host__ __device__ _Rotator operator+(const _Rotator& r) const { return _Rotator(yaw + r.yaw, pitch + r.pitch, roll + r.roll); }
    __host__ __device__ _Rotator operator-(const _Rotator& r) const { return _Rotator(yaw - r.yaw, pitch - r.pitch, roll - r.roll); }
    __host__ __device__ _Rotator operator*(const _Rotator& r) const { return _Rotator(yaw * r.yaw, pitch * r.pitch, roll * r.roll); }
    __host__ __device__ _Rotator operator/(const _Rotator& r) const { return _Rotator(yaw / r.yaw, pitch / r.pitch, roll / r.roll); }
    __host__ __device__ _Rotator operator*(const float& s) const { return _Rotator(yaw * s, pitch * s, roll * s); }
    __host__ __device__ _Rotator operator/(const float& s) const { return _Rotator<T>(yaw / s, pitch / s, roll / s); }
    __host__ __device__ _Rotator operator-() const { return _Rotator(-yaw, -pitch, -roll); }
    __host__ __device__ _Rotator& operator=(const _Rotator& r)
    {
        yaw = r.yaw;
        pitch = r.pitch;
        roll = r.roll;
        return *this;
    }
    __host__ __device__ bool operator==(const _Rotator& r) const { return yaw == r.yaw && pitch == r.pitch && roll == r.roll; }
    __host__ __device__ bool operator!=(const _Rotator& r) const { return !(*this == r); }
    __host__ __device__ T& operator[](const int& i) { return (&yaw)[i]; }
    __host__ __device__ const T& operator[](const int& i) const { return (&yaw)[i]; }

    __host__ __device__ _Matrix3<T> RotateMatrix() const
    {
        const float yawRad = static_cast<float>(yaw) / 180.0f * PI;
        const float pitchRad = static_cast<float>(pitch) / 180.0f * PI;
        const float rollRad = static_cast<float>(roll) / 180.0f * PI;
        const float sy = sinf(yawRad);
        const float cy = cosf(yawRad);
        const float sp = sinf(pitchRad);
        const float cp = cosf(pitchRad);
        const float sr = sinf(rollRad);
        const float cr = cosf(rollRad);

        return _Matrix3<T>(cr * cy - sr * -sp * -sy, sr * cp, cr * sy - sr * -sp * cy,
            -sr * cy + cr * sp * -sy, cr * cp, -sr * sy + cr * sp * cy,
            cp * -sy, -sp, cp * cy);
    }

    __host__ __device__ _Rotator(T yaw = 0, T pitch = 0, T roll = 0) : yaw(yaw), pitch(pitch), roll(roll) { }

    __host__ __device__ _Quaternion<T> Quaternion() const
    {
        _Vector3<T> forward(1, 0, 0);
        _Vector3<T> leftward(0, -1, 0);
        _Vector3<T> upward(0, 0, 1);

        _Quaternion<T> qYaw;
        qYaw.SetRotation(upward, yaw / 180.0f * PI);
        forward = qYaw.Rotate(forward);
        leftward = qYaw.Rotate(leftward);

        _Quaternion<T> qPitch;
        qPitch.SetRotation(leftward, pitch / 180.0f * PI);
        forward = qPitch.Rotate(forward);

        _Quaternion<T> qRoll;
        qRoll.SetRotation(forward, roll / 180.0f * PI);

        return Cross(qRoll, Cross(qPitch, qYaw));
    }

    __host__ __device__ _Vector3<T> Rotate(const _Vector3<T>& v) const { return Quaternion().Rotate(v); }
    __host__ __device__ void Print() const { printf("(yaw: %f, pitch: %f, roll: %f)\n", static_cast<double>(yaw), static_cast<double>(pitch), static_cast<double>(roll)); }
};

using RotatorF = _Rotator<float>;
using Rotator = RotatorF;

inline const RotatorF RotatorF::Zero(0.0f, 0.0f, 0.0f);
