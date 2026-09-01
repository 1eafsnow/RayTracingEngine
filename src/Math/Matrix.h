#pragma once
#include <stdio.h>
#include <string>
#include <iostream>

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

template <typename T>
class _Vector3;
template <typename T>
class _Vector4;

template <typename T>
class _Matrix3
{
public:
    T elements[9];

    static const _Matrix3 UNIT;

    __host__ __device__ _Matrix3<T>& operator=(const _Matrix3& m)
    {
        memcpy(elements, m.elements, sizeof(T) * 9);
        return *this;
    }

    __host__ __device__ _Matrix3 operator+(const _Matrix3& m) const
    {
        _Matrix3 res;
        for (int i = 0; i < 9; i++)
        {
            res.elements[i] = this->elements[i] + m.elements[i];
        }
        return res;
    }

    __host__ __device__ T* operator[](const int& i)
    {
        return &elements[3 * i];
    }

    __host__ __device__ const T* operator[](const int& i) const
    {
        return &elements[3 * i];
    }

    __host__ __device__ _Matrix3() : elements{ 0 } { }
    __host__ __device__ _Matrix3(const T* elements) { memcpy(this->elements, elements, sizeof(T) * 9); }
    __host__ __device__ _Matrix3(const _Matrix3& matrix) { memcpy(elements, matrix.elements, sizeof(T) * 9); }
    __host__ __device__ _Matrix3(T e00, T e01, T e02,
        T e10, T e11, T e12,
        T e20, T e21, T e22) :
        elements{ e00, e01, e02,
            e10, e11, e12,
            e20, e21, e22 } { }

    __host__ __device__ T* Array()
    {
        return elements;
    }

    __host__ __device__ const T* Array() const
    {
        return elements;
    }

    __host__ __device__ _Matrix3 Transpose() const
    {
        _Matrix3 res;
        for (int i = 0; i < 3; i++)
        {
            for (int j = 0; j < 3; j++)
            {
                res[i][j] = (*this)[j][i];
            }
        }
        return res;
    }

    __host__ __device__ void Print()
    {
        std::cout << elements[0] << ', ' << elements[1] << ', ' << elements[2] << std::endl
            << elements[3] << ', ' << elements[4] << ', ' << elements[5] << std::endl
            << elements[6] << ', ' << elements[7] << ', ' << elements[8] << std::endl;
    }
};

template <typename T>
class _Matrix4
{
public:
    T elements[16];

    static const _Matrix4 UNIT;

    __host__ __device__ _Matrix4& operator=(const _Matrix4& m)
    {
        memcpy(elements, m.elements, sizeof(T) * 16);
        return *this;
    }

    __host__ __device__ _Matrix4 operator+(const _Matrix4& m) const
    {
        _Matrix4 res;
        for (int i = 0; i < 16; i++)
        {
            res.elements[i] = this->elements[i] + m.elements[i];
        }
        return res;
    }

    __host__ __device__ T* operator[](int i)
    {
        return &elements[4 * i];
    }

    __host__ __device__ const T* operator[](int i) const
    {
        return &elements[4 * i];
    }

    __host__ __device__ _Matrix4() : elements{ 0 } { }
    __host__ __device__ _Matrix4(const T* elements) { memcpy(this->elements, elements, sizeof(T) * 16); }
    __host__ __device__ _Matrix4(const _Matrix4& matrix) { memcpy(elements, matrix.elements, sizeof(T) * 16); }
    __host__ __device__ _Matrix4(T e00, T e01, T e02, T e03,
        T e10, T e11, T e12, T e13,
        T e20, T e21, T e22, T e23,
        T e30, T e31, T e32, T e33) :
        elements{ e00, e01, e02, e03,
            e10, e11, e12, e13,
            e20, e21, e22, e23,
            e30, e31, e32, e33 } { }

    __host__ __device__ T* Array()
    {
        return elements;
    }

    __host__ __device__ const T* Array() const
    {
        return elements;
    }

    __host__ __device__ _Matrix4 Transpose() const
    {
        _Matrix4 res;
        for (int i = 0; i < 4; i++)
        {
            for (int j = 0; j < 4; j++)
            {
                res[i][j] = (*this)[j][i];
            }
        }
        return res;
    }

    __host__ __device__ _Matrix4 TransformInverse() const
    {
        _Matrix4 rotate = RotateMatrixToTransform(TransformToRotateMatrix(*this).Transpose());
        _Matrix4 translate = _Matrix4(1, 0, 0, -(*this)[0][3],
            0, 1, 0, -(*this)[1][3],
            0, 0, 1, -(*this)[2][3],
            0, 0, 0, 1);

        return Matmul(rotate, translate);
    }

    __host__ __device__ void Print()
    {
        std::cout << elements[0] << ', ' << elements[1] << ', ' << elements[2] << ', ' << elements[3] << std::endl
            << elements[4] << ', ' << elements[5] << ', ' << elements[6] << ', ' << elements[7] << std::endl
            << elements[8] << ', ' << elements[9] << ', ' << elements[10] << ', ' << elements[11] << std::endl
            << elements[12] << ', ' << elements[13] << ', ' << elements[14] << ', ' << elements[15] << std::endl;
    }
};

using Matrix3F = _Matrix3<float>;
using Matrix4F = _Matrix4<float>;
using Matrix3 = Matrix3F;
using Matrix4 = Matrix4F;

inline const Matrix3F Matrix3F::UNIT = Matrix3F(1.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 0.0, 1.0);

inline const Matrix4F Matrix4F::UNIT = Matrix4F(1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0);

std::ostream& operator<<(std::ostream& os, const Matrix3F& v);
std::ostream& operator<<(std::ostream& os, const Matrix4F& v);
