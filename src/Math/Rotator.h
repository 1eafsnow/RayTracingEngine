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
	__host__ __device__ void operator=(const _Rotator& r) { memcpy(this, &r, sizeof(_Rotator)); }
	__host__ __device__ bool operator==(const _Rotator& r) const { return yaw == r.yaw && pitch == r.pitch && roll == r.roll; }
	__host__ __device__ bool operator!=(const _Rotator& r) const { return !(*this == r); }
	__host__ __device__ T& operator[](const int& i) { return (&yaw)[i]; }
	__host__ __device__ const T& operator[](const int& i) const { return (&yaw)[i]; }

	__host__ __device__ _Matrix3<T> RotateMatrix() const
	{
		float yawRad = yaw / 180.0f * PI;
		float pitchRad = pitch / 180.0f * PI;
		float rollRad = roll / 180.0f * PI;

		return _Matrix3<T>(cos(rollRad) * cos(yawRad) - sin(rollRad) * -sin(pitchRad) * -sin(yawRad), sin(rollRad) * cos(pitchRad), cos(rollRad) * sin(yawRad) - sin(rollRad) * -sin(pitchRad) * cos(yawRad),
			-sin(rollRad) * cos(yawRad) + cos(rollRad) * sin(pitchRad) * -sin(yawRad), cos(rollRad) * cos(pitchRad), -sin(rollRad) * sin(yawRad) + cos(rollRad) * sin(pitchRad) * cos(yawRad),
			cos(pitchRad) * -sin(yawRad), -sin(pitchRad), cos(pitchRad) * cos(yawRad));
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

	__host__ __device__ _Vector3<T> Rotate(_Vector3<T> v) const { return Quaternion().Rotate(v); }
	__host__ __device__ void Print() const { printf("(yaw: %f, pitch: %f, roll: %f)\n", yaw, pitch, roll); }
};

using RotatorF = _Rotator<float>;
using Rotator = RotatorF;

const RotatorF RotatorF::Zero;