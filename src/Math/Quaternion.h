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

    __host__ __device__ _Quaternion& operator=(const _Quaternion& q)
    {
        x = q.x;
        y = q.y;
        z = q.z;
        w = q.w;
        return *this;
    }

    __host__ __device__ void SetRotation(const _Vector3<T>& axis, const T& radian = 0)
    {
        const T halfRadian = radian / static_cast<T>(2);
        const T sinHalf = static_cast<T>(sin(halfRadian));
        x = sinHalf * axis.x;
        y = sinHalf * axis.y;
        z = sinHalf * axis.z;
        w = static_cast<T>(cos(halfRadian));
    }

    __host__ __device__ _Quaternion Conjugate() const
    {
        return _Quaternion(-x, -y, -z, w);
    }

    __host__ __device__ _Vector3<T> Rotate(const _Vector3<T>& v) const
    {
        _Quaternion q = Cross(Cross(*this, _Quaternion(v, 0)), Conjugate());
        return _Vector3<T>(q.x, q.y, q.z);
    }

    __host__ __device__ _Matrix4<T> RotationMatrix() const
    {
        return _Matrix4<T>(1 - 2 * y * y - 2 * z * z, 2 * x * y - 2 * z * w, 2 * x * z + 2 * y * w, 0,
            2 * x * y + 2 * z * w, 1 - 2 * x * x - 2 * z * z, 2 * y * z - 2 * x * w, 0,
            2 * x * z - 2 * y * w, 2 * y * z + 2 * x * w, 1 - 2 * x * x - 2 * y * y, 0,
            0, 0, 0, 1);
    }

    __host__ __device__ void Print() const
    {
        printf("(x: %f, y: %f, z: %f, w: %f)\n", static_cast<double>(x), static_cast<double>(y), static_cast<double>(z), static_cast<double>(w));
    }
};

using QuaternionF = _Quaternion<float>;
using QuaternionD = _Quaternion<double>;
using Quaternion = QuaternionF;
