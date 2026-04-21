#pragma once

template <typename T>
class _Vector3;
template <typename T>
class _Rotator;

template <typename T>
class _Quaternion
{
public:
	T x;
	T y;
	T z;
	T w;

	__host__ __device__ _Quaternion(T x = 0, T y = 0, T z = 0, T w = 0) : x(x), y(y), z(z), w(w) { }
	__host__ __device__ _Quaternion(_Vector3<T> u, T w = 0) : x(u.x), y(u.y), z(u.z), w(w) { }	

	__host__ __device__ void operator=(const _Quaternion& q)
	{
		memcpy(this, &q, sizeof(_Quaternion));
	}

	__host__ __device__ void SetRotation(const _Vector3<T>& axis, const T& radian = 0)
	{
		_Vector3<T> u(sin(radian / 2) * axis.x, sin(radian / 2) * axis.y, sin(radian / 2) * axis.z);
		x = u.x;
		y = u.y;
		z = u.z; 
		w = cos(radian / 2);
	}

	__host__ __device__ _Quaternion Conjugate()
	{
		_Vector3<T> u(x, y, z);
		return _Quaternion(-u, w);
	}

	__host__ __device__ _Vector3<T> Rotate(const _Vector3<T>& v)
	{
		_Quaternion q = Cross(Cross(*this, _Quaternion(v, 0)), this->Conjugate());
		return _Vector3<T>(q.x, q.y, q.z);
	}

	__host__ __device__ _Matrix4<T> RotationMatrix()
	{
		_Matrix4<T> m(1 - 2 * y * y - 2 * z * z, 2 * x * y - 2 * z * w, 2 * x * z + 2 * y * w, 0,
					  2 * x * y + 2 * z * w, 1 - 2 * x * x - 2 * z * z, 2 * y * z - 2 * x * w, 0,
					  2 * x * z - 2 * y * w, 2 * y * z + 2 * x * w, 1 - 2 * x * x - 2 * y * y, 0,
					  0, 0, 0, 1);
		return m;
	}

	__host__ __device__ void Print()
	{
		printf("(x: %f, y: %f, z: %f, w: %f)\n", x, y, z, w);
	}
	
};

using QuaternionF = _Quaternion<float>;
using QuaternionD = _Quaternion<double>;
using Quaternion = QuaternionF;