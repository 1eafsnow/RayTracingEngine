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

	__host__ __device__ _Rotator operator+(const _Rotator& r)
	{
		return _Rotator(yaw + r.yaw, pitch + r.pitch, roll + r.roll);
	}

	__host__ __device__ _Rotator operator-(const _Rotator& r)
	{
		return _Rotator(yaw - r.yaw, pitch - r.pitch, roll - r.roll);
	}

	__host__ __device__ _Rotator operator*(const _Rotator& r)
	{
		return _Rotator(yaw * r.yaw, pitch * r.pitch, roll * r.roll);
	}

	__host__ __device__ _Rotator operator/(const _Rotator& r)
	{
		return _Rotator(yaw / r.yaw, pitch / r.pitch, roll / r.roll);
	}

	__host__ __device__ _Rotator operator*(const float& s)
	{
		return _Rotator(yaw * s, pitch * s, roll * s);
	}

	__host__ __device__ _Rotator operator/(const float& s)
	{
		return _Rotator<T>(yaw / s, pitch / s, roll / s);
	}

	__host__ __device__ _Rotator operator-()
	{
		return _Rotator(-yaw, -pitch, -roll);
	}

	__host__ __device__ void operator=(const _Rotator& r)
	{
		memcpy(this, &r, sizeof(_Rotator));
	}

	__host__ __device__ bool operator==(const _Rotator& r)
	{
		return yaw == r.yaw && pitch == r.pitch && roll == r.roll ? true : false;
	}

	__host__ __device__ bool operator!=(const _Rotator& r)
	{
		return yaw == r.yaw && pitch == r.pitch && roll == r.roll ? false : true;
	}

	__host__ __device__ T& operator[](const int& i)
	{
		return yaw;
	}

	__host__ __device__ _Matrix3<T> RotateMatrix()
	{
		float yaw = this->yaw / 180.0 * PI;
		float pitch = this->pitch / 180.0 * PI;
		float roll = this->roll / 180.0 * PI;

		return _Matrix3<T>(cos(roll) * cos(yaw) - sin(roll) * -sin(pitch) * -sin(yaw), sin(roll) * cos(pitch), cos(roll) * sin(yaw) - sin(roll) * -sin(pitch) * cos(yaw),
			-sin(roll) * cos(yaw) + cos(roll) * sin(pitch) * -sin(yaw), cos(roll) * cos(pitch), -sin(roll) * sin(yaw) + cos(roll) * sin(pitch) * cos(yaw),
			cos(pitch) * -sin(yaw), -sin(pitch), cos(pitch) * cos(yaw));
	}

	__host__ __device__ _Rotator(T yaw = 0, T pitch = 0, T roll = 0) : yaw(yaw), pitch(pitch), roll(roll) { }

	__host__ __device__ _Quaternion<T> Quaternion()
	{
		_Vector3<T> Forward(1, 0, 0);
		_Vector3<T> Leftward(0, -1, 0);
		_Vector3<T> Upward(0, 0, 1);

		_Quaternion<T> qYaw;
		qYaw.SetRotation(Upward, yaw / 180.0f * PI);
		//result = qYaw.Rotate(result);
		Forward = qYaw.Rotate(Forward);
		Leftward = qYaw.Rotate(Leftward);
		//Upward = qYaw.Rotate(Upward);

		_Quaternion<T> qPitch;
		qPitch.SetRotation(Leftward, pitch / 180.0f * PI);
		//result = qPitch.Rotate(result);
		Forward = qPitch.Rotate(Forward);
		//Leftward = qPitch.Rotate(Leftward);
		//Upward = qPitch.Rotate(Upward);

		_Quaternion<T> qRoll;
		qRoll.SetRotation(Forward, roll / 180.0f * PI);
		//result = qRoll.Rotate(result);
		//Forward = qRoll.Rotate(Forward);
		//Leftward = qRoll.Rotate(Leftward);
		//Upward = qRoll.Rotate(Upward);

		return Cross(qRoll, Cross(qPitch, qYaw));
	}

	__host__ __device__ _Vector3<T> Rotate(_Vector3<T> v)
	{
		return Quaternion().Rotate(v);
	}

	__host__ __device__ void Print()
	{
		printf("(yaw: %f, pitch: %f, roll: %f)\n", yaw, pitch, roll);
	}
};

using RotatorF = _Rotator<float>;
using Rotator = RotatorF;

const RotatorF RotatorF::Zero;